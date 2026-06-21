extends RefCounted
class_name GodotCreatureAdapter

var node: CharacterBody2D
var species_key := "creature"
var lifecycle_state := "created"
var last_context_data: Dictionary = {}
var last_state_data: Dictionary = {}
var last_decision_data: Dictionary = {}
var last_physics_data: Dictionary = {}
var world: Node
var ecosystem: Node
var debug_panel: Node
var world_query


func bind(p_node: CharacterBody2D) -> void:
	node = p_node
	species_key = _resolve_species_key()


func on_ready() -> void:
	lifecycle_state = "ready"
	last_state_data = snapshot_node_state()


func on_world_context_bound(
	p_world: Node,
	p_ecosystem: Node = null,
	p_debug_panel: Node = null,
	p_world_query = null
) -> void:
	world = p_world
	ecosystem = p_ecosystem
	debug_panel = p_debug_panel
	world_query = p_world_query
	lifecycle_state = "world_bound"
	last_state_data = snapshot_node_state()


func before_physics_tick(delta: float) -> void:
	last_physics_data = {
		"species": species_key,
		"delta": delta,
		"position_before": _vector_to_data(_get_vector("global_position")),
		"velocity_before": _vector_to_data(_get_vector("velocity")),
		"behavior_before": _get_current_behavior_name(),
		"decision_reason_before": str(_get_value("decision_reason", "")),
		"simulation_level": str(_get_value("simulation_level_name", "near")),
		"is_visibility_culled": bool(_get_value("is_visibility_culled", false))
	}


func after_physics_tick(position_before: Vector2, position_after: Vector2, velocity_after: Vector2) -> void:
	last_physics_data["position_before"] = _vector_to_data(position_before)
	last_physics_data["position_after"] = _vector_to_data(position_after)
	last_physics_data["velocity_after"] = _vector_to_data(velocity_after)
	last_physics_data["movement_distance"] = position_before.distance_to(position_after)
	last_physics_data["behavior_after"] = _get_current_behavior_name()
	last_state_data = snapshot_node_state()


func capture_decision_context(context) -> Variant:
	last_context_data = _context_to_dictionary(context)
	return context


func build_context_from_node() -> Dictionary:
	if not _has_node():
		last_context_data = {}
		return last_context_data
	if node.has_method("build_decision_context"):
		var context = node.call("build_decision_context")
		last_context_data = _context_to_dictionary(context)
		return last_context_data
	last_context_data = _build_generic_context()
	return last_context_data


func after_decision_tick(context, decision_reason: String = "") -> void:
	last_context_data = _context_to_dictionary(context)
	last_decision_data = {
		"species": species_key,
		"behavior": _get_current_behavior_name(),
		"decision_reason": decision_reason,
		"context": last_context_data.duplicate(true),
		"position": _vector_to_data(_get_vector("global_position")),
		"velocity": _vector_to_data(_get_vector("velocity")),
		"hunger": float(_get_value("hunger", 0.0)),
		"energy": float(_get_value("energy", 1.0))
	}


func execute_brain_decision(decision: Dictionary) -> void:
	# First adapter stage: keep behavior in existing node scripts, but expose
	# a stable execution seam for future pure-core brain decisions.
	last_decision_data = decision.duplicate(true)
	if not _has_node():
		return
	var next_behavior := str(decision.get("behavior", ""))
	if next_behavior.is_empty():
		return
	if node.has_method("apply_brain_decision"):
		node.call("apply_brain_decision", decision)


func snapshot_node_state() -> Dictionary:
	if not _has_node():
		return {}
	if node.has_method("get_creature_state_data"):
		return Dictionary(node.call("get_creature_state_data"))
	if node.has_method("sync_creature_state_from_node"):
		var state = node.call("sync_creature_state_from_node")
		if state != null and state.has_method("to_save_data"):
			return Dictionary(state.to_save_data())
	return _build_generic_state()


func get_debug_data() -> Dictionary:
	return {
		"adapter": get_script().resource_path,
		"species": species_key,
		"lifecycle_state": lifecycle_state,
		"last_context": last_context_data.duplicate(true),
		"last_state": last_state_data.duplicate(true),
		"last_decision": last_decision_data.duplicate(true),
		"last_physics": last_physics_data.duplicate(true),
		"has_world": is_instance_valid(world),
		"has_world_query": world_query != null
	}


func get_snapshot_summary() -> Dictionary:
	return {
		"adapter": get_script().resource_path,
		"species": species_key,
		"lifecycle_state": lifecycle_state,
		"has_world": is_instance_valid(world),
		"has_world_query": world_query != null
	}


func _build_generic_context() -> Dictionary:
	return {
		"species": species_key,
		"position": _vector_to_data(_get_vector("global_position")),
		"velocity": _vector_to_data(_get_vector("velocity")),
		"current_behavior": _get_current_behavior_name(),
		"decision_reason": str(_get_value("decision_reason", "")),
		"hunger": float(_get_value("hunger", 0.0)),
		"energy": float(_get_value("energy", 1.0)),
		"current_biome": str(_get_value("biome_id", _get_value("population_biome_id", ""))),
		"home_biome": str(_get_value("home_biome_id", "")),
		"population_biome": str(_get_value("population_biome_id", ""))
	}


func _build_generic_state() -> Dictionary:
	return {
		"species_id": str(_get_value("species_id", species_key)),
		"species_name": str(_get_value("species_name", species_key)),
		"position": _vector_to_data(_get_vector("global_position")),
		"velocity": _vector_to_data(_get_vector("velocity")),
		"health": float(_get_value("health", 0.0)),
		"max_health": float(_get_value("max_health", 0.0)),
		"hunger": float(_get_value("hunger", 0.0)),
		"energy": float(_get_value("energy", 1.0)),
		"behavior": _get_current_behavior_name(),
		"decision_reason": str(_get_value("decision_reason", ""))
	}


func _context_to_dictionary(context) -> Dictionary:
	if context == null:
		return {}
	if typeof(context) == TYPE_DICTIONARY:
		return Dictionary(context).duplicate(true)
	if context.has_method("to_dictionary"):
		return Dictionary(context.to_dictionary())
	return _build_generic_context()


func _resolve_species_key() -> String:
	if not _has_node():
		return species_key
	var explicit_species := str(_get_value("species_id", ""))
	if not explicit_species.is_empty():
		return explicit_species
	return node.name.to_snake_case()


func _get_current_behavior_name() -> String:
	if not _has_node():
		return ""
	if node.has_method("get_debug_ai_state"):
		return str(node.call("get_debug_ai_state"))
	var state_value = _get_value("state", null)
	if state_value == null:
		return ""
	return str(state_value)


func _get_value(property_name: String, fallback: Variant = null) -> Variant:
	if not _has_node():
		return fallback
	var value = node.get(property_name)
	if value == null:
		return fallback
	return value


func _get_vector(property_name: String) -> Vector2:
	var value = _get_value(property_name, Vector2.ZERO)
	if typeof(value) == TYPE_VECTOR2:
		return value
	return Vector2.ZERO


func _vector_to_data(value: Vector2) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y
	}


func _has_node() -> bool:
	return is_instance_valid(node)
