extends RefCounted

const LOADING_OVERLAY_SCENE := preload("res://scenes/ui/loading_overlay.tscn")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_loading_overlay_updates_message_and_progress(failures)
	return failures


func _test_loading_overlay_updates_message_and_progress(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	TEST_UTILS.expect(tree != null and tree.current_scene != null, failures, "Test runner should provide a current scene for loading overlay tests")
	if tree == null or tree.current_scene == null:
		return
	var overlay := LOADING_OVERLAY_SCENE.instantiate() as CanvasLayer
	tree.current_scene.add_child(overlay)
	overlay.call("show_loading", "Rendering world...", 0.94)
	TEST_UTILS.expect(overlay.visible, failures, "Loading overlay should stay visible while loading is active")
	TEST_UTILS.expect_equal(str(overlay.call("get_status_text")), "Rendering world...", failures, "Loading overlay should expose the current loading stage text")
	TEST_UTILS.expect_close(float(overlay.call("get_progress_ratio")), 0.94, failures, "Loading overlay should expose the current loading progress ratio")
	overlay.call("hide_loading")
	TEST_UTILS.expect(not overlay.visible, failures, "Loading overlay should hide once loading completes")
	overlay.free()
