extends RefCounted

const MOVEMENT_SPIKE_TRACKER := preload("res://scripts/core/common/movement_spike_tracker.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_spike_tracking(failures)
	return failures

func _test_spike_tracking(failures: Array[String]) -> void:
	var tracker := MOVEMENT_SPIKE_TRACKER.new()
	TEST_UTILS.expect(not tracker.record_movement_spike(Vector2.ZERO, Vector2(10.0, 0.0), 20.0), failures, "Distances below the warning threshold should not count as spikes")
	TEST_UTILS.expect_equal(tracker.spike_count, 0, failures, "Small movement should not increment the spike counter")
	TEST_UTILS.expect(tracker.record_movement_spike(Vector2.ZERO, Vector2(30.0, 0.0), 20.0), failures, "Distances above the warning threshold should count as spikes")
	TEST_UTILS.expect_equal(tracker.spike_count, 1, failures, "Large movement should increment the spike counter")
	TEST_UTILS.expect_close(tracker.max_spike_distance, 30.0, failures, "Tracker should remember the largest spike distance")
