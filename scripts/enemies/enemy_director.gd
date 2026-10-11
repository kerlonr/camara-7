class_name EnemyDirector
extends Node
## Diretor de inimigos de uma área (mina ou superfície à noite).
## Decide quantos e onde nascem (escala por profundidade e dia, com teto), distribui "fichas" de ataque
## (no máximo N atacando ao mesmo tempo), aplica invulnerabilidade após dano e sabe onde há fogo/luz.

const ENEMY_SCRIPT := preload("res://scripts/enemies/enemy.gd")

var area: GameArea
var mode := "mine"                    # "mine" | "surface_night"
var enabled := true
var _rng := RandomNumberGenerator.new()
var _attackers: Array = []
var _iframes := 0.0
var _grace := 0.0
var _timers: Dictionary = {}          # enemy id -> segundos até próximo nascimento
var _alive: Dictionary = {}           # enemy id -> Array[Enemy]


func setup(p_area: GameArea, p_mode: String) -> void:
	area = p_area
	mode = p_mode


func _ready() -> void:
	_rng.randomize()
	_grace = float(_fair().get("level_grace_seconds", 18))
	for rule in _rules():
		_timers[rule.enemy] = _rng.randf_range(2.0, 6.0)
		_alive[rule.enemy] = []


func _fair() -> Dictionary:
	return DataManager.enemy_cfg.get("fairness", {})


func _rules() -> Array:
	return DataManager.enemy_cfg.get("spawns", {}).get(mode, [])


func player() -> Player:
	return area.player if area and is_instance_valid(area.player) else null


# ------------------------------------------------------------------ quantos / quão fortes
func target_count(rule: Dictionary) -> int:
	var depth := area.depth if area else 0
	var day := TimeSystem.day
	if depth < int(rule.get("min_depth", 0)) or day < int(rule.get("min_day", 0)):
		return 0
	var extra_depth := maxi(0, depth - int(rule.get("min_depth", 0)))
	var n := float(rule.get("base", 1)) + extra_depth * float(rule.get("per_depth", 0.0)) \
		+ maxi(0, day - int(rule.get("min_day", 1))) * float(rule.get("per_day", 0.0))
	return clampi(int(floor(n)), 0, int(rule.get("max", 3)))


func scaling() -> Vector2:
	var sc: Dictionary = DataManager.enemy_cfg.get("scaling", {})
	var depth := area.depth if area else 0
	var hp := minf(float(sc.get("hp_max", 1.8)), 1.0 + depth * float(sc.get("hp_per_depth", 0.04)))
	var dmg := minf(float(sc.get("damage_max", 1.45)),
		1.0 + depth * float(sc.get("damage_per_depth", 0.015)) + TimeSystem.day * float(sc.get("damage_per_day", 0.015)))
	return Vector2(hp, dmg)


# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
	if get_tree().paused or player() == null:
		return
	_iframes = maxf(0.0, _iframes - delta)
	_update_dread()
	if not enabled:
		return
	_grace = maxf(0.0, _grace - delta)
	if mode == "surface_night" and not is_night():
		_send_home()
		return
	for rule in _rules():
		var eid: String = rule.enemy
		_alive[eid] = _alive[eid].filter(func(e): return is_instance_valid(e) and e.state != Enemy.S.DEAD)
		_timers[eid] = float(_timers[eid]) - delta
		if _timers[eid] <= 0.0:
			var span: Array = rule.get("respawn_seconds", [60, 120])
			_timers[eid] = _rng.randf_range(float(span[0]), float(span[1]))
			if _alive[eid].size() < target_count(rule):
				spawn(eid)


func _update_dread() -> void:
	var p := player()
	var best := 0.0
	for eid in _alive:
		for e in _alive[eid]:
			if is_instance_valid(e) and (e.state == Enemy.S.CHASE or e.state == Enemy.S.WINDUP):
				best = maxf(best, 1.0 - e.global_position.distance_to(p.global_position) / 170.0)
	AudioSystem.set_dread(best)


func _exit_tree() -> void:
	AudioSystem.set_dread(0.0)


func is_night() -> bool:
	var m := TimeSystem.clock_minute()
	return m >= 1250 or m < 300


func _send_home() -> void:
	for eid in _alive:
		for e in _alive[eid]:
			if is_instance_valid(e) and e.state != Enemy.S.DEAD and e.state != Enemy.S.FLEE:
				e._set_state(Enemy.S.FLEE)


## Nasce num ponto de chão fora da vista e longe do jogador.
func spawn(eid: String, at: Vector2 = Vector2.INF) -> Enemy:
	var p := player()
	if p == null:
		return null
	var pos := at
	if pos == Vector2.INF:
		pos = _find_spawn(p)
		if pos == Vector2.INF:
			return null
	var sc := scaling()
	var e: Enemy = ENEMY_SCRIPT.new()
	e.setup(eid, self, sc.x, sc.y)
	e.position = pos
	area.entities.add_child(e)
	_alive[eid] = _alive.get(eid, [])
	_alive[eid].append(e)
	return e


