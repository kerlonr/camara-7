extends Control
## HUD v3 — limpo e "de verdade" (inspirado nos instrumentos do Fallout 1/2 e no
## minimalismo do Darkwood). Tudo fica embaixo, em placas pequenas:
##   esquerda: relógio de pulso, data, vida, energia, dosímetro (Geiger) e bateria da lanterna
##   centro:   barra rápida, prompt de interação e legendas de sons
##   direita:  nível/XP e carteira (só aparece quando o dinheiro muda)
## Topo: só uma linha discreta de objetivo, avisos curtos, letreiro e dicas.
## Placas ficam transparentes quando o personagem passa por trás delas.

const TOAST_LIFE := 3.2
const MAX_TOASTS := 3
const FADE_ALPHA := 0.22

var _hp: StatBar
var _energy: StatBar
var _exposure_lbl: Label
var _date_lbl: Label
var _gauge: GeigerGauge
var _iodine: Label
var _left_plate: PanelContainer
var _right_plate: PanelContainer
var _hotbar: PanelContainer
var _level_lbl: Label
var _perk_badge: Label
var _money_lbl: Label
var _top_fx: Control
var _money_t := 0.0
var _objective: Label
var _prompt_box: PanelContainer
var _prompt_lbl: Label
var _caption: Label
var _item_name_lbl: Label
var _toasts: VBoxContainer
var _slots: Array[ItemSlot] = []
var _debug_lbl: Label
var _banner: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _hint_box: PanelContainer
var _hint_lbl: Label
var _item_toasts: Dictionary = {}
var _money_shown := 0
var _money_target := 0
var _obj_text := ""
var _obj_t := 0.0
var _hint_tw: Tween
var _banner_tw: Tween
var _caption_tw: Tween
var _fade_blocks: Array = []


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_refit.call_deferred()
	get_viewport().size_changed.connect(func(): _refit.call_deferred())
	EventBus.vitals_changed.connect(_update_vitals)
	EventBus.exposure_changed.connect(func(_e, _r): _update_exposure())
	EventBus.money_changed.connect(_on_money)
	EventBus.time_changed.connect(func(_d, _m): _update_clock())
	EventBus.inventory_changed.connect(_refresh_slots)
	EventBus.inventory_changed.connect(_update_quest)
	EventBus.stats_changed.connect(_refresh_slots)
	EventBus.hotbar_selected.connect(_on_hotbar_selected)
	EventBus.interact_prompt_changed.connect(_on_prompt)
	EventBus.toast.connect(add_toast)
	EventBus.item_collected.connect(_on_item_collected)
	EventBus.quest_changed.connect(func(_q): _update_quest())
	EventBus.flag_changed.connect(func(_f): _update_quest())
	EventBus.depth_reached.connect(func(_d): _update_quest())
	EventBus.banner.connect(_show_banner)
	EventBus.hint_shown.connect(_show_hint)
	EventBus.caption.connect(_show_caption)
	ProgressionSystem.xp_changed.connect(func(_a, _b): _update_level())
	ProgressionSystem.leveled_up.connect(func(_l): _update_level())
	_money_target = EconomySystem.money
	_money_shown = _money_target
	_update_vitals()
	_update_exposure()
	_update_clock()
	_refresh_slots()
	_update_quest()
	_update_level()
	_on_prompt("")


# ------------------------------------------------------------ construção
func _anchor(c: Control, ax: float, ay: float, left: float, top: float, right: float, bottom: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = left
	c.offset_top = top
	c.offset_right = right
	c.offset_bottom = bottom


func _plate() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "HudPlate"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	_fade_blocks.append(p)
	return p


func _small_bar(parent: Control, icon: String, color: Color) -> StatBar:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	var tr := TextureRect.new()
	tr.texture = DataManager.texture(icon)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tr.custom_minimum_size = Vector2(9, 9)
	h.add_child(tr)
	var bar := StatBar.new()
	bar.color = color
	bar.custom_minimum_size = Vector2(52, 5)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bar)
	parent.add_child(h)
	return bar


