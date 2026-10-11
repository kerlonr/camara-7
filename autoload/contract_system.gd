extends Node
## Contratos diários (terminal → aba CONTRATOS): objetivos curtos que mudam todo dia,
## dão dinheiro e XP. Gerados de forma reproduzível por (seed do mundo + dia).

var contracts: Array = []      # {id, template, client, item, amount, money, xp, expires_day, done}
var last_day := 0
var _counter := 0


func _ready() -> void:
	EventBus.day_started.connect(func(_d): ensure_today())


func reset() -> void:
	contracts = []
	last_day = 0
	_counter = 0


func cfg() -> Dictionary:
	return DataManager.contracts


func ensure_today() -> void:
	if last_day == TimeSystem.day:
		return
	last_day = TimeSystem.day
	contracts = contracts.filter(func(c): return not c.done and int(c.expires_day) >= TimeSystem.day)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([GameState.world_seed, TimeSystem.day, "contratos"])
	var pool := []
	for t in cfg().get("templates", []):
		if GameState.max_depth >= int(t.get("min_depth", 0)) and not contracts.any(func(c): return c.template == t.id):
			pool.append(t)
	while contracts.size() < int(cfg().get("per_day", 3)) and not pool.is_empty():
		var t: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		var span: Array = t.amount
		var scale := 1.0 + GameState.max_depth * 0.04
		var amount := int(round(rng.randi_range(int(span[0]), int(span[1])) * scale))
		var value := float(DataManager.get_item(t.item).get("value", 1))
		_counter += 1
		contracts.append({
			"id": "%s_%d" % [t.id, _counter], "template": t.id, "client": t.client, "item": t.item,
			"amount": amount, "money": int(round(value * amount * float(t.money_mult))),
			"xp": int(t.xp) + amount, "expires_day": TimeSystem.day + int(cfg().get("days_to_complete", 2)) - 1,
			"done": false,
		})


func can_deliver(c: Dictionary) -> bool:
	return not c.done and InventorySystem.count(c.item) >= int(c.amount)


func deliver(id: String) -> bool:
	for c in contracts:
		if c.id == id and can_deliver(c):
			InventorySystem.remove_item(c.item, int(c.amount))
			EconomySystem.add_money(int(c.money))
			ProgressionSystem.add_xp(int(c.xp), "contract")
			c.done = true
			AudioSystem.play("sell")
			EventBus.toast.emit("Contrato cumprido: +%s, +%d XP" % [DataManager.currency(int(c.money)), int(c.xp)], "good")
			return true
	return false


func active() -> Array:
	ensure_today()
	return contracts.filter(func(c): return not c.done)


func get_save_data() -> Dictionary:
	return {"contracts": contracts, "last_day": last_day, "counter": _counter}


func load_save_data(d: Dictionary) -> void:
	reset()
	contracts = d.get("contracts", [])
	last_day = int(d.get("last_day", 0))
	_counter = int(d.get("counter", 0))
