extends RefCounted
class_name Inventory

const ItemDatabase := preload("res://scripts/items/item_database.gd")

const SLOT_COUNT := 9

var slots: Array[Dictionary] = []


func _init() -> void:
	clear()


func clear() -> void:
	slots.clear()
	for _i in range(SLOT_COUNT):
		slots.append({
			"item_id": "",
			"amount": 0
		})


func add_item(item_id: String, amount: int) -> int:
	if amount <= 0:
		return 0
	if not ItemDatabase.has_item(item_id):
		return amount
	var remaining := amount
	var max_stack := ItemDatabase.get_max_stack(item_id)
	for slot in slots:
		if remaining <= 0:
			break
		if str(slot.get("item_id", "")) != item_id:
			continue
		var current_amount: int = int(slot.get("amount", 0))
		var available_space: int = max_stack - current_amount
		if available_space <= 0:
			continue
		var added_amount: int = int(min(available_space, remaining))
		slot["amount"] = current_amount + added_amount
		remaining -= added_amount
	for slot in slots:
		if remaining <= 0:
			break
		if str(slot.get("item_id", "")) != "":
			continue
		var added_amount: int = int(min(max_stack, remaining))
		slot["item_id"] = item_id
		slot["amount"] = added_amount
		remaining -= added_amount
	return remaining


func remove_item(item_id: String, amount: int) -> bool:
	if amount <= 0:
		return true
	if not ItemDatabase.has_item(item_id):
		return false
	if not has_item(item_id, amount):
		return false
	var remaining := amount
	for slot in slots:
		if remaining <= 0:
			break
		if str(slot.get("item_id", "")) != item_id:
			continue
		var current_amount: int = int(slot.get("amount", 0))
		var removed_amount: int = int(min(current_amount, remaining))
		current_amount -= removed_amount
		remaining -= removed_amount
		if current_amount <= 0:
			slot["item_id"] = ""
			slot["amount"] = 0
		else:
			slot["amount"] = current_amount
	return true


func has_item(item_id: String, amount: int) -> bool:
	if amount <= 0:
		return true
	return get_amount(item_id) >= amount


func get_amount(item_id: String) -> int:
	var total := 0
	for slot in slots:
		if str(slot.get("item_id", "")) == item_id:
			total += int(slot.get("amount", 0))
	return total


func get_all_items() -> Dictionary:
	var items: Dictionary = {}
	for slot in slots:
		var slot_item_id := str(slot.get("item_id", ""))
		var slot_amount := int(slot.get("amount", 0))
		if slot_item_id.is_empty() or slot_amount <= 0:
			continue
		items[slot_item_id] = int(items.get(slot_item_id, 0)) + slot_amount
	return items


func get_slots() -> Array:
	return slots.duplicate(true)


func to_save_data() -> Dictionary:
	var save_slots: Array[Dictionary] = []
	for slot in slots:
		var slot_item_id := str(slot.get("item_id", ""))
		var slot_amount := int(slot.get("amount", 0))
		if slot_item_id.is_empty() or slot_amount <= 0:
			continue
		save_slots.append({
			"item_id": slot_item_id,
			"amount": slot_amount
		})
	return {"slots": save_slots}


func load_from_save_data(data: Dictionary) -> void:
	clear()
	if data.is_empty() or not data.has("slots"):
		_migrate_legacy_inventory_data(data)
		return
	var slot_data: Array = Array(data.get("slots", []))
	var slot_index := 0
	for entry in slot_data:
		if slot_index >= SLOT_COUNT:
			break
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var slot_entry := Dictionary(entry)
		var item_id := str(slot_entry.get("item_id", ""))
		if item_id.is_empty() or not ItemDatabase.has_item(item_id):
			continue
		var amount := clampi(int(slot_entry.get("amount", 0)), 1, ItemDatabase.get_max_stack(item_id))
		slots[slot_index]["item_id"] = item_id
		slots[slot_index]["amount"] = amount
		slot_index += 1


func get_save_data() -> Dictionary:
	return to_save_data()


func restore_from_data(data: Dictionary) -> void:
	load_from_save_data(data)


func _migrate_legacy_inventory_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	var legacy_items := ["wood", "stone", "fiber", "meat", "hide", "bone", "torch"]
	for item_id in legacy_items:
		var amount := int(data.get(item_id, 0))
		if amount > 0:
			add_item(item_id, amount)
