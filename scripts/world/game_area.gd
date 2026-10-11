class_name GameArea
extends Node2D
## Base comum das áreas jogáveis (base, níveis de mina): camadas de tiles,
## entidades com y-sort, luz ambiente, props, interativos e spawn do jogador.

const TILE := 16
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var init_args: Dictionary = {}
var area_id := ""
var depth := 0
var outdoor := false

var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var floor_decor: Node2D
var shade_layer: TileMapLayer
var enemies: EnemyDirector
var entities: Node2D
var canvas_mod: CanvasModulate
var player: Player
var map_size := Vector2i.ZERO
var slow_cells: Dictionary = {}


func _create_layers() -> void:
	var ts := TileSetBuilder.get_tileset()
	floor_layer = TileMapLayer.new()
	floor_layer.name = "Floor"
	floor_layer.tile_set = ts
	add_child(floor_layer)
	wall_layer = TileMapLayer.new()
	wall_layer.name = "Walls"
	wall_layer.tile_set = ts
	add_child(wall_layer)
	floor_decor = Node2D.new()
	floor_decor.name = "FloorDecor"
	add_child(floor_decor)
	shade_layer = TileMapLayer.new()
	shade_layer.name = "ContactShade"
	shade_layer.tile_set = ts
	add_child(shade_layer)
	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)
	canvas_mod = CanvasModulate.new()
	canvas_mod.name = "Ambient"
	add_child(canvas_mod)


func set_floor(cell: Vector2i, tile_name: String) -> void:
	floor_layer.set_cell(cell, TileSetBuilder.SOURCE_ID, TileSetBuilder.coords(tile_name))
	if TileSetBuilder.is_slow(tile_name):
		slow_cells[cell] = true
	else:
		slow_cells.erase(cell)


func set_wall(cell: Vector2i, tile_name: String) -> void:
	wall_layer.set_cell(cell, TileSetBuilder.SOURCE_ID, TileSetBuilder.coords(tile_name))


## Sombra de contato: escurece o chão encostado nas paredes (peso e cantos ameaçadores).
func build_contact_shade() -> void:
	shade_layer.clear()
	for c in floor_layer.get_used_cells():
		if wall_layer.get_cell_source_id(c) != -1:
			continue
		var m := 0
		if wall_layer.get_cell_source_id(c + Vector2i.UP) != -1:
			m |= 1
		if wall_layer.get_cell_source_id(c + Vector2i.RIGHT) != -1:
			m |= 2
		if wall_layer.get_cell_source_id(c + Vector2i.DOWN) != -1:
			m |= 4
		if wall_layer.get_cell_source_id(c + Vector2i.LEFT) != -1:
			m |= 8
		if m != 0:
			shade_layer.set_cell(c, TileSetBuilder.SOURCE_ID, TileSetBuilder.coords("shade_%d" % m))


## Posição de âncora (base-centro) de uma célula.
func cell_pos(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE + TILE)


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE + TILE / 2.0)


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


func place_prop(prop_id: String, cell: Vector2i, extra: Dictionary = {}) -> Node2D:
	var p := PropFactory.create(prop_id, extra)
	if p == null:
		return null
	var cfg: Dictionary = DataManager.props[prop_id]
	var anchor := cell
	if cfg.get("mount", "") == "wall":
		anchor = cell + Vector2i(0, -1)
	p.position = cell_pos(anchor)
	if cfg.get("floor", false):
		floor_decor.add_child(p)
	else:
		entities.add_child(p)
	return p


func add_interactable(target: Node2D, action: String, prompt: String, params: Dictionary = {},
		size := Vector2(20, 18), offset := Vector2.ZERO) -> Interactable:
	var it := Interactable.create(action, prompt, size, params)
	it.position = offset + Vector2(0, -size.y / 2.0 + 6)
	target.add_child(it)
	return it


func spawn_player(world_pos: Vector2) -> Player:
	player = PLAYER_SCENE.instantiate()
	player.position = world_pos
	player.area = self
	entities.add_child(player)
	player.set_camera_limits(Rect2i(Vector2i.ZERO, map_size * TILE))
	return player


func is_slow_at(pos: Vector2) -> bool:
	return slow_cells.has(world_to_cell(pos))


## Fator do lampião do jogador (0 = desligado). Base sobrescreve conforme a hora.
func lantern_factor() -> float:
	return 1.0
