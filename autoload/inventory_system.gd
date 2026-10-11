extends Node
## Inventário em slots com pilhas. Slots 0..8 = hotbar. Capacidade vem do
## atributo 'inventory_slots' (upgrades de mochila).

const MAX_SLOTS := 45
const HOTBAR_SIZE := 9

var slots: Array = []
var selected: int = 0


func _ready() -> void:
	reset()


func reset() -> void:
	slots = []
	slots.resize(MAX_SLOTS)
	slots[0] = {"id": "pickaxe", "amount": 1}
	selected = 0
	EventBus.inventory_changed.emit()


func capacity() -> int:
	return clampi(int(UpgradeSystem.get_stat("inventory_slots", 18)), HOTBAR_SIZE, MAX_SLOTS)


func stack_size(id: String) -> int:
	return maxi(1, int(DataManager.get_item(id).get("stack", 1)))


func get_slot(i: int):
	return slots[i] if i >= 0 and i < MAX_SLOTS else null


## Adiciona e retorna quanto SOBROU (0 = coube tudo).
func add_item(id: String, amount: int) -> int:
	if not DataManager.items.has(id) or amount <= 0:
		return amount
	var cap := capacity()
	var max_stack := stack_size(id)
	for i in cap:
		var s = slots[i]
		if s != null and s.id == id and s.amount < max_stack:
			var room: int = max_stack - int(s.amount)
			var put := mini(room, amount)
			s.amount += put
			amount -= put
			if amount == 0:
				break
	if amount > 0:
		for i in cap:
			if slots[i] == null:
				var put := mini(max_stack, amount)
				slots[i] = {"id": id, "amount": put}
				amount -= put
				if amount == 0:
					break
	EventBus.inventory_changed.emit()
	return amount


func can_add(id: String, amount: int = 1) -> bool:
	var room := 0
	var max_stack := stack_size(id)
	for i in capacity():
		var s = slots[i]
		if s == null:
			room += max_stack
		elif s.id == id:
			room += max_stack - int(s.amount)
		if room >= amount:
			return true
	return false


func count(id: String) -> int:
	var n := 0
	for s in slots:
		if s != null and s.id == id:
			n += int(s.amount)
	return n


func remove_item(id: String, amount: int) -> bool:
	if count(id) < amount:
		return false
	for i in range(MAX_SLOTS - 1, -1, -1):
		var s = slots[i]
		if s != null and s.id == id:
			var take := mini(int(s.amount), amount)
			s.amount -= take
			amount -= take
			if s.amount <= 0:
				slots[i] = null
			if amount == 0:
				break
	EventBus.inventory_changed.emit()
	return true


func remove_from_slot(i: int, amount: int) -> void:
	var s = slots[i]
	if s == null:
		return
	s.amount -= amount
	if s.amount <= 0:
		slots[i] = null
	EventBus.inventory_changed.emit()


func swap(a: int, b: int) -> void:
	if a == b or a < 0 or b < 0 or a >= capacity() or b >= capacity():
		return
	var sa = slots[a]
	var sb = slots[b]
	# junta pilhas do mesmo item
	if sa != null and sb != null and sa.id == sb.id and sa.id != "pickaxe":
		var max_stack := stack_size(sa.id)
		var move := mini(int(sa.amount), max_stack - int(sb.amount))
		sb.amount += move
		sa.amount -= move
		if sa.amount <= 0:
			slots[a] = null
	else:
		slots[a] = sb
		slots[b] = sa
	EventBus.inventory_changed.emit()


func select(i: int) -> void:
	selected = clampi(i, 0, HOTBAR_SIZE - 1)
	EventBus.hotbar_selected.emit(selected)


func selected_item():
	return slots[selected]


func unique_items() -> Array:
	var out := []
	for s in slots:
		if s != null and not out.has(s.id):
			out.append(s.id)
	return out


func used_slots() -> int:
	var n := 0
	for i in capacity():
		if slots[i] != null:
			n += 1
	return n


func is_full() -> bool:
	return used_slots() >= capacity()


## Soma da radiação emitida pela carga (exposure %/s), antes da blindagem.
func carried_radiation() -> float:
	var r := 0.0
	for s in slots:
		if s != null:
			r += float(DataManager.get_item(s.id).get("radiation", 0.0)) * int(s.amount)
	return r


## Usa o consumível de um slot. Retorna true se consumiu.
func use_slot(i: int) -> bool:
	var s = slots[i]
	if s == null:
		return false
	var item := DataManager.get_item(s.id)
	var use: Dictionary = item.get("use", {})
	if use.has("note"):
		AudioSystem.play("tape")
		UIManager.open("note", {"note": use.note})
		return false
	if item.get("category", "") != "consumable":
		return false
	if use.has("energy"):
		if HealthSystem.energy >= HealthSystem.max_energy() - 0.5 and use.size() == 1:
			EventBus.toast.emit("Energia já está cheia.", "info")
			return false
		HealthSystem.restore_energy(float(use.energy))
	if use.has("hp"):
		if HealthSystem.hp >= HealthSystem.max_hp() - 0.5 and use.size() == 1:
			EventBus.toast.emit("Vida já está cheia.", "info")
			return false
		HealthSystem.heal(float(use.hp))
	if use.has("exposure"):
		RadiationSystem.add_exposure(float(use.exposure))
	if use.has("battery"):
		if HealthSystem.battery >= 99.0:
			EventBus.toast.emit("A bateria já está cheia.", "info")
			return false
		HealthSystem.battery = 100.0
		AudioSystem.play("battery")
	if use.has("throw"):
		return false
	if use.has("rad_resist"):
		RadiationSystem.add_resist(float(use.rad_resist), float(use.get("minutes", 120)))
	remove_from_slot(i, 1)
	EventBus.toast.emit("Usou: %s" % item.get("name", s.id), "good")
	return true


## Remove uma fração da carga (desmaio). Retorna lista de textos do que foi perdido.
func lose_cargo(ratio: float, rng: RandomNumberGenerator) -> Array:
	var lost := []
	for i in MAX_SLOTS:
		var s = slots[i]
		if s == null or s.id == "pickaxe":
			continue
		var cat: String = DataManager.get_item(s.id).get("category", "")
		if cat in ["consumable", "story"]:
			continue
		var n := int(round(int(s.amount) * ratio * rng.randf_range(0.6, 1.0)))
		if n > 0:
			lost.append("%dx %s" % [n, DataManager.item_name(s.id)])
			remove_from_slot(i, n)
	return lost


func get_save_data() -> Dictionary:
	return {"slots": slots.duplicate(true), "selected": selected}


func load_save_data(d: Dictionary) -> void:
	reset()
	var saved: Array = d.get("slots", [])
	for i in mini(saved.size(), MAX_SLOTS):
		var s = saved[i]
		if s is Dictionary and DataManager.items.has(s.get("id", "")):
			slots[i] = {"id": s.id, "amount": int(s.amount)}
		else:
			slots[i] = null
	if slots[0] == null or slots[0].id != "pickaxe":
		# garante a ferramenta (migração defensiva)
		var tool_idx := -1
		for i in MAX_SLOTS:
			if slots[i] != null and slots[i].id == "pickaxe":
				tool_idx = i
		if tool_idx == -1:
			add_item("pickaxe", 1)
	selected = clampi(int(d.get("selected", 0)), 0, HOTBAR_SIZE - 1)
	EventBus.inventory_changed.emit()
