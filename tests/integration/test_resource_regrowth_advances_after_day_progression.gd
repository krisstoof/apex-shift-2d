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
	var day_night := main.get_node_or_null("DayNightSystem")
	TEST_UTILS.expect(world != null, failures, "Main scene should include World")
	TEST_UTILS.expect(player != null, failures, "Main scene should include Player")
	TEST_UTILS.expect(day_night != null, failures, "Main scene should include DayNightSystem")
	if world == null or player == null or day_night == null:
		await INTEGRATION.shutdown_main(context)
		return failures

	player.global_position = Vector2(100000.0, 100000.0)
	INTEGRATION.refresh_world_cache(world)

	var biome_id := ""
	for zone_value in world.call("get_biome_zones"):
		if typeof(zone_value) != TYPE_DICTIONARY:
			continue
		var zone := Dictionary(zone_value)
		biome_id = str(zone.get("id", zone.get("name", "")))
		break
	var spawn_point := INTEGRATION.find_point_in_biome(world, biome_id)
	if spawn_point == Vector2.ZERO:
		spawn_point = world.call("get_world_rect").get_center()

	INTEGRATION.clear_nodes_in_group_near_position(tree, "edible_vegetation", spawn_point, 180.0)
	var resource := INTEGRATION.spawn_resource(world, "grass_patch", spawn_point) as Node2D
	TEST_UTILS.expect(resource != null, failures, "The test should spawn a controllable grass patch")
	if resource == null:
		await INTEGRATION.shutdown_main(context)
		return failures

	var initial_stage: int = int(resource.get("growth_stage"))
	while is_instance_valid(resource) and int(resource.get("growth_stage")) > 0:
		resource.consume_by_creature(player, 1.0)
	var harvested_stage: int = int(resource.get("growth_stage"))
	TEST_UTILS.expect(harvested_stage < initial_stage, failures, "Harvesting should reduce the growth stage")
	TEST_UTILS.expect_equal(harvested_stage, 0, failures, "The test should deplete the resource to stage 0 before regrowth")
	TEST_UTILS.expect_equal(bool(resource.get("is_edible_by_herbivores")), false, failures, "Depleted vegetation should not be edible")
	TEST_UTILS.expect_equal(bool(resource.get("can_be_harvested")), false, failures, "Depleted vegetation should not be harvestable")

	var initial_day: int = int(day_night.get("day"))
	day_night.call("debug_next_day")
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame

	var regrown_stage: int = int(resource.get("growth_stage"))
	TEST_UTILS.expect(regrown_stage > harvested_stage, failures, "Advancing the day should regrow the resource")
	TEST_UTILS.expect_equal(bool(resource.get("is_edible_by_herbivores")), true, failures, "Regrown vegetation should become edible again")
	TEST_UTILS.expect_equal(int(day_night.get("day")), initial_day + 1, failures, "Debug next day should advance the calendar by one day")
	TEST_UTILS.expect_equal(bool(resource.get("can_be_harvested")), true, failures, "Regrown resource should become harvestable again")
	INTEGRATION.assert_resource_registered(failures, world, resource, str(resource.get("resource_kind")), "Regrowth resource")

	await INTEGRATION.shutdown_main(context)
	return failures
