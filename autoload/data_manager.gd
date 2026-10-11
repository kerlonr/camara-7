extends Node
## Carrega TODO o conteúdo de res://data em registros por id.
## Adicionar conteúdo = editar JSON; nenhum script precisa mudar.

const DATA_ROOT := "res://data/"

var game: Dictionary = {}
var player: Dictionary = {}
var atmosphere: Dictionary = {}
var controls: Dictionary = {}
var items: Dictionary = {}           # id -> item
var ores: Dictionary = {}            # id -> rocha
var ore_list: Array = []
var containers: Dictionary = {}
var upgrades: Dictionary = {}        # id -> trilha
var upgrade_order: Array = []
var upgrade_categories: Dictionary = {}
var machines: Dictionary = {}
var shop: Dictionary = {}
var biomes: Array = []
var room_types: Dictionary = {}
var mine_events: Array = []
var props: Dictionary = {}
var tiles: Dictionary = {}
var npcs: Dictionary = {}
var notes: Dictionary = {}
var note_order: Array = []
var sounds: Dictionary = {}
var areas: Dictionary = {}
var dialogues: Dictionary = {}
var quests: Dictionary = {}
var scenes: Dictionary = {}
var radio: Dictionary = {}
var hints: Dictionary = {}
var placements: Array = []
var phenomena: Dictionary = {}
var perks: Dictionary = {}
var perk_order: Array = []
var recipes: Array = []
var contracts: Dictionary = {}
var enemies: Dictionary = {}          # id -> inimigo
var traits: Dictionary = {}           # id -> traço
var trait_order: Array = []
var enemy_cfg: Dictionary = {}        # fairness, scaling, spawns

var _texture_cache: Dictionary = {}
var _fallback_texture: Texture2D


func _ready() -> void:
	load_all()


func load_all() -> void:
	game = load_json("config/game.json")
	player = load_json("config/player.json")
	atmosphere = load_json("config/atmosphere.json")
	controls = load_json("config/controls.json")
	items = _index(load_json("items/items.json").get("entries", []))
	var ore_data := load_json("ores/ores.json")
	ore_list = ore_data.get("entries", [])
	ores = _index(ore_list)
	containers = _index(ore_data.get("containers", []))
	var up := load_json("upgrades/upgrades.json")
	upgrade_categories = up.get("categories", {})
	for u in up.get("entries", []):
		upgrades[u.id] = u
		upgrade_order.append(u.id)
	machines = _index(load_json("machines/machines.json").get("entries", []))
	shop = load_json("shop/shop.json")
	biomes = load_json("mines/biomes.json").get("entries", [])
	room_types = load_json("mines/rooms.json").get("entries", {})
	mine_events = load_json("mines/events.json").get("entries", [])
	props = load_json("world/props.json").get("entries", {})
	tiles = load_json("tiles/tiles.json")
	npcs = load_json("npcs/npcs.json").get("entries", {})
	for n in load_json("lore/notes.json").get("entries", []):
		notes[n.id] = n
		note_order.append(n.id)
	sounds = load_json("audio/sounds.json")
	areas["base"] = load_json("areas/base.json")
	dialogues = load_json("story/dialogues.json")
	dialogues.erase("_comment")
	quests = _index(load_json("quests/quests.json").get("entries", []))
	scenes = load_json("story/scenes.json")
	radio = load_json("story/radio.json")
	hints = load_json("story/hints.json").get("entries", {})
	placements = load_json("story/placements.json").get("entries", [])
	phenomena = load_json("mines/phenomena.json")
	for pk in load_json("perks/perks.json").get("entries", []):
		perks[pk.id] = pk
		perk_order.append(pk.id)
	recipes = load_json("crafting/recipes.json").get("entries", [])
	contracts = load_json("contracts/contracts.json")
	enemy_cfg = load_json("enemies/enemies.json")
	for t in load_json("perks/traits.json").get("entries", []):
		traits[t.id] = t
		trait_order.append(t.id)
	enemies = _index(enemy_cfg.get("entries", []))
	_validate()
	get_tree().root.title = String(game.get("window_title", "Câmara 7"))   # nome do jogo na janela/barra de tarefas


func load_json(rel_path: String) -> Dictionary:
	var path := DATA_ROOT + rel_path
	if not FileAccess.file_exists(path):
		push_error("[DataManager] arquivo ausente: %s" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_error("[DataManager] JSON inválido: %s" % path)
		return {}
	return parsed


func _index(arr: Array) -> Dictionary:
	var d := {}
	for e in arr:
		if e is Dictionary and e.has("id"):
			d[e.id] = e
	return d


func _validate() -> void:
	for ore in ore_list:
		if not ore.has("loot") and not items.has(ore.get("drop", "")):
			push_warning("[DataManager] minério '%s' dropa item inexistente '%s'" % [ore.id, ore.get("drop")])
	for c in containers.values():
		for l in c.get("loot", []):
			var it: String = l.get("item", "")
			if it != "" and not it.begins_with("@") and not items.has(it):
				push_warning("[DataManager] contêiner '%s' tem loot inexistente '%s'" % [c.id, it])
	for q in quests.values():
		for o in q.get("objectives", []):
			if o.has("item") and not items.has(o.item):
				push_warning("[DataManager] missão '%s' pede item inexistente '%s'" % [q.id, o.item])
	for npc in dialogues:
		var nodes: Dictionary = dialogues[npc].get("nodes", {})
		for nid in nodes:
			for o in nodes[nid].get("options", []):
				if o.has("node") and not nodes.has(o.node):
					push_warning("[DataManager] diálogo %s/%s aponta para nó inexistente '%s'" % [npc, nid, o.node])
	for u in upgrades.values():
		for lv in u.get("levels", []):
			for it in lv.get("items", {}):
				if not items.has(it):
					push_warning("[DataManager] upgrade '%s' pede item inexistente '%s'" % [u.id, it])


# --------------------------------------------------------------- consultas
func get_item(id: String) -> Dictionary:
	return items.get(id, {})


func item_name(id: String) -> String:
	return items.get(id, {}).get("name", id)


func rarity_color(rarity: String) -> Color:
	var r: Dictionary = game.get("rarity", {}).get(rarity, {})
	return Color(r.get("color", "#ffffff"))


func biome_for_depth(depth: int) -> Dictionary:
	for b in biomes:
		var mx: int = int(b.get("max_depth", -1))
		if depth >= int(b.min_depth) and (mx < 0 or depth <= mx):
			return b
	return biomes[biomes.size() - 1]


func currency(amount: int) -> String:
	return "%s %s" % [format_int(amount), game.get("currency_symbol", "Cr")]


static func format_int(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Carrega uma textura com cache e fallback visível (quadrado magenta) se faltar.
func texture(path: String) -> Texture2D:
	if path == "":
		return _get_fallback()
	if _texture_cache.has(path):
		return _texture_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	if tex == null:
		push_warning("[DataManager] textura ausente: %s" % path)
		tex = _get_fallback()
	_texture_cache[path] = tex
	return tex


func _get_fallback() -> Texture2D:
	if _fallback_texture == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 0, 1))
		_fallback_texture = ImageTexture.create_from_image(img)
	return _fallback_texture
