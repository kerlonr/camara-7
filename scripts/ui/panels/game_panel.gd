class_name GamePanel
extends Control
## Base dos painéis modais: fundo escurecido + caixa central com animação curta.
## Subclasses definem panel_name e implementam _build() e open(args).

var panel_name := ""
var box: PanelContainer
var content: VBoxContainer
var dim_alpha := 0.6
var _dim: ColorRect


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.015, dim_alpha)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	box = PanelContainer.new()
	center.add_child(box)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	box.add_child(content)
	_build()
	visibility_changed.connect(_on_visibility)


func _on_visibility() -> void:
	if visible:
		box.pivot_offset = box.size / 2.0
		box.scale = Vector2(0.97, 0.97)
		modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "modulate:a", 1.0, 0.12)
		tw.tween_property(box, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _build() -> void:
	pass


func open(_args: Dictionary) -> void:
	pass


func close() -> void:
	if UIManager.panels.get(panel_name) == self:
		UIManager.close(panel_name)
	else:
		visible = false
		if has_method("on_close"):
			call("on_close")


func header(text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.theme_type_variation = "HeaderLabel"
	l.text = text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var x := UITheme.button("X", close)
	x.tooltip_text = "Fechar (ESC)"
	h.add_child(x)
	return h


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func icon(path: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = DataManager.texture(path)
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	t.custom_minimum_size = Vector2(16, 16)
	return t
