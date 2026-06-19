extends RefCounted
class_name StorageState

const INVENTORY_STATE := preload("res://scripts/core/inventory/inventory_state.gd")

const DEFAULT_SLOT_COUNT := 12

var inventory_state: Variant
var slot_count := DEFAULT_SLOT_COUNT


func _init(p_slot_count: int = DEFAULT_SLOT_COUNT, p_inventory_state: Variant = null) -> void:
	slot_count = maxi(p_slot_count, 1)
	inventory_state = p_inventory_state if p_inventory_state != null else INVENTORY_STATE.new(slot_count)


func get_inventory_state() -> Variant:
	return inventory_state


func get_inventory_save_data() -> Dictionary:
	if inventory_state != null and inventory_state.has_method("to_save_data"):
		return Dictionary(inventory_state.call("to_save_data"))
	return {}


func to_save_data() -> Dictionary:
	return {
		"inventory": get_inventory_save_data()
	}


func load_from_save_data(data: Dictionary) -> void:
	if inventory_state == null:
		inventory_state = INVENTORY_STATE.new(slot_count)
	if data.has("inventory"):
		inventory_state.call("load_from_save_data", Dictionary(data.get("inventory", {})))
	else:
		inventory_state.call("load_from_save_data", data)


func get_slots() -> Array:
	return inventory_state.call("get_slots") if inventory_state != null and inventory_state.has_method("get_slots") else []


func get_amount(item_id: String) -> int:
	return int(inventory_state.call("get_amount", item_id)) if inventory_state != null and inventory_state.has_method("get_amount") else 0
