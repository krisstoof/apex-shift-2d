extends RefCounted

const LANDMARK_SERVICE := preload("res://scripts/world/landmark_service.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_landmark_service_resolves_initial_layout(failures)
	_test_landmark_service_resolves_restored_layout(failures)
	_test_landmark_service_splits_hills_and_ponds(failures)
	_test_landmark_service_calculates_nearest_landmark(failures)
	_test_landmark_service_exports_save_data(failures)
	_test_landmark_service_returns_deep_copies(failures)
	return failures


func _test_landmark_service_resolves_initial_layout(failures: Array[String]) -> void:
	var service := LANDMARK_SERVICE.new()
	var generated_calls: Array[int] = []
	var generated_landmarks := [{
		"id": "generated_pond",
		"type": "pond",
		"position": Vector2.ZERO,
		"radius": 90.0
	}]
	var resolved_generated: Dictionary = service.resolve_initial_layout(
		0,
		[],
		0,
		func(seed: int) -> Array:
			generated_calls.append(seed)
			return generated_landmarks,
		func(_data: Array) -> Array:
			return []
	)
	TEST_UTILS.expect_equal(int(resolved_generated.get("world_seed", 0)), 1, failures, "Initial landmark resolution should default world seed to 1 when none is provided")
	TEST_UTILS.expect_equal(generated_calls.size(), 1, failures, "Initial landmark resolution should generate layout when bootstrap data is missing")
	TEST_UTILS.expect_equal(Array(resolved_generated.get("landmarks", [])).size(), 1, failures, "Initial landmark resolution should return generated landmarks")
	var bootstrap_landmarks := [{
		"id": "bootstrap_hill",
		"type": "hill",
		"position": Vector2(10.0, 0.0),
		"radius": 80.0
	}]
	var resolved_bootstrap: Dictionary = service.resolve_initial_layout(
		4,
		bootstrap_landmarks,
		7,
		func(_seed: int) -> Array:
			return [],
		func(data: Array) -> Array:
			return data
	)
	TEST_UTILS.expect_equal(int(resolved_bootstrap.get("world_seed", 0)), 7, failures, "Initial landmark resolution should prefer bootstrap world seed when present")
	TEST_UTILS.expect_equal(Array(resolved_bootstrap.get("landmarks", [])).size(), 1, failures, "Initial landmark resolution should restore bootstrap landmarks instead of generating")


func _test_landmark_service_resolves_restored_layout(failures: Array[String]) -> void:
	var service := LANDMARK_SERVICE.new()
	var generated_calls: Array[int] = []
	var restored_empty: Dictionary = service.resolve_restored_layout(
		12,
		[],
		0,
		func(seed: int) -> Array:
			generated_calls.append(seed)
			return [{
				"id": "generated_hill",
				"type": "hill",
				"position": Vector2.ZERO,
				"radius": 120.0
			}],
		func(_data: Array) -> Array:
			return []
	)
	TEST_UTILS.expect_equal(int(restored_empty.get("world_seed", 0)), 12, failures, "Restored landmark resolution should keep the current world seed when no restored seed is provided")
	TEST_UTILS.expect_equal(generated_calls.size(), 1, failures, "Restored landmark resolution should regenerate layout if restored data is empty")
	var restored_data := [{
		"id": "restored_pond",
		"type": "pond",
		"position": Vector2(30.0, -10.0),
		"radius": 95.0
	}]
	var restored_layout: Dictionary = service.resolve_restored_layout(
		12,
		restored_data,
		44,
		func(_seed: int) -> Array:
			return [],
		func(data: Array) -> Array:
			return data
	)
	TEST_UTILS.expect_equal(int(restored_layout.get("world_seed", 0)), 44, failures, "Restored landmark resolution should prefer explicit restored world seed")
	TEST_UTILS.expect_equal(str(Dictionary(Array(restored_layout.get("landmarks", []))[0]).get("id", "")), "restored_pond", failures, "Restored landmark resolution should return restored landmarks when available")


func _test_landmark_service_splits_hills_and_ponds(failures: Array[String]) -> void:
	var service := LANDMARK_SERVICE.new()
	service.set_landmarks([
		{
			"id": "hill_alpha",
			"type": "hill",
			"position": Vector2(-120.0, 40.0),
			"radius": 180.0
		},
		{
			"id": "pond_alpha",
			"type": "pond",
			"position": Vector2(320.0, -80.0),
			"radius": 140.0
		},
		{
			"id": "pond_beta",
			"type": "pond",
			"position": Vector2(620.0, 120.0),
			"radius": 90.0
		}
	])
	var counts := service.get_landmark_counts()
	TEST_UTILS.expect_equal(int(counts.get("generated", 0)), 3, failures, "LandmarkService should keep the full generated landmark count")
	TEST_UTILS.expect_equal(int(counts.get("hill", 0)), 1, failures, "LandmarkService should split hill landmarks into their own list")
	TEST_UTILS.expect_equal(int(counts.get("pond", 0)), 2, failures, "LandmarkService should split pond landmarks into their own list")
	TEST_UTILS.expect_close(service.get_pond_water_search_radius(), 168.0, failures, "LandmarkService should derive pond water search radius from the largest pond")


func _test_landmark_service_calculates_nearest_landmark(failures: Array[String]) -> void:
	var service := LANDMARK_SERVICE.new()
	service.set_landmarks([
		{
			"id": "hill_alpha",
			"type": "hill",
			"position": Vector2(-100.0, 0.0),
			"radius": 150.0
		},
		{
			"id": "pond_alpha",
			"type": "pond",
			"position": Vector2(220.0, 0.0),
			"radius": 110.0
		}
	])
	var nearest := service.get_nearest_landmark_data(Vector2(180.0, 10.0))
	TEST_UTILS.expect_equal(str(nearest.get("id", "")), "pond_alpha", failures, "LandmarkService should return the nearest landmark by distance")
	TEST_UTILS.expect(float(nearest.get("distance_to_position", INF)) < 60.0, failures, "LandmarkService should report the computed distance for the nearest landmark")


func _test_landmark_service_exports_save_data(failures: Array[String]) -> void:
	var service := LANDMARK_SERVICE.new()
	service.set_landmarks([
		{
			"id": "pond_alpha",
			"type": "pond",
			"position": Vector2(30.0, -10.0),
			"radius": 95.0,
			"biome_id": "westwood",
			"gameplay_tags": ["water_source"]
		}
	])
	var save_data := service.get_landmark_save_data()
	TEST_UTILS.expect_equal(save_data.size(), 1, failures, "LandmarkService should export one save entry per landmark")
	if save_data.size() == 1:
		var exported := Dictionary(save_data[0])
		var position_data := Dictionary(exported.get("position", {}))
		TEST_UTILS.expect_equal(str(exported.get("id", "")), "pond_alpha", failures, "LandmarkService should preserve landmark ids in save export")
		TEST_UTILS.expect_equal(str(exported.get("type", "")), "pond", failures, "LandmarkService should preserve landmark types in save export")
		TEST_UTILS.expect_close(float(position_data.get("x", 0.0)), 30.0, failures, "LandmarkService should serialize landmark position X")
		TEST_UTILS.expect_close(float(position_data.get("y", 0.0)), -10.0, failures, "LandmarkService should serialize landmark position Y")
		TEST_UTILS.expect_close(float(exported.get("radius", 0.0)), 95.0, failures, "LandmarkService should preserve landmark radii in save export")


func _test_landmark_service_returns_deep_copies(failures: Array[String]) -> void:
	var service := LANDMARK_SERVICE.new()
	service.set_landmarks([
		{
			"id": "pond_alpha",
			"type": "pond",
			"position": Vector2.ZERO,
			"radius": 100.0,
			"gameplay_tags": ["water_source"]
		}
	])
	var landmarks := service.get_landmarks()
	var mutated := Dictionary(landmarks[0])
	mutated["id"] = "changed"
	var second_read := service.get_landmarks()
	TEST_UTILS.expect_equal(str(Dictionary(second_read[0]).get("id", "")), "pond_alpha", failures, "LandmarkService should not leak caller mutations back into its stored layout")
