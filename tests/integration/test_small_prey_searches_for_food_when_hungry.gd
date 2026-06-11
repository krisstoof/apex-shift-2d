extends RefCounted

const INTEGRATION := preload("res://tests/integration/integration_test_utils.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var context := await INTEGRATION.boot_main()
	if not bool(context.get("ok", false)):
		return [String(context.get("reason", "Integration bootstrap failed"))]
	var tree := context.get("tree") as SceneTree
	var main := context.get("main") as Node
	if tree == null or main == null:
		return ["Integration bootstrap returned invalid tree/main."]

	var world := main.get_node_or_null("World")
	var player := main.get_node_or_null("Player") as Node2D
	TEST_UTILS.expect(world != null, failures, "Main scene should include World")
	TEST_UTILS.expect(player != null, failures, "Main scene should include Player")
	if world == null or player == null:
		await INTEGRATION.shutdown_main(context)
		return failures

	player.global_position = Vector2(100000.0, 100000.0)
	var prey := INTEGRATION.get_first_valid_node_in_group(tree, "small_prey") as Node2D
	TEST_UTILS.expect(prey != null, failures, "Fresh world should spawn at least one small prey")
	if prey == null:
		await INTEGRATION.shutdown_main(context)
		return failures

	INTEGRATION.clear_nodes_in_group_near_position(tree, "edible_vegetation", prey.global_position, 260.0)
	INTEGRATION.refresh_world_cache(world)
	var near_food_position := prey.global_position + Vector2(80.0, 0.0)
	var far_food_position := prey.global_position + Vector2(300.0, 0.0)
	var near_food := INTEGRATION.spawn_resource(world, "berry_bush", near_food_position)
	var far_food := INTEGRATION.spawn_resource(world, "small_bush", far_food_position)
	TEST_UTILS.expect(near_food != null, failures, "The test should spawn a nearby edible bush")
	TEST_UTILS.expect(far_food != null, failures, "The test should spawn a farther edible bush")
	if near_food == null or far_food == null:
		await INTEGRATION.shutdown_main(context)
		return failures

	prey.global_position = prey.global_position
	prey.hunger_diet.hunger = 0.92
	prey.call("_sync_hunger_fields")
	INTEGRATION.refresh_world_cache(world)
	prey.call("force_ai_decision_for_tests")
	TEST_UTILS.expect_equal(prey.state, prey.State.SEEK_FOOD, failures, "Hungry small prey should switch to SEEK_FOOD")
	TEST_UTILS.expect(is_instance_valid(prey.plant_target), failures, "Hungry small prey should lock a plant target")
	TEST_UTILS.expect(prey.plant_target == near_food, failures, "Hungry small prey should choose the closest spawned food source")
	INTEGRATION.assert_valid_node2d_position(failures, prey, "Hungry small prey")
	INTEGRATION.assert_creature_registered(failures, world, prey, "small_prey", "Hungry small prey")
	prey.call("_act", 0.0)
	TEST_UTILS.expect(prey.velocity.length() > 0.0, failures, "Hungry small prey should move toward food")
	var distance_before := prey.global_position.distance_to(near_food.global_position)
	prey.call("_physics_process", 0.16)
	var distance_after := prey.global_position.distance_to(near_food.global_position)
	TEST_UTILS.expect(distance_after < distance_before, failures, "Hungry small prey should close distance to food")

	await INTEGRATION.shutdown_main(context)
	return failures


