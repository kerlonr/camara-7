class_name Crafting
extends RefCounted
## Bancada de trabalho: receitas em data/crafting/recipes.json.


static func recipes() -> Array:
	return DataManager.recipes


static func missing(r: Dictionary) -> Array:
	var out := []
	if ProgressionSystem.level < int(r.get("min_level", 1)):
		out.append("Nível %d" % int(r.min_level))
	var items: Dictionary = r.get("items", {})
	for it in items:
		if InventorySystem.count(it) < int(items[it]):
			out.append("%s %d/%d" % [DataManager.item_name(it), InventorySystem.count(it), int(items[it])])
	return out


static func can_craft(r: Dictionary) -> bool:
	return missing(r).is_empty() and InventorySystem.can_add(r.result, int(r.get("amount", 1)))


static func craft(r: Dictionary) -> bool:
	if not can_craft(r):
		AudioSystem.play("ui_error")
		return false
	var items: Dictionary = r.get("items", {})
	for it in items:
		InventorySystem.remove_item(it, int(items[it]))
	InventorySystem.add_item(r.result, int(r.get("amount", 1)))
	ProgressionSystem.add_xp(3, "craft")
	AudioSystem.play("craft")
	EventBus.toast.emit("Fabricou: %dx %s" % [int(r.get("amount", 1)), DataManager.item_name(r.result)], "good")
	return true
