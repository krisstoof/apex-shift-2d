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

	if world.has_method("_update_decorative_vegetation_visible_rect"):
		world.call("_update_decorative_vegetation_visible_rect")
	await tree.process_frame

	if not world.has_method("get_vegetation_visual_debug"):
		failures.append("World missing get_vegetation_visual_debug")
		await INTEGRATION.shutdown_main(context)
		return failures

	var debug := Dictionary(world.call("get_vegetation_visual_debug"))
	var total_count := int(debug.get("total_instance_count", debug.get("visual_instance_count", 0)))
	var drawn_count := int(debug.get("drawn_instance_count", 0))
	var skipped_by_cap := int(debug.get("skipped_by_cap_count", 0))
	var near_lod_count := int(debug.get("near_lod_count", 0))
	var mid_lod_count := int(debug.get("mid_lod_count", 0))
	var far_lod_count := int(debug.get("far_lod_count", 0))
	var max_drawn_instances := int(debug.get("max_drawn_instances", 0))
	var visible_chunks := int(debug.get("visible_chunk_count", 0))
	var total_chunks := int(debug.get("total_chunk_count", 0))

	if total_count <= 0:
		failures.append("Expected total decorative vegetation instances > 0")
	if drawn_count <= 0:
		failures.append("Expected drawn decorative vegetation instances > 0")
	if max_drawn_instances <= 0:
		failures.append("Expected max_drawn_instances > 0")
	if drawn_count > max_drawn_instances:
		failures.append("drawn_count must not exceed max_drawn_instances: %d > %d" % [drawn_count, max_drawn_instances])
	if drawn_count > total_count:
		failures.append("drawn_count must not exceed total_count: %d > %d" % [drawn_count, total_count])
	if near_lod_count + mid_lod_count + far_lod_count != drawn_count:
		failures.append("LOD counts must sum to drawn_count: %d + %d + %d != %d" % [near_lod_count, mid_lod_count, far_lod_count, drawn_count])
	if skipped_by_cap < 0:
		failures.append("Expected skipped_by_cap_count to be reported")
	if total_chunks <= 0:
		failures.append("Expected total vegetation chunks > 0")
	if visible_chunks > total_chunks:
		failures.append("visible_chunks must not exceed total_chunks: %d > %d" % [visible_chunks, total_chunks])

	var grass_node_count := 0
	for resource_value in tree.get_nodes_in_group("resources"):
		var resource := resource_value as Node
		if not is_instance_valid(resource):
			continue
		var resource_kind := str(resource.get("resource_kind"))
		if resource_kind in ["grass_patch", "dense_grass"]:
			grass_node_count += 1
	if grass_node_count != 0:
		failures.append("Expected 0 decorative grass ResourceNode nodes, got %d" % grass_node_count)

	await INTEGRATION.shutdown_main(context)
	return failures
