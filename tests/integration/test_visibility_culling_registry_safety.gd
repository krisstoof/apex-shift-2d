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
	TEST_UTILS.expect(world != null, failures, "World should exist")
	TEST_UTILS.expect(player != null, failures, "Player should exist")
	if world == null or player == null:
		await INTEGRATION.shutdown_main(context)
		return failures

	if world.has_method("enable_integration_test_mode"):
		world.call("enable_integration_test_mode")

	var resource := INTEGRATION.spawn_resource(world, "rock", player.global_position + Vector2(180.0, 0.0))
	var prey := INTEGRATION.spawn_small_prey(world, "hearth_meadow", player.global_position + Vector2(260.0, 0.0))
	TEST_UTILS.expect(resource != null, failures, "Resource should spawn")
	TEST_UTILS.expect(prey != null, failures, "Prey should spawn")
	if resource == null or prey == null:
		await INTEGRATION.shutdown_main(context)
		return failures

	await tree.process_frame
	await tree.process_frame
	INTEGRATION.refresh_world_cache(world)
	INTEGRATION.assert_resource_registered(failures, world, resource, "rock", "Cull resource initial")
	INTEGRATION.assert_creature_registered(failures, world, prey, "small_prey", "Cull prey initial")
	INTEGRATION.assert_valid_node2d_position(failures, resource, "Cull resource initial")
	INTEGRATION.assert_valid_node2d_position(failures, prey, "Cull prey initial")
	if world.has_method("_update_world_object_visibility"):
		world.call("_update_world_object_visibility")
	await tree.process_frame
	await tree.process_frame
	var initial_debug := {}
	if world.has_method("get_visibility_culling_debug"):
		initial_debug = Dictionary(world.call("get_visibility_culling_debug"))
	if world.has_method("get_visibility_culling_debug") and not bool(initial_debug.get("enabled", false)):
		failures.append("Visibility culling is disabled; registry safety test cannot exercise culling path.")

	var near_pos := player.global_position
	var world_rect: Rect2 = world.call("get_world_rect")
	player.global_position = world_rect.position + world_rect.size * 0.85
	if world.has_method("_update_world_object_visibility"):
		world.call("_update_world_object_visibility")
	await tree.process_frame
	await tree.process_frame
	var far_debug := {}
	if world.has_method("get_visibility_culling_debug"):
		far_debug = Dictionary(world.call("get_visibility_culling_debug"))
	var resource_hidden: bool = resource is CanvasItem and not resource.visible
	var prey_hidden: bool = prey is CanvasItem and not prey.visible
	var hidden_resources := int(far_debug.get("hidden_resources", 0))
	var hidden_creatures := int(far_debug.get("hidden_creatures", 0))
	if not resource_hidden and hidden_resources <= 0:
		failures.append("Visibility culling did not hide the tracked resource and hidden_resources did not increase. debug=%s" % JSON.stringify(far_debug))
	if not prey_hidden and hidden_creatures <= 0:
		failures.append("Visibility culling did not hide the tracked prey and hidden_creatures did not increase. debug=%s" % JSON.stringify(far_debug))
	INTEGRATION.assert_resource_registered(failures, world, resource, "rock", "Cull resource far")
	INTEGRATION.assert_creature_registered(failures, world, prey, "small_prey", "Cull prey far")
	INTEGRATION.assert_valid_node2d_position(failures, resource, "Cull resource far")
	INTEGRATION.assert_valid_node2d_position(failures, prey, "Cull prey far")

	player.global_position = near_pos
	if world.has_method("_update_world_object_visibility"):
		world.call("_update_world_object_visibility")
	await tree.process_frame
	await tree.process_frame
	if resource is CanvasItem and not resource.visible:
		failures.append("Resource did not become visible again after returning near.")
	if prey is CanvasItem and not prey.visible:
		failures.append("Prey did not become visible again after returning near.")
	INTEGRATION.assert_resource_registered(failures, world, resource, "rock", "Cull resource after return")
	INTEGRATION.assert_creature_registered(failures, world, prey, "small_prey", "Cull prey after return")
	INTEGRATION.assert_valid_node2d_position(failures, resource, "Cull resource after return")
	INTEGRATION.assert_valid_node2d_position(failures, prey, "Cull prey after return")
	INTEGRATION.assert_tree_unpaused(failures, tree, "Visibility culling registry safety integration")
	await INTEGRATION.shutdown_main(context)
	return failures


