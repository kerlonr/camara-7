extends Node
## Missões (data/quests/quests.json): início, progresso, entrega e recompensas.
## A missão principal fica sempre rastreada no HUD.

var active: Dictionary = {}     # id -> {started_day}
var done: Array = []
var tracked: String = ""
var _ready_notified: Dictionary = {}


func _ready() -> void:
	EventBus.inventory_changed.connect(_check_ready)
	EventBus.depth_reached.connect(func(_d): _check_ready())
	EventBus.flag_changed.connect(func(_f): _check_ready())


func reset() -> void:
	active = {}
	done = []
	tracked = ""
	_ready_notified = {}


func data(id: String) -> Dictionary:
	return DataManager.quests.get(id, {})


func is_active(id: String) -> bool:
	return active.has(id)


func is_done(id: String) -> bool:
	return done.has(id)


func start(id: String) -> void:
	if is_active(id) or is_done(id) or data(id).is_empty():
		return
	active[id] = {"started_day": TimeSystem.day}
	if data(id).get("main", false) or tracked == "" or not is_active(tracked):
		tracked = id
	EventBus.toast.emit("Nova missão: %s" % data(id).get("title", id), "item")
	AudioSystem.play("quest")
	EventBus.quest_changed.emit(id)
	_check_ready()


## Lista de objetivos com progresso: [{text, cur, need, ok}]
func progress(id: String) -> Array:
	var out := []
	for o in data(id).get("objectives", []):
		var cur := 0
		var need := 1
		match String(o.type):
			"deliver", "have":
				need = int(o.get("amount", 1))
				cur = mini(InventorySystem.count(o.item), need)
			"reach_depth":
				need = int(o.depth)
				cur = mini(GameState.max_depth, need)
			"tapes":
				need = int(o.count)
				cur = mini(StorySystem.tapes_found(), need)
			"flag":
				cur = 1 if GameState.has_flag(o.flag) else 0
		out.append({"text": o.get("text", ""), "cur": cur, "need": need, "ok": cur >= need, "type": o.type})
	return out


func is_ready(id: String) -> bool:
	if not is_active(id):
		return false
	for p in progress(id):
		if not p.ok:
			return false
	return true


func complete(id: String) -> bool:
	if not is_ready(id):
		return false
	var q := data(id)
	for o in q.get("objectives", []):
		if o.type == "deliver":
			InventorySystem.remove_item(o.item, int(o.get("amount", 1)))
	active.erase(id)
	done.append(id)
	var r: Dictionary = q.get("reward", {})
	if int(r.get("xp", 0)) > 0:
		ProgressionSystem.add_xp(int(r.xp), "quest")
	if int(r.get("money", 0)) > 0:
		EconomySystem.add_money(int(r.money))
		EventBus.toast.emit("+%s" % DataManager.currency(int(r.money)), "good")
	var items: Dictionary = r.get("items", {})
	for it in items:
		var left := InventorySystem.add_item(it, int(items[it]))
		EventBus.toast.emit("Recebeu: %dx %s" % [int(items[it]) - left, DataManager.item_name(it)], "good")
	for f in r.get("flags", []):
		GameState.set_flag(f)
	EventBus.toast.emit("Missão concluída: %s" % q.get("title", id), "good")
	AudioSystem.play("quest_done")
	if tracked == id:
		tracked = _pick_tracked()
	EventBus.quest_changed.emit(id)
	return true


func _pick_tracked() -> String:
	for id in active:
		if data(id).get("main", false):
			return id
	return active.keys()[0] if not active.is_empty() else ""


func _check_ready() -> void:
	for id in active:
		var r := is_ready(id)
		if r and not _ready_notified.get(id, false):
			_ready_notified[id] = true
			# a principal termina pela história, não por entrega
			if not data(id).get("main", false):
				var giver: String = DataManager.npcs.get(data(id).get("giver", ""), {}).get("name", "")
				EventBus.toast.emit("Missão pronta: fale com %s." % giver, "good")
				StorySystem.hint("quest_ready")
			EventBus.quest_changed.emit(id)
		elif not r:
			_ready_notified[id] = false


func get_save_data() -> Dictionary:
	return {"active": active, "done": done, "tracked": tracked}


func load_save_data(d: Dictionary) -> void:
	reset()
	var a = d.get("active", {})
	active = a if a is Dictionary else {}
	done = d.get("done", [])
	tracked = d.get("tracked", "")
	for id in active:
		_ready_notified[id] = is_ready(id)
