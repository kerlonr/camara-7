extends Node
## Automação: estado das máquinas da base. Produção avança com o relógio do jogo
## (inclusive enquanto você está na mina ou dormindo).

var state: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	TimeSystem.minute_passed.connect(advance)
	reset()


func reset() -> void:
	state = {}
	for id in DataManager.machines:
		state[id] = {"fuel_minutes": 0.0, "progress": 0.0, "buffer": {}}


func machine_level(id: String) -> int:
	var m: Dictionary = DataManager.machines.get(id, {})
	return int(UpgradeSystem.get_stat(m.get("stat", ""), 0))


func is_owned(id: String) -> bool:
	return machine_level(id) > 0


func has_power() -> bool:
	for id in DataManager.machines:
		var m: Dictionary = DataManager.machines[id]
		if m.kind == "generator" and is_owned(id) and float(state[id].fuel_minutes) > 0.0:
			return true
	return false


func is_running(id: String) -> bool:
	var m: Dictionary = DataManager.machines.get(id, {})
	if not is_owned(id):
		return false
	if m.kind == "generator":
		return float(state[id].fuel_minutes) > 0.0
	if m.get("needs_power", false) and not has_power():
		return false
	return buffer_total(id) < buffer_capacity(id)


func level_cfg(id: String) -> Dictionary:
	var lvls: Array = DataManager.machines.get(id, {}).get("levels", [])
	if lvls.is_empty():
		return {}
	return lvls[clampi(machine_level(id) - 1, 0, lvls.size() - 1)]


func buffer_total(id: String) -> int:
	var n := 0
	for k in state[id].buffer:
		n += int(state[id].buffer[k])
	return n


func buffer_capacity(id: String) -> int:
	return int(level_cfg(id).get("buffer", 0))


func advance(minutes: int) -> void:
	# o gerador consome primeiro; produtores só rodam no tempo em que houve energia
	var powered_minutes := 0.0
	for id in DataManager.machines:
		var m: Dictionary = DataManager.machines[id]
		if m.kind == "generator" and is_owned(id):
			var fuel := float(state[id].fuel_minutes)
			var used := minf(fuel, minutes)
			state[id].fuel_minutes = fuel - used
			powered_minutes = maxf(powered_minutes, used)
			if fuel > 0.0 and state[id].fuel_minutes <= 0.0:
				EventBus.toast.emit("O gerador parou: sem carvão.", "warn")
				EventBus.machine_changed.emit(id)
	for id in DataManager.machines:
		var m: Dictionary = DataManager.machines[id]
		if m.kind != "producer" or not is_owned(id):
			continue
		var run_minutes := powered_minutes if m.get("needs_power", false) else float(minutes)
		if run_minutes <= 0.0:
			continue
		var cfg := level_cfg(id)
		var interval := float(cfg.get("interval_minutes", 60))
		state[id].progress = float(state[id].progress) + run_minutes
		var changed := false
		while state[id].progress >= interval:
			state[id].progress -= interval
			if buffer_total(id) >= buffer_capacity(id):
				state[id].progress = 0.0
				break
			var item := _roll(cfg.get("output", []))
			if item != "":
				state[id].buffer[item] = int(state[id].buffer.get(item, 0)) + 1
				changed = true
		if changed:
			EventBus.machine_changed.emit(id)


func _roll(table: Array) -> String:
	var total := 0.0
	for e in table:
		total += float(e.weight)
	var r := _rng.randf() * total
	for e in table:
		r -= float(e.weight)
		if r <= 0.0:
			return e.item
	return ""


## Interação com a máquina (tecla E). Retorna texto de feedback.
func interact(id: String) -> void:
	var m: Dictionary = DataManager.machines.get(id, {})
	if not is_owned(id):
		EventBus.toast.emit("Plataforma vazia. %s disponível no terminal." % m.get("name", id), "info")
		return
	if m.kind == "generator":
		var fuel_cfg: Dictionary = m.get("fuel", {})
		var per_unit := float(fuel_cfg.get("minutes_per_unit", 60))
		var cap_units := int(fuel_cfg.get("capacity", 20))
		var cur_units := ceili(float(state[id].fuel_minutes) / per_unit)
		var want := cap_units - cur_units
		var have := InventorySystem.count(fuel_cfg.get("item", "coal"))
		var put := mini(want, have)
		if put <= 0:
			var hrs := float(state[id].fuel_minutes) / 60.0
			if have <= 0:
				EventBus.toast.emit("Gerador: %.1f h de combustível. Traga %s." % [hrs, DataManager.item_name(fuel_cfg.get("item", "coal"))], "info")
			else:
				EventBus.toast.emit("Tanque cheio (%.1f h)." % hrs, "info")
			return
		InventorySystem.remove_item(fuel_cfg.get("item", "coal"), put)
		var was_off := float(state[id].fuel_minutes) <= 0.0
		state[id].fuel_minutes = float(state[id].fuel_minutes) + put * per_unit
		EventBus.toast.emit("Abasteceu %d de carvão. Autonomia: %.1f h." % [put, float(state[id].fuel_minutes) / 60.0], "good")
		if was_off:
			AudioSystem.play("door")
		EventBus.machine_changed.emit(id)
	else:
		var buf: Dictionary = state[id].buffer
		if buf.is_empty():
			var why := "" if has_power() or not m.get("needs_power", false) else " Sem energia: abasteça o gerador."
			EventBus.toast.emit("%s: nada para recolher ainda.%s" % [m.name, why], "info")
			return
		var got := 0
		for item in buf.keys():
			var left := InventorySystem.add_item(item, int(buf[item]))
			got += int(buf[item]) - left
			if left > 0:
				buf[item] = left
			else:
				buf.erase(item)
		if got > 0:
			AudioSystem.play("pickup")
			EventBus.toast.emit("Recolheu %d itens da %s." % [got, m.name], "good")
		if not buf.is_empty():
			EventBus.toast.emit("Inventário cheio.", "warn")
		EventBus.machine_changed.emit(id)


func status_text(id: String) -> String:
	var m: Dictionary = DataManager.machines.get(id, {})
	if not is_owned(id):
		return "%s (não instalada)" % m.get("name", id)
	if m.kind == "generator":
		return "%s — %.1f h de combustível" % [m.name, float(state[id].fuel_minutes) / 60.0]
	var st := "rodando" if is_running(id) else ("sem energia" if not has_power() else "cheia")
	return "%s Mk%d — %s — %d/%d" % [m.name, machine_level(id), st, buffer_total(id), buffer_capacity(id)]


func get_save_data() -> Dictionary:
	return {"state": state.duplicate(true)}


func load_save_data(d: Dictionary) -> void:
	reset()
	var saved: Dictionary = d.get("state", {})
	for id in saved:
		if state.has(id):
			state[id].fuel_minutes = float(saved[id].get("fuel_minutes", 0.0))
			state[id].progress = float(saved[id].get("progress", 0.0))
			var buf := {}
			var sb: Dictionary = saved[id].get("buffer", {})
			for k in sb:
				buf[k] = int(sb[k])
			state[id].buffer = buf
