class_name Pickup
extends Node2D
## Item físico no chão: salta em arco, quica, e é puxado pelo jogador (ímã).

const GRAVITY := 420.0
const ARM_TIME := 0.35
const COMBO_WINDOW := 0.6

static var _combo := 0
static var _last_pick_ms := 0
static var _full_warned_ms := -10000

var item_id := ""
var amount := 1

var _vel := Vector2.ZERO
var _z := 0.0
var _vz := 0.0
var _age := 0.0
var _magnet := false
var _speed := 40.0

@onready var sprite: Sprite2D = $Sprite


func setup(id: String, n: int, rng: RandomNumberGenerator) -> void:
	item_id = id
	amount = n
	var ang := rng.randf_range(0, TAU)
	_vel = Vector2(cos(ang), sin(ang) * 0.6) * rng.randf_range(14.0, 34.0)
	_vz = rng.randf_range(70.0, 110.0)
	_z = 2.0


func _ready() -> void:
	sprite.texture = DataManager.texture(DataManager.get_item(item_id).get("icon", ""))
	z_index = 1


func _physics_process(delta: float) -> void:
	_age += delta
	if _z > 0.0 or _vz > 0.0:
		_vz -= GRAVITY * delta
		_z += _vz * delta
		position += _vel * delta
		if _z <= 0.0:
			_z = 0.0
			if absf(_vz) > 45.0:
				_vz = -_vz * 0.35
				_vel *= 0.5
			else:
				_vz = 0.0
				_vel = Vector2.ZERO
	var bob := 0.0 if _z > 0.0 else sin(_age * 4.0) * 0.8
	sprite.position = Vector2(-8, -14 - _z + bob).round()
	queue_redraw()
	if _age < ARM_TIME:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var target := player.global_position + Vector2(0, -4)
	var d := global_position.distance_to(target)
	if not _magnet and d < float(UpgradeSystem.get_stat("pickup_radius", 30.0)):
		if InventorySystem.can_add(item_id, 1):
			_magnet = true
		elif Time.get_ticks_msec() - _full_warned_ms > 4000:
			_full_warned_ms = Time.get_ticks_msec()
			EventBus.toast.emit("Mochila cheia!", "warn")
			StorySystem.hint("inventory_full")
	if _magnet:
		_speed += 520.0 * delta
		global_position = global_position.move_toward(target, _speed * delta)
		if global_position.distance_to(target) < 5.0:
			_collect()


func _collect() -> void:
	var left := InventorySystem.add_item(item_id, amount)
	var got := amount - left
	if got > 0:
		var now := Time.get_ticks_msec()
		_combo = _combo + 1 if now - _last_pick_ms < COMBO_WINDOW * 1000 else 0
		_last_pick_ms = now
		AudioSystem.play("pickup", 1.0 + mini(_combo, 10) * 0.06)
		EventBus.item_collected.emit(item_id, got)
	if left == 0:
		queue_free()
	else:
		amount = left
		_magnet = false
		_speed = 40.0


func _draw() -> void:
	var s := clampf(1.0 - _z / 30.0, 0.4, 1.0)
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 4.0 * s, Color(0, 0, 0, 0.35))
