extends Control
## Tela de título — "26 de abril de 1986, 01:30" (arte: tools/title_v5.py).
## Cena em camadas desenhada em escala 1 (pixel sempre inteiro), enquadrada pelo tamanho da tela,
## com parallax pelo mouse. Abertura: escuro + Geiger acelerando → a cena surge → o logotipo acende.
## Qualquer tecla ou clique pula a abertura.

const SCENE := Vector2(800, 420)
const REACTOR := Vector2(586, 228)
const HERO_POS := Vector2(440, 240)
const STACK_TOP := Vector2(572, 100)
const INTRO_SCENE_AT := 2.0
const INTRO_LOGO_AT := 2.9
const INTRO_MENU_AT := 3.5

var _seed_edit: LineEdit
var _confirm: Control
var _options: GamePanel
var _menu: MenuList
var _ui_root: Control
var _logo: TextureRect
var _menu_box: Control
var _footer: Array = []
var _upd_lbl: Label
var _upd_menu: MenuList
var _upd_shown := ""
var _black: ColorRect
var _rng := RandomNumberGenerator.new()

var _world: Node2D
var _layers: Array = []          # [nó, fator de parallax em px]
var _fogs: Array = []            # [sprite, velocidade]
var _beam: Sprite2D
var _glow: Sprite2D
var _fire: Sprite2D
var _stack_light: Sprite2D
var _hero: Sprite2D
var _lamp_glow: Sprite2D
var _ash: CPUParticles2D
var _heli: Sprite2D
var _heli_light: Sprite2D
var _heli_t := 18.0
var _heli_v := 0.0
var _par := Vector2.ZERO
var _t := 0.0
var _intro_t := 0.0
var _intro_done := false
var _beam_boost := 0.0
var _geiger_t := 0.5
var _fire_t := 0.0
var _logo_lit := false
var _fire_audio: AudioStreamPlayer


func _ready() -> void:
	_rng.randomize()
	theme = UITheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_scene()
	var post := CanvasLayer.new()
	post.layer = 5
	post.add_child(PostFX.new())
	add_child(post)
	_build_ui()
	var cover := CanvasLayer.new()       # preto da abertura, por cima de tudo
	cover.layer = 20
	add_child(cover)
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 1)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.add_child(_black)
	_fire_audio = AudioStreamPlayer.new()
	_fire_audio.stream = AudioSystem.loop_stream("fire")
	_fire_audio.volume_db = -60.0
	_fire_audio.bus = "Ambient"
	add_child(_fire_audio)
	AudioSystem.set_ambient("wind")
	resized.connect(_fit_scene)
	_fit_scene()


# ------------------------------------------------------------ cena
func _tex(n: String) -> Texture2D:
	return DataManager.texture("res://assets/ui/title5/%s.png" % n)


func _sprite(tex: Texture2D, pos: Vector2, parallax: float, additive := false) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.position = pos
	sp.set_meta("base", pos)
	if additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sp.material = m
	_world.add_child(sp)
	_layers.append([sp, parallax])
	return sp


