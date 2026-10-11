class_name MenuList
extends VBoxContainer
## Menu em lista de texto (estilo terminal/RPG antigo): cursor "▶", faixa de destaque,
## navegação por setas/W-S + Enter/E ou mouse. Itens têm tamanho fixo — nada pula ao passar o mouse.

signal activated(id: String)

const ROW_H := 16

var width := 170
var _items: Array = []          # {id, row, label, sub, cb, disabled}
var _sel := 0


func _init(p_width: int = 170) -> void:
	width = p_width
	add_theme_constant_override("separation", 1)
	custom_minimum_size.x = width
	focus_mode = Control.FOCUS_ALL


func add_item(id: String, text: String, cb: Callable, sub: String = "", disabled := false) -> void:
	var row := Control.new()
	row.custom_minimum_size = Vector2(width, ROW_H + 2 + (10 if sub != "" else 0))
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(row)
	var lbl := UITheme.label(text, 16, UITheme.TEXT_DIM if not disabled else Color(0.4, 0.4, 0.36), true)
	lbl.position = Vector2(14, 1)          # VT323 desenha as maiúsculas um pouco acima do centro da linha
	lbl.size = Vector2(width - 16, ROW_H)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.clip_text = true
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	var sl: Label = null
	if sub != "":
		sl = UITheme.label(sub, 10, UITheme.TEXT_DIM, true)
		sl.position = Vector2(14, ROW_H)
		sl.size = Vector2(width - 16, 10)
		sl.clip_text = true
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sl)
	var idx := _items.size()
	var f := UITheme.font()
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	if sub != "":
		tw = maxf(tw, f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x)
	_items.append({"id": id, "row": row, "label": lbl, "sub": sl, "cb": cb, "disabled": disabled,
		"text_w": minf(width - 14.0, tw)})
	row.mouse_entered.connect(func(): _select(idx, true))
	row.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_select(idx, false)
			_activate())
	row.draw.connect(_draw_row.bind(idx))
	if _items.size() == 1 or (_items[_sel].disabled and not disabled):
		_sel = idx
	_refresh()


func select_id(id: String) -> void:
	for i in _items.size():
		if _items[i].id == id:
			_select(i, false)


func _select(i: int, sound: bool) -> void:
	if i == _sel or _items[i].disabled:
		return
	_sel = i
	if sound:
		AudioSystem.play("ui_hover")
	_refresh()


func _refresh() -> void:
	for i in _items.size():
		var it: Dictionary = _items[i]
		var on: bool = i == _sel and not it.disabled
		if not it.disabled:
			it.label.add_theme_color_override("font_color", UITheme.AMBER if on else UITheme.TEXT_DIM)
		it.row.queue_redraw()


func _draw_row(i: int) -> void:
	var it: Dictionary = _items[i]
	var row: Control = it.row
	if i != _sel or it.disabled:
		return
	# faixa justa no texto (e no subtítulo, se houver), com o cursor centralizado na linha principal
	var h := row.size.y
	var bar_w := minf(width, 14.0 + float(it.text_w) + 8.0)
	row.draw_rect(Rect2(0, 0, bar_w, h), Color(0.82, 0.65, 0.2, 0.12))
	row.draw_rect(Rect2(0, 0, 2, h), UITheme.AMBER)
	row.draw_rect(Rect2(bar_w - 1, 0, 1, h), Color(0.82, 0.65, 0.2, 0.35))
	var y := 1.0 + ROW_H / 2.0
	row.draw_colored_polygon(PackedVector2Array([Vector2(5, y - 3), Vector2(9, y), Vector2(5, y + 3)]), UITheme.AMBER)


func _activate() -> void:
	var it: Dictionary = _items[_sel]
	if it.disabled:
		AudioSystem.play("ui_error")
		return
	AudioSystem.play("ui_click")
	activated.emit(it.id)
	if it.cb.is_valid():
		it.cb.call()


func _move(d: int) -> void:
	if _items.is_empty():
		return
	var i := _sel
	for k in _items.size():
		i = posmod(i + d, _items.size())
		if not _items[i].disabled:
			break
	_select(i, true)


## Só o menu do painel do topo da pilha responde ao teclado.
func _is_on_top() -> bool:
	var n := get_parent()
	while n:
		if n is GamePanel:
			var st: Array = UIManager.stack
			return st.is_empty() or st.back() == (n as GamePanel).panel_name or not UIManager.panels.has((n as GamePanel).panel_name)
		n = n.get_parent()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _items.is_empty() or not _is_on_top():
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_move(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		_move(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_activate()
		get_viewport().set_input_as_handled()
