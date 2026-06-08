extends RefCounted

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_first_week_curve_covers_days_one_to_seven(failures)
	_test_first_week_curve_clamps_inside_week(failures)
	return failures


func _test_first_week_curve_covers_days_one_to_seven(failures: Array[String]) -> void:
	var day_one := Dictionary(GAME_BALANCE.get_first_week_difficulty(1))
	var day_three := Dictionary(GAME_BALANCE.get_first_week_difficulty(3))
	var day_seven := Dictionary(GAME_BALANCE.get_first_week_difficulty(7))
	TEST_UTILS.expect_equal(int(day_one.get("varnak_max_population", 0)), 1, failures, "Day 1 should keep Varnak pressure low")
	TEST_UTILS.expect_equal(int(day_three.get("varnak_max_population", 0)), 3, failures, "Day 3 should make Varnaks relevant")
	TEST_UTILS.expect_equal(int(day_seven.get("varnak_max_population", 0)), 7, failures, "Day 7 should be clearly harsher")
	TEST_UTILS.expect_close(float(day_one.get("small_prey_population_multiplier", 0.0)), 1.15, failures, "Day 1 should gently support small prey")


func _test_first_week_curve_clamps_inside_week(failures: Array[String]) -> void:
	var clamped_low := Dictionary(GAME_BALANCE.get_first_week_difficulty(0))
	var clamped_high := Dictionary(GAME_BALANCE.get_first_week_difficulty(99))
	TEST_UTILS.expect_equal(int(clamped_low.get("varnak_max_population", 0)), 1, failures, "Days below 1 should clamp to day 1")
	TEST_UTILS.expect_equal(int(clamped_high.get("varnak_max_population", 0)), 7, failures, "Days above 7 should clamp to day 7")
