extends RefCounted

const LEGACY_RUNTIME_CONTEXT_PATH := "res://scripts/godot_adapters/runtime/godot_runtime_context.gd"
const SOURCE_RUNTIME_CONTEXT_PATH := "res://scripts/godot_runtime/runtime/godot_runtime_context.gd"

const ALLOWED_LEGACY_REFERENCE_PATHS := {
	"res://scripts/godot_adapters/runtime/godot_runtime_context.gd": true,
	"res://tests/unit/test_runtime_context_smoke.gd": true,
	"res://tests/unit/test_runtime_context_legacy_path_scan.gd": true
}


func run() -> Dictionary:
	var failures: Array[String] = []

	_test_no_runtime_code_uses_legacy_runtime_context_path(failures)
	_test_source_runtime_context_path_exists(failures)
	_test_legacy_runtime_context_shim_exists(failures)

	return {
		"passed": failures.is_empty(),
		"failures": failures
	}


func _test_no_runtime_code_uses_legacy_runtime_context_path(failures: Array[String]) -> void:
	_scan_directory_for_legacy_reference("res://scripts", failures)
	_scan_directory_for_legacy_reference("res://tests", failures)


func _test_source_runtime_context_path_exists(failures: Array[String]) -> void:
	if not ResourceLoader.exists(SOURCE_RUNTIME_CONTEXT_PATH):
		failures.append("Expected RuntimeContext source path to exist: %s" % SOURCE_RUNTIME_CONTEXT_PATH)


func _test_legacy_runtime_context_shim_exists(failures: Array[String]) -> void:
	if not ResourceLoader.exists(LEGACY_RUNTIME_CONTEXT_PATH):
		failures.append("Expected legacy RuntimeContext compatibility shim to exist: %s" % LEGACY_RUNTIME_CONTEXT_PATH)


func _scan_directory_for_legacy_reference(directory_path: String, failures: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		failures.append("Could not open directory for scan: %s" % directory_path)
		return

	directory.list_dir_begin()
	while true:
		var entry := directory.get_next()
		if entry.is_empty():
			break
		if entry.begins_with("."):
			continue
		var full_path := directory_path.path_join(entry)
		if directory.current_is_dir():
			_scan_directory_for_legacy_reference(full_path, failures)
			continue
		if not _should_scan_file(full_path):
			continue
		_scan_file_for_legacy_reference(full_path, failures)
	directory.list_dir_end()


func _should_scan_file(path: String) -> bool:
	return path.ends_with(".gd") or path.ends_with(".tscn") or path.ends_with(".tres")


func _scan_file_for_legacy_reference(path: String, failures: Array[String]) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		failures.append("Could not read file during legacy RuntimeContext scan: %s" % path)
		return

	var line_number := 0
	while not file.eof_reached():
		line_number += 1
		var raw_line := file.get_line()
		if not raw_line.contains(LEGACY_RUNTIME_CONTEXT_PATH):
			continue
		if ALLOWED_LEGACY_REFERENCE_PATHS.has(path):
			continue
		failures.append(
			"%s:%d: unexpected legacy RuntimeContext reference. Use %s instead. -> %s"
			% [path, line_number, SOURCE_RUNTIME_CONTEXT_PATH, raw_line.strip_edges()]
		)
		return
