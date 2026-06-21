extends RefCounted

const TEST_UTILS := preload("res://tests/unit/test_utils.gd")

const CORE_ROOT := "res://scripts/core"
const FORBIDDEN_PATTERNS := [
	{"label": "get_tree()", "regex": "\\bget_tree\\s*\\("},
	{"label": "add_child()", "regex": "\\badd_child\\s*\\("},
	{"label": "queue_free()", "regex": "\\bqueue_free\\s*\\("},
	{"label": "get_nodes_in_group()", "regex": "\\bget_nodes_in_group\\s*\\("},
	{"label": "get_node()", "regex": "\\bget_node\\s*\\("},
	{"label": "$NodePath shorthand", "regex": "\\$[A-Za-z_][A-Za-z0-9_]*"},
	{"label": "Sprite2D", "regex": "\\bSprite2D\\b"},
	{"label": "ImageTexture", "regex": "\\bImageTexture\\b"},
	{"label": "Control", "regex": "\\bControl\\b"},
	{"label": "CanvasItem", "regex": "\\bCanvasItem\\b"},
	{"label": "PackedScene", "regex": "\\bPackedScene\\b"},
	{"label": "Node2D", "regex": "\\bNode2D\\b"},
	{"label": "Area2D", "regex": "\\bArea2D\\b"},
	{"label": "StaticBody2D", "regex": "\\bStaticBody2D\\b"},
	{"label": "CharacterBody2D", "regex": "\\bCharacterBody2D\\b"},
	{"label": "load res://scenes", "regex": "\\bload\\s*\\(\\s*[\"']res://scenes"},
	{"label": "preload res://scenes", "regex": "\\bpreload\\s*\\(\\s*[\"']res://scenes"},
	{"label": "scene path", "regex": "[\"']res://scenes/[^\"']+[\"']"},
	{"label": "texture path", "regex": "[\"']res://assets/[^\"']+[\"']"}
]


func run() -> Array[String]:
	var failures: Array[String] = []
	_scan_core_portability(failures)
	return failures


func _scan_core_portability(failures: Array[String]) -> void:
	var core_dir := DirAccess.open(CORE_ROOT)
	if core_dir == null:
		failures.append("Could not open %s for portability scan." % CORE_ROOT)
		return
	_scan_core_directory(core_dir, CORE_ROOT, failures)


func _scan_core_directory(dir: DirAccess, path: String, failures: Array[String]) -> void:
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry.begins_with("."):
			continue
		var full_path := "%s/%s" % [path, entry]
		if dir.current_is_dir():
			var child := DirAccess.open(full_path)
			if child != null:
				_scan_core_directory(child, full_path, failures)
			continue
		if not entry.ends_with(".gd"):
			continue
		_scan_core_file(full_path, failures)
	dir.list_dir_end()


func _scan_core_file(file_path: String, failures: Array[String]) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		failures.append("%s: unable to open file for scan." % file_path)
		return
	var line_number := 0
	while not file.eof_reached():
		line_number += 1
		var raw_line := file.get_line()
		var line := _strip_inline_comment(raw_line)
		if line.is_empty():
			continue
		for pattern_value in FORBIDDEN_PATTERNS:
			var pattern := Dictionary(pattern_value)
			var regex := RegEx.new()
			if regex.compile(str(pattern.get("regex", ""))) != OK:
				continue
			var match := regex.search(line)
			if match == null:
				continue
			failures.append(_format_violation(file_path, line_number, str(pattern.get("label", "")), raw_line.strip_edges()))
			break


func _strip_inline_comment(line: String) -> String:
	var comment_index := line.find("#")
	if comment_index < 0:
		return line.strip_edges()
	return line.substr(0, comment_index).strip_edges()


func _format_violation(file_path: String, line_number: int, token: String, snippet: String) -> String:
	return "%s:%d: forbidden %s -> %s" % [file_path, line_number, token, snippet]
