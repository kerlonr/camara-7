class_name PropFactory
extends RefCounted
## Cria props a partir de data/world/props.json. Âncora = base-centro do sprite (pés).
## Anexa automaticamente: colisão, luz, radiação, efeito (fx), som em loop e interação.

const LIGHT_TEXTURE := "res://assets/effects/light_bands.png"


static func create(prop_id: String, extra: Dictionary = {}) -> Node2D:
	var cfg: Dictionary = DataManager.props.get(prop_id, {})
	if cfg.is_empty():
		push_warning("[PropFactory] prop desconhecido: %s" % prop_id)
		return null
	var root := Node2D.new()
	root.name = prop_id
	var tex := DataManager.texture(cfg.get("sprite", ""))
	var frames := int(cfg.get("frames", 1))
	var w := tex.get_width() / frames
	var spr: Node2D
	if frames > 1:
		var anim := AnimatedSprite2D.new()
		var sf := PlayerFrames.build_strip(cfg.sprite, w, float(cfg.get("anim_fps", 4)))
		anim.sprite_frames = sf
		anim.centered = false
		anim.offset = Vector2(-floorf(w / 2.0), -tex.get_height())
		anim.play("default")
		anim.frame = randi() % frames
		spr = anim
	else:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.offset = Vector2(-floorf(w / 2.0), -tex.get_height())
		spr = s
	spr.name = "Sprite"
	root.add_child(spr)
	var col: Array = cfg.get("collision", [])
	if col.size() == 2:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(col[0], col[1])
		cs.shape = r
		cs.position = Vector2(0, -float(col[1]) / 2.0)
		body.add_child(cs)
		root.add_child(body)
	var strength := float(extra.get("radiation", cfg.get("radiation", 0.0)))
	if strength > 0.0:
		root.add_to_group("rad_source")
		root.set_meta("strength", strength)
	if cfg.has("light"):
		root.add_child(make_light(cfg.light))
	if cfg.has("fx"):
		root.add_child(AmbientFX.create(cfg.fx))
		if cfg.fx == "fire":
			root.add_to_group("fire_source")
	if cfg.has("loop"):
		var a := AudioStreamPlayer2D.new()
		a.name = "Loop"
		a.stream = AudioSystem.loop_stream(cfg.loop)
		a.volume_db = AudioSystem.loop_volume(cfg.loop)
		a.max_distance = 180.0
		a.attenuation = 2.0
		a.bus = "Ambient"
		a.autoplay = true
		root.add_child(a)
	if cfg.has("interact") and not extra.get("no_interact", false):
		var it := Interactable.create(cfg.interact.action, cfg.interact.get("prompt", ""),
			Vector2(minf(w, 32.0), 18), cfg.interact.get("params", {}))
		it.position = Vector2(0, -3)
		root.add_child(it)
	root.set_meta("prop_id", prop_id)
	return root


static func make_light(l: Dictionary) -> FlickerLight:
	var light := FlickerLight.new()
	light.name = "Light"
	light.texture = DataManager.texture(LIGHT_TEXTURE)
	light.color = Color(l.get("color", "#ffffff"))
	light.base_energy = float(l.get("energy", 1.0))
	light.energy = light.base_energy
	light.texture_scale = float(l.get("scale", 1.0))
	var off: Array = l.get("offset", [0, 0])
	light.position = Vector2(off[0], off[1])
	light.flicker = float(l.get("flicker", 0.0))
	light.night_only = l.get("night_only", false)
	light.add_to_group("world_light")
	return light