func _build() -> void:
	# --- placa de equipamento (base-esquerda)
	_left_plate = _plate()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_left_plate.add_child(row)
	var watch_col := VBoxContainer.new()
	watch_col.add_theme_constant_override("separation", -2)
	row.add_child(watch_col)
	watch_col.add_child(HudWidgets.WristWatch.new())
	_date_lbl = UITheme.label("", 10, UITheme.TEXT_DIM)
	_date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	watch_col.add_child(_date_lbl)
	var vit := VBoxContainer.new()
	vit.add_theme_constant_override("separation", 2)
	vit.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(vit)
	_hp = _small_bar(vit, "res://assets/ui/icon_hp.png", Color("#c8402e"))
	_energy = _small_bar(vit, "res://assets/ui/icon_energy.png", Color("#d2a533"))
	var exr := HBoxContainer.new()
	exr.add_theme_constant_override("separation", 2)
	var tr := TextureRect.new()
	tr.texture = DataManager.texture("res://assets/ui/icon_rad.png")
	tr.custom_minimum_size = Vector2(9, 9)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	exr.add_child(tr)
	exr.add_child(HudWidgets.PenDosimeter.new())
	_exposure_lbl = UITheme.label("0%", 12, Color("#8fe854"))
	_exposure_lbl.visible = false          # a leitura agora é o dosímetro de caneta
	exr.add_child(_exposure_lbl)
	_iodine = UITheme.label(" I", 12, Color("#7fb8e0"))
	_iodine.visible = false
	exr.add_child(_iodine)
	vit.add_child(exr)
	_gauge = GeigerGauge.new()
	_gauge.custom_minimum_size = Vector2(54, 32)
	row.add_child(_gauge)
	row.add_child(HudWidgets.BatteryMeter.new())
	_left_plate.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 4)
	_left_plate.grow_vertical = Control.GROW_DIRECTION_BEGIN

	# --- barra rápida (base-centro)
	_hotbar = PanelContainer.new()
	_hotbar.theme_type_variation = "HudPlate"
	_hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hotbar)
	_fade_blocks.append(_hotbar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 1)
	_hotbar.add_child(hb)
	for i in InventorySystem.HOTBAR_SIZE:
		var s := ItemSlot.new()
		s.index = i
		s.show_number = true
		s.clicked.connect(func(idx, btn): if btn == MOUSE_BUTTON_LEFT: InventorySystem.select(idx))
		hb.add_child(s)
		_slots.append(s)
	_hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 4)
	_hotbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hotbar.grow_vertical = Control.GROW_DIRECTION_BEGIN

	# --- nível / carteira (base-direita)
	_right_plate = _plate()
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 0)
	_right_plate.add_child(rv)
	var lr := HBoxContainer.new()
	lr.add_theme_constant_override("separation", 3)
	rv.add_child(lr)
	_level_lbl = UITheme.label("NV 1", 12, UITheme.AMBER)
	lr.add_child(_level_lbl)
	_perk_badge = UITheme.label("[K] TALENTO", 10, Color("#15130e"))
	_perk_badge.add_theme_stylebox_override("normal", UITheme.flat(UITheme.AMBER, Color.TRANSPARENT, 0, 1))
	_perk_badge.visible = false
	lr.add_child(_perk_badge)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lr.add_child(sp)
	_money_lbl = UITheme.label("", 12, UITheme.AMBER)
	_money_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_money_lbl.modulate.a = 0.0
	lr.add_child(_money_lbl)
	var xb := HudWidgets.XpBar.new()
	xb.custom_minimum_size = Vector2(84, 3)
	rv.add_child(xb)
	_right_plate.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 4)
	_right_plate.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_right_plate.grow_vertical = Control.GROW_DIRECTION_BEGIN

	# --- objetivo (topo-esquerda, discreto)
	_objective = UITheme.label("", 12, UITheme.TEXT, true)
	_objective.position = Vector2(6, 4)
	_objective.modulate.a = 0.0
	add_child(_objective)

	# --- avisos (topo-esquerda, abaixo do objetivo)
	_toasts = VBoxContainer.new()
	_toasts.position = Vector2(4, 20)
	_toasts.custom_minimum_size = Vector2(160, 0)
	_toasts.add_theme_constant_override("separation", 1)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)

	# --- letreiro e dicas (centro-topo); ficam translúcidos se o personagem estiver atrás
	_top_fx = Control.new()
	_top_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_top_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_fx)
	_banner = VBoxContainer.new()
	_anchor(_banner, 0.5, 0.0, -170, 26, 170, 78)
	_banner.add_theme_constant_override("separation", -4)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	_top_fx.add_child(_banner)
	_banner_title = UITheme.label("", 32, UITheme.TEXT, true)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_title)
	_banner_sub = UITheme.label("", 16, UITheme.AMBER, true)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_sub)
	_hint_box = PanelContainer.new()
	_hint_box.theme_type_variation = "CRTPanel"
	_anchor(_hint_box, 0.5, 0.0, -150, 82, 150, 112)
	_hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_box.modulate.a = 0.0
	_top_fx.add_child(_hint_box)
	_hint_lbl = UITheme.label("", 12, UITheme.CRT_GREEN)
	_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_box.add_child(_hint_lbl)

	# --- nome do item, prompt, legenda (acima da barra rápida)
	_item_name_lbl = UITheme.label("", 12, UITheme.TEXT, true)
	_item_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(_item_name_lbl, 0.5, 1.0, -90, -44, 90, -30)
	_item_name_lbl.modulate.a = 0.0
	add_child(_item_name_lbl)
	_prompt_box = PanelContainer.new()
	_prompt_box.add_theme_stylebox_override("panel", UITheme.flat(Color(0.04, 0.04, 0.03, 0.85), Color("#5a5f4a"), 1, 2))
	_prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt_box)
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 4)
	_prompt_box.add_child(pr)
	var key := UITheme.label("E", 16, Color("#15130e"))
	key.add_theme_stylebox_override("normal", UITheme.flat(UITheme.AMBER, Color("#8a6a1c"), 1, 1))
	key.custom_minimum_size = Vector2(12, 0)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pr.add_child(key)
	_prompt_lbl = UITheme.label("", 16, UITheme.TEXT)
	pr.add_child(_prompt_lbl)
	_caption = UITheme.label("", 12, Color("#b8b4a0"))
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_stylebox_override("normal", UITheme.flat(Color(0, 0, 0, 0.7), Color.TRANSPARENT, 0, 2))
	_anchor(_caption, 0.5, 1.0, -110, -88, 110, -72)
	_caption.modulate.a = 0.0
	add_child(_caption)

	_debug_lbl = UITheme.label("", 12, UITheme.CRT_GREEN, true)
	_debug_lbl.position = Vector2(200, 4)
	_debug_lbl.visible = false
	add_child(_debug_lbl)


