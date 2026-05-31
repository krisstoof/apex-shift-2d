extends RefCounted
class_name Inventory

var items := {
	"wood": 0,
	"stone": 0,
	"fiber": 0,
	"meat": 0,
	"hide": 0,
	"bone": 0,
	"torch": 0
}

func add_item(item_name: String, amount: int) -> void:
	items[item_name] = get_amount(item_name) + amount


func remove_item(item_name: String, amount: int) -> bool:
	if not has_item(item_name, amount):
		return false
	items[item_name] = get_amount(item_name) - amount
	return true


func has_item(item_name: String, amount: int) -> bool:
	return get_amount(item_name) >= amount


func get_amount(item_name: String) -> int:
	return int(items.get(item_name, 0))


func get_save_data() -> Dictionary:
	return items.duplicate(true)


func restore_from_data(data: Dictionary) -> void:
	for item_name in items.keys():
		items[item_name] = int(data.get(item_name, 0))
