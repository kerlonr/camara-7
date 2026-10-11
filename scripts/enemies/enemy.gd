class_name Enemy
extends CharacterBody2D
## Inimigo genérico guiado por data/enemies/enemies.json.
## Estados: WANDER → CHASE → WINDUP (golpe telegrafado) → RECOVER; FLEE com pouca vida ou medo de fogo/luz;
## STAGGER ao apanhar. Implementa a mesma interface das rochas (grupo "mineable": hit(), hit_center(),
## broken, display_name()) para a picareta acertar sem código especial no jogador.

enum S { WANDER, CHASE, WINDUP, RECOVER, FLEE, STAGGER, DEAD }

var id := ""
var data: Dictionary = {}
var director: EnemyDirector
var hp := 1.0
var max_hp := 1.0
var dmg_mult := 1.0
var broken := false           # compatível com a mira da picareta
var state := S.WANDER

var _sprite: Sprite2D
var _eyes: Node2D
var _frames := 4
var _anim_t := 0.0
var _state_t := 0.0
var _wander_dir := Vector2.ZERO
var _home := Vector2.ZERO
var _stuck_t := 0.0
var _detour := Vector2.ZERO
var _detour_t := 0.0
var _idle_sound_t := 3.0
var _alerted := false
var _hit_flash := 0.0
var _knock := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _fade := 1.0


func setup(p_id: String, p_director: EnemyDirector, p_hp_mult: float, p_dmg_mult: float) -> void:
	id = p_id
	director = p_director
	data = DataManager.enemies.get(id, {})
	max_hp = float(data.get("hp", 5)) * p_hp_mult
	hp = max_hp
	dmg_mult = p_dmg_mult


func _ready() -> void:
	_rng.randomize()
	add_to_group("enemy")
	add_to_group("mineable")
	collision_layer = 16
	collision_mask = 1 | 4
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = float(data.get("body_radius", 5))
	shape.shape = c
	shape.position = Vector2(0, -c.radius)
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = DataManager.texture(String(data.get("sheet", "")))
	var fr: Array = data.get("frame", [16, 16])
	if _sprite.texture:
		_frames = maxi(1, int(_sprite.texture.get_width() / int(fr[0])))
	_sprite.hframes = _frames
	_sprite.centered = false
	_sprite.offset = Vector2(-int(fr[0]) / 2, -int(fr[1]))
	if id == "vulto":
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED   # silhueta visível no escuro (é o ponto)
		_sprite.material = m
		_sprite.modulate = Color(1, 1, 1, 0.0)
	add_child(_sprite)
	if data.has("eyes"):          # olhos refletindo no escuro (estilo Darkwood): sempre visíveis, mesmo sem luz
		_eyes = Node2D.new()
		var m2 := CanvasItemMaterial.new()
		m2.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		var col := Color(String(data.eyes.get("color", "#ffd25a")))
		var glow := Sprite2D.new()                 # halo fraco: dá para ver de longe no escuro
		glow.texture = DataManager.texture("res://assets/effects/light_soft.png")
		glow.scale = Vector2(0.075, 0.05)
		glow.position = Vector2(0.5, 0.5)
		glow.modulate = Color(col, 0.55)
		glow.material = m2
		_eyes.add_child(glow)
		for dx in [0, 2]:
			var px := ColorRect.new()
			px.size = Vector2(1, 1)
			px.position = Vector2(dx - 1, 0)
			px.color = col
			px.material = m2
			px.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_eyes.add_child(px)
		add_child(_eyes)
	_home = global_position
	_pick_wander()


## Mira da picareta: vermelho quando a ferramenta não adianta (o Vulto).
func can_mine(_tier: int) -> bool:
	return float(data.get("pickaxe_mult", 1.0)) > 0.0


func display_name() -> String:
	return String(data.get("name", id))


func hit_center() -> Vector2:
	var fr: Array = data.get("frame", [16, 16])
	return global_position + Vector2(0, -float(fr[1]) * 0.45)


## Golpe da picareta. Retorna "fail" (imune), "hit" ou "break" (morreu).
func hit(power: float, _tier: int, dir: Vector2) -> String:
	if state == S.DEAD:
		return "fail"
	var mult := float(data.get("pickaxe_mult", 1.0))
	if mult <= 0.0:
		AudioSystem.play_at("whisper", global_position, 1.4, -10.0)
		Effects.dust(get_parent(), position + Vector2(0, -10), 3)
		return "fail"
	take_damage(power * mult * float(DataManager.enemy_cfg.get("fairness", {}).get("tool_damage_mult", 3.0)), dir)
	return "break" if state == S.DEAD else "hit"


