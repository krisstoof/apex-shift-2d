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


class MockEvolutionDirector:
	extends Node

	func get_profile() -> Dictionary:
		return {
			"generation": 3,
			"aggression": 0.45,
			"fire_fear": 0.85,
			"trap_awareness": 0.10,
			"pack_coordination": 0.20
		}


class MockDayNightSystem:
	extends Node

	func get_day() -> int:
		return 2

	func get_clock_time() -> String:
		return "10:31"

	func get_time_label() -> String:
		return "Day"


class MockResource:
	extends Node2D
	var resource_kind := "berry_bush"
	var item_name := "berries"
	var player_harvestable := true


class MockVarnak:
	extends Node2D


class MockWorld:
	extends Node
	var registered_resources: Array = []
	var registered_varnaks: Array = []

	func get_registered_resources() -> Array:
		return registered_resources

	func get_registered_creatures_by_type(creature_type: String) -> Array:
		if creature_type == "varnak":
			return registered_varnaks
		return []

	func get_landmarks() -> Array[Dictionary]:
		return []


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_info_lines_fall_back_when_player_is_missing(failures)
	_test_info_lines_use_player_stats_and_inventory(failures)
	_test_map_redraw_state_does_not_retrigger_when_state_is_unchanged(failures)
	_test_map_redraw_state_reacts_to_player_position_changes(failures)
	_test_landmark_signature_changes_only_when_landmarks_change(failures)
	_test_map_redraw_state_reacts_to_resource_signature_changes(failures)
	_test_map_screen_reads_registry_resources_and_varnaks(failures)
	return failures


func _test_info_lines_fall_back_when_player_is_missing(failures: Array[String]) -> void:
	var map_screen: Object = _make_map_screen()
	var lines: Array[String] = map_screen.call("_build_info_lines")
	TEST_UTILS.expect(lines.has("Health:   0"), failures, "Map screen should show zero health when the player reference is missing")
	TEST_UTILS.expect(lines.has("Hunger:   0"), failures, "Map screen should show zero hunger when the player reference is missing")
	TEST_UTILS.expect(lines.has("Stamina:   0"), failures, "Map screen should show zero stamina when the player reference is missing")
	TEST_UTILS.expect(lines.has("Rest:   0  unknown"), failures, "Map screen should show a fallback rest condition when the player reference is missing")
	TEST_UTILS.expect(lines.has("Wood 0  Stone 0  Fiber 0"), failures, "Map screen should show zero inventory counts when the player reference is missing")
	TEST_UTILS.expect(lines.has("Meat 0  Hide 0  Bone 0"), failures, "Map screen should show zero loot counts when the player reference is missing")
	map_screen.free()


func _test_info_lines_use_player_stats_and_inventory(failures: Array[String]) -> void:
	var map_screen: Object = _make_map_screen()
	var player := MockPlayer.new()
	map_screen.set("player", player)
	var lines: Array[String] = map_screen.call("_build_info_lines")
	TEST_UTILS.expect(lines.has("Health:  86"), failures, "Map screen should expose the player's health when stats are available")
	TEST_UTILS.expect(lines.has("Hunger:  72"), failures, "Map screen should expose the player's hunger when stats are available")
	TEST_UTILS.expect(lines.has("Stamina:  54"), failures, "Map screen should expose the player's stamina when stats are available")
	TEST_UTILS.expect(lines.has("Rest:  43  steady"), failures, "Map screen should expose the player's rest condition when stats are available")
	TEST_UTILS.expect(lines.has("Wood 3  Stone 4  Fiber 5"), failures, "Map screen should expose inventory resource counts when inventory is available")
	TEST_UTILS.expect(lines.has("Meat 6  Hide 7  Bone 8"), failures, "Map screen should expose inventory loot counts when inventory is available")
	player.free()
	map_screen.free()


func _test_map_redraw_state_does_not_retrigger_when_state_is_unchanged(failures: Array[String]) -> void:
	var map_screen: Object = _make_bound_map_screen()
	var first_refresh: bool = map_screen.call("_request_map_redraw", true)
	var second_refresh: bool = map_screen.call("_request_map_redraw")
	TEST_UTILS.expect(first_refresh, failures, "Map screen should request an initial redraw for the first visible state snapshot")
	TEST_UTILS.expect(not second_refresh, failures, "Map screen should not request another redraw when the visible state key is unchanged")
	var player: Node2D = map_screen.get("player")
	player.free()
	map_screen.free()


