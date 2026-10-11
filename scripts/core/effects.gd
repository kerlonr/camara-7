class_name Effects
extends RefCounted
## Efeitos de feedback reutilizáveis: partículas, hit-stop, texto flutuante.

const PIXEL := "res://assets/effects/pixel.png"

static var _hitstop_active := false
static var _ramp: Gradient


static func burst(parent: Node, pos: Vector2, color: Color, amount: int = 6, speed: float = 70.0,
		lifetime: float = 0.55, spread: float = 80.0, gravity: float = 300.0) -> void:
	if parent == null:
		return
	var p := CPUParticles2D.new()
	p.texture = DataManager.texture(PIXEL)
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = maxi(1, amount)
	p.lifetime = lifetime
	p.direction = Vector2(0, -1)
	p.spread = spread
	p.initial_velocity_min = speed * 0.45
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	p.color = color
	if _ramp == null:
		_ramp = Gradient.new()
		_ramp.set_color(0, Color(1, 1, 1, 1))
		_ramp.set_color(1, Color(1, 1, 1, 0))
		_ramp.add_point(0.7, Color(1, 1, 1, 1))
	p.color_ramp = _ramp
	p.position = pos
	p.z_index = 5
	p.emitting = false
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func dust(parent: Node, pos: Vector2, amount: int = 8) -> void:
	burst(parent, pos, Color(0.55, 0.52, 0.46, 0.7), amount, 28.0, 0.9, 180.0, -12.0)


static func sparks(parent: Node, pos: Vector2) -> void:
	burst(parent, pos, Color("#ffd27a"), 5, 110.0, 0.25, 120.0, 200.0)


## Congela o jogo por um instante (sensação de impacto).
static func hitstop(tree: SceneTree, duration: float = 0.04) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = 0.05
	await tree.create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


static func float_text(parent: Node, pos: Vector2, text: String, color: Color = Color.WHITE, size: int = 12) -> void:
	if parent == null:
		return
	var l := Label.new()
	l.theme = UITheme.get_theme()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Color("#0b0a07"))
	l.position = pos + Vector2(-20, -10)
	l.size = Vector2(40, 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 20
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 14.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.25)
	tw.tween_callback(l.queue_free)


## Item que salta no chão (mesmo comportamento dos drops de rocha).
static func spawn_drop(parent: Node, pos: Vector2, item_id: String, amount: int = 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in amount:
		var p: Node2D = load("res://scenes/mining/pickup.tscn").instantiate()
		p.setup(item_id, 1, rng)
		p.position = pos + Vector2(0, -2)
		parent.add_child(p)
