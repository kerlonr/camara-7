class_name InventoryPanel
extends GamePanel
## Mochila (TAB) com TAMANHO FIXO: grade de slots + ficha do item à direita.
## Aba STATUS (estilo Pip-Boy): nível, XP, talentos e atributos atuais.
## Clique esquerdo: pegar/trocar. Clique direito: usar consumível / ouvir fita.

const PANEL_SIZE := Vector2(400, 214)
const INFO_SIZE := Vector2(166, 120)

var _tab := "bag"
var _tabs: Dictionary = {}
var _bag: HBoxContainer
var _status: ScrollContainer
var _status_list: VBoxContainer
var _grid: GridContainer
var _slots: Array[ItemSlot] = []
var _title: Label
var _icon: TextureRect
var _info_name: Label
var _info_meta: Label
var _info_desc: Label
var _wallet: Label
var _held := -1


func _init() -> void:
	panel_name = "inventory"


func _build() -> void:
	box.custom_minimum_size = PANEL_SIZE
	content.add_child(header("MOCHILA"))
	var tabs := HBoxContainer.new()
	content.add_child(tabs)
	for t in [["bag", "ITENS"], ["status", "STATUS"]]:
		var b := UITheme.button(t[1], _set_tab.bind(t[0]), 80)
		b.toggle_mode = true
		tabs.add_child(b)
		_tabs[t[0]] = b
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(sp)
	_wallet = UITheme.label("", 16, UITheme.AMBER)
	tabs.add_child(_wallet)

	# --- aba ITENS
	_bag = HBoxContainer.new()
	_bag.add_theme_constant_override("separation", 8)
	content.add_child(_bag)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	_bag.add_child(left)
	_title = UITheme.label("", 12, UITheme.TEXT_DIM)
	_title.custom_minimum_size = Vector2(196, 12)
	_title.clip_text = true
	left.add_child(_title)
	_grid = GridContainer.new()
	_grid.columns = 9
	_grid.add_theme_constant_override("h_separation", 1)
	_grid.add_theme_constant_override("v_separation", 1)
	left.add_child(_grid)
	for i in InventorySystem.MAX_SLOTS:
		var s := ItemSlot.new()
		s.index = i
		s.clicked.connect(_on_slot_clicked)
		s.hovered.connect(_show_info)
		_grid.add_child(s)
		_slots.append(s)
	left.add_child(UITheme.label("Esq: mover  ·  Dir: usar  ·  1-9: barra", 10, UITheme.TEXT_DIM))
	# ficha do item: caixa de tamanho fixo, textos cortados/quebrados dentro dela
	var info := PanelContainer.new()
	info.theme_type_variation = "CRTPanel"
	info.custom_minimum_size = INFO_SIZE
	info.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	info.clip_contents = true
	_bag.add_child(info)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 0)
	info.add_child(iv)
	var head := HBoxContainer.new()
	iv.add_child(head)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(32, 32)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(_icon)
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", -3)
	head.add_child(nv)
	_info_name = UITheme.label("", 12, UITheme.CRT_GREEN)
	_info_name.custom_minimum_size = Vector2(118, 0)
	_info_name.clip_text = true
	_info_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nv.add_child(_info_name)
	_info_meta = UITheme.label("", 10, UITheme.CRT_DIM)
	_info_meta.custom_minimum_size = Vector2(118, 0)
	_info_meta.clip_text = true
	_info_meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nv.add_child(_info_meta)
	_info_desc = UITheme.label("", 12, UITheme.CRT_GREEN)
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_desc.custom_minimum_size = Vector2(INFO_SIZE.x - 12, 0)
	iv.add_child(_info_desc)

	# --- aba STATUS
	_status = ScrollContainer.new()
	_status.custom_minimum_size = Vector2(PANEL_SIZE.x - 16, 150)
	_status.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(_status)
	_status_list = VBoxContainer.new()
	_status_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.add_child(_status_list)
	EventBus.inventory_changed.connect(_refresh)


func open(_args: Dictionary) -> void:
	_held = -1
	_set_tab(_tab)
	_show_info(InventorySystem.selected)


func on_close() -> void:
	_held = -1


func _set_tab(t: String) -> void:
	_tab = t
	for k in _tabs:
		_tabs[k].button_pressed = k == t
	_bag.visible = t == "bag"
	_status.visible = t == "status"
	if t == "status":
		_build_status()
	_refresh()


