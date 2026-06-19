extends RefCounted

const WORLD_ENTITY_REGISTRY := preload("res://scripts/core/world/world_entity_registry.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_register_entity_stores_data(failures)
	_test_update_entity_position_updates_spatial_query(failures)
	_test_unregister_entity_removes_from_registry_and_spatial_index(failures)
	_test_query_circle_through_registry(failures)
	_test_query_rect_through_registry(failures)
	_test_category_and_type_filters(failures)
	_test_active_state_removes_entity_from_spatial_queries(failures)
	_test_biome_filter(failures)
	return failures


func _test_register_entity_stores_data(failures: Array[String]) -> void:
	var registry := WORLD_ENTITY_REGISTRY.new()
	registry.register_entity("resource:1", "resource", "berry_bush", Vector2(100.0, 100.0), "hearth_meadow", {"amount": 3})
	var record := registry.get_entity("resource:1")
	TEST_UTILS.expect_equal(record.get("entity_id", ""), "resource:1", failures, "Registry should preserve entity id")
	TEST_UTILS.expect_equal(record.get("category", ""), "resource", failures, "Registry should preserve category")
	TEST_UTILS.expect_equal(record.get("type", ""), "berry_bush", failures, "Registry should preserve type")
	TEST_UTILS.expect_equal(record.get("biome_id", ""), "hearth_meadow", failures, "Registry should preserve biome id")
	TEST_UTILS.expect_equal(Dictionary(record.get("metadata", {})).get("amount", 0), 3, failures, "Registry should preserve metadata")


func _test_update_entity_position_updates_spatial_query(failures: Array[String]) -> void:
	var registry := WORLD_ENTITY_REGISTRY.new()
	registry.register_entity("resource:1", "resource", "berry_bush", Vector2(10.0, 10.0))
	registry.update_entity_position("resource:1", Vector2(600.0, 10.0))
	var old_query := registry.get_resources_near(Vector2(10.0, 10.0), 64.0, "berry_bush")
	var new_query := registry.get_resources_near(Vector2(600.0, 10.0), 64.0, "berry_bush")
	TEST_UTILS.expect_equal(old_query.size(), 0, failures, "Updated entity should leave old spatial query area")
	TEST_UTILS.expect_equal(new_query.size(), 1, failures, "Updated entity should appear in new spatial query area")
	TEST_UTILS.expect_equal(Dictionary(new_query[0]).get("entity_id", ""), "resource:1", failures, "Spatial query through registry should return correct entity")


func _test_unregister_entity_removes_from_registry_and_spatial_index(failures: Array[String]) -> void:
	var registry := WORLD_ENTITY_REGISTRY.new()
	registry.register_entity("creature:1", "creature", "small_prey", Vector2(100.0, 100.0))
	registry.unregister_entity("creature:1")
	var query := registry.get_creatures_near(Vector2(100.0, 100.0), 64.0, "small_prey")
	TEST_UTILS.expect_equal(registry.has_entity("creature:1"), false, failures, "Unregistered entity should not remain in registry")
	TEST_UTILS.expect_equal(query.size(), 0, failures, "Unregistered entity should not remain in spatial index")


func _test_query_circle_through_registry(failures: Array[String]) -> void:
	var registry := WORLD_ENTITY_REGISTRY.new()
	registry.register_entity("resource:inside", "resource", "tree", Vector2(100.0, 100.0))
	registry.register_entity("resource:outside", "resource", "tree", Vector2(500.0, 500.0))
	var query := registry.get_resources_near(Vector2(100.0, 100.0), 64.0, "tree")
	TEST_UTILS.expect_equal(query.size(), 1, failures, "Circle query should return one nearby resource")
	TEST_UTILS.expect_equal(Dictionary(query[0]).get("entity_id", ""), "resource:inside", failures, "Circle query should return correct resource")


func _test_query_rect_through_registry(failures: Array[String]) -> void:
	var registry := WORLD_ENTITY_REGISTRY.new()
	registry.register_entity("building:inside", "building", "campfire", Vector2(100.0, 100.0))
	registry.register_entity("building:outside", "building", "campfire", Vector2(500.0, 500.0))
	var query := registry.get_buildings_in_rect(Rect2(Vector2(50.0, 50.0), Vector2(100.0, 100.0)), "campfire")
	TEST_UTILS.expect_equal(query.size(), 1, failures, "Rect query should return one building inside rect")
	TEST_UTILS.expect_equal(Dictionary(query[0]).get("entity_id", ""), "building:inside", failures, "Rect query should return correct building")


func _test_category_and_type_filters(failures: Array[String]) -> void:
	var registry := WORLD_ENTITY_REGISTRY.new()
	registry.register_entity("resource:berry", "resource", "berry_bush", Vector2(100.0, 100.0))
	registry.register_entity("resource:grass", "resource", "grass_patch", Vector2(110.0, 100.0))
	registry.register_entity("creature:prey", "creature", "small_prey", Vector2(100.0, 100.0))
	var berries := registry.get_resources_near(Vector2(100.0, 100.0), 64.0, "berry_bush")
	var creatures := registry.get_creatures_near(Vector2(100.0, 100.0), 64.0, "small_prey")
	TEST_UTILS.expect_equal(berries.size(), 1, failures, "Registry should filter resources by type")
	TEST_UTILS.expect_equal(Dictionary(berries[0]).get("entity_id", ""), "resource:berry", failures, "Registry should return matching resource")
	TEST_UTILS.expect_equal(creatures.size(), 1, failures, "Registry should filter creatures by type")
	TEST_UTILS.expect_equal(Dictionary(creatures[0]).get("entity_id", ""), "creature:prey", failures, "Registry should return matching creature")


func _test_active_state_removes_entity_from_spatial_queries(failures: Array[String]) -> void:
	var registry := WORLD_ENTITY_REGISTRY.new()
	registry.register_entity("resource:1", "resource", "berry_bush", Vector2(100.0, 100.0))
	registry.set_entity_active("resource:1", false)
	var query := registry.get_resources_near(Vector2(100.0, 100.0), 64.0, "berry_bush")
	var all_records := registry.get_entities("resource", "berry_bush", true)
	TEST_UTILS.expect_equal(query.size(), 0, failures, "Inactive entity should not appear in spatial queries")
	TEST_UTILS.expect_equal(all_records.size(), 1, failures, "Inactive entity should remain in registry when include_inactive is true")


func _test_biome_filter(failures: Array[String]) -> void:
	var registry := WORLD_ENTITY_REGISTRY.new()
	registry.register_entity("resource:forest", "resource", "berry_bush", Vector2(100.0, 100.0), "westwood")
	registry.register_entity("resource:meadow", "resource", "berry_bush", Vector2(120.0, 100.0), "hearth_meadow")
	var westwood := registry.get_entities_by_biome("resource", "westwood", "berry_bush")
	TEST_UTILS.expect_equal(westwood.size(), 1, failures, "Registry should filter entities by biome")
	TEST_UTILS.expect_equal(Dictionary(westwood[0]).get("entity_id", ""), "resource:forest", failures, "Registry should return entity from requested biome")
