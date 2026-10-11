extends Node
## Trilhas de upgrade e atributos derivados.
## Atributo final = base (player.json) → 'set' do nível atual de cada trilha → soma de todos os 'add'.

var levels: Dictionary = {}
var _stats: Dictionary = {}


func _ready() -> void:
	reset()


func reset() -> void:
	levels = {}
	for id in DataManager.upgrade_order:
		levels[id] = 0
	recalc()


func level(track_id: String) -> int:
	return int(levels.get(track_id, 0))


func max_level(track_id: String) -> int:
	return DataManager.upgrades.get(track_id, {}).get("levels", []).size() - 1


func level_data(track_id: String, lv: int) -> Dictionary:
	var lvls: Array = DataManager.upgrades.get(track_id, {}).get("levels", [])
	if lv < 0 or lv >= lvls.size():
		return {}
	return lvls[lv]


func current_data(track_id: String) -> Dictionary:
	return level_data(track_id, level(track_id))


func next_data(track_id: String) -> Dictionary:
	return level_data(track_id, level(track_id) + 1)


func is_maxed(track_id: String) -> bool:
	return level(track_id) >= max_level(track_id)


## Retorna {ok: bool, reasons: Array[String]} para o próximo nível.
func check(track_id: String) -> Dictionary:
	var reasons: Array = []
	if is_maxed(track_id):
		return {"ok": false, "reasons": ["Nível máximo"]}
	var nxt := next_data(track_id)
	var req: Dictionary = nxt.get("requires", {})
	if int(req.get("max_depth", 0)) > GameState.max_depth:
		reasons.append("Alcance o nível %d da mina" % int(req.max_depth))
	var ups: Dictionary = req.get("upgrades", {})
	for other in ups:
		if level(other) < int(ups[other]):
			var od := level_data(other, int(ups[other]))
			reasons.append("Requer: %s" % od.get("name", other))
	for it in nxt.get("items", {}):
		if InventorySystem.count(it) < int(nxt.items[it]):
			reasons.append("Faltam itens")
			break
	if not EconomySystem.can_afford(int(nxt.get("cost", 0))):
		reasons.append("Dinheiro insuficiente")
	return {"ok": reasons.is_empty(), "reasons": reasons}


func purchase(track_id: String) -> bool:
	if not check(track_id).ok:
		return false
	var nxt := next_data(track_id)
	if not EconomySystem.spend(int(nxt.get("cost", 0))):
		return false
	for it in nxt.get("items", {}):
		InventorySystem.remove_item(it, int(nxt.items[it]))
	levels[track_id] = level(track_id) + 1
	recalc()
	EventBus.upgrade_purchased.emit(track_id, level(track_id))
	return true


func recalc() -> void:
	_stats = DataManager.player.get("base_stats", {}).duplicate(true)
	for id in DataManager.upgrade_order:
		var lvls: Array = DataManager.upgrades[id].get("levels", [])
		for i in range(mini(level(id), lvls.size() - 1) + 1):
			var lv: Dictionary = lvls[i]
			var s: Dictionary = lv.get("set", {})
			for k in s:
				_stats[k] = s[k]
			var a: Dictionary = lv.get("add", {})
			for k in a:
				_stats[k] = float(_stats.get(k, 0.0)) + float(a[k])
	# talentos (ProgressionSystem): soma, depois multiplica, depois flags
	var prog := get_node_or_null("/root/ProgressionSystem")
	if prog:
		for eff in prog.perk_effects():
			var a2: Dictionary = eff.get("add", {})
			for k in a2:
				_stats[k] = float(_stats.get(k, 0.0)) + float(a2[k])
			var m: Dictionary = eff.get("mul", {})
			for k in m:
				_stats[k] = float(_stats.get(k, 1.0)) * float(m[k])
			var st: Dictionary = eff.get("set", {})
			for k in st:
				_stats[k] = st[k]
	EventBus.stats_changed.emit()


func get_stat(stat_name: String, default = 0):
	return _stats.get(stat_name, default)


func get_save_data() -> Dictionary:
	return {"levels": levels}


func load_save_data(d: Dictionary) -> void:
	reset()
	var saved: Dictionary = d.get("levels", {})
	for k in saved:
		if levels.has(k):
			levels[k] = clampi(int(saved[k]), 0, max_level(k))
	recalc()
