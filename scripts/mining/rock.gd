class_name Rock
extends StaticBody2D
## Rocha/minério ou contêiner quebrável. Dados vêm de data/ores/ores.json.
## Feedback: tremor, flash, rachaduras, partículas, número, som, hit-stop, drops físicos.

const HIT_CENTER := Vector2(0, -7)
const CRACKS := ["", "res://assets/environment/rocks/cracks_1.png",
	"res://assets/environment/rocks/cracks_2.png", "res://assets/environment/rocks/cracks_3.png"]
const PICKUP_SCENE := preload("res://scenes/mining/pickup.tscn")
const LIGHT_TEXTURE := "res://assets/effects/light_bands.png"

var data: Dictionary = {}
var is_container := false
var depth := 1
var hp := 1.0
var max_hp := 1.0
var broken := false
var rich := false

var _rng := RandomNumberGenerator.new()
var _shake_tw: Tween

@onready var sprite: Sprite2D = $Sprite
@onready var cracks: Sprite2D = $Sprite/Cracks


func setup(d: Dictionary, container: bool, at_depth: int, seed_value: int, p_rich: bool = false) -> void:
	data = d
	is_container = container
	depth = at_depth
	rich = p_rich
	_rng.seed = seed_value
	hp = float(d.get("hp", 2))
	if not container:
		hp = maxf(1.0, round(hp * _rng.randf_range(0.8, 1.2)))
	if rich:
		hp = ceil(hp * 1.4)
	max_hp = hp


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	add_to_group("mineable")
	var sprites: Array = data.get("sprites", [data.get("sprite", "")])
	sprite.texture = DataManager.texture(sprites[_rng.randi() % sprites.size()])
	if sprite.texture:   # âncora pelo pé, qualquer tamanho (a arte pode ter margem para o contorno)
		var ts := sprite.texture.get_size()
		sprite.offset = Vector2(-floorf(ts.x / 2.0), -ts.y)
	sprite.flip_h = not is_container and _rng.randf() < 0.5
	var strength := float(data.get("radiation", 0.0))
	if strength > 0.0:
		add_to_group("rad_source")
		set_meta("strength", strength)
	if rich:
		var sp := Sparkle.new()
		sp.position = HIT_CENTER
		add_child(sp)
	if data.has("glow") or rich:
		var l := FlickerLight.new()
		l.texture = DataManager.texture(LIGHT_TEXTURE)
		l.color = Color(data.get("glow", "#ffe6a0"))
		l.base_energy = 0.55
		l.texture_scale = 0.32
		l.flicker = 0.05
		l.position = HIT_CENTER
		add_child(l)


func display_name() -> String:
	return String(data.get("name", "rocha")).to_lower()


func hit_center() -> Vector2:
	return global_position + HIT_CENTER


func min_tier() -> int:
	return int(data.get("min_tier", 1))


func can_mine(tier: int) -> bool:
	return tier >= min_tier()


func hit(power: float, tier: int, from_dir: Vector2) -> String:
	if broken:
		return "none"
	var parent := get_parent()
	if not can_mine(tier):
		AudioSystem.play_at("hit_fail", hit_center())
		Effects.sparks(parent, hit_center() - from_dir * 4.0)
		Effects.float_text(parent, hit_center() + Vector2(0, -6), "FERRAMENTA NV %d" % min_tier(), UITheme.DANGER, 10)
		_shake(1.0)
		return "fail"
	hp -= power
	var metal: bool = data.get("metal", false)
	if is_container:
		AudioSystem.play_at("hit_rock", hit_center(), 1.4)
	else:
		AudioSystem.play_at("hit_rock", hit_center(), 1.0)
		if metal:
			AudioSystem.play_at("hit_metal", hit_center(), 1.0, -4.0)
	_flash()
	_shake(2.0)
	var col := Color(data.get("particle_color", "#6a625a"))
	Effects.burst(parent, hit_center() - from_dir * 3.0, col, 5, 70.0)
	Effects.dust(parent, hit_center(), 2)
	if Settings.get_v("damage_numbers"):
		Effects.float_text(parent, hit_center() + Vector2(0, -8), str(snappedf(power, 0.1)).trim_suffix(".0"), Color("#e8e2c8"), 10)
	EventBus.camera_shake.emit(0.7, 0.07)
	if hp <= 0.0:
		_break(from_dir)
		return "break"
	var stage := clampi(int(ceil((1.0 - hp / max_hp) * 3.0)), 0, 3)
	cracks.texture = DataManager.texture(CRACKS[stage]) if stage > 0 else null
	return "hit"


func _flash() -> void:
	if not Settings.get_v("flashes"):
		return
	sprite.modulate = Color(2.6, 2.6, 2.4)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.09)


