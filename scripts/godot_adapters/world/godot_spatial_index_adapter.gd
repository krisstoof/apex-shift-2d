extends RefCounted
class_name GodotSpatialIndexAdapter

const CORE_WORLD_SPATIAL_INDEX := preload("res://scripts/core/spatial/world_spatial_index.gd")

var core_index := CORE_WORLD_SPATIAL_INDEX.new()
var node_by_entity_id: Dictionary = {}
var entity_id_by_instance_id: Dictionary = {}


func clear() -> void:
	core_index.clear()
	node_by_entity_id.clear()
	entity_id_by_instance_id.clear()


func register_entity(entity_id: Variant, position: Vector2, category: String, metadata: Dictionary = {}) -> void:
	if entity_id == null or category.is_empty():
		return
	core_index.register_entity(entity_id, position, category, metadata)


func unregister_entity(entity_id: Variant) -> void:
	core_index.unregister_entity(entity_id)
	node_by_entity_id.erase(entity_id)
	entity_id_by_instance_id.erase(entity_id)


func update_entity_position(entity_id: Variant, position: Vector2) -> void:
	core_index.update_entity_position(entity_id, position)


func update_entity_metadata(entity_id: Variant, metadata: Dictionary) -> void:
	core_index.update_entity_metadata(entity_id, metadata)


func has_entity_id(entity_id: Variant) -> bool:
	return core_index.has_entity_id(entity_id)


func get_entity_cell_by_id(entity_id: Variant) -> Vector2i:
	return core_index.get_entity_cell_by_id(entity_id)


func register_node(node: Node, category: String, type_name: String) -> String:
	if not _is_valid_spatial_node(node):
		return ""
	var entity_id := _make_entity_id(node)
	var node_2d := node as Node2D
	node_by_entity_id[entity_id] = node
	entity_id_by_instance_id[node.get_instance_id()] = entity_id
	core_index.register_entity(entity_id, node_2d.global_position, category, {"type": type_name, "kind": type_name, "payload": node, "node_ref": weakref(node), "instance_id": node.get_instance_id()})
	return entity_id


func unregister_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var instance_id := node.get_instance_id()
	var entity_id := str(entity_id_by_instance_id.get(instance_id, ""))
	if entity_id.is_empty():
		return
	core_index.unregister_entity(entity_id)
	node_by_entity_id.erase(entity_id)
	entity_id_by_instance_id.erase(instance_id)


func update_node_position(node: Node) -> void:
	if not _is_valid_spatial_node(node):
		return
	var instance_id := node.get_instance_id()
	var entity_id := str(entity_id_by_instance_id.get(instance_id, ""))
	if entity_id.is_empty():
		return
	core_index.update_entity_position(entity_id, (node as Node2D).global_position)


func query_nodes_near(position: Vector2, radius: float, category: String = "", type_filter: Variant = null) -> Array:
	return _resolve_nodes(core_index.query_circle(position, radius, category, type_filter))


func query_nodes_in_rect(rect: Rect2, category: String = "", type_filter: Variant = null) -> Array:
	return _resolve_nodes(core_index.query_rect(rect, category, type_filter))


func query_resources_near(position: Vector2, radius: float, kind_filter: Variant = null) -> Array:
	return query_nodes_near(position, radius, "resource", kind_filter)


func query_creatures_near(position: Vector2, radius: float, creature_type_filter: Variant = null) -> Array:
	return query_nodes_near(position, radius, "creature", creature_type_filter)


func query_meat_near(position: Vector2, radius: float) -> Array:
	return query_nodes_near(position, radius, "meat")


func query_resources_in_rect(rect: Rect2, kind_filter: Variant = null) -> Array:
	return query_nodes_in_rect(rect, "resource", kind_filter)


func query_creatures_in_rect(rect: Rect2, creature_type_filter: Variant = null) -> Array:
	return query_nodes_in_rect(rect, "creature", creature_type_filter)


func query_meat_in_rect(rect: Rect2) -> Array:
	return query_nodes_in_rect(rect, "meat")


func get_debug_counts() -> Dictionary:
	var debug := core_index.get_debug_counts()
	debug["tracked_nodes"] = node_by_entity_id.size()
	return debug


func get_debug_data() -> Dictionary:
	return get_debug_counts()


func _resolve_nodes(results: Array) -> Array:
	var nodes: Array = []
	for result in results:
		var entity_id: Variant = null
		if result is Dictionary:
			entity_id = Dictionary(result).get("entity_id", null)
		elif result != null and result.has_method("get"):
			entity_id = result.get("entity_id")
		var node: Variant = node_by_entity_id.get(entity_id, null)
		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		nodes.append(node)
	return nodes


func _make_entity_id(node: Node) -> String:
	if node.has_meta("entity_id"):
		return str(node.get_meta("entity_id"))
	var entity_id := "%s_%d" % [node.name, node.get_instance_id()]
	node.set_meta("entity_id", entity_id)
	return entity_id


func _is_valid_spatial_node(node: Node) -> bool:
	return node != null and is_instance_valid(node) and not node.is_queued_for_deletion() and node is Node2D
