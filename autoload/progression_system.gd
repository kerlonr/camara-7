extends Node
## Progressão do personagem (estilo Fallout): XP → níveis → talentos (escolha 1 de 3).
## Também guarda o catálogo de descobertas (primeira vez que minera cada rocha).

signal leveled_up(level: int)
signal xp_changed(xp: int, need: int)

const OFFER_SIZE := 3

var level: int = 1
var xp: int = 0
var perks: Array = []
var pending_picks: int = 0
var offer: Array = []
var discovered: Array = []
var trait_id := ""               # traço escolhido (único)
var trait_pending := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func reset() -> void:
	level = 1
	xp = 0
	perks = []
	pending_picks = 0
	offer = []
	discovered = []
	trait_id = ""
	trait_pending = true


func xp_to_next(lv: int = -1) -> int:
	if lv < 0:
		lv = level
	return 40 + 30 * lv + 5 * lv * lv


func add_xp(amount: int, source: String = "") -> void:
	if amount <= 0:
		return
	amount = maxi(1, int(round(amount * float(UpgradeSystem.get_stat("xp_mult", 1.0)))))
	xp += amount
	var gained := 0
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		pending_picks += 1
		gained += 1
		leveled_up.emit(level)
	if gained > 0:
		AudioSystem.play("level_up")
		EventBus.banner.emit("EXPERIÊNCIA", "Nível pessoal %d · talento: tecla K" % level)
		EventBus.toast.emit("Nível %d! Tecla K: escolher talento." % level, "good")
	xp_changed.emit(xp, xp_to_next())


## Escolhe o traço (uma vez só).
func choose_trait(id: String) -> bool:
	if not trait_pending or not DataManager.traits.has(id):
		return false
	trait_id = id
	trait_pending = false
	UpgradeSystem.recalc()
	HealthSystem.clamp_to_max()
	AudioSystem.play("quest_done")
	EventBus.toast.emit("Traço: %s" % DataManager.traits[id].get("name", id), "good")
	xp_changed.emit(xp, xp_to_next())
	return true


## Abre a escolha de traço se estiver pendente e nada mais estiver na tela.
func maybe_offer_trait() -> void:
	if trait_pending and UIManager.stack.is_empty() and not SceneManager.busy and GameState.location == "base":
		UIManager.open("perks", {"mode": "trait"})


func has_perk(id: String) -> bool:
	return perks.has(id)


func perk_data(id: String) -> Dictionary:
	return DataManager.perks.get(id, {})


## Três talentos sorteados (mantidos até a escolha para não dar para "rolar de novo").
func current_offer() -> Array:
	if pending_picks <= 0:
		return []
	if offer.is_empty():
		var pool := []
		for id in DataManager.perk_order:
			if not perks.has(id):
				pool.append(id)
		for i in range(pool.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var t = pool[i]
			pool[i] = pool[j]
			pool[j] = t
		offer = pool.slice(0, OFFER_SIZE)
	return offer


func choose(id: String) -> bool:
	if pending_picks <= 0 or not offer.has(id):
		return false
	perks.append(id)
	pending_picks -= 1
	offer = []
	UpgradeSystem.recalc()
	HealthSystem.clamp_to_max()
	AudioSystem.play("quest_done")
	EventBus.toast.emit("Talento adquirido: %s" % perk_data(id).get("name", id), "good")
	return true


## Efeitos de todos os talentos (lidos pelo UpgradeSystem.recalc()).
func perk_effects() -> Array:
	var out := []
	if trait_id != "":
		out.append(DataManager.traits.get(trait_id, {}).get("effects", {}))
	for id in perks:
		out.append(perk_data(id).get("effects", {}))
	return out


## Primeira vez que quebra um tipo de rocha → entra no catálogo e dá XP.
func discover(ore_id: String) -> void:
	if ore_id == "" or discovered.has(ore_id):
		return
	discovered.append(ore_id)
	var nm: String = DataManager.ores.get(ore_id, DataManager.containers.get(ore_id, {})).get("name", ore_id)
	EventBus.toast.emit("Descoberta: %s (+20 XP)" % nm, "item")
	add_xp(20, "discovery")


func get_save_data() -> Dictionary:
	return {"level": level, "xp": xp, "perks": perks, "pending": pending_picks, "offer": offer, "discovered": discovered,
		"trait": trait_id, "trait_pending": trait_pending}


func load_save_data(d: Dictionary) -> void:
	reset()
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	perks = d.get("perks", [])
	pending_picks = int(d.get("pending", 0))
	offer = d.get("offer", [])
	discovered = d.get("discovered", [])
	trait_id = String(d.get("trait", ""))
	trait_pending = bool(d.get("trait_pending", trait_id == ""))   # saves antigos ganham a escolha