# ------------------------------------------------------------ atualizações
func _update_vitals() -> void:
	_hp.set_value(HealthSystem.hp / maxf(1.0, HealthSystem.max_hp()))
	_energy.set_value(HealthSystem.energy / maxf(1.0, float(UpgradeSystem.get_stat("max_energy", 150.0))))


func _update_exposure() -> void:
	var e := RadiationSystem.exposure
	_exposure_lbl.text = "%d%%" % int(e)
	_exposure_lbl.add_theme_color_override("font_color",
		UITheme.DANGER if e >= 75 else (UITheme.WARN if e >= 50 else Color("#8fe854")))


func _update_clock() -> void:
	var dd := TimeSystem.date_dict()
	_date_lbl.text = "%02d.%02d" % [dd.day, dd.month]
	if TimeSystem.minutes_left_in_day() < 120:
		StorySystem.hint("night")


func _update_level() -> void:
	_level_lbl.text = "NV %d" % ProgressionSystem.level
	var bv := ProgressionSystem.pending_picks > 0
	if bv != _perk_badge.visible:
		_perk_badge.visible = bv
		_refit.call_deferred()


## Recalcula o tamanho das placas a partir do conteúdo visível.
func _refit() -> void:
	var hb_w := _hotbar.get_combined_minimum_size().x
	var hb_h := _hotbar.get_combined_minimum_size().y
	var view_w := get_viewport_rect().size.x
	var hb_left := (view_w - hb_w) / 2.0
	for pair in [[_left_plate, Control.PRESET_BOTTOM_LEFT], [_right_plate, Control.PRESET_BOTTOM_RIGHT]]:
		var pl: Control = pair[0]
		pl.size = Vector2.ZERO
		pl.set_anchors_and_offsets_preset(pair[1], Control.PRESET_MODE_MINSIZE, 4)
		var w := pl.get_combined_minimum_size().x
		var overlaps := (4.0 + w > hb_left - 3.0) if pair[1] == Control.PRESET_BOTTOM_LEFT else (view_w - 4.0 - w < hb_left + hb_w + 3.0)
		if overlaps:   # tela estreita (zoom "Perto"): a placa sobe para cima da barra rápida
			pl.offset_top -= hb_h + 4
			pl.offset_bottom -= hb_h + 4


