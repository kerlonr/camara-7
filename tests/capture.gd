extends Node
## Captura screenshots de várias situações para revisão visual.
##   godot --path . res://tests/capture.tscn -- --out=C:/pasta

var out_dir := "user://captures"


func _ready() -> void:
	SaveSystem.save_dir = "user://test_saves/"   # nunca tocar no save real
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	reparent.call_deferred(get_tree().root)
	_run.call_deferred()


func shot(name: String, frames: int = 20) -> void:
	for i in frames:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir + "/" + name + ".png")
	print("captura: ", name)


func wait_area(cls: String) -> void:
	for i in 900:
		await get_tree().process_frame
		var a = SceneManager.current_area
		if a and is_instance_valid(a) and a.get_script().get_global_name() == cls and not SceneManager.busy and a.player:
			return


func _run() -> void:
	var title: Node = load("res://scenes/ui/title_screen.tscn").instantiate()
	get_tree().root.add_child(title)
	await get_tree().process_frame
	title._skip_intro()
	await shot("00_title", 60)
	title.queue_free()
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	SceneManager.start_new_game(8472191)
	await wait_area("BaseArea")
	await shot("01_intro", 140)
	UIManager.close_all()
	# dia 3: todos os moradores na base
	TimeSystem.day = 3
	TimeSystem.minute = 620
	await SceneManager.go_to_base("default", false)
	await wait_area("BaseArea")
	var area = SceneManager.current_area
	area.player.global_position = area.cell_pos(Vector2i(17, 11))
	await shot("02_base_day", 60)
	UIManager.open("dialogue", {"npc": "hanna"})
	await shot("03_dialogue", 90)
	UIManager.close_all()
	area.player.global_position = area.cell_pos(Vector2i(31, 17))
	await shot("04_base_bus", 50)
	TimeSystem.minute = 1300
	area._update_light()
	area.player.global_position = area.cell_pos(Vector2i(19, 15))
	await shot("05_base_night", 70)
	TimeSystem.minute = 620
	QuestSystem.start("q_turno_c")
	UIManager.open("journal")
	await shot("06_journal", 15)
	UIManager.close_all()
	UIManager.open("options")
	await shot("07_options", 15)
	UIManager.close_all()
	for it in [["coal", 14], ["copper_ore", 6], ["scrap", 5], ["iron_ore", 9], ["flare", 2], ["battery", 1], ["dynamite", 3], ["medkit", 1]]:
		InventorySystem.add_item(it[0], it[1])
	UIManager.open("inventory")
	await shot("07a_inventory", 15)
	UIManager.panels["inventory"]._set_tab("status") if UIManager.panels["inventory"].has_method("_set_tab") else null
	await shot("07b_inventory_status", 10)
	UIManager.close_all()
	ProgressionSystem.add_xp(400, "teste")
	UIManager.close_all()
	UIManager.open("perks")
	await shot("07c_perks", 20)
	UIManager.close_all()
	UIManager.open("craft")
	await shot("07d_craft", 15)
	UIManager.close_all()
	UIManager.open("shop", {"tab": "contracts"})
	await shot("07e_contracts", 15)
	UIManager.close_all()
	GameState.set_flag("radio_fixed")
	UIManager.open("radio")
	var rp = UIManager.panels["radio"]
	rp.set_freq(7.25)
	await shot("07f_radio", 140)
	UIManager.close_all()
	area.player.global_position = area.cell_pos(Vector2i(2, 2))
	await shot("07g_hud_topleft", 40)
	area.player.global_position = area.cell_pos(Vector2i(3, 21))
	await shot("07h_hud_bottomleft", 40)
	GameState.max_depth = 3
	await SceneManager.enter_mine(4)
	await wait_area("MineLevel")
	await shot("08_mine_4", 70)
	var m = SceneManager.current_area
	if not m.layout.story.is_empty():
		m.player.global_position = m.cell_pos(m.layout.story.cell + Vector2i(0, 2))
		await shot("09_story_room", 60)
	var rocks = m.entities.get_children().filter(func(n): return n is Rock)
	rocks.sort_custom(func(a, b): return a.global_position.distance_to(m.player.global_position) < b.global_position.distance_to(m.player.global_position))
	for r in rocks.slice(0, 3):
		for i in 10:
			if not r.broken:
				r.hit(1.0, 3, Vector2.DOWN)
	await shot("10_mine_breaking", 6)
	GameState.max_depth = 14
	await SceneManager.enter_mine(14)
	await wait_area("MineLevel")
	await shot("11_mine_14", 70)
	await SceneManager.enter_mine(23)
	await wait_area("MineLevel")
	await shot("12_mine_23", 70)
	for t in ["tape_1", "tape_2", "tape_3", "tape_4", "tape_5"]:
		GameState.set_flag(t)
	await SceneManager.enter_mine(30)
	await wait_area("MineLevel")
	m = SceneManager.current_area
	if not m.layout.story.is_empty():
		m.player.global_position = m.cell_pos(m.layout.story.cell + Vector2i(0, 2))
	await shot("13_chamber_door", 70)
	UIManager.open("cutscene", {"scene": "chamber"})
	await shot("14_chamber_scene", 160)
	get_tree().quit()
