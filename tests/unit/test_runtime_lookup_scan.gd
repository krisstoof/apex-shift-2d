extends RefCounted

const SCAN_ROOT := "res://scripts"

const ALLOWED_LOOKUP_FILES := {
	"res://scripts/godot_runtime/runtime/godot_runtime_context_builder.gd": true,
	"res://scripts/systems/runtime_bootstrapper.gd": true
}

const LOOKUP_PATTERNS := [
	"get_first_node_in_group(\"player\")",
	"get_first_node_in_group('player')",
	"get_nodes_in_group(\"player\")",
	"get_nodes_in_group('player')",
	"get_node_or_null(\"/root/EventBus\")",
	"get_node_or_null('/root/EventBus')",
	"get_node_or_null(\"/root/GameSession\")",
	"get_node_or_null('/root/GameSession')",
	"root.get_node_or_null(\"EventBus\")",
	"root.get_node_or_null('EventBus')",
	"root.get_node_or_null(\"GameSession\")",
	"root.get_node_or_null('GameSession')",
	"find_child(\"Minimap\"",
	"find_child('Minimap'",
	"find_child(\"MapScreen\"",
	"find_child('MapScreen'"
]


func run() -> Dictionary:
	var failures: Array[String] = []
	var findings: Array[Dictionary] = []

	_scan_directory(SCAN_ROOT, findings, failures)
	_print_report(findings)

	return {
		"passed": failures.is_empty(),
		"failures": failures
	}


func _scan_directory(directory_path: String, findings: Array[Dictionary], failures: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		failures.append("Could not open directory: %s" % directory_path)
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
			_scan_directory(full_path, findings, failures)
			continue
		if not _should_scan_file(full_path):
			continue
		_scan_file(full_path, findings, failures)
	directory.list_dir_end()


func _should_scan_file(path: String) -> bool:
	return path.ends_with(".gd")


func _scan_file(path: String, findings: Array[Dictionary], failures: Array[String]) -> void:
	if ALLOWED_LOOKUP_FILES.has(path):
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		failures.append("Could not read file: %s" % path)
		return

	var content := file.get_as_text()
	var matched_patterns: Array[String] = []
	for pattern in LOOKUP_PATTERNS:
		if content.contains(pattern):
			matched_patterns.append(pattern)

	if matched_patterns.is_empty():
		return

	findings.append({
		"path": path,
		"patterns": matched_patterns
	})


func _print_report(findings: Array[Dictionary]) -> void:
	if findings.is_empty():
		print("[RuntimeLookupScan] No direct runtime lookups found.")
		return

	print("[RuntimeLookupScan] Direct runtime lookup report:")
	print("[RuntimeLookupScan] Findings: %d files" % findings.size())
	for finding in findings:
		var path := str(finding.get("path", ""))
		var patterns := Array(finding.get("patterns", []))
		print("[RuntimeLookupScan] %s" % path)
		for pattern in patterns:
			print("  - %s" % str(pattern))
