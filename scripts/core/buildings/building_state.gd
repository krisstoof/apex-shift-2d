extends RefCounted
class_name BuildingState

var kind := ""
var position := Vector2.ZERO
var custom_data: Dictionary = {}


func for_kind(building_kind: String) -> Dictionary:
	return {
		"kind": building_kind,
		"position": {"x": position.x, "y": position.y},
		"custom_data": custom_data.duplicate(true)
	}


func to_save_data() -> Dictionary:
	return {
		"kind": kind,
		"position": {"x": position.x, "y": position.y},
		"custom_data": custom_data.duplicate(true)
	}


func load_from_save_data(data: Dictionary) -> void:
	kind = str(data.get("kind", kind))
	position = Vector2(float(Dictionary(data.get("position", {})).get("x", position.x)), float(Dictionary(data.get("position", {})).get("y", position.y)))
	custom_data = Dictionary(data.get("custom_data", custom_data)).duplicate(true)


func capture_from_building(building: Node) -> void:
	kind = str(building.get("building_kind")) if building.get("building_kind") != null else kind
	position = building.global_position if building is Node2D else position
	if building.has_method("get_building_state"):
		var state := Dictionary(building.call("get_building_state"))
		load_from_save_data(state)
		return
	custom_data = {}


func apply_to_building(building: Node) -> void:
	if building is Node2D:
		(building as Node2D).global_position = position
	if building.has_method("apply_building_state"):
		building.call("apply_building_state", to_save_data())
		return
