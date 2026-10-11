extends Node
## Vida e energia do jogador. Persistem entre cenas (o nó Player só exibe/consome).

var hp: float = 100.0
var energy: float = 150.0
var battery: float = 100.0          # bateria da lanterna (%)
var _battery_warned := 100
var _vitals: Dictionary = {}
var _exhausted_warned := false


func _ready() -> void:
	_vitals = DataManager.player.get("vitals", {})


func reset() -> void:
	full_restore()


func max_hp() -> float:
	return float(UpgradeSystem.get_stat("max_hp", 100.0))


func max_energy() -> float:
	var m := float(UpgradeSystem.get_stat("max_energy", 150.0))
	if RadiationSystem.exposure >= float(_vitals.get("exposure_energy_penalty_at", 50.0)):
		m *= 1.0 - float(_vitals.get("exposure_energy_penalty", 0.3))
	return m


func full_restore() -> void:
	hp = max_hp()
	energy = max_energy()
	battery = 100.0
	_battery_warned = 100
	_exhausted_warned = false
	EventBus.vitals_changed.emit()


func damage(amount: float, reason: String = "") -> void:
	if hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	EventBus.vitals_changed.emit()
	if hp <= 0.0:
		EventBus.player_passed_out.emit(reason if reason != "" else "hp")


func heal(amount: float) -> void:
	hp = minf(max_hp(), hp + amount)
	EventBus.vitals_changed.emit()


## Gasta energia. Retorna false se o jogador está exausto (ação fica mais fraca).
func spend_energy(amount: float) -> bool:
	var had := energy > 0.0
	energy = maxf(0.0, energy - amount)
	EventBus.vitals_changed.emit()
	if energy <= 0.0 and not _exhausted_warned:
		_exhausted_warned = true
		EventBus.toast.emit("Exausto. Coma algo ou volte para dormir.", "warn")
		StorySystem.hint("exhausted")
	return had


func restore_energy(amount: float) -> void:
	energy = minf(max_energy(), energy + amount)
	if energy > 0.0:
		_exhausted_warned = false
	EventBus.vitals_changed.emit()


func is_exhausted() -> bool:
	return energy <= 0.0


func clamp_to_max() -> void:
	hp = minf(hp, max_hp())
	energy = minf(energy, max_energy())
	EventBus.vitals_changed.emit()


## Gasta bateria da lanterna (minutos de jogo com ela ligada).
func drain_battery(minutes: float) -> void:
	var total := maxf(60.0, float(UpgradeSystem.get_stat("battery_minutes", 900.0)))
	battery = maxf(0.0, battery - minutes / total * 100.0)
	for th in [25, 10, 0]:
		if battery <= th and _battery_warned > th:
			_battery_warned = th
			var msg: String = {25: "Bateria da lanterna em 25%.", 10: "Bateria quase no fim!", 0: "A lanterna apagou. Só um brilho fraco."}[th]
			EventBus.toast.emit(msg, "danger" if th <= 10 else "warn")
			AudioSystem.play("alarm", 0.7)
	if battery > 30:
		_battery_warned = 100


func get_save_data() -> Dictionary:
	return {"hp": hp, "energy": energy, "battery": battery}


func load_save_data(d: Dictionary) -> void:
	hp = float(d.get("hp", max_hp()))
	energy = float(d.get("energy", max_energy()))
	battery = float(d.get("battery", 100.0))
	EventBus.vitals_changed.emit()
