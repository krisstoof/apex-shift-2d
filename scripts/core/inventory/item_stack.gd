extends RefCounted
class_name ItemStack

var item_id := ""
var amount := 0


func _init(p_item_id: String = "", p_amount: int = 0) -> void:
	item_id = p_item_id
	amount = max(p_amount, 0)
	if amount <= 0 or item_id.is_empty():
		clear()


func is_empty() -> bool:
	return item_id.is_empty() or amount <= 0


func can_stack_with(target_item_id: String) -> bool:
	return not is_empty() and item_id == target_item_id


func get_available_space(max_stack: int) -> int:
	if max_stack <= 0:
		return 0
	if is_empty():
		return max_stack
	return max(max_stack - amount, 0)


func add_amount(value: int, max_stack: int) -> int:
	if value <= 0:
		return 0
	var added := mini(get_available_space(max_stack), value)
	amount += added
	return value - added


func remove_amount(value: int) -> int:
	if value <= 0 or is_empty():
		return 0
	var removed := mini(amount, value)
	amount -= removed
	if amount <= 0:
		clear()
	return removed


func set_stack(p_item_id: String, p_amount: int) -> void:
	item_id = p_item_id
	amount = max(p_amount, 0)
	if amount <= 0 or item_id.is_empty():
		clear()


func clear() -> void:
	item_id = ""
	amount = 0


func to_save_data() -> Dictionary:
	if is_empty():
		return {}
	return {
		"item_id": item_id,
		"amount": amount
	}


func load_from_save_data(data: Dictionary) -> void:
	set_stack(str(data.get("item_id", "")), int(data.get("amount", 0)))


func duplicate_stack():
	var duplicate: Variant = get_script().new(item_id, amount)
	return duplicate
