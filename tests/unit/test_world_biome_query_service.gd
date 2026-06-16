extends RefCounted

const WORLD_BIOME_QUERY_SERVICE := preload("res://scripts/world/world_biome_query_service.gd")
const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_returns_biome_for_known_positions(failures)
	_test_returns_empty_for_outside_position(failures)
	_test_repeated_lookup_uses_cache(failures)
	return failures


func _test_returns_biome_for_known_positions(failures: Array[String]) -> void:
	var service := _make_service()
	for biome in WORLD_CONFIG.get_biome_zones():
		var point := _find_point_in_biome(Dictionary(biome))
		if point == Vector2.INF:
			failures.append("Could not find a sample point inside biome %s" % str(biome.get("name", "biome")))
			continue
		var biome_id: String = service.get_biome_id_for_position(point)
		TEST_UTILS.expect(not biome_id.is_empty(), failures, "Biome lookup should return a biome id for an interior point")


func _test_returns_empty_for_outside_position(failures: Array[String]) -> void:
	var service := _make_service()
	TEST_UTILS.expect_equal(service.get_biome_id_for_position(Vector2(999999.0, 999999.0)), "", failures, "Biome lookup should return empty string outside all biome polygons")


func _test_repeated_lookup_uses_cache(failures: Array[String]) -> void:
	var service := _make_service()
	var point := _find_point_in_biome(Dictionary(WORLD_CONFIG.get_biome_zones()[0]))
	if point == Vector2.INF:
		failures.append("Could not find a sample point for cache test")
		return
	service.get_biome_id_for_position(point)
	var after_first: Dictionary = service.get_debug_counts()
	service.get_biome_id_for_position(point)
	var after_second: Dictionary = service.get_debug_counts()
	TEST_UTILS.expect(int(after_second.get("cache_hit_count", 0)) > int(after_first.get("cache_hit_count", 0)), failures, "Repeated biome lookup should increase cache hits")
	TEST_UTILS.expect_equal(int(after_first.get("cache_miss_count", 0)), 1, failures, "First biome lookup should count as one cache miss")


func _make_service() -> Object:
	var service := WORLD_BIOME_QUERY_SERVICE.new()
	service.bind_biomes(WORLD_CONFIG.get_biome_zones())
	return service


func _find_point_in_biome(biome: Dictionary) -> Vector2:
	var points := PackedVector2Array(biome.get("points", []))
	if points.size() < 3:
		return Vector2.INF
	var center := Vector2.ZERO
	for point in points:
		center += point
	center /= float(points.size())
	for radius_factor in [0.0, 0.12, 0.22, 0.34, 0.46]:
		for angle_step in range(24):
			var angle := TAU * float(angle_step) / 24.0
			var candidate: Vector2 = center + Vector2(cos(angle), sin(angle)) * 64.0 * radius_factor
			if Geometry2D.is_point_in_polygon(candidate, points):
				return candidate
	return Vector2.INF
