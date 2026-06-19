extends RefCounted
class_name InventoryState

const ITEM_DATABASE := preload("res://scripts/items/item_database.gd")
const ITEM_STACK := preload("res://scripts/core/inventory/item_stack.gd")

const DEFAULT_SLOT_COUNT := 9

signal inventory_changed

var slots: Array = []
var slot_count: int = DEFAULT_SLOT_COUNT


func _init(p_slot_count: int = DEFAULT_SLOT_COUNT) -> void:
	slot_count = maxi(p_slot_count, 1)
	_reset_slots()


func clear() -> void:
	_reset_slots()
	inventory_changed.emit()


func add_item(item_id: String, amount: int) -> int:
	item_id = ITEM_DATABASE.normalize_item_id(item_id)
	if amount <= 0:
		return 0
	if not ITEM_DATABASE.has_item(item_id):
		return amount

	var remaining := amount
	var max_stack := ITEM_DATABASE.get_max_stack(item_id)

	for slot_value in slots:
		if remaining <= 0:
			break
		var slot: Variant = slot_value
		if not slot.can_stack_with(item_id):
			continue
		remaining = slot.add_amount(remaining, max_stack)

	for slot_value in slots:
		if remaining <= 0:
			break
		var slot: Variant = slot_value
		if not slot.is_empty():
			continue
		var added := mini(max_stack, remaining)
		slot.set_stack(item_id, added)
		remaining -= added

	if remaining != amount:
		inventory_changed.emit()
	return remaining


func can_add_item(item_id: String, amount: int) -> bool:
	item_id = ITEM_DATABASE.normalize_item_id(item_id)
	if amount <= 0:
		return false
	if not ITEM_DATABASE.has_item(item_id):
		return false

	var remaining := amount
	var max_stack := ITEM_DATABASE.get_max_stack(item_id)
	for slot_value in slots:
		if remaining <= 0:
			break
		var slot: Variant = slot_value
		if slot.can_stack_with(item_id) or slot.is_empty():
			remaining -= slot.get_available_space(max_stack)
	return remaining <= 0


func add_item_full_stack(item_id: String, amount: int) -> bool:
	item_id = ITEM_DATABASE.normalize_item_id(item_id)
	if not can_add_item(item_id, amount):
		return false
	return add_item(item_id, amount) == 0


func remove_item(item_id: String, amount: int) -> bool:
	item_id = ITEM_DATABASE.normalize_item_id(item_id)
	if amount <= 0:
		return true
	if not ITEM_DATABASE.has_item(item_id):
		return false
	if not has_item(item_id, amount):
		return false

	var remaining := amount
	for slot_value in slots:
		if remaining <= 0:
			break
		var slot: Variant = slot_value
		if not slot.can_stack_with(item_id):
			continue
		remaining -= slot.remove_amount(remaining)

	inventory_changed.emit()
	return true


func remove_from_slot(slot_index: int, amount: int = -1) -> int:
	if not is_valid_slot_index(slot_index):
		return 0
	var slot: Variant = slots[slot_index]
	if slot.is_empty():
		return 0
	var requested: int = slot.amount if amount <= 0 else amount
	var removed: int = slot.remove_amount(requested)
	if removed > 0:
		inventory_changed.emit()
	return removed


func has_item(item_id: String, amount: int) -> bool:
	item_id = ITEM_DATABASE.normalize_item_id(item_id)
	if amount <= 0:
		return true
	return get_amount(item_id) >= amount


func get_amount(item_id: String) -> int:
	item_id = ITEM_DATABASE.normalize_item_id(item_id)
	var total := 0
	for slot_value in slots:
		var slot: Variant = slot_value
		if not slot.is_empty() and slot.item_id == item_id:
			total += slot.amount
	return total


func get_all_items() -> Dictionary:
	var items: Dictionary = {}
	for slot_value in slots:
		var slot: Variant = slot_value
		if slot.is_empty():
			continue
		items[slot.item_id] = int(items.get(slot.item_id, 0)) + slot.amount
	return items


func get_slots() -> Array:
	var result: Array = []
	for slot_value in slots:
		var slot: Variant = slot_value
		if slot.is_empty():
			result.append({
				"item_id": "",
				"amount": 0
			})
		else:
			result.append(slot.to_save_data())
	return result


func get_slot_count() -> int:
	return slot_count


func get_empty_slot_count() -> int:
	var count := 0
	for slot_value in slots:
		var slot: Variant = slot_value
		if slot.is_empty():
			count += 1
	return count


func is_valid_slot_index(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < slots.size()


func peek_slot_stack(slot_index: int) -> Dictionary:
	if not is_valid_slot_index(slot_index):
		return {}
	var slot: Variant = slots[slot_index]
	if slot.is_empty():
		return {}
	return {
		"slot_index": slot_index,
		"item_id": slot.item_id,
		"amount": slot.amount
	}


func clear_slot_stack(slot_index: int) -> bool:
	if not is_valid_slot_index(slot_index):
		return false
	var slot: Variant = slots[slot_index]
	if slot.is_empty():
		return false
	slot.clear()
	inventory_changed.emit()
	return true


func to_save_data() -> Dictionary:
	var save_slots: Array[Dictionary] = []
	for slot_value in slots:
		var slot: Variant = slot_value
		if slot.is_empty():
			continue
		save_slots.append(slot.to_save_data())
	return {"slots": save_slots}


func load_from_save_data(data: Dictionary) -> void:
	_reset_slots()
	if data.is_empty():
		inventory_changed.emit()
		return

	var saved_slots: Array = []
	if data.has("slots") and data["slots"] is Array:
		saved_slots = Array(data.get("slots", []))
	elif data.has("items") and data["items"] is Array:
		saved_slots = Array(data.get("items", []))
	else:
		_migrate_legacy_inventory_data(data)
		inventory_changed.emit()
		return

	var next_compact_slot_index := 0
	for entry in saved_slots:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var slot_entry := Dictionary(entry)
		var item_id := ITEM_DATABASE.normalize_item_id(str(slot_entry.get("item_id", "")))
		if item_id.is_empty() or not ITEM_DATABASE.has_item(item_id):
			continue
		var amount := clampi(int(slot_entry.get("amount", 0)), 1, ITEM_DATABASE.get_max_stack(item_id))
		var target_slot_index := next_compact_slot_index
		if slot_entry.has("slot_index"):
			target_slot_index = int(slot_entry.get("slot_index", next_compact_slot_index))
		if not is_valid_slot_index(target_slot_index):
			continue
		var slot: Variant = slots[target_slot_index]
		if not slot.is_empty():
			continue
		slot.set_stack(item_id, amount)
		if not slot_entry.has("slot_index"):
			next_compact_slot_index += 1
		if next_compact_slot_index >= slot_count:
			break

	inventory_changed.emit()


func get_save_data() -> Dictionary:
	return to_save_data()


func restore_from_data(data: Dictionary) -> void:
	load_from_save_data(data)


func _reset_slots() -> void:
	slots.clear()
	for _i in range(slot_count):
		slots.append(ITEM_STACK.new())


func _migrate_legacy_inventory_data(data: Dictionary) -> void:
	var legacy_items := ["wood", "stone", "fiber", "meat", "hide", "bone", "torch"]
	for item_id in legacy_items:
		var amount := int(data.get(item_id, 0))
		if amount > 0:
			add_item(item_id, amount)
