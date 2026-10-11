class_name Throwable
extends Node2D
## Objeto arremessado: voa em arco até o alvo e então:
##   flare    → acende uma luz vermelha por FLARE_TIME segundos (ilumina como no Darkwood)
##   dynamite → pavio de FUSE segundos e explosão que quebra rochas e machuca quem estiver perto

const FLIGHT_TIME := 0.45
const FLARE_TIME := 90.0
const FUSE := 2.0
const BLAST_RADIUS := 34.0
const BLAST_POWER := 14.0
const BLAST_TIER := 3
const PLAYER_DAMAGE := 22.0

var kind := "flare"
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _t := 0.0
var _landed := false
var _life := 0.0
var _light: FlickerLight
var _sparks: CPUParticles2D
var _sprite: Sprite2D


func setup(p_kind: String, from: Vector2, to: Vector2) -> void:
	kind = p_kind
	_from = from
	_to = to


func _ready() -> void:
	global_position = _from
	z_index = 3
	_sprite = Sprite2D.new()
	_sprite.texture = DataManager.texture(DataManager.get_item(kind).get("icon", ""))
	_sprite.scale = Vector2(0.75, 0.75)
	add_child(_sprite)
	_sparks = CPUParticles2D.new()
	_sparks.texture = DataManager.texture(Effects.PIXEL)
	_sparks.amount = 16
	_sparks.lifetime = 0.5
	_sparks.direction = Vector2(0, -1)
	_sparks.spread = 60.0
	_sparks.gravity = Vector2(0, 60)
	_sparks.initial_velocity_min = 12.0
	_sparks.initial_velocity_max = 30.0
	_sparks.scale_amount_min = 0.5
	_sparks.scale_amount_max = 0.5
	_sparks.color = Color("#ff5a40") if kind == "flare" else Color("#ffd27a")
	_sparks.emitting = kind == "dynamite"
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_sparks.material = mat
	add_child(_sparks)


func _process(delta: float) -> void:
	if not _landed:
		_t += delta / FLIGHT_TIME
		var k := minf(_t, 1.0)
		global_position = _from.lerp(_to, k) + Vector2(0, -sin(k * PI) * 18.0)
		_sprite.rotation += delta * 12.0
		if _t >= 1.0:
			_land()
		return
	_life += delta
	if kind == "flare":
		if _light:
			_light.base_energy = 1.4 * clampf((FLARE_TIME - _life) / 6.0, 0.0, 1.0)
		if _life >= FLARE_TIME:
			queue_free()
	elif kind == "dynamite" and _life >= FUSE:
		_explode()


func _land() -> void:
	_landed = true
	_sprite.rotation = 0.0
	AudioSystem.play_at("thud", global_position)
	if kind == "flare":
		add_to_group("flare_light")
		add_to_group("fire_source")       # cães não chegam perto; o Vulto queima
		_light = PropFactory.make_light({"color": "#ff3a28", "energy": 1.4, "scale": 1.3, "flicker": 0.35})
		_light.position = Vector2(0, -3)
		add_child(_light)
		_sparks.emitting = true
		AudioSystem.play_at("flare", global_position)
		EventBus.caption.emit("[sinalizador chiando]")
	else:
		AudioSystem.play_at("fuse", global_position)
		EventBus.caption.emit("[pavio queimando]")


func _explode() -> void:
	var pos := global_position
	var parent := get_parent()
	for body in get_tree().get_nodes_in_group("mineable"):
		if body.broken:
			continue
		var d: float = body.hit_center().distance_to(pos)
		if d <= BLAST_RADIUS:
			body.hit(BLAST_POWER * (1.0 - d / BLAST_RADIUS * 0.5), BLAST_TIER, (body.hit_center() - pos).normalized())
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p and p.global_position.distance_to(pos) < BLAST_RADIUS + 6.0:
		HealthSystem.damage(PLAYER_DAMAGE, "hp")
		AudioSystem.play("hurt")
	AudioSystem.play_at("explosion", pos)
	EventBus.caption.emit("[explosão]")
	EventBus.camera_shake.emit(4.0, 0.45)
	Effects.burst(parent, position, Color("#ffcf6a"), 26, 140.0, 0.5)
	Effects.dust(parent, position, 24)
	var flash := PropFactory.make_light({"color": "#ffd9a0", "energy": 2.5, "scale": 2.2})
	flash.global_position = pos
	parent.add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "base_energy", 0.0, 0.35)
	tw.tween_callback(flash.queue_free)
	queue_free()
