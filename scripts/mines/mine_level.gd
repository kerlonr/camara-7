class_name MineLevel
extends GameArea
## Um nível da mina, construído a partir do layout do MineGenerator.
## Cada descida gera uma mina nova (seed + profundidade + nº da descida).

const ROCK_SCENE := preload("res://scenes/mining/rock.tscn")

var layout: Dictionary = {}
var special: SpecialEncounter
var base_ambient := 0.0
var fog_extra := 0.0


func _ready() -> void:
	depth = int(init_args.get("depth", 1))
	area_id = "mine"
	_create_layers()
	var story := StorySystem.pending_placement(depth)
	layout = MineGenerator.new().generate(GameState.world_seed, depth, {
		"descent": GameState.descents,
		"story": story,
		"blessing": GameState.has_flag("hanna_blessing"),
		"rich_mult": float(UpgradeSystem.get_stat("rich_mult", 1.0)),
		"geode_mult": float(UpgradeSystem.get_stat("geode_mult", 1.0)),
	})
	map_size = Vector2i(layout.w, layout.h)
	_build_tiles()
	build_contact_shade()
	_build_props()
	_build_lamps()
	_build_rocks()
	_build_exits()
	_build_story()
	_build_drips()
	var b: Dictionary = layout.biome
	var eff: Dictionary = layout.effects
	var dark := Color(b.get("darkness", "#151310")) * float(layout.darkness_mult)
	if layout.lamps_off:
		dark = dark.darkened(0.35)
	if layout.red_lights:
		dark = dark.lerp(Color("#2a0d0a"), 0.5)
	dark.a = 1.0
	canvas_mod.color = dark
	fog_extra = float(eff.get("fog", 0.0))
	base_ambient = float(layout.ambient_rad)
	RadiationSystem.ambient_rate = base_ambient
	if eff.get("silence", false):
		AudioSystem.set_ambient("")
	else:
		AudioSystem.set_ambient(b.get("ambient_sound", "mine"))
	AudioSystem.set_music(b.get("music", ""))
	Settings.set_underground_reverb(true)
	spawn_player(cell_pos(layout.spawn))
	player.facing = Vector2.DOWN
	var fx := WeatherFX.new()
	player.add_child(fx)
	fx.set_mode("dust")
	var ph := Phenomena.new()
	ph.setup(self, float(eff.get("phenomena_mult", 1.0)), eff.get("tremors", false))
	add_child(ph)
	enemies = EnemyDirector.new()
	enemies.setup(self, "mine")
	add_child(enemies)
	_add_special.call_deferred()
	_announce()


## Encontro especial raro (depois de as rochas existirem na física).
func _add_special() -> void:
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	special = SpecialEncounter.roll(self)
	if special:
		add_child(special)


func _exit_tree() -> void:
	Settings.set_underground_reverb(false)


