extends RefCounted

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_debug_panel_starts_closed_without_processing(failures)
	_test_debug_panel_open_and_close_toggle_processing(failures)
	return failures


func _test_debug_panel_starts_closed_without_processing(failures: Array[String]) -> void:
	var hud: CanvasLayer = _instantiate_hud()
	if hud == null:
		failures.append("HUD scene should instantiate for debug panel tests")
		return
	var debug_panel: Control = hud.get_node("DebugPanel")
	TEST_UTILS.expect(not debug_panel.visible, failures, "Debug panel should start hidden")
	TEST_UTILS.expect(not debug_panel.is_processing(), failures, "Hidden debug panel should not keep its process loop active")
	hud.queue_free()


func _test_debug_panel_open_and_close_toggle_processing(failures: Array[String]) -> void:
	var hud: CanvasLayer = _instantiate_hud()
	if hud == null:
		failures.append("HUD scene should instantiate for debug panel toggle tests")
		return
	var debug_panel: Control = hud.get_node("DebugPanel")
	debug_panel.call("set_open", true)
	TEST_UTILS.expect(debug_panel.visible, failures, "Debug panel should become visible after opening")
	TEST_UTILS.expect(debug_panel.is_processing(), failures, "Visible debug panel should enable its process loop")
	TEST_UTILS.expect_close(float(debug_panel.get("state_refresh_timer")), 0.0, failures, "Opening the debug panel should reset its refresh timer")
	debug_panel.call("set_open", false)
	TEST_UTILS.expect(not debug_panel.visible, failures, "Debug panel should become hidden after closing")
	TEST_UTILS.expect(not debug_panel.is_processing(), failures, "Closed debug panel should disable its process loop again")
	TEST_UTILS.expect_close(float(debug_panel.get("state_refresh_timer")), 0.0, failures, "Closing the debug panel should reset its refresh timer")
	hud.queue_free()


func _instantiate_hud() -> CanvasLayer:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var hud := HUD_SCENE.instantiate() as CanvasLayer
	tree.root.add_child(hud)
	return hud
