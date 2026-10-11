extends Node
## Registra as ações de entrada a partir de data/config/controls.json.
## Facilita remapeamento futuro (menu de opções) sem editar project.godot.

const MOUSE_BUTTONS := {1: MOUSE_BUTTON_LEFT, 2: MOUSE_BUTTON_RIGHT, 3: MOUSE_BUTTON_MIDDLE}


func _ready() -> void:
	apply(DataManager.controls)


func apply(map: Dictionary) -> void:
	for action in map:
		if action.begins_with("_"):
			continue
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, 0.2)
		for binding in map[action]:
			var ev := _make_event(binding)
			if ev:
				InputMap.action_add_event(action, ev)


func _make_event(binding: Dictionary) -> InputEvent:
	if binding.has("key"):
		var code := OS.find_keycode_from_string(String(binding.key))
		if code == KEY_NONE:
			push_warning("[Controls] tecla desconhecida: %s" % binding.key)
			return null
		var k := InputEventKey.new()
		k.physical_keycode = code
		return k
	if binding.has("mouse"):
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTONS.get(int(binding.mouse), MOUSE_BUTTON_LEFT)
		return m
	return null
