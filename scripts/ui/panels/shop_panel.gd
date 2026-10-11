class_name ShopPanel
extends GamePanel
## Terminal de comércio (CRT): vender, suprimentos e melhorias.

var _tab := "sell"
var _list: VBoxContainer
var _balance: Label
var _tab_buttons: Dictionary = {}
var _footer: HBoxContainer


func _init() -> void:
	panel_name = "shop"


func _build() -> void:
	box.theme_type_variation = "CRTPanel"
	box.custom_minimum_size = Vector2(460, 250)
	var h := header(String(DataManager.shop.get("name", "TERMINAL")))
	(h.get_child(0) as Label).add_theme_color_override("font_color", UITheme.CRT_GREEN)
	content.add_child(h)
	_balance = UITheme.label("", 16, UITheme.AMBER)
	content.add_child(_balance)
	var tabs := HBoxContainer.new()
	content.add_child(tabs)
	for t in [["sell", "VENDER"], ["contracts", "CONTRATOS"], ["supplies", "SUPRIMENTOS"], ["upgrades", "MELHORIAS"]]:
		var b := UITheme.button(t[1], _set_tab.bind(t[0]), 80)
		b.toggle_mode = true
		tabs.add_child(b)
		_tab_buttons[t[0]] = b
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(444, 170)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)
	_footer = HBoxContainer.new()
	content.add_child(_footer)


func open(args: Dictionary) -> void:
	_set_tab(args.get("tab", _tab))


func _set_tab(t: String) -> void:
	_tab = t
	for k in _tab_buttons:
		_tab_buttons[k].button_pressed = k == t
	_rebuild()


func _rebuild() -> void:
	_balance.text = "SALDO: %s" % DataManager.currency(EconomySystem.money)
	GamePanel.clear(_list)
	GamePanel.clear(_footer)
	match _tab:
		"sell": _build_sell()
		"supplies": _build_supplies()
		"upgrades": _build_upgrades()
		"contracts": _build_contracts()


func _row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 4)
	_list.add_child(r)
	return r


func _crt(text: String, size := 16, color := UITheme.CRT_GREEN, expand := false) -> Label:
	var l := UITheme.label(text, size, color)
	if expand:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


# ------------------------------------------------------------ vender
func _build_sell() -> void:
	var total := 0
	var any := false
	for id in InventorySystem.unique_items():
		if not EconomySystem.is_sellable(id):
			continue
		any = true
		var n := InventorySystem.count(id)
		var price := EconomySystem.sell_price(id)
		total += price * n if DataManager.get_item(id).get("category", "") != "consumable" else 0
		var r := _row()
		r.add_child(GamePanel.icon(DataManager.get_item(id).get("icon", "")))
		var rarity: String = DataManager.get_item(id).get("rarity", "common")
		r.add_child(_crt(DataManager.item_name(id), 16, DataManager.rarity_color(rarity), true))
		r.add_child(_crt("x%d" % n, 16, UITheme.CRT_DIM))
		r.add_child(_crt("%s" % DataManager.currency(price), 16, UITheme.CRT_GREEN))
		r.add_child(UITheme.button("1", _sell.bind(id, 1)))
		r.add_child(UITheme.button("TUDO", _sell.bind(id, n)))
	if not any:
		_list.add_child(_crt("Nada para vender. Vá minerar.", 16, UITheme.CRT_DIM))
	var b := UITheme.button("VENDER CARGA (minérios e materiais)  +%s" % DataManager.currency(total), _sell_all)
	b.disabled = total <= 0
	_footer.add_child(b)


func _sell(id: String, n: int) -> void:
	var got := EconomySystem.sell(id, n)
	if got > 0:
		AudioSystem.play("sell")
	_rebuild()


func _sell_all() -> void:
	var got := EconomySystem.sell_all_cargo()
	if got > 0:
		AudioSystem.play("sell")
		EventBus.toast.emit("Vendido: +%s" % DataManager.currency(got), "good")
	_rebuild()


# ------------------------------------------------------------ contratos
func _build_contracts() -> void:
	var list := ContractSystem.active()
	_list.add_child(_crt("Pedidos do dia %d. Valem mais que vender no balcão e dão XP." % TimeSystem.day, 12, UITheme.CRT_DIM))
	if list.is_empty():
		_list.add_child(_crt("Nenhum pedido em aberto. Volte amanhã.", 16, UITheme.CRT_DIM))
	for c in list:
		var item := DataManager.get_item(c.item)
		var r := _row()
		r.add_child(GamePanel.icon(item.get("icon", "")))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -3)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(v)
		v.add_child(_crt("%dx %s" % [int(c.amount), item.get("name", c.item)], 16, UITheme.CRT_GREEN))
		var left := int(c.expires_day) - TimeSystem.day
		v.add_child(_crt("%s · %s" % [c.client, "vence hoje" if left <= 0 else "vence amanhã"], 10, UITheme.CRT_DIM))
		r.add_child(_crt("%d/%d" % [mini(InventorySystem.count(c.item), int(c.amount)), int(c.amount)], 16,
			UITheme.GOOD if ContractSystem.can_deliver(c) else UITheme.CRT_DIM))
		r.add_child(_crt("%s +%d XP" % [DataManager.currency(int(c.money)), int(c.xp)], 12, UITheme.AMBER))
		var b := UITheme.button("ENTREGAR", _deliver.bind(c.id))
		b.disabled = not ContractSystem.can_deliver(c)
		r.add_child(b)


