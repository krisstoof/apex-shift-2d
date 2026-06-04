extends RefCounted

const WORLD_SCRIPT := preload("res://scripts/world/world.gd")
const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_world_rect_matches_config(failures)
	_test_water_zone_detection_uses_pond_geometry(failures)
	_test_plant_resources_are_blocked_by_water(failures)
	_test_non_plant_resources_ignore_water_blocking(failures)
	_test_hills_block_navigation(failures)
	_test_terrain_speed_multiplier_changes_in_water(failures)
	return failures


func _test_world_rect_matches_config(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	TEST_UTILS.expect_equal(world.get_world_rect(), WORLD_CONFIG.WORLD_RECT, failures, "World rectangle should match world config")
	world.free()


func _test_water_zone_detection_uses_pond_geometry(failures: Array[String]) -> void:
	var world := _make_world_with_single_pond()
	TEST_UTILS.expect_equal(world.get_water_zone(Vector2.ZERO), "deep_water", failures, "Pond center should be deep water")
	var shallow_point := _find_sample_point_for_zone(world, "shallow_water")
	TEST_UTILS.expect(shallow_point != Vector2.INF, failures, "The pond should expose at least one shallow-water sample point")
	if shallow_point != Vector2.INF:
		TEST_UTILS.expect_equal(world.get_water_zone(shallow_point), "shallow_water", failures, "A sampled mid-ring point should be shallow water")
	TEST_UTILS.expect_equal(world.get_water_zone(Vector2(160.0, 0.0)), "land", failures, "Outside the pond should be land")
	world.free()


func _test_plant_resources_are_blocked_by_water(failures: Array[String]) -> void:
	var world := _make_world_with_single_pond()
	TEST_UTILS.expect(world.is_resource_position_blocked_by_water("grass_patch", Vector2.ZERO), failures, "Plant resources should be blocked in pond water")
	TEST_UTILS.expect(world.is_resource_position_blocked_by_water("bush", Vector2(15.0, 0.0)), failures, "Bushes should be blocked in pond water")
	world.free()


func _test_non_plant_resources_ignore_water_blocking(failures: Array[String]) -> void:
	var world := _make_world_with_single_pond()
	TEST_UTILS.expect(not world.is_resource_position_blocked_by_water("rock", Vector2.ZERO), failures, "Rocks should ignore water blocking")
	TEST_UTILS.expect(not world.is_resource_position_blocked_by_water("meat_drop", Vector2.ZERO), failures, "Meat drops should ignore water blocking")
	world.free()


func _test_hills_block_navigation(failures: Array[String]) -> void:
	var world := _make_world_with_single_hill()
	TEST_UTILS.expect(world.is_creature_navigation_blocked(Vector2.ZERO), failures, "Hill centers should block navigation")
	TEST_UTILS.expect(not world.is_creature_navigation_blocked(Vector2(220.0, 0.0)), failures, "Positions far from the hill should remain navigable")
	world.free()


func _test_terrain_speed_multiplier_changes_in_water(failures: Array[String]) -> void:
	var world := _make_world_with_single_pond()
	var deep_speed: float = float(world.get_terrain_speed_multiplier(Vector2.ZERO))
	var shallow_point := _find_sample_point_for_zone(world, "shallow_water")
	var shallow_speed: float = float(world.get_terrain_speed_multiplier(shallow_point if shallow_point != Vector2.INF else Vector2(80.0, 0.0)))
	var land_speed: float = float(world.get_terrain_speed_multiplier(Vector2(160.0, 0.0)))
	TEST_UTILS.expect(deep_speed < shallow_speed, failures, "Deep water should slow movement more than shallow water")
	TEST_UTILS.expect(shallow_speed < land_speed, failures, "Shallow water should still slow movement more than land")
	world.free()


func _make_world_with_single_pond() -> Node2D:
	var world := WORLD_SCRIPT.new()
	world.pond_landmarks = [{
		"id": "test_pond",
		"position": Vector2.ZERO,
		"radius": 100.0
	}]
	world.pond_water_search_radius = 120.0
	world.hill_landmarks = []
	return world


func _make_world_with_single_hill() -> Node2D:
	var world := WORLD_SCRIPT.new()
	world.pond_landmarks = []
	world.pond_water_search_radius = 0.0
	world.hill_landmarks = [{
		"id": "test_hill",
		"position": Vector2.ZERO,
		"radius": 100.0
	}]
	return world


func _find_sample_point_for_zone(world: Node2D, target_zone: String) -> Vector2:
	for x in range(1, 201):
		var candidate := Vector2(float(x), 0.0)
		if world.get_water_zone(candidate) == target_zone:
			return candidate
	return Vector2.INF
