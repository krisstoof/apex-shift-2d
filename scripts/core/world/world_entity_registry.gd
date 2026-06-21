class_name WorldEntityRegistry
extends RefCounted

const GODOT_SPATIAL_INDEX_ADAPTER := preload("res://scripts/godot_adapters/world/godot_spatial_index_adapter.gd")

const CATEGORY_RESOURCE := "resource"
const CATEGORY_CREATURE := "creature"
const CATEGORY_BUILDING := "building"
const CATEGORY_MEAT := "meat"

const SUPPORTED_CATEGORIES := {
	CATEGORY_RESOURCE: true,
	CATEGORY_CREATURE: true,
	CATEGORY_BUILDING: true,
	CATEGORY_MEAT: true
}

var spatial_index = GODOT_SPATIAL_INDEX_ADAPTER.new()
var entity_records: Dictionary = {}
var entity_ids_by_category: Dictionary = {
	CATEGORY_RESOURCE: {},
	CATEGORY_CREATURE: {},
	CATEGORY_BUILDING: {},
	CATEGORY_MEAT: {}
}

var resource_version := 0
var creature_version := 0
var building_version := 0
var meat_version := 0


func register_entity(entity_id: Variant, category: String, entity_type: String, position: Vector2, biome_id: String = "", metadata: Dictionary = {}, active: bool = true) -> void:
	if entity_id == null or not _is_supported_category(category):
		return
	if entity_records.has(entity_id):
		unregister_entity(entity_id)
	var normalized_metadata := metadata.duplicate(true)
	normalized_metadata["type"] = entity_type
	normalized_metadata["kind"] = entity_type
	var record := {
		"entity_id": entity_id,
		"category": category,
		"type": entity_type,
		"position": position,
		"biome_id": biome_id,
		"metadata": normalized_metadata,
		"active": active
	}
	entity_records[entity_id] = record
	Dictionary(entity_ids_by_category[category])[entity_id] = true
	_increment_version(category)
	if active and spatial_index != null:
		spatial_index.register_entity(entity_id, position, category, normalized_metadata)


func unregister_entity(entity_id: Variant) -> void:
	if entity_id == null or not entity_records.has(entity_id):
		return
	var record := Dictionary(entity_records.get(entity_id, {}))
	var category := str(record.get("category", ""))
	if spatial_index != null:
		spatial_index.unregister_entity(entity_id)
	entity_records.erase(entity_id)
	if entity_ids_by_category.has(category):
		Dictionary(entity_ids_by_category[category]).erase(entity_id)
	_increment_version(category)


func update_entity_position(entity_id: Variant, position: Vector2) -> void:
	if entity_id == null or not entity_records.has(entity_id):
		return
	var record := Dictionary(entity_records.get(entity_id, {}))
	record["position"] = position
	entity_records[entity_id] = record
	if bool(record.get("active", true)) and spatial_index != null:
		spatial_index.update_entity_position(entity_id, position)


func update_entity_biome(entity_id: Variant, biome_id: String) -> void:
	if entity_id == null or not entity_records.has(entity_id):
		return
	var record := Dictionary(entity_records.get(entity_id, {}))
	record["biome_id"] = biome_id
	entity_records[entity_id] = record


func update_entity_metadata(entity_id: Variant, metadata: Dictionary) -> void:
	if entity_id == null or not entity_records.has(entity_id):
		return
	var record := Dictionary(entity_records.get(entity_id, {}))
	var normalized_metadata := metadata.duplicate(true)
	normalized_metadata["type"] = str(record.get("type", normalized_metadata.get("type", "")))
	normalized_metadata["kind"] = str(record.get("type", normalized_metadata.get("kind", "")))
	record["metadata"] = normalized_metadata
	entity_records[entity_id] = record
	if bool(record.get("active", true)) and spatial_index != null:
		spatial_index.update_entity_metadata(entity_id, normalized_metadata)


func set_entity_active(entity_id: Variant, active: bool) -> void:
	if entity_id == null or not entity_records.has(entity_id):
		return
	var record := Dictionary(entity_records.get(entity_id, {}))
	var was_active := bool(record.get("active", true))
	if was_active == active:
		return
	record["active"] = active
	entity_records[entity_id] = record
	var category := str(record.get("category", ""))
	var position := Vector2(record.get("position", Vector2.ZERO))
	var metadata := Dictionary(record.get("metadata", {}))
	if spatial_index == null:
		return
	if active:
		spatial_index.register_entity(entity_id, position, category, metadata)
	else:
		spatial_index.unregister_entity(entity_id)


func has_entity(entity_id: Variant) -> bool:
	return entity_records.has(entity_id)


func get_entity(entity_id: Variant) -> Dictionary:
	return Dictionary(entity_records.get(entity_id, {})).duplicate(true)


