extends BuildingState
class_name StorageBoxBuildingState

var inventory: Dictionary = {}
var storage_box_state: Dictionary = {}

func capture_from_building(building: Node) -> void:
	kind = "storage_box"
	super.capture_from_building(building)
	if building.has_method("get_save_data"):
		var save_data := Dictionary(building.call("get_save_data"))
		inventory = Dictionary(save_data.get("inventory", inventory)).duplicate(true)
	storage_box_state = {
		"inventory": inventory.duplicate(true)
	}

func for_kind(_building_kind: String = "storage_box") -> Dictionary:
	return {
		"kind": "storage_box",
		"position": {"x": position.x, "y": position.y},
		"storage_box_state": storage_box_state.duplicate(true)
	}
