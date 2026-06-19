extends RefCounted
class_name RuntimeProfiler

static var enabled := false
static var _frame_times: Dictionary = {}
static var _rolling: Dictionary = {}
static var _rolling_window_seconds := 1.0
static var _rolling_window_start_usec := 0
static var _rolling_sample_count := 0
static var _active_scope_starts: Dictionary = {}
static var _last_frame_snapshot: Dictionary = {}
static var _last_frame_total_ms: float = 0.0
static var _last_frame_max_scope := ""
static var _last_frame_max_scope_ms: float = 0.0
static var _frame_sequence: int = 0

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

static func reset_frame_snapshot() -> void:
	_reset_frame()

static func get_and_reset_frame_snapshot() -> Dictionary:
	var snapshot := get_frame_snapshot()
	_store_last_frame_snapshot(snapshot)
	_reset_frame()
	return snapshot

static func consume_frame_snapshot() -> Dictionary:
	return get_and_reset_frame_snapshot()

static func get_last_frame_snapshot() -> Dictionary:
	return _last_frame_snapshot.duplicate(true)

static func get_last_frame_summary() -> Dictionary:
	return {
		"frame_sequence": _frame_sequence,
		"total_ms": _last_frame_total_ms,
		"max_scope": _last_frame_max_scope,
		"max_scope_ms": _last_frame_max_scope_ms,
		"scope_count": _last_frame_snapshot.size()
	}

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
	_last_frame_snapshot.clear()
	_last_frame_total_ms = 0.0
	_last_frame_max_scope = ""
	_last_frame_max_scope_ms = 0.0
	_frame_sequence = 0

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

static func get_top_scopes_from_snapshot(snapshot: Dictionary, limit: int = 8) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	for key_value in snapshot.keys():
		ranked.append({
			"name": str(key_value),
			"ms": float(snapshot.get(key_value, 0.0))
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("ms", 0.0)) > float(b.get("ms", 0.0))
	)
	if ranked.size() > limit:
		ranked.resize(limit)
	return ranked

static func get_top_scope_from_snapshot(snapshot: Dictionary) -> String:
	var top_scopes := get_top_scopes_from_snapshot(snapshot, 1)
	if top_scopes.is_empty():
		return ""
	var top := Dictionary(top_scopes[0])
	return "%s:%.1fms" % [str(top.get("name", "")), float(top.get("ms", 0.0))]

static func get_snapshot_total_ms(snapshot: Dictionary) -> float:
	var total := 0.0
	for key in snapshot.keys():
		total += float(snapshot.get(key, 0.0))
	return total

static func get_snapshot_max_scope(snapshot: Dictionary) -> Dictionary:
	var max_scope := ""
	var max_ms := 0.0
	for key in snapshot.keys():
		var value := float(snapshot.get(key, 0.0))
		if value >= max_ms:
			max_ms = value
			max_scope = str(key)
	return {
		"name": max_scope,
		"ms": max_ms
	}

static func is_snapshot_suspect(snapshot: Dictionary, wall_frame_delta_ms: float, performance_process_ms: float) -> bool:
	if snapshot.is_empty():
		return false
	var max_scope := get_snapshot_max_scope(snapshot)
	var max_scope_ms := float(max_scope.get("ms", 0.0))
	if wall_frame_delta_ms > 0.0 and max_scope_ms > wall_frame_delta_ms * 1.15:
		return true
	if performance_process_ms > 0.0 and max_scope_ms > maxf(performance_process_ms * 4.0, performance_process_ms + 120.0):
		return true
	return false

static func _store_last_frame_snapshot(snapshot: Dictionary) -> void:
	_last_frame_snapshot = snapshot.duplicate(true)
	_last_frame_total_ms = get_snapshot_total_ms(snapshot)
	_last_frame_max_scope = ""
	_last_frame_max_scope_ms = 0.0
	for key in snapshot.keys():
		var value := float(snapshot.get(key, 0.0))
		if value >= _last_frame_max_scope_ms:
			_last_frame_max_scope_ms = value
			_last_frame_max_scope = str(key)
	_frame_sequence += 1
