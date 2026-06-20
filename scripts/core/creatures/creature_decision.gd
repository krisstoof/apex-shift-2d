extends RefCounted
class_name CreatureDecision

const ACTION_WANDER := "wander"
const ACTION_FLEE := "flee"
const ACTION_SEEK_FOOD := "seek_food"
const ACTION_EAT := "eat"
const ACTION_HUNT := "hunt"
const ACTION_AVOID_BUILDING := "avoid_building"
const ACTION_AVOID_WATER := "avoid_water"
const ACTION_RETURN_TO_BIOME := "return_to_biome"
const ACTION_REST := "rest"
const VALID_ACTIONS := [
	ACTION_WANDER,
	ACTION_FLEE,
	ACTION_SEEK_FOOD,
	ACTION_EAT,
	ACTION_HUNT,
	ACTION_AVOID_BUILDING,
	ACTION_AVOID_WATER,
	ACTION_RETURN_TO_BIOME,
	ACTION_REST
]

var action := ACTION_WANDER
var reason := ""
var target_position := Vector2.ZERO
var target_entity_id := 0
var target_kind := ""
var priority := 0.0
var duration := 0.0
var metadata: Dictionary = {}


func _init(
	p_action: String = ACTION_WANDER,
	p_reason: String = "",
	p_target_position: Vector2 = Vector2.ZERO,
	p_target_entity_id: int = 0,
	p_target_kind: String = "",
	p_metadata: Dictionary = {}
) -> void:
	action = _normalize_action(p_action)
	reason = p_reason
	target_position = p_target_position
	target_entity_id = p_target_entity_id
	target_kind = p_target_kind
	metadata = p_metadata.duplicate(true)
	priority = float(metadata.get("priority", priority))
	duration = float(metadata.get("duration", duration))


static func for_action(
	p_action: String,
	p_reason: String = "",
	p_target_position: Vector2 = Vector2.ZERO,
	p_target_entity_id: int = 0,
	p_target_kind: String = "",
	p_metadata: Dictionary = {}
) -> CreatureDecision:
	return CreatureDecision.new(p_action, p_reason, p_target_position, p_target_entity_id, p_target_kind, p_metadata)


func duplicate_decision() -> CreatureDecision:
	var copy := CreatureDecision.new(action, reason, target_position, target_entity_id, target_kind, metadata)
	copy.priority = priority
	copy.duration = duration
	return copy


func is_action(expected_action: String) -> bool:
	return action == expected_action


func has_target() -> bool:
	return target_entity_id != 0 or target_position != Vector2.ZERO or not target_kind.is_empty()


func to_dictionary() -> Dictionary:
	return {
		"action": action,
		"reason": reason,
		"target_position": _vector_to_data(target_position),
		"target_entity_id": target_entity_id,
		"target_kind": target_kind,
		"priority": priority,
		"duration": duration,
		"metadata": metadata.duplicate(true)
	}


func load_from_dictionary(data: Dictionary) -> void:
	action = _normalize_action(str(data.get("action", action)))
	reason = str(data.get("reason", reason))
	target_position = _data_to_vector(data.get("target_position", _vector_to_data(target_position)), target_position)
	target_entity_id = int(data.get("target_entity_id", target_entity_id))
	target_kind = str(data.get("target_kind", target_kind))
	priority = float(data.get("priority", priority))
	duration = float(data.get("duration", duration))
	metadata = Dictionary(data.get("metadata", metadata)).duplicate(true)


static func _normalize_action(value: String) -> String:
	return value if VALID_ACTIONS.has(value) else ACTION_WANDER


static func _vector_to_data(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


static func _data_to_vector(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if typeof(value) != TYPE_DICTIONARY:
		return fallback
	var data := Dictionary(value)
	return Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y)))
