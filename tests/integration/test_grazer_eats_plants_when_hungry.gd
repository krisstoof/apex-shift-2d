extends RefCounted

const INTEGRATION := preload("res://tests/integration/integration_test_utils.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var context := await INTEGRATION.boot_main()
	var tree := context.get("tree") as SceneTree
	var main := context.get("main") as Node
	if tree == null or main == null:
		failures.append("Integration bootstrap failed")
		return failures

	var world := main.get_node_or_null("World")
	var player := main.get_node_or_null("Player") as Node2D
	TEST_UTILS.expect(world != null, failures, "Main scene should include World")
	TEST_UTILS.expect(player != null, failures, "Main scene should include Player")
	if world == null or player == null:
		await INTEGRATION.shutdown_main(context)
		return failures

	player.global_position = Vector2(-100000.0, -100000.0)
	var grazer := INTEGRATION.get_first_valid_node_in_group(tree, "grazer") as Node2D
	TEST_UTILS.expect(grazer != null, failures, "Fresh world should spawn at least one grazer")
	if grazer == null:
		await INTEGRATION.shutdown_main(context)
		return failures

	INTEGRATION.clear_nodes_in_group_near_position(tree, "edible_vegetation", grazer.global_position, 260.0)
	INTEGRATION.refresh_world_cache(world)
	var food_position := grazer.global_position + Vector2(18.0, 0.0)
	var plant := INTEGRATION.spawn_resource(world, "grass_patch", food_position)
	TEST_UTILS.expect(plant != null, failures, "The test should spawn a control plant resource")
	if plant == null:
		await INTEGRATION.shutdown_main(context)
		return failures

	var hunger_before: float = float(grazer.hunger_diet.hunger)
	grazer.hunger_diet.hunger = 0.90
	grazer.call("_sync_hunger_fields")
	grazer.call("_update_state")
	TEST_UTILS.expect_equal(grazer.state, grazer.State.SEEK_FOOD, failures, "Hungry grazer should seek food")
	TEST_UTILS.expect(is_instance_valid(grazer.plant_target), failures, "Hungry grazer should lock a plant target")
	TEST_UTILS.expect(grazer.plant_target == plant, failures, "Hungry grazer should choose the closest plant")
	grazer.call("_act", 0.0)
	TEST_UTILS.expect(grazer.velocity.length() > 0.0 or grazer.state == grazer.State.EAT_PLANTS, failures, "Hungry grazer should either move toward or start eating the plant")
	grazer.global_position = food_position
	grazer.call("_update_state")
	grazer.call("_consume_plants")
	TEST_UTILS.expect(grazer.hunger_diet.hunger < hunger_before, failures, "Eating plants should reduce grazer hunger")
	TEST_UTILS.expect(float(plant.get("growth_stage")) < float(plant.get("max_growth_stage")), failures, "Plant resource should be partially consumed")
	TEST_UTILS.expect_equal(grazer.last_food_source, "plants", failures, "Plant eating should be recorded as the food source")

	await INTEGRATION.shutdown_main(context)
	return failures
