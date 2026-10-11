class_name NPC
extends Node2D
## NPC parado com animação de respiração. Vira para o jogador, mostra [!] quando
## tem conversa/missão nova e solta falas curtas (balões) quando você passa perto.
## Conversa completa: data/story/dialogues.json (StorySystem).

const BARK_RANGE := 44.0

var npc_id := ""
var data: Dictionary = {}

var _bubble: Label
var _indicator: Label
var _bark_cd := 0.0
var _check_t := 0.0
var _rng := RandomNumberGenerator.new()

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	_rng.randomize()
	data = DataManager.npcs.get(npc_id, {})
	sprite.sprite_frames = PlayerFrames.build_strip(data.get("sprite", ""), 16, 1.2)
	sprite.play("default")
	sprite.frame = _rng.randi() % 2
	var it := Interactable.create("talk", "Falar com %s" % data.get("name", "?"), Vector2(20, 22), {"npc": npc_id})
	it.position = Vector2(0, -10)
	add_child(it)
	_indicator = _make_label("!", UITheme.AMBER, 16)
	_indicator.position = Vector2(-20, -50)
	add_child(_indicator)
	_bubble = _make_label("", UITheme.TEXT, 10)
	_bubble.position = Vector2(-60, -52)
	_bubble.modulate.a = 0.0
	add_child(_bubble)
	_bark_cd = _rng.randf_range(1.0, 4.0)
	_refresh_indicator()


func _make_label(text: String, color: Color, size: int) -> Label:
	var l := Label.new()
	l.theme = UITheme.get_theme()
	l.text = text
	l.size = Vector2(40 if text == "!" else 120, 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color("#0b0a07"))
	l.z_index = 30
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	l.material = mat
	return l


func _refresh_indicator() -> void:
	_indicator.visible = StorySystem.npc_has_news(npc_id)


func _process(delta: float) -> void:
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 0.5
		_refresh_indicator()
	if _indicator.visible:
		_indicator.position.y = -50 + round(sin(Time.get_ticks_msec() / 220.0) * 1.5)
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return
	var d := p.global_position.distance_to(global_position)
	if d < 48.0:
		sprite.flip_h = p.global_position.x < global_position.x
	_bark_cd -= delta
	if d < BARK_RANGE and _bark_cd <= 0.0 and not _indicator.visible:
		_bark_cd = _rng.randf_range(12.0, 22.0)
		_bark()


func _bark() -> void:
	var pool := []
	for b in data.get("barks", []):
		if Conditions.check(b.get("if", [])):
			pool.append(b.text)
	if pool.is_empty():
		return
	_bubble.text = pool[_rng.randi_range(0, pool.size() - 1)]
	var tw := create_tween()
	tw.tween_property(_bubble, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.6)
	tw.tween_property(_bubble, "modulate:a", 0.0, 0.5)


func _draw() -> void:
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.35))
