extends RefCounted

const GAME_CLOCK_SYSTEM := preload("res://scripts/core/time/game_clock_system.gd")
const GAME_CLOCK_STATE := preload("res://scripts/core/time/game_clock_state.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_clock_can_advance_multiple_days_without_scene(failures)
	_test_phase_boundaries_match_day_night_adapter(failures)
	_test_save_load_round_trip_preserves_clock_state(failures)
	_test_day_progression_event_payload_contains_legacy_fields(failures)
	return failures


func _test_clock_can_advance_multiple_days_without_scene(failures: Array[String]) -> void:
	var clock := GAME_CLOCK_SYSTEM.new()
	clock.configure(10.0, GameClockState.START_HOUR)
	var events := clock.tick(35.0)
	TEST_UTILS.expect_equal(events.size(), 3, failures, "Core clock should simulate several days without a scene")
	TEST_UTILS.expect_equal(clock.get_day(), 4, failures, "Core clock should advance the day for every full wrapped day")
	TEST_UTILS.expect(clock.state.time_of_day < clock.state.day_length_seconds, failures, "Core clock should keep time inside the current day")


func _test_phase_boundaries_match_day_night_adapter(failures: Array[String]) -> void:
	var state := GAME_CLOCK_STATE.new()
	state.day_length_seconds = 180.0
	state.set_hour(5.0)
	TEST_UTILS.expect_equal(state.get_phase_label(), "Dawn", failures, "5:00 should be dawn")
	state.set_hour(6.0)
	TEST_UTILS.expect_equal(state.get_phase_label(), "Day", failures, "6:00 should be day")
	state.set_hour(20.0)
	TEST_UTILS.expect_equal(state.get_phase_label(), "Dusk", failures, "20:00 should be dusk")
	state.set_hour(21.0)
	TEST_UTILS.expect_equal(state.get_phase_label(), "Night", failures, "21:00 should be night")


func _test_save_load_round_trip_preserves_clock_state(failures: Array[String]) -> void:
	var clock := GAME_CLOCK_SYSTEM.new()
	clock.configure(120.0, 8.0)
	clock.set_public_state(5, 33.0, 120.0, 2.0)
	var data := clock.get_save_data()
	var restored := GAME_CLOCK_SYSTEM.new()
	restored.load_save_data(data)
	TEST_UTILS.expect_equal(restored.get_save_data(), data, failures, "Core clock save/load should round-trip")


func _test_day_progression_event_payload_contains_legacy_fields(failures: Array[String]) -> void:
	var clock := GAME_CLOCK_SYSTEM.new()
	clock.configure(60.0, 8.0)
	var event := clock.start_new_day("unit_test")
	var payload := event.to_dictionary()
	TEST_UTILS.expect_equal(int(payload.get("day", 0)), 2, failures, "Day progression payload should include the new day")
	TEST_UTILS.expect_equal(str(payload.get("reason", "")), "unit_test", failures, "Day progression payload should include the reason")
	TEST_UTILS.expect(payload.has("clock_state"), failures, "Day progression payload should include clock_state for core consumers")
