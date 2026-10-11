extends Node
## Raiz da partida: contém o mundo, HUD, pós-processamento, menus e o fade.

@onready var world_root: Node2D = $WorldRoot
@onready var menus: CanvasLayer = $Menus
@onready var fade_rect: ColorRect = $Fade/Rect
@onready var center_label: Label = $Fade/Label


func _ready() -> void:
	UIManager.clear_panels()
	var panels: Array = [InventoryPanel.new(), ShopPanel.new(), DialoguePanel.new()]
	panels.append_array(SimplePanels.create_all())
	panels.append_array(StoryPanels.create_all())
	panels.append_array(ProgressionPanels.create_all())
	for p in panels:
		menus.add_child(p)
		UIManager.register_panel(p.panel_name, p)
	fade_rect.color = Color(0, 0, 0, 1)
	center_label.theme = UITheme.get_theme()
	center_label.modulate.a = 0.0
	SceneManager.register_main(self)


func fade_out(t: float = 0.5) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, t)
	await tw.finished


func fade_in(t: float = 0.5) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, t)
	await tw.finished


func show_center_text(text: String, duration: float) -> void:
	center_label.text = text
	var tw := create_tween()
	tw.tween_property(center_label, "modulate:a", 1.0, 0.4)
	tw.tween_interval(duration)
	tw.tween_property(center_label, "modulate:a", 0.0, 0.4)
	await tw.finished
