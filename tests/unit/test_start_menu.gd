extends RefCounted

const START_MENU_SCRIPT := preload("res://scripts/ui/start_menu.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_resume_tree_helper_clears_pause(failures)
	_test_start_menu_source_uses_resume_helper_on_ready_and_scene_change(failures)
	_test_start_menu_uses_app_version_for_display_text(failures)
	return failures


func _test_resume_tree_helper_clears_pause(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		failures.append("SceneTree should exist for start menu tests")
		return
	var start_menu := START_MENU_SCRIPT.new()
	tree.paused = true
	start_menu.call("_resume_tree_if_paused", tree)
	TEST_UTILS.expect(not tree.paused, failures, "Start menu should clear a paused SceneTree before entering the game")


func _test_start_menu_source_uses_resume_helper_on_ready_and_scene_change(failures: Array[String]) -> void:
	var script_text := FileAccess.get_file_as_string("res://scripts/ui/start_menu.gd")
	TEST_UTILS.expect(script_text.contains("func _ready() -> void:\n\tprocess_mode = Node.PROCESS_MODE_ALWAYS\n\tmouse_filter = Control.MOUSE_FILTER_STOP\n\t_resume_tree_if_paused()"), failures, "Start menu should resume the tree as soon as the menu scene becomes active")
	TEST_UTILS.expect(script_text.contains("func _change_to_game_scene() -> void:\n\t_resume_tree_if_paused()"), failures, "Start menu should resume the tree again right before switching into the game scene")


func _test_start_menu_uses_app_version_for_display_text(failures: Array[String]) -> void:
	var script_text := FileAccess.get_file_as_string("res://scripts/ui/start_menu.gd")
	TEST_UTILS.expect(script_text.contains("const APP_VERSION := preload(\"res://scripts/systems/app_version.gd\")"), failures, "Start menu should use the shared app version source")
	TEST_UTILS.expect(script_text.contains("subtitle.text = APP_VERSION.get_display_name()"), failures, "Start menu should display the shared app version string")
	TEST_UTILS.expect(not script_text.contains("Prototype build"), failures, "Start menu should no longer contain the Prototype build label")
