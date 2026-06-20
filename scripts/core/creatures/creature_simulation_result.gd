extends RefCounted
class_name CreatureSimulationResult

var behavior := ""
var decision_reason := ""
var target_entity_id := 0
var target_position := Vector2.ZERO
var target_kind := ""
var desired_velocity := Vector2.ZERO
var should_consume_target := false
var should_attack_target := false
var should_flee := false
var events: Array[Dictionary] = []


static func for_behavior(next_behavior: String, reason: String = "") -> CreatureSimulationResult:
	var result := CreatureSimulationResult.new()
	result.behavior = next_behavior
	result.decision_reason = reason
	return result


func to_save_data() -> Dictionary:
	return {
		"behavior": behavior,
		"decision_reason": decision_reason,
		"target_entity_id": target_entity_id,
		"target_position": _vector_to_data(target_position),
		"target_kind": target_kind,
		"desired_velocity": _vector_to_data(desired_velocity),
		"should_consume_target": should_consume_target,
		"should_attack_target": should_attack_target,
		"should_flee": should_flee,
		"events": events.duplicate(true)
	}


func load_from_save_data(data: Dictionary) -> void:
	behavior = str(data.get("behavior", behavior))
	decision_reason = str(data.get("decision_reason", decision_reason))
	target_entity_id = int(data.get("target_entity_id", target_entity_id))
	target_position = _data_to_vector(data.get("target_position", _vector_to_data(target_position)), target_position)
	target_kind = str(data.get("target_kind", target_kind))
	desired_velocity = _data_to_vector(data.get("desired_velocity", _vector_to_data(desired_velocity)), desired_velocity)
	should_consume_target = bool(data.get("should_consume_target", should_consume_target))
	should_attack_target = bool(data.get("should_attack_target", should_attack_target))
	should_flee = bool(data.get("should_flee", should_flee))
	events = Array(data.get("events", events)).duplicate(true)


func add_event(event_name: String, payload: Dictionary = {}) -> void:
	events.append({
		"name": event_name,
		"payload": payload.duplicate(true)
	})


static func _vector_to_data(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


static func _data_to_vector(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if typeof(value) != TYPE_DICTIONARY:
		return fallback
	var data := Dictionary(value)
	return Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y)))
