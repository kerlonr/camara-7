class_name BaseArea
extends GameArea
## Base do jogador, construída a partir de data/areas/base.json.
## Luz ambiente acompanha a hora (sempre nublada/sombria — data/config/atmosphere.json).

const NPC_SCENE := preload("res://scenes/npc/npc.tscn")
const MACHINE_SCENE := preload("res://scenes/machines/machine_node.tscn")

var data: Dictionary = {}
var weather: WeatherFX
var _rain_minutes_left := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	area_id = "base"
	outdoor = true
	_rng.randomize()
	data = DataManager.areas.get("base", {})
	_create_layers()
	_build_map()
	build_contact_shade()
	_build_objects()
	RadiationSystem.ambient_rate = 0.0
	AudioSystem.set_ambient(data.get("ambient_sound", "wind"))
	spawn_player(_spawn_position())
	weather = WeatherFX.new()
	player.add_child(weather)
	weather.set_mode("rain" if _rain_minutes_left > 0 else "none")
	weather.set_ash(true)
	AudioSystem.set_music("base")
	TimeSystem.minute_passed.connect(_on_minutes)
	_roll_weather_start()
	_update_light()
	enemies = EnemyDirector.new()          # cães da Zona rondam o posto à noite
	enemies.setup(self, "surface_night")
	add_child(enemies)


func _spawn_position() -> Vector2:
	var spawn: String = init_args.get("spawn", "default")
	if spawn == "saved" and GameState.player_position != Vector2.ZERO:
		return GameState.player_position
	var spawns: Dictionary = data.get("spawns", {})
	var c: Array = spawns.get(spawn, spawns.get("default", [10, 10]))
	return cell_pos(Vector2i(c[0], c[1]))


func _build_map() -> void:
	var rows: Array = data.get("rows", [])
	var legend: Dictionary = data.get("legend", {})
	var width := 0
	for r in rows:
		width = maxi(width, String(r).length())
	map_size = Vector2i(width, rows.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 1986
	for y in rows.size():
		var row: String = rows[y]
		for x in width:
			var ch := row[x] if x < row.length() else "."
			var entry: Dictionary = legend.get(ch, legend.get(".", {}))
			var c := Vector2i(x, y)
			if entry.get("wall", false):
				var below_is_wall: bool = y + 1 >= rows.size() or (x < String(rows[y + 1]).length() and legend.get(String(rows[y + 1])[x], {}).get("wall", false))
				set_wall(c, entry.top if below_is_wall else entry.face)
				# chão por baixo (aparece em bordas transparentes)
				set_floor(c, "grass")
			else:
				var opts: Array = entry.get("tiles", ["grass"])
				set_floor(c, opts[rng.randi_range(0, opts.size() - 1)])


func _build_objects() -> void:
	for o in data.get("objects", []):
		if not Conditions.check(o.get("if", [])):
			continue
		var cell := Vector2i(o.cell[0], o.cell[1])
		if o.has("prop"):
			var p := place_prop(o.prop, cell, o)
			if p and o.has("action"):
				var ptex := DataManager.texture(DataManager.props[o.prop].get("sprite", ""))
				var wpx := minf(ptex.get_width() / float(DataManager.props[o.prop].get("frames", 1)), 40.0)
				var off: Array = o.get("interact_offset", [0, 0])
				add_interactable(p, o.action, o.get("prompt", ""), o.get("params", {}), Vector2(wpx, 20), Vector2(off[0], off[1]))
		elif o.has("npc"):
			var npc: Node2D = NPC_SCENE.instantiate()
			npc.npc_id = o.npc
			npc.position = cell_pos(cell)
			entities.add_child(npc)
		elif o.has("machine"):
			var m: Node2D = MACHINE_SCENE.instantiate()
			m.machine_id = o.machine
			m.position = Vector2((cell.x + 1) * TILE, (cell.y + 1) * TILE)
			entities.add_child(m)
			if o.get("pad", false):
				var pad := PropFactory.create("pad")
				pad.position = m.position
				floor_decor.add_child(pad)
		elif o.has("lore"):
			if GameState.has_note(o.lore):
				continue
			var d := place_prop("documents", cell)
			add_interactable(d, "note", "Ler: bilhete", {"note": o.lore, "consume": true}, Vector2(18, 14))


func _exit_tree() -> void:
	if TimeSystem.minute_passed.is_connected(_on_minutes):
		TimeSystem.minute_passed.disconnect(_on_minutes)


# ------------------------------------------------------------ luz / clima
func _on_minutes(minutes: int) -> void:
	if not is_inside_tree():
		return
	if _rain_minutes_left > 0:
		_rain_minutes_left = maxi(0, _rain_minutes_left - minutes)
		if _rain_minutes_left == 0:
			weather.set_mode("none")
			EventBus.weather_changed.emit("clear")
	elif _rng.randf() < float(DataManager.atmosphere.get("weather", {}).get("drizzle_chance_per_hour", 0.3)) * minutes / 60.0:
		_start_rain()
	_update_light()


func _roll_weather_start() -> void:
	if _rng.randf() < 0.4:
		_start_rain()


func _start_rain() -> void:
	var wcfg: Dictionary = DataManager.atmosphere.get("weather", {})
	_rain_minutes_left = _rng.randi_range(int(wcfg.get("drizzle_min_minutes", 60)), int(wcfg.get("drizzle_max_minutes", 240)))
	if weather:
		weather.set_mode("rain")
	EventBus.weather_changed.emit("rain")


func is_raining() -> bool:
	return _rain_minutes_left > 0


func _update_light() -> void:
	var c := _sky_color(TimeSystem.clock_minute())
	if is_raining():
		c = c * float(DataManager.atmosphere.get("weather", {}).get("storm_darkening", 0.82))
		c.a = 1.0
	canvas_mod.color = c
	var night := clampf((0.42 - c.get_luminance()) * 3.5, 0.0, 1.0)
	for l in get_tree().get_nodes_in_group("world_light"):
		if l is FlickerLight and is_ancestor_of(l):
			l.factor = night if l.night_only else lerpf(0.35, 1.0, night)


func _sky_color(minute: int) -> Color:
	var keys: Array = DataManager.atmosphere.get("surface_light", [])
	if keys.is_empty():
		return Color(0.5, 0.5, 0.5)
	var prev: Dictionary = keys[0]
	for k in keys:
		if int(k.minute) > minute:
			var t := float(minute - int(prev.minute)) / maxf(1.0, float(int(k.minute) - int(prev.minute)))
			return Color(prev.color).lerp(Color(k.color), t)
		prev = k
	return Color(prev.color)


func lantern_factor() -> float:
	return clampf((0.4 - canvas_mod.color.get_luminance()) * 3.0, 0.0, 1.0)
