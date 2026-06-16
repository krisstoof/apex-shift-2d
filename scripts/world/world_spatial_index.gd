extends RefCounted
class_name WorldSpatialIndex

var cell_size := 256.0
var resources_by_cell: Dictionary = {}
var creatures_by_cell: Dictionary = {}
var meat_by_cell: Dictionary = {}
var entity_cells: Dictionary = {}
var entity_categories: Dictionary = {}
var entity_types: Dictionary = {}
var tracked_entities: Dictionary = {}
var stale_entries_removed_last_cleanup := 0


func register_entity(entity: Node, category: String = "", type_name: String = "") -> void:
	if not _is_supported_category(category):
		return
	if not _is_live_entity(entity):
		return
	var instance_id := entity.get_instance_id()
	unregister_entity_by_id(instance_id)
	var cell := _get_cell_for_position(_get_entity_position(entity))
	entity_cells[instance_id] = cell
	entity_categories[instance_id] = category
	entity_types[instance_id] = type_name
	tracked_entities[instance_id] = {
		"ref": weakref(entity),
		"category": category,
		"cell": cell,
		"kind": type_name
	}
	_add_entity_to_cell(entity, category, cell)


func unregister_entity(entity: Node) -> void:
	if entity == null:
		return
	if not is_instance_valid(entity):
		return
	unregister_entity_by_id(entity.get_instance_id())


func unregister_entity_by_id(instance_id: int) -> void:
	if not tracked_entities.has(instance_id):
		_cleanup_stale_entity(instance_id)
		return
	var entry := Dictionary(tracked_entities.get(instance_id, {}))
	var category := str(entry.get("category", ""))
	var cell_value: Variant = entry.get("cell", Vector2i(-1, -1))
	if cell_value is Vector2i:
		_remove_instance_from_bucket(category, Vector2i(cell_value), instance_id)
	tracked_entities.erase(instance_id)
	_cleanup_stale_entity(instance_id)


func update_entity_cell(entity: Node) -> void:
	if not _is_live_entity(entity):
		return
	var instance_id := entity.get_instance_id()
	if not entity_cells.has(instance_id):
		return
	var current_cell_value: Variant = entity_cells.get(instance_id, null)
	if not (current_cell_value is Vector2i):
		return
	var current_cell := Vector2i(current_cell_value)
	var next_cell := _get_cell_for_position(_get_entity_position(entity))
	if next_cell == current_cell:
		return
	var category := str(entity_categories.get(instance_id, ""))
	if not _is_supported_category(category):
		return
	_remove_instance_from_bucket(category, current_cell, instance_id)
	_add_entity_to_cell(entity, category, next_cell)
	entity_cells[instance_id] = next_cell
	if tracked_entities.has(instance_id):
		var tracked_entry := Dictionary(tracked_entities.get(instance_id, {}))
		tracked_entry["cell"] = next_cell
		tracked_entities[instance_id] = tracked_entry


func cleanup_bucket(category: String, cell: Vector2i) -> int:
	if not _is_supported_category(category):
		return 0
	var cells := _get_cells_for_category(category)
	if not cells.has(cell):
		return 0
	var bucket: Array = Array(cells[cell])
	var cleaned_bucket: Array = []
	var seen_ids: Dictionary = {}
	var removed := 0
	for entity_value in bucket:
		if entity_value == null:
			removed += 1
			continue
		if not is_instance_valid(entity_value):
			removed += 1
			continue
		var entity := entity_value as Node
		if entity == null or entity.is_queued_for_deletion():
			removed += 1
			continue
		var instance_id := entity.get_instance_id()
		if seen_ids.has(instance_id):
			removed += 1
			continue
		seen_ids[instance_id] = true
		cleaned_bucket.append(entity)
		var tracked_entry: Variant = tracked_entities.get(instance_id, null)
		if tracked_entry is Dictionary:
			var entry_dict := Dictionary(tracked_entry)
			entry_dict["ref"] = weakref(entity)
			entry_dict["category"] = category
			entry_dict["cell"] = cell
			tracked_entities[instance_id] = entry_dict
		else:
			tracked_entities[instance_id] = {
				"ref": weakref(entity),
				"category": category,
				"cell": cell,
				"kind": str(entity_types.get(instance_id, ""))
			}
	if cleaned_bucket.is_empty():
		cells.erase(cell)
	else:
		cells[cell] = cleaned_bucket
	stale_entries_removed_last_cleanup = removed
	return removed


