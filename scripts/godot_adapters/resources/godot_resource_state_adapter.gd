extends RefCounted
class_name GodotResourceStateAdapter

const ResourceState := preload("res://scripts/core/resources/resource_state.gd")


func from_node(resource_node: Node) -> ResourceState:
	var state := ResourceState.new()
	if resource_node == null or not is_instance_valid(resource_node):
		return state
	state.id = _get_or_create_resource_id(resource_node)
	state.kind = _read_string(resource_node, "resource_kind", _read_string(resource_node, "kind", ""))
	state.position = _read_position(resource_node)
	state.biome_id = _read_biome_id(resource_node)
	state.amount = _read_int(resource_node, "amount", 1)
	state.max_amount = _read_int(resource_node, "max_amount", max(state.amount, 1))
	state.growth_stage = _read_int(resource_node, "growth_stage", 0)
	state.max_growth_stage = _read_int(resource_node, "max_growth_stage", 3)
	state.depleted = _read_bool(resource_node, "depleted", false)
	state.regrowth_progress_days = _read_float(resource_node, "regrowth_progress_days", 0.0)
	state.days_per_growth_stage = _read_float(resource_node, "days_per_growth_stage", 1.0)
	return state


func apply_to_node(resource_node: Node, state: ResourceState) -> void:
	if resource_node == null or state == null or not is_instance_valid(resource_node):
		return
	if resource_node is Node2D:
		(resource_node as Node2D).global_position = state.position
	resource_node.set_meta("entity_id", state.id)
	if not state.biome_id.is_empty():
		resource_node.set_meta("biome_id", state.biome_id)
	_write_property_if_exists(resource_node, "resource_kind", state.kind)
	_write_property_if_exists(resource_node, "kind", state.kind)
	_write_property_if_exists(resource_node, "amount", state.amount)
	_write_property_if_exists(resource_node, "max_amount", state.max_amount)
	_write_property_if_exists(resource_node, "growth_stage", state.growth_stage)
	_write_property_if_exists(resource_node, "max_growth_stage", state.max_growth_stage)
	_write_property_if_exists(resource_node, "depleted", state.depleted)
	_write_property_if_exists(resource_node, "regrowth_progress_days", state.regrowth_progress_days)
	_write_property_if_exists(resource_node, "days_per_growth_stage", state.days_per_growth_stage)
	if resource_node.has_method("refresh_visual_state"):
		resource_node.refresh_visual_state()
	elif resource_node.has_method("update_visual_state"):
		resource_node.update_visual_state()


func build_states_from_nodes(resource_nodes: Array) -> Array:
	var states: Array = []
	for node_value in resource_nodes:
		var node := node_value as Node
		if node == null or not is_instance_valid(node):
			continue
		var state := from_node(node)
		if state.is_empty():
			continue
		states.append(state)
	return states


func apply_states_to_nodes(states: Array, resource_nodes: Array) -> int:
	var nodes_by_id := {}
	for node_value in resource_nodes:
		var node := node_value as Node
		if node == null or not is_instance_valid(node):
			continue
		var id := _get_or_create_resource_id(node)
		if id.is_empty():
			continue
		nodes_by_id[id] = node
	var changed_count := 0
	for state_value in states:
		var state := state_value as ResourceState
		if state == null:
			continue
		var node: Variant = nodes_by_id.get(state.id, null)
		if node == null or not is_instance_valid(node):
			continue
		apply_to_node(node, state)
		changed_count += 1
	return changed_count


func _get_or_create_resource_id(resource_node: Node) -> String:
	if resource_node.has_meta("entity_id"):
		return str(resource_node.get_meta("entity_id"))
	if resource_node.has_meta("resource_id"):
		var saved_id := str(resource_node.get_meta("resource_id"))
		if not saved_id.is_empty():
			resource_node.set_meta("entity_id", saved_id)
			return saved_id
	var id := "%s_%d" % [resource_node.name, resource_node.get_instance_id()]
	resource_node.set_meta("entity_id", id)
	return id


func _read_position(resource_node: Node) -> Vector2:
	if resource_node is Node2D:
		return (resource_node as Node2D).global_position
	return Vector2.ZERO


func _read_biome_id(resource_node: Node) -> String:
	if resource_node.has_meta("biome_id"):
		return str(resource_node.get_meta("biome_id"))
	if _has_property(resource_node, "biome_id"):
		return str(resource_node.get("biome_id"))
	return ""


func _read_string(node: Node, property_name: String, default_value: String = "") -> String:
	return str(node.get(property_name)) if _has_property(node, property_name) else default_value


func _read_int(node: Node, property_name: String, default_value: int = 0) -> int:
	return int(node.get(property_name)) if _has_property(node, property_name) else default_value


func _read_float(node: Node, property_name: String, default_value: float = 0.0) -> float:
	return float(node.get(property_name)) if _has_property(node, property_name) else default_value


func _read_bool(node: Node, property_name: String, default_value: bool = false) -> bool:
	return bool(node.get(property_name)) if _has_property(node, property_name) else default_value


func _write_property_if_exists(node: Node, property_name: String, value: Variant) -> void:
	if _has_property(node, property_name):
		node.set(property_name, value)


func _has_property(node: Object, property_name: String) -> bool:
	if node == null:
		return false
	for property_data in node.get_property_list():
		var data := Dictionary(property_data)
		if str(data.get("name", "")) == property_name:
			return true
	return false
