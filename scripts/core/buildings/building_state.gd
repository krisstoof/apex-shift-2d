extends RefCounted
class_name BuildingState

var kind := ""
var position := Vector2.ZERO
var custom_data: Dictionary = {}


func for_kind(building_kind: String) -> Dictionary:
	kind = building_kind
	var data := to_save_data()
	var state_key := _get_state_key_for_kind(building_kind)
	if state_key != "":
		data[state_key] = custom_data.duplicate(true)
		for key in custom_data.keys():
			data[key] = custom_data[key]
	return data


func to_save_data() -> Dictionary:
	return {
		"kind": kind,
		"position": {"x": position.x, "y": position.y},
		"custom_data": custom_data.duplicate(true)
	}


func load_from_save_data(data: Dictionary) -> void:
	kind = str(data.get("kind", kind))
	position = _data_to_vector(Dictionary(data.get("position", {})), position)
	custom_data = Dictionary(data.get("custom_data", {})).duplicate(true)
	var state_key := _get_state_key_for_kind(kind)
	if state_key != "" and data.has(state_key):
		custom_data.merge(Dictionary(data.get(state_key, {})), true)
	for key in ["active", "fear_radius", "armed", "damage", "health", "inventory"]:
		if data.has(key):
			custom_data[key] = data[key]
	if data.has("campfire_state"):
		custom_data.merge(Dictionary(data.get("campfire_state", {})), true)
	if data.has("trap_state"):
		custom_data.merge(Dictionary(data.get("trap_state", {})), true)
	if data.has("wall_state"):
		custom_data.merge(Dictionary(data.get("wall_state", {})), true)
	if data.has("storage_box_state"):
		custom_data.merge(Dictionary(data.get("storage_box_state", {})), true)


func capture_from_building(building: Node) -> void:
	kind = str(building.get("building_kind")) if building.get("building_kind") != null else kind
	position = building.global_position if building is Node2D else position
	if building.has_method("get_building_state"):
		var state := Dictionary(building.call("get_building_state"))
		load_from_save_data(state)
		return
	custom_data = {}
	for key in ["active", "fear_radius", "armed", "damage", "health", "inventory"]:
		var value = building.get(key)
		if value != null:
			custom_data[key] = value
	if building.has_method("get") and building.get("storage_state") != null:
		custom_data["inventory"] = building.get("storage_state").get_inventory_save_data()


func apply_to_building(building: Node) -> void:
	if building is Node2D:
		(building as Node2D).global_position = position
	if building.has_method("apply_building_state"):
		building.call("apply_building_state", to_save_data())
		return


static func _data_to_vector(data: Dictionary, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if data.is_empty():
		return fallback
	return Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y)))


static func _get_state_key_for_kind(building_kind: String) -> String:
	match building_kind:
		"campfire":
			return "campfire_state"
		"trap":
			return "trap_state"
		"wall":
			return "wall_state"
		"storage_box":
			return "storage_box_state"
		_:
			return ""
