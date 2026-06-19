extends RefCounted

const CORE_WORLD_SPATIAL_INDEX := preload("res://scripts/core/spatial/world_spatial_index.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_register_and_query_circle(failures)
	_test_update_entity_position_moves_between_queries(failures)
	_test_unregister_removes_entity(failures)
	_test_query_rect(failures)
	_test_category_filter(failures)
	_test_type_filter(failures)
	_test_supported_categories(failures)
	_test_metadata_payload_is_optional(failures)
	return failures


func _test_register_and_query_circle(failures: Array[String]) -> void:
	var index := CORE_WORLD_SPATIAL_INDEX.new()
	index.register_entity("resource:1", Vector2(100.0, 100.0), "resource", {"type": "berry_bush"})
	var found := index.query_circle(Vector2(100.0, 100.0), 32.0, "resource")
	TEST_UTILS.expect_equal(found.size(), 1, failures, "Circle query should return registered entity")
	TEST_UTILS.expect_equal(found[0].entity_id, "resource:1", failures, "Circle query should preserve entity id")


func _test_update_entity_position_moves_between_queries(failures: Array[String]) -> void:
	var index := CORE_WORLD_SPATIAL_INDEX.new()
	index.register_entity("resource:1", Vector2(10.0, 10.0), "resource", {"type": "berry_bush"})
	index.update_entity_position("resource:1", Vector2(600.0, 10.0))
	var old_query := index.query_circle(Vector2(10.0, 10.0), 64.0, "resource")
	var new_query := index.query_circle(Vector2(600.0, 10.0), 64.0, "resource")
	TEST_UTILS.expect_equal(old_query.size(), 0, failures, "Entity should leave old circle after position update")
	TEST_UTILS.expect_equal(new_query.size(), 1, failures, "Entity should be found near new position")
	TEST_UTILS.expect_equal(index.get_entity_cell_by_id("resource:1"), Vector2i(2, 0), failures, "Entity cell should update")


func _test_unregister_removes_entity(failures: Array[String]) -> void:
	var index := CORE_WORLD_SPATIAL_INDEX.new()
	index.register_entity("creature:1", Vector2(100.0, 100.0), "creature", {"type": "small_prey"})
	index.unregister_entity("creature:1")
	var found := index.query_circle(Vector2(100.0, 100.0), 64.0, "creature")
	TEST_UTILS.expect_equal(found.size(), 0, failures, "Unregistered entity should not be returned")
	TEST_UTILS.expect_equal(index.has_entity_id("creature:1"), false, failures, "Unregistered entity id should not be tracked")


func _test_query_rect(failures: Array[String]) -> void:
	var index := CORE_WORLD_SPATIAL_INDEX.new()
	index.register_entity("resource:inside", Vector2(100.0, 100.0), "resource", {"type": "tree"})
	index.register_entity("resource:outside", Vector2(500.0, 500.0), "resource", {"type": "tree"})
	var found := index.query_rect(Rect2(Vector2(50.0, 50.0), Vector2(100.0, 100.0)), "resource")
	TEST_UTILS.expect_equal(found.size(), 1, failures, "Rect query should return only entity inside rect")
	TEST_UTILS.expect_equal(found[0].entity_id, "resource:inside", failures, "Rect query should return correct entity")


func _test_category_filter(failures: Array[String]) -> void:
	var index := CORE_WORLD_SPATIAL_INDEX.new()
	index.register_entity("resource:1", Vector2(100.0, 100.0), "resource", {"type": "tree"})
	index.register_entity("creature:1", Vector2(100.0, 100.0), "creature", {"type": "small_prey"})
	var resources := index.query_circle(Vector2(100.0, 100.0), 32.0, "resource")
	var creatures := index.query_circle(Vector2(100.0, 100.0), 32.0, "creature")
	TEST_UTILS.expect_equal(resources.size(), 1, failures, "Category filter should return resource only")
	TEST_UTILS.expect_equal(resources[0].entity_id, "resource:1", failures, "Resource category filter should preserve resource id")
	TEST_UTILS.expect_equal(creatures.size(), 1, failures, "Category filter should return creature only")
	TEST_UTILS.expect_equal(creatures[0].entity_id, "creature:1", failures, "Creature category filter should preserve creature id")


func _test_type_filter(failures: Array[String]) -> void:
	var index := CORE_WORLD_SPATIAL_INDEX.new()
	index.register_entity("resource:berry", Vector2(100.0, 100.0), "resource", {"type": "berry_bush"})
	index.register_entity("resource:grass", Vector2(110.0, 100.0), "resource", {"type": "grass_patch"})
	var found := index.query_circle(Vector2(100.0, 100.0), 64.0, "resource", "berry_bush")
	var found_multi := index.query_circle(Vector2(100.0, 100.0), 64.0, "resource", ["berry_bush", "grass_patch"])
	TEST_UTILS.expect_equal(found.size(), 1, failures, "Type filter should return matching type only")
	TEST_UTILS.expect_equal(found[0].entity_id, "resource:berry", failures, "Type filter should preserve matching id")
	TEST_UTILS.expect_equal(found_multi.size(), 2, failures, "Array type filter should match multiple types")


func _test_supported_categories(failures: Array[String]) -> void:
	var index := CORE_WORLD_SPATIAL_INDEX.new()
	index.register_entity("building:1", Vector2(100.0, 100.0), "building", {"type": "campfire"})
	index.register_entity("meat:1", Vector2(110.0, 100.0), "meat", {"type": "meat_drop"})
	index.register_entity("decoration:1", Vector2(120.0, 100.0), "decoration", {"type": "grass_visual"})
	TEST_UTILS.expect_equal(index.query_circle(Vector2(100.0, 100.0), 64.0, "building").size(), 1, failures, "Index should support building category")
	TEST_UTILS.expect_equal(index.query_circle(Vector2(100.0, 100.0), 64.0, "meat").size(), 1, failures, "Index should support meat category")
	TEST_UTILS.expect_equal(index.query_circle(Vector2(100.0, 100.0), 64.0, "decoration").size(), 1, failures, "Index should support decoration category")


func _test_metadata_payload_is_optional(failures: Array[String]) -> void:
	var index := CORE_WORLD_SPATIAL_INDEX.new()
	index.register_entity("resource:1", Vector2(100.0, 100.0), "resource", {})
	var found := index.query_circle(Vector2(100.0, 100.0), 32.0, "resource")
	TEST_UTILS.expect_equal(found.size(), 1, failures, "Index should not require payload metadata")
	TEST_UTILS.expect_equal(found[0].get_payload(null), null, failures, "Payload should be optional")
