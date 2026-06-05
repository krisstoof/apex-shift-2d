extends RefCounted

const LANDMARK_SERVICE := preload("res://scripts/world/landmark_service.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_landmark_service_splits_hills_and_ponds(failures)
	_test_landmark_service_calculates_nearest_landmark(failures)
	_test_landmark_service_returns_deep_copies(failures)
	return failures


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
