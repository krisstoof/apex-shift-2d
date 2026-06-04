extends RefCounted

const SAVE_SYSTEM_SCRIPT := preload("res://scripts/systems/save_system.gd")
const PLAYER_STATS := preload("res://scripts/player/player_stats.gd")
const INVENTORY := preload("res://scripts/player/inventory.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


class TestPlayer:
	extends Node2D

	var stats := PLAYER_STATS.new()
	var inventory := INVENTORY.new()
	var has_spear := false
	var has_bow := false
	var torch_active := false
	var torch_remaining_seconds := 0.0

	func clear_inactive_torch_state() -> void:
		torch_active = false
		torch_remaining_seconds = 0.0


class TestCampfire:
	extends Node2D

	var active := true
	var fear_radius := 180.0


class TestTrap:
	extends Node2D

	var armed := true
	var damage := 12.0


class TestWall:
	extends Node2D

	var health := 100.0


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_save_system_initializes(failures)
	_test_vector_helpers_round_trip(failures)
	_test_get_player_data_contains_expected_fields(failures)
	_test_restore_player_data_restores_player_state(failures)
	_test_get_building_data_contains_expected_fields(failures)
	_test_restore_building_state_restores_building_fields(failures)
	return failures


func _test_save_system_initializes(failures: Array[String]) -> void:
	var save_system := SAVE_SYSTEM_SCRIPT.new()
	TEST_UTILS.expect(save_system != null, failures, "SaveSystem should instantiate")


func _test_vector_helpers_round_trip(failures: Array[String]) -> void:
	var save_system := SAVE_SYSTEM_SCRIPT.new()
	var original := Vector2(42.0, -12.5)
	var data: Dictionary = Dictionary(save_system.call("_vector_to_data", original))
	var restored := save_system.call("_data_to_vector", data) as Vector2
	TEST_UTILS.expect_close(restored.x, original.x, failures, "Vector helper should preserve X")
	TEST_UTILS.expect_close(restored.y, original.y, failures, "Vector helper should preserve Y")


func _test_get_player_data_contains_expected_fields(failures: Array[String]) -> void:
	var save_system := SAVE_SYSTEM_SCRIPT.new()
	var player := _make_player()
	player.stats.health = 88.0
	player.stats.hunger = 64.0
	player.stats.stamina = 55.0
	player.stats.rest = 72.0
	player.inventory.add_item("wood", 2)
	player.has_spear = true
	player.torch_active = true
	player.torch_remaining_seconds = 12.5
	var data: Dictionary = Dictionary(save_system.call("_get_player_data", player))
	TEST_UTILS.expect(data.has("position"), failures, "Player save data should contain position")
	TEST_UTILS.expect(data.has("stats"), failures, "Player save data should contain stats")
	TEST_UTILS.expect(data.has("inventory"), failures, "Player save data should contain inventory")
	TEST_UTILS.expect(data.get("has_spear", false) == true, failures, "Player save data should contain spear state")
	TEST_UTILS.expect(data.get("torch_active", false) == true, failures, "Player save data should contain torch state")
	var stats: Dictionary = Dictionary(data.get("stats", {}))
	var inventory: Dictionary = Dictionary(data.get("inventory", {}))
	TEST_UTILS.expect_close(float(stats.get("health", 0.0)), 88.0, failures, "Player save data should capture health")
	TEST_UTILS.expect_close(float(stats.get("hunger", 0.0)), 64.0, failures, "Player save data should capture hunger")
	TEST_UTILS.expect_close(float(stats.get("stamina", 0.0)), 55.0, failures, "Player save data should capture stamina")
	TEST_UTILS.expect_close(float(stats.get("rest", 0.0)), 72.0, failures, "Player save data should capture rest")
	TEST_UTILS.expect_equal(int(inventory.get("wood", 0)), 2, failures, "Player save data should capture inventory items")


func _test_restore_player_data_restores_player_state(failures: Array[String]) -> void:
	var save_system := SAVE_SYSTEM_SCRIPT.new()
	var player := _make_player()
	save_system.call("_restore_player_data", player, {
		"position": {"x": 42.0, "y": -12.0},
		"stats": {"health": 75.0, "hunger": 60.0, "stamina": 70.0, "rest": 80.0},
		"inventory": {"wood": 3},
		"has_spear": true,
		"has_bow": true,
		"torch_active": true,
		"torch_remaining_seconds": 12.5
	})
	TEST_UTILS.expect_close(player.global_position.x, 42.0, failures, "Player X should be restored")
	TEST_UTILS.expect_close(player.global_position.y, -12.0, failures, "Player Y should be restored")
	TEST_UTILS.expect_close(player.stats.health, 75.0, failures, "Player health should be restored")
	TEST_UTILS.expect_close(player.stats.hunger, 60.0, failures, "Player hunger should be restored")
	TEST_UTILS.expect_close(player.stats.stamina, 70.0, failures, "Player stamina should be restored")
	TEST_UTILS.expect_close(player.stats.rest, 80.0, failures, "Player rest should be restored")
	TEST_UTILS.expect_equal(player.inventory.get_amount("wood"), 3, failures, "Player inventory should be restored")
	TEST_UTILS.expect(player.torch_active, failures, "Player torch state should be restored")
	TEST_UTILS.expect(player.has_spear == true, failures, "Player spear state should be restored")
	TEST_UTILS.expect(player.has_bow == true, failures, "Player bow state should be restored")
	TEST_UTILS.expect_close(player.torch_remaining_seconds, 12.5, failures, "Player torch duration should be restored")


func _test_get_building_data_contains_expected_fields(failures: Array[String]) -> void:
	var save_system := SAVE_SYSTEM_SCRIPT.new()
	var campfire := TestCampfire.new()
	campfire.global_position = Vector2(10.0, 20.0)
	var trap := TestTrap.new()
	trap.global_position = Vector2(30.0, 40.0)
	var wall := TestWall.new()
	wall.global_position = Vector2(50.0, 60.0)
	var campfire_data: Dictionary = Dictionary(save_system.call("_get_building_data", "campfire", campfire))
	var trap_data: Dictionary = Dictionary(save_system.call("_get_building_data", "trap", trap))
	var wall_data: Dictionary = Dictionary(save_system.call("_get_building_data", "wall", wall))
	TEST_UTILS.expect_equal(campfire_data.get("kind", ""), "campfire", failures, "Campfire save data should contain the kind")
	TEST_UTILS.expect_equal(trap_data.get("kind", ""), "trap", failures, "Trap save data should contain the kind")
	TEST_UTILS.expect_equal(wall_data.get("kind", ""), "wall", failures, "Wall save data should contain the kind")
	TEST_UTILS.expect(campfire_data.has("position"), failures, "Campfire save data should contain position")


func _test_restore_building_state_restores_building_fields(failures: Array[String]) -> void:
	var save_system := SAVE_SYSTEM_SCRIPT.new()
	var campfire := TestCampfire.new()
	var trap := TestTrap.new()
	var wall := TestWall.new()
	save_system.call("_restore_building_state", "campfire", campfire, {"active": false, "fear_radius": 260.0})
	save_system.call("_restore_building_state", "trap", trap, {"armed": false, "damage": 24.0})
	save_system.call("_restore_building_state", "wall", wall, {"health": 65.0})
	TEST_UTILS.expect(not campfire.active, failures, "Campfire active state should be restored")
	TEST_UTILS.expect_close(campfire.fear_radius, 260.0, failures, "Campfire fear radius should be restored")
	TEST_UTILS.expect(not trap.armed, failures, "Trap armed state should be restored")
	TEST_UTILS.expect_close(trap.damage, 24.0, failures, "Trap damage should be restored")
	TEST_UTILS.expect_close(wall.health, 65.0, failures, "Wall health should be restored")


func _make_player() -> TestPlayer:
	return TestPlayer.new()