func get_entities(category_filter: Variant = null, type_filter: Variant = null, include_inactive: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var categories := _resolve_categories(category_filter)
	for category in categories:
		if not entity_ids_by_category.has(category):
			continue
		for entity_id in Dictionary(entity_ids_by_category[category]).keys():
			if not entity_records.has(entity_id):
				continue
			var record := Dictionary(entity_records.get(entity_id, {}))
			if not include_inactive and not bool(record.get("active", true)):
				continue
			if not _matches_type_filter(record, type_filter):
				continue
			result.append(record.duplicate(true))
	return result


func get_entities_by_category(category: String, include_inactive: bool = false) -> Array[Dictionary]:
	return get_entities(category, null, include_inactive)


func get_entities_by_type(category: String, entity_type: String, include_inactive: bool = false) -> Array[Dictionary]:
	return get_entities(category, entity_type, include_inactive)


func get_entities_by_biome(category_filter: Variant, biome_id: String, type_filter: Variant = null, include_inactive: bool = false) -> Array[Dictionary]:
	if biome_id.is_empty():
		return get_entities(category_filter, type_filter, include_inactive)
	var result: Array[Dictionary] = []
	for record in get_entities(category_filter, type_filter, include_inactive):
		if str(record.get("biome_id", "")) == biome_id:
			result.append(record)
	return result


func query_circle(position: Vector2, radius: float, category_filter: Variant = null, type_filter: Variant = null) -> Array[Dictionary]:
	if spatial_index == null:
		return []
	var spatial_results: Array = spatial_index.query_circle(position, radius, category_filter, type_filter)
	return _records_from_spatial_results(spatial_results)


func query_rect(rect: Rect2, category_filter: Variant = null, type_filter: Variant = null) -> Array[Dictionary]:
	if spatial_index == null:
		return []
	var spatial_results: Array = spatial_index.query_rect(rect, category_filter, type_filter)
	return _records_from_spatial_results(spatial_results)


func get_resources_near(position: Vector2, radius: float, kind_filter: Variant = null) -> Array[Dictionary]:
	return query_circle(position, radius, CATEGORY_RESOURCE, kind_filter)


func get_creatures_near(position: Vector2, radius: float, creature_type_filter: Variant = null) -> Array[Dictionary]:
	return query_circle(position, radius, CATEGORY_CREATURE, creature_type_filter)


func get_buildings_near(position: Vector2, radius: float, building_type_filter: Variant = null) -> Array[Dictionary]:
	return query_circle(position, radius, CATEGORY_BUILDING, building_type_filter)


func get_meat_near(position: Vector2, radius: float) -> Array[Dictionary]:
	return query_circle(position, radius, CATEGORY_MEAT, null)


func get_resources_in_rect(rect: Rect2, kind_filter: Variant = null) -> Array[Dictionary]:
	return query_rect(rect, CATEGORY_RESOURCE, kind_filter)


func get_creatures_in_rect(rect: Rect2, creature_type_filter: Variant = null) -> Array[Dictionary]:
	return query_rect(rect, CATEGORY_CREATURE, creature_type_filter)


func get_buildings_in_rect(rect: Rect2, building_type_filter: Variant = null) -> Array[Dictionary]:
	return query_rect(rect, CATEGORY_BUILDING, building_type_filter)


func get_meat_in_rect(rect: Rect2) -> Array[Dictionary]:
	return query_rect(rect, CATEGORY_MEAT, null)


func clear() -> void:
	entity_records.clear()
	for category in entity_ids_by_category.keys():
		Dictionary(entity_ids_by_category[category]).clear()
	if spatial_index != null and spatial_index.has_method("clear"):
		spatial_index.clear()
	resource_version = 0
	creature_version = 0
	building_version = 0
	meat_version = 0


func get_debug_counts() -> Dictionary:
	var spatial_debug := {}
	if spatial_index != null and spatial_index.has_method("get_debug_counts"):
		spatial_debug = spatial_index.get_debug_counts()
	return {
		"tracked_entities": entity_records.size(),
		"resources_total": Dictionary(entity_ids_by_category[CATEGORY_RESOURCE]).size(),
		"creatures_total": Dictionary(entity_ids_by_category[CATEGORY_CREATURE]).size(),
		"buildings_total": Dictionary(entity_ids_by_category[CATEGORY_BUILDING]).size(),
		"meat_total": Dictionary(entity_ids_by_category[CATEGORY_MEAT]).size(),
		"resource_version": resource_version,
		"creature_version": creature_version,
		"building_version": building_version,
		"meat_version": meat_version,
		"spatial_index": spatial_debug
	}


func get_debug_data() -> Dictionary:
	return get_debug_counts()


func get_visibility_query_provider() -> RefCounted:
	return spatial_index


func _records_from_spatial_results(spatial_results: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spatial_result in spatial_results:
		var entity_id: Variant = spatial_result.entity_id
		if not entity_records.has(entity_id):
			continue
		var record := Dictionary(entity_records.get(entity_id, {}))
		if not bool(record.get("active", true)):
			continue
		result.append(record.duplicate(true))
	return result


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
	var entity_type := str(record.get("type", ""))
	if typeof(type_filter) == TYPE_STRING:
		var filter_string := str(type_filter)
		if filter_string.is_empty():
			return true
		return entity_type == filter_string
	if type_filter is Array:
		for value in Array(type_filter):
			if entity_type == str(value):
				return true
		return false
	return true


func _increment_version(category: String) -> void:
	match category:
		CATEGORY_RESOURCE:
			resource_version += 1
		CATEGORY_CREATURE:
			creature_version += 1
		CATEGORY_BUILDING:
			building_version += 1
		CATEGORY_MEAT:
			meat_version += 1
