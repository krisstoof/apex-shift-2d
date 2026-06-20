extends RefCounted
class_name CreatureMemory

var current_behavior := "wander"
var previous_behavior := ""
var decision_reason := "spawn"
var last_food_source := "none"

var target_entity_id := 0
var target_position := Vector2.ZERO
var target_kind := ""

var threat_entity_id := 0
var threat_position := Vector2.INF

var home_biome := ""
var current_biome := ""
var population_biome := ""

var state_time := 0.0
var target_lock_time := 0.0
var eat_cooldown := 0.0
var age_seconds := 0.0


func duplicate_state() -> CreatureMemory:
	var copy := CreatureMemory.new()
	copy.load_from_save_data(to_save_data())
	return copy


func clear_target() -> void:
	target_entity_id = 0
	target_position = Vector2.ZERO
	target_kind = ""


func set_target(entity_id: int, position: Vector2, kind: String = "") -> void:
	target_entity_id = entity_id
	target_position = position
	target_kind = kind


func set_behavior(next_behavior: String, reason: String = "") -> void:
	if current_behavior == next_behavior:
		if not reason.is_empty():
			decision_reason = reason
		return
	previous_behavior = current_behavior
	current_behavior = next_behavior
	if not reason.is_empty():
		decision_reason = reason


func to_save_data() -> Dictionary:
	return {
		"current_behavior": current_behavior,
		"previous_behavior": previous_behavior,
		"decision_reason": decision_reason,
		"last_food_source": last_food_source,
		"target_entity_id": target_entity_id,
		"target_position": _vector_to_data(target_position),
		"target_kind": target_kind,
		"threat_entity_id": threat_entity_id,
		"threat_position": _vector_to_data(threat_position),
		"home_biome": home_biome,
		"current_biome": current_biome,
		"population_biome": population_biome,
		"state_time": state_time,
		"target_lock_time": target_lock_time,
		"eat_cooldown": eat_cooldown,
		"age_seconds": age_seconds
	}


func load_from_save_data(data: Dictionary) -> void:
	current_behavior = str(data.get("current_behavior", current_behavior))
	previous_behavior = str(data.get("previous_behavior", previous_behavior))
	decision_reason = str(data.get("decision_reason", decision_reason))
	last_food_source = str(data.get("last_food_source", last_food_source))
	target_entity_id = int(data.get("target_entity_id", target_entity_id))
	target_position = _data_to_vector(data.get("target_position", _vector_to_data(target_position)), target_position)
	target_kind = str(data.get("target_kind", target_kind))
	threat_entity_id = int(data.get("threat_entity_id", threat_entity_id))
	threat_position = _data_to_vector(data.get("threat_position", _vector_to_data(threat_position)), threat_position)
	home_biome = str(data.get("home_biome", home_biome))
	current_biome = str(data.get("current_biome", current_biome))
	population_biome = str(data.get("population_biome", population_biome))
	state_time = maxf(_safe_float(data, "state_time", state_time), 0.0)
	target_lock_time = maxf(_safe_float(data, "target_lock_time", target_lock_time), 0.0)
	eat_cooldown = maxf(_safe_float(data, "eat_cooldown", eat_cooldown), 0.0)
	age_seconds = maxf(_safe_float(data, "age_seconds", age_seconds), 0.0)


static func _vector_to_data(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


static func _data_to_vector(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if typeof(value) != TYPE_DICTIONARY:
		return fallback
	var data := Dictionary(value)
	return Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y)))


static func _safe_float(data: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = data.get(key, fallback)
	if value == null:
		return fallback
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	if typeof(value) == TYPE_STRING and str(value).is_valid_float():
		return float(value)
	return fallback
