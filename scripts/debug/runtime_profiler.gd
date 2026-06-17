extends RefCounted
class_name RuntimeProfiler

static var enabled := false
static var _frame_times: Dictionary = {}
static var _rolling: Dictionary = {}
static var _rolling_window_seconds := 1.0
static var _rolling_window_start_usec := 0
static var _rolling_sample_count := 0
static var _active_scope_starts: Dictionary = {}

static func set_enabled(value: bool) -> void:
	enabled = value
	if enabled and _rolling_window_start_usec == 0:
		_rolling_window_start_usec = Time.get_ticks_usec()

static func begin_scope(_scope_name: String) -> void:
	if not enabled:
		return
	var stack: Array = Array(_active_scope_starts.get(_scope_name, []))
	stack.append(Time.get_ticks_usec())
	_active_scope_starts[_scope_name] = stack

static func end_scope(scope_name: String) -> void:
	if not enabled:
		return
	var stack: Array = Array(_active_scope_starts.get(scope_name, []))
	if stack.is_empty():
		return
	var started_at := int(stack.pop_back())
	_active_scope_starts[scope_name] = stack
	var elapsed_ms := float(Time.get_ticks_usec() - started_at) / 1000.0
	add_time(scope_name, elapsed_ms)

static func add_time(scope_name: String, ms: float) -> void:
	if not enabled:
		return
	_frame_times[scope_name] = float(_frame_times.get(scope_name, 0.0)) + ms

static func get_frame_snapshot() -> Dictionary:
	return _frame_times.duplicate(true)

static func get_and_reset_frame_snapshot() -> Dictionary:
	var snapshot := get_frame_snapshot()
	_reset_frame()
	return snapshot

static func get_rolling_summary() -> Dictionary:
	return _build_summary(_rolling)

static func record_frame_snapshot(snapshot: Dictionary) -> void:
	if not enabled:
		return
	for key in snapshot.keys():
		var value := float(snapshot.get(key, 0.0))
		var stats := Dictionary(_rolling.get(key, {"sum": 0.0, "max": 0.0, "count": 0}))
		stats["sum"] = float(stats.get("sum", 0.0)) + value
		stats["max"] = maxf(float(stats.get("max", 0.0)), value)
		stats["count"] = int(stats.get("count", 0)) + 1
		_rolling[key] = stats
	_rolling_sample_count += 1
	var now_usec := Time.get_ticks_usec()
	if now_usec - _rolling_window_start_usec >= int(_rolling_window_seconds * 1000000.0):
		_rolling_window_start_usec = now_usec
		_rolling_sample_count = 0
		for key in _rolling.keys():
			var stats := Dictionary(_rolling[key])
			stats["sum"] = 0.0
			stats["max"] = 0.0
			stats["count"] = 0
			_rolling[key] = stats

static func reset() -> void:
	_reset_frame()
	_rolling.clear()
	_rolling_window_start_usec = 0
	_rolling_sample_count = 0
	_active_scope_starts.clear()

static func _reset_frame() -> void:
	_frame_times.clear()

static func _build_summary(source: Dictionary) -> Dictionary:
	var subsystems: Dictionary = {}
	var top_name := ""
	var top_avg := 0.0
	var top_max := 0.0
	for key_value in source.keys():
		var key := str(key_value)
		var stats: Dictionary = Dictionary(source.get(key, {}))
		var count: int = maxi(1, int(stats.get("count", 0)))
		var avg := float(stats.get("sum", 0.0)) / float(count)
		var max_ms := float(stats.get("max", 0.0))
		subsystems[key] = {"avg": avg, "max": max_ms, "count": count}
		if avg >= top_avg:
			top_avg = avg
			top_max = max_ms
			top_name = str(key)
	return {
		"enabled": enabled,
		"window_seconds": _rolling_window_seconds,
		"top_subsystem": top_name,
		"top_subsystem_avg_ms": top_avg,
		"top_subsystem_max_ms": top_max,
		"samples_with_render_attribution": _rolling_sample_count,
		"subsystems": subsystems
	}
