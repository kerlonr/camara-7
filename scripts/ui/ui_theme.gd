class_name UITheme
extends RefCounted
## Tema industrial/CRT construído em código a partir das texturas em assets/ui.
## Trocar o visual = substituir os PNGs ou ajustar as cores abaixo.

const FONT_PATH := "res://assets/fonts/VT323-Regular.ttf"

const TEXT := Color("#d6d2bd")
const TEXT_DIM := Color("#8c8a78")
const AMBER := Color("#e0b54a")
const CRT_GREEN := Color("#8fe08a")
const CRT_DIM := Color("#4f8a52")
const DANGER := Color("#e0604a")
const GOOD := Color("#9bd06a")
const WARN := Color("#e8a33c")
const OUTLINE := Color("#0b0a07")

static var _font: Font
static var _theme: Theme


## Tema compartilhado (aplicar na raiz de cada árvore de UI).
static func get_theme() -> Theme:
	if _theme == null:
		_theme = build()
	return _theme


static func font() -> Font:
	if _font == null:
		var f := load(FONT_PATH) as FontFile
		if f:
			f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			f.hinting = TextServer.HINTING_NONE
			# VT323 não tem cirílico: Pixelify Sans (OFL) cobre placas, rádio e notas em russo/ucraniano
			var cyr := load("res://assets/fonts/PixelifySans.ttf") as FontFile
			if cyr:
				cyr.antialiasing = TextServer.FONT_ANTIALIASING_NONE
				cyr.hinting = TextServer.HINTING_NONE
				f.fallbacks = [cyr]
			_font = f
		else:
			_font = ThemeDB.fallback_font
	return _font


static func _tex_box(path: String, margin: int, content: Vector4) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	return sb


static func flat(bg: Color, border: Color = Color.TRANSPARENT, bw: int = 0, pad: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_content_margin_all(pad)
	return sb


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 16

	var panel := _tex_box("res://assets/ui/panel.png", 7, Vector4(8, 6, 8, 6))
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)

	t.add_type("CRTPanel")
	t.set_type_variation("CRTPanel", "PanelContainer")
	t.set_stylebox("panel", "CRTPanel", _tex_box("res://assets/ui/crt.png", 4, Vector4(6, 4, 6, 4)))

	t.add_type("HudPlate")
	t.set_type_variation("HudPlate", "PanelContainer")
	t.set_stylebox("panel", "HudPlate", _tex_box("res://assets/ui/plate.png", 4, Vector4(4, 3, 4, 3)))

	t.add_type("PaperPanel")
	t.set_type_variation("PaperPanel", "PanelContainer")
	t.set_stylebox("panel", "PaperPanel", flat(Color("#cfc7ab"), Color("#5a5446"), 1, 8))

	var b := Vector4(6, 1, 6, 2)
	t.set_stylebox("normal", "Button", _tex_box("res://assets/ui/button.png", 3, b))
	t.set_stylebox("hover", "Button", _tex_box("res://assets/ui/button_hover.png", 3, b))
	t.set_stylebox("pressed", "Button", _tex_box("res://assets/ui/button_pressed.png", 3, b))
	t.set_stylebox("disabled", "Button", _tex_box("res://assets/ui/button_disabled.png", 3, b))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", AMBER)
	t.set_color("font_pressed_color", "Button", AMBER)
	t.set_color("font_disabled_color", "Button", Color("#6a6858"))
	t.set_color("font_focus_color", "Button", TEXT)

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", OUTLINE)
	t.set_constant("outline_size", "Label", 0)
	t.set_constant("line_spacing", "Label", -2)

	t.add_type("HeaderLabel")
	t.set_type_variation("HeaderLabel", "Label")
	t.set_color("font_color", "HeaderLabel", AMBER)
	t.set_font_size("font_size", "HeaderLabel", 20)

	t.add_type("DimLabel")
	t.set_type_variation("DimLabel", "Label")
	t.set_color("font_color", "DimLabel", TEXT_DIM)

	t.add_type("CRTLabel")
	t.set_type_variation("CRTLabel", "Label")
	t.set_color("font_color", "CRTLabel", CRT_GREEN)

	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_constant("line_separation", "RichTextLabel", -2)

	t.set_stylebox("normal", "LineEdit", flat(Color("#0d120d"), Color("#3b3f31"), 1, 3))
	t.set_stylebox("focus", "LineEdit", flat(Color("#0d120d"), AMBER, 1, 3))
	t.set_color("font_color", "LineEdit", CRT_GREEN)
	t.set_color("caret_color", "LineEdit", CRT_GREEN)

	var grab := flat(Color("#5a604a"))
	t.set_stylebox("scroll", "VScrollBar", flat(Color("#15160f"), Color.TRANSPARENT, 0, 1))
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", flat(Color("#7a8260")))
	t.set_stylebox("grabber_pressed", "VScrollBar", flat(AMBER))

	t.set_stylebox("slider", "HSlider", flat(Color("#15160f"), Color("#3b3f31"), 1, 2))
	t.set_stylebox("grabber_area", "HSlider", flat(Color("#8a6a1c")))
	t.set_stylebox("grabber_area_highlight", "HSlider", flat(AMBER))
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", AMBER)
	t.set_color("font_pressed_color", "CheckBox", TEXT)
	t.set_stylebox("panel", "TooltipPanel", flat(Color("#141510"), Color("#5a5f4a"), 1, 4))
	t.set_color("font_color", "TooltipLabel", TEXT)

	t.set_stylebox("tab_selected", "TabBar", flat(Color("#3b3f31"), AMBER, 1, 4))
	t.set_stylebox("tab_unselected", "TabBar", flat(Color("#1d1f17"), Color("#3b3f31"), 1, 4))
	t.set_stylebox("tab_hovered", "TabBar", flat(Color("#2c2f24"), Color("#5a5f4a"), 1, 4))
	t.set_color("font_selected_color", "TabBar", AMBER)
	t.set_color("font_unselected_color", "TabBar", TEXT_DIM)
	t.set_color("font_hovered_color", "TabBar", TEXT)
	return t


## Label pronto com tamanho/cor opcionais.
static func label(text: String, size: int = 16, color: Color = TEXT, outline: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_constant_override("outline_size", 4)
		l.add_theme_color_override("font_outline_color", OUTLINE)
	return l


static func button(text: String, cb: Callable, min_w: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.x = min_w
	b.pressed.connect(func(): AudioSystem.play("ui_click"))
	b.mouse_entered.connect(func(): if not b.disabled: AudioSystem.play("ui_hover"))
	b.pressed.connect(cb)
	return b


static func kind_color(kind: String) -> Color:
	match kind:
		"good": return GOOD
		"warn": return WARN
		"danger": return DANGER
		"item": return AMBER
	return TEXT
