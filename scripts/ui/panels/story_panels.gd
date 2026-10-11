class_name StoryPanels
extends RefCounted
## Painéis narrativos: cena em slides, rádio, diário (J), nota/fita/terminal e opções.


static func create_all() -> Array:
	return [CutscenePanel.new(), RadioPanel.new(), JournalPanel.new(), NotePanel.new(), OptionsPanel.new()]


# =================================================================== CENA (slides)
class CutscenePanel extends GamePanel:
	const CPS := 38.0
	var _slides: Array = []
	var _i := 0
	var _text: Label
	var _tag: Label
	var _hint: Label
	var _choices: VBoxContainer
	var _typing := 0.0
	var _scene_id := ""
	var _on_finish: Callable
	var _locked := false

	func _init() -> void:
		panel_name = "cutscene"
		dim_alpha = 1.0

	func _build() -> void:
		_dim.color = Color(0.015, 0.015, 0.012, 1.0)
		box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		box.custom_minimum_size = Vector2(400, 180)
		_tag = UITheme.label("", 12, UITheme.TEXT_DIM)
		_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(_tag)
		_text = UITheme.label("", 20, UITheme.TEXT)
		_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_text.custom_minimum_size = Vector2(400, 120)
		content.add_child(_text)
		_choices = VBoxContainer.new()
		_choices.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_child(_choices)
		_hint = UITheme.label("clique ou E para continuar", 12, UITheme.TEXT_DIM)
		_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(_hint)

	func open(args: Dictionary) -> void:
		_scene_id = args.get("scene", "")
		_on_finish = args.get("on_finish", Callable())
		_slides = StorySystem.scene(_scene_id)
		_i = 0
		_locked = false
		AudioSystem.set_music("")
		_show()

	func _show() -> void:
		if _i >= _slides.size():
			_finish()
			return
		var s: Dictionary = _slides[_i]
		_text.text = s.get("text", "")
		_text.visible_ratio = 0.0
		_typing = 0.0
		var tag: String = s.get("tag", "")
		_tag.text = "[ %s ]" % tag.to_upper() if tag != "" else ""
		_tag.add_theme_color_override("font_color", UITheme.AMBER if tag.begins_with("fato") else UITheme.TEXT_DIM)
		if s.has("sound"):
			AudioSystem.play(s.sound)
		GamePanel.clear(_choices)
		_choices.visible = false
		for c in s.get("choices", []):
			var b := UITheme.button(c.text, _choose.bind(c), 260)
			_choices.add_child(b)
		_hint.visible = not s.has("choices")

	func _choose(c: Dictionary) -> void:
		StorySystem.apply_ending(c.get("flag", ""))
		_scene_id = c.get("next_scene", "")
		_slides = StorySystem.scene(_scene_id)
		_i = 0
		_show()

	func _advance() -> void:
		if _text.visible_ratio < 1.0:
			_text.visible_ratio = 1.0
			return
		if not (_slides[_i] as Dictionary).get("choices", []).is_empty():
			return
		_i += 1
		_show()

	func _finish() -> void:
		var id := _scene_id
		close()
		if id.begins_with("ending_"):
			UIManager.open("cutscene", {"scene": "epilogue", "on_finish": SceneManager.after_ending})
			return
		if _on_finish.is_valid():
			_on_finish.call()

	func _process(delta: float) -> void:
		if not visible or _slides.is_empty() or _i >= _slides.size():
			return
		if _text.visible_ratio < 1.0:
			_typing += delta
			_text.visible_ratio = minf(1.0, _typing * CPS / maxf(1.0, _text.text.length()))
		elif not _choices.visible and _choices.get_child_count() > 0:
			_choices.visible = true

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_advance()

	func _unhandled_input(event: InputEvent) -> void:
		if visible and (event.is_action_pressed("interact") or event.is_action_pressed("use_tool")):
			_advance()
			get_viewport().set_input_as_handled()


# =================================================================== NOTA / FITA / TERMINAL
class NotePanel extends GamePanel:
	var _title: Label
	var _text: Label
	var _typing := 0.0
	var _style := "paper"

	func _init() -> void:
		panel_name = "note"

	func _build() -> void:
		box.custom_minimum_size = Vector2(300, 0)
		_title = UITheme.label("", 20)
		content.add_child(_title)
		_text = UITheme.label("", 16)
		_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_text.custom_minimum_size.x = 284
		content.add_child(_text)
		content.add_child(UITheme.button("Fechar", close))

	func open(args: Dictionary) -> void:
		var n: Dictionary = DataManager.notes.get(args.get("note", ""), {})
		_style = n.get("style", "paper")
		_title.text = n.get("title", "")
		_text.text = n.get("text", "")
		_typing = 0.0
		match _style:
			"terminal":
				box.theme_type_variation = "CRTPanel"
				_title.add_theme_color_override("font_color", UITheme.CRT_GREEN)
				_text.add_theme_color_override("font_color", UITheme.CRT_GREEN)
				_text.visible_ratio = 0.0
			"tape":
				box.theme_type_variation = "CRTPanel"
				_title.add_theme_color_override("font_color", UITheme.AMBER)
				_text.add_theme_color_override("font_color", Color("#e8d8b0"))
				_text.visible_ratio = 0.0
				AudioSystem.play("tape")
			_:
				box.theme_type_variation = "PaperPanel"
				_title.add_theme_color_override("font_color", Color("#3a2a1a"))
				_text.add_theme_color_override("font_color", Color("#2a2620"))
				_text.visible_ratio = 1.0

	func _process(delta: float) -> void:
		if visible and _text.visible_ratio < 1.0:
			_typing += delta
			var speed := 60.0 if _style == "terminal" else 30.0
			_text.visible_ratio = minf(1.0, _typing * speed / maxf(1.0, _text.text.length()))
			if _style == "terminal" and Engine.get_process_frames() % 4 == 0:
				AudioSystem.play("text_blip", 1.6, -8.0)


