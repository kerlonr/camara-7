class_name SimplePanels
extends RefCounted
## Fábrica dos painéis pequenos (pausa, confirmação, diálogo, notas, elevador,
## descontaminação). Cada classe interna é um GamePanel independente.


static func create_all() -> Array:
	return [PausePanel.new(), ConfirmPanel.new(), NotesListPanel.new(), ElevatorPanel.new(), DeconPanel.new()]


# =================================================================== PAUSA
class PausePanel extends GamePanel:
	var _status: Label
	var _controls: Label

	func _init() -> void:
		panel_name = "pause"

	func _build() -> void:
		box.custom_minimum_size = Vector2(220, 0)
		content.add_child(header("PAUSA"))
		_status = UITheme.label("", 12, UITheme.TEXT_DIM)
		content.add_child(_status)
		var m := MenuList.new(204)
		m.add_item("resume", "Continuar", close)
		m.add_item("save", "Salvar jogo", _save)
		m.add_item("load", "Carregar último save", _load)
		m.add_item("journal", "Diário  [J]", func(): UIManager.open("journal"))
		m.add_item("perks", "Talentos  [K]", func(): UIManager.open("perks"))
		m.add_item("options", "Opções", func(): UIManager.open("options"))
		m.add_item("controls", "Controles", _toggle_controls)
		m.add_item("title", "Sair para o título", func(): SceneManager.quit_to_title())
		m.add_item("quit", "Sair do jogo", func(): get_tree().quit())
		content.add_child(m)
		_controls = UITheme.label("WASD mover · SHIFT correr · Mouse esq. minerar/usar/arremessar\nE interagir · TAB mochila · K talentos · J diário\n1-9 / roda: barra rápida · ESC menu · F11 tela cheia", 10, UITheme.TEXT)
		_controls.visible = false
		content.add_child(_controls)

	func open(_args: Dictionary) -> void:
		_status.text = "%s · Nível máx. %d · %d descidas · %d rochas
Seed %d" % [
			TimeSystem.date_string(), GameState.max_depth, GameState.descents, int(GameState.stats.get("rocks_broken", 0)), GameState.world_seed]

	func _save() -> void:
		if GameState.location == "mine":
			EventBus.toast.emit("Salvo. Ao carregar, você volta ao início do nível %d." % GameState.depth, "info")
		if SaveSystem.save_game():
			AudioSystem.play("ui_buy")
			EventBus.toast.emit("Jogo salvo.", "good")
		close()

	func _load() -> void:
		if not SaveSystem.has_save():
			AudioSystem.play("ui_error")
			return
		UIManager.close_all()
		SceneManager.continue_game()

	func _toggle_controls() -> void:
		_controls.visible = not _controls.visible


# =================================================================== CONFIRMAÇÃO
class ConfirmPanel extends GamePanel:
	var _title: Label
	var _text: Label
	var _yes: Button
	var _cb: Callable

	func _init() -> void:
		panel_name = "confirm"

	func _build() -> void:
		box.custom_minimum_size = Vector2(240, 0)
		_title = Label.new()
		_title.theme_type_variation = "HeaderLabel"
		content.add_child(_title)
		_text = UITheme.label("", 16)
		_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_text.custom_minimum_size.x = 230
		content.add_child(_text)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END
		_yes = UITheme.button("Sim", _on_yes, 70)
		row.add_child(UITheme.button("Cancelar", close, 70))
		row.add_child(_yes)
		content.add_child(row)

	func open(args: Dictionary) -> void:
		_title.text = args.get("title", "CONFIRMAR")
		_text.text = args.get("text", "")
		_yes.text = args.get("yes", "Sim")
		_cb = args.get("on_yes", Callable())

	func _on_yes() -> void:
		close()
		if _cb.is_valid():
			_cb.call()


