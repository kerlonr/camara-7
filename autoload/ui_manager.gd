extends Node
## Pilha de painéis modais. Com qualquer painel aberto o jogo pausa
## (os painéis rodam com PROCESS_MODE_ALWAYS).

var panels: Dictionary = {}
var stack: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.theme = UITheme.get_theme()
	_set_cursor()


func _set_cursor() -> void:
	var path := "res://assets/ui/cursor.png"
	if ResourceLoader.exists(path):
		Input.set_custom_mouse_cursor(load(path), Input.CURSOR_ARROW, Vector2(1, 1))


func register_panel(panel_name: String, panel: Control) -> void:
	panels[panel_name] = panel
	panel.visible = false


func clear_panels() -> void:
	panels = {}
	stack = []


func is_open(panel_name: String = "") -> bool:
	if panel_name == "":
		return not stack.is_empty()
	return stack.has(panel_name)


func top() -> String:
	return stack.back() if not stack.is_empty() else ""


func open(panel_name: String, args: Dictionary = {}) -> void:
	if not panels.has(panel_name) or SceneManager.busy:
		return
	if stack.has(panel_name):
		stack.erase(panel_name)
	stack.append(panel_name)
	var p: Control = panels[panel_name]
	p.visible = true
	if p.has_method("open"):
		p.open(args)
	_update_pause()
	EventBus.interact_prompt_changed.emit("")


func close(panel_name: String) -> void:
	if not stack.has(panel_name):
		return
	stack.erase(panel_name)
	var p: Control = panels.get(panel_name)
	if p:
		if p.has_method("on_close"):
			p.on_close()
		p.visible = false
	_update_pause()
	if panel_name == "cutscene":
		ProgressionSystem.maybe_offer_trait.call_deferred()


func close_top() -> void:
	if not stack.is_empty():
		close(stack.back())


func close_all() -> void:
	while not stack.is_empty():
		close_top()


func _update_pause() -> void:
	get_tree().paused = not stack.is_empty()
	# menus que não são "mundo" abafam o som; cenas e diálogos mantêm o clima
	var muffle := false
	for p in stack:
		if p in ["pause", "inventory", "shop", "journal", "options", "perks", "craft"]:
			muffle = true
	Settings.set_muffled(muffle)


func _unhandled_input(event: InputEvent) -> void:
	if SceneManager.main == null or SceneManager.busy:
		return
	if event.is_action_pressed("pause"):
		if stack.is_empty():
			open("pause")
		else:
			AudioSystem.play("ui_click")
			close_top()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("perks"):
		if top() == "perks":
			close("perks")
		elif stack.is_empty():
			open("perks")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("journal"):
		if top() == "journal":
			close("journal")
		elif stack.is_empty():
			open("journal")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		if top() == "inventory":
			close("inventory")
		elif stack.is_empty():
			open("inventory")
		get_viewport().set_input_as_handled()
