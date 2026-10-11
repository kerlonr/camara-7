class_name RadioPanel
extends GamePanel
## Rádio de ondas curtas soviético (estilizado). Tamanho FIXO; os controles são
## desenhados e não mudam de lugar. Sintonize girando o botão (arrastar / roda do
## mouse) ou com ← → / A D. Cada transmissão fica numa frequência; o resto é estática.

const RADIO_SIZE := Vector2(340, 200)
const F_MIN := 6.0
const F_MAX := 16.0
const LOCK := 0.18          # MHz de tolerância para "pegar" a estação

var freq := 9.4
var volume := 0.8
var _set: RadioSet
var _paper: Label
var _tag: Label
var _station: Dictionary = {}
var _lines_shown := 0
var _line_t := 0.0
var _static: AudioStreamPlayer
var _tone: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	panel_name = "radio"
	dim_alpha = 0.55


func _build() -> void:
	_rng.randomize()
	box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_set = RadioSet.new()
	_set.panel = self
	_set.custom_minimum_size = RADIO_SIZE
	content.add_child(_set)
	# tira de papel com a transcrição (posição fixa sobre o aparelho)
	_tag = UITheme.label("", 10, Color("#6a4a2a"))
	_tag.position = Vector2(150, 108)
	_tag.size = Vector2(176, 12)
	_tag.clip_text = true
	_set.add_child(_tag)
	_paper = UITheme.label("", 12, Color("#2a2418"))
	_paper.position = Vector2(150, 120)
	_paper.size = Vector2(176, 56)
	_paper.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_paper.clip_contents = true
	_paper.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_set.add_child(_paper)
	_static = AudioStreamPlayer.new()
	_static.bus = "UI"
	add_child(_static)
	_tone = AudioStreamPlayer.new()
	_tone.bus = "UI"
	add_child(_tone)


func open(_args: Dictionary) -> void:
	_static.stream = AudioSystem.loop_stream("radio_static")
	_static.volume_db = -60.0
	_static.play()
	AudioSystem.play("radio_burst")
	_retune()


func on_close() -> void:
	_static.stop()
	_tone.stop()


func stations() -> Array:
	return StorySystem.radio_stations()


func set_freq(f: float) -> void:
	var nf := clampf(f, F_MIN, F_MAX)
	if absf(nf - freq) < 0.0001:
		return
	freq = nf
	_retune()


