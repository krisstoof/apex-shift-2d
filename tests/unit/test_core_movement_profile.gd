extends RefCounted

const MOVEMENT_PROFILE := preload("res://scripts/core/common/movement_profile.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_defaults(failures)
	_test_speed_calculation(failures)
	return failures

func _test_defaults(failures: Array[String]) -> void:
	var profile := MOVEMENT_PROFILE.new()
	TEST_UTILS.expect_close(profile.walk_speed, 180.0, failures, "Default walk speed should match Player defaults")
	TEST_UTILS.expect_close(profile.run_speed, 290.0, failures, "Default run speed should match Player defaults")

func _test_speed_calculation(failures: Array[String]) -> void:
	var profile := MOVEMENT_PROFILE.new(150.0, 250.0)
	TEST_UTILS.expect_close(profile.get_movement_speed(false, 0.75, 0.5), 56.25, failures, "Walk speed should multiply all factors")
	TEST_UTILS.expect_close(profile.get_movement_speed(true, 1.0, 0.8), 200.0, failures, "Run speed should multiply all factors")
