extends RefCounted

const GAME_SESSION_SCRIPT := preload("res://scripts/systems/game_session.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")
const SAVE_PATH := "user://savegame.json"


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_request_new_game_creates_bootstrap_seed(failures)
	_test_request_new_game_clears_load_save_requested(failures)
	_test_request_new_game_clears_pending_landmarks(failures)
	_test_request_new_game_generates_seed(failures)
	_test_set_bootstrap_world_state_round_trips_landmarks(failures)
	_test_set_bootstrap_world_state_sanitizes_landmarks(failures)
	_test_extract_bootstrap_world_data_reads_seed_and_landmarks(failures)
	_test_extract_bootstrap_world_data_falls_back_without_world_block(failures)
	_test_request_continue_without_save_sets_load_save_requested(failures)
	_test_request_continue_without_save_generates_fallback_seed(failures)
	_test_request_continue_with_save_loads_world_seed(failures)
	_test_request_continue_with_save_loads_only_valid_landmarks(failures)
	_test_consume_load_save_request_is_one_shot(failures)
	_test_request_new_game_after_continue_resets_state(failures)
	return failures


func _test_request_new_game_creates_bootstrap_seed(failures: Array[String]) -> void:
	var game_session := GAME_SESSION_SCRIPT.new()
	game_session.request_new_game()
	var world_seed := int(game_session.get_bootstrap_world_seed())
	TEST_UTILS.expect(world_seed > 0, failures, "New game should prepare a positive bootstrap world seed")
	TEST_UTILS.expect_equal(game_session.get_bootstrap_landmarks().size(), 0, failures, "New game bootstrap should start without saved landmark overrides")


func _test_request_new_game_clears_load_save_requested(failures: Array[String]) -> void:
	var game_session := GAME_SESSION_SCRIPT.new()
	game_session.load_save_requested = true
	game_session.request_new_game()
	TEST_UTILS.expect_equal(game_session.load_save_requested, false, failures, "New game should clear any pending continue request")


func _test_request_new_game_clears_pending_landmarks(failures: Array[String]) -> void:
	var game_session := GAME_SESSION_SCRIPT.new()
	game_session.pending_world_seed = 123
	game_session.pending_landmarks = [{"id": "old"}]
	game_session.request_new_game()
	TEST_UTILS.expect_equal(game_session.pending_landmarks.size(), 0, failures, "New game should clear pending landmark overrides")


func _test_request_new_game_generates_seed(failures: Array[String]) -> void:
	var game_session := GAME_SESSION_SCRIPT.new()
	game_session.pending_world_seed = 0
	game_session.request_new_game()
	TEST_UTILS.expect(game_session.pending_world_seed > 0, failures, "New game should generate a fresh seed")


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


func _test_set_bootstrap_world_state_sanitizes_landmarks(failures: Array[String]) -> void:
	var game_session := GAME_SESSION_SCRIPT.new()
	game_session.set_bootstrap_world_state(0, [{"id": "valid"}, "invalid_landmark"])
	TEST_UTILS.expect(game_session.get_bootstrap_world_seed() > 0, failures, "Bootstrap world state should generate a seed when zero is supplied")
	TEST_UTILS.expect_equal(game_session.get_bootstrap_landmarks().size(), 1, failures, "Bootstrap world state should discard invalid landmark entries")


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


func _test_extract_bootstrap_world_data_falls_back_without_world_block(failures: Array[String]) -> void:
	var game_session := GAME_SESSION_SCRIPT.new()
	var bootstrap: Dictionary = game_session.call("_extract_bootstrap_world_data", {
		"version": 1,
		"player": {"position": {"x": 0.0, "y": 0.0}}
	})
	TEST_UTILS.expect(int(bootstrap.get("world_seed", 0)) > 0, failures, "Bootstrap extraction should generate a fallback world seed when an older save has no world block")
	var landmarks: Array = Array(bootstrap.get("landmarks", []))
	TEST_UTILS.expect_equal(landmarks.size(), 0, failures, "Bootstrap extraction should keep an empty landmark override list for older saves without world data")


