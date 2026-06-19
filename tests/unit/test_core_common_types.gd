extends RefCounted

const ENTITY_ID := preload("res://scripts/core/common/entity_id.gd")
const GAME_POSITION := preload("res://scripts/core/common/game_position.gd")
const GAME_RECT := preload("res://scripts/core/common/game_rect.gd")
const GAME_RESULT := preload("res://scripts/core/common/game_result.gd")
const GAME_TIME := preload("res://scripts/core/common/game_time.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_entity_id_validity_and_equality(failures)
	_test_entity_id_serialization(failures)
	_test_game_position_vector_conversion_and_distance(failures)
	_test_game_position_serialization(failures)
	_test_game_rect_contains_and_intersects(failures)
	_test_game_rect_conversion_and_serialization(failures)
	_test_game_result_success_and_failure(failures)
	_test_game_result_serialization(failures)
	_test_game_time_advance_and_copy(failures)
	_test_game_time_serialization(failures)
	return failures


func _test_entity_id_validity_and_equality(failures: Array[String]) -> void:
	var empty_id := ENTITY_ID.new("")
	var id_a := ENTITY_ID.new("creature:1")
	var id_b := ENTITY_ID.new("creature:1")
	var id_c := ENTITY_ID.new("creature:2")

	TEST_UTILS.expect_equal(empty_id.is_valid(), false, failures, "Empty EntityId should be invalid")
	TEST_UTILS.expect(id_a.is_valid(), failures, "Non-empty EntityId should be valid")
	TEST_UTILS.expect(id_a.equals(id_b), failures, "EntityIds with the same value should be equal")
	TEST_UTILS.expect_equal(id_a.equals(id_c), false, failures, "EntityIds with different values should not be equal")
	TEST_UTILS.expect_equal(id_a.as_string(), "creature:1", failures, "EntityId should expose its string value")


func _test_entity_id_serialization(failures: Array[String]) -> void:
	var id := ENTITY_ID.new("resource:berry:3")
	var restored := ENTITY_ID.from_dict(id.to_dict())

	TEST_UTILS.expect(restored.equals(id), failures, "EntityId should preserve value through dict serialization")


func _test_game_position_vector_conversion_and_distance(failures: Array[String]) -> void:
	var position := GAME_POSITION.new(3.0, 4.0)
	var vector := position.to_vector2()
	var restored := GAME_POSITION.from_vector2(Vector2(3.0, 4.0))
	var origin := GAME_POSITION.zero()

	TEST_UTILS.expect_equal(vector, Vector2(3.0, 4.0), failures, "GamePosition should convert to Vector2")
	TEST_UTILS.expect(position.equals(restored), failures, "GamePosition should restore from Vector2")
	TEST_UTILS.expect_close(origin.distance_to(position), 5.0, failures, "GamePosition should calculate distance")
	TEST_UTILS.expect_close(origin.distance_squared_to(position), 25.0, failures, "GamePosition should calculate squared distance")


func _test_game_position_serialization(failures: Array[String]) -> void:
	var position := GAME_POSITION.new(12.5, -4.25)
	var restored := GAME_POSITION.from_dict(position.to_dict())

	TEST_UTILS.expect(position.equals(restored), failures, "GamePosition should preserve values through dict serialization")


func _test_game_rect_contains_and_intersects(failures: Array[String]) -> void:
	var rect := GAME_RECT.new(10.0, 20.0, 100.0, 50.0)
	var inside := GAME_POSITION.new(20.0, 30.0)
	var outside := GAME_POSITION.new(500.0, 30.0)
	var overlap := GAME_RECT.new(50.0, 40.0, 20.0, 20.0)
	var separate := GAME_RECT.new(500.0, 500.0, 10.0, 10.0)

	TEST_UTILS.expect(rect.contains_position(inside), failures, "GameRect should contain inner position")
	TEST_UTILS.expect_equal(rect.contains_position(outside), false, failures, "GameRect should reject outside position")
	TEST_UTILS.expect(rect.intersects(overlap), failures, "GameRect should intersect overlapping rect")
	TEST_UTILS.expect_equal(rect.intersects(separate), false, failures, "GameRect should not intersect separate rect")


func _test_game_rect_conversion_and_serialization(failures: Array[String]) -> void:
	var rect := GAME_RECT.new(1.0, 2.0, 3.0, 4.0)
	var rect2 := rect.to_rect2()
	var from_rect2 := GAME_RECT.from_rect2(Rect2(Vector2(1.0, 2.0), Vector2(3.0, 4.0)))
	var restored := GAME_RECT.from_dict(rect.to_dict())

	TEST_UTILS.expect_equal(rect2, Rect2(Vector2(1.0, 2.0), Vector2(3.0, 4.0)), failures, "GameRect should convert to Rect2")
	TEST_UTILS.expect(rect.equals(from_rect2), failures, "GameRect should restore from Rect2")
	TEST_UTILS.expect(rect.equals(restored), failures, "GameRect should preserve values through dict serialization")


func _test_game_result_success_and_failure(failures: Array[String]) -> void:
	var ok_result := GAME_RESULT.ok({"amount": 3})
	var fail_result := GAME_RESULT.fail("Not enough resources", {"missing": "wood"})

	TEST_UTILS.expect(ok_result.is_ok(), failures, "GameResult.ok should create successful result")
	TEST_UTILS.expect_equal(ok_result.is_failed(), false, failures, "Successful result should not be failed")
	TEST_UTILS.expect_equal(Dictionary(ok_result.data).get("amount", 0), 3, failures, "Successful result should preserve data")

	TEST_UTILS.expect(fail_result.is_failed(), failures, "GameResult.fail should create failed result")
	TEST_UTILS.expect_equal(fail_result.is_ok(), false, failures, "Failed result should not be ok")
	TEST_UTILS.expect_equal(fail_result.message, "Not enough resources", failures, "Failed result should preserve message")
	TEST_UTILS.expect_equal(Dictionary(fail_result.data).get("missing", ""), "wood", failures, "Failed result should preserve data")


func _test_game_result_serialization(failures: Array[String]) -> void:
	var result := GAME_RESULT.fail("Blocked", {"reason": "water"})
	var restored := GAME_RESULT.from_dict(result.to_dict())

	TEST_UTILS.expect(restored.is_failed(), failures, "GameResult should preserve failure state through dict serialization")
	TEST_UTILS.expect_equal(restored.message, "Blocked", failures, "GameResult should preserve message through dict serialization")
	TEST_UTILS.expect_equal(Dictionary(restored.data).get("reason", ""), "water", failures, "GameResult should preserve data through dict serialization")


func _test_game_time_advance_and_copy(failures: Array[String]) -> void:
	var game_time := GAME_TIME.new(1, 90.0, 90.0)
	var copied := game_time.copy()

	game_time.advance(45.0, 120.0)

	TEST_UTILS.expect_equal(game_time.day, 2, failures, "GameTime should advance to next day after day length is exceeded")
	TEST_UTILS.expect_close(game_time.seconds_of_day, 15.0, failures, "GameTime should wrap seconds of day")
	TEST_UTILS.expect_close(game_time.total_seconds, 135.0, failures, "GameTime should increase total seconds")
	TEST_UTILS.expect_equal(copied.day, 1, failures, "GameTime copy should be independent")
	TEST_UTILS.expect_close(copied.seconds_of_day, 90.0, failures, "GameTime copy should preserve original seconds of day")


func _test_game_time_serialization(failures: Array[String]) -> void:
	var game_time := GAME_TIME.new(3, 42.5, 250.0)
	var restored := GAME_TIME.from_dict(game_time.to_dict())

	TEST_UTILS.expect_equal(restored.day, 3, failures, "GameTime should preserve day through dict serialization")
	TEST_UTILS.expect_close(restored.seconds_of_day, 42.5, failures, "GameTime should preserve seconds of day through dict serialization")
	TEST_UTILS.expect_close(restored.total_seconds, 250.0, failures, "GameTime should preserve total seconds through dict serialization")
