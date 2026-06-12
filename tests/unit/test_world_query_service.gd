extends RefCounted

const WORLD_QUERY_SERVICE := preload("res://scripts/world/world_query_service.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


class TestWorldContext:
	extends RefCounted

	var pond_landmarks: Array = []
	var hill_landmarks: Array = []
	var pond_water_search_radius := 0.0


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_query_service_detects_water_zones_and_speed_bands(failures)
	_test_query_service_blocks_plants_but_not_rocks_in_water(failures)
	_test_query_service_blocks_navigation_in_deep_water_and_hills(failures)
	_test_query_service_reads_updated_landmarks_without_rebuild_copy(failures)
	return failures


func _test_query_service_detects_water_zones_and_speed_bands(failures: Array[String]) -> void:
	var context := _make_context_with_single_pond()
	var service := _make_service(context)
	TEST_UTILS.expect_equal(service.get_water_zone(Vector2.ZERO), "deep_ocean", failures, "WorldQueryService should classify pond centers as deep ocean")
	var shallow_point := _find_sample_point_for_zone(service, Dictionary(context.pond_landmarks[0]), "shallow_water")
	if shallow_point != Vector2.INF:
		TEST_UTILS.expect_equal(service.get_water_zone(shallow_point), "shallow_water", failures, "WorldQueryService should classify sampled mid-ring points as shallow water")
		TEST_UTILS.expect(float(service.get_terrain_speed_multiplier(Vector2.ZERO)) < float(service.get_terrain_speed_multiplier(shallow_point)), failures, "Deep water should slow movement more than shallow water")
	var land_point := Vector2(180.0, 0.0)
	TEST_UTILS.expect(
		service.get_water_zone(land_point) in ["land", "shore", "highland"],
		failures,
		"WorldQueryService should keep points outside the pond on playable land"
	)
	TEST_UTILS.expect(float(service.get_terrain_speed_multiplier(land_point)) > float(service.get_terrain_speed_multiplier(Vector2.ZERO)), failures, "Land should be faster than deep water")


func _test_query_service_blocks_plants_but_not_rocks_in_water(failures: Array[String]) -> void:
	var context := _make_context_with_single_pond()
	var service := _make_service(context)
	TEST_UTILS.expect(service.is_resource_position_blocked_by_water("grass_patch", Vector2.ZERO), failures, "Plants should be blocked in pond water")
	TEST_UTILS.expect(service.is_resource_position_blocked_by_water("bush", Vector2(12.0, 0.0)), failures, "Bushes should be blocked inside pond water margins")
	TEST_UTILS.expect(not service.is_resource_position_blocked_by_water("rock", Vector2.ZERO), failures, "Rocks should ignore plant-only water blocking")


func _test_query_service_blocks_navigation_in_deep_water_and_hills(failures: Array[String]) -> void:
	var context := _make_context_with_single_pond()
	context.hill_landmarks = [{
		"id": "hill_alpha",
		"type": "hill",
		"position": Vector2(240.0, 0.0),
		"radius": 120.0
	}]
	var service := _make_service(context)
	TEST_UTILS.expect(service.is_creature_navigation_blocked(Vector2.ZERO), failures, "Deep water should block creature navigation")
	TEST_UTILS.expect(service.is_creature_navigation_blocked(Vector2(240.0, 0.0)), failures, "Hill centers should block creature navigation")
	TEST_UTILS.expect(not service.is_creature_navigation_blocked(Vector2(460.0, 0.0)), failures, "Dry terrain away from landmarks should stay navigable")
	TEST_UTILS.expect(service.is_creature_spawn_blocked_by_water(Vector2.ZERO), failures, "Creature spawning should be blocked in deep water")


func _test_query_service_reads_updated_landmarks_without_rebuild_copy(failures: Array[String]) -> void:
	var context := TestWorldContext.new()
	var service := _make_service(context)
	TEST_UTILS.expect(service.get_water_zone(Vector2.ZERO) in ["land", "shore", "highland"], failures, "Without ponds the query service should default to playable terrain")
	context.pond_landmarks = [{
		"id": "pond_runtime",
		"type": "pond",
		"position": Vector2.ZERO,
		"radius": 100.0
	}]
	context.pond_water_search_radius = 120.0
	TEST_UTILS.expect_equal(service.get_water_zone(Vector2.ZERO), "deep_ocean", failures, "After runtime landmark updates the query service should read the new pond data")


func _make_service(context: TestWorldContext) -> Object:
	return WORLD_QUERY_SERVICE.new().bind_world(
		context,
		["conifer_tree", "leafy_tree", "bush", "dry_bush", "small_bush", "berry_bush", "grass_patch", "dense_grass"],
		0.72,
		0.58,
		0.62,
		"land",
		"shore",
		"shallow_water",
		"deep_ocean"
	)


func _make_context_with_single_pond() -> TestWorldContext:
	var context := TestWorldContext.new()
	context.pond_landmarks = [{
		"id": "pond_alpha",
		"type": "pond",
		"position": Vector2.ZERO,
		"radius": 100.0
	}]
	context.pond_water_search_radius = 120.0
	return context


func _find_sample_point_for_zone(service: Object, pond: Dictionary, expected_zone: String) -> Vector2:
	var center := Vector2(pond.get("position", Vector2.ZERO))
	var radius := float(pond.get("radius", 0.0))
	for step in 48:
		var angle := TAU * float(step) / 48.0
		for distance_factor in [0.70, 0.78, 0.84, 0.92, 1.02, 1.08]:
			var point := center + Vector2(cos(angle) * radius * distance_factor, sin(angle) * radius * 0.62 * distance_factor)
			if service.get_water_zone(point) == expected_zone:
				return point
	return Vector2.INF
