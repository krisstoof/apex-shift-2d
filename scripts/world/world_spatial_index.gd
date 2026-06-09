extends RefCounted
class_name WorldSpatialIndex

var cell_size := 256.0
var resources_by_cell: Dictionary = {}
var creatures_by_cell: Dictionary = {}
var meat_by_cell: Dictionary = {}
var entity_cells: Dictionary = {}
var entity_categories: Dictionary = {}
var entity_types: Dictionary = {}


func register_entity(entity: Node, category: String = "", type_name: String = "") -> void:
	if not _is_supported_category(category):
		return
	if not _is_live_entity(entity):
		return
	unregister_entity(entity)
	var instance_id := entity.get_instance_id()
	var cell := _get_cell_for_position(_get_entity_position(entity))
	entity_cells[instance_id] = cell
	entity_categories[instance_id] = category
	entity_types[instance_id] = type_name
	_add_entity_to_cell(entity, category, cell)


func unregister_entity(entity: Node) -> void:
	if entity == null:
		return
	if not is_instance_valid(entity):
		return
	var instance_id := entity.get_instance_id()
	var cell_value: Variant = entity_cells.get(instance_id, null)
	var category := str(entity_categories.get(instance_id, ""))
	if cell_value is Vector2i:
		var cell := Vector2i(cell_value)
		_remove_entity_from_cell(entity, category, cell)
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
	_remove_entity_from_cell(entity, category, current_cell)
	_add_entity_to_cell(entity, category, next_cell)
	entity_cells[instance_id] = next_cell


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
	var stale_entities: Array[Node] = []
	for cell_x in range(min_cell_x, max_cell_x + 1):
		for cell_y in range(min_cell_y, max_cell_y + 1):
			var cell := Vector2i(cell_x, cell_y)
			if not cells.has(cell):
				continue
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
	for stale_entity in stale_entities:
		unregister_entity(stale_entity)
	return results


func query_resources_near(position: Vector2, radius: float, kind_filter: Variant = null) -> Array:
	return query_near(position, radius, "resource", kind_filter)


func query_creatures_near(position: Vector2, radius: float, creature_type_filter: Variant = null) -> Array:
	return query_near(position, radius, "creature", creature_type_filter)


func query_meat_near(position: Vector2, radius: float) -> Array:
	return query_near(position, radius, "meat")


func clear() -> void:
	resources_by_cell.clear()
	creatures_by_cell.clear()
	meat_by_cell.clear()
	entity_cells.clear()
	entity_categories.clear()
	entity_types.clear()


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
	return {
		"resource_cells": resources_by_cell.size(),
		"creature_cells": creatures_by_cell.size(),
		"meat_cells": meat_by_cell.size(),
		"tracked_entities": entity_cells.size()
	}


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


func _cleanup_stale_entity(instance_id: int) -> void:
	entity_cells.erase(instance_id)
	entity_categories.erase(instance_id)
	entity_types.erase(instance_id)


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