func _test_request_continue_without_save_sets_load_save_requested(failures: Array[String]) -> void:
	_clear_save_file()
	var game_session := GAME_SESSION_SCRIPT.new()
	game_session.request_continue()
	TEST_UTILS.expect_equal(game_session.load_save_requested, true, failures, "Continue should mark the load-save request even without a save file")
	_clear_save_file()


func _test_request_continue_without_save_generates_fallback_seed(failures: Array[String]) -> void:
	_clear_save_file()
	var game_session := GAME_SESSION_SCRIPT.new()
	game_session.request_continue()
	TEST_UTILS.expect(game_session.pending_world_seed > 0, failures, "Continue without a save should fall back to a generated seed")
	TEST_UTILS.expect_equal(game_session.pending_landmarks.size(), 0, failures, "Continue without a save should keep landmarks empty")
	_clear_save_file()


func _test_request_continue_with_save_loads_world_seed(failures: Array[String]) -> void:
	_write_save_file({
		"world": {
			"world_seed": 12345,
			"landmarks": [
				{"id": "valid_landmark", "type": "pond"},
				"invalid_landmark"
			]
		}
	})
	var game_session := GAME_SESSION_SCRIPT.new()
	game_session.request_continue()
	TEST_UTILS.expect_equal(game_session.load_save_requested, true, failures, "Continue should keep the load-save request active until consumed")
	TEST_UTILS.expect_equal(game_session.pending_world_seed, 12345, failures, "Continue should load the saved world seed")
	TEST_UTILS.expect_equal(game_session.pending_landmarks.size(), 1, failures, "Continue should filter invalid landmarks")
	if game_session.pending_landmarks.size() == 1:
		TEST_UTILS.expect_equal(str(game_session.pending_landmarks[0].get("id", "")), "valid_landmark", failures, "Continue should keep valid landmark data")
	_clear_save_file()


func _test_request_continue_with_save_loads_only_valid_landmarks(failures: Array[String]) -> void:
	_write_save_file({
		"world": {
			"world_seed": 777,
			"landmarks": [
				{"id": "keep_me"},
				"discard_me",
				{"id": "keep_me_too"}
			]
		}
	})
	var game_session := GAME_SESSION_SCRIPT.new()
	game_session.request_continue()
	TEST_UTILS.expect_equal(game_session.pending_landmarks.size(), 2, failures, "Continue should retain only dictionary landmarks")
	_clear_save_file()


func _test_consume_load_save_request_is_one_shot(failures: Array[String]) -> void:
	var game_session := GAME_SESSION_SCRIPT.new()
	game_session.load_save_requested = true
	TEST_UTILS.expect_equal(game_session.consume_load_save_request(), true, failures, "Consume should return the current request state")
	TEST_UTILS.expect_equal(game_session.consume_load_save_request(), false, failures, "Consume should clear the request after the first read")


func _test_request_new_game_after_continue_resets_state(failures: Array[String]) -> void:
	_write_save_file({
		"world": {
			"world_seed": 12345,
			"landmarks": [{"id": "valid_landmark"}]
		}
	})
	var game_session := GAME_SESSION_SCRIPT.new()
	game_session.request_continue()
	game_session.request_new_game()
	TEST_UTILS.expect_equal(game_session.load_save_requested, false, failures, "New game after continue should clear continue state")
	TEST_UTILS.expect_equal(game_session.get_bootstrap_landmarks().size(), 0, failures, "New game after continue should clear landmarks")
	TEST_UTILS.expect(game_session.get_bootstrap_world_seed() > 0, failures, "New game after continue should still prepare a seed")
	_clear_save_file()


func _write_save_file(save_data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data))


func _clear_save_file() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
