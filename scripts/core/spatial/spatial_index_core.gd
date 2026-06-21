extends RefCounted
class_name SpatialIndexCore

var cell_size := 256.0
var entities_by_cell: Dictionary = {}
var entity_cells: Dictionary = {}
var entity_data: Dictionary = {}


func clear() -> void:
	entities_by_cell.clear()
	entity_cells.clear()
	entity_data.clear()


func register_entity(entity_id: String, category: String, type_name: String, position: Vector2) -> void:
	if entity_id.is_empty():
		return
	unregister_entity(entity_id)
	var cell := _get_cell_for_position(position)
	entity_cells[entity_id] = cell
	entity_data[entity_id] = {
		"id": entity_id,
		"category": category,
		"type": type_name,
		"position": position
	}
	if not entities_by_cell.has(cell):
		entities_by_cell[cell] = []
	var bucket: Array = Array(entities_by_cell[cell])
	if entity_id not in bucket:
		bucket.append(entity_id)
	entities_by_cell[cell] = bucket


func unregister_entity(entity_id: String) -> void:
	if entity_id.is_empty():
		return
	var cell_value: Variant = entity_cells.get(entity_id, null)
	if cell_value is Vector2i:
		var cell := Vector2i(cell_value)
		if entities_by_cell.has(cell):
			var bucket: Array = Array(entities_by_cell[cell])
			bucket.erase(entity_id)
			if bucket.is_empty():
				entities_by_cell.erase(cell)
			else:
				entities_by_cell[cell] = bucket
	entity_cells.erase(entity_id)
	entity_data.erase(entity_id)


func update_entity_position(entity_id: String, position: Vector2) -> void:
	if entity_id.is_empty() or not entity_data.has(entity_id):
		return
	var previous_cell := Vector2i(entity_cells.get(entity_id, Vector2i.ZERO))
	var next_cell := _get_cell_for_position(position)
	var data := Dictionary(entity_data[entity_id])
	data["position"] = position
	entity_data[entity_id] = data
	if previous_cell == next_cell:
		return
	if entities_by_cell.has(previous_cell):
		var previous_bucket: Array = Array(entities_by_cell[previous_cell])
		previous_bucket.erase(entity_id)
		if previous_bucket.is_empty():
			entities_by_cell.erase(previous_cell)
		else:
			entities_by_cell[previous_cell] = previous_bucket
	if not entities_by_cell.has(next_cell):
		entities_by_cell[next_cell] = []
	var next_bucket: Array = Array(entities_by_cell[next_cell])
	if entity_id not in next_bucket:
		next_bucket.append(entity_id)
	entities_by_cell[next_cell] = next_bucket
	entity_cells[entity_id] = next_cell


func query_near(position: Vector2, radius: float, category: String = "", type_filter: Variant = null) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if radius <= 0.0:
		return results
	var radius_squared := radius * radius
	var min_cell_x := floori((position.x - radius) / cell_size)
	var max_cell_x := floori((position.x + radius) / cell_size)
	var min_cell_y := floori((position.y - radius) / cell_size)
	var max_cell_y := floori((position.y + radius) / cell_size)
	for cell_x in range(min_cell_x, max_cell_x + 1):
		for cell_y in range(min_cell_y, max_cell_y + 1):
			var cell := Vector2i(cell_x, cell_y)
			if not entities_by_cell.has(cell):
				continue
			for entity_id_value in Array(entities_by_cell[cell]):
				var entity_id := str(entity_id_value)
				if not entity_data.has(entity_id):
					continue
				var data := Dictionary(entity_data[entity_id])
				if not _matches_filter(data, category, type_filter):
					continue
				var entity_position := Vector2(data.get("position", Vector2.ZERO))
				if entity_position.distance_squared_to(position) <= radius_squared:
					results.append(data.duplicate(true))
	return results


func query_rect(rect: Rect2, category: String = "", type_filter: Variant = null) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return results
	var min_cell_x := floori(rect.position.x / cell_size)
	var max_cell_x := floori(rect.end.x / cell_size)
	var min_cell_y := floori(rect.position.y / cell_size)
	var max_cell_y := floori(rect.end.y / cell_size)
	for cell_x in range(min_cell_x, max_cell_x + 1):
		for cell_y in range(min_cell_y, max_cell_y + 1):
			var cell := Vector2i(cell_x, cell_y)
			if not entities_by_cell.has(cell):
				continue
			for entity_id_value in Array(entities_by_cell[cell]):
				var entity_id := str(entity_id_value)
				if not entity_data.has(entity_id):
					continue
				var data := Dictionary(entity_data[entity_id])
				if not _matches_filter(data, category, type_filter):
					continue
				var entity_position := Vector2(data.get("position", Vector2.ZERO))
				if rect.has_point(entity_position):
					results.append(data.duplicate(true))
	return results


func has_entity(entity_id: String) -> bool:
	return entity_data.has(entity_id)


func get_entity_data(entity_id: String) -> Dictionary:
	if not entity_data.has(entity_id):
		return {}
	return Dictionary(entity_data[entity_id]).duplicate(true)


func get_debug_counts() -> Dictionary:
	return {
		"cells": entities_by_cell.size(),
		"entities": entity_data.size(),
		"tracked_cells": entity_cells.size()
	}


func _matches_filter(data: Dictionary, category: String, type_filter: Variant) -> bool:
	if not category.is_empty() and str(data.get("category", "")) != category:
		return false
	if type_filter == null:
		return true
	var type_name := str(data.get("type", ""))
	if typeof(type_filter) == TYPE_STRING:
		var filter_string := str(type_filter)
		if filter_string.is_empty():
			return true
		return type_name == filter_string
	if type_filter is Array:
		for filter_value in Array(type_filter):
			if type_name == str(filter_value):
				return true
		return false
	return true


func _get_cell_for_position(position: Vector2) -> Vector2i:
	return Vector2i(
		floori(position.x / cell_size),
		floori(position.y / cell_size)
	)