func _particles(pos: Vector2, parallax: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = pos
	p.set_meta("base", pos)
	_world.add_child(p)
	_layers.append([p, parallax])
	return p


func _fog(y: float, speed: float, alpha: float, parallax: float) -> void:
	var sp := _sprite(_tex("fog"), Vector2(-20, y), parallax)
	sp.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sp.region_enabled = true
	sp.region_rect = Rect2(0, 0, SCENE.x + 40, 120)
	sp.modulate.a = alpha
	_fogs.append([sp, speed])


func _build_scene() -> void:
	_world = Node2D.new()
	add_child(_world)
	_sprite(_tex("sky"), Vector2.ZERO, 1.0)
	_glow = _sprite(DataManager.texture("res://assets/effects/light_soft.png"), REACTOR - Vector2(160, 150), 2.5, true)
	_glow.scale = Vector2(2.5, 2.3)
	_glow.modulate = Color(1.0, 0.45, 0.15, 0.32)
	_beam = _sprite(_tex("beam"), Vector2(REACTOR.x - 35, 0), 2.5, true)
	_sprite(_tex("city"), Vector2.ZERO, 2.0)
	# fumaça saindo do reator e indo com o vento para a direita
	var smoke := _particles(REACTOR + Vector2(0, -4), 2.5)
	smoke.texture = _tex("smoke")
	var sm := CanvasItemMaterial.new()
	sm.particles_animation = true
	sm.particles_anim_h_frames = 4
	sm.particles_anim_v_frames = 1
	smoke.material = sm
	smoke.anim_offset_min = 0.0
	smoke.anim_offset_max = 1.0
	smoke.amount = 16
	smoke.lifetime = 20.0
	smoke.preprocess = 20.0
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smoke.emission_rect_extents = Vector2(18, 3)
	smoke.direction = Vector2(0.15, -1)
	smoke.spread = 12.0
	smoke.gravity = Vector2(3.2, -0.6)
	smoke.initial_velocity_min = 5.0
	smoke.initial_velocity_max = 9.0
	var sr := Gradient.new()
	sr.set_color(0, Color(2.4, 1.2, 0.7, 0.0))
	sr.add_point(0.08, Color(1.8, 1.0, 0.7, 0.85))
	sr.add_point(0.4, Color(1.0, 0.95, 0.9, 0.7))
	sr.set_color(sr.get_point_count() - 1, Color(0.8, 0.8, 0.8, 0.0))
	smoke.color_ramp = sr
	_sprite(_tex("plant"), Vector2.ZERO, 2.5)
	_fire = _sprite(_tex("fire"), Vector2.ZERO, 2.5)
	_fire.hframes = 3
	_stack_light = _sprite(DataManager.texture("res://assets/effects/light_soft.png"), STACK_TOP - Vector2(6, 6), 2.5, true)
	_stack_light.scale = Vector2(0.1, 0.1)
	_stack_light.modulate = Color(1.0, 0.15, 0.08, 0.0)
	# fagulhas subindo do núcleo exposto
	var embers := _particles(REACTOR + Vector2(0, 2), 2.5)
	embers.texture = DataManager.texture("res://assets/effects/pixel.png")
	embers.amount = 34
	embers.lifetime = 5.0
	embers.preprocess = 5.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(26, 4)
	embers.direction = Vector2(0.2, -1)
	embers.spread = 30.0
	embers.gravity = Vector2(4, -6)
	embers.initial_velocity_min = 8.0
	embers.initial_velocity_max = 22.0
	embers.scale_amount_min = 0.5
	embers.scale_amount_max = 0.5
	var er := Gradient.new()
	er.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	er.add_point(0.5, Color(1.0, 0.45, 0.15, 0.9))
	er.set_color(er.get_point_count() - 1, Color(0.6, 0.1, 0.05, 0.0))
	embers.color_ramp = er
	_heli = _sprite(_tex("heli"), Vector2(-60, 80), 1.5)
	_heli.hframes = 2
	_heli.visible = false
	_heli_light = _sprite(DataManager.texture("res://assets/effects/light_soft.png"), Vector2(-60, 80), 1.5, true)
	_heli_light.scale = Vector2(0.06, 0.06)
	_heli_light.modulate = Color(1, 0.2, 0.1, 0)
	_fog(196, 4.0, 0.35, 3.0)
	_sprite(_tex("mid"), Vector2.ZERO, 4.0)
	_fog(250, 9.0, 0.45, 6.0)
	_sprite(_tex("front"), Vector2.ZERO, 8.0)
	_hero = _sprite(_tex("hero"), HERO_POS, 9.0)
	_hero.hframes = 2
	_lamp_glow = _sprite(DataManager.texture("res://assets/effects/light_soft.png"), HERO_POS + Vector2(8 - 20, 77 - 20), 9.0, true)
	_lamp_glow.scale = Vector2(0.32, 0.32)
	_lamp_glow.modulate = Color(1.0, 0.7, 0.35, 0.5)
	_fog(312, 15.0, 0.25, 11.0)
	# cinza caindo (cobre a tela toda, independente do enquadramento)
	_ash = CPUParticles2D.new()
	_ash.texture = DataManager.texture("res://assets/effects/pixel.png")
	_ash.amount = 70
	_ash.lifetime = 16.0
	_ash.preprocess = 16.0
	_ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_ash.direction = Vector2(0.35, 1)
	_ash.spread = 20.0
	_ash.gravity = Vector2(1.5, 2.5)
	_ash.initial_velocity_min = 5.0
	_ash.initial_velocity_max = 12.0
	_ash.scale_amount_min = 0.5
	_ash.scale_amount_max = 0.5
	_ash.color = Color(0.72, 0.68, 0.62, 0.55)
	add_child(_ash)


## Enquadra a cena: pixel inteiro, o reator sempre no mesmo ponto relativo da tela.
func _fit_scene() -> void:
	if _world == null:
		return
	var vs := get_viewport_rect().size
	var base := Vector2(vs.x * 0.72 - REACTOR.x, vs.y * 0.75 - 300.0).round()
	base.x = clampf(base.x, vs.x - SCENE.x + 14.0, -14.0)
	base.y = clampf(base.y, vs.y - SCENE.y + 14.0, -14.0)
	_world.position = base
	_ash.position = Vector2(vs.x / 2.0, -8)
	_ash.emission_rect_extents = Vector2(vs.x / 2.0 + 30.0, 2)


func _animate_scene(delta: float) -> void:
	_t += delta
	var vs := get_viewport_rect().size
	var m := (get_viewport().get_mouse_position() / vs - Vector2(0.5, 0.5)).clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5))
	m += Vector2(sin(_t * 0.13), cos(_t * 0.11)) * 0.15            # deriva lenta mesmo sem mouse
	_par = _par.lerp(-m * 2.0, clampf(delta * 2.0, 0.0, 1.0)).limit_length(1.0)
	for l in _layers:
		var n: Node2D = l[0]
		n.position = ((n.get_meta("base") as Vector2) + _par * float(l[1])).round()
	for f in _fogs:
		var sp: Sprite2D = f[0]
		sp.region_rect.position.x = fmod(_t * float(f[1]), 640.0)
	# coluna de luz tremulando (e o clarão da abertura)
	_beam_boost = maxf(0.0, _beam_boost - delta * 0.7)
	var flick := 0.82 + 0.1 * sin(_t * 2.3) * sin(_t * 0.71) + (0.12 * _rng.randf() if _rng.randf() < 0.08 else 0.0)
	_beam.modulate.a = clampf(flick + _beam_boost, 0.0, 1.6)
	_glow.modulate.a = 0.28 + 0.06 * sin(_t * 0.9) + _beam_boost * 0.4 + (0.04 * _rng.randf())
	_fire_t -= delta
	if _fire_t <= 0.0:
		_fire_t = _rng.randf_range(0.08, 0.16)
		_fire.frame = (_fire.frame + 1 + _rng.randi() % 2) % 3
	var ph := fmod(_t, 1.6)
	_stack_light.modulate.a = 1.0 if ph < 0.3 else maxf(0.0, 1.0 - (ph - 0.3) * 4.0)
	_hero.frame = 1 if fmod(_t, 3.4) > 1.7 else 0                 # respiração
	_lamp_glow.modulate.a = 0.42 + 0.08 * sin(_t * 7.0) + 0.06 * _rng.randf()
	_animate_heli(delta)
	# Geiger ambiente: cliques esparsos (acelera na abertura)
	_geiger_t -= delta
	if _geiger_t <= 0.0:
		var rate := 0.7
		if not _intro_done and _intro_t < INTRO_SCENE_AT:
			rate = lerpf(2.0, 26.0, clampf(_intro_t / INTRO_SCENE_AT, 0.0, 1.0))
		_geiger_t = _rng.randf_range(0.2, 1.8) / rate
		AudioSystem.play("geiger", 1.0, -6.0 if not _intro_done else -12.0)


