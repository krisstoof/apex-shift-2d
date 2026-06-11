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
	var day_night := main.get_node_or_null("DayNightSystem")
	var ecosystem := main.get_node_or_null("EcosystemDirector")
	var save_system := main.get_node_or_null("SaveSystem")
	TEST_UTILS.expect(world != null, failures, "World should exist")
	TEST_UTILS.expect(day_night != null, failures, "DayNightSystem should exist")
	TEST_UTILS.expect(ecosystem != null, failures, "EcosystemDirector should exist")
	TEST_UTILS.expect(save_system != null, failures, "SaveSystem should exist")
	if world == null or day_night == null or ecosystem == null or save_system == null:
		await INTEGRATION.shutdown_main(context)
		return failures

	var biome_states: Dictionary = ecosystem.get_biome_states()
	var biome_ids := biome_states.keys()
	TEST_UTILS.expect(not biome_ids.is_empty(), failures, "Ecosystem should expose biome states")
	if biome_ids.is_empty():
		await INTEGRATION.shutdown_main(context)
		return failures

	var biome_id := str(biome_ids[0])
	var biome_point := INTEGRATION.find_point_in_biome(world, biome_id)
	if biome_point == Vector2.ZERO:
		biome_point = world.call("get_world_rect").get_center()

	var berry := INTEGRATION.spawn_resource(world, "berry_bush", biome_point + Vector2(120.0, 0.0))
	var grass := INTEGRATION.spawn_resource(world, "grass_patch", biome_point + Vector2(-120.0, 0.0))
	var prey := INTEGRATION.spawn_small_prey(world, biome_id, biome_point + Vector2(64.0, 64.0))
	var grazer := INTEGRATION.spawn_grazer(world, biome_id, biome_point + Vector2(-64.0, -64.0))
	var varnak := INTEGRATION.spawn_varnak(world, biome_point + Vector2(0.0, 140.0))
	TEST_UTILS.expect(berry != null, failures, "Berry bush should spawn for the test")
	TEST_UTILS.expect(grass != null, failures, "Grass patch should spawn for the test")
	TEST_UTILS.expect(prey != null, failures, "Small prey should spawn for the test")
	TEST_UTILS.expect(grazer != null, failures, "Grazer should spawn for the test")
	TEST_UTILS.expect(varnak != null, failures, "Varnak should spawn for the test")
	if berry == null or grass == null or prey == null or grazer == null or varnak == null:
		await INTEGRATION.shutdown_main(context)
		return failures

	if berry.has_method("force_full_regrowth"):
		berry.call("force_full_regrowth")
	if grass.has_method("force_full_regrowth"):
		grass.call("force_full_regrowth")
	await tree.process_frame

	day_night.call("debug_next_day")
	day_night.call("debug_next_day")
	await tree.process_frame
	await tree.process_frame

	var expected_day := int(day_night.get("day"))
	var expected_small_prey: int = world.call("get_registered_creatures_by_type", "small_prey").size()
	var expected_grazers: int = world.call("get_registered_creatures_by_type", "grazer").size()
	var expected_varnaks: int = world.call("get_registered_creatures_by_type", "varnak").size()
	var expected_resources: int = world.call("get_registered_resources").size()
	var expected_berries: int = world.call("get_registered_resources_by_kind", "berry_bush").size()
	var expected_grass: int = world.call("get_registered_resources_by_kind", "grass_patch").size()
	var expected_berry_stage := int(berry.get("growth_stage"))
	var expected_grass_stage := int(grass.get("growth_stage"))
	var expected_berry_days := float(berry.get("days_since_harvested"))
	var expected_grass_days := float(grass.get("days_since_harvested"))
	var expected_prey_hunger := float(prey.get("hunger"))
	var expected_grazer_hunger := float(grazer.get("hunger"))
	var expected_varnak_hunger := float(varnak.get("hunger"))
	var expected_varnak_health := float(varnak.get("health"))

	save_system.call("save_game")
	await tree.process_frame
	await tree.process_frame

	# Disturb the scene so the restore has to rebuild the previous state.
	INTEGRATION.clear_nodes_in_group_near_position(tree, "small_prey", biome_point, 99999.0)
	INTEGRATION.clear_nodes_in_group_near_position(tree, "grazer", biome_point, 99999.0)
	INTEGRATION.clear_nodes_in_group_near_position(tree, "varnak", biome_point, 99999.0)
	INTEGRATION.clear_nodes_in_group_near_position(tree, "resources", biome_point, 99999.0)
	await tree.process_frame

	await save_system.load_game()
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame

	TEST_UTILS.expect_equal(int(day_night.get("day")), expected_day, failures, "Day counter should survive save/load after multiple days")
	TEST_UTILS.expect_equal(world.call("get_registered_creatures_by_type", "small_prey").size(), expected_small_prey, failures, "Small prey count should restore without duplication")
	TEST_UTILS.expect_equal(world.call("get_registered_creatures_by_type", "grazer").size(), expected_grazers, failures, "Grazer count should restore without duplication")
	TEST_UTILS.expect_equal(world.call("get_registered_creatures_by_type", "varnak").size(), expected_varnaks, failures, "Varnak count should restore without duplication")
	TEST_UTILS.expect_equal(world.call("get_registered_resources").size(), expected_resources, failures, "Resource count should restore without duplication")
	TEST_UTILS.expect_equal(world.call("get_registered_resources_by_kind", "berry_bush").size(), expected_berries, failures, "Berry bush count should restore without duplication")
	TEST_UTILS.expect_equal(world.call("get_registered_resources_by_kind", "grass_patch").size(), expected_grass, failures, "Grass patch count should restore without duplication")
	var restored_berry := _find_closest_node(world.call("get_registered_resources_by_kind", "berry_bush"), biome_point + Vector2(120.0, 0.0)) as Node2D
	var restored_grass := _find_closest_node(world.call("get_registered_resources_by_kind", "grass_patch"), biome_point + Vector2(-120.0, 0.0)) as Node2D
	var restored_prey := _find_closest_node(world.call("get_registered_creatures_by_type", "small_prey"), biome_point + Vector2(64.0, 64.0)) as Node2D
	var restored_grazer := _find_closest_node(world.call("get_registered_creatures_by_type", "grazer"), biome_point + Vector2(-64.0, -64.0)) as Node2D
	var restored_varnak := _find_closest_node(world.call("get_registered_creatures_by_type", "varnak"), biome_point + Vector2(0.0, 140.0)) as Node2D
	TEST_UTILS.expect(restored_berry != null, failures, "Restored berry bush should be found near the saved position")
	TEST_UTILS.expect(restored_grass != null, failures, "Restored grass patch should be found near the saved position")
	TEST_UTILS.expect(restored_prey != null, failures, "Restored small prey should be found near the saved position")
	TEST_UTILS.expect(restored_grazer != null, failures, "Restored grazer should be found near the saved position")
	TEST_UTILS.expect(restored_varnak != null, failures, "Restored varnak should be found near the saved position")
	if restored_berry != null and restored_grass != null and restored_prey != null and restored_grazer != null and restored_varnak != null:
		TEST_UTILS.expect_equal(int(restored_berry.get("growth_stage")), expected_berry_stage, failures, "Berry growth stage should restore")
		TEST_UTILS.expect_equal(int(restored_grass.get("growth_stage")), expected_grass_stage, failures, "Grass growth stage should restore")
		TEST_UTILS.expect_close(float(restored_berry.get("days_since_harvested")), expected_berry_days, failures, "Berry regrowth timer should restore")
		TEST_UTILS.expect_close(float(restored_grass.get("days_since_harvested")), expected_grass_days, failures, "Grass regrowth timer should restore")
		TEST_UTILS.expect_close(float(restored_prey.get("hunger")), expected_prey_hunger, failures, "Small prey hunger should restore")
		TEST_UTILS.expect_close(float(restored_grazer.get("hunger")), expected_grazer_hunger, failures, "Grazer hunger should restore")
		TEST_UTILS.expect_close(float(restored_varnak.get("hunger")), expected_varnak_hunger, failures, "Varnak hunger should restore")
		TEST_UTILS.expect_close(float(restored_varnak.get("health")), expected_varnak_health, failures, "Varnak health should restore")

	day_night.call("debug_next_day")
	await tree.process_frame
	await tree.process_frame

	TEST_UTILS.expect_equal(world.call("get_registered_creatures_by_type", "small_prey").size(), expected_small_prey, failures, "Small prey count should stay stable after a post-load day tick")
	TEST_UTILS.expect_equal(world.call("get_registered_creatures_by_type", "grazer").size(), expected_grazers, failures, "Grazer count should stay stable after a post-load day tick")
	TEST_UTILS.expect_equal(world.call("get_registered_creatures_by_type", "varnak").size(), expected_varnaks, failures, "Varnak count should stay stable after a post-load day tick")
	TEST_UTILS.expect_equal(world.call("get_registered_resources").size(), expected_resources, failures, "Resource count should stay stable after a post-load day tick")

	var save_path := ProjectSettings.globalize_path("user://savegame.json")
	if FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(save_path)

	await INTEGRATION.shutdown_main(context)
	return failures


func _find_closest_node(nodes: Array, position: Vector2) -> Node2D:
	var closest: Node2D = null
	var closest_distance := INF
	for node_value in nodes:
		var node := node_value as Node2D
		if node == null or not is_instance_valid(node):
			continue
		var distance := node.global_position.distance_to(position)
		if distance < closest_distance:
			closest_distance = distance
			closest = node
	return closest


