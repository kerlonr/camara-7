extends Node
## Radiação: soma fontes (ambiente, objetos no grupo "rad_source", carga),
## aplica proteção do traje e acumula "exposição" (0–100%).
## Exposição é uma ABSTRAÇÃO DE JOGO (ver docs/REFERENCIAS.md), não dose real.

const SOURCE_FALLOFF_TILES := 1.2
const SOURCE_RANGE := 112.0
const CPS_BACKGROUND := 0.35
const CPS_PER_RATE := 240.0

var exposure: float = 0.0
var rate: float = 0.0            # exposure %/s efetiva (após proteção)
var external_raw: float = 0.0    # antes da proteção
var ambient_rate: float = 0.0    # definido pela área atual
var active: bool = false         # true quando há gameplay acontecendo
var player: Node2D = null

var resist: float = 0.0          # efeito temporário (iodeto de potássio, no jogo)
var resist_until: float = 0.0
var _vitals: Dictionary = {}
var _warned := {}


func _ready() -> void:
	_vitals = DataManager.player.get("vitals", {})


func reset() -> void:
	exposure = 0.0
	rate = 0.0
	resist = 0.0
	resist_until = 0.0
	_warned = {}


func cps() -> float:
	return CPS_BACKGROUND + rate * CPS_PER_RATE


func _physics_process(delta: float) -> void:
	if not active or player == null or not is_instance_valid(player):
		return
	external_raw = ambient_rate + _sources_at(player.global_position)
	var protection := clampf(float(UpgradeSystem.get_stat("rad_protection", 0.0)), 0.0, 0.95)
	var shield := clampf(float(UpgradeSystem.get_stat("carried_shield", 0.0)), 0.0, 0.95)
	var carried := InventorySystem.carried_radiation() * (1.0 - shield)
	var buff := resist if TimeSystem.absolute_minute() < resist_until else 0.0
	rate = external_raw * (1.0 - protection) * (1.0 - buff) + carried
	if rate > 0.0005:
		exposure = minf(100.0, exposure + rate * delta)
	elif GameState.location == "base" and int(UpgradeSystem.get_stat("no_base_decay", 0)) == 0:
		exposure = maxf(0.0, exposure - float(_vitals.get("exposure_decay_base_per_sec", 0.08)) * delta)
	if rate > 0.02:
		StorySystem.hint("geiger")
	_apply_effects(delta)
	EventBus.exposure_changed.emit(exposure, rate)


func _sources_at(pos: Vector2) -> float:
	var total := 0.0
	for src in get_tree().get_nodes_in_group("rad_source"):
		var n := src as Node2D
		if n == null or not n.is_inside_tree():
			continue
		var d := n.global_position.distance_to(pos)
		if d > SOURCE_RANGE:
			continue
		var t := d / (16.0 * SOURCE_FALLOFF_TILES)
		total += float(n.get_meta("strength", 0.0)) / (1.0 + t * t)
	return total


func _apply_effects(delta: float) -> void:
	var dmg_at := float(_vitals.get("exposure_damage_at", 75.0))
	if exposure >= dmg_at:
		var k := (exposure - dmg_at) / maxf(1.0, 100.0 - dmg_at)
		HealthSystem.damage(float(_vitals.get("exposure_damage_per_sec", 0.6)) * (0.5 + k) * delta, "radiation")
	for threshold in [50, 75, 90]:
		if exposure >= threshold and not _warned.get(threshold, false):
			_warned[threshold] = true
			var msg: String = {50: "Exposição em 50%. Energia máxima reduzida.",
				75: "Exposição em 75%! Você está perdendo vida.",
				90: "EXPOSIÇÃO CRÍTICA. Saia agora."}[threshold]
			EventBus.toast.emit(msg, "danger" if threshold >= 75 else "warn")
			HealthSystem.clamp_to_max()
		elif exposure < threshold - 5:
			_warned[threshold] = false
	if exposure >= 100.0:
		EventBus.player_passed_out.emit("radiation")


func add_resist(amount: float, minutes: float) -> void:
	resist = clampf(amount, 0.0, 0.9)
	resist_until = TimeSystem.absolute_minute() + minutes


func resist_active() -> bool:
	return TimeSystem.absolute_minute() < resist_until


func add_exposure(amount: float) -> void:
	exposure = clampf(exposure + amount, 0.0, 100.0)
	EventBus.exposure_changed.emit(exposure, rate)


func get_save_data() -> Dictionary:
	return {"exposure": exposure, "resist": resist, "resist_until": resist_until}


func load_save_data(d: Dictionary) -> void:
	exposure = float(d.get("exposure", 0.0))
	resist = float(d.get("resist", 0.0))
	resist_until = float(d.get("resist_until", 0.0))