func _animate_heli(delta: float) -> void:
	_heli_t -= delta
	if _heli_t <= 0.0 and not _heli.visible:
		_heli.visible = true
		# Mi-8 cruzando da direita para a esquerda, passando na frente da coluna de luz
		var y := _rng.randf_range(150.0, 185.0)
		_heli.set_meta("base", Vector2(-_world.position.x + get_viewport_rect().size.x + 30.0, y))
		_heli_v = -_rng.randf_range(20.0, 26.0)
		_heli.flip_h = true
		AudioSystem.play("distant_bang", 0.5, -18.0)
	if _heli.visible:
		var b: Vector2 = _heli.get_meta("base")
		b.x += _heli_v * delta
		_heli.set_meta("base", b)
		_heli.frame = int(_t * 16.0) % 2
		_heli_light.set_meta("base", b + Vector2(7 - 4, 9 - 4))
		_heli_light.modulate.a = 0.9 if fmod(_t, 1.1) < 0.15 else 0.0
		if b.x < -_world.position.x - 50.0:
			_heli.visible = false
			_heli_light.modulate.a = 0.0
			_heli_t = _rng.randf_range(28.0, 50.0)


# ------------------------------------------------------------ abertura
func _process(delta: float) -> void:
	_animate_scene(delta)
	if _upd_lbl and UpdateSystem.state == UpdateSystem.St.DOWNLOADING:
		_upd_lbl.text = UpdateSystem.status_text
	if _intro_done:
		_logo_flicker(delta)
		return
	_intro_t += delta
	if _intro_t >= INTRO_SCENE_AT and _black.color.a >= 1.0:
		AudioSystem.play("stinger", 0.9, -2.0)
		AudioSystem.set_music("base")
		_beam_boost = 0.8
	if _intro_t >= INTRO_SCENE_AT:
		_black.color.a = clampf(1.0 - (_intro_t - INTRO_SCENE_AT) / 1.5, 0.0, 1.0)
		_fire_audio.volume_db = linear_to_db(clampf((_intro_t - INTRO_SCENE_AT) / 2.0, 0.001, 1.0) * 0.18)
		if not _fire_audio.playing:
			_fire_audio.play()
	if _intro_t >= INTRO_LOGO_AT:
		var k := _intro_t - INTRO_LOGO_AT
		# acende como letreiro velho: pisca, falha, firma
		_logo.modulate.a = 1.0 if (k > 0.55 or fmod(k, 0.13) < 0.06) and not (0.3 < k and k < 0.38) else 0.0
		if not _logo_lit and k > 0.05:
			_logo_lit = true
			AudioSystem.play("spark", 0.8, -4.0)
	if _intro_t >= INTRO_MENU_AT:
		var a := clampf((_intro_t - INTRO_MENU_AT) / 0.6, 0.0, 1.0)
		_menu_box.modulate.a = a
		for f in _footer:
			f.modulate.a = a
		if a >= 1.0:
			_finish_intro()


