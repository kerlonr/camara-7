class_name ProgressionPanels
extends RefCounted
## Painéis de progressão: escolha de talento (K) e bancada de trabalho.


static func create_all() -> Array:
	return [PerkPanel.new(), CraftPanel.new()]


# =================================================================== TALENTOS
class PerkPanel extends GamePanel:
	const CARD := Vector2(132, 150)
	const TRAIT_CARD := Vector2(136, 92)
	var _cards: VBoxContainer
	var _sub: Label
	var _title: Label
	var _mode := "perk"

	func _init() -> void:
		panel_name = "perks"

	func _build() -> void:
		box.custom_minimum_size = Vector2(430, 220)
		var h := header("TALENTOS")
		_title = h.get_child(0) as Label
		content.add_child(h)
		_sub = UITheme.label("", 12, UITheme.TEXT_DIM)
		_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sub.custom_minimum_size.x = 420
		content.add_child(_sub)
		_cards = VBoxContainer.new()
		_cards.add_theme_constant_override("separation", 6)
		content.add_child(_cards)

	func open(args: Dictionary) -> void:
		_mode = String(args.get("mode", "trait" if ProgressionSystem.trait_pending and ProgressionSystem.pending_picks <= 0 else "perk"))
		_rebuild()

	func _row() -> HBoxContainer:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		_cards.add_child(r)
		return r

	func _rebuild() -> void:
		GamePanel.clear(_cards)
		var p := ProgressionSystem
		if _mode == "trait":
			_title.text = "QUEM É VOCÊ?"
			_sub.text = "Escolha um traço. É para sempre: cada um ajuda numa coisa e atrapalha em outra."
			var row := _row()
			for i in DataManager.trait_order.size():
				if i == 3:
					row = _row()
				row.add_child(_card(DataManager.trait_order[i], true))
			return
		_title.text = "TALENTOS"
		if p.pending_picks <= 0:
			_sub.text = "Nível %d. Suba de nível para escolher talentos (XP: minerar, descer, contratos, missões, inimigos)." % p.level
			var lines := []
			if p.trait_id != "":
				lines.append("Traço: " + String(DataManager.traits.get(p.trait_id, {}).get("name", p.trait_id)))
			lines.append("Talentos: " + (", ".join(p.perks.map(func(id): return p.perk_data(id).get("name", id))) if not p.perks.is_empty() else "nenhum"))
			var owned := UITheme.label("
".join(lines), 12)
			owned.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			owned.custom_minimum_size.x = 400
			_row().add_child(owned)
			return
		_sub.text = "Nível %d — escolha 1 talento (%d disponível%s)." % [p.level, p.pending_picks, "s" if p.pending_picks > 1 else ""]
		var r := _row()
		for id in p.current_offer():
			r.add_child(_card(id, false))

	func _card(id: String, is_trait: bool) -> Control:
		var d: Dictionary = DataManager.traits.get(id, {}) if is_trait else ProgressionSystem.perk_data(id)
		var size := TRAIT_CARD if is_trait else CARD
		var panel := PanelContainer.new()
		panel.theme_type_variation = "CRTPanel"
		panel.custom_minimum_size = size
		panel.clip_contents = true
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 1 if is_trait else 2)
		panel.add_child(v)
		var ic := TextureRect.new()
		var at := AtlasTexture.new()
		at.atlas = DataManager.texture("res://assets/ui/perk_icons.png")
		var idx := int(d.get("icon", 0))
		at.region = Rect2((idx % 8) * 16, (idx / 8) * 16, 16, 16)
		ic.texture = at
		ic.custom_minimum_size = Vector2(16, 16) if is_trait else Vector2(48, 48)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 4)
		if is_trait:
			top.add_child(ic)
			v.add_child(top)
		else:
			v.add_child(ic)
		var n := UITheme.label(d.get("name", id), 12 if is_trait else 16, UITheme.AMBER)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_trait else HORIZONTAL_ALIGNMENT_CENTER
		n.custom_minimum_size.x = size.x - (32 if is_trait else 12)
		if is_trait:
			top.add_child(n)
		else:
			v.add_child(n)
		var desc := UITheme.label(d.get("desc", ""), 10 if is_trait else 12, UITheme.CRT_GREEN)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size.x = size.x - 12
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_trait else HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(desc)
		if d.has("cost"):
			var c := UITheme.label(("" if is_trait else "Custo: ") + d.cost, 10 if is_trait else 12, UITheme.DANGER)
			c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			c.custom_minimum_size.x = size.x - 12
			c.horizontal_alignment = desc.horizontal_alignment
			v.add_child(c)
		var sp := Control.new()
		sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(sp)
		v.add_child(UITheme.button("ESCOLHER", _pick.bind(id, is_trait)))
		return panel

	func _pick(id: String, is_trait: bool) -> void:
		var ok := ProgressionSystem.choose_trait(id) if is_trait else ProgressionSystem.choose(id)
		if ok:
			if is_trait:
				_mode = "perk"
				if ProgressionSystem.pending_picks <= 0:
					close()
					return
			_rebuild()
			if not is_trait and ProgressionSystem.pending_picks <= 0:
				close()


# =================================================================== BANCADA
class CraftPanel extends GamePanel:
	var _list: VBoxContainer

	func _init() -> void:
		panel_name = "craft"

	func _build() -> void:
		box.custom_minimum_size = Vector2(400, 214)
		content.add_child(header("BANCADA DE TRABALHO"))
		content.add_child(UITheme.label("Transforme minério e sucata em equipamento. Arremessáveis: clique com o item na mão.", 10, UITheme.TEXT_DIM))
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(384, 168)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		content.add_child(scroll)
		_list = VBoxContainer.new()
		_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list.add_theme_constant_override("separation", 2)
		scroll.add_child(_list)

	func open(_args: Dictionary) -> void:
		_rebuild()

	func _rebuild() -> void:
		GamePanel.clear(_list)
		for r in Crafting.recipes():
			var item := DataManager.get_item(r.result)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			_list.add_child(row)
			row.add_child(GamePanel.icon(item.get("icon", "")))
			var v := VBoxContainer.new()
			v.add_theme_constant_override("separation", -3)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(v)
			v.add_child(UITheme.label("%dx %s" % [int(r.get("amount", 1)), item.get("name", r.result)], 16, UITheme.TEXT))
			var parts := []
			var items: Dictionary = r.get("items", {})
			for it in items:
				parts.append("%s %d/%d" % [DataManager.item_name(it), InventorySystem.count(it), int(items[it])])
			var miss := Crafting.missing(r)
			var locked := ProgressionSystem.level < int(r.get("min_level", 1))
			var req := UITheme.label((("[requer NV %d]  " % int(r.min_level)) if locked else "") + ", ".join(parts), 10,
				UITheme.GOOD if miss.is_empty() else UITheme.WARN)
			req.custom_minimum_size.x = 280
			req.clip_text = true
			req.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			v.add_child(req)
			var b := UITheme.button("FABRICAR", _craft.bind(r), 70)
			b.disabled = not Crafting.can_craft(r)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(b)

	func _craft(r: Dictionary) -> void:
		Crafting.craft(r)
		_rebuild()
