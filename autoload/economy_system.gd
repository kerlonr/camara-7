extends Node
## Dinheiro, preços e vendas. sell_price() é o ponto único para futuros
## modificadores de mercado (inflação, compradores, contratos).

var money: int = 0


func reset() -> void:
	money = int(DataManager.game.get("start_money", 0))
	EventBus.money_changed.emit(money)


func add_money(amount: int) -> void:
	money += amount
	if amount > 0:
		GameState.add_stat("money_earned", amount)
	EventBus.money_changed.emit(money)


func can_afford(amount: int) -> bool:
	return money >= amount


func spend(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	EventBus.money_changed.emit(money)
	return true


func sell_price(item_id: String) -> int:
	var item := DataManager.get_item(item_id)
	var base := float(item.get("value", 0))
	if base <= 0.0:
		return 0
	var mult := float(DataManager.shop.get("sell_multiplier", 1.0))
	mult *= 1.0 + float(UpgradeSystem.get_stat("sell_bonus", 0.0))
	return maxi(1, roundi(base * mult))


func is_sellable(item_id: String) -> bool:
	var item := DataManager.get_item(item_id)
	return not item.get("category", "") in ["tool", "story"] and sell_price(item_id) > 0


## Vende até 'amount' unidades do inventário. Retorna o valor recebido.
func sell(item_id: String, amount: int) -> int:
	var have := InventorySystem.count(item_id)
	amount = mini(amount, have)
	if amount <= 0 or not is_sellable(item_id):
		return 0
	InventorySystem.remove_item(item_id, amount)
	var total := sell_price(item_id) * amount
	add_money(total)
	GameState.add_stat("items_sold", amount)
	return total


## Vende tudo que não for consumível nem ferramenta.
func sell_all_cargo() -> int:
	var total := 0
	for id in InventorySystem.unique_items():
		var cat: String = DataManager.get_item(id).get("category", "")
		if cat in ["ore", "material", "component"]:
			total += sell(id, InventorySystem.count(id))
	return total


func get_save_data() -> Dictionary:
	return {"money": money}


func load_save_data(d: Dictionary) -> void:
	money = int(d.get("money", 0))
	EventBus.money_changed.emit(money)
