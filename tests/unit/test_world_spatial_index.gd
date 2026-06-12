extends RefCounted

const WORLD_SPATIAL_INDEX := preload("res://scripts/world/world_spatial_index.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_register_resource_queries_nearby_resources(failures)
	_test_unregister_resource_removes_it_from_queries(failures)
	_test_update_entity_cell_moves_entity_between_buckets(failures)
	_test_query_filters_creatures_by_type(failures)
	_test_meat_drop_uses_separate_meat_category(failures)
	_test_query_ignores_queued_for_deletion_entities(failures)
	_test_type_filter_array_matches_multiple_types(failures)
	return failures


func _test_register_resource_queries_nearby_resources(failures: Array[String]) -> void:
	var index := WORLD_SPATIAL_INDEX.new()
	var resource := _make_node(Vector2(96.0, 96.0))
	index.register_entity(resource, "resource", "berry_bush")
	var found := index.query_resources_near(Vector2(96.0, 96.0), 32.0, "berry_bush")
	TEST_UTILS.expect(found.has(resource), failures, "Registered resource should be returned by nearby resource query")


func _test_unregister_resource_removes_it_from_queries(failures: Array[String]) -> void:
	var index := WORLD_SPATIAL_INDEX.new()
	var resource := _make_node(Vector2(96.0, 96.0))
	index.register_entity(resource, "resource", "berry_bush")
	index.unregister_entity(resource)
	var found := index.query_resources_near(Vector2(96.0, 96.0), 64.0, "berry_bush")
	TEST_UTILS.expect_equal(found.has(resource), false, failures, "Unregistered resource should no longer be returned")


func _test_update_entity_cell_moves_entity_between_buckets(failures: Array[String]) -> void:
	var index := WORLD_SPATIAL_INDEX.new()
	var resource := _make_node(Vector2(10.0, 10.0))
	index.register_entity(resource, "resource", "berry_bush")
	resource.global_position = Vector2(600.0, 10.0)
	index.update_entity_cell(resource)
	var old_query := index.query_resources_near(Vector2(10.0, 10.0), 64.0, "berry_bush")
	var new_query := index.query_resources_near(Vector2(600.0, 10.0), 64.0, "berry_bush")
	TEST_UTILS.expect_equal(old_query.has(resource), false, failures, "Resource should leave its old cell after update")
	TEST_UTILS.expect(new_query.has(resource), failures, "Resource should enter its new cell after update")
	TEST_UTILS.expect_equal(index.get_entity_cell(resource), Vector2i(2, 0), failures, "Entity cell should reflect the new position")


func _test_query_filters_creatures_by_type(failures: Array[String]) -> void:
	var index := WORLD_SPATIAL_INDEX.new()
	var small_prey := _make_node(Vector2(128.0, 128.0))
	var grazer := _make_node(Vector2(144.0, 128.0))
	index.register_entity(small_prey, "creature", "small_prey")
	index.register_entity(grazer, "creature", "grazer")
	var filtered := index.query_creatures_near(Vector2(128.0, 128.0), 96.0, "small_prey")
	TEST_UTILS.expect(filtered.has(small_prey), failures, "Creature query should return the requested type")
	TEST_UTILS.expect_equal(filtered.has(grazer), false, failures, "Creature query should filter out other types")


func _test_meat_drop_uses_separate_meat_category(failures: Array[String]) -> void:
	var index := WORLD_SPATIAL_INDEX.new()
	var meat_drop := _make_node(Vector2(192.0, 192.0))
	index.register_entity(meat_drop, "meat", "meat_drop")
	var found := index.query_meat_near(Vector2(192.0, 192.0), 48.0)
	TEST_UTILS.expect(found.has(meat_drop), failures, "Meat drop should be found through the meat query")
	TEST_UTILS.expect_equal(index.query_resources_near(Vector2(192.0, 192.0), 48.0, "meat_drop").has(meat_drop), false, failures, "Meat drop should not be treated as a normal resource bucket entry")


func _test_query_ignores_queued_for_deletion_entities(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var index := WORLD_SPATIAL_INDEX.new()
	var resource := _make_node(Vector2(256.0, 256.0))
	tree.current_scene.add_child(resource)
	index.register_entity(resource, "resource", "berry_bush")
	resource.queue_free()
	var found := index.query_resources_near(Vector2(256.0, 256.0), 64.0, "berry_bush")
	TEST_UTILS.expect_equal(found.has(resource), false, failures, "Queued-for-deletion entities should be ignored by queries")


func _test_type_filter_array_matches_multiple_types(failures: Array[String]) -> void:
	var index := WORLD_SPATIAL_INDEX.new()
	var berry_bush := _make_node(Vector2(320.0, 320.0))
	var grass_patch := _make_node(Vector2(336.0, 320.0))
	index.register_entity(berry_bush, "resource", "berry_bush")
	index.register_entity(grass_patch, "resource", "grass_patch")
	var found := index.query_resources_near(Vector2(320.0, 320.0), 64.0, ["berry_bush", "grass_patch"])
	TEST_UTILS.expect(found.has(berry_bush), failures, "Array type filters should match the first requested type")
	TEST_UTILS.expect(found.has(grass_patch), failures, "Array type filters should match additional requested types")


func _make_node(position: Vector2) -> Node2D:
	var node := Node2D.new()
	node.global_position = position
	return node
