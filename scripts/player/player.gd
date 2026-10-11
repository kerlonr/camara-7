class_name Player
extends CharacterBody2D
## Jogador: movimento, mira, ferramenta, arremesso (sinalizador/dinamite), interação,
## animação e lanterna em CONE (visão estilo Darkwood) + halo fraco em volta.
## Estado persistente (vida, energia, bateria, inventário) vive nos sistemas globais.

const SWING_WINDUP := 0.12
const SWING_STRIKE := 0.05
const SWING_RECOVER := 0.14
const HAND_OFFSET := {"down": Vector2(0, -12), "up": Vector2(0, -17), "side": Vector2(3, -13)}
const MOUSE_AIM_TIMEOUT := 3.0
const AIM_MAX_SNAP := 16.0
const CONE_TEXTURE := "res://assets/effects/light_cone.png"
const AURA_TEXTURE := "res://assets/effects/light_soft.png"
const THROW_SCENE := preload("res://scenes/mining/throwable.tscn")
const THROW_RANGE := 90.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var tool_pivot: Node2D = $ToolPivot
@onready var tool_sprite: Sprite2D = $ToolPivot/Tool
@onready var lantern: PointLight2D = $Lantern
@onready var camera: Camera2D = $Camera
@onready var interact_area: Area2D = $InteractArea
@onready var drill_audio: AudioStreamPlayer2D = $DrillAudio
@onready var marker: Node2D = $TargetMarker

var area: GameArea
var facing := Vector2.DOWN
var input_enabled := true

var _aura: PointLight2D
var _cone_angle := PI / 2.0
var _cooldown := 0.0
var _swing_t := -1.0
var _swing_hit_done := false
var _drilling := false
var _target: Node2D = null
var _interactable: Interactable = null
var _step_t := 0.0
var _shake_t := 0.0
var _shake_str := 0.0
var _suit := -1
var _mouse_moved_at := -100.0
var _clock := 0.0
var _weak_warned_at := -10.0
var _sprite_h := 32
var _rng := RandomNumberGenerator.new()
var _knock := Vector2.ZERO


func _ready() -> void:
	add_to_group("player")
	_rng.randomize()
	RadiationSystem.player = self
	EventBus.stats_changed.connect(_apply_stats)
	EventBus.camera_shake.connect(_on_shake)
	var fs: Array = DataManager.player.get("sprites", {}).get("frame_size", [16, 32])
	_sprite_h = int(fs[1])
	# cone da lanterna: textura com o vértice no centro, apontando para a direita
	lantern.texture = DataManager.texture(CONE_TEXTURE)
	lantern.position = Vector2(0, -12)
	lantern.shadow_enabled = DataManager.atmosphere.get("mine", {}).get("player_light_shadows", true)
	lantern.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	lantern.shadow_filter_smooth = 1.5
	_aura = PointLight2D.new()
	_aura.texture = DataManager.texture(AURA_TEXTURE)
	_aura.position = Vector2(0, -10)
	_aura.texture_scale = 0.55
	_aura.energy = 0.0
	add_child(_aura)
	drill_audio.stream = AudioSystem.loop_stream("drill")
	drill_audio.volume_db = AudioSystem.loop_volume("drill")
	drill_audio.bus = "SFX"
	_apply_stats()
	_update_anim(Vector2.ZERO, false)
	EventBus.interact_prompt_changed.emit("")


func set_input_enabled(on: bool) -> void:
	input_enabled = on
	if not on:
		velocity = Vector2.ZERO
		_stop_drill()


func set_camera_limits(r: Rect2i) -> void:
	if camera == null:
		await ready
	camera.limit_left = r.position.x
	camera.limit_top = r.position.y
	camera.limit_right = r.end.x
	camera.limit_bottom = r.end.y
	camera.reset_smoothing()


func _apply_stats() -> void:
	var suit := int(UpgradeSystem.get_stat("suit", 1))
	if suit != _suit:
		_suit = suit
		var sp: Dictionary = DataManager.player.get("sprites", {})
		var sheets: Dictionary = sp.get("suits", {})
		var fs: Array = sp.get("frame_size", [16, 32])
		var anim := sprite.animation
		sprite.sprite_frames = PlayerFrames.build(sheets.get(str(suit), sheets.get("1", "")), Vector2i(int(fs[0]), int(fs[1])))
		if sprite.sprite_frames.has_animation(anim):
			sprite.play(anim)
	tool_sprite.texture = DataManager.texture(UpgradeSystem.get_stat("tool_sprite", ""))
	var drill_mode := _tool_mode() == "drill"
	tool_sprite.offset = Vector2(-8, -2) if drill_mode else Vector2(-2, -13)
	var c := Color(UpgradeSystem.get_stat("light_color", "#ffc98a"))
	lantern.color = c
	_aura.color = c
	lantern.texture_scale = 1.15 * float(UpgradeSystem.get_stat("light_scale", 1.0))