func cleanup_stale_entries() -> Dictionary:
	var removed := 0
	var stale_tracked_removed := 0
	var empty_buckets_removed := 0
	var categories := {
		"resource": resources_by_cell,
		"creature": creatures_by_cell,
		"meat": meat_by_cell
	}
	for category in categories.keys():
		var cells: Dictionary = categories[category]
		var cell_keys := cells.keys()
		for cell_value in cell_keys:
			if not (cell_value is Vector2i):
				continue
			var cell := Vector2i(cell_value)
			var before_has_cell := cells.has(cell)
			var cleaned := cleanup_bucket(str(category), cell)
			removed += cleaned
			if before_has_cell and not cells.has(cell):
				empty_buckets_removed += 1
	var tracked_ids := tracked_entities.keys()
	for instance_id in tracked_ids:
		var tracked_entry: Variant = tracked_entities.get(instance_id, null)
		if tracked_entry is Dictionary:
			var ref_value: Variant = Dictionary(tracked_entry).get("ref", null)
			var tracked_ref := ref_value as WeakRef
			if tracked_ref == null or tracked_ref.get_ref() == null:
				stale_tracked_removed += 1
				_cleanup_stale_entity(instance_id)
	stale_entries_removed_last_cleanup = removed
	return {
		"removed": removed,
		"stale_tracked_removed": stale_tracked_removed,
		"empty_buckets_removed": empty_buckets_removed
	}


func query_near(position: Vector2, radius: float, category: String = "", type_filter: Variant = null) -> Array:
	if radius <= 0.0:
		return []
	if not _is_supported_category(category):
		return []
	var min_cell_x := floori((position.x - radius) / cell_size)
	var max_cell_x := floori((position.x + radius) / cell_size)
	var min_cell_y := floori((position.y - radius) / cell_size)
	var max_cell_y := floori((position.y + radius) / cell_size)
	var radius_squared := radius * radius
	var cells := _get_cells_for_category(category)
	var results: Array = []
	var touched_cells: Dictionary = {}
	for cell_x in range(min_cell_x, max_cell_x + 1):
		for cell_y in range(min_cell_y, max_cell_y + 1):
			var cell := Vector2i(cell_x, cell_y)
			if not cells.has(cell):
				continue
			touched_cells[cell] = true
			for entity_value in Array(cells[cell]):
				if entity_value == null:
					continue
				if not is_instance_valid(entity_value):
					continue
				var entity := entity_value as Node
				if not _is_live_entity(entity):
					continue
				if not _matches_type_filter(entity, type_filter):
					continue
				var entity_position := _get_entity_position(entity)
				if entity_position.distance_squared_to(position) <= radius_squared:
					results.append(entity)
	for cell_value in touched_cells.keys():
		cleanup_bucket(category, Vector2i(cell_value))
	return results


func query_resources_near(position: Vector2, radius: float, kind_filter: Variant = null) -> Array:
	return query_near(position, radius, "resource", kind_filter)


func query_creatures_near(position: Vector2, radius: float, creature_type_filter: Variant = null) -> Array:
	return query_near(position, radius, "creature", creature_type_filter)


func query_meat_near(position: Vector2, radius: float) -> Array:
	return query_near(position, radius, "meat")


