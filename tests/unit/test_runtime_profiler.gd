extends RefCounted

const RUNTIME_PROFILER := preload("res://scripts/debug/runtime_profiler.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_consume_frame_snapshot_resets_current_frame(failures)
	_test_snapshot_max_scope(failures)
	_test_snapshot_suspect_when_scope_exceeds_wall_delta(failures)
	return failures


func _test_consume_frame_snapshot_resets_current_frame(failures: Array[String]) -> void:
	RUNTIME_PROFILER.reset()
	RUNTIME_PROFILER.set_enabled(true)

	RUNTIME_PROFILER.add_time("minimap_process_ms", 10.0)
	var snapshot := RUNTIME_PROFILER.consume_frame_snapshot()
	var after := RUNTIME_PROFILER.get_frame_snapshot()

	TEST_UTILS.expect_equal(float(snapshot.get("minimap_process_ms", 0.0)), 10.0, failures, "Consumed snapshot should contain frame scope")
	TEST_UTILS.expect_equal(after.is_empty(), true, failures, "Profiler frame snapshot should reset after consume")

	RUNTIME_PROFILER.set_enabled(false)
	RUNTIME_PROFILER.reset()


func _test_snapshot_max_scope(failures: Array[String]) -> void:
	var snapshot := {
		"world_process_total_ms": 2.0,
		"minimap_process_ms": 5.0,
		"hud_total_ms": 1.0
	}

	var max_scope := RUNTIME_PROFILER.get_snapshot_max_scope(snapshot)

	TEST_UTILS.expect_equal(str(max_scope.get("name", "")), "minimap_process_ms", failures, "Profiler should detect max scope")
	TEST_UTILS.expect_equal(float(max_scope.get("ms", 0.0)), 5.0, failures, "Profiler should detect max scope ms")


func _test_snapshot_suspect_when_scope_exceeds_wall_delta(failures: Array[String]) -> void:
	var snapshot := {
		"minimap_process_ms": 1400.0
	}

	var suspect := RUNTIME_PROFILER.is_snapshot_suspect(snapshot, 100.0, 10.0)

	TEST_UTILS.expect_equal(suspect, true, failures, "Profiler snapshot should be suspect when a scope exceeds wall delta")
