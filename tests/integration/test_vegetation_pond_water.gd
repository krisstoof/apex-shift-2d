extends RefCounted

const INTEGRATION := preload("res://tests/integration/integration_test_utils.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")

const PLANT_RESOURCE_KINDS := [
	"conifer_tree",
	"leafy_tree",
	"bush",
	"dry_bush",
	"small_bush",
	"berry_bush",
	"grass_patch",
	"dense_grass"
]


func run() -> Array[String]:
	var failures: Array[String] = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		failures.append("SceneTree is not available for the integration test run")
		return failures
	var original_scene := tree.current_scene

	var main := MAIN_SCENE.instantiate()
	tree.root.call_deferred("add_child", main)
	tree.call_deferred("set_current_scene", main)
	await main.ready

	var world_boot := main.get_node_or_null("World")
	if world_boot != null and world_boot.has_method("is_boot_ready") and not bool(world_boot.call("is_boot_ready")):
		if world_boot.has_signal("world_initialized"):
			await world_boot.world_initialized
	await tree.process_frame

	var world := main.get_node_or_null("World")
	TEST_UTILS.expect(world != null, failures, "Main scene should include World")
	if world == null:
		if is_instance_valid(main):
			main.queue_free()
			await tree.process_frame
		if is_instance_valid(original_scene):
			tree.current_scene = original_scene
		return failures

	var landmarks: Array = world.call("get_landmarks")
	var pond_count := 0
	for landmark_value in landmarks:
		if typeof(landmark_value) != TYPE_DICTIONARY:
			continue
		var landmark := Dictionary(landmark_value)
		if str(landmark.get("type", "")) == "pond":
			pond_count += 1
	TEST_UTILS.expect(pond_count > 0, failures, "Fresh world should contain at least one pond landmark")

	var plant_resource_count := 0
	for resource_value in tree.get_nodes_in_group("resources"):
		var resource := resource_value as Node2D
		if resource == null or not is_instance_valid(resource):
			continue
		var resource_kind := str(resource.get("resource_kind"))
		if resource_kind not in PLANT_RESOURCE_KINDS:
			continue
		plant_resource_count += 1
		INTEGRATION.assert_valid_node2d_position(failures, resource, "Vegetation %s" % resource_kind)
		INTEGRATION.assert_node_inside_world_rect(failures, world, resource, "Vegetation %s" % resource_kind)
		INTEGRATION.assert_resource_registered(failures, world, resource, resource_kind, "Vegetation %s" % resource_kind)
		var water_zone := str(world.call("get_water_zone", resource.global_position))
		TEST_UTILS.expect(not world.call("is_position_in_water", resource.global_position), failures, "Plant resource %s spawned in water zone %s at %s" % [resource_kind, water_zone, str(resource.global_position)])
		if bool(resource.get("is_pond_vegetation")):
			continue

	TEST_UTILS.expect(plant_resource_count > 0, failures, "Fresh world should spawn plant resources to validate pond placement")

	if is_instance_valid(main):
		main.queue_free()
		await tree.process_frame
	if is_instance_valid(original_scene):
		tree.current_scene = original_scene

	return failures
