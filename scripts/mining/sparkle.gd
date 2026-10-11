class_name Sparkle
extends Node2D
## Brilho intermitente de veio rico: pequenas cruzes que piscam em volta da rocha.

var _t := 0.0
var _pts: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	z_index = 2
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	for i in 3:
		_pts.append({"pos": Vector2(_rng.randf_range(-5, 5), _rng.randf_range(-4, 3)), "phase": _rng.randf() * TAU})


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	for p in _pts:
		var a := maxf(0.0, sin(_t * 3.0 + p.phase))
		if a < 0.3:
			continue
		var c := Color(1.0, 0.95, 0.7, a)
		var pos: Vector2 = p.pos.round()
		draw_rect(Rect2(pos, Vector2(1, 1)), c)
		if a > 0.8:
			draw_rect(Rect2(pos + Vector2(-1, 0), Vector2(3, 1)), Color(c, a * 0.6))
			draw_rect(Rect2(pos + Vector2(0, -1), Vector2(1, 3)), Color(c, a * 0.6))
