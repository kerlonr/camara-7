class_name WeatherFX
extends Node2D
## Partículas de clima que acompanham o jogador (coordenadas globais):
## garoa na superfície, poeira em suspensão na mina (visível só sob luz).

const RAIN_TEX := "res://assets/effects/rain.png"
const PIXEL := "res://assets/effects/pixel.png"

var _rain: CPUParticles2D
var _dust: CPUParticles2D
var _ash: CPUParticles2D


func _ready() -> void:
	_rain = CPUParticles2D.new()
	_rain.texture = DataManager.texture(RAIN_TEX)
	_rain.local_coords = false
	_rain.amount = int(DataManager.atmosphere.get("weather", {}).get("drizzle_amount", 140))
	_rain.lifetime = 0.9
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(280, 10)
	_rain.position = Vector2(30, -170)
	_rain.direction = Vector2(-0.25, 1)
	_rain.spread = 3.0
	_rain.gravity = Vector2.ZERO
	_rain.initial_velocity_min = 300.0
	_rain.initial_velocity_max = 380.0
	_rain.color = Color(0.75, 0.8, 0.8, 0.45)
	_rain.particle_flag_align_y = true
	_rain.emitting = false
	_rain.z_index = 40
	add_child(_rain)
	_dust = CPUParticles2D.new()
	_dust.texture = DataManager.texture(PIXEL)
	_dust.local_coords = false
	_dust.amount = 40
	_dust.lifetime = 6.0
	_dust.preprocess = 6.0
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(160, 100)
	_dust.direction = Vector2(1, -0.3)
	_dust.spread = 180.0
	_dust.gravity = Vector2(0, 2)
	_dust.initial_velocity_min = 2.0
	_dust.initial_velocity_max = 7.0
	_dust.scale_amount_min = 0.5
	_dust.scale_amount_max = 0.5
	_dust.color = Color(0.85, 0.82, 0.7, 0.55)
	_dust.emitting = false
	_dust.z_index = 40
	add_child(_dust)
	# cinza fina caindo devagar (superfície)
	_ash = CPUParticles2D.new()
	_ash.texture = DataManager.texture(PIXEL)
	_ash.local_coords = false
	_ash.amount = 36
	_ash.lifetime = 7.0
	_ash.preprocess = 7.0
	_ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_ash.emission_rect_extents = Vector2(300, 10)
	_ash.position = Vector2(0, -170)
	_ash.direction = Vector2(0.4, 1)
	_ash.spread = 25.0
	_ash.gravity = Vector2(2, 6)
	_ash.initial_velocity_min = 8.0
	_ash.initial_velocity_max = 18.0
	_ash.scale_amount_min = 0.5
	_ash.scale_amount_max = 1.0
	_ash.color = Color(0.72, 0.7, 0.66, 0.55)
	_ash.emitting = false
	_ash.z_index = 40
	add_child(_ash)


func set_ash(on: bool) -> void:
	if _ash == null:
		await ready
	_ash.emitting = on


func set_mode(mode: String) -> void:
	if _rain == null:
		await ready
	_rain.emitting = mode == "rain"
	_dust.emitting = mode == "dust"
