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
	INTEGRATION.clear_nodes_in_group(tree, "small_prey")
	INTEGRATION.clear_nodes_in_group(tree, "meat_drops")
	INTEGRATION.refresh_world_cache(world)

	var biome_id := ""
	var hunt_point := Vector2.ZERO
	for zone_value in world.call("get_biome_zones"):
		if typeof(zone_value) != TYPE_DICTIONARY:
			continue
		var zone := Dictionary(zone_value)
		if zone.get("dangerous", false) != true:
			continue
		biome_id = str(zone.get("id", zone.get("name", "")))
		hunt_point = INTEGRATION.find_point_in_biome(world, biome_id)
		break
	if hunt_point == Vector2.ZERO:
		hunt_point = world.call("get_world_rect").get_center()

	var prey := INTEGRATION.spawn_small_prey(world, biome_id, hunt_point + Vector2(180.0, 0.0)) as Node2D
	TEST_UTILS.expect(prey != null, failures, "The test should spawn a controlled small prey target")
	if prey == null:
		await INTEGRATION.shutdown_main(context)
		return failures

	var varnak := INTEGRATION.spawn_varnak(world, hunt_point - Vector2(120.0, 0.0)) as Node2D
	TEST_UTILS.expect(varnak != null, failures, "The test should spawn a controlled Varnak")
	if varnak == null:
		await INTEGRATION.shutdown_main(context)
		return failures

	INTEGRATION.refresh_world_cache(world)
	varnak.global_position = hunt_point - Vector2(120.0, 0.0)
	varnak.hunger = 0.70
	varnak.energy = 0.65
	varnak.call("_update_state")
	TEST_UTILS.expect_equal(varnak.state, varnak.State.HUNT_ECOSYSTEM, failures, "Hungry Varnak should switch to ecosystem hunting")
	TEST_UTILS.expect_equal(varnak.ecosystem_target, prey, failures, "Hungry Varnak should lock onto the spawned prey")
	TEST_UTILS.expect_equal(varnak.decision_reason, "hunt_drive_ecosystem_prey", failures, "Varnak should explain that it is hunting ecosystem prey")
	var distance_before: float = varnak.global_position.distance_to(prey.global_position)
	varnak.call("_act", 0.0)
	TEST_UTILS.expect(varnak.velocity.length() > 0.0, failures, "Hunting Varnak should start moving toward prey")
	varnak.call("_physics_process", 0.16)
	var distance_after: float = varnak.global_position.distance_to(prey.global_position)
	TEST_UTILS.expect(distance_after < distance_before, failures, "Hunting Varnak should close the distance to prey")

	await INTEGRATION.shutdown_main(context)
	return failures
