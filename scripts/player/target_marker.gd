extends Node2D
## Cantoneiras em volta da rocha mirada. Vermelho = ferramenta fraca demais.

var target: Node2D = null
var _t := 0.0


func _ready() -> void:
	top_level = true
	z_index = 30


func _process(delta: float) -> void:
	_t += delta
	visible = target != null and is_instance_valid(target) and not target.get("broken")
	if visible:
		global_position = target.hit_center().round()
	queue_redraw()


func _draw() -> void:
	if not visible or target == null or not is_instance_valid(target):
		return
	var ok: bool = target.can_mine(int(UpgradeSystem.get_stat("tool_tier", 1)))
	var col := Color("#e0b54a") if ok else Color("#e0604a")
	col.a = 0.65 + 0.35 * sin(_t * 8.0)
	var s := 9.0 + (0.0 if fmod(_t, 0.8) < 0.4 else 1.0)
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			var c := Vector2(sx * s, sy * s)
			draw_line(c, c + Vector2(-sx * 3, 0), col, 1.0)
			draw_line(c, c + Vector2(0, -sy * 3), col, 1.0)