func _tool_mode() -> String:
	return String(UpgradeSystem.get_stat("tool_mode", "swing"))


func _reach() -> float:
	return float(UpgradeSystem.get_stat("tool_reach", 22.0))


# ------------------------------------------------------------------ loop
func _physics_process(delta: float) -> void:
	_clock += delta
	_cooldown -= delta
	var dir := Vector2.ZERO
	if input_enabled:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var running := input_enabled and Input.is_action_pressed("run")
	var speed := float(UpgradeSystem.get_stat("run_speed" if running else "move_speed", 62.0))
	if area and area.is_slow_at(global_position):
		speed *= 0.6
	if _swing_t >= 0.0:
		speed *= 0.35
	if _drilling:
		speed *= 0.3
	velocity = dir * speed + _knock
	_knock = _knock.move_toward(Vector2.ZERO, delta * 420.0)
	move_and_slide()
	if dir != Vector2.ZERO and _swing_t < 0.0 and not _drilling:
		facing = _snap(dir)
	_update_target()
	_handle_tool(delta)
	_update_anim(dir, running)
	_update_tool_visual()
	_footsteps(dir, running, delta)
	_update_interact()
	_update_lantern(delta)
	_camera_shake(delta)
	GameState.player_position = global_position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_moved_at = _clock
	if not input_enabled:
		return
	for i in InventorySystem.HOTBAR_SIZE:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			InventorySystem.select(i)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			InventorySystem.select(wrapi(InventorySystem.selected - 1, 0, InventorySystem.HOTBAR_SIZE))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			InventorySystem.select(wrapi(InventorySystem.selected + 1, 0, InventorySystem.HOTBAR_SIZE))
	if event.is_action_pressed("lantern"):
		GameState.lantern_on = not GameState.lantern_on
		AudioSystem.play("battery", 1.6 if GameState.lantern_on else 1.2, -4.0)
		EventBus.caption.emit("[clique da lanterna]" if GameState.lantern_on else "[lanterna desligada — escuro]")
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("interact") and _interactable and is_instance_valid(_interactable):
		_interactable.interact()
		get_viewport().set_input_as_handled()


func _snap(v: Vector2) -> Vector2:
	if absf(v.x) > absf(v.y):
		return Vector2(signf(v.x), 0)
	return Vector2(0, signf(v.y))


func _dir_name() -> String:
	if facing.y < 0:
		return "up"
	if facing.y > 0:
		return "down"
	return "side"


func _origin() -> Vector2:
	return global_position + Vector2(0, -7)


func _mouse_aim() -> bool:
	return _clock - _mouse_moved_at < MOUSE_AIM_TIMEOUT


## Posição na tela (útil para o HUD esmaecer quando o jogador passa por trás).
func screen_position() -> Vector2:
	return get_global_transform_with_canvas().origin + Vector2(0, -12)


# ------------------------------------------------------------------ mira
func _update_target() -> void:
	var origin := _origin()
	var aim: Vector2
	if _mouse_aim():
		aim = origin + (get_global_mouse_position() - origin).limit_length(_reach())
	else:
		aim = origin + facing * 14.0
	var best: Node2D = null
	var best_d := AIM_MAX_SNAP
	var reach_sq := (_reach() + 10.0) * (_reach() + 10.0)
	for body in get_tree().get_nodes_in_group("mineable"):
		if body.broken or body.global_position.distance_squared_to(global_position) > reach_sq * 2.0:
			continue
		var c: Vector2 = body.hit_center()
		if c.distance_to(origin) > _reach() + 10.0:
			continue
		var d := c.distance_to(aim)
		if d < best_d:
			best_d = d
			best = body
	_target = best
	var sel = InventorySystem.selected_item()
	marker.target = _target if (sel != null and sel.id == "pickaxe") else null


