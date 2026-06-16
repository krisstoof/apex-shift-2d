extends RefCounted
class_name WorldBiomeQueryService

# Legacy/fallback cache only. Procedural worlds should prefer generator biome IDs.
const BIOME_QUERY_CELL_SIZE := 64.0

var cell_size := BIOME_QUERY_CELL_SIZE
var biome_id_by_cell: Dictionary = {}
var cache_hit_count := 0
var cache_miss_count := 0
var polygon_check_count := 0
var biome_zones: Array[Dictionary] = []


func bind_biomes(p_biome_zones: Array) -> void:
	biome_zones = []
	for biome_value in p_biome_zones:
		if typeof(biome_value) == TYPE_DICTIONARY:
			biome_zones.append(Dictionary(biome_value))
	clear_cache()


func get_biome_id_for_position(position: Vector2) -> String:
	var key := _get_cell_key(position)
	if biome_id_by_cell.has(key):
		cache_hit_count += 1
		return str(biome_id_by_cell[key])
	cache_miss_count += 1
	var biome_id := _resolve_biome_id_by_polygon(position)
	biome_id_by_cell[key] = biome_id
	return biome_id


func get_biome_id_for_position_exact(position: Vector2) -> String:
	return _resolve_biome_id_by_polygon(position)


func clear_cache() -> void:
	biome_id_by_cell.clear()
	cache_hit_count = 0
	cache_miss_count = 0
	polygon_check_count = 0


func get_debug_counts() -> Dictionary:
	return {
		"cell_size": cell_size,
		"cache_size": biome_id_by_cell.size(),
		"cache_hit_count": cache_hit_count,
		"cache_miss_count": cache_miss_count,
		"polygon_check_count": polygon_check_count
	}


func _get_cell_key(position: Vector2) -> String:
	var cell := Vector2i(floori(position.x / cell_size), floori(position.y / cell_size))
	return "%d:%d" % [cell.x, cell.y]


func _resolve_biome_id_by_polygon(position: Vector2) -> String:
	for biome in biome_zones:
		polygon_check_count += 1
		if _is_point_in_biome(position, biome):
			return _get_biome_id(biome)
	return ""


func _is_point_in_biome(position: Vector2, biome: Dictionary) -> bool:
	var points := PackedVector2Array(biome.get("points", []))
	if points.size() < 3:
		return false
	return Geometry2D.is_point_in_polygon(position, points)


func _get_biome_id(biome: Dictionary) -> String:
	var biome_id := str(biome.get("id", ""))
	if not biome_id.is_empty():
		return biome_id
	return str(biome.get("name", "biome")).to_snake_case()
