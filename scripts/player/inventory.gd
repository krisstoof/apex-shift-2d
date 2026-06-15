extends RefCounted
class_name Inventory

const ITEM_DATABASE := preload("res://scripts/items/item_database.gd")

const DEFAULT_SLOT_COUNT := 9

signal inventory_changed

var slots: Array[Dictionary] = []
var slot_count: int = DEFAULT_SLOT_COUNT


func _init(p_slot_count: int = DEFAULT_SLOT_COUNT) -> void:
	slot_count = maxi(p_slot_count, 1)
	clear()


func clear() -> void:
	slots.clear()
	for _i in range(slot_count):
		slots.append({
			"item_id": "",
			"amount": 0
		})
	inventory_changed.emit()


func add_item(item_id: String, amount: int) -> int:
	item_id = ITEM_DATABASE.normalize_item_id(item_id)
	if amount <= 0:
		return 0
	if not ITEM_DATABASE.has_item(item_id):
		return amount
	var remaining := amount
	var max_stack := ITEM_DATABASE.get_max_stack(item_id)
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
	if remaining != amount:
		inventory_changed.emit()
	return remaining


func can_add_item(item_id: String, amount: int) -> bool:
	item_id = ITEM_DATABASE.normalize_item_id(item_id)
	if amount <= 0:
		return false
	if not ITEM_DATABASE.has_item(item_id):
		return false
	var max_stack := ITEM_DATABASE.get_max_stack(item_id)
	var remaining := amount
	for slot in slots:
		if remaining <= 0:
			break
		var slot_item_id := str(slot.get("item_id", ""))
		var current_amount: int = int(slot.get("amount", 0))
		if slot_item_id == item_id:
			var available_space: int = max_stack - current_amount
			remaining -= maxi(available_space, 0)
		elif slot_item_id.is_empty():
			remaining -= max_stack
	return remaining <= 0


func add_item_full_stack(item_id: String, amount: int) -> bool:
	item_id = ITEM_DATABASE.normalize_item_id(item_id)
	if not can_add_item(item_id, amount):
		return false
	var leftover := add_item(item_id, amount)
	return leftover == 0


func is_valid_slot_index(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < slots.size()


func peek_slot_stack(slot_index: int) -> Dictionary:
	if not is_valid_slot_index(slot_index):
		return {}
	var slot := Dictionary(slots[slot_index])
	var item_id := str(slot.get("item_id", ""))
	var amount := int(slot.get("amount", 0))
	if item_id.is_empty() or amount <= 0:
		return {}
	return {
		"slot_index": slot_index,
		"item_id": item_id,
		"amount": amount
	}


func clear_slot_stack(slot_index: int) -> bool:
	if not is_valid_slot_index(slot_index):
		return false
	var stack := peek_slot_stack(slot_index)
	if stack.is_empty():
		return false
	slots[slot_index]["item_id"] = ""
	slots[slot_index]["amount"] = 0
	inventory_changed.emit()
	return true


func remove_item(item_id: String, amount: int) -> bool:
	item_id = ITEM_DATABASE.normalize_item_id(item_id)
	if amount <= 0:
		return true
	if not ITEM_DATABASE.has_item(item_id):
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
	inventory_changed.emit()
	return true


func has_item(item_id: String, amount: int) -> bool:
	item_id = ITEM_DATABASE.normalize_item_id(item_id)
	if amount <= 0:
		return true
	return get_amount(item_id) >= amount


func get_amount(item_id: String) -> int:
	item_id = ITEM_DATABASE.normalize_item_id(item_id)
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
	if data.is_empty():
		return
	var saved_slots: Array = []
	if data.has("slots") and data["slots"] is Array:
		saved_slots = Array(data.get("slots", []))
	elif data.has("items") and data["items"] is Array:
		saved_slots = Array(data.get("items", []))
	else:
		_migrate_legacy_inventory_data(data)
		return
	var slot_index := 0
	for entry in saved_slots:
		if slot_index >= slot_count:
			break
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var slot_entry := Dictionary(entry)
		var item_id := str(slot_entry.get("item_id", ""))
		if item_id.is_empty() or not ITEM_DATABASE.has_item(item_id):
			continue
		var amount := clampi(int(slot_entry.get("amount", 0)), 1, ITEM_DATABASE.get_max_stack(item_id))
		slots[slot_index]["item_id"] = item_id
		slots[slot_index]["amount"] = amount
		slot_index += 1
	inventory_changed.emit()


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
