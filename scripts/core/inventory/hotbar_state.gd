extends RefCounted
class_name HotbarState

const DEFAULT_SLOT_COUNT := 9

signal hotbar_changed

var slot_count := DEFAULT_SLOT_COUNT
var selected_index := 0


func _init(p_slot_count: int = DEFAULT_SLOT_COUNT) -> void:
	slot_count = maxi(p_slot_count, 1)
	selected_index = 0


func select_slot(index: int) -> bool:
	if index < 0 or index >= slot_count:
		return false
	if selected_index == index:
		return true
	selected_index = index
	hotbar_changed.emit()
	return true


func select_next() -> int:
	selected_index = (selected_index + 1) % slot_count
	hotbar_changed.emit()
	return selected_index


func select_previous() -> int:
	selected_index = (selected_index - 1 + slot_count) % slot_count
	hotbar_changed.emit()
	return selected_index


func get_selected_index() -> int:
	return selected_index


func get_slot_count() -> int:
	return slot_count


func to_save_data() -> Dictionary:
	return {
		"slot_count": slot_count,
		"selected_index": selected_index
	}


func load_from_save_data(data: Dictionary) -> void:
	slot_count = maxi(int(data.get("slot_count", slot_count)), 1)
	selected_index = clampi(int(data.get("selected_index", selected_index)), 0, slot_count - 1)
	hotbar_changed.emit()
