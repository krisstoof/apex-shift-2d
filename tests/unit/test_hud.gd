extends RefCounted

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const HUD_SCRIPT := preload("res://scripts/ui/hud.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


class TestPlayer:
	extends Node
	var stats := {
		"health": 100.0,
		"MAX_HEALTH": 100.0
	}


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_hud_formats_clock_and_stats_from_snapshot(failures)
	_test_hud_creates_critical_health_overlay(failures)
	_test_hud_activates_warning_when_health_is_low(failures)
	_test_game_over_scene_is_root_full_rect(failures)
	return failures


func _test_hud_formats_clock_and_stats_from_snapshot(failures: Array[String]) -> void:
	var hud := HUD_SCRIPT.new()
	var snapshot := {
		"time": {
			"clock_time": "13:48",
			"time_label": "Day"
		},
		"player": {
			"health": 91,
			"hunger": 62,
			"stamina": 48,
			"rest": 77,
			"condition_text": "steady",
			"campfire_regen_active": true,
			"torch_active": true,
			"torch_remaining_seconds": 17.2,
			"has_spear": true,
			"has_bow": false,
			"prompt_text": "E: interact",
			"inventory": {
				"wood": 4,
				"stone": 3,
				"fiber": 2,
				"meat": 1,
				"torch": 2
			}
		}
	}
	var clock_text: String = hud.call("_build_clock_text_from_snapshot", snapshot)
	var stats_text: String = hud.call("_build_stats_text_from_snapshot", snapshot)
	var prompt_text: String = hud.call("_get_prompt_text_from_snapshot", snapshot)
	TEST_UTILS.expect_equal(clock_text, "13:48\nDay", failures, "HUD should format the clock text from snapshot data")
	TEST_UTILS.expect(stats_text.contains("Health:  91  Hunger:  62  Stamina:  48  Rest:  77  steady campfire_regen_active"), failures, "HUD should build the player stats line from snapshot data")
	TEST_UTILS.expect(stats_text.contains("Wood: 4  Stone: 3  Fiber: 2  Meat: 1  Torch: 2 active 18s  Spear: yes  Bow: no"), failures, "HUD should build the inventory/tools line from snapshot data")
	TEST_UTILS.expect_equal(prompt_text, "E: interact", failures, "HUD should read the interaction prompt from snapshot data")
	hud.free()


func _test_hud_creates_critical_health_overlay(failures: Array[String]) -> void:
	var hud := _make_hud()
	var debug_state: Dictionary = hud.call("get_critical_health_debug")
	TEST_UTILS.expect_equal(debug_state.get("overlay_visible", false), false, failures, "Critical health overlay should start hidden")
	TEST_UTILS.expect_equal(debug_state.get("overlay_alpha", 1.0), 0.0, failures, "Critical health overlay should start transparent")
	hud.queue_free()


func _test_hud_activates_warning_when_health_is_low(failures: Array[String]) -> void:
	var hud := _make_hud()
	var player := TestPlayer.new()
	player.stats.health = 15.0
	player.stats.MAX_HEALTH = 100.0
	hud.player = player
	hud.evolution_director = Node.new()
	hud.day_night_system = Node.new()
	hud.call("_update_critical_health_warning", 0.5)
	var debug_state: Dictionary = hud.call("get_critical_health_debug")
	TEST_UTILS.expect_equal(debug_state.get("active", false), true, failures, "Critical health warning should activate when health drops below the threshold")
	TEST_UTILS.expect_equal(debug_state.get("overlay_visible", false), true, failures, "Critical health overlay should become visible at low health")
	TEST_UTILS.expect(float(debug_state.get("overlay_alpha", 0.0)) > 0.0, failures, "Critical health overlay should gain a visible alpha when active")
	player.stats.health = 80.0
	hud.call("_update_critical_health_warning", 0.5)
	debug_state = hud.call("get_critical_health_debug")
	TEST_UTILS.expect_equal(debug_state.get("active", true), false, failures, "Critical health warning should deactivate when health recovers")
	TEST_UTILS.expect_equal(debug_state.get("overlay_visible", true), false, failures, "Critical health overlay should hide when health recovers")
	TEST_UTILS.expect_equal(debug_state.get("overlay_alpha", 1.0), 0.0, failures, "Critical health overlay should become transparent when inactive")
	hud.queue_free()


func _test_game_over_scene_is_root_full_rect(failures: Array[String]) -> void:
	var scene_text := FileAccess.get_file_as_string("res://scenes/ui/game_over_screen.tscn")
	TEST_UTILS.expect(scene_text.contains("anchors_preset = 15"), failures, "Game Over root should fill the full screen so the internal center container can center the panel")
	TEST_UTILS.expect(scene_text.contains("GameOverScreen"), failures, "Game Over scene should still define the expected root node")


func _make_hud() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	var hud := HUD_SCENE.instantiate()
	tree.current_scene.add_child(hud)
	return hud
