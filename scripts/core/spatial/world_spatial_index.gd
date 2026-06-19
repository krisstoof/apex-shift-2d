class_name WorldSpatialIndex
extends RefCounted

const SpatialQueryResultScript := preload("res://scripts/core/spatial/spatial_query_result.gd")

const CATEGORY_RESOURCE := "resource"
const CATEGORY_CREATURE := "creature"
const CATEGORY_BUILDING := "building"
const CATEGORY_MEAT := "meat"
const CATEGORY_DECORATION := "decoration"

const SUPPORTED_CATEGORIES := {
	CATEGORY_RESOURCE: true,
	CATEGORY_CREATURE: true,
	CATEGORY_BUILDING: true,
	CATEGORY_MEAT: true,
	CATEGORY_DECORATION: true
}

var cell_size := 256.0
var entities_by_cell: Dictionary = {}
var entity_records: Dictionary = {}
var entity_cells: Dictionary = {}
var stale_entries_removed_last_cleanup := 0


func register_entity(entity_id: Variant, position: Vector2, category: String, metadata: Dictionary = {}) -> void:
	if entity_id == null or not _is_supported_category(category):
		return
	unregister_entity(entity_id)
	var cell := _get_cell_for_position(position)
	var record := {"entity_id": entity_id, "position": position, "category": category, "metadata": metadata.duplicate(true), "cell": cell}
	entity_records[entity_id] = record
	entity_cells[entity_id] = cell
	_add_entity_to_cell(entity_id, category, cell)


func unregister_entity(entity_id: Variant) -> void:
	if entity_id == null:
		return
	if not entity_records.has(entity_id):
		entity_cells.erase(entity_id)
		return
	var record := Dictionary(entity_records.get(entity_id, {}))
	var category := str(record.get("category", ""))
	var cell_value: Variant = record.get("cell", entity_cells.get(entity_id, Vector2i(-1, -1)))
	if cell_value is Vector2i:
		_remove_entity_from_cell(entity_id, category, Vector2i(cell_value))
	entity_records.erase(entity_id)
	entity_cells.erase(entity_id)


func update_entity_position(entity_id: Variant, position: Vector2) -> void:
	if entity_id == null or not entity_records.has(entity_id):
		return
	var record := Dictionary(entity_records.get(entity_id, {}))
	var category := str(record.get("category", ""))
	if not _is_supported_category(category):
		return
	var old_cell := Vector2i(record.get("cell", entity_cells.get(entity_id, Vector2i(-1, -1))))
	var new_cell := _get_cell_for_position(position)
	if new_cell != old_cell:
		_remove_entity_from_cell(entity_id, category, old_cell)
		_add_entity_to_cell(entity_id, category, new_cell)
	record["position"] = position
	record["cell"] = new_cell
	entity_records[entity_id] = record
	entity_cells[entity_id] = new_cell


func update_entity_metadata(entity_id: Variant, metadata: Dictionary) -> void:
	if entity_id == null or not entity_records.has(entity_id):
		return
	var record := Dictionary(entity_records.get(entity_id, {}))
	record["metadata"] = metadata.duplicate(true)
	entity_records[entity_id] = record


func has_entity_id(entity_id: Variant) -> bool:
	return entity_records.has(entity_id)


func get_entity_cell_by_id(entity_id: Variant) -> Vector2i:
	var cell_value: Variant = entity_cells.get(entity_id, Vector2i(-1, -1))
	return Vector2i(cell_value) if cell_value is Vector2i else Vector2i(-1, -1)


func get_entity_record(entity_id: Variant) -> Dictionary:
	return Dictionary(entity_records.get(entity_id, {})).duplicate(true)


func query_circle(position: Vector2, radius: float, category_filter: Variant = null, type_filter: Variant = null) -> Array:
	if radius <= 0.0:
		return []
	var categories := _resolve_categories(category_filter)
	if categories.is_empty():
		return []
	var radius_squared := radius * radius
	var min_cell_x := floori((position.x - radius) / cell_size)
	var max_cell_x := floori((position.x + radius) / cell_size)
	var min_cell_y := floori((position.y - radius) / cell_size)
	var max_cell_y := floori((position.y + radius) / cell_size)
	var results: Array = []
	var seen: Dictionary = {}
	for category in categories:
		for cell_x in range(min_cell_x, max_cell_x + 1):
			for cell_y in range(min_cell_y, max_cell_y + 1):
				var cell := Vector2i(cell_x, cell_y)
				var bucket_key := _get_bucket_key(category, cell)
				if not entities_by_cell.has(bucket_key):
					continue
				for entity_id in Array(entities_by_cell[bucket_key]):
					if seen.has(entity_id) or not entity_records.has(entity_id):
						continue
					var record := Dictionary(entity_records[entity_id])
					var entity_position := Vector2(record.get("position", Vector2.ZERO))
					if entity_position.distance_squared_to(position) > radius_squared:
						continue
					if not _matches_type_filter(record, type_filter):
						continue
					seen[entity_id] = true
					results.append(SpatialQueryResultScript.from_record(record, position))
	_sort_results_by_distance(results)
	return results