func _build_tiles() -> void:
	var grid: PackedByteArray = layout.grid
	var w: int = layout.w
	var b: Dictionary = layout.biome
	var tops: Array = b.get("wall_top", ["rock_top"])
	var faces: Array = b.get("wall_face", ["rock_face"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([GameState.world_seed, depth, GameState.descents, "tiles"])
	for y in range(-1, layout.h + 1):
		for x in range(-1, w + 1):
			var c := Vector2i(x, y)
			var floor_here: bool = x >= 0 and y >= 0 and x < w and y < layout.h and grid[y * w + x] == MineGenerator.FLOOR
			if floor_here:
				set_floor(c, layout.floor_tiles.get(c, "mine_floor"))
			else:
				var below := Vector2i(x, y + 1)
				var floor_below: bool = below.x >= 0 and below.y >= 0 and below.x < w and below.y < layout.h \
					and grid[below.y * w + below.x] == MineGenerator.FLOOR
				if floor_below:
					set_wall(c, faces[rng.randi_range(0, faces.size() - 1)])
				else:
					set_wall(c, tops[rng.randi_range(0, tops.size() - 1)])


func _build_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([GameState.world_seed, depth, GameState.descents, "terminals"])
	for p in layout.props:
		if p.has("container"):
			continue
		var node := place_prop(p.id, p.cell, {"no_interact": p.id == "terminal_mine"})
		if node and p.id == "terminal_mine":
			var note := GameState.random_note(rng, depth, "terminal")
			if note == "":
				var all := []
				for id in DataManager.note_order:
					if DataManager.notes[id].get("pool", "") == "terminal":
						all.append(id)
				note = all[rng.randi_range(0, all.size() - 1)] if not all.is_empty() else ""
			if note != "":
				add_interactable(node, "terminal", "Terminal ЭВМ-7", {"note": note}, Vector2(20, 16))


func _build_lamps() -> void:
	var flicker_chance := float(DataManager.atmosphere.get("mine", {}).get("lamp_flicker_chance", 0.35))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([GameState.world_seed, depth, GameState.descents, "lamps"])
	for l in layout.lamps:
		var prop := place_prop(l.id, l.cell)
		if prop == null:
			continue
		var light := prop.get_node_or_null("Light") as FlickerLight
		if light == null:
			continue
		if l.color != null:
			light.color = Color(l.color)
		if rng.randf() < flicker_chance:
			light.flicker = 0.9
		if layout.lamps_off:
			light.broken = true
			var loop := prop.get_node_or_null("Loop")
			if loop:
				loop.queue_free()
			var spr := prop.get_node_or_null("Sprite") as CanvasItem
			if spr:
				spr.modulate = Color(0.45, 0.45, 0.45)


func _build_rocks() -> void:
	var i := 0
	for r in layout.rocks:
		var data: Dictionary = DataManager.containers.get(r.id, {}) if r.container else DataManager.ores.get(r.id, {})
		if data.is_empty():
			continue
		var rock: Rock = ROCK_SCENE.instantiate()
		rock.setup(data, r.container, depth, hash([GameState.world_seed, depth, GameState.descents, i]), r.get("rich", false))
		rock.position = cell_pos(r.cell)
		entities.add_child(rock)
		i += 1


func _build_exits() -> void:
	var up := place_prop("ladder_up", layout.ladder_up)
	add_interactable(up, "ladder_up", "Subir para a base", {}, Vector2(16, 12), Vector2(0, 10))
	var down := place_prop("ladder_down", layout.ladder_down)
	add_interactable(down, "ladder_down", "Descer para o nível %d" % (depth + 1), {}, Vector2(18, 16))
	if layout.elevator != null:
		var el := place_prop("elevator", layout.elevator)
		add_interactable(el, "elevator", "Elevador", {}, Vector2(30, 16))


func _build_story() -> void:
	var s: Dictionary = layout.story
	if s.is_empty():
		return
	var p: Dictionary = s.placement
	match String(p.get("kind", "")):
		"tape":
			var rec := place_prop("tape_recorder", s.cell)
			add_interactable(rec, "story_pickup", "Pegar a fita do gravador", {"placement": p}, Vector2(18, 14))
			EventBus.caption.emit("[chiado de fita em algum lugar deste nível]")
		"item":
			var h := place_prop("helmet_floor", s.cell)
			h.modulate = Color(1.2, 0.85, 0.85)
			add_interactable(h, "story_pickup", "Capacete com fita vermelha", {"placement": p}, Vector2(16, 14))
		"final_door":
			var door := place_prop("door_7", s.cell)
			add_interactable(door, "final_door", "Porta hermética — CÂMARA 7", {}, Vector2(30, 14), Vector2(0, 14))
			EventBus.caption.emit("[um zumbido grave vem de algum lugar profundo]")


func _build_drips() -> void:
	for c in layout.drips:
		var fx := AmbientFX.create("drip")
		fx.position = cell_pos(c) + Vector2(randf_range(-5, 5), -2)
		floor_decor.add_child(fx)


func _announce() -> void:
	var b: Dictionary = layout.biome
	EventBus.banner.emit("NÍVEL %d" % depth, String(b.get("name", "")).to_upper())
	for ev in layout.events:
		EventBus.toast.emit(ev.get("message", ""), "warn")
	if layout.elevator != null:
		EventBus.toast.emit("Elevador restaurável neste nível.", "good")
		if int(UpgradeSystem.get_stat("elevator", 0)) > 0:
			StorySystem.hint("elevator")
	StorySystem.hint("first_mine")
	if depth >= 2:
		StorySystem.hint("dosimeter_pen")