func _on_money(v: int) -> void:
	_money_target = v
	_money_t = 3.5


func _update_quest() -> void:
	var id := QuestSystem.tracked
	var txt := ""
	if id != "" and QuestSystem.is_active(id):
		var q := QuestSystem.data(id)
		for p in QuestSystem.progress(id):
			if not p.ok:
				txt = p.text + (" %d/%d" % [p.cur, p.need] if p.need > 1 else "")
				break
		if txt == "":
			txt = "%s: volte e fale com quem pediu" % q.get("title", id)
		txt = ("★ " if q.get("main", false) else "▸ ") + txt
	if txt != _obj_text:
		_obj_text = txt
		_objective.text = txt
		_obj_t = 6.0


func _refresh_slots() -> void:
	for s in _slots:
		s.selected = s.index == InventorySystem.selected
		s.queue_redraw()


func _on_hotbar_selected(idx: int) -> void:
	_refresh_slots()
	var s = InventorySystem.get_slot(idx)
	var txt := ""
	if s != null:
		txt = DataManager.item_name(s.id)
		if s.id == "pickaxe":
			txt = UpgradeSystem.current_data("tool").get("name", txt)
	_item_name_lbl.text = txt
	_item_name_lbl.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(_item_name_lbl, "modulate:a", 0.0, 0.5)


func _on_prompt(text: String) -> void:
	text = text.trim_prefix("[E] ")
	_prompt_box.visible = text != ""
	_prompt_lbl.text = text
	_prompt_box.reset_size()
	var w := _prompt_box.get_combined_minimum_size().x
	_anchor(_prompt_box, 0.5, 1.0, -w / 2.0, -66, w / 2.0, -48)


func _show_banner(title: String, sub: String) -> void:
	_banner_title.text = title
	_banner_sub.text = sub
	if _banner_tw:
		_banner_tw.kill()
	_banner.modulate.a = 0.0
	_banner_tw = create_tween()
	_banner_tw.tween_property(_banner, "modulate:a", 1.0, 0.6)
	_banner_tw.tween_interval(2.2)
	_banner_tw.tween_property(_banner, "modulate:a", 0.0, 1.0)


func _show_hint(text: String) -> void:
	_hint_lbl.text = "DICA: " + text
	if _hint_tw:
		_hint_tw.kill()
	_hint_tw = create_tween()
	_hint_tw.tween_interval(0.8)
	_hint_tw.tween_property(_hint_box, "modulate:a", 1.0, 0.4)
	_hint_tw.tween_interval(7.0)
	_hint_tw.tween_property(_hint_box, "modulate:a", 0.0, 0.8)


func _show_caption(text: String) -> void:
	if text == "" or not Settings.get_v("captions"):
		return
	_caption.text = text
	if _caption_tw:
		_caption_tw.kill()
	_caption_tw = create_tween()
	_caption_tw.tween_property(_caption, "modulate:a", 1.0, 0.3)
	_caption_tw.tween_interval(3.0)
	_caption_tw.tween_property(_caption, "modulate:a", 0.0, 0.8)


