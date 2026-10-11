extends Node
## Áudio em camadas (ver data/audio/sounds.json):
##   cama de ambiente (loop com crossfade) + one-shots ambientes aleatórios
##   + trilha discreta (música) + efeitos com pool + Geiger
##   + batimento cardíaco em perigo + "silêncio errado" (corta o ambiente de propósito).
## Barramentos: Music, Ambient, SFX (com eco na mina), UI — volumes em Settings.

const POOL_SIZE := 20
const POOL_2D_SIZE := 14

var geiger_enabled := true

var _pool: Array[AudioStreamPlayer] = []
var _pool_2d: Array[AudioStreamPlayer2D] = []
var _amb_a: AudioStreamPlayer
var _amb_b: AudioStreamPlayer
var _mus_a: AudioStreamPlayer
var _mus_b: AudioStreamPlayer
var _ambient_id := ""
var _music_id := ""
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _alarm_cd := 0.0
var _heart_t := 0.0
var _silence_t := 0.0
var _dread: AudioStreamPlayer
var _dread_target := 0.0
var _dread_level := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for i in POOL_2D_SIZE:
		var p2 := AudioStreamPlayer2D.new()
		p2.max_distance = 300.0
		p2.attenuation = 1.5
		add_child(p2)
		_pool_2d.append(p2)
	_amb_a = _make_player("Ambient")
	_amb_b = _make_player("Ambient")
	_mus_a = _make_player("Music")
	_mus_b = _make_player("Music")
	_dread = _make_player("Ambient")
	_rng.randomize()


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if s == null:
		push_warning("[AudioSystem] som ausente: %s" % path)
	_streams[path] = s
	return s


func _sfx_cfg(id: String) -> Dictionary:
	return DataManager.sounds.get("sfx", {}).get(id, {})


func _pick(cfg: Dictionary) -> AudioStream:
	var files: Array = cfg.get("files", [])
	if files.is_empty():
		return null
	return _stream(files[_rng.randi_range(0, files.size() - 1)])


func play(id: String, pitch: float = 1.0, volume_offset: float = 0.0) -> void:
	var cfg := _sfx_cfg(id)
	var s := _pick(cfg)
	if s == null:
		return
	var p := _free_player()
	p.stream = s
	p.bus = cfg.get("bus", "SFX")
	p.volume_db = float(cfg.get("volume", 0)) + volume_offset
	var pv := float(cfg.get("pitch_var", 0.0))
	p.pitch_scale = maxf(0.05, pitch * (1.0 + _rng.randf_range(-pv, pv)))
	p.play()
	if cfg.has("caption"):
		EventBus.caption.emit(cfg.caption)


func play_at(id: String, pos: Vector2, pitch: float = 1.0, volume_offset: float = 0.0) -> void:
	var cfg := _sfx_cfg(id)
	var s := _pick(cfg)
	if s == null:
		return
	var p: AudioStreamPlayer2D = _pool_2d[0]
	for c in _pool_2d:
		if not c.playing:
			p = c
			break
	p.stream = s
	p.bus = cfg.get("bus", "SFX")
	p.global_position = pos
	p.volume_db = float(cfg.get("volume", 0)) + volume_offset
	var pv := float(cfg.get("pitch_var", 0.0))
	p.pitch_scale = maxf(0.05, pitch * (1.0 + _rng.randf_range(-pv, pv)))
	p.play()


func _free_player() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing:
			return p
	return _pool[_rng.randi_range(0, _pool.size() - 1)]


func _loopify(s: AudioStream) -> AudioStream:
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate)
	return s


## Stream de loop pronto para uso (AudioStreamPlayer2D de máquinas/props).
func loop_stream(id: String) -> AudioStream:
	var cfg: Dictionary = DataManager.sounds.get("loops", {}).get(id, {})
	return _loopify(_stream(cfg.get("file", "")))


func loop_volume(id: String) -> float:
	return float(DataManager.sounds.get("loops", {}).get(id, {}).get("volume", 0))


# ------------------------------------------------------------ ambiente e música
func _crossfade(a: AudioStreamPlayer, b: AudioStreamPlayer, stream: AudioStream, vol: float) -> void:
	var old := a if a.playing else b
	var nxt := b if old == a else a
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -60.0, 1.5)
		tw.tween_callback(old.stop)
	if stream:
		nxt.stream = stream
		nxt.volume_db = -50.0
		nxt.play()
		create_tween().tween_property(nxt, "volume_db", vol, 2.0)


