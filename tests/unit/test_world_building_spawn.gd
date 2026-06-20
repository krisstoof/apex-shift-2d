extends RefCounted

const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


class TestWorld:
	extends Node

	var spawned := []

	func register_building_node(node: Node, building_type: String) -> void:
		spawned.append({"node": node, "building_type": building_type})


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_world_exposes_spawn_building_for_tests(failures)
	return failures


func _test_world_exposes_spawn_building_for_tests(failures: Array[String]) -> void:
	var world_script := preload("res://scripts/world/world.gd")
	var world := world_script.new()
	var tree := Engine.get_main_loop() as SceneTree
	var scene := Node2D.new()
	scene.name = "TestScene"
	tree.root.add_child(scene)
	scene.add_child(world)
	var building := world.call("spawn_building_for_tests", "campfire", Vector2(72.0, 88.0))
	TEST_UTILS.expect(building != null, failures, "World should expose spawn_building_for_tests")
	if building != null:
		TEST_UTILS.expect_equal((building as Node2D).global_position, Vector2(72.0, 88.0), failures, "World test helper should place the building at the requested position")
	world.queue_free()
	scene.queue_free()