func _find_spawn(p: Player) -> Vector2:
	var min_d := float(_fair().get("spawn_min_distance", 110))
	var view := p.get_viewport_rect().size
	var cam_center := p.camera.get_screen_center_position() if p.camera else p.global_position
	var cells: Array = area.floor_layer.get_used_cells()
	for attempt in 40:
		var c: Vector2i = cells[_rng.randi_range(0, cells.size() - 1)]
		if area.wall_layer.get_cell_source_id(c) != -1:
			continue
		var pos := area.cell_pos(c)
		if pos.distance_to(p.global_position) < min_d:
			continue
		if absf(pos.x - cam_center.x) < view.x * 0.5 + 8 and absf(pos.y - cam_center.y) < view.y * 0.5 + 8:
			continue                               # nunca nasce na frente do jogador
		if _blocked(pos):
			continue
		return pos
	return Vector2.INF


func _blocked(pos: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = pos + Vector2(0, -3)
	q.collision_mask = 1 | 4
	return not area.get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()


func despawn(e: Enemy) -> void:
	release_attack(e)
	if is_instance_valid(e):
		e.queue_free()


# ------------------------------------------------------------------ percepção
func can_notice(e: Enemy, p: Player, dist: float) -> bool:
	if _grace > 0.0:
		return false
	var sight := float(e.data.get("sight", 100)) * float(UpgradeSystem.get_stat("stealth", 1.0))
	if String(e.data.get("light_rule", "")) == "attracted":
		if p.lantern_on():
			sight *= 1.3
		if Input.is_action_pressed("run") and p.velocity.length() > 10.0:
			sight *= 1.4                          # correr faz barulho
		if not p.lantern_on():
			sight *= 0.55
	if String(e.data.get("light_rule", "")) == "burned_by_light":
		# o Vulto só se aproxima de quem está no escuro ou de costas para ele
		if p.lantern_on() and is_in_player_light(e.global_position + Vector2(0, -14)):
			return false
	if String(e.data.get("light_rule", "")) == "fears_fire" and nearest_fire(p.global_position) != Vector2.INF \
			and p.global_position.distance_to(nearest_fire(p.global_position)) < 64.0:
		return false                              # perto do fogo os cães não arriscam
	if dist > sight:
		return false
	return _line_of_sight(e.global_position + Vector2(0, -4), p.global_position + Vector2(0, -6))


func _line_of_sight(a: Vector2, b: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(a, b, 1)
	return area.get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func is_in_player_light(pos: Vector2) -> bool:
	var p := player()
	if p == null or not p.lantern_on():
		return false
	return p.point_in_cone(pos)


func nearest_fire(pos: Vector2) -> Vector2:
	var best := Vector2.INF
	for f in get_tree().get_nodes_in_group("fire_source"):
		if f is Node2D and is_instance_valid(f) and (best == Vector2.INF or pos.distance_to(f.global_position) < pos.distance_to(best)):
			best = f.global_position
	return best


func near_flare(pos: Vector2, radius: float) -> bool:
	for f in get_tree().get_nodes_in_group("flare_light"):
		if f is Node2D and is_instance_valid(f) and pos.distance_to(f.global_position) < radius:
			return true
	return false


# ------------------------------------------------------------------ combate justo
func request_attack(e: Enemy) -> bool:
	_attackers = _attackers.filter(func(a): return is_instance_valid(a) and a.state == Enemy.S.WINDUP)
	if e in _attackers:
		return true
	if _attackers.size() >= int(_fair().get("max_attackers", 2)):
		return false
	_attackers.append(e)
	return true


func release_attack(e: Enemy) -> void:
	_attackers.erase(e)


func hurt_player(e: Enemy, amount: float, exposure: float, dir: Vector2) -> void:
	var p := player()
	if p == null or _iframes > 0.0:
		return
	_iframes = float(_fair().get("player_iframes", 0.8))
	amount = minf(amount * float(UpgradeSystem.get_stat("damage_taken_mult", 1.0)), HealthSystem.max_hp() * 0.12)        # nenhum golpe tira mais de 12% da vida
	HealthSystem.damage(amount, "enemy")
	if exposure > 0.0:
		RadiationSystem.add_exposure(exposure)
	p.knockback(dir.normalized() * float(_fair().get("knockback", 70)))
	AudioSystem.play("hurt", 1.0 + _rng.randf_range(-0.08, 0.08))
	EventBus.camera_shake.emit(1.5, 0.18)
	if Settings.get_v("damage_numbers"):
		Effects.float_text(area.entities, p.position + Vector2(0, -26), "-%d" % int(ceilf(amount)), Color("#e05040"))


func on_enemy_alerted(_e: Enemy) -> void:
	AudioSystem.play("stinger_soft", 1.0, -6.0)


func on_enemy_died(e: Enemy) -> void:
	release_attack(e)


func alive_count() -> int:
	var n := 0
	for eid in _alive:
		for e in _alive[eid]:
			if is_instance_valid(e) and e.state != Enemy.S.DEAD:
				n += 1
	return n