func query_rect(rect: Rect2, category_filter: Variant = null, type_filter: Variant = null) -> Array:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return []
	var categories := _resolve_categories(category_filter)
	if categories.is_empty():
		return []
	var min_cell_x := floori(rect.position.x / cell_size)
	var max_cell_x := floori(rect.end.x / cell_size)
	var min_cell_y := floori(rect.position.y / cell_size)
	var max_cell_y := floori(rect.end.y / cell_size)
	var results: Array = []
	var seen: Dictionary = {}
	for category in categories:
		for cell_x in range(min_cell_x, max_cell_x + 1):
			for cell_y in range(min_cell_y, max_cell_y + 1):
				var cell := Vector2i(cell_x, cell_y)
				var bucket_key := _get_bucket_key(category, cell)
				if not entities_by_cell.has(bucket_key):
					continue
				for entity_id in Array(entities_by_cell[bucket_key]):
					if seen.has(entity_id) or not entity_records.has(entity_id):
						continue
					var record := Dictionary(entity_records[entity_id])
					var entity_position := Vector2(record.get("position", Vector2.ZERO))
					if not rect.has_point(entity_position) or not _matches_type_filter(record, type_filter):
						continue
					seen[entity_id] = true
					results.append(SpatialQueryResultScript.from_record(record, rect.get_center()))
	_sort_results_by_distance(results)
	return results


func clear() -> void:
	entities_by_cell.clear()
	entity_records.clear()
	entity_cells.clear()
	stale_entries_removed_last_cleanup = 0


func get_debug_counts() -> Dictionary:
	var category_counts := {}
	var category_cell_counts := {}
	var max_entities_in_cell := 0
	for category in SUPPORTED_CATEGORIES.keys():
		category_counts[category] = 0
		category_cell_counts[category] = 0
	for bucket_key in entities_by_cell.keys():
		var bucket := Array(entities_by_cell[bucket_key])
		max_entities_in_cell = maxi(max_entities_in_cell, bucket.size())
		var parts := str(bucket_key).split("|")
		var category := str(parts[0]) if parts.size() > 0 else ""
		category_cell_counts[category] = int(category_cell_counts.get(category, 0)) + 1
		category_counts[category] = int(category_counts.get(category, 0)) + bucket.size()
	var non_empty_cells := entities_by_cell.size()
	var average_entities_per_cell := float(entity_records.size()) / float(non_empty_cells) if non_empty_cells > 0 else 0.0
	return {
		"tracked_entities": entity_records.size(),
		"resource_cells": int(category_cell_counts.get(CATEGORY_RESOURCE, 0)),
		"creature_cells": int(category_cell_counts.get(CATEGORY_CREATURE, 0)),
		"building_cells": int(category_cell_counts.get(CATEGORY_BUILDING, 0)),
		"meat_cells": int(category_cell_counts.get(CATEGORY_MEAT, 0)),
		"decoration_cells": int(category_cell_counts.get(CATEGORY_DECORATION, 0)),
		"resources_total": int(category_counts.get(CATEGORY_RESOURCE, 0)),
		"creatures_total": int(category_counts.get(CATEGORY_CREATURE, 0)),
		"buildings_total": int(category_counts.get(CATEGORY_BUILDING, 0)),
		"meat_total": int(category_counts.get(CATEGORY_MEAT, 0)),
		"decorations_total": int(category_counts.get(CATEGORY_DECORATION, 0)),
		"average_entities_per_cell": average_entities_per_cell,
		"max_entities_in_cell": max_entities_in_cell,
		"stale_entries_removed_last_cleanup": stale_entries_removed_last_cleanup
	}


func get_debug_data() -> Dictionary:
	return get_debug_counts()


func _is_supported_category(category: String) -> bool:
	return SUPPORTED_CATEGORIES.has(category)


func _resolve_categories(category_filter: Variant) -> Array[String]:
	var categories: Array[String] = []
	if category_filter == null:
		for category in SUPPORTED_CATEGORIES.keys():
			categories.append(str(category))
		return categories
	if typeof(category_filter) == TYPE_STRING:
		var category := str(category_filter)
		if category.is_empty():
			for key in SUPPORTED_CATEGORIES.keys():
				categories.append(str(key))
		elif _is_supported_category(category):
			categories.append(category)
		return categories
	if category_filter is Array:
		for value in Array(category_filter):
			var category := str(value)
			if _is_supported_category(category):
				categories.append(category)
	return categories


func _matches_type_filter(record: Dictionary, type_filter: Variant) -> bool:
	if type_filter == null:
		return true
	var metadata := Dictionary(record.get("metadata", {}))
	var entity_type := str(metadata.get("type", metadata.get("kind", "")))
	if typeof(type_filter) == TYPE_STRING:
		var filter_string := str(type_filter)
		return filter_string.is_empty() or entity_type == filter_string
	if type_filter is Array:
		for filter_value in Array(type_filter):
			if entity_type == str(filter_value):
				return true
		return false
	return true


func _get_cell_for_position(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / cell_size), floori(position.y / cell_size))


func _get_bucket_key(category: String, cell: Vector2i) -> String:
	return "%s|%d|%d" % [category, cell.x, cell.y]


func _add_entity_to_cell(entity_id: Variant, category: String, cell: Vector2i) -> void:
	var bucket_key := _get_bucket_key(category, cell)
	if not entities_by_cell.has(bucket_key):
		entities_by_cell[bucket_key] = []
	var bucket: Array = Array(entities_by_cell[bucket_key])
	if entity_id not in bucket:
		bucket.append(entity_id)
	entities_by_cell[bucket_key] = bucket


func _remove_entity_from_cell(entity_id: Variant, category: String, cell: Vector2i) -> void:
	var bucket_key := _get_bucket_key(category, cell)
	if not entities_by_cell.has(bucket_key):
		return
	var bucket: Array = Array(entities_by_cell[bucket_key])
	for index in range(bucket.size() - 1, -1, -1):
		if bucket[index] == entity_id:
			bucket.remove_at(index)
	if bucket.is_empty():
		entities_by_cell.erase(bucket_key)
	else:
		entities_by_cell[bucket_key] = bucket


func _sort_results_by_distance(results: Array) -> void:
	results.sort_custom(func(left, right) -> bool:
		return float(left.distance_squared) < float(right.distance_squared)
	)