# ------------------------------------------------------------------ ferramenta / arremesso
func _handle_tool(delta: float) -> void:
	var sel = InventorySystem.selected_item()
	var holding_tool: bool = sel != null and sel.id == "pickaxe"
	var pressed := input_enabled and Input.is_action_pressed("use_tool")
	if input_enabled and Input.is_action_just_pressed("use_tool") and sel != null and not holding_tool:
		var use: Dictionary = DataManager.get_item(sel.id).get("use", {})
		if use.has("throw"):
			_throw(String(use.throw))
		else:
			InventorySystem.use_slot(InventorySystem.selected)
		return
	if _tool_mode() == "drill":
		if pressed and holding_tool:
			_face_aim()
			if not _drilling:
				_drilling = true
				drill_audio.play()
			if _cooldown <= 0.0:
				_cooldown = float(UpgradeSystem.get_stat("tool_cooldown", 0.12))
				_strike()
		else:
			_stop_drill()
		return
	if _swing_t >= 0.0:
		_swing_t += delta
		if not _swing_hit_done and _swing_t >= SWING_WINDUP:
			_swing_hit_done = true
			_strike()
		if _swing_t >= SWING_WINDUP + SWING_STRIKE + SWING_RECOVER:
			_swing_t = -1.0
	elif pressed and holding_tool and _cooldown <= 0.0:
		_face_aim()
		_cooldown = float(UpgradeSystem.get_stat("tool_cooldown", 0.5))
		_swing_t = 0.0
		_swing_hit_done = false
		AudioSystem.play("swing")


func _throw(kind: String) -> void:
	if _cooldown > 0.0 or area == null:
		return
	_cooldown = 0.5
	var origin := _origin()
	var target := origin + (get_global_mouse_position() - origin).limit_length(THROW_RANGE) if _mouse_aim() \
		else origin + facing * 48.0
	facing = _snap(target - origin)
	var t: Node2D = THROW_SCENE.instantiate()
	t.setup(kind, origin, target)
	area.entities.add_child(t)
	InventorySystem.remove_from_slot(InventorySystem.selected, 1)
	AudioSystem.play("swing", 0.8)


func _stop_drill() -> void:
	if _drilling:
		_drilling = false
		drill_audio.stop()


func _face_aim() -> void:
	if _target and is_instance_valid(_target):
		facing = _snap(_target.hit_center() - _origin())
	elif _mouse_aim():
		facing = _snap(get_global_mouse_position() - _origin())


func _strike() -> void:
	var cost := float(UpgradeSystem.get_stat("tool_energy_cost", 1.0))
	var had_energy := HealthSystem.spend_energy(cost)
	if _target == null or not is_instance_valid(_target) or _target.broken:
		return
	var power := float(UpgradeSystem.get_stat("tool_power", 1.0))
	if not had_energy:
		power *= float(DataManager.player.get("vitals", {}).get("energy_exhausted_damage_mult", 0.5))
	var result: String = _target.hit(power, int(UpgradeSystem.get_stat("tool_tier", 1)), facing)
	if result == "fail" and _clock - _weak_warned_at > 3.0:
		_weak_warned_at = _clock
		EventBus.toast.emit("Ferramenta fraca demais para %s." % _target.display_name(), "warn")


# ------------------------------------------------------------------ visual
func _update_anim(dir: Vector2, running: bool) -> void:
	var dn := _dir_name()
	sprite.flip_h = facing.x < 0
	sprite.offset = Vector2(0, -_sprite_h / 2.0)
	if _swing_t >= 0.0:
		_set_anim("swing_" + dn)
		sprite.frame = 0 if _swing_t < SWING_WINDUP else 1
	elif _drilling:
		_set_anim("swing_" + dn)
		sprite.frame = 1
		sprite.offset += Vector2(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.4, 0.4))
	elif dir != Vector2.ZERO:
		_set_anim("walk_" + dn)
		sprite.speed_scale = 1.6 if running else 1.0
	else:
		_set_anim("idle_" + dn)


func _set_anim(anim: String) -> void:
	if sprite.animation != anim:
		sprite.play(anim)
	if anim.begins_with("swing"):
		sprite.pause()
	elif not sprite.is_playing():
		sprite.play(anim)


