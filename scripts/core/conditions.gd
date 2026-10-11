class_name Conditions
extends RefCounted
## Avalia condições em texto usadas pelos dados (diálogos, missões, rádio, objetos, mina).
##
## Uma lista (Array) = todas precisam passar (E). Dentro de uma string, "||" = OU.
## Prefixo "!" nega. Formatos:
##   flag                      flag de história ligada
##   quest:id                  missão ativa ou concluída
##   quest_active:id           missão ativa
##   quest_done:id             missão concluída
##   quest_ready:id            missão ativa com objetivos cumpridos
##   has:item>=N               itens no inventário
##   upgrade:id>=N             nível de upgrade
##   chave<op>N                day, money, max_depth, depth, exposure, hp, tapes, descents
##   (op: >=, <=, >, <, ==)

static var _re: RegEx


static func check(conds) -> bool:
	if conds == null:
		return true
	if conds is String:
		return _check_or(conds)
	if conds is Array:
		for c in conds:
			if not _check_or(String(c)):
				return false
		return true
	return true


static func _check_or(expr: String) -> bool:
	expr = expr.strip_edges()
	if expr == "":
		return true
	if expr.contains("||"):
		for part in expr.split("||"):
			if _check_one(part.strip_edges()):
				return true
		return false
	return _check_one(expr)


static func _check_one(c: String) -> bool:
	if c.begins_with("!"):
		return not _check_one(c.substr(1))
	if _re == null:
		_re = RegEx.create_from_string("^([a-z_]+(?::[a-z0-9_]+)?)\\s*(>=|<=|==|>|<)\\s*(-?[0-9.]+)$")
	var m := _re.search(c)
	if m:
		var val := _value(m.get_string(1))
		var rhs := float(m.get_string(3))
		match m.get_string(2):
			">=": return val >= rhs
			"<=": return val <= rhs
			">": return val > rhs
			"<": return val < rhs
			"==": return is_equal_approx(val, rhs)
		return false
	if c.begins_with("perk:"):
		return ProgressionSystem.has_perk(c.substr(5))
	if c.begins_with("quest_done:"):
		return QuestSystem.is_done(c.substr(11))
	if c.begins_with("quest_ready:"):
		return QuestSystem.is_ready(c.substr(12))
	if c.begins_with("quest_active:"):
		return QuestSystem.is_active(c.substr(13))
	if c.begins_with("quest:"):
		var q := c.substr(6)
		return QuestSystem.is_active(q) or QuestSystem.is_done(q)
	return GameState.has_flag(c)


static func _value(key: String) -> float:
	if key.begins_with("has:"):
		return InventorySystem.count(key.substr(4))
	if key.begins_with("upgrade:"):
		return UpgradeSystem.level(key.substr(8))
	match key:
		"day": return TimeSystem.day
		"money": return EconomySystem.money
		"max_depth": return GameState.max_depth
		"depth": return GameState.depth
		"exposure": return RadiationSystem.exposure
		"hp": return HealthSystem.hp
		"tapes": return StorySystem.tapes_found()
		"descents": return GameState.descents
		"level": return ProgressionSystem.level
	push_warning("[Conditions] chave desconhecida: %s" % key)
	return 0.0