# =================================================================== DIÁRIO (J)
class JournalPanel extends GamePanel:
	var _tab := "quests"
	var _list: VBoxContainer
	var _tabs: Dictionary = {}

	func _init() -> void:
		panel_name = "journal"

	func _build() -> void:
		box.custom_minimum_size = Vector2(380, 220)
		content.add_child(header("DIÁRIO"))
		var row := HBoxContainer.new()
		content.add_child(row)
		for t in [["quests", "MISSÕES"], ["tapes", "FITAS"], ["notes", "NOTAS"], ["catalog", "CATÁLOGO"]]:
			var b := UITheme.button(t[1], _set_tab.bind(t[0]), 86)
			b.toggle_mode = true
			row.add_child(b)
			_tabs[t[0]] = b
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(368, 160)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		content.add_child(scroll)
		_list = VBoxContainer.new()
		_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(_list)

	func open(_args: Dictionary) -> void:
		_set_tab(_tab)

	func _set_tab(t: String) -> void:
		_tab = t
		for k in _tabs:
			_tabs[k].button_pressed = k == t
		GamePanel.clear(_list)
		match t:
			"quests": _quests()
			"tapes": _notes_of("tape")
			"notes": _notes_of("")
			"catalog": _catalog()

	func _quests() -> void:
		if QuestSystem.active.is_empty() and QuestSystem.done.is_empty():
			_list.add_child(UITheme.label("Nenhuma missão ainda. Converse com as pessoas da base.", 16, UITheme.TEXT_DIM))
		for id in QuestSystem.active:
			var q := QuestSystem.data(id)
			var title := UITheme.label(("★ " if q.get("main", false) else "") + q.get("title", id), 16, UITheme.AMBER)
			_list.add_child(title)
			var d := UITheme.label(q.get("desc", ""), 12, UITheme.TEXT)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.custom_minimum_size.x = 350
			_list.add_child(d)
			for p in QuestSystem.progress(id):
				var mark := "[x]" if p.ok else "[ ]"
				var txt := "  %s %s" % [mark, p.text]
				if p.need > 1:
					txt += " (%d/%d)" % [p.cur, p.need]
				_list.add_child(UITheme.label(txt, 12, UITheme.GOOD if p.ok else UITheme.TEXT_DIM))
		for id in QuestSystem.done:
			_list.add_child(UITheme.label("✓ " + String(QuestSystem.data(id).get("title", id)), 12, UITheme.TEXT_DIM))

	func _catalog() -> void:
		var found := ProgressionSystem.discovered
		var all := DataManager.ore_list.map(func(o): return o.id)
		var n := all.filter(func(id): return found.has(id)).size()
		_list.add_child(UITheme.label("Rochas e minerais descobertos: %d/%d" % [n, all.size()], 16, UITheme.AMBER))
		for o in DataManager.ore_list:
			var row := HBoxContainer.new()
			_list.add_child(row)
			var known: bool = found.has(o.id)
			var ic := TextureRect.new()
			var sprites: Array = o.get("sprites", [""])
			ic.texture = DataManager.texture(sprites[0])
			ic.modulate = Color.WHITE if known else Color(0, 0, 0, 0.85)
			ic.custom_minimum_size = Vector2(16, 16)
			row.add_child(ic)
			var txt := "???  (aparece a partir do nível %d)" % int(o.min_depth)
			if known:
				var drop := DataManager.item_name(o.get("drop", "")) if o.has("drop") else "vários itens"
				txt = "%s  ·  rende %s  ·  ferramenta nível %d" % [o.name, drop, int(o.get("min_tier", 1))]
			row.add_child(UITheme.label(txt, 12, UITheme.TEXT if known else UITheme.TEXT_DIM))

		# bestiário
		_list.add_child(UITheme.label("O que vive aqui embaixo", 16, UITheme.AMBER))
		for eid in DataManager.enemies:
			var e: Dictionary = DataManager.enemies[eid]
			var seen := GameState.has_flag("seen_" + String(eid))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			_list.add_child(row)
			var ic := TextureRect.new()
			var at := AtlasTexture.new()
			at.atlas = DataManager.texture(String(e.get("sheet", "")))
			var fr: Array = e.get("frame", [16, 16])
			at.region = Rect2(0, 0, int(fr[0]), int(fr[1]))
			ic.texture = at
			ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			ic.custom_minimum_size = Vector2(24, 18)
			ic.modulate = Color.WHITE if seen else Color(0, 0, 0, 0.85)
			row.add_child(ic)
			var v := VBoxContainer.new()
			v.add_theme_constant_override("separation", -2)
			row.add_child(v)
			if seen:
				v.add_child(UITheme.label(String(e.get("name", eid)), 12, UITheme.TEXT))
				var l1 := UITheme.label(String(e.get("lore", "")), 10, UITheme.TEXT_DIM)
				l1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l1.custom_minimum_size.x = 340
				v.add_child(l1)
				var l2 := UITheme.label("Fraqueza: " + String(e.get("weakness", "")), 10, UITheme.AMBER)
				l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l2.custom_minimum_size.x = 340
				v.add_child(l2)
			else:
				v.add_child(UITheme.label("???  (ainda não encontrado)", 12, UITheme.TEXT_DIM))

	func _notes_of(style: String) -> void:
		var any := false
		for id in DataManager.note_order:
			var n: Dictionary = DataManager.notes[id]
			var is_tape: bool = n.get("style", "") == "tape"
			if (style == "tape") != is_tape or not GameState.has_note(id):
				continue
			any = true
			_list.add_child(UITheme.button(n.get("title", id), func(): UIManager.open("note", {"note": id})))
		if not any:
			var msg := "Nenhuma fita ainda. Elas estão nas profundezas." if style == "tape" else "Procure em caixas, armários e terminais."
			_list.add_child(UITheme.label(msg, 16, UITheme.TEXT_DIM))


