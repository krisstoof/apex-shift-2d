extends RefCounted

const GAME_SESSION_SCRIPT := preload("res://scripts/systems/game_session.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_request_new_game_creates_bootstrap_seed(failures)
	_test_set_bootstrap_world_state_round_trips_landmarks(failures)
	_test_extract_bootstrap_world_data_reads_seed_and_landmarks(failures)
	return failures


func _test_request_new_game_creates_bootstrap_seed(failures: Array[String]) -> void:
	var game_session := GAME_SESSION_SCRIPT.new()
	game_session.request_new_game()
	var world_seed := int(game_session.get_bootstrap_world_seed())
	TEST_UTILS.expect(world_seed > 0, failures, "New game should prepare a positive bootstrap world seed")
	TEST_UTILS.expect_equal(game_session.get_bootstrap_landmarks().size(), 0, failures, "New game bootstrap should start without saved landmark overrides")


func _test_set_bootstrap_world_state_round_trips_landmarks(failures: Array[String]) -> void:
	var game_session := GAME_SESSION_SCRIPT.new()
	var landmarks := [{
		"id": "test_hill",
		"type": "hill",
		"position": {"x": 100.0, "y": -40.0},
		"radius": 220.0,
		"biome_id": "westwood"
	}]
	game_session.set_bootstrap_world_state(12345, landmarks)
	var bootstrap_landmarks: Array = game_session.get_bootstrap_landmarks()
	TEST_UTILS.expect_equal(int(game_session.get_bootstrap_world_seed()), 12345, failures, "Bootstrap world state should keep the provided seed")
	TEST_UTILS.expect_equal(bootstrap_landmarks.size(), 1, failures, "Bootstrap world state should keep saved landmark overrides")
	if bootstrap_landmarks.size() == 1:
		var landmark := Dictionary(bootstrap_landmarks[0])
		TEST_UTILS.expect_equal(str(landmark.get("id", "")), "test_hill", failures, "Bootstrap landmarks should keep their ids")


func _test_extract_bootstrap_world_data_reads_seed_and_landmarks(failures: Array[String]) -> void:
	var game_session := GAME_SESSION_SCRIPT.new()
	var bootstrap: Dictionary = game_session.call("_extract_bootstrap_world_data", {
		"world": {
			"world_seed": 777,
			"landmarks": [{
				"id": "pond_a",
				"type": "pond",
				"position": {"x": -20.0, "y": 88.0},
				"radius": 160.0,
				"biome_id": "hearth_meadow"
			}]
		}
	})
	TEST_UTILS.expect_equal(int(bootstrap.get("world_seed", 0)), 777, failures, "Bootstrap extraction should read world seed from save data")
	var landmarks: Array = Array(bootstrap.get("landmarks", []))
	TEST_UTILS.expect_equal(landmarks.size(), 1, failures, "Bootstrap extraction should read saved landmark overrides")
