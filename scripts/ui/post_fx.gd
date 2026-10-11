class_name PostFX
extends ColorRect
## Controla o shader de pós-processamento a partir de atmosphere.json e do estado do jogo.

const SHADER := preload("res://shaders/post_fx.gdshader")

var _mat: ShaderMaterial
var _hurt := 0.0
var _last_hp := -1.0
var _raining := false
var _dread := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	var post: Dictionary = DataManager.atmosphere.get("post", {})
	_mat.set_shader_parameter("saturation", float(post.get("saturation", 0.62)))
	_mat.set_shader_parameter("contrast", float(post.get("contrast", 1.08)))
	_mat.set_shader_parameter("vignette", float(post.get("vignette", 0.55)))
	_mat.set_shader_parameter("grain", float(post.get("grain", 0.05)))
	_mat.set_shader_parameter("tint", Color(post.get("tint", "#e8ece0")))
	_mat.set_shader_parameter("fog_color", Color(post.get("fog_color", "#9aa39a")))
	_mat.set_shader_parameter("shadow_tint", Color(post.get("shadow_tint", "#d2ebfa")))
	_mat.set_shader_parameter("light_tint", Color(post.get("light_tint", "#fff2d8")))
	EventBus.vitals_changed.connect(_on_vitals)
	EventBus.weather_changed.connect(func(s): _raining = s == "rain")
	EventBus.location_changed.connect(func(_l, _d): _raining = false if GameState.location == "mine" else _raining)


func _on_vitals() -> void:
	if _last_hp >= 0.0 and HealthSystem.hp < _last_hp - 0.5 and Settings.get_v("flashes"):
		_hurt = 1.0
	_last_hp = HealthSystem.hp


func _process(delta: float) -> void:
	var post: Dictionary = DataManager.atmosphere.get("post", {})
	var fog := float(post.get("mine_fog", 0.08)) if GameState.location == "mine" else float(post.get("surface_fog", 0.22))
	if _raining and GameState.location != "mine":
		fog += 0.1
	var area = SceneManager.current_area
	if area and is_instance_valid(area) and area.get("fog_extra") != null:
		fog += float(area.fog_extra)
	_mat.set_shader_parameter("fog", fog)
	_mat.set_shader_parameter("virtual_size", get_viewport_rect().size)
	var rad := clampf(RadiationSystem.rate * 2.2, 0.0, 1.0) if RadiationSystem.active else 0.0
	_mat.set_shader_parameter("rad", rad)
	_hurt = maxf(0.0, _hurt - delta * 2.5)
	_mat.set_shader_parameter("hurt", _hurt)
	# pavor: vida baixa, exposição alta e profundidade fecham a visão e fazem a vinheta pulsar
	var hp_k := 1.0 - HealthSystem.hp / maxf(1.0, HealthSystem.max_hp())
	var target := clampf(maxf(hp_k - 0.45, 0.0) * 1.6 + maxf(RadiationSystem.exposure - 55.0, 0.0) / 60.0, 0.0, 1.0)
	if GameState.location == "mine":
		target = maxf(target, clampf(GameState.depth / 40.0, 0.0, 0.35))
	_dread = move_toward(_dread, target, delta * 0.5)
	_mat.set_shader_parameter("dread", _dread)
	_mat.set_shader_parameter("pulse_rate", 0.9 + _dread * 0.9)