func _deliver(id: String) -> void:
	ContractSystem.deliver(id)
	_rebuild()


# ------------------------------------------------------------ suprimentos
func _build_supplies() -> void:
	for s in DataManager.shop.get("supplies", []):
		var item := DataManager.get_item(s.item)
		var r := _row()
		r.add_child(GamePanel.icon(item.get("icon", "")))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -3)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(_crt(item.get("name", s.item)))
		v.add_child(_crt(item.get("desc", ""), 12, UITheme.CRT_DIM))
		r.add_child(v)
		r.add_child(_crt("x%d" % InventorySystem.count(s.item), 16, UITheme.CRT_DIM))
		r.add_child(_crt(DataManager.currency(int(s.price)), 16, UITheme.AMBER))
		var b := UITheme.button("COMPRAR", _buy_supply.bind(s.item, int(s.price)))
		b.disabled = not EconomySystem.can_afford(int(s.price)) or not InventorySystem.can_add(s.item)
		r.add_child(b)


func _buy_supply(id: String, price: int) -> void:
	if not InventorySystem.can_add(id):
		AudioSystem.play("ui_error")
		return
	if EconomySystem.spend(price):
		InventorySystem.add_item(id, 1)
		AudioSystem.play("ui_buy")
	else:
		AudioSystem.play("ui_error")
	_rebuild()


# ------------------------------------------------------------ melhorias
func _build_upgrades() -> void:
	var cats: Dictionary = DataManager.upgrade_categories
	var by_cat := {}
	for id in DataManager.upgrade_order:
		var c: String = DataManager.upgrades[id].get("category", "")
		if not by_cat.has(c):
			by_cat[c] = []
		by_cat[c].append(id)
	for c in cats:
		if not by_cat.has(c):
			continue
		_list.add_child(_crt("— %s —" % cats[c], 16, UITheme.AMBER))
		for id in by_cat[c]:
			_upgrade_row(id)


func _upgrade_row(id: String) -> void:
	var track: Dictionary = DataManager.upgrades[id]
	var lv := UpgradeSystem.level(id)
	var mx := UpgradeSystem.max_level(id)
	var cur := UpgradeSystem.current_data(id)
	var r := _row()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(v)
	v.add_child(_crt("%s  [%d/%d]  %s" % [track.name, lv, mx, cur.get("name", "")], 16, UITheme.CRT_GREEN))
	if UpgradeSystem.is_maxed(id):
		v.add_child(_crt("Nível máximo.", 12, UITheme.CRT_DIM))
		r.add_child(_crt("MÁXIMO", 16, UITheme.CRT_DIM))
		return
	var nxt := UpgradeSystem.next_data(id)
	v.add_child(_crt("> %s: %s" % [nxt.get("name", ""), nxt.get("desc", "")], 12, Color("#b8e8a8")))
	var cost := int(nxt.get("cost", 0))
	var parts := [DataManager.currency(cost)]
	for it in nxt.get("items", {}):
		parts.append("%s %d/%d" % [DataManager.item_name(it), InventorySystem.count(it), int(nxt.items[it])])
	var chk := UpgradeSystem.check(id)
	var cost_lbl := _crt("Custo: " + ", ".join(parts), 12, UITheme.AMBER if chk.ok else UITheme.WARN)
	cost_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(cost_lbl)
	var reasons: Array = chk.reasons.filter(func(x): return x != "Dinheiro insuficiente" and x != "Faltam itens")
	if not reasons.is_empty():
		v.add_child(_crt(" · ".join(reasons), 12, UITheme.DANGER))
	var b := UITheme.button("COMPRAR", _buy_upgrade.bind(id))
	b.disabled = not chk.ok
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(b)


func _buy_upgrade(id: String) -> void:
	if UpgradeSystem.purchase(id):
		AudioSystem.play("ui_buy")
		var d := UpgradeSystem.current_data(id)
		EventBus.toast.emit("Adquirido: %s" % d.get("name", id), "good")
		HealthSystem.clamp_to_max()
	else:
		AudioSystem.play("ui_error")
	_rebuild()