func _finish_intro() -> void:
	_intro_done = true
	_black.color.a = 0.0
	_logo.modulate.a = 1.0
	_menu_box.modulate.a = 1.0
	_menu.visible = true
	_refresh_update()
	for f in _footer:
		f.modulate.a = 1.0
	if not _fire_audio.playing:
		_fire_audio.play()
	_fire_audio.volume_db = linear_to_db(0.18)
	AudioSystem.set_music("base")


func _skip_intro() -> void:
	if _intro_done:
		return
	if _intro_t < INTRO_SCENE_AT:
		AudioSystem.play("stinger", 0.9, -4.0)
	_intro_t = INTRO_MENU_AT + 1.0
	_finish_intro()


## Depois de aceso, o letreiro ainda falha de vez em quando.
func _logo_flicker(_delta: float) -> void:
	if _rng.randf() < 0.004:
		_logo.modulate.a = 0.25
	else:
		_logo.modulate.a = lerpf(_logo.modulate.a, 1.0, 0.2)


# ------------------------------------------------------------ interface
func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	_ui_root = Control.new()
	_ui_root.theme = UITheme.get_theme()
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_ui_root)
	var root := _ui_root
	# sombra à esquerda para o texto respirar sobre a arte
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.01, 0.01, 0.015, 0.78))
	grad.add_point(0.55, Color(0.01, 0.01, 0.015, 0.45))
	grad.set_color(grad.get_point_count() - 1, Color(0.01, 0.01, 0.015, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 64
	gt.height = 4
	shade.texture = gt
	shade.anchor_bottom = 1.0
	shade.offset_right = 270
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	_logo = TextureRect.new()
	_logo.texture = _tex("logo")
	_logo.position = Vector2(10, 12)
	_logo.modulate.a = 0.0
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_logo)
	var box := VBoxContainer.new()
	box.position = Vector2(26, 104)
	box.add_theme_constant_override("separation", 10)
	box.modulate.a = 0.0
	root.add_child(box)
	_menu_box = box
	box.add_child(UITheme.label("ZONA DE EXCLUSÃO · NOITE DE 26 DE ABRIL DE 1986", 10, Color("#a89a7a"), true))
	var menu := MenuList.new(196)
	box.add_child(menu)
	if SaveSystem.has_save():
		var info := SaveSystem.save_info()
		menu.add_item("continue", "CONTINUAR", _continue, "Dia %d · %s · nível máx. %d" % [
			int(info.get("day", 1)), DataManager.currency(int(info.get("money", 0))), int(info.get("max_depth", 0))])
	menu.add_item("new", "NOVO JOGO", _new_game_pressed)
	menu.add_item("options", "OPÇÕES", _open_options)
	menu.add_item("quit", "SAIR", func(): get_tree().quit())
	menu.visible = false
	_menu = menu
	# seed discreta no canto (mesma seed = mesmo mundo)
	var seed_row := HBoxContainer.new()
	seed_row.anchor_left = 1.0
	seed_row.anchor_right = 1.0
	seed_row.anchor_top = 1.0
	seed_row.anchor_bottom = 1.0
	seed_row.offset_left = -150
	seed_row.offset_right = -8
	seed_row.offset_top = -20
	seed_row.offset_bottom = -4
	seed_row.alignment = BoxContainer.ALIGNMENT_END
	seed_row.modulate.a = 0.0
	root.add_child(seed_row)
	seed_row.add_child(UITheme.label("seed do mundo", 10, UITheme.TEXT_DIM, true))
	_seed_edit = LineEdit.new()
	_seed_edit.text = str(_rng.randi_range(1000000, 9999999))
	_seed_edit.custom_minimum_size = Vector2(70, 0)
	_seed_edit.max_length = 10
	_seed_edit.add_theme_font_size_override("font_size", 12)
	_seed_edit.tooltip_text = "A mesma seed gera o mesmo mundo e as mesmas descidas."
	seed_row.add_child(_seed_edit)
	var foot := UITheme.label("v%s · Ficção inspirada em fatos reais · F11: tela cheia" % DataManager.game.get("version", ""), 10, UITheme.TEXT_DIM, true)
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = 8
	foot.offset_top = -16
	foot.modulate.a = 0.0
	root.add_child(foot)
	# atualização automática: linha de status + ação (aparece só quando há algo a fazer)
	_upd_lbl = UITheme.label("", 10, Color("#8fb87a"), true)
	_upd_lbl.anchor_top = 1.0
	_upd_lbl.anchor_bottom = 1.0
	_upd_lbl.offset_left = 8
	_upd_lbl.offset_top = -30
	_upd_lbl.modulate.a = 0.0
	root.add_child(_upd_lbl)
	_upd_menu = MenuList.new(220)
	box.add_child(_upd_menu)
	_upd_menu.visible = false
	UpdateSystem.status_changed.connect(func(_s, _t): _refresh_update())
	_footer = [seed_row, foot, _upd_lbl]
	_options = StoryPanels.OptionsPanel.new()
	_options.visible = false
	root.add_child(_options)
	_build_confirm(root)


func _refresh_update() -> void:
	if _upd_lbl == null:
		return
	_upd_lbl.text = UpdateSystem.status_text
	var st := String(UpdateSystem.St.keys()[UpdateSystem.state])
	if st == _upd_shown:
		return
	_upd_shown = st
	for c in _upd_menu.get_children():
		c.queue_free()
	_upd_menu._items.clear()
	_upd_menu._sel = 0
	if st == "READY":
		_upd_menu.add_item("update", "REINICIAR E ATUALIZAR", func(): UpdateSystem.apply_and_restart(),
			"versão %s baixada" % UpdateSystem.latest_version)
	elif st == "NEEDS_INSTALLER":
		_upd_menu.add_item("installer", "BAIXAR VERSÃO NOVA", func(): UpdateSystem.open_release_page(),
			"v%s precisa do instalador novo" % UpdateSystem.latest_version)
	_upd_menu.visible = _upd_menu._items.size() > 0 and _menu.visible


func _build_confirm(root: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.visible = false
	root.add_child(center)
	_confirm = center
	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var l := UITheme.label("Começar um novo jogo?\nO save atual será substituído\nna próxima vez que você dormir.", 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var m := MenuList.new(150)
	m.add_item("cancel", "Cancelar", func(): _confirm.visible = false)
	m.add_item("start", "Começar do zero", _start_new)
	v.add_child(m)


func _open_options() -> void:
	_options.visible = true
	_menu.visible = false
	_options.visibility_changed.connect(func(): _menu.visible = not _options.visible, CONNECT_ONE_SHOT)


func _continue() -> void:
	if not SceneManager.continue_game():
		AudioSystem.play("ui_error")


func _new_game_pressed() -> void:
	if SaveSystem.has_save():
		_confirm.visible = true
		_menu.visible = false
		_confirm.visibility_changed.connect(func(): _menu.visible = not _confirm.visible, CONNECT_ONE_SHOT)
	else:
		_start_new()


func _start_new() -> void:
	var s := _seed_edit.text.strip_edges()
	var seed_value := int(s) if s.is_valid_int() else s.hash()
	SceneManager.start_new_game(seed_value)


func _input(event: InputEvent) -> void:
	if not _intro_done and ((event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed)):
		_skip_intro()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _options.visible:
			_options.visible = false
		elif _confirm.visible:
			_confirm.visible = false


func _exit_tree() -> void:
	if _fire_audio:
		_fire_audio.stop()
