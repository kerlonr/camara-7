class_name SpecialEncounter
extends Node2D
## Encontro especial raro de um nível (data/mines/specials.json). Sorteado de forma reproduzível
## pela seed + profundidade + descida; no máximo um por nível.

var level: MineLevel
var data: Dictionary = {}
var _done := false
var _armed := false
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _figure: Sprite2D
var _radio_audio: AudioStreamPlayer2D
var _cell := Vector2i.ZERO


## Sorteia (ou não) um encontro para o nível. Retorna null se não houver.
static func roll(p_level: MineLevel) -> SpecialEncounter:
	var cfg := DataManager.load_json("mines/specials.json")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([GameState.world_seed, p_level.depth, GameState.descents, "especial"])
	if rng.randf() >= float(cfg.get("total_chance", 0.15)):
		return null
	var pool := []
	var total := 0.0
	for e in cfg.get("entries", []):
		if p_level.depth < int(e.get("min_depth", 1)):
			continue
		if e.get("once", false) and GameState.has_flag("special_" + String(e.id)):
			continue
		pool.append(e)
		total += float(e.get("weight", 1))
	if pool.is_empty():
		return null
	var r := rng.randf() * total
	var pick: Dictionary = pool[0]
	for e in pool:
		r -= float(e.get("weight", 1))
		if r <= 0.0:
			pick = e
			break
	var se := SpecialEncounter.new()
	se.level = p_level
	se.data = pick
	se._rng.seed = rng.seed + 7
	return se


func _ready() -> void:
	_cell = _find_cell()
	position = level.cell_pos(_cell)
	match String(data.id):
		"lost_miner":
			_figure = Sprite2D.new()
			_figure.texture = DataManager.texture("res://assets/environment/props/miner_sitting.png")
			_figure.centered = false
			_figure.hframes = 2
			_figure.offset = Vector2(-8, -24)
			add_child(_figure)
		"radio_room":
			var p := level.place_prop("radio_old", _cell)
			_radio_audio = AudioStreamPlayer2D.new()
			_radio_audio.stream = AudioSystem.loop_stream("radio_song")
			_radio_audio.volume_db = -6.0
			_radio_audio.max_distance = 220.0
			_radio_audio.bus = "Ambient"
			_radio_audio.autoplay = true
			add_child(_radio_audio)
			if p:
				level.add_interactable(p, "special", String(data.prompt), {"node": get_path()}, Vector2(18, 14))
		"full_cart":
			var c := level.place_prop("minecart", _cell)
			if c:
				level.add_interactable(c, "special", String(data.prompt), {"node": get_path()}, Vector2(22, 14))
		"kolya_stash":
			var b := level.place_prop("concrete_blocks", _cell)
			if b:
				level.add_interactable(b, "special", String(data.prompt), {"node": get_path()}, Vector2(20, 14))
		"helmet_circle":
			for i in 6:
				var off := Vector2i(roundi(cos(i * TAU / 6) * 1.6), roundi(sin(i * TAU / 6) * 1.2))
				level.place_prop("helmet_floor", _cell + off)
			var cd := level.place_prop("candles", _cell)
			if cd:
				for l in cd.get_children():
					if l is Light2D:
						l.enabled = false                 # velas apagadas até o jogador acender
				level.add_interactable(cd, "special", String(data.prompt), {"node": get_path()}, Vector2(16, 14))
		"geiger_song":
			pass
	_armed = true


func _find_cell() -> Vector2i:
	var spawn: Vector2i = level.layout.spawn
	var best := spawn
	var tries := 0
	while tries < 300:
		tries += 1
		var c := Vector2i(_rng.randi_range(2, level.layout.w - 3), _rng.randi_range(2, level.layout.h - 3))
		if level.layout.grid[c.y * level.layout.w + c.x] != MineGenerator.FLOOR:
			continue
		if Vector2(c - spawn).length() < 10.0:
			continue
		var pos := level.cell_pos(c)
		var q := PhysicsPointQueryParameters2D.new()
		q.position = pos + Vector2(0, -4)
		q.collision_mask = 1 | 4
		if not level.get_world_2d().direct_space_state.intersect_point(q, 1).is_empty():
			continue
		if String(data.id) == "lost_miner" and level.layout.grid[(c.y - 1) * level.layout.w + c.x] == MineGenerator.FLOOR:
			continue                       # o mineiro fica encostado numa parede
		best = c
		break
	return best


func _process(delta: float) -> void:
	if _done or not _armed or level.player == null or get_tree().paused:
		return
	_t += delta
	var d := level.player.global_position.distance_to(global_position)
	match String(data.id):
		"lost_miner":
			if d < 34.0:
				_figure.frame = 1                  # ele vira a cabeça
				_done = true
				AudioSystem.play_at("vulto_fade", global_position, 1.1)
				var tw := create_tween()
				tw.tween_interval(0.5)
				tw.tween_property(_figure, "modulate:a", 0.0, 1.6)
				tw.tween_callback(func():
					level.place_prop("lamp_broken", _cell)
					_reward())
		"geiger_song":
			if d < 60.0:
				_done = true
				_geiger_pattern()


func _geiger_pattern() -> void:
	EventBus.caption.emit("[o contador começa a clicar em ritmo]")
	for n in [7, 7, 2, 6, 0, 4]:
		for i in maxi(1, n):
			AudioSystem.play("geiger", 1.0 if n > 0 else 0.6)
			await get_tree().create_timer(0.09).timeout
		await get_tree().create_timer(0.55).timeout
	_reward()


## Chamado pela ação "special" do interativo.
func interact() -> void:
	if _done:
		return
	_done = true
	match String(data.id):
		"radio_room":
			if _radio_audio:
				_radio_audio.stop()
			AudioSystem.play("radio_tick")
		"full_cart":
			var ores := ["coal", "iron_ore", "copper_ore"]
			if level.depth >= 6:
				ores.append("lead_ore")
			for i in _rng.randi_range(6, 9):
				Effects.spawn_drop(level.entities, position + Vector2(0, -4), ores[_rng.randi() % ores.size()], 1)
			AudioSystem.play("pickup")
		"kolya_stash":
			AudioSystem.play("rock_break", 1.3, -6.0)
		"helmet_circle":
			for l in get_tree().get_nodes_in_group("world_light"):
				if l is Light2D and l.global_position.distance_to(global_position) < 12.0:
					l.enabled = true
			AudioSystem.play("stinger_soft")
	_reward()


func _reward() -> void:
	ProgressionSystem.add_xp(int(data.get("xp", 10)), "especial")
	for dr in data.get("drops", []):
		if _rng.randf() < float(dr[2]):
			Effects.spawn_drop(level.entities, position + Vector2(0, -4), String(dr[0]), int(dr[1]))
	if data.has("resist"):
		RadiationSystem.add_resist(float(data.resist[0]), float(data.resist[1]))
	if data.has("flag"):
		GameState.set_flag(String(data.flag))
	GameState.set_flag("special_" + String(data.id))
	GameState.stats["specials_found"] = int(GameState.stats.get("specials_found", 0)) + 1
	EventBus.toast.emit(String(data.get("message", "")), "item")
