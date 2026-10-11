extends Node
## Configurações do jogador (user://settings.cfg): vídeo, áudio e acessibilidade.
## Também ajusta a escala da tela automaticamente: escolhe o maior fator INTEIRO
## que mantém ~270 px de altura virtual, então a pixel art fica nítida em qualquer
## resolução e a tela é preenchida sem barras pretas (a área visível se adapta).

signal changed(key: String)

const PATH := "user://settings.cfg"
## Alturas virtuais oferecidas no "zoom da tela" (maior = câmera mais afastada, UI menor).
const VIEW_HEIGHTS := [270, 320, 360]
const MIN_VIRTUAL_WIDTH := 400
const WINDOWED_SIZE := Vector2i(1280, 720)
const BUSES := ["Music", "Ambient", "SFX", "UI"]

var values := {
	"fullscreen": true,
	"view_height": 360,
	"vol_master": 0.85,
	"vol_music": 0.55,
	"vol_ambient": 0.9,
	"vol_sfx": 0.9,
	"vol_ui": 0.8,
	"screen_shake": true,
	"flashes": true,
	"damage_numbers": true,
	"captions": true,
	"hints": true,
	"auto_update": true,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_load()
	get_window().size_changed.connect(_update_scale)
	for k in values:
		_apply(k)
	_update_scale.call_deferred()


func get_v(key: String):
	return values.get(key)


func set_v(key: String, value) -> void:
	values[key] = value
	_apply(key)
	_save()
	changed.emit(key)


func toggle_fullscreen() -> void:
	set_v("fullscreen", not bool(values.fullscreen))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------ aplicação
func _apply(key: String) -> void:
	if key == "fullscreen":
		_apply_window_mode()
	elif key == "view_height":
		_update_scale()
	elif key.begins_with("vol_"):
		var bus: String = {"vol_master": "Master", "vol_music": "Music", "vol_ambient": "Ambient",
			"vol_sfx": "SFX", "vol_ui": "UI"}.get(key, "Master")
		var idx := AudioServer.get_bus_index(bus)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(float(values[key]), 0.0001)))


func _apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var win := get_window()
	if values.fullscreen:
		win.mode = Window.MODE_FULLSCREEN
	else:
		win.mode = Window.MODE_WINDOWED
		var screen := DisplayServer.screen_get_usable_rect(win.current_screen).size
		win.size = Vector2i(mini(WINDOWED_SIZE.x, screen.x - 40), mini(WINDOWED_SIZE.y, screen.y - 60))
		win.move_to_center()
	_update_scale()


func _update_scale() -> void:
	var win := get_window()
	var s := win.size
	if s.x <= 0 or s.y <= 0:
		return
	var factor := maxi(1, roundi(s.y / float(values.get("view_height", 360))))
	while factor > 1 and s.x / factor < MIN_VIRTUAL_WIDTH:
		factor -= 1
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
	win.content_scale_size = Vector2i(s.x / factor, s.y / factor)


## Tamanho virtual atual (útil para UI que precisa saber a área visível).
func virtual_size() -> Vector2:
	return get_viewport().get_visible_rect().size


# ------------------------------------------------------------ áudio
func _ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
	# eco subterrâneo no SFX (ligado só na mina)
	var sfx := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx) == 0:
		var rev := AudioEffectReverb.new()
		rev.room_size = 0.75
		rev.damping = 0.55
		rev.wet = 0.22
		rev.dry = 1.0
		rev.spread = 0.6
		AudioServer.add_bus_effect(sfx, rev, 0)
		AudioServer.set_bus_effect_enabled(sfx, 0, false)
	# abafado quando o jogo está pausado (menus)
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 900.0
		AudioServer.add_bus_effect(master, lp, 0)
		AudioServer.set_bus_effect_enabled(master, 0, false)


func set_underground_reverb(on: bool) -> void:
	AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index("SFX"), 0, on)


func set_muffled(on: bool) -> void:
	AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index("Master"), 0, on)


# ------------------------------------------------------------ persistência
func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k in values:
		if cfg.has_section_key("settings", k):
			values[k] = cfg.get_value("settings", k)


func _save() -> void:
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("settings", k, values[k])
	cfg.save(PATH)
