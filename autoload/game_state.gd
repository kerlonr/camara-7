extends Node
## Estado do mundo: seed, local, profundidade, descidas, flags de história,
## notas encontradas e estatísticas.

var world_seed: int = 0
var location: String = "base"        # base | mine
var depth: int = 0                   # 0 = superfície
var max_depth: int = 0
var descents: int = 0                # quantas vezes desceu (cada descida gera uma mina diferente)
var notes_found: Array = []
var flags: Dictionary = {}
var stats: Dictionary = {}
var player_position: Vector2 = Vector2.ZERO
var lantern_on := true                # lanterna ligada (tecla F); não vai para o save
var spawn_point: String = "default"


func reset(seed_value: int) -> void:
	world_seed = seed_value
	location = "base"
	depth = 0
	max_depth = 0
	descents = 0
	notes_found = []
	flags = {}
	stats = {"rocks_broken": 0, "money_earned": 0, "items_sold": 0, "days": 1, "passouts": 0}
	spawn_point = "default"


func set_location(loc: String, d: int) -> void:
	location = loc
	depth = d
	if d > max_depth:
		var old := max_depth
		max_depth = d
		EventBus.depth_reached.emit(d)
		ProgressionSystem.add_xp(5 + d, "depth")
		if old > 0 and d > 1 and d % 5 == 0:
			EventBus.toast.emit("Recorde: nível %d" % d, "good")
	EventBus.location_changed.emit(loc, d)


func checkpoint_every() -> int:
	return int(DataManager.game.get("mine", {}).get("checkpoint_every", 5))


## Níveis acessíveis pelo elevador: 1 e múltiplos de N já alcançados.
func checkpoints() -> Array:
	var out := [1]
	var step := checkpoint_every()
	var d := step
	while d <= max_depth:
		out.append(d)
		d += step
	return out


# ------------------------------------------------------------ flags
func has_flag(f: String) -> bool:
	return flags.get(f, false)


func set_flag(f: String, value: bool = true) -> void:
	if has_flag(f) == value:
		return
	flags[f] = value
	EventBus.flag_changed.emit(f)


# ------------------------------------------------------------ estatísticas / notas
func add_stat(key: String, amount: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + amount


func has_note(id: String) -> bool:
	return notes_found.has(id)


func find_note(id: String) -> void:
	if id == "" or notes_found.has(id):
		return
	notes_found.append(id)
	ProgressionSystem.add_xp(40 if id.begins_with("tape_") else 10, "note")
	EventBus.note_found.emit(id)


## Sorteia uma nota ainda não encontrada adequada à profundidade ("" se não houver).
func random_note(rng: RandomNumberGenerator, at_depth: int, pool: String = "random") -> String:
	var candidates := []
	for id in DataManager.note_order:
		var n: Dictionary = DataManager.notes[id]
		if n.get("fixed", false) or notes_found.has(id):
			continue
		if String(n.get("pool", "random")) != pool:
			continue
		if int(n.get("min_depth", 1)) <= at_depth:
			candidates.append(id)
	if candidates.is_empty():
		return ""
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func get_save_data() -> Dictionary:
	return {
		"world_seed": world_seed, "location": location, "depth": depth, "max_depth": max_depth,
		"descents": descents, "notes_found": notes_found, "flags": flags, "stats": stats,
		"player_position": [player_position.x, player_position.y],
	}


func load_save_data(d: Dictionary) -> void:
	world_seed = int(d.get("world_seed", 0))
	location = d.get("location", "base")
	depth = int(d.get("depth", 0))
	max_depth = int(d.get("max_depth", 0))
	descents = int(d.get("descents", 0))
	notes_found = d.get("notes_found", [])
	var f = d.get("flags", {})
	flags = f if f is Dictionary else {}
	stats = d.get("stats", {})
	var p: Array = d.get("player_position", [0, 0])
	player_position = Vector2(p[0], p[1])
