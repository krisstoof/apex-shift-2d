extends RefCounted

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


class MockSnapshotService:
	extends RefCounted

	var snapshot: Dictionary = {}
	var refresh_count := 0

	func refresh(force := false) -> Dictionary:
		refresh_count += 1
		return snapshot.duplicate(true)

	func get_snapshot() -> Dictionary:
		return snapshot.duplicate(true)


func run() -> Array[String]:
	var failures: Array[String] = []
	await _test_debug_panel_starts_closed_without_processing(failures)
	await _test_debug_panel_open_and_close_toggle_processing(failures)
	await _test_debug_panel_skips_heavy_refresh_when_hidden(failures)
	await _test_debug_panel_refreshes_snapshot_when_visible(failures)
	await _test_debug_panel_refreshes_overlays_only_for_creatures_tab(failures)
	await _test_population_recovery_debug_lines_explain_population_changes(failures)
	return failures


func _test_debug_panel_starts_closed_without_processing(failures: Array[String]) -> void:
	var hud: CanvasLayer = await _instantiate_hud()
	if hud == null:
		failures.append("HUD scene should instantiate for debug panel tests")
		return
	var debug_panel: Control = hud.get_node("DebugPanel")
	TEST_UTILS.expect(not debug_panel.visible, failures, "Debug panel should start hidden")
	TEST_UTILS.expect(not debug_panel.is_processing(), failures, "Hidden debug panel should not keep its process loop active")
	hud.queue_free()


func _test_debug_panel_open_and_close_toggle_processing(failures: Array[String]) -> void:
	var hud: CanvasLayer = await _instantiate_hud()
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
	var hud: CanvasLayer = await _instantiate_hud()
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


func _test_debug_panel_refreshes_snapshot_when_visible(failures: Array[String]) -> void:
	var hud: CanvasLayer = await _instantiate_hud()
	if hud == null:
		failures.append("HUD scene should instantiate for visible debug panel snapshot tests")
		return
	var debug_panel: Control = hud.get_node("DebugPanel")
	var mock_service := MockSnapshotService.new()
	mock_service.snapshot = {
		"player": {"health": 80, "hunger": 70, "stamina": 60, "rest": 50, "inventory": {"bone": 0}},
		"time": {"day": 1, "phase_label": "day", "night_amount": 0.0},
		"world": {"varnak_population": {"day": 1, "live": 0, "target": 0, "max": 12}},
		"debug": {"live_varnaks": 0, "current_biome_name": "start"}
	}
	debug_panel.call("bind", null, null, null, null, mock_service)
	debug_panel.call("set_open", true)
	debug_panel.call("_process", 0.6)
	var first_text := str(debug_panel.get_node("Panel/StateScroll/StateLabel").text)
	mock_service.snapshot = {
		"player": {"health": 42, "hunger": 18, "stamina": 12, "rest": 9, "inventory": {"bone": 3}},
		"time": {"day": 4, "phase_label": "night", "night_amount": 0.85},
		"world": {"varnak_population": {"day": 4, "live": 5, "target": 6, "max": 12}},
		"debug": {"live_varnaks": 5, "current_biome_name": "redfang_wilds"}
	}
	debug_panel.call("_process", 0.6)
	var second_text := str(debug_panel.get_node("Panel/StateScroll/StateLabel").text)
	TEST_UTILS.expect(first_text != second_text, failures, "Visible debug panel should rebuild its text from a fresh snapshot")
	TEST_UTILS.expect(second_text.contains("Bone"), failures, "Updated debug text should reflect the live inventory snapshot")
	TEST_UTILS.expect(mock_service.refresh_count >= 2, failures, "Visible debug panel should ask the snapshot service to refresh")
	hud.queue_free()


func _test_debug_panel_refreshes_overlays_only_for_creatures_tab(failures: Array[String]) -> void:
	var hud: CanvasLayer = await _instantiate_hud()
	if hud == null:
		failures.append("HUD scene should instantiate for tab-specific overlay tests")
		return
	var debug_panel: Control = hud.get_node("DebugPanel")
	debug_panel.call("set_open", true)
	debug_panel.call("_process", 0.6)
	var stats_overview: Dictionary = Dictionary(debug_panel.call("get_debug_panel_performance_debug"))
	TEST_UTILS.expect_equal(int(stats_overview.get("overlay_refresh_count", 0)), 0, failures, "Overview tab should not redraw creature overlays")
	debug_panel.call("_on_debug_tab_changed", 4)
	debug_panel.call("_process", 0.6)
	var stats_creatures: Dictionary = Dictionary(debug_panel.call("get_debug_panel_performance_debug"))
	TEST_UTILS.expect(int(stats_creatures.get("overlay_refresh_count", 0)) > int(stats_overview.get("overlay_refresh_count", 0)), failures, "Creatures tab should redraw creature overlays")
	hud.queue_free()


func _test_population_recovery_debug_lines_explain_population_changes(failures: Array[String]) -> void:
	var hud: CanvasLayer = await _instantiate_hud()
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
	tree.root.call_deferred("add_child", hud)
	await tree.process_frame
	await tree.process_frame
	return hud
