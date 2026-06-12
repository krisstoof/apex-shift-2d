extends RefCounted

const DAY_NIGHT_SYSTEM := preload("res://scripts/systems/day_night_system.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_default_day_is_one(failures)
	_test_debug_next_day_increments_day(failures)
	_test_process_wraps_time_and_starts_new_day(failures)
	_test_save_load_round_trip(failures)
	_test_restore_emits_day_changed(failures)
	_test_phase_boundaries_are_correct(failures)
	return failures


func _test_default_day_is_one(failures: Array[String]) -> void:
	var system := DAY_NIGHT_SYSTEM.new()
	system._ready()
	TEST_UTILS.expect_equal(system.get_day(), 1, failures, "DayNightSystem should start on day 1")


func _test_debug_next_day_increments_day(failures: Array[String]) -> void:
	var system := DAY_NIGHT_SYSTEM.new()
	system._ready()
	system.debug_next_day()
	TEST_UTILS.expect_equal(system.get_day(), 2, failures, "debug_next_day should advance to the next day")


func _test_process_wraps_time_and_starts_new_day(failures: Array[String]) -> void:
	var system := DAY_NIGHT_SYSTEM.new()
	system._ready()
	system.day_length_seconds = 1.0
	system.time_of_day = 0.95
	system._process(0.10)
	TEST_UTILS.expect_equal(system.get_day(), 2, failures, "_process should advance the day after wrapping")
	TEST_UTILS.expect(system.time_of_day < system.day_length_seconds, failures, "_process should keep time_of_day within the day length")


func _test_save_load_round_trip(failures: Array[String]) -> void:
	var system := DAY_NIGHT_SYSTEM.new()
	system._ready()
	system.day = 4
	system.time_of_day = 7.5
	system.night_amount = 0.25
	var save_data := system.get_save_data()
	var restored := DAY_NIGHT_SYSTEM.new()
	restored._ready()
	restored.restore_from_data(save_data)
	TEST_UTILS.expect_equal(restored.get_save_data(), save_data, failures, "DayNightSystem save/load should round-trip cleanly")


func _test_restore_emits_day_changed(failures: Array[String]) -> void:
	var system := DAY_NIGHT_SYSTEM.new()
	system._ready()
	var emitted_days: Array[int] = []
	system.day_changed.connect(func(day: int):
		emitted_days.append(day)
	)
	system.restore_from_data({
		"day": 5,
		"time_of_day": 10.0,
		"night_amount": 0.0
	})
	TEST_UTILS.expect_equal(emitted_days.size(), 1, failures, "restore_from_data should emit day_changed once")
	if emitted_days.size() == 1:
		TEST_UTILS.expect_equal(emitted_days[0], 5, failures, "restore_from_data should emit the restored day")


func _test_phase_boundaries_are_correct(failures: Array[String]) -> void:
	var system := DAY_NIGHT_SYSTEM.new()
	system._ready()
	system.time_of_day = system.day_length_seconds * (5.0 / 24.0)
	TEST_UTILS.expect_equal(system.get_phase_label(), "Dawn", failures, "5:00 should be dawn")
	system.time_of_day = system.day_length_seconds * (6.0 / 24.0)
	TEST_UTILS.expect_equal(system.get_phase_label(), "Day", failures, "6:00 should be day")
	system.time_of_day = system.day_length_seconds * (20.0 / 24.0)
	TEST_UTILS.expect_equal(system.get_phase_label(), "Dusk", failures, "20:00 should be dusk")
	system.time_of_day = system.day_length_seconds * (21.0 / 24.0)
	TEST_UTILS.expect_equal(system.get_phase_label(), "Night", failures, "21:00 should be night")
