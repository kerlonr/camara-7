class_name Interactable
extends Area2D
## Algo com que o jogador interage (tecla E). A ação é resolvida pelo ActionRouter.

var action: String = ""
var prompt: String = ""
var params: Dictionary = {}


func _init() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


static func create(p_action: String, p_prompt: String, size: Vector2, p_params: Dictionary = {}) -> Interactable:
	var it := Interactable.new()
	it.name = "Interact"
	it.action = p_action
	it.prompt = p_prompt
	it.params = p_params
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	it.add_child(cs)
	return it


func get_prompt() -> String:
	if action == "machine":
		return MachineSystem.status_text(params.get("machine", ""))
	return prompt


func interact() -> void:
	ActionRouter.perform(action, params, self)
