extends RefCounted

const HUD_SCRIPT := preload("res://scripts/ui/hud.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_hud_formats_clock_and_stats_from_snapshot(failures)
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
