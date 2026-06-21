extends RefCounted
class_name VegetationDistributionValidator

const MAX_ABS_CORRELATION := 0.85


static func validate_distribution(spawn_items: Array) -> Dictionary:
	var warnings: Array[String] = []
	var by_biome := _count_by_biome(spawn_items)
	var by_kind := _count_by_kind(spawn_items)
	warnings.append_array(_detect_line_patterns(spawn_items))
	return {
		"warnings": warnings,
		"by_biome": by_biome,
		"by_kind": by_kind,
		"line_pattern_warnings": warnings.duplicate(true)
	}


static func _count_by_biome(spawn_items: Array) -> Dictionary:
	var result: Dictionary = {}
	for item_value in spawn_items:
		var data := _to_dictionary(item_value)
		var biome_id := str(data.get("biome_id", "unknown"))
		var kind := str(data.get("kind", "unknown"))
		if not result.has(biome_id):
			result[biome_id] = {"total": 0}
		var biome_data := Dictionary(result[biome_id])
		biome_data["total"] = int(biome_data.get("total", 0)) + 1
		biome_data[kind] = int(biome_data.get(kind, 0)) + 1
		result[biome_id] = biome_data
	return result


static func _count_by_kind(spawn_items: Array) -> Dictionary:
	var result: Dictionary = {}
	for item_value in spawn_items:
		var data := _to_dictionary(item_value)
		var biome_id := str(data.get("biome_id", "unknown"))
		var kind := str(data.get("kind", "unknown"))
		if not result.has(kind):
			result[kind] = {"total": 0}
		var kind_data := Dictionary(result[kind])
		kind_data["total"] = int(kind_data.get("total", 0)) + 1
		kind_data[biome_id] = int(kind_data.get(biome_id, 0)) + 1
		result[kind] = kind_data
	return result


static func _detect_line_patterns(spawn_items: Array) -> Array[String]:
	var warnings: Array[String] = []
	var points_by_key: Dictionary = {}
	for item_value in spawn_items:
		var data := _to_dictionary(item_value)
		var biome_id := str(data.get("biome_id", "unknown"))
		var kind := str(data.get("kind", "unknown"))
		var key := "%s|%s" % [biome_id, kind]
		if not points_by_key.has(key):
			points_by_key[key] = []
		var points: Array = Array(points_by_key[key])
		points.append(Vector2(data.get("position", Vector2.ZERO)))
		points_by_key[key] = points
	for key in points_by_key.keys():
		var points: Array = Array(points_by_key[key])
		if points.size() < 8:
			continue
		var corr := _calculate_xy_correlation(points)
		if absf(corr) >= MAX_ABS_CORRELATION:
			warnings.append("[VEGETATION_LINE_PATTERN_WARNING] key=%s count=%d correlation=%.3f" % [key, points.size(), corr])
	return warnings


static func _calculate_xy_correlation(points: Array) -> float:
	var count := points.size()
	if count <= 1:
		return 0.0
	var sum_x := 0.0
	var sum_y := 0.0
	for point_value in points:
		var point := Vector2(point_value)
		sum_x += point.x
		sum_y += point.y
	var mean_x := sum_x / float(count)
	var mean_y := sum_y / float(count)
	var numerator := 0.0
	var denom_x := 0.0
	var denom_y := 0.0
	for point_value in points:
		var point := Vector2(point_value)
		var dx := point.x - mean_x
		var dy := point.y - mean_y
		numerator += dx * dy
		denom_x += dx * dx
		denom_y += dy * dy
	var denom := sqrt(denom_x * denom_y)
	if denom <= 0.0001:
		return 0.0
	return numerator / denom


static func _to_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return Dictionary(value)
	if value != null and value.has_method("to_dictionary"):
		return Dictionary(value.to_dictionary())
	return {}
