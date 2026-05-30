extends RefCounted
class_name Inventory

var items := {
	"wood": 8,
	"stone": 5,
	"fiber": 5,
	"meat": 0,
	"hide": 0,
	"bone": 0
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
