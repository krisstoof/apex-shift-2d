@tool
extends Node

const MAIN_SCENE := preload("res://scenes/main.tscn")
const BENCHMARK_RUNNER := preload("res://scripts/systems/benchmark_runner.gd")
const SUMMARY_OUTPUT_PATH := "res://tmp/benchmark_summary.txt"

var _main_scene: Node
var _benchmark_runner: Node
var _benchmark_started := false
var _wait_frames := 0
var _preset_name := "normal"
var _duration_seconds := 60.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_cli_args()
	_main_scene = MAIN_SCENE.instantiate()
	get_tree().root.add_child(_main_scene)
	call_deferred("_run")


func _run() -> void:
	await _wait_for_world_ready()
	_benchmark_runner = BENCHMARK_RUNNER.new()
	_main_scene.add_child(_benchmark_runner)
	if _benchmark_runner.has_signal("finished"):
		_benchmark_runner.finished.connect(_on_benchmark_finished)
	if _benchmark_runner.has_signal("benchmark_progress"):
		_benchmark_runner.benchmark_progress.connect(_on_benchmark_progress)
	var started: bool = _benchmark_runner.call("start", _preset_name) == true
	if not started:
		push_error("[BenchmarkHarness] Benchmark failed to start")
		get_tree().quit(1)
		return
	_benchmark_started = true
	print("[BenchmarkHarness] Benchmark started preset=%s duration=%.1f" % [_preset_name, _duration_seconds])
	_override_benchmark_duration()


func _wait_for_world_ready() -> void:
	var deadline_frames := 600
	while deadline_frames > 0:
		deadline_frames -= 1
		await get_tree().process_frame
		var world := _find_node_by_name(_main_scene, "World")
		var hud := _find_node_by_name(_main_scene, "HUD")
		var player := _find_node_by_name(_main_scene, "Player")
		if world != null and hud != null and player != null:
			if world.has_method("is_boot_ready") and world.is_boot_ready():
				return
			if world.has_method("get_boot_progress_state"):
				var boot := Dictionary(world.get_boot_progress_state())
				if bool(boot.get("boot_ready", false)):
					return
	return


func _find_node_by_name(root: Node, name: String) -> Node:
	if root == null:
		return null
	if root.name == name:
		return root
	for child in root.get_children():
		var found := _find_node_by_name(child as Node, name)
		if found != null:
			return found
	return null


func _on_benchmark_progress(elapsed_seconds: float, remaining_seconds: float) -> void:
	print("[BenchmarkHarness] progress=%.1fs remaining=%.1fs" % [elapsed_seconds, remaining_seconds])


func _on_benchmark_finished(log_path: String, json_path: String) -> void:
	print("[BenchmarkHarness] finished")
	print("[BenchmarkHarness] log=%s" % log_path)
	print("[BenchmarkHarness] json=%s" % json_path)
	var json_text := FileAccess.get_file_as_string(json_path)
	if not json_text.is_empty():
		var parsed: Variant = JSON.parse_string(json_text)
		if parsed is Dictionary:
			var report := Dictionary(parsed)
			var summary_path := _write_summary(report, log_path, json_path)
			if not summary_path.is_empty():
				print("[BenchmarkHarness] summary=%s" % summary_path)
	get_tree().quit(0)


func _write_summary(report: Dictionary, log_path: String, json_path: String) -> String:
	var threshold_validation := Dictionary(report.get("threshold_validation", {}))
	var runtime_hitch_summary := Dictionary(report.get("runtime_hitch_summary", {}))
	var summary_path := ProjectSettings.globalize_path(SUMMARY_OUTPUT_PATH)
	var summary_dir := summary_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(summary_dir):
		var dir_error := DirAccess.make_dir_recursive_absolute(summary_dir)
		if dir_error != OK:
			push_error("[BenchmarkHarness] Could not create summary directory: %s (error %d)" % [summary_dir, dir_error])
			return ""
	var summary_lines: Array[String] = []
	summary_lines.append("benchmark_name=%s" % str(report.get("benchmark_name", "unknown")))
	summary_lines.append("benchmark_preset=%s" % str(report.get("benchmark_preset", "unknown")))
	summary_lines.append("threshold_status=%s" % str(threshold_validation.get("status", "unknown")))
	summary_lines.append("sample_collection_ms=%.2f" % float(report.get("benchmark_sample_collection_ms", 0.0)))
	summary_lines.append("sample_build_ms=%.2f" % float(report.get("benchmark_sample_build_ms", 0.0)))
	summary_lines.append("realtime_hitch_count=%d" % int(report.get("realtime_hitch_count", 0)))
	summary_lines.append("max_realtime_delta_ms=%d" % int(report.get("max_realtime_delta_ms", 0)))
	summary_lines.append("hitch_summary=%s" % _format_hitch_summary(runtime_hitch_summary))
	summary_lines.append("log_path=%s" % log_path)
	summary_lines.append("json_path=%s" % json_path)
	var file := FileAccess.open(summary_path, FileAccess.WRITE)
	if file == null:
		push_error("[BenchmarkHarness] Could not write summary file: %s" % summary_path)
		return ""
	file.store_string("\n".join(summary_lines))
	file.flush()
	return summary_path


func _format_hitch_summary(runtime_hitch_summary: Dictionary) -> String:
	var by_scope: Dictionary = Dictionary(runtime_hitch_summary.get("hitch_count_by_scope", {}))
	if by_scope.is_empty():
		return "none"
	var max_by_scope: Dictionary = Dictionary(runtime_hitch_summary.get("max_delta_by_scope", {}))
	var last_by_scope: Dictionary = Dictionary(runtime_hitch_summary.get("last_hitch_delta_by_scope", {}))
	var parts: Array[String] = []
	for scope_name in by_scope.keys():
		parts.append("%s:%d/%d/%d" % [
			str(scope_name),
			int(by_scope.get(scope_name, 0)),
			int(max_by_scope.get(scope_name, 0)),
			int(last_by_scope.get(scope_name, 0))
		])
	parts.sort()
	return ", ".join(parts)


func _parse_cli_args() -> void:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--benchmark-preset="):
			_preset_name = arg.split("=", false, 1)[1]
		elif arg.begins_with("--benchmark-duration="):
			_duration_seconds = maxf(float(arg.split("=", false, 1)[1]), 1.0)


func _override_benchmark_duration() -> void:
	if _benchmark_runner == null:
		return
	if _benchmark_runner.has_method("set_benchmark_duration_seconds"):
		_benchmark_runner.call("set_benchmark_duration_seconds", _duration_seconds)
	else:
		_benchmark_runner.set("benchmark_duration_seconds", _duration_seconds)