func query_rect(rect: Rect2, category: String = "", type_filter: Variant = null) -> Array:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return []
	if not _is_supported_category(category):
		return []
	var min_cell_x := floori(rect.position.x / cell_size)
	var max_cell_x := floori(rect.end.x / cell_size)
	var min_cell_y := floori(rect.position.y / cell_size)
	var max_cell_y := floori(rect.end.y / cell_size)
	var cells := _get_cells_for_category(category)
	var results: Array = []
	for cell_x in range(min_cell_x, max_cell_x + 1):
		for cell_y in range(min_cell_y, max_cell_y + 1):
			var cell := Vector2i(cell_x, cell_y)
			if not cells.has(cell):
				continue
			cleanup_bucket(category, cell)
			var bucket: Array = Array(cells[cell])
			for entity_value in bucket:
				if entity_value == null:
					continue
				if not is_instance_valid(entity_value):
					continue
				var entity := entity_value as Node
				if not _is_live_entity(entity):
					continue
				if not _matches_type_filter(entity, type_filter):
					continue
				var entity_position := _get_entity_position(entity)
				if rect.has_point(entity_position):
					results.append(entity)
	return results


func query_resources_in_rect(rect: Rect2, kind_filter: Variant = null) -> Array:
	return query_rect(rect, "resource", kind_filter)


func query_creatures_in_rect(rect: Rect2, creature_type_filter: Variant = null) -> Array:
	return query_rect(rect, "creature", creature_type_filter)


func query_meat_in_rect(rect: Rect2) -> Array:
	return query_rect(rect, "meat")


func clear() -> void:
	resources_by_cell.clear()
	creatures_by_cell.clear()
	meat_by_cell.clear()
	entity_cells.clear()
	entity_categories.clear()
	entity_types.clear()
	tracked_entities.clear()
	stale_entries_removed_last_cleanup = 0


func has_entity(entity: Node) -> bool:
	if entity == null or not is_instance_valid(entity):
		return false
	return entity_cells.has(entity.get_instance_id())


func get_entity_cell(entity: Node) -> Vector2i:
	if entity == null or not is_instance_valid(entity):
		return Vector2i(-1, -1)
	var cell_value: Variant = entity_cells.get(entity.get_instance_id(), Vector2i(-1, -1))
	if cell_value is Vector2i:
		return Vector2i(cell_value)
	return Vector2i(-1, -1)


func get_debug_counts() -> Dictionary:
	var live_count := 0
	var stale_count := 0
	for instance_id in tracked_entities.keys():
		var tracked_entry: Variant = tracked_entities.get(instance_id, null)
		if tracked_entry is Dictionary:
			var ref_value: Variant = Dictionary(tracked_entry).get("ref", null)
			var tracked_ref := ref_value as WeakRef
			var live_entity: Variant = tracked_ref.get_ref() if tracked_ref != null else null
			if live_entity != null and is_instance_valid(live_entity) and not live_entity.is_queued_for_deletion():
				live_count += 1
			else:
				stale_count += 1
		else:
			stale_count += 1
	var resources_total := 0
	var creatures_total := 0
	var meat_total := 0
	for cell in resources_by_cell.values():
		resources_total += _count_live_bucket(Array(cell))
	for cell in creatures_by_cell.values():
		creatures_total += _count_live_bucket(Array(cell))
	for cell in meat_by_cell.values():
		meat_total += _count_live_bucket(Array(cell))
	return {
		"resource_cells": resources_by_cell.size(),
		"creature_cells": creatures_by_cell.size(),
		"meat_cells": meat_by_cell.size(),
		"tracked_entities": tracked_entities.size(),
		"tracked_live_entities": live_count,
		"tracked_stale_entities": stale_count,
		"stale_entries_removed_last_cleanup": stale_entries_removed_last_cleanup,
		"resources_total": resources_total,
		"creatures_total": creatures_total,
		"meat_total": meat_total
	}


func get_debug_data() -> Dictionary:
	return get_debug_counts()


func _is_supported_category(category: String) -> bool:
	return category == "resource" or category == "creature" or category == "meat"