func _test_map_redraw_state_reacts_to_player_position_changes(failures: Array[String]) -> void:
	var map_screen: Object = _make_bound_map_screen()
	var player: Node2D = map_screen.get("player")
	map_screen.call("_request_map_redraw", true)
	player.global_position = Vector2(180.0, -64.0)
	var changed: bool = map_screen.call("_request_map_redraw")
	TEST_UTILS.expect(changed, failures, "Map screen should request redraw when the player position shown on the map changes")
	player.free()
	map_screen.free()


func _test_landmark_signature_changes_only_when_landmarks_change(failures: Array[String]) -> void:
	var map_screen: Object = _make_map_screen()
	var landmarks: Array[Dictionary] = [
		{
			"id": "pond_a",
			"type": "pond",
			"position": Vector2(120.0, 80.0),
			"radius": 90.0
		}
	]
	map_screen.set("landmarks", landmarks)
	var first_change: bool = map_screen.call("_update_landmarks_signature")
	var second_change: bool = map_screen.call("_update_landmarks_signature")
	landmarks[0]["radius"] = 120.0
	map_screen.set("landmarks", landmarks)
	var third_change: bool = map_screen.call("_update_landmarks_signature")
	TEST_UTILS.expect(first_change, failures, "Map screen should mark landmark cache as changed when the first signature is built")
	TEST_UTILS.expect(not second_change, failures, "Map screen should keep landmark cache stable when landmarks do not change")
	TEST_UTILS.expect(third_change, failures, "Map screen should notice landmark changes that require a new map redraw")
	map_screen.free()


func _test_map_redraw_state_reacts_to_resource_signature_changes(failures: Array[String]) -> void:
	var map_screen: Object = _make_bound_map_screen()
	map_screen.set("cached_resources_signature", "resource-a")
	map_screen.call("_request_map_redraw", true)
	map_screen.set("cached_resources_signature", "resource-b")
	var changed: bool = map_screen.call("_request_map_redraw")
	TEST_UTILS.expect(changed, failures, "Map screen should request redraw when the cached resource signature changes")
	var player: Node2D = map_screen.get("player")
	player.free()
	map_screen.free()


func _test_map_screen_reads_registry_resources_and_varnaks(failures: Array[String]) -> void:
	var world := MockWorld.new()
	var resource := MockResource.new()
	resource.global_position = Vector2(120.0, -40.0)
	var varnak := MockVarnak.new()
	varnak.global_position = Vector2(260.0, 80.0)
	world.registered_resources = [resource]
	world.registered_varnaks = [varnak]
	var map_screen: Control = _make_bound_map_screen()
	map_screen.set("world", world)
	var cache_changed: bool = map_screen.call("_update_resources_cache")
	var lines: Array[String] = map_screen.call("_build_info_lines")
	TEST_UTILS.expect(cache_changed, failures, "Map screen should rebuild its resource cache when WorldRegistry provides a new resource marker")
	TEST_UTILS.expect_equal(Array(map_screen.get("cached_resources")).size(), 1, failures, "Map screen should cache resource markers from WorldRegistry")
	TEST_UTILS.expect(lines.has("Live Varnaks: 1"), failures, "Map screen info panel should count varnaks from WorldRegistry instead of group scans")
	map_screen.free()


func _make_map_screen() -> Object:
	var map_screen: Control = MAP_SCREEN_SCRIPT.new()
	map_screen.size = Vector2(1280.0, 720.0)
	return map_screen


func _make_bound_map_screen() -> Object:
	var map_screen: Object = _make_map_screen()
	var player := MockPlayer.new()
	player.global_position = Vector2(32.0, 48.0)
	map_screen.set("player", player)
	map_screen.set("evolution_director", MockEvolutionDirector.new())
	map_screen.set("day_night_system", MockDayNightSystem.new())
	map_screen.set("landmarks", [
		{
			"id": "hill_a",
			"type": "hill",
			"position": Vector2(260.0, -120.0),
			"radius": 140.0
		}
	])
	map_screen.call("_update_landmarks_signature")
	return map_screen
