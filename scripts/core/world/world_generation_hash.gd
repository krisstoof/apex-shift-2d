extends RefCounted

const WORLD_GENERATION_RESULT := preload("res://scripts/core/world/world_generation_result.gd")


static func compute_from_result(result) -> String:
	if result == null:
		return ""
	return compute_from_payload(_build_payload_from_result(result))


static func compute_from_layout(layout: Dictionary) -> String:
	return compute_from_result(WORLD_GENERATION_RESULT.from_layout(layout))


static func compute_from_payload(payload: Dictionary) -> String:
	var normalized: Variant = _normalize_value(payload)
	var json := JSON.stringify(normalized)
	return str(hash(json))


static func _build_payload_from_result(result) -> Dictionary:
	return {
		"seed": result.seed,
		"generator_version": result.generator_version,
		"world_rect": _rect_to_payload(result.world_rect),
		"terrain_counts": result.terrain_counts,
		"biome_coverage": result.biome_coverage,
		"biomes": _normalize_dict_array(result.biome_regions),
		"landmarks": _normalize_dict_array(result.landmarks),
		"player_spawn_position": _vector_to_payload(result.player_spawn_position),
		"resource_spawns": _normalize_dict_array(result.resource_spawns),
		"creature_spawns": _normalize_dict_array(result.creature_spawns)
	}


static func _rect_to_payload(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"w": rect.size.x,
		"h": rect.size.y
	}


static func _vector_to_payload(value: Vector2) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y
	}


static func _normalize_dict_array(value: Array) -> Array:
	var result: Array = []
	for item in value:
		result.append(_normalize_value(item))
	return result


static func _normalize_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var source := Dictionary(value)
			var normalized := {}
			var keys := source.keys()
			keys.sort()
			for key in keys:
				normalized[str(key)] = _normalize_value(source[key])
			return normalized
		TYPE_ARRAY:
			var normalized_array: Array = []
			for item in Array(value):
				normalized_array.append(_normalize_value(item))
			return normalized_array
		TYPE_VECTOR2:
			return _vector_to_payload(Vector2(value))
		TYPE_VECTOR2I:
			var vector_i := Vector2i(value)
			return {"x": vector_i.x, "y": vector_i.y}
		TYPE_RECT2:
			return _rect_to_payload(Rect2(value))
		TYPE_RECT2I:
			var rect_i := Rect2i(value)
			return {
				"x": rect_i.position.x,
				"y": rect_i.position.y,
				"w": rect_i.size.x,
				"h": rect_i.size.y
			}
		TYPE_FLOAT:
			return snappedf(float(value), 0.0001)
		_:
			return value
