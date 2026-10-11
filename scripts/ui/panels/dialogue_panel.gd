class_name DialoguePanel
extends GamePanel
## Conversa ramificada com NPC: retrato, nome, texto em máquina de escrever
## (com bipes), opções numeradas (1-9 ou clique). [•] = assunto novo.

const CHARS_PER_SEC := 45.0

var _npc := ""
var _name: Label
var _text: Label
var _portrait: TextureRect
var _options: VBoxContainer
var _typing := 0.0
var _blip_acc := 0.0
var _current_opts: Array = []


func _init() -> void:
	panel_name = "dialogue"
	dim_alpha = 0.35


func _build() -> void:
	box.custom_minimum_size = Vector2(360, 0)
	var center := box.get_parent() as Control
	center.anchor_top = 0.5
	center.offset_top = 0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	var frame := PanelContainer.new()
	frame.theme_type_variation = "CRTPanel"
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(frame)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(48, 96)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.add_child(_portrait)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	row.add_child(v)
	_name = Label.new()
	_name.theme_type_variation = "HeaderLabel"
	v.add_child(_name)
	_text = UITheme.label("", 16)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(290, 48)
	v.add_child(_text)
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 1)
	v.add_child(_options)


func open(args: Dictionary) -> void:
	_npc = args.get("npc", "")
	var d: Dictionary = DataManager.npcs.get(_npc, {})
	_name.text = "%s — %s" % [d.get("name", "?"), d.get("role", "")]
	var at := AtlasTexture.new()
	at.atlas = DataManager.texture(d.get("sprite", ""))
	at.region = Rect2(0, 0, 16, 32)
	_portrait.texture = at
	_go(StorySystem.start_node(_npc))


func _go(node_id: String) -> void:
	var n := StorySystem.enter_node(_npc, node_id)
	if n.is_empty():
		close()
		return
	_text.text = n.text
	_text.visible_ratio = 0.0
	_typing = 0.0
	_current_opts = n.options
	GamePanel.clear(_options)
	var i := 1
	for o in _current_opts:
		var label := "%d. %s%s" % [i, "• " if o.get("new", false) else "", o.text]
		var b := UITheme.button(label, _choose.bind(o))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 16)
		if String(o.text).begins_with("["):
			b.add_theme_color_override("font_color", UITheme.AMBER)
		_options.add_child(b)
		i += 1
	_options.visible = false


func _choose(o: Dictionary) -> void:
	var nxt := StorySystem.choose(_npc, o)
	match nxt:
		"":
			close()
		"@shop":
			UIManager.close(panel_name)
			UIManager.open("shop")
		"@radio":
			UIManager.close(panel_name)
			UIManager.open("radio")
		_:
			_go(nxt)


func _process(delta: float) -> void:
	if not visible:
		return
	if _text.visible_ratio < 1.0:
		_typing += delta
		var total := maxf(1.0, _text.text.length())
		_text.visible_ratio = minf(1.0, _typing * CHARS_PER_SEC / total)
		_blip_acc += delta
		if _blip_acc > 0.06:
			_blip_acc = 0.0
			AudioSystem.play("text_blip", 1.0 + randf_range(-0.08, 0.08))
		if _text.visible_ratio >= 1.0:
			_options.visible = true
	else:
		_options.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if _text.visible_ratio < 1.0:
			_text.visible_ratio = 1.0
			_options.visible = true
			get_viewport().set_input_as_handled()
		elif _current_opts.size() == 1 and event.is_action_pressed("interact"):
			_choose(_current_opts[0])
			get_viewport().set_input_as_handled()
		return
	for i in mini(_current_opts.size(), 9):
		if event.is_action_pressed("hotbar_%d" % (i + 1)) and _options.visible:
			_choose(_current_opts[i])
			get_viewport().set_input_as_handled()
			return
