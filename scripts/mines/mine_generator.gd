class_name MineGenerator
extends RefCounted
## Gera o LAYOUT (dados puros) de um nível de mina. Determinístico por
## (seed do mundo, profundidade, nº da descida): cada descida é diferente, mas
## qualquer descida pode ser reproduzida para depuração.
##
## Etapas: bioma → eventos → salas tipadas → conexões (MST + laços) → entrada/saída
## → caminho garantido → sala de história → pisos/trilhos → props → lâmpadas
## → rochas (perfil geológico sorteado, veios, veios ricos, aglomerado "fora de época").

const WALL := 0
const FLOOR := 1
const N8 := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
const N4 := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const MULT_KEYS := ["rad_mult", "ore_mult", "density_mult", "phenomena_mult"]
const ADD_KEYS := ["rad_add", "fog", "extra_puddles"]

var rng := RandomNumberGenerator.new()
var w := 0
var h := 0
var depth := 1
var opts: Dictionary = {}
var grid := PackedByteArray()
var room_of := PackedInt32Array()
var rooms: Array = []
var segments: Array = []
var reserved: Dictionary = {}
var no_rock: Dictionary = {}
var floor_tiles: Dictionary = {}
var biome: Dictionary = {}
var events: Array = []
var effects: Dictionary = {}
var ore_profile: Dictionary = {}


## opts: descent (int), story (Dictionary de placements.json ou {}), blessing (bool)
func generate(world_seed: int, at_depth: int, p_opts: Dictionary = {}) -> Dictionary:
	depth = at_depth
	opts = p_opts
	rng.seed = hash([world_seed, at_depth, int(opts.get("descent", 0)), "krasnyi_yar"])
	biome = DataManager.biome_for_depth(depth)
	_roll_events()
	var size: Array = biome.get("size", [46, 34])
	var var_px := int(biome.get("size_var", 0))
	w = int(size[0]) + rng.randi_range(-var_px, var_px) + mini(depth % 10, 4)
	h = int(size[1]) + rng.randi_range(-var_px / 2, var_px / 2) + mini(depth % 10, 3)
	grid.resize(w * h)
	grid.fill(WALL)
	room_of.resize(w * h)
	room_of.fill(-1)

	_place_rooms()
	_connect_rooms()
	var spawn_info := _place_entrance()
	var spawn: Vector2i = spawn_info.spawn
	var ladder_up: Vector2i = spawn_info.ladder
	var ladder_down := _place_exit(spawn)
	var elevator = null
	if depth % GameState.checkpoint_every() == 0:
		elevator = _place_elevator(ladder_up)
	_guarantee_path(spawn, ladder_down)
	_clear_around(spawn, 2)
	_clear_around(ladder_down, 1)
	var story := _place_story(spawn, ladder_down)
	_assign_floors()
	_lay_rails()
	var props := _place_props()
	var lamps := _place_lamps(spawn)
	_roll_ore_profile()
	var rocks := _place_rocks(props)
	var drips := _place_drips()

	var amb := float(biome.get("ambient_rad", 0.0)) + float(biome.get("rad_per_depth", 0.0)) * (depth - int(biome.get("min_depth", 1)))
	amb = amb * float(effects.get("rad_mult", 1.0)) + float(effects.get("rad_add", 0.0))
	var dv := float(biome.get("darkness_var", 0.0))
	return {
		"w": w, "h": h, "grid": grid, "floor_tiles": floor_tiles,
		"rocks": rocks, "props": props, "lamps": lamps, "drips": drips,
		"spawn": spawn, "ladder_up": ladder_up, "ladder_down": ladder_down, "elevator": elevator,
		"story": story, "biome": biome, "events": events, "effects": effects, "ambient_rad": amb,
		"lamps_off": effects.get("lamps_off", false), "red_lights": effects.get("red_lights", false),
		"darkness_mult": 1.0 + rng.randf_range(-dv, dv), "ore_profile": ore_profile,
		"room_types": rooms.map(func(r): return r.type),
	}


# ------------------------------------------------------------ utilidades
func idx(c: Vector2i) -> int:
	return c.y * w + c.x