func _refresh() -> void:
	if not visible:
		return
	_wallet.text = DataManager.currency(EconomySystem.money)
	var cap := InventorySystem.capacity()
	var rad := InventorySystem.carried_radiation()
	_title.text = "%d/%d espaços%s" % [InventorySystem.used_slots(), cap, ("  ·  carga radioativa!" if rad > 0.0 else "")]
	for s in _slots:
		s.locked = s.index >= cap
		s.held = s.index == _held
		s.selected = s.index == _held or (s.index == InventorySystem.selected and _held < 0)
		s.queue_redraw()


func _show_info(idx: int) -> void:
	var s = InventorySystem.get_slot(idx)
	if s == null:
		_icon.texture = null
		_info_name.text = "—"
		_info_meta.text = ""
		_info_desc.text = ""
		return
	var item := DataManager.get_item(s.id)
	var rarity: String = item.get("rarity", "common")
	if s.id == "pickaxe":
		var td := UpgradeSystem.current_data("tool")
		_icon.texture = DataManager.texture(UpgradeSystem.get_stat("tool_sprite", ""))
		_info_name.text = td.get("name", "")
		_info_name.add_theme_color_override("font_color", UITheme.CRT_GREEN)
		_info_meta.text = "Ferramenta · NV %d · dano %d" % [int(UpgradeSystem.get_stat("tool_tier", 1)), int(UpgradeSystem.get_stat("tool_power", 1))]
		_info_desc.text = td.get("desc", "")
		return
	_icon.texture = DataManager.texture(item.get("icon", ""))
	_info_name.text = item.get("name", s.id)
	_info_name.add_theme_color_override("font_color", DataManager.rarity_color(rarity))
	var rname: String = DataManager.game.get("rarity", {}).get(rarity, {}).get("name", rarity)
	var meta := "%s · x%d" % [rname, int(s.amount)]
	if EconomySystem.is_sellable(s.id):
		meta += " · %s" % DataManager.currency(EconomySystem.sell_price(s.id))
	_info_meta.text = meta
	var desc: String = item.get("desc", "")
	if float(item.get("radiation", 0.0)) > 0.0:
		desc += " [RADIOATIVO]"
	_info_desc.text = desc


func _on_slot_clicked(idx: int, button: int) -> void:
	if idx >= InventorySystem.capacity():
		return
	if button == MOUSE_BUTTON_RIGHT:
		if InventorySystem.use_slot(idx):
			AudioSystem.play("ui_click")
		_refresh()
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	AudioSystem.play("ui_click")
	if _held < 0:
		if InventorySystem.get_slot(idx) != null:
			_held = idx
	else:
		InventorySystem.swap(_held, idx)
		_held = -1
	_refresh()
	_show_info(idx)


# ------------------------------------------------------------ STATUS
func _line(text: String, size: int = 12, color: Color = UITheme.TEXT) -> void:
	var l := UITheme.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = PANEL_SIZE.x - 30
	_status_list.add_child(l)


func _build_status() -> void:
	GamePanel.clear(_status_list)
	var p := ProgressionSystem
	_line("NÍVEL %d  ·  XP %d/%d%s" % [p.level, p.xp, p.xp_to_next(),
		"  ·  %d talento(s) para escolher [K]" % p.pending_picks if p.pending_picks > 0 else ""], 16, UITheme.AMBER)
	_line("Ferramenta: %s (dano %.1f, nível %d)" % [UpgradeSystem.current_data("tool").get("name", ""),
		float(UpgradeSystem.get_stat("tool_power", 1)), int(UpgradeSystem.get_stat("tool_tier", 1))])
	_line("Traje: %s · proteção %d%% · blindagem da carga %d%%" % [UpgradeSystem.current_data("suit").get("name", ""),
		int(float(UpgradeSystem.get_stat("rad_protection", 0)) * 100), int(float(UpgradeSystem.get_stat("carried_shield", 0)) * 100)])
	_line("Vida %d/%d · Energia %d/%d · Bateria %d%%" % [int(HealthSystem.hp), int(HealthSystem.max_hp()),
		int(HealthSystem.energy), int(HealthSystem.max_energy()), int(HealthSystem.battery)])
	_line("Profundidade máxima: nível %d · %d descidas · %d rochas quebradas" % [GameState.max_depth, GameState.descents,
		int(GameState.stats.get("rocks_broken", 0))], 12, UITheme.TEXT_DIM)
	_line("TALENTOS", 16, UITheme.AMBER)
	if p.perks.is_empty():
		_line("Nenhum ainda. Suba de nível minerando, descendo e cumprindo contratos.", 12, UITheme.TEXT_DIM)
	for id in p.perks:
		var d := p.perk_data(id)
		_line("• %s — %s%s" % [d.get("name", id), d.get("desc", ""), ("  (custo: %s)" % d.cost) if d.has("cost") else ""])