func set_ambient(id: String) -> void:
	if id == _ambient_id:
		return
	_ambient_id = id
	var cfg: Dictionary = DataManager.sounds.get("loops", {}).get(id, {})
	_crossfade(_amb_a, _amb_b, loop_stream(id) if id != "" else null, float(cfg.get("volume", 0)))


func stop_ambient() -> void:
	set_ambient("")
	set_music("")
	set_dread(0.0)


func set_music(id: String) -> void:
	if id == _music_id:
		return
	_music_id = id
	var cfg: Dictionary = DataManager.sounds.get("music", {}).get(id, {})
	var s: AudioStream = _loopify(_stream(cfg.get("file", ""))) if id != "" else null
	_crossfade(_mus_a, _mus_b, s, float(cfg.get("volume", 0)))


## "Silêncio errado": corta ambiente e música por alguns segundos (técnica de horror).
func silence(seconds: float) -> void:
	_silence_t = seconds
	for p in [_amb_a, _amb_b, _mus_a, _mus_b]:
		if p.playing:
			create_tween().tween_property(p, "volume_db", -60.0, 0.4)


func _restore_after_silence() -> void:
	var amb_vol := loop_volume(_ambient_id)
	var mus_vol := float(DataManager.sounds.get("music", {}).get(_music_id, {}).get("volume", 0))
	for p in [_amb_a, _amb_b]:
		if p.playing:
			create_tween().tween_property(p, "volume_db", amb_vol, 3.0)
	for p in [_mus_a, _mus_b]:
		if p.playing:
			create_tween().tween_property(p, "volume_db", mus_vol, 3.0)
	play("distant_bang", 0.8)


## Pavor (0..1): camada grave que cresce quando algo persegue o jogador.
func set_dread(level: float) -> void:
	_dread_target = clampf(level, 0.0, 1.0)


func _update_dread(delta: float) -> void:
	_dread_level = move_toward(_dread_level, _dread_target, delta * (0.8 if _dread_target > _dread_level else 0.25))
	if _dread_level > 0.01:
		if not _dread.playing:
			_dread.stream = loop_stream("dread_near")
			_dread.play()
		_dread.volume_db = loop_volume("dread_near") + linear_to_db(maxf(0.0001, _dread_level))
	elif _dread.playing:
		_dread.stop()


# ------------------------------------------------------------ loop por quadro
func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_update_dread(delta)
	if _silence_t > 0.0:
		_silence_t -= delta
		if _silence_t <= 0.0:
			_restore_after_silence()
	else:
		var shots: Array = DataManager.sounds.get("ambient_oneshots", {}).get(_ambient_id, [])
		for s in shots:
			if _rng.randf() < float(s.chance_per_min) / 60.0 * delta:
				play(s.id, 1.0, _rng.randf_range(-6.0, 0.0))
	if not RadiationSystem.active:
		return
	_geiger(delta)
	_heartbeat(delta)


func _geiger(delta: float) -> void:
	if not geiger_enabled:
		return
	var c := minf(RadiationSystem.cps(), 90.0)
	var expected := c * delta
	while expected > 0.0:
		if _rng.randf() < minf(expected, 1.0):
			play("geiger", 1.0, _rng.randf_range(-3.0, 0.0))
		expected -= 1.0
	_alarm_cd -= delta
	if int(UpgradeSystem.get_stat("dosimeter", 0)) > 0 and RadiationSystem.rate > 0.08 and _alarm_cd <= 0.0:
		_alarm_cd = clampf(1.4 - RadiationSystem.rate * 3.0, 0.25, 1.4)
		play("alarm")


func _heartbeat(delta: float) -> void:
	var danger := HealthSystem.hp < HealthSystem.max_hp() * 0.35 or RadiationSystem.exposure >= 75.0
	if not danger:
		return
	_heart_t -= delta
	if _heart_t <= 0.0:
		_heart_t = 0.75 if HealthSystem.hp < HealthSystem.max_hp() * 0.2 else 1.0
		play("heartbeat")
