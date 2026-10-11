class_name StatBar
extends Control
## Barra segmentada estilo painel de LED. Pisca quando o valor está crítico.

var value := 1.0             # 0..1
var color := Color("#c8402e")
var critical_below := 0.2
var critical_above := 2.0    # para exposição (pisca acima)
var _t := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(72, 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_value(v: float) -> void:
	value = clampf(v, 0.0, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if value < critical_below or value > critical_above:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color("#0c0d09"))
	draw_rect(r.grow(-1), Color("#1b1d15"))
	var seg_w := 3.0
	var gap := 1.0
	var inner := r.grow(-1)
	var n := int((inner.size.x + gap) / (seg_w + gap))
	var lit := int(round(value * n))
	var blink := (value < critical_below or value > critical_above) and fmod(_t, 0.5) < 0.25
	for i in n:
		var x := inner.position.x + i * (seg_w + gap)
		var c := color if i < lit else Color(color, 0.12)
		if i < lit and blink:
			c = c.lightened(0.45)
		draw_rect(Rect2(x, inner.position.y, seg_w, inner.size.y), c)