func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func is_floor(c: Vector2i) -> bool:
	return inside(c) and grid[idx(c)] == FLOOR


func _carve(c: Vector2i) -> void:
	if c.x >= 1 and c.y >= 2 and c.x < w - 1 and c.y < h - 1:
		grid[idx(c)] = FLOOR


func _weighted_key(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := rng.randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return k
	return weights.keys()[0]


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t


# ------------------------------------------------------------ eventos
func _roll_events() -> void:
	events = []
	effects = {"extra_rooms": []}
	var pool: Array = DataManager.mine_events.duplicate()
	_shuffle(pool)
	for e in pool:
		if events.size() >= 2:
			break
		if depth >= int(e.get("min_depth", 1)) and rng.randf() < float(e.get("chance", 0.0)):
			events.append(e)
	for e in events:
		var eff: Dictionary = e.get("effects", {})
		for k in eff:
			if k == "extra_room":
				effects.extra_rooms.append(eff[k])
			elif k in MULT_KEYS:
				effects[k] = float(effects.get(k, 1.0)) * float(eff[k])
			elif k in ADD_KEYS:
				effects[k] = float(effects.get(k, 0.0)) + float(eff[k])
			else:
				effects[k] = eff[k]


# ------------------------------------------------------------ salas
func _room_weights() -> Dictionary:
	var out := {}
	var all: Dictionary = biome.get("room_types", {"cave": 1})
	for t in all:
		if depth >= int(DataManager.room_types.get(t, {}).get("min_depth", 0)):
			out[t] = all[t]
	return out


func _place_rooms() -> void:
	var span: Array = biome.get("rooms", [6, 9])
	var target := rng.randi_range(int(span[0]), int(span[1]))
	var forced: Array = effects.extra_rooms.duplicate()
	target += forced.size()
	if not opts.get("story", {}).is_empty():
		target += 1
	var weights := _room_weights()
	var attempts := 0
	while rooms.size() < target and attempts < 800:
		attempts += 1
		var rw := rng.randi_range(7, 13)
		var rh := rng.randi_range(6, 10)
		var rect := Rect2i(rng.randi_range(2, w - rw - 3), rng.randi_range(3, h - rh - 3), rw, rh)
		var ok := true
		for r in rooms:
			if r.rect.grow(2).intersects(rect):
				ok = false
				break
		if not ok:
			continue
		var type: String
		if rooms.is_empty():
			type = "timber"
		elif not forced.is_empty():
			type = forced.pop_back()
		else:
			type = _weighted_key(weights)
		var room := {"rect": rect, "type": type, "cfg": DataManager.room_types.get(type, {}), "cells": [], "index": rooms.size()}
		_carve_room(room)
		rooms.append(room)


func _carve_room(room: Dictionary) -> void:
	var r: Rect2i = room.rect
	var cells: Array = []
	if room.cfg.get("shape", "rect") == "cave":
		cells = _cave_cells(r)
	if cells.size() < int(r.size.x * r.size.y * 0.35):
		cells = []
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var corner := (x == r.position.x or x == r.end.x - 1) and (y == r.position.y or y == r.end.y - 1)
				if not corner:
					cells.append(Vector2i(x, y))
	for c in cells:
		_carve(c)
		room_of[idx(c)] = room.index
	room.cells = cells
	var avg := Vector2.ZERO
	for c in cells:
		avg += Vector2(c)
	avg /= maxf(1.0, cells.size())
	var best: Vector2i = cells[0]
	for c in cells:
		if Vector2(c).distance_squared_to(avg) < Vector2(best).distance_squared_to(avg):
			best = c
	room.center = best


## Autômato celular dentro do retângulo; retorna o maior componente conectado.
func _cave_cells(r: Rect2i) -> Array:
	var rw := r.size.x
	var rh := r.size.y
	var fill := rng.randf_range(0.56, 0.66)
	var cur := []
	cur.resize(rw * rh)
	for y in rh:
		for x in rw:
			var border := x == 0 or y == 0 or x == rw - 1 or y == rh - 1
			cur[y * rw + x] = not border and rng.randf() < fill
	for _iter in 4:
		var nxt := []
		nxt.resize(rw * rh)
		for y in rh:
			for x in rw:
				var walls := 0
				for d in N8:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx < 0 or ny < 0 or nx >= rw or ny >= rh or not cur[ny * rw + nx]:
						walls += 1
				nxt[y * rw + x] = walls < 5 if cur[y * rw + x] else walls < 4
		cur = nxt
	var seen := {}
	var best: Array = []
	for y in rh:
		for x in rw:
			if not cur[y * rw + x] or seen.has(Vector2i(x, y)):
				continue
			var comp := []
			var stack := [Vector2i(x, y)]
			seen[Vector2i(x, y)] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				comp.append(c)
				for d in N4:
					var n: Vector2i = c + d
					if n.x >= 0 and n.y >= 0 and n.x < rw and n.y < rh and cur[n.y * rw + n.x] and not seen.has(n):
						seen[n] = true
						stack.append(n)
			if comp.size() > best.size():
				best = comp
	var out := []
	for c in best:
		out.append(c + r.position)
	return out


# ------------------------------------------------------------ conexões
func _connect_rooms() -> void:
	if rooms.size() < 2:
		return
	var connected := [0]
	var edges := []
	while connected.size() < rooms.size():
		var best_a := -1
		var best_b := -1
		var best_d := INF
		for a in connected:
			for b in rooms.size():
				if connected.has(b):
					continue
				var d := Vector2(rooms[a].center).distance_to(Vector2(rooms[b].center))
				if d < best_d:
					best_d = d
					best_a = a
					best_b = b
		connected.append(best_b)
		edges.append([best_a, best_b])
	for _i in rng.randi_range(1, 3):
		var a := rng.randi_range(0, rooms.size() - 1)
		var b := rng.randi_range(0, rooms.size() - 1)
		if a != b:
			edges.append([a, b])
	for e in edges:
		_carve_corridor(rooms[e[0]].center, rooms[e[1]].center)


func _carve_corridor(a: Vector2i, b: Vector2i) -> void:
	var corner := Vector2i(b.x, a.y) if rng.randf() < 0.5 else Vector2i(a.x, b.y)
	_carve_line(a, corner)
	_carve_line(corner, b)


func _carve_line(a: Vector2i, b: Vector2i) -> void:
	var horizontal := a.y == b.y
	var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	var c := a
	var cells := [a]
	while c != b:
		c += step
		cells.append(c)
	for cell in cells:
		_carve(cell)
		_carve(cell + (Vector2i(0, 1) if horizontal else Vector2i(1, 0)))
	segments.append({"cells": cells, "horizontal": horizontal})


# ------------------------------------------------------------ entrada / saída
func _place_entrance() -> Dictionary:
	var room: Dictionary = rooms[0]
	var best = null
	for c in room.cells:
		if is_floor(c) and not is_floor(c + Vector2i(0, -1)) and is_floor(c + Vector2i(0, 1)) and is_floor(c + Vector2i(0, 2)):
			if best == null or absi(c.x - room.center.x) + c.y * 2 < absi(best.x - room.center.x) + best.y * 2:
				best = c
	if best == null:
		for c in room.cells:
			if is_floor(c) and not is_floor(c + Vector2i(0, -1)) and is_floor(c + Vector2i(0, 1)):
				best = c
				break
	if best == null:
		best = room.center
	var ladder: Vector2i = best
	# o jogador nasce DOIS tiles abaixo da escada: não fica preso no "Subir para a base"
	var spawn := ladder + Vector2i(0, 2) if is_floor(ladder + Vector2i(0, 2)) else ladder + Vector2i(0, 1)
	reserved[ladder] = true
	reserved[ladder + Vector2i(0, 1)] = true
	return {"spawn": spawn, "ladder": ladder}


func _bfs(from: Vector2i) -> Dictionary:
	var dist := {from: 0}
	var queue := [from]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in N4:
			var n: Vector2i = c + d
			if is_floor(n) and not dist.has(n):
				dist[n] = dist[c] + 1
				queue.append(n)
	return dist


func _place_exit(spawn: Vector2i) -> Vector2i:
	var dist := _bfs(spawn)
	var best: Vector2i = rooms[rooms.size() - 1].center
	var best_d := -1
	for room in rooms.slice(1):
		var d := int(dist.get(room.center, -1))
		if d > best_d:
			best_d = d
			best = room.center
	reserved[best] = true
	return best


func _place_elevator(ladder: Vector2i):
	for dx in [3, -3, 4, -4, 5, -5, 2, -2]:
		var c := ladder + Vector2i(dx, 0)
		var ok := true
		for x in range(-1, 2):
			var cc := c + Vector2i(x, 0)
			if not is_floor(cc) or is_floor(cc + Vector2i(0, -1)) or reserved.has(cc):
				ok = false
		if ok:
			for x in range(-1, 2):
				reserved[c + Vector2i(x, 0)] = true
				no_rock[c + Vector2i(x, 1)] = true
			return c
	return null


func _guarantee_path(a: Vector2i, b: Vector2i) -> void:
	var dist := _bfs(b)
	if not dist.has(a):
		_carve_corridor(a, b)
		dist = _bfs(b)
	var c := a
	var guard := 0
	while c != b and guard < 5000:
		guard += 1
		no_rock[c] = true
		var nxt := c
		for d in N4:
			var n: Vector2i = c + d
			if dist.has(n) and dist[n] < dist.get(nxt, 1 << 30):
				nxt = n
		if nxt == c:
			break
		c = nxt
	no_rock[b] = true


func _clear_around(c: Vector2i, r: int) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			no_rock[c + Vector2i(x, y)] = true


# ------------------------------------------------------------ história
## Escolhe uma sala longe da entrada para o objeto de história (fita, item, porta final).
func _place_story(spawn: Vector2i, exit_cell: Vector2i) -> Dictionary:
	var p: Dictionary = opts.get("story", {})
	if p.is_empty() or rooms.size() < 3:
		return {}
	var dist := _bfs(spawn)
	var best_room = null
	var best_d := -1
	for room in rooms.slice(1):
		if room.center == exit_cell and rooms.size() > 3:
			continue
		var d := int(dist.get(room.center, -1))
		if d > best_d:
			best_d = d
			best_room = room
	if best_room == null:
		return {}
	var final := String(p.get("kind", "")) == "final_door"
	best_room.type = "vault" if final else "story"
	best_room.cfg = DataManager.room_types.get(best_room.type, {})
	# célula com parede acima (e largura livre para a porta)
	var cands := []
	for c in best_room.cells:
		if not is_floor(c) or is_floor(c + Vector2i(0, -1)) or reserved.has(c):
			continue
		if final:
			var wide := true
			for dx in [-1, 1]:
				if not is_floor(c + Vector2i(dx, 0)) or is_floor(c + Vector2i(dx, -1)):
					wide = false
			if not wide:
				continue
		cands.append(c)
	if cands.is_empty():
		cands = [best_room.center]
	var cell: Vector2i = cands[rng.randi_range(0, cands.size() - 1)]
	for dx in range(-1, 2):
		reserved[cell + Vector2i(dx, 0)] = true
	_clear_around(cell + Vector2i(0, 1), 1)
	# garante acesso sem rochas até o objeto
	_guarantee_path(spawn, cell + Vector2i(0, 1))
	return {"placement": p, "cell": cell}


# ------------------------------------------------------------ pisos
func _assign_floors() -> void:
	var base_list: Array = biome.get("floor", ["mine_floor"])
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if grid[idx(c)] != FLOOR:
				continue
			var tile: String = base_list[rng.randi_range(0, base_list.size() - 1)]
			var ri := room_of[idx(c)]
			if ri >= 0:
				var cfg: Dictionary = rooms[ri].cfg
				if cfg.has("floor_override"):
					tile = cfg.floor_override
				if rooms[ri].type == "hot":
					tile = "hot_floor" if rng.randf() < 0.6 else "hot_floor2"
				if rng.randf() < float(cfg.get("wet", 0.0)):
					tile = biome.get("wet_floor", "mine_wet")
			floor_tiles[c] = tile


func _lay_rails() -> void:
	if not biome.get("rails", false):
		return
	for seg in segments:
		if seg.cells.size() < 7 or rng.randf() > 0.5:
			continue
		for c in seg.cells.slice(1, seg.cells.size() - 1):
			if room_of[idx(c)] == -1 and is_floor(c):
				floor_tiles[c] = "rail_h" if seg.horizontal else "rail_v"


# ------------------------------------------------------------ props
func _place_props() -> Array:
	var out := []
	for room in rooms:
		for spec in room.cfg.get("props", []):
			var id: String = spec[0]
			var n := rng.randi_range(int(spec[1]), int(spec[2]))
			var container := id.begins_with("@")
			var pcfg: Dictionary = {} if container else DataManager.props.get(id, {})
			var blocking: bool = container or pcfg.has("collision")
			var wide := false
			if not container and pcfg.has("collision"):
				wide = pcfg.collision[0] > 16
			for _k in n:
				var c = _pick_cell(room, spec[3], blocking, pcfg.get("mount", "") == "wall")
				if c == null:
					break
				reserved[c] = true
				if wide:
					reserved[c + Vector2i(1, 0)] = true
					reserved[c + Vector2i(-1, 0)] = true
				if container:
					out.append({"container": id.substr(1), "cell": c})
				else:
					out.append({"id": id, "cell": c})
	var puddles := int(effects.get("extra_puddles", 0))
	var floor_cells := []
	for room in rooms:
		floor_cells.append_array(room.cells)
	for _i in puddles:
		var c: Vector2i = floor_cells[rng.randi_range(0, floor_cells.size() - 1)]
		if not reserved.has(c):
			reserved[c] = true
			out.append({"id": "puddle_rad", "cell": c})
	return out


func _pick_cell(room: Dictionary, where: String, blocking: bool, mounted: bool):
	var cands := []
	for c in room.cells:
		if not is_floor(c) or reserved.has(c):
			continue
		if blocking and no_rock.has(c):
			continue
		var wall_above := not is_floor(c + Vector2i(0, -1))
		if (where == "wall" or mounted) and not wall_above:
			continue
		cands.append(c)
	if cands.is_empty():
		return null
	return cands[rng.randi_range(0, cands.size() - 1)]


func _place_lamps(spawn: Vector2i) -> Array:
	var span: Array = biome.get("lamps", [3, 5])
	var count := rng.randi_range(int(span[0]), int(span[1]))
	var cands := []
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if is_floor(c) and not is_floor(c + Vector2i(0, -1)) and not reserved.has(c):
				cands.append(c)
	if cands.is_empty():
		return []
	cands.sort_custom(func(a, b): return a.distance_squared_to(spawn) < b.distance_squared_to(spawn))
	var first: Array = cands.slice(0, 1)
	var rest: Array = cands.slice(1)
	_shuffle(rest)
	var placed := []
	for c in first + rest:
		if placed.size() >= count + 1:
			break
		var ok := true
		for p in placed:
			if Vector2(p.cell).distance_to(Vector2(c)) < 8.0:
				ok = false
				break
		if not ok:
			continue
		var id := "lamp"
		var ri := room_of[idx(c)]
		var color = null
		if ri >= 0 and rooms[ri].cfg.has("lamp_color"):
			color = rooms[ri].cfg.lamp_color
		elif depth >= 8 and rng.randf() < 0.2:
			id = "lamp_red"
		if effects.get("red_lights", false):
			id = "lamp_red"
			color = null
		placed.append({"id": id, "cell": c, "color": color})
		reserved[c] = true
	return placed


func _place_drips() -> Array:
	var faces := []
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var c := Vector2i(x, y)
			if not is_floor(c) and is_floor(c + Vector2i(0, 1)):
				faces.append(c)
	_shuffle(faces)
	return faces.slice(0, rng.randi_range(6, 14))


# ------------------------------------------------------------ rochas
## Perfil geológico da descida: cada minério ganha um multiplicador aleatório
## (log-normal) e um deles é o "destaque" do nível.
func _roll_ore_profile() -> void:
	ore_profile = {}
	var candidates := []
	for ore in DataManager.ore_list:
		if ore.get("filler", false):
			continue
		ore_profile[ore.id] = clampf(exp(rng.randfn(0.0, 0.5)), 0.3, 2.8)
		candidates.append(ore.id)
	if not candidates.is_empty():
		var featured: String = candidates[rng.randi_range(0, candidates.size() - 1)]
		ore_profile[featured] = float(ore_profile[featured]) * 1.6
		ore_profile["_featured"] = featured
	ore_profile["_vein_chance"] = rng.randf_range(0.35, 0.68)


func _ore_table(room_cfg: Dictionary) -> Array:
	var table := []
	var ore_mult := float(effects.get("ore_mult", 1.0))
	var room_mult: Dictionary = room_cfg.get("ore_mult", {})
	for ore in DataManager.ore_list:
		var mx := int(ore.get("max_depth", -1))
		if depth < int(ore.min_depth) or (mx >= 0 and depth > mx):
			continue
		var wgt := float(ore.spawn_weight)
		if ore.id == "geode":
			wgt *= float(opts.get("geode_mult", 1.0))
		if not ore.get("filler", false):
			wgt *= (1.0 + depth * 0.03) * ore_mult * float(room_mult.get(ore.id, 1.0)) * float(ore_profile.get(ore.id, 1.0))
		table.append([ore.id, wgt])
	return table


func _roll(table: Array) -> String:
	var total := 0.0
	for e in table:
		total += e[1]
	var r := rng.randf() * total
	for e in table:
		r -= e[1]
		if r <= 0.0:
			return e[0]
	return table[0][0]


func _place_rocks(props: Array) -> Array:
	var out := []
	for p in props:
		if p.has("container"):
			out.append({"cell": p.cell, "id": p.container, "container": true})
	var dens_mult := float(effects.get("density_mult", 1.0))
	var base_d := float(biome.get("rock_density", 0.34)) * rng.randf_range(0.85, 1.15)
	var cells := []
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if not is_floor(c) or reserved.has(c) or no_rock.has(c):
				continue
			var ri := room_of[idx(c)]
			var d := base_d * dens_mult * (float(rooms[ri].cfg.get("density_mult", 1.0)) if ri >= 0 else 0.55)
			if rng.randf() < d:
				cells.append(c)
	_shuffle(cells)
	var tables := {}
	var assigned := {}
	var vein_chance := float(ore_profile.get("_vein_chance", 0.5))
	for c in cells:
		var ri := room_of[idx(c)]
		var key := str(ri)
		if not tables.has(key):
			tables[key] = _ore_table(rooms[ri].cfg if ri >= 0 else {})
		var neighbor := ""
		for d in N8:
			var o: String = assigned.get(c + d, "")
			if o != "" and not DataManager.ores[o].get("filler", false):
				neighbor = o
				break
		var ore_id := neighbor if neighbor != "" and rng.randf() < vein_chance else _roll(tables[key])
		assigned[c] = ore_id
	_lucky_cluster(cells, assigned)
	var rich_bonus := (1.6 if opts.get("blessing", false) else 1.0) * float(opts.get("rich_mult", 1.0))
	for c in cells:
		var ore: Dictionary = DataManager.ores[assigned[c]]
		var rich := rng.randf() < float(ore.get("rich_chance", 0.0)) * rich_bonus
		out.append({"cell": c, "id": assigned[c], "container": false, "rich": rich})
	return out


## Às vezes aparece um aglomerado de um minério mais profundo do que o normal:
## uma isca para o jogador voltar com uma ferramenta melhor.
func _lucky_cluster(cells: Array, assigned: Dictionary) -> void:
	if cells.size() < 10 or rng.randf() > 0.14:
		return
	var deeper := []
	for ore in DataManager.ore_list:
		var md := int(ore.get("min_depth", 1))
		if not ore.get("filler", false) and md > depth and md <= depth + 8:
			deeper.append(ore.id)
	if deeper.is_empty():
		return
	var ore_id: String = deeper[rng.randi_range(0, deeper.size() - 1)]
	var start: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
	var n := 0
	for c in cells:
		if c.distance_to(start) <= 1.5 and n < 4:
			assigned[c] = ore_id
			n += 1
	ore_profile["_lucky"] = ore_id