# =================================================================== OPÇÕES
class OptionsPanel extends GamePanel:
	var _checks: Dictionary = {}

	func _init() -> void:
		panel_name = "options"

	func _enter_tree() -> void:
		if not Settings.changed.is_connected(_on_setting):
			Settings.changed.connect(_on_setting)

	func _exit_tree() -> void:
		if Settings.changed.is_connected(_on_setting):
			Settings.changed.disconnect(_on_setting)

	func _on_setting(key: String) -> void:
		if _checks.has(key):
			_checks[key].set_pressed_no_signal(bool(Settings.get_v(key)))

	func _build() -> void:
		box.custom_minimum_size = Vector2(400, 0)
		content.add_child(header("OPÇÕES"))
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 12)
		content.add_child(cols)
		var left := VBoxContainer.new()
		left.add_theme_constant_override("separation", 2)
		cols.add_child(left)
		var right := VBoxContainer.new()
		right.add_theme_constant_override("separation", 0)
		cols.add_child(right)
		left.add_child(UITheme.label("ÁUDIO", 12, UITheme.AMBER))
		_slider(left, "Geral", "vol_master")
		_slider(left, "Música", "vol_music")
		_slider(left, "Ambiente", "vol_ambient")
		_slider(left, "Efeitos", "vol_sfx")
		_slider(left, "Interface", "vol_ui")
		right.add_child(UITheme.label("TELA E ACESSIBILIDADE", 12, UITheme.AMBER))
		_check(right, "Tela cheia (F11)", "fullscreen")
		var zr := HBoxContainer.new()
		zr.add_child(UITheme.label("Zoom", 12))
		var ob := OptionButton.new()
		ob.add_theme_font_size_override("font_size", 12)
		for pair in [["Perto", 270], ["Médio", 320], ["Longe", 360]]:
			ob.add_item(pair[0], pair[1])
		ob.select(maxi(0, Settings.VIEW_HEIGHTS.find(int(Settings.get_v("view_height")))))
		ob.item_selected.connect(func(i): Settings.set_v("view_height", ob.get_item_id(i)))
		zr.add_child(ob)
		right.add_child(zr)
		_check(right, "Tremor de tela", "screen_shake")
		_check(right, "Flashes", "flashes")
		_check(right, "Números de dano", "damage_numbers")
		_check(right, "Legendas de sons", "captions")
		_check(right, "Dicas", "hints")
		_check(right, "Atualizar automaticamente", "auto_update")
		content.add_child(UITheme.label("A resolução se ajusta sozinha à tela (pixel perfeito).", 12, UITheme.TEXT_DIM))

	func _check(parent: Control, label: String, key: String) -> void:
		var c := CheckBox.new()
		c.text = label
		c.add_theme_font_size_override("font_size", 12)
		c.button_pressed = bool(Settings.get_v(key))
		c.toggled.connect(func(on): Settings.set_v(key, on); AudioSystem.play("ui_click"))
		_checks[key] = c
		parent.add_child(c)

	func _slider(parent: Control, label: String, key: String) -> void:
		var row := HBoxContainer.new()
		var l := UITheme.label(label, 12)
		l.custom_minimum_size.x = 56
		row.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = float(Settings.get_v(key))
		s.custom_minimum_size = Vector2(110, 10)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.value_changed.connect(func(v): Settings.set_v(key, v))
		s.drag_ended.connect(func(_c): AudioSystem.play("ui_click"))
		row.add_child(s)
		parent.add_child(row)
