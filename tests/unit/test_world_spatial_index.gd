extends RefCounted

const SPATIAL_INDEX := preload("res://scripts/world/world_spatial_index.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_register_resource(failures)
	_test_unregister_resource(failures)
	_test_update_cell_moves_entity_between_cells(failures)
	_test_query_radius_filters_by_distance(failures)
	_test_query_rect_returns_only_nodes_inside_rect(failures)
	_test_query_type_filter_matches_resources(failures)
	_test_query_type_filter_matches_creatures(failures)
	_test_meat_query_uses_meat_category(failures)
	_test_invalid_node_does_not_crash_queries(failures)
	return failures


func _make_node(tree: SceneTree, position: Vector2) -> Node2D:
	var node := Node2D.new()
	node.global_position = position
	tree.current_scene.add_child(node)
	return node


func _test_register_resource(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var index := SPATIAL_INDEX.new()
	var node := _make_node(tree, Vector2(64.0, 64.0))
	index.register_entity(node, "resource", "berry_bush")
	TEST_UTILS.expect_equal(index.query_resources_near(Vector2(64.0, 64.0), 32.0, "berry_bush").size(), 1, failures, "Registered resource should be found near its cell")
	node.queue_free()


func _test_unregister_resource(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var index := SPATIAL_INDEX.new()
	var node := _make_node(tree, Vector2(64.0, 64.0))
	index.register_entity(node, "resource", "berry_bush")
	index.unregister_entity(node)
	TEST_UTILS.expect_equal(index.query_resources_near(Vector2(64.0, 64.0), 32.0, "berry_bush").size(), 0, failures, "Unregistered resource should not be returned")
	node.queue_free()


func _test_update_cell_moves_entity_between_cells(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var index := SPATIAL_INDEX.new()
	var node := _make_node(tree, Vector2(10.0, 10.0))
	index.register_entity(node, "resource", "berry_bush")
	node.global_position = Vector2(600.0, 10.0)
	index.update_entity_cell(node)
	TEST_UTILS.expect_equal(index.query_resources_near(Vector2(10.0, 10.0), 64.0, "berry_bush").size(), 0, failures, "Moved resource should leave the old cell")
	TEST_UTILS.expect_equal(index.query_resources_near(Vector2(600.0, 10.0), 64.0, "berry_bush").size(), 1, failures, "Moved resource should appear in the new cell")
	node.queue_free()


func _test_query_radius_filters_by_distance(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var index := SPATIAL_INDEX.new()
	var near_node := _make_node(tree, Vector2(20.0, 20.0))
	var far_node := _make_node(tree, Vector2(400.0, 20.0))
	index.register_entity(near_node, "resource", "berry_bush")
	index.register_entity(far_node, "resource", "berry_bush")
	TEST_UTILS.expect_equal(index.query_resources_near(Vector2(0.0, 0.0), 80.0, "berry_bush").size(), 1, failures, "Radius query should only return nearby nodes")
	near_node.queue_free()
	far_node.queue_free()


func _test_query_rect_returns_only_nodes_inside_rect(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var index := SPATIAL_INDEX.new()
	var inside := _make_node(tree, Vector2(64.0, 64.0))
	var outside := _make_node(tree, Vector2(600.0, 600.0))
	index.register_entity(inside, "resource", "berry_bush")
	index.register_entity(outside, "resource", "berry_bush")
	var result := index.query_resources_in_rect(Rect2(Vector2.ZERO, Vector2(128.0, 128.0)), "berry_bush")
	TEST_UTILS.expect_equal(result.size(), 1, failures, "Rect query should return only resource inside rect")
	inside.queue_free()
	outside.queue_free()


func _test_query_type_filter_matches_resources(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var index := SPATIAL_INDEX.new()
	var berry := _make_node(tree, Vector2(32.0, 32.0))
	var rock := _make_node(tree, Vector2(40.0, 32.0))
	index.register_entity(berry, "resource", "berry_bush")
	index.register_entity(rock, "resource", "rock")
	TEST_UTILS.expect_equal(index.query_resources_near(Vector2(0.0, 0.0), 80.0, "berry_bush").size(), 1, failures, "Resource type filter should keep only matching resources")
	berry.queue_free()
	rock.queue_free()


func _test_query_type_filter_matches_creatures(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var index := SPATIAL_INDEX.new()
	var small_prey := _make_node(tree, Vector2(16.0, 16.0))
	var grazer := _make_node(tree, Vector2(24.0, 16.0))
	index.register_entity(small_prey, "creature", "small_prey")
	index.register_entity(grazer, "creature", "grazer")
	TEST_UTILS.expect_equal(index.query_creatures_near(Vector2(0.0, 0.0), 80.0, "small_prey").size(), 1, failures, "Creature type filter should keep only matching creatures")
	small_prey.queue_free()
	grazer.queue_free()


func _test_meat_query_uses_meat_category(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var index := SPATIAL_INDEX.new()
	var meat_drop := _make_node(tree, Vector2(48.0, 48.0))
	index.register_entity(meat_drop, "meat", "meat_drop")
	TEST_UTILS.expect_equal(index.query_meat_near(Vector2(48.0, 48.0), 24.0).size(), 1, failures, "Meat query should use the dedicated meat category")
	meat_drop.queue_free()


func _test_invalid_node_does_not_crash_queries(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var index := SPATIAL_INDEX.new()
	var node := _make_node(tree, Vector2(64.0, 64.0))
	index.register_entity(node, "resource", "berry_bush")
	node.queue_free()
	await tree.process_frame
	var result := index.query_resources_near(Vector2(64.0, 64.0), 32.0, "berry_bush")
	TEST_UTILS.expect_equal(result.size(), 0, failures, "Query should ignore freed nodes")
