extends Node
## Save estruturado em JSON, versionado, com migrações.
## Cada sistema serializa a própria chave via get_save_data()/load_save_data().

const SAVE_VERSION := 3
## Pasta dos saves. Os testes automatizados trocam para "user://test_saves/" para nunca
## tocar no save real do jogador.
var save_dir := "user://saves/"
const SETTINGS_PATH := "user://settings.cfg"

## chave no save -> nome do autoload. A ORDEM importa no load
## (upgrades antes de inventário/vida, pois definem capacidades).
const SYSTEMS := [
	["game_state", "GameState"],
	["progression", "ProgressionSystem"],
	["upgrades", "UpgradeSystem"],
	["time", "TimeSystem"],
	["economy", "EconomySystem"],
	["inventory", "InventorySystem"],
	["radiation", "RadiationSystem"],
	["health", "HealthSystem"],
	["machines", "MachineSystem"],
	["quests", "QuestSystem"],
	["story", "StorySystem"],
	["contracts", "ContractSystem"],
]

## versão_origem -> método que converte o dicionário para versão_origem + 1
const MIGRATIONS := {
	1: "_migrate_1_to_2",
	2: "_migrate_2_to_3",
}


func slot_path(slot: int) -> String:
	return save_dir + "slot_%d.json" % slot


func has_save(slot: int = 1) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func new_game(seed_value: int) -> void:
	GameState.reset(seed_value)
	ProgressionSystem.reset()
	ContractSystem.reset()
	UpgradeSystem.reset()
	TimeSystem.reset()
	EconomySystem.reset()
	InventorySystem.reset()
	RadiationSystem.reset()
	MachineSystem.reset()
	QuestSystem.reset()
	StorySystem.reset()
	HealthSystem.reset()
	for it in DataManager.game.get("start_items", []):
		InventorySystem.add_item(it.id, int(it.amount))
	EventBus.new_game_started.emit()


func save_game(slot: int = 1) -> bool:
	DirAccess.make_dir_recursive_absolute(save_dir)
	var systems := {}
	for pair in SYSTEMS:
		systems[pair[0]] = get_node("/root/" + pair[1]).get_save_data()
	var data := {
		"save_version": SAVE_VERSION,
		"game_version": DataManager.game.get("version", "0"),
		"saved_at": Time.get_datetime_string_from_system(),
		"systems": systems,
	}
	var tmp := slot_path(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("[SaveSystem] não foi possível escrever %s" % tmp)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	# escrita atômica: só substitui o save depois de gravar o temporário
	if FileAccess.file_exists(slot_path(slot)):
		DirAccess.remove_absolute(slot_path(slot))
	DirAccess.rename_absolute(tmp, slot_path(slot))
	EventBus.game_saved.emit()
	return true


func load_game(slot: int = 1) -> bool:
	if not has_save(slot):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(slot_path(slot)))
	if not parsed is Dictionary:
		push_error("[SaveSystem] save corrompido")
		return false
	var data: Dictionary = _migrate(parsed)
	var systems: Dictionary = data.get("systems", {})
	for pair in SYSTEMS:
		get_node("/root/" + pair[1]).load_save_data(systems.get(pair[0], {}))
	EventBus.game_loaded.emit()
	return true


func save_info(slot: int = 1) -> Dictionary:
	if not has_save(slot):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(slot_path(slot)))
	if not parsed is Dictionary:
		return {}
	var sys: Dictionary = parsed.get("systems", {})
	return {
		"saved_at": parsed.get("saved_at", ""),
		"day": sys.get("time", {}).get("day", 1),
		"money": sys.get("economy", {}).get("money", 0),
		"max_depth": sys.get("game_state", {}).get("max_depth", 0),
	}


func _migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("save_version", 1))
	while v < SAVE_VERSION:
		if not MIGRATIONS.has(v):
			push_error("[SaveSystem] sem migração de v%d" % v)
			break
		data = call(MIGRATIONS[v], data)
		v += 1
		data["save_version"] = v
	return data


## v1 → v2: entram missões, história e contador de descidas.
func _migrate_1_to_2(data: Dictionary) -> Dictionary:
	var sys: Dictionary = data.get("systems", {})
	sys["quests"] = sys.get("quests", {})
	sys["story"] = sys.get("story", {})
	var gs: Dictionary = sys.get("game_state", {})
	gs["descents"] = gs.get("descents", 0)
	if not gs.get("flags", {}) is Dictionary:
		gs["flags"] = {}
	sys["game_state"] = gs
	data["systems"] = sys
	return data


## v2 → v3: entram nível/talentos, contratos e bateria. Quem já jogava ganha um nível
## proporcional ao progresso, com talentos para escolher (nada do save antigo é perdido).
func _migrate_2_to_3(data: Dictionary) -> Dictionary:
	var sys: Dictionary = data.get("systems", {})
	var gs: Dictionary = sys.get("game_state", {})
	var done: Array = sys.get("quests", {}).get("done", [])
	var lv := 1 + int(gs.get("max_depth", 0)) / 3 + done.size() / 2
	sys["progression"] = {"level": lv, "xp": 0, "perks": [], "pending": lv - 1, "offer": [], "discovered": []}
	sys["contracts"] = {}
	var h: Dictionary = sys.get("health", {})
	h["battery"] = 100.0
	sys["health"] = h
	data["systems"] = sys
	return data


# ------------------------------------------------------------ configurações
func save_settings(settings: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	cfg.save(SETTINGS_PATH)


func load_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	var out := {}
	if cfg.load(SETTINGS_PATH) == OK:
		for k in cfg.get_section_keys("settings"):
			out[k] = cfg.get_value("settings", k)
	return out
