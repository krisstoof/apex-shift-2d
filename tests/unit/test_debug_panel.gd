extends RefCounted

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_debug_panel_starts_closed_without_processing(failures)
	_test_debug_panel_open_and_close_toggle_processing(failures)
	_test_debug_panel_skips_heavy_refresh_when_hidden(failures)
	_test_population_recovery_debug_lines_explain_population_changes(failures)
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


func _test_debug_panel_skips_heavy_refresh_when_hidden(failures: Array[String]) -> void:
	var hud: CanvasLayer = _instantiate_hud()
	if hud == null:
		failures.append("HUD scene should instantiate for hidden debug panel tests")
		return
	var debug_panel: Control = hud.get_node("DebugPanel")
	var stats_before: Dictionary = Dictionary(debug_panel.call("get_debug_panel_performance_debug"))
	debug_panel.call("_process", 0.6)
	var stats_after: Dictionary = Dictionary(debug_panel.call("get_debug_panel_performance_debug"))
	TEST_UTILS.expect_equal(int(stats_after.get("hidden_skip_count", 0)), int(stats_before.get("hidden_skip_count", 0)) + 1, failures, "Hidden debug panel should skip expensive refresh work instead of rebuilding its state")
	TEST_UTILS.expect_equal(int(stats_after.get("refresh_count", 0)), int(stats_before.get("refresh_count", 0)), failures, "Hidden debug panel should not rebuild its visible state text")
	TEST_UTILS.expect_equal(int(stats_after.get("overlay_refresh_count", 0)), int(stats_before.get("overlay_refresh_count", 0)), failures, "Hidden debug panel should not redraw creature overlays")
	hud.queue_free()


func _test_population_recovery_debug_lines_explain_population_changes(failures: Array[String]) -> void:
	var hud: CanvasLayer = _instantiate_hud()
	if hud == null:
		failures.append("HUD scene should instantiate for population recovery debug tests")
		return
	var debug_panel: Control = hud.get_node("DebugPanel")
	var lines: Array[String] = debug_panel.call("_get_population_recovery_debug_lines", {
		"small_prey_daily_recovery": 5.0,
		"grazer_daily_recovery": 2.5,
		"small_prey_predation_pressure": 0.35,
		"grazer_predation_pressure": 0.20,
		"grazer_starvation_pressure": 0.15,
		"small_prey_population_trend": "growing",
		"grazer_population_trend": "stable"
	})
	TEST_UTILS.expect(lines[0].contains("12/25/40"), failures, "SmallPrey debug line should show min, target, and max populations")
	TEST_UTILS.expect(lines[0].contains("daily +5.00"), failures, "SmallPrey debug line should show daily recovery")
	TEST_UTILS.expect(lines[0].contains("growing"), failures, "SmallPrey debug line should show the population trend")
	TEST_UTILS.expect(lines[1].contains("6/14/25"), failures, "Grazer debug line should show min, target, and max populations")
	TEST_UTILS.expect(lines[1].contains("starve 0.15"), failures, "Grazer debug line should show starvation pressure")
	hud.queue_free()


func _instantiate_hud() -> CanvasLayer:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var hud := HUD_SCENE.instantiate() as CanvasLayer
	tree.root.add_child(hud)
	return hud
