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

	var dangerous_point := INTEGRATION.find_point_in_dangerous_biome(world)
	TEST_UTILS.expect(dangerous_point != Vector2.ZERO, failures, "World should contain a dangerous biome for Varnak spawn validation")
	if dangerous_point != Vector2.ZERO:
		player.global_position = dangerous_point
		world.call("respawn_missing_varnaks")
		await tree.process_frame
		await tree.process_frame

	_assert_group_not_in_water(tree, world, "small_prey", failures)
	_assert_group_not_in_water(tree, world, "grazer", failures)
	_assert_group_not_in_water(tree, world, "varnak", failures)
	INTEGRATION.assert_tree_unpaused(failures, tree, "AnimalsDoNotSpawnInPondWater")

	await INTEGRATION.shutdown_main(context)
	return failures


func _assert_group_not_in_water(tree: SceneTree, world: Node, group_name: String, failures: Array[String]) -> void:
	var nodes := INTEGRATION.get_valid_nodes_in_group(tree, group_name)
	TEST_UTILS.expect(nodes.size() > 0, failures, "Expected at least one %s to validate spawn water rules" % group_name)
	for node in nodes:
		var creature := node as Node2D
		if creature == null:
			continue
		INTEGRATION.assert_valid_node2d_position(failures, creature, "%s creature" % group_name)
		INTEGRATION.assert_creature_registered(failures, world, creature, group_name, "%s creature" % group_name)
		TEST_UTILS.expect(world.call("get_world_rect").has_point(creature.global_position), failures, "%s should start inside world bounds" % group_name)
		TEST_UTILS.expect(not world.call("is_position_in_water", creature.global_position), failures, "%s spawned in water at %s" % [group_name, str(creature.global_position)])
