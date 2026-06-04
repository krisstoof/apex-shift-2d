extends RefCounted

const RESOURCE_NODE_SCENE := preload("res://scenes/world/resource_node.tscn")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_resource_node_setup_exposes_herbivore_food(failures)
	_test_resource_node_restore_recreates_edible_food_value(failures)
	return failures


func _test_resource_node_setup_exposes_herbivore_food(failures: Array[String]) -> void:
	var resource := RESOURCE_NODE_SCENE.instantiate()
	resource.call("setup", "tree")
	TEST_UTILS.expect(resource.is_in_group("edible_vegetation"), failures, "Tree resources should belong to edible_vegetation")
	TEST_UTILS.expect(float(resource.get("food_value")) > 0.0, failures, "Tree resources should expose a positive food value")
	var eaten := float(resource.call("consume_by_creature", null, 1.0))
	TEST_UTILS.expect(eaten > 0.0, failures, "Tree resources should return nutrition when consumed")
	TEST_UTILS.expect_equal(int(resource.get("growth_stage")), 2, failures, "Tree consumption should reduce the growth stage by one")
	resource.free()


func _test_resource_node_restore_recreates_edible_food_value(failures: Array[String]) -> void:
	var resource := RESOURCE_NODE_SCENE.instantiate()
	resource.call("restore_from_data", {
		"biome_id": "hearth_meadow",
		"mature_amount": 4,
		"amount": 4,
		"growth_stage": 3,
		"max_growth_stage": 3,
		"growth_progress": 0.0,
		"days_to_next_stage": 1.0,
		"days_since_harvested": 0.0,
		"is_harvested": false,
		"can_be_harvested": true,
		"player_harvestable": true,
		"is_edible_by_herbivores": false,
		"food_value": 0.0,
		"is_pond_vegetation": false,
		"pond_id": "",
		"food_bonus_multiplier": 1.0,
		"pond_visual_multiplier": 1.0
	})
	TEST_UTILS.expect(float(resource.get("food_value")) > 0.0, failures, "Older saves should restore a herbivore food value for trees and bushes")
	TEST_UTILS.expect(bool(resource.get("is_edible_by_herbivores")), failures, "Older saves should rejoin edible_vegetation after restore")
	resource.free()
