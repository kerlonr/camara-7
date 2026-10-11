class_name PlayerFrames
extends RefCounted
## Monta SpriteFrames a partir de uma folha de personagem:
## colunas 0=parado, 1-4=andar, 5-6=golpe | linhas 0=baixo, 1=cima, 2=lado (direita).

const ROWS := {"down": 0, "up": 1, "side": 2}

static var _cache: Dictionary = {}


static func build(sheet_path: String, frame_size: Vector2i = Vector2i(16, 24)) -> SpriteFrames:
	if _cache.has(sheet_path):
		return _cache[sheet_path]
	var tex := DataManager.texture(sheet_path)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for dir_name in ROWS:
		var row: int = ROWS[dir_name]
		_add(sf, "idle_" + dir_name, tex, row, [0], 1.0, frame_size)
		_add(sf, "walk_" + dir_name, tex, row, [1, 2, 3, 4], 8.0, frame_size)
		_add(sf, "swing_" + dir_name, tex, row, [5, 6], 0.0, frame_size)
	_cache[sheet_path] = sf
	return sf


static func _add(sf: SpriteFrames, anim: String, tex: Texture2D, row: int, cols: Array, fps: float, fs: Vector2i) -> void:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, fps > 0.0)
	for c in cols:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(c * fs.x, row * fs.y, fs.x, fs.y)
		sf.add_frame(anim, at)


## Folha simples de NPC: N quadros numa linha, animação "idle".
static func build_strip(sheet_path: String, frame_w: int, fps: float = 1.5) -> SpriteFrames:
	var key := sheet_path + "#strip"
	if _cache.has(key):
		return _cache[key]
	var tex := DataManager.texture(sheet_path)
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", fps)
	for i in tex.get_width() / frame_w:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * frame_w, 0, frame_w, tex.get_height())
		sf.add_frame("default", at)
	_cache[key] = sf
	return sf