func take_damage(amount: float, dir: Vector2 = Vector2.ZERO, silent := false) -> void:
	if state == S.DEAD:
		return
	hp -= amount
	_hit_flash = 0.12
	_knock = dir.normalized() * 90.0
	if not silent:
		_sound("hurt", 1.0 + _rng.randf_range(-0.1, 0.1))
		AudioSystem.play_at("enemy_hit", global_position, _rng.randf_range(0.9, 1.1))
		if Settings.get_v("damage_numbers"):
			Effects.float_text(get_parent(), position + Vector2(0, -18), str(int(ceilf(amount))), Color("#e8c070"))
		Effects.burst(get_parent(), hit_center() - get_parent().global_position, Color("#5a1c16") if id != "vulto" else Color("#1c1824"), 5, 50.0)
		Effects.hitstop(get_tree(), 0.035)
	if hp <= 0.0:
		_die()
		return
	_alerted = true
	if hp <= max_hp * float(data.get("flee_below", 0.0)):
		_set_state(S.FLEE)
	elif state != S.WINDUP:
		_set_state(S.STAGGER)


func _die() -> void:
	state = S.DEAD
	broken = true
	remove_from_group("mineable")
	collision_layer = 0
	_sound("die")
	ProgressionSystem.add_xp(int(data.get("xp", 5)), "inimigo")
	GameState.stats["enemies_defeated"] = int(GameState.stats.get("enemies_defeated", 0)) + 1
	var drop: Dictionary = data.get("drop", {})
	if not drop.is_empty() and _rng.randf() < float(drop.get("chance", 0.0)):
		Effects.spawn_drop(get_parent(), position, String(drop.item), 1)
	if director:
		director.on_enemy_died(self)


# ------------------------------------------------------------------ loop
func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	_anim_t += delta
	_state_t += delta
	_hit_flash = maxf(0.0, _hit_flash - delta)
	if state == S.DEAD:
		_fade -= delta * 0.7
		_sprite.modulate.a = maxf(0.0, _fade)
		_sprite.frame = mini(3, _frames - 1)
		_sprite.rotation = lerpf(_sprite.rotation, PI / 2.0 if id != "vulto" else 0.0, delta * 8.0)
		if _eyes:
			_eyes.visible = false
		if _fade <= 0.0:
			queue_free()
		return
	var p := director.player() if director else null
	if p == null:
		return
	var to_p := p.global_position - global_position
	var dist := to_p.length()
	_update_light_rules(delta, p, dist)
	if state == S.DEAD:
		return
	var move := Vector2.ZERO
	match state:
		S.WANDER:
			move = _wander_dir * float(data.get("wander_speed", 15))
			if _state_t > 2.5:
				_pick_wander()
			if director.can_notice(self, p, dist):
				_alert()
		S.CHASE:
			if dist > float(data.get("sight", 100)) * 1.8 and not _alerted_recent():
				_set_state(S.WANDER)
			elif dist <= float(data.get("reach", 12)) + 2.0 and director.request_attack(self):
				_set_state(S.WINDUP)
				_sound("windup")
			else:
				move = _steer(to_p.normalized()) * float(data.get("speed", 40))
				if dist <= float(data.get("reach", 12)):
					move *= 0.2                         # espera a vez de atacar sem colar no jogador
		S.WINDUP:
			move = Vector2.ZERO
			if _state_t >= float(data.get("windup", 0.5)):
				# golpe só acerta se o jogador continuar no alcance (dá para desviar)
				if dist <= float(data.get("reach", 12)) + 3.0:
					director.hurt_player(self, float(data.get("damage", 3)) * dmg_mult, float(data.get("exposure", 0)), to_p)
				_sound("attack")
				director.release_attack(self)
				_set_state(S.RECOVER)
		S.RECOVER:
			move = -to_p.normalized() * float(data.get("wander_speed", 15)) * 1.5
			if _state_t >= float(data.get("recover", 1.2)):
				_set_state(S.CHASE)
		S.FLEE:
			move = _steer(-to_p.normalized()) * float(data.get("speed", 40)) * 1.1
			if _state_t > 3.5:
				if hp <= max_hp * float(data.get("flee_below", 0.0)) and dist > 140.0:
					director.despawn(self)          # sumiu na escuridão
					return
				_set_state(S.CHASE if hp > max_hp * float(data.get("flee_below", 0.0)) else S.FLEE)
		S.STAGGER:
			if _state_t > 0.3:
				_set_state(S.CHASE)
	velocity = move + _knock
	_knock = _knock.move_toward(Vector2.ZERO, delta * 400.0)
	var before := global_position
	move_and_slide()
	_check_stuck(delta, before, move)
	_update_visual(move, to_p)
	_idle_sound_t -= delta
	if _idle_sound_t <= 0.0:
		_idle_sound_t = _rng.randf_range(5.0, 11.0)
		if dist < 220.0:
			_sound("idle", _rng.randf_range(0.85, 1.1), -6.0)


