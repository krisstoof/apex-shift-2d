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
	INTEGRATION.clear_nodes_in_group(tree, "small_prey")
	INTEGRATION.clear_nodes_in_group(tree, "meat_drops")
	INTEGRATION.refresh_world_cache(world)

	var biome_id := ""
	var spawn_point: Vector2 = world.call("get_world_rect").get_center()
	for zone_value in world.call("get_biome_zones"):
		if typeof(zone_value) != TYPE_DICTIONARY:
			continue
		var zone := Dictionary(zone_value)
		biome_id = str(zone.get("id", zone.get("name", "")))
		spawn_point = INTEGRATION.find_point_in_biome(world, biome_id)
		break
	if spawn_point == Vector2.ZERO:
		spawn_point = world.call("get_world_rect").get_center()

	var prey := INTEGRATION.spawn_small_prey(world, biome_id, spawn_point) as Node2D
	TEST_UTILS.expect(prey != null, failures, "The test should spawn a controlled small prey")
	if prey == null:
		await INTEGRATION.shutdown_main(context)
		return failures

	var meat_drops_before := INTEGRATION.get_valid_nodes_in_group(tree, "meat_drops").size()
	TEST_UTILS.expect_equal(meat_drops_before, 0, failures, "Test setup should start with no meat drops")
	prey.take_damage(999.0, "varnak")
	await tree.process_frame
	await tree.process_frame
	INTEGRATION.refresh_world_cache(world)

	var meat_drops := INTEGRATION.get_valid_nodes_in_group(tree, "meat_drops")
	TEST_UTILS.expect_equal(meat_drops.size(), 1, failures, "Animal death should create exactly one meat drop")
	if meat_drops.size() == 1:
		var meat_drop := meat_drops[0] as Node2D
		TEST_UTILS.expect(meat_drop != null, failures, "Meat drop should be a Node2D")
		if meat_drop != null:
			TEST_UTILS.expect_equal(str(meat_drop.get("resource_kind")), "meat_drop", failures, "Spawned drop should be a meat_drop resource")
			TEST_UTILS.expect(int(meat_drop.get("amount")) > 0, failures, "Spawned meat drop should have a positive amount")
			TEST_UTILS.expect(meat_drop.global_position.distance_to(spawn_point) < 32.0, failures, "Meat drop should appear where the animal died")
			INTEGRATION.assert_resource_registered(failures, world, meat_drop, "meat_drop", "Meat drop")
			INTEGRATION.assert_valid_node2d_position(failures, meat_drop, "Meat drop")
			INTEGRATION.assert_node_inside_world_rect(failures, world, meat_drop, "Meat drop")
			var save_data: Dictionary = meat_drop.call("get_save_data")
			TEST_UTILS.expect_equal(str(save_data.get("resource_kind", "")), "meat_drop", failures, "Meat drop save data should use resource_kind=meat_drop")
	TEST_UTILS.expect(not is_instance_valid(prey), failures, "Dead prey should be freed from the scene")

	await INTEGRATION.shutdown_main(context)
	return failures