func _shake(strength: float) -> void:
	if _shake_tw:
		_shake_tw.kill()
	_shake_tw = create_tween()
	for i in 3:
		var off := Vector2(_rng.randf_range(-strength, strength), _rng.randf_range(-strength * 0.5, strength * 0.5))
		_shake_tw.tween_property(sprite, "position", off, 0.025)
	_shake_tw.tween_property(sprite, "position", Vector2.ZERO, 0.03)


func _break(from_dir: Vector2) -> void:
	broken = true
	remove_from_group("mineable")
	set_deferred("collision_layer", 0)
	remove_from_group("rad_source")
	var parent := get_parent()
	var pos := hit_center()
	AudioSystem.play_at(data.get("sound", "rock_break"), pos)
	var col := Color(data.get("particle_color", "#6a625a"))
	Effects.burst(parent, pos, col, 14, 95.0, 0.7)
	Effects.burst(parent, pos, col.lightened(0.25), 6, 50.0, 0.5)
	Effects.dust(parent, pos + Vector2(0, 4), 10)
	EventBus.camera_shake.emit(2.0, 0.14)
	Effects.hitstop(get_tree(), 0.035)
	_spawn_drops()
	ProgressionSystem.add_xp(int(data.get("xp", 1)), "rock")
	ProgressionSystem.discover(String(data.get("id", "")))
	EventBus.rock_broken.emit(String(data.get("id", "")), pos)
	GameState.add_stat("rocks_broken")
	cracks.texture = null
	for c in get_children():
		if c is PointLight2D:
			c.queue_free()
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.25, 0.4), 0.06)
	tw.parallel().tween_property(sprite, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)


func _spawn_drops() -> void:
	var drops: Dictionary = {}
	if is_container:
		for _roll in 1 + int(UpgradeSystem.get_stat("crate_bonus", 0)):
			var loot := _roll_loot(data.get("loot", []))
			if loot.item == "@note":
				var note := GameState.random_note(_rng, depth)
				if note != "":
					_spawn_note(note)
				else:
					drops["scrap"] = int(drops.get("scrap", 0)) + 1
			elif loot.item != "":
				drops[loot.item] = int(drops.get(loot.item, 0)) + _rng.randi_range(int(loot.get("min", 1)), int(loot.get("max", 1)))
	elif data.has("loot"):
		var rolls: Array = data.get("loot_rolls", [2, 3])
		for _r in _rng.randi_range(int(rolls[0]), int(rolls[1])):
			var l := _roll_loot(data.loot)
			if l.item != "":
				drops[l.item] = int(drops.get(l.item, 0)) + 1
	else:
		var item_id: String = data.get("drop", "")
		if item_id != "":
			drops[item_id] = _rng.randi_range(int(data.get("drop_min", 1)), int(data.get("drop_max", 1)))
			if rich:
				drops[item_id] = int(round((drops[item_id] * 2 + 1) * float(UpgradeSystem.get_stat("rich_yield", 1.0))))
		for extra in data.get("extra", []):
			if _rng.randf() < float(extra.chance):
				drops[extra.item] = int(drops.get(extra.item, 0)) + 1
	var rare := false
	for item_id in drops:
		if DataManager.get_item(item_id).get("rarity", "common") in ["rare", "very_rare"]:
			rare = true
		for i in int(drops[item_id]):
			var p: Node2D = PICKUP_SCENE.instantiate()
			p.setup(item_id, 1, _rng)
			p.position = position + Vector2(0, -2)
			get_parent().add_child(p)
	if rare or rich or data.has("loot"):
		AudioSystem.play("rare_find")
		Effects.float_text(get_parent(), hit_center() + Vector2(0, -12), "ACHADO RARO" if rare else "VEIO RICO", UITheme.AMBER, 10)


func _roll_loot(table: Array) -> Dictionary:
	var valid := []
	var total := 0.0
	for e in table:
		if int(e.get("min_depth", 0)) <= depth:
			valid.append(e)
			total += float(e.weight)
	var r := _rng.randf() * total
	for e in valid:
		r -= float(e.weight)
		if r <= 0.0:
			return e
	return {"item": ""}


func _spawn_note(note_id: String) -> void:
	var area := SceneManager.current_area
	if area == null:
		return
	var prop: Node2D = PropFactory.create("documents")
	prop.position = position
	area.floor_decor.add_child(prop)
	var it := Interactable.create("note", "Ler: documento", Vector2(18, 14), {"note": note_id, "consume": true})
	it.position = Vector2(0, -6)
	prop.add_child(it)
	Effects.float_text(get_parent(), hit_center() + Vector2(0, -10), "DOCUMENTO", UITheme.AMBER, 10)
