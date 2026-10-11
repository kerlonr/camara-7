class_name TileSetBuilder
extends RefCounted
## Monta o TileSet em runtime a partir de data/tiles/tiles.json
## (colisão e oclusão de luz por tile). Construído uma vez e reutilizado.

const SOURCE_ID := 0

static var _tileset: TileSet
static var _coords: Dictionary = {}
static var _props: Dictionary = {}


static func get_tileset() -> TileSet:
	if _tileset:
		return _tileset
	var data: Dictionary = DataManager.tiles
	var size := int(data.get("tile_size", 16))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(size, size)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_occlusion_layer()
	var src := TileSetAtlasSource.new()
	src.texture = load(data.get("texture", ""))
	src.texture_region_size = Vector2i(size, size)
	ts.add_source(src, SOURCE_ID)
	var h := size / 2.0
	var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	var tiles: Dictionary = data.get("tiles", {})
	for tile_name in tiles:
		var t: Dictionary = tiles[tile_name]
		var c := Vector2i(int(t.coords[0]), int(t.coords[1]))
		src.create_tile(c)
		_coords[tile_name] = c
		_props[tile_name] = t
		var td := src.get_tile_data(c, 0)
		if t.get("solid", false):
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, square)
		if t.get("occluder", false):
			var occ := OccluderPolygon2D.new()
			occ.polygon = square
			td.add_occluder_polygon(0)
			td.set_occluder_polygon(0, 0, occ)
	_tileset = ts
	return ts


static func coords(tile_name: String) -> Vector2i:
	get_tileset()
	if not _coords.has(tile_name):
		push_warning("[TileSetBuilder] tile desconhecido: %s" % tile_name)
		return _coords.get("void", Vector2i.ZERO)
	return _coords[tile_name]


static func is_slow(tile_name: String) -> bool:
	return _props.get(tile_name, {}).get("slow", false)
