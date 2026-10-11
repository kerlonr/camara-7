extends Node
## Teste automatizado do ciclo principal. Rodar:
##   godot --headless --path . res://tests/smoke_test.tscn
## Sai com código 0 se tudo passar, 1 se algo falhar.

var _fails := 0


func _ready() -> void:
	SaveSystem.save_dir = "user://test_saves/"   # nunca tocar no save real
	# sobrevive à troca de cena
	reparent.call_deferred(get_tree().root)
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		_fails += 1
		printerr("  FAIL ", msg)


func wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait_area(script_class: String) -> void:
	for i in 600:
		await get_tree().process_frame
		var a = SceneManager.current_area
		if a and is_instance_valid(a) and a.get_script() and a.get_script().get_global_name() == script_class \
				and not SceneManager.busy and a.player:
			return
	check(false, "timeout esperando área " + script_class)


func _run() -> void:
	await wait_frames(2)
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	print("== Determinismo da geração")
	var g1 := MineGenerator.new().generate(8472191, 7, {"descent": 3})
	var g2 := MineGenerator.new().generate(8472191, 7, {"descent": 3})
	var g3 := MineGenerator.new().generate(8472191, 8, {"descent": 3})
	var g4 := MineGenerator.new().generate(8472191, 7, {"descent": 4})
	check(str(g1.rocks) == str(g2.rocks) and g1.spawn == g2.spawn, "mesma seed+nível+descida = mesma mina (reprodutível)")
	check(str(g1.rocks) != str(g3.rocks), "nível diferente = mina diferente")
	check(str(g1.rocks) != str(g4.rocks) and str(g1.room_types) != str(g4.room_types), "cada descida gera uma mina diferente")
	var types := {}
	var events := 0
	var rich := 0
	for k in 20:
		var L := MineGenerator.new().generate(99, 12, {"descent": k})
		for t in L.room_types:
			types[t] = true
		events += L.events.size()
		for r in L.rocks:
			if r.get("rich", false):
				rich += 1
	check(types.size() >= 8, "variedade de salas em 20 descidas: %d tipos" % types.size())
	check(events >= 3, "eventos de nível acontecem (%d em 20 descidas)" % events)
	check(rich > 0, "veios ricos aparecem (%d)" % rich)
	var st := MineGenerator.new().generate(5, 4, {"descent": 1, "story": {"id": "tape_1", "kind": "tape"}})
	check(not st.story.is_empty(), "sala de história com a fita 1 é gerada no nível 4")

	print("== Validação de 40 níveis")
	var t0 := Time.get_ticks_msec()
	var bad := 0
	for d in range(1, 41):
		var L := MineGenerator.new().generate(1234, d, {"descent": d * 7})
		var rock_cells := {}
		for r in L.rocks:
			rock_cells[r.cell] = true
		if not _path_exists(L, rock_cells):
			bad += 1
			printerr("    nível %d sem caminho livre" % d)
		if L.rocks.size() < 20:
			bad += 1
			printerr("    nível %d com poucas rochas (%d)" % [d, L.rocks.size()])
	check(bad == 0, "40 níveis com caminho livre entrada→saída e rochas suficientes (%d ms)" % (Time.get_ticks_msec() - t0))

	print("== Novo jogo")
	SceneManager.start_new_game(4242)
	await wait_area("BaseArea")
	await wait_frames(5)
	check(UIManager.is_open("cutscene"), "intro de 1986 abre no novo jogo")
	UIManager.close("cutscene")
	await wait_frames(3)
	check(ProgressionSystem.trait_pending and UIManager.is_open("perks"), "escolha de traço abre depois da intro")
	var en0 := HealthSystem.max_energy()
	check(ProgressionSystem.choose_trait("coruja") and not ProgressionSystem.trait_pending, "escolheu traço")
	check(HealthSystem.max_energy() < en0 and float(UpgradeSystem.get_stat("battery_minutes", 0)) > 900.0, "traço aplica vantagem e desvantagem")
	check(not ProgressionSystem.choose_trait("braco"), "traço é escolhido uma vez só")
	UIManager.close_all()
	check(GameState.location == "base", "começa na base")
	check(InventorySystem.count("pickaxe") == 1, "tem a ferramenta")
	var money0 := EconomySystem.money

	print("== Mina nível 1")
	await SceneManager.enter_mine(1)
	await wait_area("MineLevel")
	var area: MineLevel = SceneManager.current_area
	check(GameState.depth == 1, "profundidade 1")
	var rocks := area.entities.get_children().filter(func(n): return n is Rock and not n.is_container)
	check(rocks.size() > 10, "rochas geradas: %d" % rocks.size())
	var broken := 0
	for r in rocks.slice(0, 12):
		for i in 30:
			if r.broken:
				break
			r.hit(1.0, 1, Vector2.DOWN)
		if r.broken:
			broken += 1
		await get_tree().process_frame
	check(broken == 12, "quebrou 12 rochas")
	await wait_frames(30)
	var picks := area.entities.get_children().filter(func(n): return n is Pickup)
	check(picks.size() >= 12, "drops físicos gerados: %d" % picks.size())
	for p in picks:
		p._collect()
	var cargo := 0
	for id in InventorySystem.unique_items():
		if DataManager.get_item(id).get("category", "") in ["ore", "material"]:
			cargo += InventorySystem.count(id)
	check(cargo >= 12, "itens coletados no inventário: %d" % cargo)

	print("== Controle por entrada simulada")
	var player: Player = area.player
	var p0 := player.global_position
	Input.action_press("move_right")
	await wait_frames(20)
	Input.action_release("move_right")
	check(player.global_position.distance_to(p0) > 4.0, "andar para a direita move o jogador (%.0f px)" % player.global_position.distance_to(p0))
	# acha uma rocha com célula livre acima
	var target: Rock = null
	var occupied := {}
	for n in area.entities.get_children():
		if n is Rock and not n.broken:
			occupied[area.world_to_cell(n.global_position - Vector2(0, 1))] = true
	for n in area.entities.get_children():
		if n is Rock and not n.broken and not n.is_container and n.min_tier() <= 1:
			var c := area.world_to_cell(n.global_position - Vector2(0, 1))
			var up := c + Vector2i(0, -1)
			if area.floor_layer.get_cell_source_id(up) != -1 and area.wall_layer.get_cell_source_id(up) == -1 and not occupied.has(up):
				target = n
				player.global_position = area.cell_pos(up) + Vector2(0, -2)
				break
	check(target != null, "encontrou rocha alcançável")
	if target:
		player.facing = Vector2.DOWN
		var e0 := HealthSystem.energy
		await wait_frames(3)
		Input.action_press("use_tool")
		for i in 240:
			await get_tree().physics_frame
			if not is_instance_valid(target) or target.broken:
				break
		Input.action_release("use_tool")
		check(not is_instance_valid(target) or target.broken, "segurar o botão minera a rocha mirada")
		check(HealthSystem.energy < e0, "golpes gastam energia (%.0f -> %.0f)" % [e0, HealthSystem.energy])
		await wait_frames(60)
	# interação: escada de saída via tecla E
	var up_cell: Vector2i = area.layout.ladder_up
	player.global_position = area.cell_pos(up_cell + Vector2i(0, 1)) + Vector2(0, -4)
	player.facing = Vector2.UP
	await wait_frames(5)
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait_area("BaseArea")
	check(GameState.location == "base", "E na escada leva de volta à base")
	await SceneManager.enter_mine(1)
	await wait_area("MineLevel")
	area = SceneManager.current_area

	print("== Radiação")
	RadiationSystem.ambient_rate = 0.5
	var e0 := RadiationSystem.exposure
	await wait_frames(30)
	check(RadiationSystem.exposure > e0, "exposição sobe em área radioativa (%.2f)" % RadiationSystem.exposure)
	RadiationSystem.ambient_rate = 0.0

	print("== Voltar e vender")
	await SceneManager.go_to_base("from_mine")
	await wait_area("BaseArea")
	var got := EconomySystem.sell_all_cargo()
	check(got > 0 and EconomySystem.money == money0 + got, "vendeu carga por %d" % got)

	print("== Upgrade")
	EconomySystem.add_money(1000)
	var ok := UpgradeSystem.purchase("tool")
	check(ok and int(UpgradeSystem.get_stat("tool_power")) == 2, "comprou picareta de ferro (poder 2)")
	check(int(UpgradeSystem.get_stat("tool_tier")) == 2, "tier da ferramenta = 2")
	check(not UpgradeSystem.check("drill_rig").ok, "perfuratriz bloqueada sem gerador")

	print("== Automação")
	GameState.max_depth = 5
	InventorySystem.add_item("iron_ore", 30)
	InventorySystem.add_item("copper_ore", 10)
	InventorySystem.add_item("mech_parts", 4)
	InventorySystem.add_item("coal", 10)
	EconomySystem.add_money(5000)
	check(UpgradeSystem.purchase("generator"), "comprou gerador")
	check(UpgradeSystem.purchase("drill_rig"), "comprou perfuratriz")
	MachineSystem.interact("generator")
	check(MachineSystem.has_power(), "gerador abastecido com carvão")
	MachineSystem.advance(400)
	check(MachineSystem.buffer_total("drill") >= 9, "perfuratriz produziu %d itens em 400 min" % MachineSystem.buffer_total("drill"))

	print("== Save / Load")
	var money_before := EconomySystem.money
	var lv_before := UpgradeSystem.level("tool")
	var inv_before := InventorySystem.count("iron_ore")
	check(SaveSystem.save_game(99), "salvou no slot 99")
	EconomySystem.money = 0
	UpgradeSystem.reset()
	InventorySystem.reset()
	check(SaveSystem.load_game(99), "carregou slot 99")
	check(EconomySystem.money == money_before, "dinheiro restaurado")
	check(UpgradeSystem.level("tool") == lv_before, "upgrades restaurados")
	check(InventorySystem.count("iron_ore") == inv_before, "inventário restaurado")
	DirAccess.remove_absolute(SaveSystem.slot_path(99))

	print("== Mina profunda (nível 25)")
	await SceneManager.enter_mine(25)
	await wait_area("MineLevel")
	check(RadiationSystem.ambient_rate > 0.0, "radiação ambiente no nível 25: %.3f" % RadiationSystem.ambient_rate)

	print("== Desmaio por radiação")
	EconomySystem.money = 1000
	InventorySystem.add_item("iron_ore", 10)
	EventBus.player_passed_out.emit("radiation")
	for i in 900:
		await get_tree().process_frame
		if not SceneManager.busy and GameState.location == "base" and SceneManager.current_area is BaseArea:
			break
	await wait_area("BaseArea")
	check(GameState.location == "base", "resgatado para a base")
	check(EconomySystem.money < 1000, "pagou taxa de resgate (%d)" % EconomySystem.money)
	check(RadiationSystem.exposure <= 55.0, "exposição reduzida após resgate")

	print("== Painéis")
	for pname in ["inventory", "shop", "pause", "notes", "decon", "elevator", "perks", "craft", "radio", "journal"]:
		UIManager.open(pname)
		await wait_frames(2)
		check(UIManager.is_open(pname) and get_tree().paused, "abre painel '%s' e pausa" % pname)
		UIManager.close_all()
	UIManager.open("dialogue", {"npc": "kolya"})
	await wait_frames(2)
	check(UIManager.is_open("dialogue"), "diálogo com NPC")
	UIManager.close_all()
	await wait_frames(2)
	check(not get_tree().paused, "fechar painéis despausa")
	EconomySystem.money = 500
	RadiationSystem.exposure = 40.0
	UIManager.open("decon")
	UIManager.panels["decon"]._do()
	check(RadiationSystem.exposure == 0.0 and EconomySystem.money == 420, "descontaminação zera exposição por 80 Cr")
	UIManager.close_all()

	print("== Dormir")
	var had_save := SaveSystem.has_save(1)
	var day0 := TimeSystem.day
	HealthSystem.energy = 10.0
	await SceneManager.sleep()
	check(TimeSystem.day == day0 + 1, "dormir avança o dia")
	check(HealthSystem.energy >= HealthSystem.max_energy() - 0.1, "dormir restaura energia")
	check(SaveSystem.has_save(1), "dormir salva o jogo")
	if not had_save:
		DirAccess.remove_absolute(SaveSystem.slot_path(1))

	print("== História e NPCs")
	check(Conditions.check(["day>=1", "!flag_inexistente"]), "condições simples")
	check(Conditions.check("max_depth>=999 || day>=1"), "condição OU")
	var n := StorySystem.start_node("oksana")
	check(n == "intro" or n == "hub", "diálogo da Oksana começa (%s)" % n)
	var node := StorySystem.enter_node("oksana", "story1")
	check(GameState.has_flag("oksana_story") and node.options.size() > 0, "nó de história marca flag e tem opções")
	var hub := StorySystem.enter_node("oksana", "hub")
	var offer = null
	for o in hub.options:
		if o.get("node", "") == "turno_offer":
			offer = o
	check(offer != null, "opção de missão aparece no hub")
	StorySystem.choose("oksana", {"quest_start": "q_turno_c", "node": "hub"})
	check(QuestSystem.is_active("q_turno_c") and QuestSystem.tracked == "q_turno_c", "missão principal iniciada e rastreada")
	var p := StorySystem.pending_placement(4)
	check(p.get("id", "") == "tape_1", "fita 1 pendente no nível 4")
	StorySystem.collect_story_object(p)
	UIManager.close_all()
	check(StorySystem.tapes_found() == 1 and InventorySystem.count("tape_1") == 1, "fita coletada vira item e flag")
	check(StorySystem.pending_placement(4).is_empty() and StorySystem.pending_placement(9).get("id", "") == "tape_2", "próxima fita só a partir do nível 9")
	QuestSystem.start("q_radio")
	InventorySystem.add_item("elec_components", 3)
	check(QuestSystem.is_ready("q_radio"), "missão do rádio pronta com 3 componentes")
	var m0 := EconomySystem.money
	check(QuestSystem.complete("q_radio") and GameState.has_flag("radio_fixed") and EconomySystem.money > m0, "entregar missão dá recompensa e conserta o rádio")
	var b1 := StorySystem.next_broadcast()
	check(b1.get("id", "") == "r_tass", "primeira transmissão é o anúncio oficial")
	for t in ["tape_2", "tape_3", "tape_4", "tape_5"]:
		GameState.set_flag(t)
	check(StorySystem.tapes_found() == 5, "cinco fitas")
	StorySystem.apply_ending("ending_truth")
	check(GameState.has_flag("chamber_opened") and QuestSystem.is_done("q_turno_c"), "final conclui a missão principal")
	check(Conditions.check(["ending_truth"]), "flag do final gravada")

	print("== Progressão (XP, níveis, talentos)")
	ProgressionSystem.reset()
	ProgressionSystem.trait_pending = false
	UpgradeSystem.recalc()
	var lv0 := ProgressionSystem.level
	ProgressionSystem.add_xp(ProgressionSystem.xp_to_next() + 5, "teste")
	check(ProgressionSystem.level == lv0 + 1 and ProgressionSystem.pending_picks == 1, "XP sobe de nível e libera talento")
	var off := ProgressionSystem.current_offer()
	check(off.size() == 3 and str(off) == str(ProgressionSystem.current_offer()), "oferta de 3 talentos estável até escolher")
	var picked: String = "bateria" if off.has("bateria") else off[0]
	var reach0 := float(UpgradeSystem.get_stat("battery_minutes", 0))
	check(ProgressionSystem.choose(picked) and ProgressionSystem.has_perk(picked) and ProgressionSystem.pending_picks == 0, "escolheu talento '%s'" % picked)
	if picked == "bateria":
		check(float(UpgradeSystem.get_stat("battery_minutes", 0)) > reach0, "talento altera atributo")
	check(not ProgressionSystem.choose("golpe_certeiro"), "não escolhe sem nível pendente")
	var xp0 := ProgressionSystem.xp + ProgressionSystem.level * 100000
	ProgressionSystem.discover("coal")
	ProgressionSystem.discover("coal")
	check(ProgressionSystem.discovered.count("coal") == 1, "catálogo registra descoberta uma vez")

	print("== Contratos")
	ContractSystem.reset()
	ContractSystem.ensure_today()
	var cl := ContractSystem.active()
	check(cl.size() == int(ContractSystem.cfg().get("per_day", 3)), "contratos do dia gerados (%d)" % cl.size())
	var c0: Dictionary = cl[0]
	check(not ContractSystem.can_deliver(c0) or InventorySystem.count(c0.item) >= int(c0.amount), "não entrega sem itens")
	InventorySystem.add_item(c0.item, int(c0.amount))
	var mc := EconomySystem.money
	var lvx := ProgressionSystem.level * 100000 + ProgressionSystem.xp
	check(ContractSystem.deliver(c0.id) and EconomySystem.money == mc + int(c0.money), "entregou contrato (+%d Cr)" % int(c0.money))
	check(ProgressionSystem.level * 100000 + ProgressionSystem.xp > lvx, "contrato dá XP")
	check(ContractSystem.active().size() == cl.size() - 1, "contrato entregue sai da lista")

	print("== Bancada")
	var rf: Dictionary = {}
	for r in Crafting.recipes():
		if r.id == "r_flare":
			rf = r
	check(not rf.is_empty(), "receita de sinalizador existe")
	for it in rf.get("items", {}):
		InventorySystem.add_item(it, int(rf.items[it]))
	var fl0 := InventorySystem.count("flare")
	check(Crafting.can_craft(rf) and Crafting.craft(rf) and InventorySystem.count("flare") == fl0 + int(rf.get("amount", 1)), "fabricou sinalizador")
	for r in Crafting.recipes():
		var ic: String = DataManager.get_item(r.result).get("icon", "")
		check(ic == "" or ResourceLoader.exists(ic), "ícone de '%s' existe" % r.result)

	print("== Bateria da lanterna")
	HealthSystem.battery = 100.0
	HealthSystem.drain_battery(60.0)
	check(HealthSystem.battery < 100.0, "lanterna gasta bateria (%.1f%%)" % HealthSystem.battery)
	InventorySystem.add_item("battery", 1)
	var bslot := -1
	for i in InventorySystem.slots.size():
		var sl = InventorySystem.slots[i]
		if sl and sl.get("id", "") == "battery":
			bslot = i
	if bslot >= 0:
		InventorySystem.use_slot(bslot)
	check(HealthSystem.battery >= 99.9, "trocar bateria recarrega")

	print("== Inimigos (equilíbrio e justiça)")
	check(DataManager.enemies.size() == 3, "3 tipos de inimigo carregados")
	await SceneManager.enter_mine(14)
	await wait_area("MineLevel")
	var ml = SceneManager.current_area
	var dir: EnemyDirector = ml.enemies
	check(dir != null, "mina tem diretor de inimigos")
	dir.enabled = false
	var rules := {}
	for r in DataManager.enemy_cfg.spawns.mine:
		rules[r.enemy] = r
	var dog_rule: Dictionary = DataManager.enemy_cfg.spawns.surface_night[0]
	var save_depth: int = ml.depth
	var save_day := TimeSystem.day
	ml.depth = 1
	check(dir.target_count(rules.rat) == 0, "nível 1 sem ratos")
	ml.depth = 2
	TimeSystem.day = 1
	check(dir.target_count(rules.rat) == 1, "nível 2: 1 rato")
	check(dir.target_count(rules.vulto) == 0, "Vulto não aparece antes do nível 12")
	ml.depth = 12
	check(dir.target_count(rules.vulto) == 1, "nível 12: 1 Vulto")
	ml.depth = 200
	TimeSystem.day = 300
	check(dir.target_count(rules.rat) <= 6 and dir.target_count(rules.vulto) <= 3, "quantidade tem teto mesmo no fim do jogo")
	var sc := dir.scaling()
	check(sc.x <= 1.8001 and sc.y <= 1.4501, "força tem teto (vida x%.2f, dano x%.2f)" % [sc.x, sc.y])
	TimeSystem.day = 2
	check(dir.target_count(dog_rule) == 0, "sem cães antes do dia 3")
	TimeSystem.day = 3
	check(dir.target_count(dog_rule) == 1, "dia 3: 1 cão")
	ml.depth = save_depth
	TimeSystem.day = save_day
	HealthSystem.full_restore()
	var hp0 := HealthSystem.hp
	var rat := dir.spawn("rat", ml.player.global_position + Vector2(40, 0))
	dir.hurt_player(rat, 9999.0, 0.0, Vector2.RIGHT)
	check(hp0 - HealthSystem.hp <= HealthSystem.max_hp() * 0.12 + 0.01, "nenhum golpe tira mais de 12%% da vida (%.1f)" % (hp0 - HealthSystem.hp))
	var hp1 := HealthSystem.hp
	dir.hurt_player(rat, 5.0, 0.0, Vector2.RIGHT)
	check(HealthSystem.hp == hp1, "invulnerabilidade logo após levar dano")
	var r2 := dir.spawn("rat", ml.player.global_position + Vector2(-40, 0))
	var r3 := dir.spawn("rat", ml.player.global_position + Vector2(0, 40))
	rat.state = Enemy.S.WINDUP
	r2.state = Enemy.S.WINDUP
	r3.state = Enemy.S.WINDUP
	check(dir.request_attack(rat) and dir.request_attack(r2), "dois podem atacar")
	check(not dir.request_attack(r3), "terceiro espera a vez (máx. 2 atacando)")
	dir.release_attack(rat)
	dir.release_attack(r2)
	for e in [rat, r2, r3]:
		e.state = Enemy.S.WANDER
	var hits := 0
	while rat.state != Enemy.S.DEAD and hits < 20:
		rat.hit(1.0, 1, Vector2.RIGHT)
		hits += 1
	check(hits <= 4, "rato morre com %d golpes da picareta inicial" % hits)
	var v := dir.spawn("vulto", ml.player.global_position + Vector2(30, -6))
	check(v.hit(5.0, 3, Vector2.RIGHT) == "fail", "picareta atravessa o Vulto")
	GameState.lantern_on = true
	HealthSystem.battery = 100.0
	ml.player.facing = Vector2.RIGHT
	ml.player._mouse_moved_at = -100.0
	for i in 40:
		await get_tree().physics_frame
	var vhp := v.hp
	for i in 30:
		await get_tree().physics_frame
	check(not is_instance_valid(v) or v.hp < vhp or v.state == Enemy.S.FLEE, "lanterna queima/espanta o Vulto")
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	HealthSystem.full_restore()

	print("== Encontros especiais (todos forçados)")
	var spcfg := DataManager.load_json("mines/specials.json")
	for spd in spcfg.entries:
		await SceneManager.enter_mine(12)
		await wait_area("MineLevel")
		var lv = SceneManager.current_area
		lv.enemies.enabled = false
		if lv.special:
			lv.special.queue_free()
		var se := SpecialEncounter.new()
		se.level = lv
		se.data = spd
		se._rng.seed = 99
		lv.add_child(se)
		await get_tree().physics_frame
		var xpb: int = ProgressionSystem.level * 100000 + ProgressionSystem.xp
		if spd.id in ["lost_miner", "geiger_song"]:
			lv.player.global_position = se.global_position + Vector2(0, 4)
			await get_tree().create_timer(7.0).timeout
		else:
			se.interact()
			await wait_frames(4)
		check(GameState.has_flag("special_" + String(spd.id)) and ProgressionSystem.level * 100000 + ProgressionSystem.xp > xpb,
			"encontro '%s' funciona e recompensa" % spd.id)
	check(GameState.has_flag("kolya_stash_found"), "esconderijo do Kolya marca a flag")

	print("== Bateria de níveis com inimigos ativos")
	var errs_before := _fails
	for dp in [2, 6, 12, 18, 25]:
		await SceneManager.enter_mine(dp)
		await wait_area("MineLevel")
		var lv2 = SceneManager.current_area
		lv2.enemies._grace = 0.0
		for rule in DataManager.enemy_cfg.spawns.mine:
			for k in lv2.enemies.target_count(rule):
				lv2.enemies.spawn(rule.enemy)
		for i in 90:
			await get_tree().physics_frame
		HealthSystem.full_restore()
	check(_fails == errs_before and get_tree().get_nodes_in_group("enemy").size() > 0, "5 níveis com inimigos rodando sem erro")
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	HealthSystem.full_restore()
	await SceneManager.go_to_base("default", false)
	await wait_area("BaseArea")

	print("== Migração de save")
	var old := {"save_version": 1, "systems": {"game_state": {"world_seed": 7, "max_depth": 3, "flags": []}, "economy": {"money": 123}}}
	var migrated: Dictionary = SaveSystem._migrate(old)
	check(int(migrated.save_version) == SaveSystem.SAVE_VERSION and migrated.systems.has("quests") and migrated.systems.has("progression") \
		and migrated.systems.game_state.flags is Dictionary, "save v1 migra até a versão atual")
	# cópia do save real do jogador (somente leitura do original)
	var real := "user://saves/slot_1.json"
	if FileAccess.file_exists(real):
		var raw := FileAccess.get_file_as_string(real)
		DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
		var f := FileAccess.open(SaveSystem.slot_path(7), FileAccess.WRITE)
		f.store_string(raw)
		f.close()
		var src: Dictionary = JSON.parse_string(raw)
		var money_real := int(src.get("systems", {}).get("economy", {}).get("money", -1))
		check(SaveSystem.load_game(7), "save real do jogador (cópia) carrega na v0.3")
		check(EconomySystem.money == money_real, "dinheiro do save real preservado (%d)" % money_real)
		check(ProgressionSystem.level >= 1 and ProgressionSystem.pending_picks == ProgressionSystem.level - 1, "save antigo ganha nível %d e %d talento(s) para escolher" % [ProgressionSystem.level, ProgressionSystem.pending_picks])
		check(FileAccess.get_file_as_string(real) == raw, "save real intocado")
		DirAccess.remove_absolute(SaveSystem.slot_path(7))

	print("")
	if _fails == 0:
		print("SMOKE TEST OK")
	else:
		printerr("SMOKE TEST: %d falha(s)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _path_exists(L: Dictionary, rock_cells: Dictionary) -> bool:
	var w: int = L.w
	var start: Vector2i = L.spawn
	var goal: Vector2i = L.ladder_down
	var seen := {start: true}
	var q := [start]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		if c == goal:
			return true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= L.h or seen.has(n):
				continue
			if L.grid[n.y * w + n.x] != MineGenerator.FLOOR:
				continue
			if rock_cells.has(n) and n != goal:
				continue
			seen[n] = true
			q.append(n)
	return false