func _update_tool_visual() -> void:
	var dn := _dir_name()
	var swinging := _swing_t >= 0.0
	tool_pivot.visible = swinging or _drilling
	if not tool_pivot.visible:
		return
	tool_pivot.position = HAND_OFFSET[dn]
	tool_pivot.show_behind_parent = dn == "up"
	var face_angle := Vector2.RIGHT.angle() if dn == "side" else facing.angle()
	var left := facing.x < 0
	var rot: float
	if _drilling:
		rot = face_angle - PI / 2.0
		tool_pivot.position += Vector2(_rng.randf_range(-0.7, 0.7), _rng.randf_range(-0.7, 0.7))
	else:
		var strike_rot := face_angle + PI / 4.0
		var raise_rot := strike_rot - deg_to_rad(150.0)
		if _swing_t < SWING_WINDUP:
			rot = lerpf(raise_rot + deg_to_rad(40.0), raise_rot, ease(_swing_t / SWING_WINDUP, 0.4))
		elif _swing_t < SWING_WINDUP + SWING_STRIKE:
			rot = lerpf(raise_rot, strike_rot, (_swing_t - SWING_WINDUP) / SWING_STRIKE)
		else:
			rot = strike_rot
	if left:
		tool_pivot.scale.x = -1.0
		tool_pivot.rotation = -rot
	else:
		tool_pivot.scale.x = 1.0
		tool_pivot.rotation = rot


func _footsteps(dir: Vector2, running: bool, delta: float) -> void:
	if dir == Vector2.ZERO:
		_step_t = 0.0
		return
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = 0.24 if running else 0.34
		AudioSystem.play("step")


## Lanterna: o cone segue a mira; força depende do ambiente (mina/noite) e da bateria.
func _update_lantern(delta: float) -> void:
	var env := area.lantern_factor() if area else 1.0
	var bat := HealthSystem.battery
	var bat_k := 1.0 if bat > 20.0 else (0.35 + 0.65 * bat / 20.0 if bat > 0.0 else 0.0)
	var flick := 1.0
	if bat > 0.0 and bat < 20.0 and _rng.randf() < 0.08:
		flick = _rng.randf_range(0.2, 0.7)
	var e := float(UpgradeSystem.get_stat("light_energy", 1.0)) * env * (1.0 if GameState.lantern_on else 0.0)
	lantern.energy = move_toward(lantern.energy, e * bat_k * flick, delta * 4.0)
	lantern.visible = lantern.energy > 0.01
	# halo fraco: sem bateria vira só o brilho do visor
	_aura.energy = move_toward(_aura.energy, env * (0.6 if bat > 0.0 else 0.35), delta * 2.0)
	_aura.texture_scale = 0.7 if bat > 0.0 else 0.45
	_aura.visible = _aura.energy > 0.01
	var aim_angle := facing.angle()
	if _mouse_aim():
		aim_angle = (get_global_mouse_position() - (global_position + lantern.position)).angle()
	_cone_angle = lerp_angle(_cone_angle, aim_angle, clampf(delta * 12.0, 0.0, 1.0))
	lantern.rotation = _cone_angle


## Lanterna ligada e com bateria (o cone existe)?
func lantern_on() -> bool:
	return GameState.lantern_on and HealthSystem.battery > 0.0 and lantern.energy > 0.15


## O ponto está dentro do cone da lanterna (alcance e ângulo aproximados da textura)?
func point_in_cone(pos: Vector2) -> bool:
	var origin := global_position + lantern.position
	var v := pos - origin
	var reach := 128.0 * lantern.texture_scale * 0.85
	if v.length() > reach or v.length() < 2.0:
		return v.length() < 10.0
	return absf(wrapf(v.angle() - _cone_angle, -PI, PI)) < deg_to_rad(30.0)


func knockback(v: Vector2) -> void:
	_knock = v


# ------------------------------------------------------------------ interação
func _update_interact() -> void:
	interact_area.position = facing * 8.0 + Vector2(0, -6)
	var best: Interactable = null
	var best_d := INF
	if input_enabled:
		var probe := global_position + facing * 10.0
		for a in interact_area.get_overlapping_areas():
			if a is Interactable:
				var d: float = a.global_position.distance_to(probe)
				if d < best_d:
					best_d = d
					best = a
	if best != _interactable:
		_interactable = best
		EventBus.interact_prompt_changed.emit("[E] " + best.get_prompt() if best else "")


func refresh_prompt() -> void:
	if _interactable and is_instance_valid(_interactable):
		EventBus.interact_prompt_changed.emit("[E] " + _interactable.get_prompt())


# ------------------------------------------------------------------ câmera
func _on_shake(strength: float, duration: float) -> void:
	if not Settings.get_v("screen_shake"):
		return
	_shake_str = maxf(_shake_str, strength)
	_shake_t = maxf(_shake_t, duration)


func _camera_shake(delta: float) -> void:
	if _shake_t > 0.0:
		_shake_t -= delta
		camera.offset = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _shake_str
	else:
		_shake_str = 0.0
		camera.offset = Vector2.ZERO


func _draw() -> void:
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.35))
