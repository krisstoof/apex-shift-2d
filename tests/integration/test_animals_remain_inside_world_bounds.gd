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

	var world_rect: Rect2 = world.call("get_world_rect")
	player.global_position = world_rect.end + Vector2(3000.0, 3000.0)
	var dangerous_point := INTEGRATION.find_point_in_dangerous_biome(world)
	if dangerous_point == Vector2.ZERO:
		dangerous_point = world_rect.get_center()
	var varnak := INTEGRATION.get_first_valid_node_in_group(tree, "varnak")
	if varnak == null:
		varnak = INTEGRATION.spawn_varnak(world, dangerous_point)
		await tree.process_frame
		await tree.process_frame
	var creature_specs := [
		{"node": INTEGRATION.get_first_valid_node_in_group(tree, "small_prey"), "position": world_rect.position + Vector2(80.0, 80.0)},
		{"node": INTEGRATION.get_first_valid_node_in_group(tree, "grazer"), "position": Vector2(world_rect.end.x - 80.0, world_rect.position.y + 80.0)},
		{"node": varnak, "position": Vector2(world_rect.end.x - 80.0, world_rect.end.y - 80.0)}
	]
	for spec in creature_specs:
		var creature: Node2D = spec.get("node") as Node2D
		if creature == null:
			continue
		var position: Vector2 = spec.get("position") as Vector2
		creature.global_position = position
		if creature.has_method("_pick_wander_target"):
			creature.call("_pick_wander_target")
		if INTEGRATION.has_property(creature, "wander_target"):
			creature.set("wander_target", world_rect.end + Vector2(1200.0, 1200.0))
		if INTEGRATION.has_property(creature, "state"):
			var state_value: int = int(creature.get("state"))
			if typeof(state_value) == TYPE_INT:
				creature.set("state", state_value)

	for _step in range(18):
		for spec in creature_specs:
			var creature: Node = spec.get("node") as Node
			if creature == null or not is_instance_valid(creature):
				continue
			if creature.has_method("_physics_process"):
				creature.call("_physics_process", 0.16)
			var position: Vector2 = (creature as Node2D).global_position
			TEST_UTILS.expect(is_finite(position.x) and is_finite(position.y), failures, "%s position should remain finite" % creature.name)
			TEST_UTILS.expect(world_rect.has_point(position), failures, "%s should stay inside world bounds" % creature.name)
	if world.has_method("get_creatures_out_of_bounds_count"):
		TEST_UTILS.expect_equal(int(world.call("get_creatures_out_of_bounds_count")), 0, failures, "World should report no out-of-bounds creatures")
	INTEGRATION.assert_tree_unpaused(failures, tree, "AnimalsRemainInsideWorldBounds")

	await INTEGRATION.shutdown_main(context)
	return failures
