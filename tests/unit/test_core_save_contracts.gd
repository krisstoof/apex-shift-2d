extends RefCounted

const GAME_SAVE_DATA := preload("res://scripts/core/save/game_save_data.gd")
const SAVE_SERIALIZER := preload("res://scripts/core/save/save_serializer.gd")
const SAVE_SYSTEM := preload("res://scripts/systems/save_system.gd")
const INVENTORY := preload("res://scripts/player/inventory.gd")
const PLAYER_STATS := preload("res://scripts/player/player_stats.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_game_save_data_has_version_field(failures)
	_test_save_serializer_sanitizes_vectors_and_non_finite_values(failures)
	_test_save_serializer_round_trip_is_equivalent(failures)
	_test_save_system_legacy_inventory_migration_still_works(failures)
	return failures


func _test_game_save_data_has_version_field(failures: Array[String]) -> void:
	var save_data := GAME_SAVE_DATA.new()
	TEST_UTILS.expect(save_data.has_method("to_save_data"), failures, "GameSaveData should expose to_save_data")
	TEST_UTILS.expect_equal(int(save_data.version), 5, failures, "GameSaveData should expose a version field")


func _test_save_serializer_sanitizes_vectors_and_non_finite_values(failures: Array[String]) -> void:
	var payload := {
		"vector2": Vector2(12.5, -9.25),
		"vector2i": Vector2i(7, 3),
		"finite": 4.5,
		"nan_value": NAN,
		"inf_value": INF,
		"nested": {
			"position": Vector2(1.0, 2.0)
		}
	}
	var sanitized := Dictionary(SAVE_SERIALIZER.serialize(payload))
	TEST_UTILS.expect(sanitized.get("vector2") is Dictionary, failures, "Serializer should convert Vector2 to dictionaries")
	TEST_UTILS.expect(sanitized.get("vector2i") is Dictionary, failures, "Serializer should convert Vector2i to dictionaries")
	TEST_UTILS.expect_equal(sanitized.get("nan_value"), null, failures, "Serializer should null out NaN")
	TEST_UTILS.expect_equal(sanitized.get("inf_value"), null, failures, "Serializer should null out Inf")
	var vector2 := Dictionary(sanitized.get("vector2", {}))
	TEST_UTILS.expect_close(float(vector2.get("x", 0.0)), 12.5, failures, "Vector2 X should be preserved")
	TEST_UTILS.expect_close(float(vector2.get("y", 0.0)), -9.25, failures, "Vector2 Y should be preserved")


func _test_save_serializer_round_trip_is_equivalent(failures: Array[String]) -> void:
	var raw := {
		"version": 5,
		"world": {
			"world_seed": 42,
			"landmarks": [{"id": "pond", "position": {"x": 1.0, "y": 2.0}}]
		},
		"world_generation": {
			"version": 1,
			"layout": {"seed": 42}
		},
		"player": {
			"position": {"x": 4.0, "y": 8.0},
			"inventory": {"slots": [{"item_id": "wood", "amount": 3}]}
		},
		"resources": [{"kind": "conifer_tree", "position": {"x": 9.0, "y": 10.0}}],
		"varnaks": [],
		"small_prey": [],
		"grazers": [],
		"buildings": [],
		"storage_boxes": [],
		"day_night": {"day": 2, "time_of_day": 0.5},
		"evolution": {"generation": 7},
		"ecosystem": {"biomass": 1.0}
	}
	var serialized := SAVE_SERIALIZER.serialize(SAVE_SERIALIZER.deserialize(raw))
	TEST_UTILS.expect_equal(JSON.stringify(serialized), JSON.stringify(SAVE_SERIALIZER.serialize(raw)), failures, "Serialize/deserialize/serialize should be stable")


func _test_save_system_legacy_inventory_migration_still_works(failures: Array[String]) -> void:
	var save_system := SAVE_SYSTEM.new()
	var player := _make_player()
	save_system.call("_restore_player_data", player, {
		"position": {"x": 0.0, "y": 0.0},
		"stats": {},
		"wood": 2,
		"stone": 3,
		"fiber": 4,
		"meat": 5,
		"bone": 6
	})
	TEST_UTILS.expect_equal(player.inventory.get_amount("wood"), 2, failures, "Legacy inventory wood should migrate")
	TEST_UTILS.expect_equal(player.inventory.get_amount("stone"), 3, failures, "Legacy inventory stone should migrate")
	TEST_UTILS.expect_equal(player.inventory.get_amount("bone"), 6, failures, "Legacy inventory bone should migrate")


func _make_player() -> Node2D:
	var player := MockPlayer.new()
	return player


class MockPlayer:
	extends Node2D

	var stats := PLAYER_STATS.new()
	var inventory := INVENTORY.new()
	var hotbar_state: Variant = null
	var has_spear := false
	var has_bow := false
	var torch_active := false
	var torch_remaining_seconds := 0.0

	func clear_inactive_torch_state() -> void:
		torch_active = false
		torch_remaining_seconds = 0.0