func _get_cells_for_category(category: String) -> Dictionary:
	match category:
		"resource":
			return resources_by_cell
		"creature":
			return creatures_by_cell
		"meat":
			return meat_by_cell
		_:
			return {}


func _count_live_bucket(bucket: Array) -> int:
	var count := 0
	for entity_value in bucket:
		if entity_value == null:
			continue
		if not is_instance_valid(entity_value):
			continue
		var entity := entity_value as Node
		if entity == null or entity.is_queued_for_deletion():
			continue
		count += 1
	return count


func _add_entity_to_cell(entity: Node, category: String, cell: Vector2i) -> void:
	if not _is_supported_category(category):
		return
	if not _is_live_entity(entity):
		return
	var cells := _get_cells_for_category(category)
	if not cells.has(cell):
		cells[cell] = []
	var bucket: Array = Array(cells[cell])
	if entity not in bucket:
		bucket.append(entity)
		cells[cell] = bucket


func _remove_entity_from_cell(entity: Node, category: String, cell: Vector2i) -> void:
	if not _is_supported_category(category):
		return
	var cells := _get_cells_for_category(category)
	if not cells.has(cell):
		return
	var bucket: Array = Array(cells[cell])
	for index in range(bucket.size() - 1, -1, -1):
		var bucket_entity_value: Variant = bucket[index]
		if bucket_entity_value == null:
			bucket.remove_at(index)
			continue
		if not is_instance_valid(bucket_entity_value):
			bucket.remove_at(index)
			continue
		var bucket_entity := bucket_entity_value as Node
		if bucket_entity == entity or bucket_entity == null or bucket_entity.is_queued_for_deletion():
			bucket.remove_at(index)
	if bucket.is_empty():
		cells.erase(cell)
	else:
		cells[cell] = bucket


func _remove_instance_from_bucket(category: String, cell: Vector2i, instance_id: int) -> void:
	if not _is_supported_category(category):
		return
	var cells := _get_cells_for_category(category)
	if not cells.has(cell):
		return
	var bucket: Array = Array(cells[cell])
	for index in range(bucket.size() - 1, -1, -1):
		var bucket_entity_value: Variant = bucket[index]
		if bucket_entity_value == null:
			bucket.remove_at(index)
			continue
		if not is_instance_valid(bucket_entity_value):
			bucket.remove_at(index)
			continue
		var bucket_entity := bucket_entity_value as Node
		if bucket_entity == null or bucket_entity.get_instance_id() == instance_id or bucket_entity.is_queued_for_deletion():
			bucket.remove_at(index)
	if bucket.is_empty():
		cells.erase(cell)
	else:
		cells[cell] = bucket


func _cleanup_stale_entity(instance_id: int) -> void:
	entity_cells.erase(instance_id)
	entity_categories.erase(instance_id)
	entity_types.erase(instance_id)
	tracked_entities.erase(instance_id)


func _get_cell_for_position(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / cell_size), floori(position.y / cell_size))


func _get_entity_position(entity: Node) -> Vector2:
	var node_2d := entity as Node2D
	if node_2d == null:
		return Vector2.INF
	return node_2d.global_position


func _is_live_entity(entity: Node) -> bool:
	if entity == null:
		return false
	if not is_instance_valid(entity):
		return false
	if entity.is_queued_for_deletion():
		return false
	return entity is Node2D


func _matches_type_filter(entity: Node, type_filter: Variant) -> bool:
	if type_filter == null:
		return true
	if entity == null or not is_instance_valid(entity):
		return false
	var entity_type := str(entity_types.get(entity.get_instance_id(), ""))
	if typeof(type_filter) == TYPE_STRING:
		var filter_string := str(type_filter)
		if filter_string.is_empty():
			return true
		return entity_type == filter_string
	if type_filter is Array:
		for filter_value in Array(type_filter):
			if entity_type == str(filter_value):
				return true
		return false
	return true
