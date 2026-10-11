class_name FlickerLight
extends PointLight2D
## Luz que tremula/falha. flicker = 0 (estável) .. 1 (muito instável).

var flicker: float = 0.15
var base_energy: float = 1.0
var night_only: bool = false
var broken: bool = false
var factor: float = 1.0          # multiplicador externo (dia/noite)

var _dip_t := 0.0
var _rng := RandomNumberGenerator.new()
var _phase := 0.0


func _ready() -> void:
	_rng.randomize()
	_phase = _rng.randf() * 10.0


func _process(delta: float) -> void:
	if broken:
		energy = 0.0
		return
	_phase += delta
	var e := base_energy * (1.0 + sin(_phase * 7.3) * 0.03 * flicker)
	if _dip_t > 0.0:
		_dip_t -= delta
		e *= 0.15
	elif _rng.randf() < flicker * delta * 1.6:
		_dip_t = _rng.randf_range(0.03, 0.14)
	energy = e * factor
