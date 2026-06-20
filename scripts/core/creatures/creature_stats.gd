extends RefCounted
class_name CreatureStats

var max_health := 1.0
var health := 1.0
var speed := 1.0
var fear := 0.0
var aggression := 0.0
var plant_diet := 0.0
var meat_diet := 0.0
var scavenger_diet := 0.0
var fire_fear := 0.0
var trap_awareness := 0.0
var pack_coordination := 0.0
var night_activity := 0.0
var reproduction_value := 0.0
var size := 1.0


func duplicate_state() -> CreatureStats:
	var copy := CreatureStats.new()
	copy.load_from_save_data(to_save_data())
	return copy


func to_save_data() -> Dictionary:
	return {
		"max_health": max_health,
		"health": health,
		"speed": speed,
		"fear": fear,
		"aggression": aggression,
		"plant_diet": plant_diet,
		"meat_diet": meat_diet,
		"scavenger_diet": scavenger_diet,
		"fire_fear": fire_fear,
		"trap_awareness": trap_awareness,
		"pack_coordination": pack_coordination,
		"night_activity": night_activity,
		"reproduction_value": reproduction_value,
		"size": size
	}


func load_from_save_data(data: Dictionary) -> void:
	max_health = maxf(_safe_float(data, "max_health", max_health), 0.01)
	health = clampf(_safe_float(data, "health", health), 0.0, max_health)
	speed = maxf(_safe_float(data, "speed", speed), 0.0)
	fear = clampf(_safe_float(data, "fear", fear), 0.0, 10.0)
	aggression = clampf(_safe_float(data, "aggression", aggression), 0.0, 10.0)
	plant_diet = clampf(_safe_float(data, "plant_diet", plant_diet), 0.0, 1.0)
	meat_diet = clampf(_safe_float(data, "meat_diet", meat_diet), 0.0, 1.0)
	scavenger_diet = clampf(_safe_float(data, "scavenger_diet", scavenger_diet), 0.0, 1.0)
	fire_fear = clampf(_safe_float(data, "fire_fear", fire_fear), 0.0, 10.0)
	trap_awareness = clampf(_safe_float(data, "trap_awareness", trap_awareness), 0.0, 10.0)
	pack_coordination = clampf(_safe_float(data, "pack_coordination", pack_coordination), 0.0, 10.0)
	night_activity = clampf(_safe_float(data, "night_activity", night_activity), 0.0, 10.0)
	reproduction_value = clampf(_safe_float(data, "reproduction_value", reproduction_value), 0.0, 10.0)
	size = maxf(_safe_float(data, "size", size), 0.01)


static func _safe_float(data: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = data.get(key, fallback)
	if value == null:
		return fallback
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	if typeof(value) == TYPE_STRING and str(value).is_valid_float():
		return float(value)
	return fallback
