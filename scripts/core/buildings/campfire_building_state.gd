extends BuildingState
class_name CampfireBuildingState

var active := true
var fear_radius := 0.0
var campfire_state: Dictionary = {}

func capture_from_building(building: Node) -> void:
	kind = "campfire"
	super.capture_from_building(building)
	active = bool(building.get("active")) if building.get("active") != null else active
	fear_radius = float(building.get("fear_radius")) if building.get("fear_radius") != null else fear_radius
	campfire_state = {
		"active": active,
		"fear_radius": fear_radius
	}

func for_kind(_building_kind: String = "campfire") -> Dictionary:
	return {
		"kind": "campfire",
		"position": {"x": position.x, "y": position.y},
		"campfire_state": campfire_state.duplicate(true)
	}
