class_name MachineNode
extends Node2D
## Representação visual de uma máquina da base. Estado e regras ficam no MachineSystem;
## este nó só mostra plataforma vazia / máquina parada / máquina funcionando.

var machine_id := ""
var data: Dictionary = {}

var _sprite: Sprite2D
var _body: StaticBody2D
var _audio: AudioStreamPlayer2D
var _smoke: CPUParticles2D
var _anim_t := 0.0


func _ready() -> void:
	data = DataManager.machines.get(machine_id, {})
	var tex := DataManager.texture(data.get("sprite", ""))
	var frames := int(data.get("frames", 1))
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.hframes = frames
	_sprite.centered = false
	_sprite.offset = Vector2(-tex.get_width() / frames / 2.0, -tex.get_height() - 2)
	add_child(_sprite)
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	var col: Array = data.get("collision", [24, 10])
	r.size = Vector2(col[0], col[1])
	cs.shape = r
	cs.position = Vector2(0, -float(col[1]) / 2.0 - 3)
	_body.add_child(cs)
	add_child(_body)
	_audio = AudioStreamPlayer2D.new()
	_audio.stream = AudioSystem.loop_stream(data.get("sound", ""))
	_audio.volume_db = AudioSystem.loop_volume(data.get("sound", ""))
	_audio.max_distance = 220.0
	_audio.bus = "Ambient"
	add_child(_audio)
	if data.get("kind", "") == "generator":
		_smoke = CPUParticles2D.new()
		_smoke.texture = DataManager.texture(Effects.PIXEL)
		_smoke.amount = 14
		_smoke.lifetime = 1.8
		_smoke.direction = Vector2(0.3, -1)
		_smoke.spread = 15.0
		_smoke.gravity = Vector2(4, -6)
		_smoke.initial_velocity_min = 10.0
		_smoke.initial_velocity_max = 18.0
		_smoke.scale_amount_min = 1.0
		_smoke.scale_amount_max = 2.0
		_smoke.color = Color(0.3, 0.3, 0.28, 0.55)
		_smoke.position = Vector2(-9, -32)
		_smoke.emitting = false
		add_child(_smoke)
	var it := Interactable.create("machine", "", Vector2(30, 22), {"machine": machine_id})
	it.position = Vector2(0, -8)
	add_child(it)
	EventBus.machine_changed.connect(func(_id): _refresh())
	EventBus.upgrade_purchased.connect(func(_a, _b): _refresh())
	_refresh()


func _refresh() -> void:
	var owned := MachineSystem.is_owned(machine_id)
	_sprite.visible = owned
	_body.process_mode = Node.PROCESS_MODE_INHERIT if owned else Node.PROCESS_MODE_DISABLED
	_body.collision_layer = 1 if owned else 0
	var running := MachineSystem.is_running(machine_id)
	if running and not _audio.playing:
		_audio.play()
	elif not running and _audio.playing:
		_audio.stop()
	if _smoke:
		_smoke.emitting = running
	if not running:
		_sprite.frame = 0
	var p := get_tree().get_first_node_in_group("player")
	if p:
		p.refresh_prompt()


func _process(delta: float) -> void:
	if not _sprite.visible or not MachineSystem.is_running(machine_id):
		_sprite.position = Vector2.ZERO
		return
	_anim_t += delta
	if _sprite.hframes > 1:
		_sprite.frame = int(_anim_t * 6.0) % _sprite.hframes
	_sprite.position = Vector2(0, -1 if fmod(_anim_t, 0.12) < 0.06 else 0)
