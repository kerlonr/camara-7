class_name AmbientFX
extends Node2D
## Efeitos de ambiente reutilizáveis (partículas + som), criados a partir de dados:
## steam (vapor), fire (fogo), sparks (faíscas), motes (partículas radioativas),
## smoke (fumaça), drip (gotejamento da parede), ash (cinza caindo na superfície).

const PIXEL := "res://assets/effects/pixel.png"
const PUFF := "res://assets/effects/puff.png"

var kind := ""
var _emitter: CPUParticles2D
var _timer := 0.0
var _rng := RandomNumberGenerator.new()


static func create(p_kind: String) -> AmbientFX:
	var fx := AmbientFX.new()
	fx.kind = p_kind
	fx.name = "FX_" + p_kind
	return fx


func _ready() -> void:
	_rng.randomize()
	_timer = _rng.randf_range(0.5, 4.0)
	_emitter = CPUParticles2D.new()
	_emitter.z_index = 6
	add_child(_emitter)
	var e := _emitter
	match kind:
		"steam":
			e.texture = DataManager.texture(PUFF)
			e.amount = 14
			e.lifetime = 2.2
			e.direction = Vector2(0, -1)
			e.spread = 18.0
			e.gravity = Vector2(3, -8)
			e.initial_velocity_min = 8.0
			e.initial_velocity_max = 16.0
			e.scale_amount_min = 0.5
			e.scale_amount_max = 1.4
			e.color = Color(0.85, 0.88, 0.85, 0.28)
			e.color_ramp = _fade_ramp()
			e.position = Vector2(0, -4)
			e.emitting = false
		"fire":
			e.texture = DataManager.texture(PIXEL)
			e.amount = 26
			e.lifetime = 0.7
			e.direction = Vector2(0, -1)
			e.spread = 25.0
			e.gravity = Vector2(0, -30)
			e.initial_velocity_min = 6.0
			e.initial_velocity_max = 18.0
			e.scale_amount_min = 0.5
			e.scale_amount_max = 1.5
			e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			e.emission_rect_extents = Vector2(4, 1)
			e.position = Vector2(0, -13)
			var g := Gradient.new()
			g.set_color(0, Color(1.0, 0.9, 0.5, 1.0))
			g.set_color(1, Color(0.6, 0.15, 0.05, 0.0))
			g.add_point(0.4, Color(1.0, 0.5, 0.15, 0.9))
			e.color_ramp = g
			e.emitting = true
			var smoke := CPUParticles2D.new()
			smoke.texture = DataManager.texture(PUFF)
			smoke.amount = 8
			smoke.lifetime = 3.0
			smoke.direction = Vector2(0.2, -1)
			smoke.spread = 12.0
			smoke.gravity = Vector2(5, -5)
			smoke.initial_velocity_min = 6.0
			smoke.initial_velocity_max = 12.0
			smoke.scale_amount_min = 0.6
			smoke.scale_amount_max = 1.8
			smoke.color = Color(0.2, 0.19, 0.17, 0.35)
			smoke.color_ramp = _fade_ramp()
			smoke.position = Vector2(0, -18)
			add_child(smoke)
		"sparks":
			e.texture = DataManager.texture(PIXEL)
			e.amount = 8
			e.lifetime = 0.45
			e.one_shot = true
			e.explosiveness = 0.9
			e.direction = Vector2(0, 1)
			e.spread = 70.0
			e.gravity = Vector2(0, 260)
			e.initial_velocity_min = 25.0
			e.initial_velocity_max = 60.0
			e.scale_amount_min = 0.5
			e.scale_amount_max = 0.5
			e.color = Color("#ffe08a")
			e.position = Vector2(0, -8)
			e.emitting = false
		"motes":
			e.texture = DataManager.texture(PIXEL)
			e.amount = 6
			e.lifetime = 2.6
			e.direction = Vector2(0, -1)
			e.spread = 30.0
			e.gravity = Vector2(0, -4)
			e.initial_velocity_min = 3.0
			e.initial_velocity_max = 8.0
			e.scale_amount_min = 0.5
			e.scale_amount_max = 0.5
			e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			e.emission_rect_extents = Vector2(6, 2)
			e.color = Color(0.6, 1.0, 0.45, 0.8)
			e.color_ramp = _fade_ramp()
			e.position = Vector2(0, -4)
			e.emitting = true
		"drip":
			e.texture = DataManager.texture(PIXEL)
			e.amount = 1
			e.lifetime = 0.5
			e.one_shot = true
			e.direction = Vector2(0, 1)
			e.spread = 0.0
			e.gravity = Vector2(0, 220)
			e.initial_velocity_min = 0.0
			e.initial_velocity_max = 0.0
			e.scale_amount_min = 0.5
			e.scale_amount_max = 0.5
			e.color = Color(0.55, 0.7, 0.72, 0.85)
			e.emitting = false


static func _fade_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.25, Color(1, 1, 1, 1.0))
	return g


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	match kind:
		"steam":
			# rajadas de vapor com chiado
			_emitter.emitting = not _emitter.emitting
			_timer = _rng.randf_range(1.5, 3.5) if _emitter.emitting else _rng.randf_range(3.0, 8.0)
			if _emitter.emitting and _near_player(180.0):
				AudioSystem.play_at("steam_burst", global_position, 1.0, -4.0)
		"sparks":
			_timer = _rng.randf_range(4.0, 14.0)
			if _near_player(200.0):
				_emitter.restart()
				_emitter.emitting = true
				AudioSystem.play_at("spark", global_position)
		"drip":
			_timer = _rng.randf_range(2.5, 9.0)
			if _near_player(170.0):
				_emitter.restart()
				_emitter.emitting = true
				_splash_later()


func _splash_later() -> void:
	await get_tree().create_timer(0.38).timeout
	if not is_inside_tree():
		return
	var p := global_position + Vector2(0, 17)
	Effects.burst(get_parent(), position + Vector2(0, 17), Color(0.55, 0.7, 0.72, 0.8), 3, 18.0, 0.25, 120.0, 200.0)
	AudioSystem.play_at("drip", p, 1.0, -6.0)


func _near_player(dist: float) -> bool:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	return p != null and p.global_position.distance_to(global_position) < dist