func _retune() -> void:
	var best: Dictionary = {}
	var best_d := LOCK
	for s in stations():
		var d := absf(float(s.freq) - freq)
		if d <= best_d:
			best_d = d
			best = s
	if best.get("id", "") != _station.get("id", "x"):
		_station = best
		_lines_shown = 0
		_line_t = 0.6
		_paper.text = ""
		_tag.text = ("[ %s ]" % String(best.get("tag", "")).to_upper()) if best.has("tag") and best.tag != "" else ""
		if best.is_empty():
			_paper.text = "(chiado)"
			_tone.stop()
		else:
			_tone.stream = AudioSystem.loop_stream("radio_song" if best.get("repeat", false) else "radio_speech")
			_tone.volume_db = -60.0
			_tone.play()
	_set.signal_strength = 0.0 if best.is_empty() else 1.0 - best_d / LOCK
	_set.queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	var sig := _set.signal_strength
	_static.volume_db = linear_to_db(maxf(0.0001, volume * (1.0 - sig * 0.85) * 0.5))
	if _tone.playing:
		_tone.volume_db = linear_to_db(maxf(0.0001, volume * sig * sig * 0.8))
	if _station.is_empty():
		return
	var lines: Array = _station.get("lines", [])
	if _lines_shown < lines.size():
		_line_t -= delta
		if _line_t <= 0.0:
			_line_t = 1.8
			_paper.text = "\n".join(lines.slice(maxi(0, _lines_shown - 2), _lines_shown + 1))
			_lines_shown += 1
			AudioSystem.play("radio_tick", 1.0, -8.0)
			if _lines_shown >= lines.size():
				StorySystem.mark_radio_played(_station.id)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("move_left") or (event is InputEventKey and event.pressed and event.keycode == KEY_LEFT):
		set_freq(freq - 0.05)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right") or (event is InputEventKey and event.pressed and event.keycode == KEY_RIGHT):
		set_freq(freq + 0.05)
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------ o aparelho
class RadioSet extends Control:
	var panel: RadioPanel
	var signal_strength := 0.0
	var _drag := ""
	var _drag_y := 0.0
	const TUNE_C := Vector2(296, 72)
	const VOL_C := Vector2(296, 30)
	const POWER := Rect2(258, 182, 32, 12)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.position.distance_to(TUNE_C) < 16:
					_drag = "tune"
				elif mb.position.distance_to(VOL_C) < 10:
					_drag = "vol"
				elif POWER.has_point(mb.position):
					AudioSystem.play("ui_click")
					panel.close()
				elif Rect2(150, 22, 128, 44).has_point(mb.position):
					panel.set_freq(RadioPanel.F_MIN + (mb.position.x - 156) / 116.0 * (RadioPanel.F_MAX - RadioPanel.F_MIN))
				_drag_y = mb.position.y
				accept_event()
			elif not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_drag = ""
			elif mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				var dir := 1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
				if mb.position.distance_to(VOL_C) < 14:
					panel.volume = clampf(panel.volume + dir * 0.1, 0.0, 1.0)
				else:
					panel.set_freq(panel.freq + dir * 0.05)
				queue_redraw()
				accept_event()
		elif event is InputEventMouseMotion and _drag != "":
			var dy: float = (_drag_y - event.position.y) + event.relative.x
			_drag_y = event.position.y
			if _drag == "tune":
				panel.set_freq(panel.freq + dy * 0.02)
			else:
				panel.volume = clampf(panel.volume + dy * 0.01, 0.0, 1.0)
			queue_redraw()

	func _draw() -> void:
		var f := UITheme.font()
		# caixa de madeira
		draw_rect(Rect2(0, 0, size.x, size.y), Color("#1c120a"))
		draw_rect(Rect2(2, 2, size.x - 4, size.y - 4), Color("#5a3820"))
		for i in range(6, int(size.y) - 6, 5):
			var c := Color("#4e301b") if (i / 5) % 2 == 0 else Color("#64402a")
			draw_line(Vector2(4, i), Vector2(size.x - 4, i + sin(i * 0.3) * 1.5), c, 1.0)
		draw_rect(Rect2(2, 2, size.x - 4, 3), Color("#7a5434"))
		# grade do alto-falante (tecido)
		var g := Rect2(10, 12, 128, 176)
		draw_rect(g.grow(2), Color("#2a1a0e"))
		draw_rect(g, Color("#3e3424"))
		for x in range(int(g.position.x), int(g.end.x), 3):
			draw_line(Vector2(x, g.position.y), Vector2(x, g.end.y), Color("#4a4030"), 1.0)
		for y in range(int(g.position.y), int(g.end.y), 3):
			draw_line(Vector2(g.position.x, y), Vector2(g.end.x, y), Color("#352c1e"), 1.0)
		for k in 4:
			draw_rect(Rect2(g.position.x, g.position.y + 30 + k * 36, g.size.x, 2), Color("#6a4a2a"))
		draw_rect(Rect2(46, 168, 56, 12), Color("#c8b070"))
		draw_string(f, Vector2(52, 178), "ЗАЛIВ-7", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#3a2a1a"))
		# janela do dial
		var dial := Rect2(150, 22, 128, 44)
		draw_rect(dial.grow(2), Color("#2a1a0e"))
		draw_rect(dial, Color("#d9cba0"))
		draw_string(f, Vector2(154, 32), "КВ  МГц", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#5a4a2a"))
		for i in range(0, 11):
			var x := dial.position.x + 6 + i / 10.0 * 116.0
			draw_line(Vector2(x, dial.end.y - 14), Vector2(x, dial.end.y - (8 if i % 2 else 4)), Color("#3a2a1a"), 1.0)
			if i % 2 == 0:
				draw_string(f, Vector2(x - 4, dial.end.y - 16), str(6 + i), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#3a2a1a"))
		for s in panel.stations():
			var sx := dial.position.x + 6 + (float(s.freq) - RadioPanel.F_MIN) / (RadioPanel.F_MAX - RadioPanel.F_MIN) * 116.0
			draw_rect(Rect2(sx - 1, dial.end.y - 3, 2, 2), Color("#a8322a"))
		var nx := dial.position.x + 6 + (panel.freq - RadioPanel.F_MIN) / (RadioPanel.F_MAX - RadioPanel.F_MIN) * 116.0
		draw_line(Vector2(nx, dial.position.y + 2), Vector2(nx, dial.end.y - 2), Color("#c8301e"), 1.0)
		draw_string(f, Vector2(dial.end.x - 40, dial.position.y + 10), "%.2f" % panel.freq, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#5a4a2a"))
		# medidor de sinal (LEDs)
		for i in 6:
			var on := signal_strength * 6.0 > i
			draw_rect(Rect2(150 + i * 7, 74, 5, 4), Color("#8fe854") if on else Color("#2a3a20"))
		draw_string(f, Vector2(196, 79), "СИГНАЛ", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#d9cba0"))
		# tira de papel (transcrição)
		var paper := Rect2(146, 104, 184, 76)
		draw_rect(paper, Color("#e3d7b4"))
		for y in range(int(paper.position.y) + 12, int(paper.end.y), 10):
			draw_line(Vector2(paper.position.x + 2, y), Vector2(paper.end.x - 2, y), Color("#cdbf98"), 1.0)
		draw_rect(Rect2(paper.position.x, paper.end.y - 2, paper.size.x, 2), Color("#b8a882"))
		# botões
		_knob(TUNE_C, 14.0, panel.freq / RadioPanel.F_MAX * TAU * 2.0, "SINT.")
		_knob(VOL_C, 9.0, panel.volume * PI * 1.5 - PI * 0.75, "VOL.")
		draw_rect(POWER, Color("#1c120a"))
		draw_rect(POWER.grow(-1), Color("#3a2a1a"))
		draw_rect(Rect2(POWER.position.x + 2, POWER.position.y + 2, 12, POWER.size.y - 4), Color("#c8b070"))
		draw_string(f, Vector2(POWER.position.x - 30, POWER.position.y + 10), "ВЫКЛ", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#d9cba0"))

	func _knob(c: Vector2, r: float, angle: float, label: String) -> void:
		var f := UITheme.font()
		draw_circle(c + Vector2(1, 2), r, Color(0, 0, 0, 0.5))
		draw_circle(c, r, Color("#1a1a16"))
		draw_circle(c, r - 2, Color("#3a3830"))
		for i in 12:
			var a := i / 12.0 * TAU
			draw_line(c + Vector2.from_angle(a) * (r - 2), c + Vector2.from_angle(a) * r, Color("#141410"), 1.0)
		draw_line(c, c + Vector2.from_angle(angle - PI / 2.0) * (r - 3), Color("#d9cba0"), 2.0)
		draw_string(f, Vector2(c.x - r, c.y + r + 9), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#d9cba0"))