# =================================================================== NOTAS
class NotesListPanel extends GamePanel:
	var _list: VBoxContainer

	func _init() -> void:
		panel_name = "notes"

	func _build() -> void:
		box.custom_minimum_size = Vector2(240, 0)
		content.add_child(header("NOTAS ENCONTRADAS"))
		_list = VBoxContainer.new()
		content.add_child(_list)

	func open(_args: Dictionary) -> void:
		GamePanel.clear(_list)
		if GameState.notes_found.is_empty():
			_list.add_child(UITheme.label("Nenhuma ainda. Procure em caixas e armários.", 12, UITheme.TEXT_DIM))
		for id in DataManager.note_order:
			if GameState.notes_found.has(id):
				var n: Dictionary = DataManager.notes[id]
				_list.add_child(UITheme.button(n.get("title", id), func(): UIManager.open("note", {"note": id})))
		_list.add_child(UITheme.label("%d de %d" % [GameState.notes_found.size(), DataManager.notes.size()], 12, UITheme.TEXT_DIM))


# =================================================================== ELEVADOR
class ElevatorPanel extends GamePanel:
	var _list: VBoxContainer

	func _init() -> void:
		panel_name = "elevator"

	func _build() -> void:
		box.theme_type_variation = "CRTPanel"
		box.custom_minimum_size = Vector2(200, 0)
		var h := header("ELEVADOR — POÇO 2")
		(h.get_child(0) as Label).add_theme_color_override("font_color", UITheme.CRT_GREEN)
		content.add_child(h)
		_list = VBoxContainer.new()
		content.add_child(_list)

	func open(_args: Dictionary) -> void:
		GamePanel.clear(_list)
		if int(UpgradeSystem.get_stat("elevator", 0)) <= 0:
			_list.add_child(UITheme.label("Elevador sem energia.\nRestaure-o no terminal (Melhorias).", 16, UITheme.CRT_DIM))
			if GameState.location == "mine":
				_list.add_child(UITheme.button("Usar a escada para subir", _go_base))
			return
		if GameState.location == "mine":
			_list.add_child(UITheme.button("SUPERFÍCIE (base)", _go_base))
		for d in GameState.checkpoints():
			if GameState.location == "mine" and d == GameState.depth:
				continue
			_list.add_child(UITheme.button("NÍVEL %d" % d, _go.bind(d)))

	func _go(d: int) -> void:
		UIManager.close_all()
		SceneManager.enter_mine(d)

	func _go_base() -> void:
		UIManager.close_all()
		SceneManager.go_to_base("from_mine")


# =================================================================== DESCONTAMINAÇÃO
class DeconPanel extends GamePanel:
	var _text: Label
	var _btn: Button
	var _cost := 0

	func _init() -> void:
		panel_name = "decon"

	func _build() -> void:
		box.custom_minimum_size = Vector2(240, 0)
		content.add_child(header("CHUVEIRO DE DESCONTAMINAÇÃO"))
		_text = UITheme.label("", 16)
		_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_text.custom_minimum_size.x = 230
		content.add_child(_text)
		content.add_child(UITheme.label("(Mecânica de jogo — ver docs/REFERENCIAS.md)", 12, UITheme.TEXT_DIM))
		_btn = UITheme.button("Descontaminar", _do)
		content.add_child(_btn)

	func open(_args: Dictionary) -> void:
		var e := RadiationSystem.exposure
		_cost = int(ceil(e * float(DataManager.shop.get("decon_cost_per_point", 2))))
		if e < 1.0:
			_text.text = "Exposição: %d%%.\nVocê está limpo." % int(e)
			_btn.disabled = true
		else:
			_text.text = "Exposição atual: %d%%.\nCusto: %s" % [int(e), DataManager.currency(_cost)]
			_btn.disabled = not EconomySystem.can_afford(_cost)

	func _do() -> void:
		if EconomySystem.spend(_cost):
			RadiationSystem.add_exposure(-100.0)
			HealthSystem.clamp_to_max()
			AudioSystem.play("drip", 0.6)
			AudioSystem.play("door")
			EventBus.toast.emit("Descontaminado. Exposição zerada.", "good")
			close()
