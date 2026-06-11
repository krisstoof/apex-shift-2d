extends RefCounted

const INTEGRATION := preload("res://tests/integration/integration_test_utils.gd")


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
	if world == null:
		failures.append("World not found")
		await INTEGRATION.shutdown_main(context)
		return failures

	if world.has_method("enable_integration_test_mode"):
		world.call("enable_integration_test_mode")

	if world.has_signal("world_initialized") and world.has_method("is_boot_ready") and not bool(world.call("is_boot_ready")):
		await world.world_initialized
	await tree.process_frame
	await tree.process_frame

	var visual_debug: Dictionary = {}
	if world.has_method("get_vegetation_visual_debug"):
		visual_debug = Dictionary(world.call("get_vegetation_visual_debug"))
	var visual_count := int(visual_debug.get("visual_instance_count", 0))
	if visual_count <= 0:
		failures.append("Expected decorative vegetation visual instances > 0")

	var grass_node_count := 0
	var edible_node_count := 0
	for resource_value in tree.get_nodes_in_group("resources"):
		var resource := resource_value as Node
		if not is_instance_valid(resource):
			continue
		var resource_kind := str(resource.get("resource_kind"))
		if resource_kind in ["grass_patch", "dense_grass"]:
			grass_node_count += 1
		if resource.is_in_group("edible_vegetation"):
			edible_node_count += 1
	var expected_max := 60
	if grass_node_count > expected_max:
		failures.append("Too many grass ResourceNode nodes: %d > %d" % [grass_node_count, expected_max])
	if edible_node_count <= 0:
		failures.append("Expected edible vegetation nodes > 0")

	if world.has_method("get_edible_vegetation_near"):
		var targets: Array = world.call("get_edible_vegetation_near", Vector2.ZERO, 99999.0, "")
		var valid_target_found := false
		for target_value in targets:
			var target := target_value as Node2D
			if is_instance_valid(target) and target.is_in_group("edible_vegetation"):
				valid_target_found = true
				break
		if not valid_target_found:
			failures.append("Expected get_edible_vegetation_near to return at least one valid target")
	else:
		failures.append("World missing get_edible_vegetation_near")

	await INTEGRATION.shutdown_main(context)
	return failures
