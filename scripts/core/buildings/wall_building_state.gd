extends BuildingState
class_name WallBuildingState

var health := 0.0
var wall_state: Dictionary = {}

func capture_from_building(building: Node) -> void:
	kind = "wall"
	super.capture_from_building(building)
	health = float(building.get("health")) if building.get("health") != null else health
	wall_state = {
		"health": health
	}

func for_kind(_building_kind: String = "wall") -> Dictionary:
	return {
		"kind": "wall",
		"position": {"x": position.x, "y": position.y},
		"wall_state": wall_state.duplicate(true)
	}
