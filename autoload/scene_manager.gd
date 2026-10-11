extends Node
## Fluxo de jogo: título → partida, troca de áreas (base/mina) com fade,
## dormir, desmaio e resgate.

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const MAIN_SCENE := "res://scenes/main/main.tscn"
const BASE_SCENE := "res://scenes/world/base_area.tscn"
const MINE_SCENE := "res://scenes/mines/mine_level.tscn"

var main: Node = null
var current_area: Node = null
var busy := false

var _pending: Dictionary = {}
var _handling_passout := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.player_passed_out.connect(_on_passed_out)
	_rng.randomize()


# ------------------------------------------------------------ partida
func start_new_game(seed_value: int) -> void:
	SaveSystem.new_game(seed_value)
	_pending = {"location": "base", "spawn": "default", "intro": true}
	_enter_main()


func continue_game() -> bool:
	if not SaveSystem.load_game():
		return false
	_pending = {"location": GameState.location, "depth": GameState.depth, "spawn": "saved"}
	_enter_main()
	return true


func quit_to_title() -> void:
	_set_gameplay_active(false)
	get_tree().paused = false
	UIManager.close_all()
	AudioSystem.stop_ambient()
	main = null
	current_area = null
	busy = false
	get_tree().change_scene_to_file(TITLE_SCENE)


func _enter_main() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_SCENE)


## Chamado pelo Main quando está pronto.
func register_main(m: Node) -> void:
	main = m
	if _pending.is_empty():
		_pending = {"location": "base", "spawn": "default"}
	var p := _pending
	_pending = {}
	if p.location == "mine" and int(p.get("depth", 0)) > 0:
		await enter_mine(int(p.depth), false)
	else:
		await go_to_base(p.get("spawn", "default"), false)
	if p.get("intro", false):
		UIManager.open("cutscene", {"scene": "intro", "on_finish": _after_intro})
		main.fade_in(0.8)
	else:
		main.fade_in(1.2)


func _after_intro() -> void:
	EventBus.banner.emit("POSTO ZALIV", TimeSystem.date_string())
	StorySystem.hint("welcome")


# ------------------------------------------------------------ áreas
func go_to_base(spawn: String = "default", fade: bool = true) -> void:
	if fade and GameState.location == "mine":
		AudioSystem.play("ladder")
	await _change_area(BASE_SCENE, {"spawn": spawn}, fade)
	GameState.set_location("base", 0)
	if spawn != "saved" and spawn != "rescue":
		EventBus.banner.emit("POSTO ZALIV", TimeSystem.date_string())
	if ProgressionSystem.pending_picks > 0:
		EventBus.toast.emit("Você tem talento(s) para escolher: tecla K.", "good")
	ProgressionSystem.maybe_offer_trait.call_deferred()


func enter_mine(depth: int, fade: bool = true) -> void:
	if fade:
		AudioSystem.play("ladder")
	GameState.descents += 1
	await _change_area(MINE_SCENE, {"depth": depth}, fade)
	GameState.set_location("mine", depth)


func _change_area(scene_path: String, args: Dictionary, fade: bool) -> void:
	if busy or main == null:
		return
	busy = true
	_set_gameplay_active(false)
	if fade:
		await main.fade_out(0.45)
	if current_area and is_instance_valid(current_area):
		main.world_root.remove_child(current_area)
		current_area.queue_free()
	EventBus.interact_prompt_changed.emit("")
	var area: Node = load(scene_path).instantiate()
	area.set("init_args", args)
	main.world_root.add_child(area)
	current_area = area
	_set_gameplay_active(true)
	if fade:
		await main.fade_in(0.45)
	busy = false


func _set_gameplay_active(on: bool) -> void:
	TimeSystem.running = on
	RadiationSystem.active = on


# ------------------------------------------------------------ dormir
func sleep() -> void:
	if busy or main == null:
		return
	busy = true
	_set_gameplay_active(false)
	AudioSystem.play("sleep")
	await main.fade_out(1.0)
	TimeSystem.sleep()
	var red := float(DataManager.player.get("vitals", {}).get("sleep_exposure_reduction", 35.0))
	RadiationSystem.add_exposure(-red * float(UpgradeSystem.get_stat("sleep_rad_mult", 1.0)))
	HealthSystem.full_restore()
	GameState.add_stat("days")
	SaveSystem.save_game()
	await main.show_center_text("DIA %d" % TimeSystem.day, 1.6)
	_set_gameplay_active(true)
	await main.fade_in(1.0)
	busy = false
	EventBus.toast.emit("Jogo salvo.", "good")
	_report_machines()


## Depois do final: volta à base para o jogo infinito.
func after_ending() -> void:
	if main == null:
		return
	await go_to_base("from_mine")
	EventBus.toast.emit("A mina continua. Você pode continuar minerando.", "info")
	SaveSystem.save_game()


func _report_machines() -> void:
	for id in DataManager.machines:
		if MachineSystem.is_owned(id):
			EventBus.toast.emit(MachineSystem.status_text(id), "info")


# ------------------------------------------------------------ desmaio
func _on_passed_out(reason: String) -> void:
	if _handling_passout or main == null or busy:
		return
	_handling_passout = true
	busy = true
	_set_gameplay_active(false)
	get_tree().call_group("player", "set_input_enabled", false)
	AudioSystem.play("passout")
	await main.fade_out(1.6)
	var cfg: Dictionary = DataManager.game.get("passout", {})
	var fee := mini(int(cfg.get("fee_max", 400)), int(EconomySystem.money * float(cfg.get("fee_ratio", 0.1))))
	EconomySystem.spend(fee)
	var lost := []
	if GameState.location == "mine" or reason != "time":
		var ratio := 1.0 if int(UpgradeSystem.get_stat("passout_lose_all", 0)) > 0 else float(cfg.get("cargo_loss_ratio", 0.5))
		lost = InventorySystem.lose_cargo(ratio, _rng)
	if reason == "time":
		TimeSystem.sleep()
	else:
		TimeSystem.minute = minf(TimeSystem.minute + 120.0, 1500.0)
	if reason == "radiation":
		RadiationSystem.exposure = 55.0
	HealthSystem.full_restore()
	HealthSystem.hp = HealthSystem.max_hp() * float(cfg.get("wake_hp_ratio", 0.5))
	HealthSystem.energy = HealthSystem.max_energy() * float(cfg.get("wake_energy_ratio", 0.5))
	GameState.add_stat("passouts")
	var why: String = {"radiation": "A radiação te derrubou.", "time": "Você desmaiou de cansaço.",
		"hp": "Você desmaiou."}.get(reason, "Você desmaiou.")
	await main.show_center_text(why + "\nUma equipe te arrastou de volta para a base.", 2.6)
	busy = false
	await _change_area(BASE_SCENE, {"spawn": "rescue"}, false)
	GameState.set_location("base", 0)
	await main.fade_in(1.2)
	if fee > 0:
		EventBus.toast.emit("Taxa de resgate: -%s" % DataManager.currency(fee), "danger")
	for l in lost.slice(0, 4):
		EventBus.toast.emit("Perdido: %s" % l, "danger")
	HealthSystem.clamp_to_max()
	_handling_passout = false
