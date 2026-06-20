extends RefCounted
class_name CreatureState

const CREATURE_STATS := preload("res://scripts/core/creatures/creature_stats.gd")
const CREATURE_NEEDS := preload("res://scripts/core/creatures/creature_needs.gd")
const CREATURE_MEMORY := preload("res://scripts/core/creatures/creature_memory.gd")
const CREATURE_SIMULATION_RESULT := preload("res://scripts/core/creatures/creature_simulation_result.gd")

var entity_id := 0
var creature_type := ""
var species_id := ""
var species_name := ""
var generation := 1

var position := Vector2.ZERO
var facing_angle := 0.0
var facing_side := 1.0
var velocity := Vector2.ZERO

var stats: CreatureStats = CREATURE_STATS.new()
var needs: CreatureNeeds = CREATURE_NEEDS.new()
var memory: CreatureMemory = CREATURE_MEMORY.new()

var lod_state := "near"
var is_visibility_culled := false
var is_background_simulated := false
var is_dead := false

var custom_data: Dictionary = {}


func duplicate_state() -> CreatureState:
	var copy := CreatureState.new()
	copy.load_from_save_data(to_save_data())
	return copy


func tick_needs(delta: float, movement_intensity: float = 0.0) -> CreatureSimulationResult:
	needs.tick(delta, movement_intensity)
	memory.age_seconds += maxf(delta, 0.0)
	return decide_next_behavior({})


func decide_next_behavior(context: Dictionary = {}) -> CreatureSimulationResult:
	if is_dead or stats.health <= 0.0:
		memory.set_behavior("dead", "dead")
		return CREATURE_SIMULATION_RESULT.for_behavior("dead", "dead")

	var result := CREATURE_SIMULATION_RESULT.for_behavior(memory.current_behavior, memory.decision_reason)
	result.target_entity_id = memory.target_entity_id
	result.target_position = memory.target_position
	result.target_kind = memory.target_kind
	return result


func apply_simulation_result(result: CreatureSimulationResult) -> void:
	if result == null:
		return
	if not result.behavior.is_empty():
		memory.set_behavior(result.behavior, result.decision_reason)
	if result.target_entity_id != 0:
		memory.set_target(result.target_entity_id, result.target_position, result.target_kind)


func to_save_data() -> Dictionary:
	return {
		"entity_id": entity_id,
		"creature_type": creature_type,
		"species_id": species_id,
		"species_name": species_name,
		"generation": generation,
		"position": _vector_to_data(position),
		"facing_angle": facing_angle,
		"facing_side": facing_side,
		"velocity": _vector_to_data(velocity),
		"stats": stats.to_save_data(),
		"needs": needs.to_save_data(),
		"memory": memory.to_save_data(),
		"lod_state": lod_state,
		"is_visibility_culled": is_visibility_culled,
		"is_background_simulated": is_background_simulated,
		"is_dead": is_dead,
		"custom_data": custom_data.duplicate(true)
	}


func load_from_save_data(data: Dictionary) -> void:
	entity_id = int(data.get("entity_id", entity_id))
	creature_type = str(data.get("creature_type", creature_type))
	species_id = str(data.get("species_id", species_id))
	species_name = str(data.get("species_name", species_name))
	generation = max(int(data.get("generation", generation)), 1)
	position = _data_to_vector(data.get("position", _vector_to_data(position)), position)
	facing_angle = _safe_float(data, "facing_angle", facing_angle)
	facing_side = _safe_float(data, "facing_side", facing_side)
	velocity = _data_to_vector(data.get("velocity", _vector_to_data(velocity)), velocity)
	stats.load_from_save_data(Dictionary(data.get("stats", {})))
	needs.load_from_save_data(Dictionary(data.get("needs", {})))
	memory.load_from_save_data(Dictionary(data.get("memory", {})))
	lod_state = str(data.get("lod_state", lod_state))
	is_visibility_culled = bool(data.get("is_visibility_culled", is_visibility_culled))
	is_background_simulated = bool(data.get("is_background_simulated", is_background_simulated))
	is_dead = bool(data.get("is_dead", is_dead))
	custom_data = Dictionary(data.get("custom_data", custom_data)).duplicate(true)


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