func _alerted_recent() -> bool:
	return state == S.CHASE and _state_t < 6.0


func _alert() -> void:
	if not _alerted:
		_alerted = true
		if not GameState.has_flag("seen_" + id):     # bestiário: primeira vez que vê este bicho
			GameState.set_flag("seen_" + id)
			EventBus.toast.emit("Novo no diário: %s" % display_name(), "warn")
		_sound("alert")
		var cap := String(data.get("caption_alert", ""))
		if cap != "":
			EventBus.caption.emit(cap)
		director.on_enemy_alerted(self)
	_set_state(S.CHASE)


func _set_state(s: int) -> void:
	if state == S.WINDUP and s != S.RECOVER and director:
		director.release_attack(self)
	state = s
	_state_t = 0.0


func _pick_wander() -> void:
	_state_t = 0.0
	if _rng.randf() < 0.3:
		_wander_dir = Vector2.ZERO
	else:
		var back := (_home - global_position)
		_wander_dir = (Vector2.from_angle(_rng.randf() * TAU) + (back / 120.0 if back.length() > 90.0 else Vector2.ZERO)).normalized()


func _steer(dir: Vector2) -> Vector2:
	if _detour_t > 0.0:
		return (_detour + dir * 0.3).normalized()
	return dir


func _check_stuck(delta: float, before: Vector2, move: Vector2) -> void:
	_detour_t = maxf(0.0, _detour_t - delta)
	if move.length() > 5.0 and global_position.distance_to(before) < move.length() * delta * 0.25:
		_stuck_t += delta
		if _stuck_t > 0.35:
			_stuck_t = 0.0
			_detour = move.normalized().orthogonal() * (1.0 if _rng.randf() < 0.5 else -1.0)
			_detour_t = 0.7
			if state == S.WANDER:
				_pick_wander()
	else:
		_stuck_t = 0.0


# ------------------------------------------------------------------ luz
func _update_light_rules(delta: float, p: Player, dist: float) -> void:
	match String(data.get("light_rule", "")):
		"fears_fire":
			var f := director.nearest_fire(global_position)
			if f != Vector2.INF and global_position.distance_to(f) < 64.0 and state != S.FLEE:
				_set_state(S.FLEE)
		"burned_by_light":
			var lit := director.is_in_player_light(global_position + Vector2(0, -14)) or director.near_flare(global_position, 70.0)
			var target_a := 0.0 if (state == S.WANDER and dist > 90.0) else (0.85 if not lit else 0.45)
			_sprite.modulate.a = move_toward(_sprite.modulate.a, target_a * (0.75 + 0.25 * sin(_anim_t * 9.0)), delta * 1.5)
			if lit:
				take_damage(float(data.get("light_burn", 6.0)) * delta, Vector2.ZERO, true)
				if _rng.randf() < delta * 3.0:
					_sound("hurt", _rng.randf_range(0.9, 1.15), -4.0)
				if state != S.FLEE and state != S.DEAD:
					director.release_attack(self)
					_set_state(S.FLEE)
		_:
			pass


# ------------------------------------------------------------------ visual / som
func _update_visual(move: Vector2, to_p: Vector2) -> void:
	var face_x := move.x if absf(move.x) > 2.0 else to_p.x
	_sprite.flip_h = face_x < 0.0
	var f := 0
	match state:
		S.WINDUP:
			f = 2
			_sprite.position = Vector2(_rng.randf_range(-0.5, 0.5), 0)       # tremida do bote
		S.RECOVER:
			f = 3 if _state_t < 0.18 else 0
			_sprite.position = Vector2.ZERO
		_:
			f = int(_anim_t * (9.0 if move.length() > 20.0 else 4.0)) % 2 if move.length() > 2.0 else 0
			_sprite.position = Vector2.ZERO
	_sprite.frame = mini(f, _frames - 1)
	if _eyes:
		var ep: Array = data.eyes.get("pos", [0, -8])
		var ex := float(ep[0]) + (2.0 if f == 3 else 0.0)
		_eyes.position = Vector2(-ex - 1.0 if _sprite.flip_h else ex, float(ep[1]) + (1.0 if f == 2 else 0.0)) + _sprite.position
		_eyes.modulate.a = 0.9 if fmod(_anim_t, 3.7) > 0.12 else 0.0   # piscada
	if id != "vulto":
		_sprite.modulate = Color(2.2, 1.9, 1.9) if _hit_flash > 0.0 else Color.WHITE


func _sound(key: String, pitch := 1.0, vol := 0.0) -> void:
	var sid := String(data.get("sounds", {}).get(key, ""))
	if sid != "":
		AudioSystem.play_at(sid, global_position, pitch, vol)
