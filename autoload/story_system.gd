extends Node
## História: diálogos ramificados, fitas do Turno C, objetos de história na mina,
## dicas contextuais, transmissões de rádio e finais.

const TAPES := ["tape_1", "tape_2", "tape_3", "tape_4", "tape_5"]

var hints_shown: Array = []
var radio_played: Array = []
var seen_nodes: Dictionary = {}     # npc -> Array de nós já vistos
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func reset() -> void:
	hints_shown = []
	radio_played = []
	seen_nodes = {}


func tapes_found() -> int:
	var n := 0
	for t in TAPES:
		if GameState.has_flag(t):
			n += 1
	return n


# ------------------------------------------------------------ diálogos
func _graph(npc: String) -> Dictionary:
	return DataManager.dialogues.get(npc, {})


func start_node(npc: String) -> String:
	for e in _graph(npc).get("start", []):
		if Conditions.check(e.get("if", [])):
			return e.node
	return "hub"


## Resolve um nó: aplica efeitos de entrada e devolve {text, options}.
func enter_node(npc: String, node_id: String) -> Dictionary:
	var node: Dictionary = _graph(npc).get("nodes", {}).get(node_id, {})
	if node.is_empty():
		return {}
	if not seen_nodes.has(npc):
		seen_nodes[npc] = []
	if not seen_nodes[npc].has(node_id):
		seen_nodes[npc].append(node_id)
	for f in node.get("set", []):
		GameState.set_flag(f)
	if node.has("quest_complete"):
		QuestSystem.complete(node.quest_complete)
	if node.has("quest_start"):
		QuestSystem.start(node.quest_start)
	var give: Dictionary = node.get("give", {})
	if not give.is_empty() and not seen_nodes[npc].has(node_id + "#given"):
		seen_nodes[npc].append(node_id + "#given")
		for it in give:
			InventorySystem.add_item(it, int(give[it]))
			EventBus.toast.emit("Recebeu: %dx %s" % [int(give[it]), DataManager.item_name(it)], "good")
	return {"text": _resolve_text(node), "options": visible_options(npc, node_id)}


func _resolve_text(node: Dictionary) -> String:
	if node.has("text"):
		return node.text
	var plain := []
	for e in node.get("text_pool", []):
		if e.has("if"):
			if Conditions.check(e.if):
				return e.text
		else:
			plain.append(e.text)
	return plain[_rng.randi_range(0, plain.size() - 1)] if not plain.is_empty() else "..."


func visible_options(npc: String, node_id: String) -> Array:
	var node: Dictionary = _graph(npc).get("nodes", {}).get(node_id, {})
	var out := []
	for o in node.get("options", []):
		if Conditions.check(o.get("if", [])):
			var opt: Dictionary = o.duplicate()
			opt["new"] = o.has("node") and o.node != "hub" and not seen_nodes.get(npc, []).has(o.node)
			out.append(opt)
	return out


## Executa uma opção. Retorna o próximo nó ("" = encerrar conversa).
func choose(npc: String, opt: Dictionary) -> String:
	for f in opt.get("set", []):
		GameState.set_flag(f)
	if opt.has("quest_start"):
		QuestSystem.start(opt.quest_start)
	if opt.has("quest_complete"):
		QuestSystem.complete(opt.quest_complete)
	match String(opt.get("action", "")):
		"shop":
			return "@shop"
		"radio":
			return "@radio"
		"close":
			return ""
	if opt.get("end", false):
		return ""
	return String(opt.get("node", ""))


## O NPC tem algo novo a dizer? (indicador [!] na cabeça)
func npc_has_news(npc: String) -> bool:
	var start := start_node(npc)
	if start != "hub":
		return not seen_nodes.get(npc, []).has(start) or start == "intro"
	for o in visible_options(npc, "hub"):
		if o.get("new", false):
			return true
		var target: Dictionary = _graph(npc).get("nodes", {}).get(o.get("node", ""), {})
		if target.has("quest_complete") and QuestSystem.is_ready(target.quest_complete):
			return true
	return false


# ------------------------------------------------------------ objetos na mina
## Objeto de história pendente para esta profundidade (ou {}).
func pending_placement(at_depth: int) -> Dictionary:
	for p in DataManager.placements:
		if GameState.has_flag(p.id):
			continue
		if at_depth < int(p.get("min_depth", 1)):
			continue
		if int(p.get("max_depth", -1)) >= 0 and at_depth > int(p.max_depth):
			continue
		if not Conditions.check(p.get("if", [])):
			continue
		return p
	return {}


func collect_story_object(p: Dictionary) -> void:
	match String(p.get("kind", "")):
		"tape":
			GameState.set_flag(p.id)
			InventorySystem.add_item(p.id, 1)
			GameState.find_note(p.id)
			AudioSystem.play("tape")
			EventBus.toast.emit("Encontrou: %s" % DataManager.item_name(p.id), "item")
			hint("tape")
			if not QuestSystem.is_active("q_turno_c") and not QuestSystem.is_done("q_turno_c"):
				EventBus.toast.emit("Talvez a Oksana saiba de quem é esta voz.", "info")
			UIManager.open("note", {"note": p.id})
		"item":
			GameState.set_flag(p.id)
			InventorySystem.add_item(p.get("item", p.id), 1)
			AudioSystem.play("quest")
			EventBus.toast.emit("Encontrou: %s" % DataManager.item_name(p.get("item", p.id)), "item")


# ------------------------------------------------------------ dicas
func hint(id: String) -> void:
	if hints_shown.has(id) or not Settings.get_v("hints"):
		return
	var text: String = DataManager.hints.get(id, "")
	if text == "":
		return
	hints_shown.append(id)
	EventBus.hint_shown.emit(text)


# ------------------------------------------------------------ rádio
func next_broadcast() -> Dictionary:
	for b in DataManager.radio.get("entries", []):
		if radio_played.has(b.id):
			continue
		if Conditions.check(b.get("if", [])):
			radio_played.append(b.id)
			return b
	var idle: Array = DataManager.radio.get("idle", ["(chiado)"])
	return {"id": "idle", "lines": [idle[_rng.randi_range(0, idle.size() - 1)]], "tag": ""}


## Estações sintonizáveis agora (condição passa). Mesmo já ouvidas continuam no ar.
func radio_stations() -> Array:
	var out := []
	for b in DataManager.radio.get("entries", []):
		if Conditions.check(b.get("if", [])):
			out.append(b)
	return out


func mark_radio_played(id: String) -> void:
	if not radio_played.has(id):
		radio_played.append(id)


func has_new_broadcast() -> bool:
	for b in DataManager.radio.get("entries", []):
		if not radio_played.has(b.id) and Conditions.check(b.get("if", [])):
			return true
	return false


# ------------------------------------------------------------ finais
func scene(id: String) -> Array:
	return DataManager.scenes.get(id, [])


func apply_ending(flag: String) -> void:
	GameState.set_flag(flag)
	GameState.set_flag("chamber_opened")
	GameState.set_flag("game_finished")
	if flag == "ending_silence":
		EconomySystem.add_money(15000)
		for t in TAPES:
			InventorySystem.remove_item(t, 1)
	if QuestSystem.is_active("q_turno_c"):
		QuestSystem.complete("q_turno_c")


func get_save_data() -> Dictionary:
	return {"hints": hints_shown, "radio": radio_played, "seen": seen_nodes}


func load_save_data(d: Dictionary) -> void:
	reset()
	hints_shown = d.get("hints", [])
	radio_played = d.get("radio", [])
	var s = d.get("seen", {})
	seen_nodes = s if s is Dictionary else {}
