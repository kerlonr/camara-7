class_name GeigerGauge
extends Control
## Contador Geiger analógico: ponteiro em escala logarítmica de CPS (fictícia),
## LED que pisca com os cliques. Com o dosímetro, mostra valores numéricos.

const MIN_CPS := 0.3
const MAX_CPS := 120.0
const A0 := 3.5779249  # 205°
const A1 := 5.8468530  # 335°

var _needle := 0.0
var _led := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	custom_minimum_size = Vector2(72, 40)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()


func _process(delta: float) -> void:
	var cps := RadiationSystem.cps() if RadiationSystem.active else 0.0
	var k := clampf(log(maxf(cps, MIN_CPS) / MIN_CPS) / log(MAX_CPS / MIN_CPS), 0.0, 1.0)
	k += _rng.randf_range(-0.02, 0.02) * (0.3 + k)
	_needle = lerpf(_needle, k, clampf(delta * 6.0, 0.0, 1.0))
	if _rng.randf() < cps * delta:
		_led = 1.0
	_led = maxf(0.0, _led - delta * 12.0)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color("#0c0d09"))
	draw_rect(r.grow(-1), Color("#c9c2a4"))
	var c := Vector2(size.x / 2.0, size.y - 6)
	var rad := size.y - 12.0
	# zonas
	for i in 24:
		var t0 := float(i) / 24.0
		var t1 := float(i + 1) / 24.0
		var col := Color("#3f7a45") if t0 < 0.5 else (Color("#c99a2e") if t0 < 0.78 else Color("#b8402e"))
		draw_arc(c, rad - 2, lerpf(A0, A1, t0), lerpf(A0, A1, t1), 3, col, 2.0)
	for i in 7:
		var a := lerpf(A0, A1, float(i) / 6.0)
		draw_line(c + Vector2.from_angle(a) * (rad - 5), c + Vector2.from_angle(a) * (rad + 0), Color("#1a1a14"), 1.0)
	var na := lerpf(A0, A1, _needle)
	draw_line(c, c + Vector2.from_angle(na) * (rad - 1), Color("#1a1a14"), 1.0)
	draw_circle(c, 2.0, Color("#1a1a14"))
	# LED
	var led_c := Color("#ff5a40").lerp(Color("#3a120c"), 1.0 - _led)
	draw_rect(Rect2(size.x - 7, 3, 4, 3), led_c)
	var f := UITheme.font()
	draw_string(f, Vector2(3, 9), "мР/ч", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#3a3a2e"))
	if int(UpgradeSystem.get_stat("dosimeter", 0)) > 0:
		var txt := "%.1f%%/min" % (RadiationSystem.rate * 60.0)
		draw_string(f, Vector2(3, size.y - 1), txt, HORIZONTAL_ALIGNMENT_LEFT, size.x - 4, 10, Color("#1a3a1c"))
