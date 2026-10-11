class_name ActionRouter
extends RefCounted
## Resolve ações de interação (vindas de dados) para chamadas de sistemas/UI.
## Nova ação = um novo 'match' aqui + o nome no JSON.


static func perform(action: String, params: Dictionary, source: Node = null) -> void:
	match action:
		"sleep":
			UIManager.open("confirm", {
				"title": "TRAILER",
				"text": "Dormir até amanhã?\nO jogo será salvo. Energia e vida serão restauradas.",
				"yes": "Dormir", "on_yes": SceneManager.sleep,
			})
		"shop":
			AudioSystem.play("ui_open")
			UIManager.open("shop")
		"decon":
			UIManager.open("decon")
		"mine":
			if int(UpgradeSystem.get_stat("elevator", 0)) > 0 and GameState.checkpoints().size() > 1:
				UIManager.open("elevator")
			else:
				SceneManager.enter_mine(1)
		"ladder_up":
			SceneManager.go_to_base("from_mine")
		"ladder_down":
			SceneManager.enter_mine(GameState.depth + 1)
		"elevator":
			UIManager.open("elevator")
		"special":
			var n := source.get_tree().root.get_node_or_null(NodePath(String(params.get("node", "")))) if source else null
			if n and n.has_method("interact"):
				n.interact()
		"craft":
			AudioSystem.play("ui_open")
			UIManager.open("craft")
		"talk":
			UIManager.open("dialogue", {"npc": params.get("npc", "")})
		"machine":
			MachineSystem.interact(params.get("machine", ""))
		"radio":
			if GameState.has_flag("radio_fixed"):
				UIManager.open("radio")
			else:
				AudioSystem.play("radio_burst", 1.0, -6.0)
				EventBus.toast.emit("O rádio está mudo. O Kolya talvez saiba consertar.", "info")
		"note":
			var id: String = params.get("note", "")
			GameState.find_note(id)
			AudioSystem.play("paper")
			UIManager.open("note", {"note": id})
			if source and params.get("consume", false):
				source.get_parent().queue_free()
		"terminal":
			var tid: String = params.get("note", "")
			GameState.find_note(tid)
			AudioSystem.play("terminal_beep")
			UIManager.open("note", {"note": tid})
		"story_pickup":
			var p: Dictionary = params.get("placement", {})
			if p.is_empty() or GameState.has_flag(p.id):
				return
			StorySystem.collect_story_object(p)
			if source:
				source.queue_free()
		"final_door":
			if StorySystem.tapes_found() >= 5:
				UIManager.open("cutscene", {"scene": "chamber"})
			else:
				AudioSystem.play("door_heavy", 0.7, -6.0)
				UIManager.open("cutscene", {"scene": "chamber_locked"})
		_:
			push_warning("[ActionRouter] ação desconhecida: %s" % action)
