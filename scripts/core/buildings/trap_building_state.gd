extends BuildingState
class_name TrapBuildingState

var armed := true
var damage := 0.0
var trap_state: Dictionary = {}

func capture_from_building(building: Node) -> void:
	kind = "trap"
	super.capture_from_building(building)
	armed = bool(building.get("armed")) if building.get("armed") != null else armed
	damage = float(building.get("damage")) if building.get("damage") != null else damage
	trap_state = {
		"armed": armed,
		"damage": damage
	}

func for_kind(_building_kind: String = "trap") -> Dictionary:
	return {
		"kind": "trap",
		"position": {"x": position.x, "y": position.y},
		"trap_state": trap_state.duplicate(true)
	}
