class_name Phenomena
extends Node2D
## Fenômenos estranhos da mina (data/mines/phenomena.json). Não há monstros:
## o desconforto vem de som, luz e da sensação de não estar sozinho.
## Cada evento gera uma legenda de som (acessibilidade).

var level: MineLevel
var mult := 1.0
var _timer := 0.0
var _rng := RandomNumberGenerator.new()
var _shadow: Sprite2D
var _shadow_t := 0.0
var _ghost_t := 0.0
var _tremors := false
var _tremor_timer := 0.0


func setup(p_level: MineLevel, p_mult: float, tremors: bool) -> void:
	level = p_level
	mult = p_mult
	_tremors = tremors


func _ready() -> void:
	_rng.randomize()
	_timer = _next_interval() * 0.6
	_tremor_timer = _rng.randf_range(20.0, 45.0)
	_shadow = Sprite2D.new()
	_shadow.texture = DataManager.texture("res://assets/effects/shadow_figure.png")
	_shadow.centered = false
	_shadow.offset = Vector2(-8, -26)
	_shadow.visible = false
	_shadow.z_index = 4
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED   # visível mesmo fora da luz
	_shadow.material = mat
	add_child(_shadow)


func _next_interval() -> float:
	var cfg: Dictionary = DataManager.phenomena
	var deep := clampf(float(level.depth) / 25.0, 0.0, 1.0) if level else 0.0
	var a: Array = cfg.get("interval", [55, 120])
	var b: Array = cfg.get("interval_min_deep", [30, 70])
	var lo := lerpf(float(a[0]), float(b[0]), deep)
	var hi := lerpf(float(a[1]), float(b[1]), deep)
	return _rng.randf_range(lo, hi) / maxf(0.2, mult)


func _process(delta: float) -> void:
	if level == null or level.player == null or get_tree().paused:
		return
	_update_shadow(delta)
	if _ghost_t > 0.0:
		_ghost_t -= delta
		RadiationSystem.ambient_rate = level.base_ambient + (0.25 if _ghost_t > 0.0 else 0.0)
		if _ghost_t <= 0.0:
			RadiationSystem.ambient_rate = level.base_ambient
	if _tremors:
		_tremor_timer -= delta
		if _tremor_timer <= 0.0:
			_tremor_timer = _rng.randf_range(25.0, 60.0)
			_do("tremor")
	_timer -= delta
	if _timer <= 0.0:
		_timer = _next_interval()
		var e := _pick()
		if not e.is_empty():
			_do(e.id)
			EventBus.caption.emit(e.get("caption", ""))
			StorySystem.hint("phenomenon")


func _pick() -> Dictionary:
	var pool := []
	var total := 0.0
	for e in DataManager.phenomena.get("entries", []):
		if level.depth >= int(e.get("min_depth", 1)):
			pool.append(e)
			total += float(e.weight)
	var r := _rng.randf() * total
	for e in pool:
		r -= float(e.weight)
		if r <= 0.0:
			return e
	return {}


func _behind_player(dist: float) -> Vector2:
	var p := level.player
	return p.global_position - p.facing * dist + Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-12, 12))


func _do(id: String) -> void:
	var p := level.player
	match id:
		"footsteps":
			_footsteps(p)
		"knock":
			_knocks(p.global_position + Vector2(_rng.randf_range(-120, 120), _rng.randf_range(-80, 80)))
		"whisper":
			AudioSystem.play_at("whisper", _behind_player(40.0), _rng.randf_range(0.85, 1.05))
		"lights":
			for l in level.get_tree().get_nodes_in_group("world_light"):
				if l is FlickerLight and level.is_ancestor_of(l) and l.global_position.distance_to(p.global_position) < 260.0:
					_blackout(l, _rng.randf_range(1.5, 4.0))
			AudioSystem.play("power_down", 1.0, -6.0)
		"silence":
			AudioSystem.silence(_rng.randf_range(8.0, 16.0))
		"radio":
			AudioSystem.play_at("radio_voice", p.global_position + Vector2(_rng.randf_range(-90, 90), _rng.randf_range(-60, 60)))
		"geiger_ghost":
			_ghost_t = _rng.randf_range(2.0, 4.0)
		"name_call":
			AudioSystem.play_at("name_call", _behind_player(70.0), 0.9)
		"shadow":
			_spawn_shadow(p)
		"tremor":
			EventBus.camera_shake.emit(1.6, 1.2)
			AudioSystem.play("quake")
			for i in 6:
				var pos := p.global_position + Vector2(_rng.randf_range(-140, 140), _rng.randf_range(-90, 60))
				Effects.dust(level.entities, pos - level.entities.global_position, 6)


func _footsteps(p: Player) -> void:
	var pos := _behind_player(60.0)
	for i in _rng.randi_range(3, 6):
		if not is_inside_tree():
			return
		AudioSystem.play_at("step", pos, 0.8, 4.0)
		pos += (p.global_position - pos).normalized() * 6.0
		await get_tree().create_timer(0.42).timeout


func _knocks(pos: Vector2) -> void:
	for i in 3:
		if not is_inside_tree():
			return
		AudioSystem.play_at("knock", pos)
		await get_tree().create_timer(0.55 if i < 2 else 0.0).timeout


func _blackout(l: FlickerLight, dur: float) -> void:
	l.broken = true
	await get_tree().create_timer(dur).timeout
	if is_instance_valid(l) and not level.layout.get("lamps_off", false):
		l.broken = false


func _spawn_shadow(p: Player) -> void:
	# aparece na borda da escuridão, num chão livre, e some quando você chega perto
	for attempt in 12:
		var ang := _rng.randf() * TAU
		var pos := p.global_position + Vector2.from_angle(ang) * _rng.randf_range(95.0, 130.0)
		var cell := level.world_to_cell(pos)
		if level.floor_layer.get_cell_source_id(cell) != -1 and level.wall_layer.get_cell_source_id(cell) == -1:
			_shadow.global_position = level.cell_pos(cell)
			_shadow.modulate = Color(0, 0, 0, 0.0)
			_shadow.visible = true
			_shadow_t = _rng.randf_range(2.5, 4.0)
			create_tween().tween_property(_shadow, "modulate:a", 0.85, 0.6)
			AudioSystem.play_at("whisper", _shadow.global_position, 0.7, -6.0)
			return


func _update_shadow(delta: float) -> void:
	if not _shadow.visible:
		return
	_shadow_t -= delta
	var d := _shadow.global_position.distance_to(level.player.global_position)
	if _shadow_t <= 0.0 or d < 70.0:
		_shadow.visible = false
		if d < 70.0:
			AudioSystem.play("stinger_soft", 1.0, -8.0)
