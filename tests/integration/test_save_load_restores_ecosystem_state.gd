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
	var ecosystem := main.get_node_or_null("EcosystemDirector")
	var save_system := main.get_node_or_null("SaveSystem")
	TEST_UTILS.expect(world != null, failures, "Main scene should include World")
	TEST_UTILS.expect(player != null, failures, "Main scene should include Player")
	TEST_UTILS.expect(day_night != null, failures, "Main scene should include DayNightSystem")
	TEST_UTILS.expect(ecosystem != null, failures, "Main scene should include EcosystemDirector")
	TEST_UTILS.expect(save_system != null, failures, "Main scene should include SaveSystem")
	if world == null or player == null or day_night == null or ecosystem == null or save_system == null:
		await INTEGRATION.shutdown_main(context)
		return failures

	var biome_states: Dictionary = ecosystem.get_biome_states()
	var biome_ids := biome_states.keys()
	TEST_UTILS.expect(biome_ids.size() > 0, failures, "Ecosystem should expose at least one biome state")
	if biome_ids.is_empty():
		await INTEGRATION.shutdown_main(context)
		return failures

	var biome_id := str(biome_ids[0])
	var biome_point := INTEGRATION.find_point_in_biome(world, biome_id)
	if biome_point == Vector2.ZERO:
		biome_point = world.call("get_world_rect").get_center()
	var expected_player_position := biome_point + Vector2(144.0, 72.0)

	player.global_position = expected_player_position
	player.stats.damage(17.0)
	player.inventory.add_item("wood", 4)
	player.inventory.add_item("fiber", 2)
	day_night.call("debug_next_day")
	day_night.call("debug_next_day")
	ecosystem.call("debug_reduce_plant_biomass", biome_point)
	await tree.process_frame
	await tree.process_frame

	var expected_day: int = int(day_night.get("day"))
	var expected_health: float = float(player.stats.health)
	var expected_wood: int = player.inventory.get_amount("wood")
	var expected_fiber: int = player.inventory.get_amount("fiber")
	var expected_ecosystem_state: Dictionary = ecosystem.get_biome_state(biome_id)
	var expected_biomass: float = float(expected_ecosystem_state.get("plant_biomass", 0.0))
	var expected_small_prey_population: float = float(expected_ecosystem_state.get("small_prey_population", 0.0))
	var expected_grazer_population: float = float(expected_ecosystem_state.get("grazer_population", 0.0))
	var expected_small_prey_recovery: float = float(expected_ecosystem_state.get("small_prey_daily_recovery", 0.0))
	var expected_grazer_recovery: float = float(expected_ecosystem_state.get("grazer_daily_recovery", 0.0))

	save_system.call("save_game")
	await tree.process_frame

	player.global_position = world.call("get_world_rect").get_center()
	player.stats.heal(50.0)
	player.inventory.add_item("wood", 9)
	player.inventory.add_item("fiber", 6)
	day_night.call("debug_next_day")
	ecosystem.call("debug_restore_plant_biomass", biome_point)
	ecosystem.biome_states[biome_id]["small_prey_population"] = 1.0
	ecosystem.biome_states[biome_id]["grazer_population"] = 1.0
	ecosystem.biome_states[biome_id]["small_prey_daily_recovery"] = 0.0
	ecosystem.biome_states[biome_id]["grazer_daily_recovery"] = 0.0
	await tree.process_frame
	await tree.process_frame

	await save_system.load_game()
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame

	TEST_UTILS.expect_close(player.global_position.x, expected_player_position.x, failures, "Player X position should be restored from save")
	TEST_UTILS.expect_close(player.global_position.y, expected_player_position.y, failures, "Player Y position should be restored from save")
	TEST_UTILS.expect_equal(int(day_night.get("day")), expected_day, failures, "Day counter should be restored from save")
	TEST_UTILS.expect_close(float(player.stats.health), expected_health, failures, "Player health should be restored from save")
	TEST_UTILS.expect_equal(player.inventory.get_amount("wood"), expected_wood, failures, "Wood inventory should be restored from save")
	TEST_UTILS.expect_equal(player.inventory.get_amount("fiber"), expected_fiber, failures, "Fiber inventory should be restored from save")
	TEST_UTILS.expect_close(float(ecosystem.get_biome_state(biome_id).get("plant_biomass", 0.0)), expected_biomass, failures, "Biome biomass should be restored from save")
	TEST_UTILS.expect_close(float(ecosystem.get_biome_state(biome_id).get("small_prey_population", 0.0)), expected_small_prey_population, failures, "SmallPrey population should be restored from save")
	TEST_UTILS.expect_close(float(ecosystem.get_biome_state(biome_id).get("grazer_population", 0.0)), expected_grazer_population, failures, "Grazer population should be restored from save")
	TEST_UTILS.expect_close(float(ecosystem.get_biome_state(biome_id).get("small_prey_daily_recovery", 0.0)), expected_small_prey_recovery, failures, "SmallPrey recovery diagnostics should be restored from save")
	TEST_UTILS.expect_close(float(ecosystem.get_biome_state(biome_id).get("grazer_daily_recovery", 0.0)), expected_grazer_recovery, failures, "Grazer recovery diagnostics should be restored from save")

	var save_path := ProjectSettings.globalize_path("user://savegame.json")
	if FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(save_path)

	await INTEGRATION.shutdown_main(context)
	return failures
