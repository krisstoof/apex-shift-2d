extends RefCounted
class_name BiomeSurfaceSampler


func get_biome_id_at(position: Vector2, biome_zones: Array) -> String:
	for biome_value in biome_zones:
		var biome := Dictionary(biome_value)
		var points := PackedVector2Array(biome.get("points", []))
		if points.size() < 3:
			continue
		if Geometry2D.is_point_in_polygon(position, points):
			return _resolve_biome_id(biome)
	return ""


func get_biome_name_at(position: Vector2, biome_zones: Array) -> String:
	for biome_value in biome_zones:
		var biome := Dictionary(biome_value)
		var points := PackedVector2Array(biome.get("points", []))
		if points.size() < 3:
			continue
		if Geometry2D.is_point_in_polygon(position, points):
			return str(biome.get("name", _resolve_biome_id(biome)))
	return ""


func get_biome_color_at(position: Vector2, biome_zones: Array, fallback_color: Color = Color.BLACK) -> Color:
	for biome_value in biome_zones:
		var biome := Dictionary(biome_value)
		var points := PackedVector2Array(biome.get("points", []))
		if points.size() < 3:
			continue
		if Geometry2D.is_point_in_polygon(position, points):
			return Color(biome.get("color", fallback_color))
	return fallback_color


func build_surface_sample(position: Vector2, biome_zones: Array, fallback_color: Color = Color.BLACK) -> Dictionary:
	for biome_value in biome_zones:
		var biome := Dictionary(biome_value)
		var points := PackedVector2Array(biome.get("points", []))
		if points.size() < 3:
			continue
		if Geometry2D.is_point_in_polygon(position, points):
			return {
				"position": position,
				"biome_id": _resolve_biome_id(biome),
				"biome_name": str(biome.get("name", "")),
				"color": Color(biome.get("color", fallback_color))
			}
	return {
		"position": position,
		"biome_id": "",
		"biome_name": "",
		"color": fallback_color
	}


func _resolve_biome_id(biome: Dictionary) -> String:
	if biome.has("id"):
		return str(biome.get("id", ""))
	if biome.has("biome_id"):
		return str(biome.get("biome_id", ""))
	if biome.has("name"):
		return str(biome.get("name", "")).to_lower().replace(" ", "_")
	return ""
