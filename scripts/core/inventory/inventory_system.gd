extends RefCounted
class_name InventorySystem

const ITEM_DATABASE := preload("res://scripts/items/item_database.gd")


static func add_item(inventory_state: Variant, item_id: String, amount: int) -> int:
	if inventory_state == null or not inventory_state.has_method("add_item"):
		return amount
	return int(inventory_state.call("add_item", item_id, amount))


static func remove_item(inventory_state: Variant, item_id: String, amount: int) -> bool:
	if inventory_state == null or not inventory_state.has_method("remove_item"):
		return false
	return bool(inventory_state.call("remove_item", item_id, amount))


static func transfer_item(source_state: Variant, destination_state: Variant, item_id: String, amount: int) -> Dictionary:
	item_id = ITEM_DATABASE.normalize_item_id(item_id)
	if source_state == null or destination_state == null:
		return _build_transfer_result(item_id, amount, 0, amount, false)
	if item_id.is_empty() or amount <= 0 or not ITEM_DATABASE.has_item(item_id):
		return _build_transfer_result(item_id, amount, 0, amount, false)
	if not source_state.has_method("get_amount") or not source_state.has_method("remove_item"):
		return _build_transfer_result(item_id, amount, 0, amount, false)
	if not destination_state.has_method("add_item"):
		return _build_transfer_result(item_id, amount, 0, amount, false)

	var available := int(source_state.call("get_amount", item_id))
	var requested := mini(amount, available)
	if requested <= 0:
		return _build_transfer_result(item_id, amount, 0, amount, false)

	var leftover := int(destination_state.call("add_item", item_id, requested))
	var moved := requested - leftover
	if moved <= 0:
		return _build_transfer_result(item_id, requested, 0, requested, false)

	var removed := bool(source_state.call("remove_item", item_id, moved))
	if not removed:
		if destination_state.has_method("remove_item"):
			destination_state.call("remove_item", item_id, moved)
		return _build_transfer_result(item_id, requested, 0, requested, false)

	return _build_transfer_result(item_id, requested, moved, leftover, true)


static func transfer_slot(source_state: Variant, destination_state: Variant, source_slot_index: int, amount: int = -1) -> Dictionary:
	if source_state == null or destination_state == null:
		return _build_transfer_result("", amount, 0, amount, false)
	if not source_state.has_method("peek_slot_stack"):
		return _build_transfer_result("", amount, 0, amount, false)
	if not destination_state.has_method("add_item"):
		return _build_transfer_result("", amount, 0, amount, false)

	var stack := Dictionary(source_state.call("peek_slot_stack", source_slot_index))
	if stack.is_empty():
		return _build_transfer_result("", amount, 0, amount, false)

	var item_id := ITEM_DATABASE.normalize_item_id(str(stack.get("item_id", "")))
	var available := int(stack.get("amount", 0))
	var requested := available if amount <= 0 else mini(amount, available)
	if item_id.is_empty() or requested <= 0:
		return _build_transfer_result(item_id, requested, 0, requested, false)

	var leftover := int(destination_state.call("add_item", item_id, requested))
	var moved := requested - leftover
	if moved <= 0:
		return _build_transfer_result(item_id, requested, 0, requested, false)

	var removed := 0
	if source_state.has_method("remove_from_slot"):
		removed = int(source_state.call("remove_from_slot", source_slot_index, moved))
	elif source_state.has_method("remove_item"):
		removed = moved if bool(source_state.call("remove_item", item_id, moved)) else 0

	if removed != moved:
		if removed > 0 and destination_state.has_method("remove_item"):
			destination_state.call("remove_item", item_id, removed)
		return _build_transfer_result(item_id, requested, removed, requested - removed, removed > 0)

	return _build_transfer_result(item_id, requested, moved, leftover, true)


static func _build_transfer_result(item_id: String, requested: int, moved: int, leftover: int, success: bool) -> Dictionary:
	return {
		"item_id": item_id,
		"requested": max(requested, 0),
		"moved": max(moved, 0),
		"leftover": max(leftover, 0),
		"success": success
	}
