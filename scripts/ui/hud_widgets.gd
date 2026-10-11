class_name HudWidgets
extends RefCounted
## Instrumentos "de verdade" do HUD: relógio de pulso, bateria da lanterna e barra de XP.


# =================================================================== RELÓGIO DE PULSO
class WristWatch extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(30, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 1.0
		draw_circle(c, r + 1, Color("#0c0d09"))
		draw_circle(c, r, Color("#3a3d33"))
		draw_circle(c, r - 2, Color("#d8d2b8"))
		for i in 12:
			var a := i / 12.0 * TAU
			var p0 := c + Vector2.from_angle(a) * (r - 3)
			var p1 := c + Vector2.from_angle(a) * (r - (5 if i % 3 == 0 else 4))
			draw_line(p0, p1, Color("#2a2a24"), 1.0)
		var m := TimeSystem.clock_minute()
		var ha := (m / 60.0) / 12.0 * TAU - PI / 2.0
		var ma := (m % 60) / 60.0 * TAU - PI / 2.0
		draw_line(c, c + Vector2.from_angle(ha) * (r * 0.45), Color("#15130e"), 2.0)
		draw_line(c, c + Vector2.from_angle(ma) * (r * 0.72), Color("#15130e"), 1.0)
		draw_circle(c, 1.5, Color("#a8322a"))


# =================================================================== BATERIA
class BatteryMeter extends Control:
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(12, 33)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y - 7
		# lâmpada da lanterna (acesa/apagada — tecla F)
		var on := GameState.lantern_on and HealthSystem.battery > 0.0
		draw_rect(Rect2(3, 0, w - 6, 5), Color("#0c0d09"))
		draw_rect(Rect2(4, 1, w - 8, 3), Color("#ffd27a") if on else Color("#2a2a22"))
		if on:
			draw_rect(Rect2(4, 1, 1, 1), Color("#fff6d8"))
		draw_set_transform(Vector2(0, 7))
		draw_rect(Rect2(3, 0, w - 6, 2), Color("#5a5f4a"))
		draw_rect(Rect2(0, 2, w, h - 2), Color("#0c0d09"))
		draw_rect(Rect2(1, 3, w - 2, h - 4), Color("#1d1f17"))
		var b := HealthSystem.battery
		var cells := 4
		var lit := ceili(b / 25.0)
		var ch := (h - 6) / float(cells)
		for i in cells:
			var y := h - 2 - (i + 1) * ch
			var col := Color("#8fe854") if b > 50 else (Color("#e0b54a") if b > 20 else Color("#e0604a"))
			if i >= lit:
				col = Color(col, 0.1)
			elif b <= 20 and fmod(_t, 0.6) < 0.3:
				col = col.darkened(0.6)
			draw_rect(Rect2(2, y + 1, w - 4, ch - 1), col)


# =================================================================== DOSÍMETRO DE CANETA
## Dosímetro de leitura direta (tipo DKP-50, usado pelos liquidantes): escala 0–50 R e um fio
## de quartzo que avança com a dose acumulada. 50 R = 100% de exposição (desmaio).
class PenDosimeter extends Control:
	var _shown := 0.0
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(62, 11)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(d: float) -> void:
		_t += d
		_shown = lerpf(_shown, clampf(RadiationSystem.exposure / 100.0, 0.0, 1.0), clampf(d * 4.0, 0.0, 1.0))
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		# corpo metálico com presilha
		draw_rect(Rect2(0, 2, w - 4, 7), Color("#0c0d09"))
		draw_rect(Rect2(1, 3, w - 6, 5), Color("#5a5f52"))
		draw_rect(Rect2(1, 3, w - 6, 1), Color("#8a8f80"))
		draw_rect(Rect2(w - 5, 3, 4, 5), Color("#3a3d34"))            # tampa
		draw_rect(Rect2(6, 0, 18, 2), Color("#3a3d34"))               # clipe
		# janela da escala
		var x0 := 4.0
		var x1 := w - 9.0
		draw_rect(Rect2(x0, 4, x1 - x0, 3), Color("#d8d2b0"))
		for i in 6:
			var x := roundf(lerpf(x0, x1 - 1, i / 5.0))
			draw_rect(Rect2(x, 4, 1, 1 if i % 5 else 2), Color("#3a3a2e"))
		for mark in [[0.5, Color("#c99a2e")], [0.75, Color("#b8402e")]]:   # limites do jogo
			draw_rect(Rect2(roundf(lerpf(x0, x1 - 1, mark[0])), 6, 1, 1), mark[1])
		var hx := roundf(lerpf(x0, x1 - 1, _shown))
		var col := Color("#1a1a14")
		if _shown >= 0.75 and fmod(_t, 0.5) < 0.25:
			col = Color("#b8402e")
		draw_rect(Rect2(hx, 3, 1, 5), col)                            # fio de quartzo


# =================================================================== XP
class XpBar extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(120, 3)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var k := float(ProgressionSystem.xp) / maxf(1.0, ProgressionSystem.xp_to_next())
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0c0d09"))
		draw_rect(Rect2(Vector2(1, 1), Vector2((size.x - 2) * k, size.y - 2)), Color("#d2a533"))
