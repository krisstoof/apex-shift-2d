extends RefCounted

const BUILDING_PLACEMENT_SERVICE := preload("res://scripts/systems/building_placement_service.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


class TestWorld:
	extends Node

	var registered := []

	func register_building_node(node: Node, building_type: String) -> void:
		registered.append({"node": node, "building_type": building_type})


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_building_placement_service_places_and_registers_building(failures)
	_test_building_placement_service_rejects_unknown_building(failures)
	return failures


func _test_building_placement_service_places_and_registers_building(failures: Array[String]) -> void:
	var service := BUILDING_PLACEMENT_SERVICE.new()
	var parent := Node.new()
	var world := TestWorld.new()
	var building := service.place_building("campfire", Vector2(64.0, 32.0), parent, world)
	TEST_UTILS.expect(building != null, failures, "Placement service should instantiate known buildings")
	if building != null:
		TEST_UTILS.expect_equal((building as Node2D).global_position, Vector2(64.0, 32.0), failures, "Placement service should set building position")
	TEST_UTILS.expect_equal(parent.get_child_count(), 1, failures, "Placement service should add the building to the provided parent")
	TEST_UTILS.expect_equal(world.registered.size(), 1, failures, "Placement service should register buildings in the world")
	if world.registered.size() == 1:
		TEST_UTILS.expect_equal(str(world.registered[0].get("building_type", "")), "campfire", failures, "Placement service should register the correct building type")


func _test_building_placement_service_rejects_unknown_building(failures: Array[String]) -> void:
	var service := BUILDING_PLACEMENT_SERVICE.new()
	var parent := Node.new()
	var building := service.place_building("unknown_building", Vector2.ZERO, parent, null)
	TEST_UTILS.expect_equal(building, null, failures, "Placement service should reject unknown building kinds")
	TEST_UTILS.expect_equal(parent.get_child_count(), 0, failures, "Placement service should not add rejected buildings")
