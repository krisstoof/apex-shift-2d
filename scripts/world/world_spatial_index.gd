extends "res://scripts/core/spatial/world_spatial_index.gd"

var _node_refs_by_id: Dictionary = {}
var _node_ids_by_instance_id: Dictionary = {}


func register_entity(entity: Node, category: String = "", type_name: String = "") -> void:
	if not _is_live_node_2d(entity):
		return
	var entity_id := entity.get_instance_id()
	var metadata := {
		"type": type_name,
		"kind": type_name,
		"payload": entity,
		"node_ref": weakref(entity),
		"instance_id": entity_id
	}
	_node_refs_by_id[entity_id] = weakref(entity)
	_node_ids_by_instance_id[entity_id] = entity_id
	super.register_entity(entity_id, _get_entity_position(entity), category, metadata)


func unregister_entity(entity: Node) -> void:
	if entity == null or not is_instance_valid(entity):
		return
	unregister_entity_by_id(entity.get_instance_id())


func unregister_entity_by_id(instance_id: int) -> void:
	super.unregister_entity(instance_id)
	_node_refs_by_id.erase(instance_id)
	_node_ids_by_instance_id.erase(instance_id)


func update_entity_cell(entity: Node) -> void:
	if not _is_live_node_2d(entity):
		return
	var entity_id := entity.get_instance_id()
	if not has_entity_id(entity_id):
		return
	update_entity_position(entity_id, _get_entity_position(entity))


func has_entity(entity: Node) -> bool:
	return entity != null and is_instance_valid(entity) and has_entity_id(entity.get_instance_id())


func get_entity_cell(entity: Node) -> Vector2i:
	if entity == null or not is_instance_valid(entity):
		return Vector2i(-1, -1)
	return get_entity_cell_by_id(entity.get_instance_id())


func query_near(position: Vector2, radius: float, category: String = "", type_filter: Variant = null) -> Array:
	return _results_to_live_nodes(query_circle(position, radius, category, type_filter))


func query_resources_near(position: Vector2, radius: float, kind_filter: Variant = null) -> Array:
	return query_near(position, radius, "resource", kind_filter)


func query_creatures_near(position: Vector2, radius: float, creature_type_filter: Variant = null) -> Array:
	return query_near(position, radius, "creature", creature_type_filter)


func query_meat_near(position: Vector2, radius: float) -> Array:
	return query_near(position, radius, "meat")


func query_rect(rect: Rect2, category: String = "", type_filter: Variant = null) -> Array:
	return _results_to_live_nodes(super.query_rect(rect, category, type_filter))


func query_resources_in_rect(rect: Rect2, kind_filter: Variant = null) -> Array:
	return query_rect(rect, "resource", kind_filter)


func query_creatures_in_rect(rect: Rect2, creature_type_filter: Variant = null) -> Array:
	return query_rect(rect, "creature", creature_type_filter)


func query_meat_in_rect(rect: Rect2) -> Array:
	return query_rect(rect, "meat")


func cleanup_stale_entries() -> Dictionary:
	var removed := 0
	for entity_id in entity_records.keys():
		var record := Dictionary(entity_records.get(entity_id, {}))
		var metadata := Dictionary(record.get("metadata", {}))
		var node_ref := metadata.get("node_ref", null) as WeakRef
		var node := node_ref.get_ref() if node_ref != null else null
		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
			unregister_entity_by_id(entity_id)
			removed += 1
	stale_entries_removed_last_cleanup = removed
	return {"removed": removed, "stale_tracked_removed": removed, "empty_buckets_removed": 0}


func clear() -> void:
	super.clear()
	_node_refs_by_id.clear()
	_node_ids_by_instance_id.clear()


func get_debug_counts() -> Dictionary:
	var debug := super.get_debug_counts()
	var stale_count := 0
	var live_count := 0
	for entity_id in entity_records.keys():
		var record := Dictionary(entity_records.get(entity_id, {}))
		var metadata := Dictionary(record.get("metadata", {}))
		var node_ref := metadata.get("node_ref", null) as WeakRef
		var node := node_ref.get_ref() if node_ref != null else null
		if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
			live_count += 1
		else:
			stale_count += 1
	debug["tracked_live_entities"] = live_count
	debug["tracked_stale_entities"] = stale_count
	debug["stale_entries_removed_last_cleanup"] = stale_entries_removed_last_cleanup
	return debug


func get_debug_data() -> Dictionary:
	return get_debug_counts()


func _results_to_live_nodes(results: Array) -> Array:
	var nodes: Array = []
	for result in results:
		var metadata := Dictionary(result.metadata)
		var node := metadata.get("payload", null)
		var node_ref := metadata.get("node_ref", null) as WeakRef
		if node == null and node_ref != null:
			node = node_ref.get_ref()
		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		nodes.append(node)
	return nodes


func _get_entity_position(entity: Node) -> Vector2:
	var node_2d := entity as Node2D
	return node_2d.global_position if node_2d != null else Vector2.INF


func _is_live_node_2d(entity: Node) -> bool:
	return entity != null and is_instance_valid(entity) and not entity.is_queued_for_deletion() and entity is Node2D