func _toast_label(text: String, color: Color) -> Label:
	var l := UITheme.label(text, 12, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 160
	l.add_theme_stylebox_override("normal", UITheme.flat(Color(0.03, 0.03, 0.02, 0.72), Color.TRANSPARENT, 0, 2))
	return l


func add_toast(text: String, kind: String = "info") -> void:
	if text == "":
		return
	var l := _toast_label(text, UITheme.kind_color(kind))
	_toasts.add_child(l)
	while _toasts.get_child_count() > MAX_TOASTS:
		_toasts.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(TOAST_LIFE)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _on_item_collected(item_id: String, amount: int) -> void:
	var entry = _item_toasts.get(item_id)
	if entry and is_instance_valid(entry.label):
		entry.amount += amount
		entry.t = 0.0
		entry.label.modulate.a = 1.0
		entry.label.text = "+%d %s" % [entry.amount, DataManager.item_name(item_id)]
		return
	var rarity: String = DataManager.get_item(item_id).get("rarity", "common")
	var l := _toast_label("+%d %s" % [amount, DataManager.item_name(item_id)], DataManager.rarity_color(rarity))
	_toasts.add_child(l)
	while _toasts.get_child_count() > MAX_TOASTS:
		_toasts.get_child(0).free()
	_item_toasts[item_id] = {"label": l, "amount": amount, "t": 0.0}


func _process(delta: float) -> void:
	for id in _item_toasts.keys():
		var e = _item_toasts[id]
		if not is_instance_valid(e.label):
			_item_toasts.erase(id)
			continue
		e.t += delta
		if e.t > 2.6:
			e.label.modulate.a -= delta * 2.0
			if e.label.modulate.a <= 0.0:
				e.label.queue_free()
				_item_toasts.erase(id)
	if _money_shown != _money_target:
		var diff := _money_target - _money_shown
		_money_shown += signi(diff) * maxi(1, absi(diff) / 8)
	_money_lbl.text = DataManager.currency(_money_shown)
	_money_t -= delta
	_money_lbl.modulate.a = 0.6 + clampf(_money_t, 0.0, 0.4)
	_obj_t -= delta
	_objective.modulate.a = (0.45 + clampf(_obj_t, 0.0, 0.55)) if _obj_text != "" else 0.0
	var gv := GameState.location == "mine" or RadiationSystem.rate > 0.004 or RadiationSystem.exposure > 1.0
	var iv := RadiationSystem.resist_active()
	if gv != _gauge.visible or iv != _iodine.visible:
		_gauge.visible = gv
		_iodine.visible = iv
		_refit.call_deferred()
	_fade_under_player(delta)
	if _debug_lbl.visible:
		_debug_lbl.text = "FPS %d | seed %d | prof %d (máx %d) | descida %d | rate %.3f/s" % [
			Engine.get_frames_per_second(), GameState.world_seed, GameState.depth, GameState.max_depth,
			GameState.descents, RadiationSystem.rate]


## Placas ficam transparentes quando o personagem está atrás delas.
func _fade_under_player(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player")
	var sp := Vector2(-999, -999)
	if p and p.has_method("screen_position"):
		sp = p.screen_position()
	for b in _fade_blocks:
		var r: Rect2 = (b as Control).get_global_rect().grow(10)
		var target := FADE_ALPHA if r.has_point(sp) else 1.0
		b.modulate.a = move_toward(b.modulate.a, target, delta * 5.0)
	var behind := (_banner.modulate.a > 0.05 and _banner.get_global_rect().grow(12).has_point(sp)) 		or (_hint_box.modulate.a > 0.05 and _hint_box.get_global_rect().grow(12).has_point(sp))
	_top_fx.modulate.a = move_toward(_top_fx.modulate.a, 0.25 if behind else 1.0, delta * 5.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		_debug_lbl.visible = not _debug_lbl.visible
