extends RefCounted
class_name PlayerSaveData

const INVENTORY_SAVE_DATA := preload("res://scripts/core/save/inventory_save_data.gd")

var position := Vector2.ZERO
var stats: Dictionary = {}
var inventory: InventorySaveData = INVENTORY_SAVE_DATA.new()
var hotbar: Dictionary = {}
var has_spear := false
var has_bow := false
var torch_active := false
var torch_remaining_seconds := 0.0


func load_from_save_data(data: Dictionary) -> void:
	var source: Dictionary = Dictionary(data)
	position = _data_to_vector(source.get("position", {}), position)
	stats = Dictionary(source.get("stats", {})).duplicate(true)
	inventory.load_from_save_data(Dictionary(source.get("inventory", {})))
	hotbar = Dictionary(source.get("hotbar", {})).duplicate(true)
	has_spear = bool(source.get("has_spear", has_spear))
	has_bow = bool(source.get("has_bow", has_bow))
	torch_active = bool(source.get("torch_active", torch_active))
	torch_remaining_seconds = float(source.get("torch_remaining_seconds", torch_remaining_seconds))


func to_save_data() -> Dictionary:
	return {
		"position": _vector_to_data(position),
		"stats": stats.duplicate(true),
		"inventory": inventory.to_save_data(),
		"hotbar": hotbar.duplicate(true),
		"has_spear": has_spear,
		"has_bow": has_bow,
		"torch_active": torch_active,
		"torch_remaining_seconds": torch_remaining_seconds
	}


static func _vector_to_data(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


static func _data_to_vector(data: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if typeof(data) != TYPE_DICTIONARY:
		return fallback
	var dict: Dictionary = Dictionary(data)
	return Vector2(float(dict.get("x", fallback.x)), float(dict.get("y", fallback.y)))
