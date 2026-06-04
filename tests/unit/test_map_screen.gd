extends RefCounted

const MAP_SCREEN_SCRIPT := preload("res://scripts/ui/map_screen.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


class MockStats:
	extends RefCounted
	var health := 86
	var hunger := 72
	var stamina := 54
	var rest := 43

	func get_condition_text() -> String:
		return "steady"


class MockInventory:
	extends RefCounted

	func get_amount(item_id: String) -> int:
		match item_id:
			"wood":
				return 3
			"stone":
				return 4
			"fiber":
				return 5
			"meat":
				return 6
			"hide":
				return 7
			"bone":
				return 8
		return 0


class MockPlayer:
	extends Node2D
	var stats := MockStats.new()
	var inventory := MockInventory.new()


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_info_lines_fall_back_when_player_is_missing(failures)
	_test_info_lines_use_player_stats_and_inventory(failures)
	return failures


func _test_info_lines_fall_back_when_player_is_missing(failures: Array[String]) -> void:
	var map_screen := _make_map_screen()
	var lines: Array[String] = map_screen.call("_build_info_lines")
	TEST_UTILS.expect(lines.has("Health:   0"), failures, "Map screen should show zero health when the player reference is missing")
	TEST_UTILS.expect(lines.has("Hunger:   0"), failures, "Map screen should show zero hunger when the player reference is missing")
	TEST_UTILS.expect(lines.has("Stamina:   0"), failures, "Map screen should show zero stamina when the player reference is missing")
	TEST_UTILS.expect(lines.has("Rest:   0  unknown"), failures, "Map screen should show a fallback rest condition when the player reference is missing")
	TEST_UTILS.expect(lines.has("Wood 0  Stone 0  Fiber 0"), failures, "Map screen should show zero inventory counts when the player reference is missing")
	TEST_UTILS.expect(lines.has("Meat 0  Hide 0  Bone 0"), failures, "Map screen should show zero loot counts when the player reference is missing")
	map_screen.free()


func _test_info_lines_use_player_stats_and_inventory(failures: Array[String]) -> void:
	var map_screen := _make_map_screen()
	var player := MockPlayer.new()
	map_screen.player = player
	var lines: Array[String] = map_screen.call("_build_info_lines")
	TEST_UTILS.expect(lines.has("Health:  86"), failures, "Map screen should expose the player's health when stats are available")
	TEST_UTILS.expect(lines.has("Hunger:  72"), failures, "Map screen should expose the player's hunger when stats are available")
	TEST_UTILS.expect(lines.has("Stamina:  54"), failures, "Map screen should expose the player's stamina when stats are available")
	TEST_UTILS.expect(lines.has("Rest:  43  steady"), failures, "Map screen should expose the player's rest condition when stats are available")
	TEST_UTILS.expect(lines.has("Wood 3  Stone 4  Fiber 5"), failures, "Map screen should expose inventory resource counts when inventory is available")
	TEST_UTILS.expect(lines.has("Meat 6  Hide 7  Bone 8"), failures, "Map screen should expose inventory loot counts when inventory is available")
	player.free()
	map_screen.free()


func _make_map_screen() -> Control:
	var map_screen := MAP_SCREEN_SCRIPT.new()
	map_screen.size = Vector2(1280.0, 720.0)
	return map_screen
