class_name ItemSlot
extends Control
## Slot de inventário/hotbar desenhado à mão. Emite clicked(index, button).

signal clicked(index: int, button: int)
signal hovered(index: int)

const SLOT_TEX := "res://assets/ui/slot.png"
const SLOT_SEL_TEX := "res://assets/ui/slot_selected.png"

var index := 0
var selected := false
var held := false
var locked := false
var show_number := false


func _init() -> void:
	custom_minimum_size = Vector2(20, 20)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		clicked.emit(index, event.button_index)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		hovered.emit(index)


func _draw() -> void:
	draw_texture(DataManager.texture(SLOT_SEL_TEX if selected else SLOT_TEX), Vector2.ZERO)
	if locked:
		draw_rect(Rect2(2, 2, 16, 16), Color(0, 0, 0, 0.55))
		draw_line(Vector2(5, 5), Vector2(15, 15), Color("#3a3a30"), 1.0)
		return
	var s = InventorySystem.get_slot(index)
	var f := UITheme.font()
	if s != null:
		var item := DataManager.get_item(s.id)
		var icon_path: String = item.get("icon", "")
		if s.id == "pickaxe":
			icon_path = UpgradeSystem.get_stat("tool_sprite", icon_path)
		var icon := DataManager.texture(icon_path)
		var mod := Color(1, 1, 1, 0.35) if held else Color.WHITE
		if icon:
			draw_texture(icon, ((size - icon.get_size()) / 2.0).floor(), mod)
		if int(s.amount) > 1:
			var txt := str(s.amount)
			var pos := Vector2(19 - f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x, 19)
			draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color("#0b0a07"))
			draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#e8e2c8"))
		if float(item.get("radiation", 0.0)) > 0.0:
			draw_rect(Rect2(2, 2, 3, 3), Color("#8fe854"))
	if show_number:
		draw_string(f, Vector2(2, 8), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#8c8a78"))
