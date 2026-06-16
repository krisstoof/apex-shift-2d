extends RefCounted
class_name CreatureSimulationLOD

enum Level { NEAR, MEDIUM, FAR }

const LEVEL_NAMES := {
	Level.NEAR: "near",
	Level.MEDIUM: "medium",
	Level.FAR: "far"
}


static func get_level_name(level: int) -> String:
	return str(LEVEL_NAMES.get(level, "unknown"))


static func resolve_level(distance_to_player: float, config: Dictionary, creature_type: String = "") -> int:
	var near_distance := float(config.get("near_distance", 900.0))
	var medium_distance := float(config.get("medium_distance", 1800.0))
	if creature_type == "varnak":
		var force_varnak_near_distance := float(config.get("force_varnak_near_distance", near_distance))
		if distance_to_player <= force_varnak_near_distance:
			return Level.NEAR
	if distance_to_player <= near_distance:
		return Level.NEAR
	if distance_to_player <= medium_distance:
		return Level.MEDIUM
	return Level.FAR


static func get_medium_ai_interval(base_interval: float, config: Dictionary) -> float:
	return base_interval * float(config.get("medium_ai_interval_multiplier", 3.0))


static func get_medium_spatial_interval(base_interval: float, config: Dictionary) -> float:
	return base_interval * float(config.get("medium_spatial_update_multiplier", 2.0))


static func get_far_update_interval(config: Dictionary) -> float:
	return float(config.get("far_update_interval_seconds", 3.0))
