extends Node

const NEW_GAME_TESTS := preload("res://tests/integration/test_new_game.gd")
const VEGETATION_POND_WATER_TESTS := preload("res://tests/integration/test_vegetation_pond_water.gd")
const ANIMALS_DO_NOT_SPAWN_IN_POND_WATER_TESTS := preload("res://tests/integration/test_animals_do_not_spawn_in_pond_water.gd")
const ANIMALS_REMAIN_INSIDE_WORLD_BOUNDS_TESTS := preload("res://tests/integration/test_animals_remain_inside_world_bounds.gd")
const SMALL_PREY_SEARCHES_FOR_FOOD_WHEN_HUNGRY_TESTS := preload("res://tests/integration/test_small_prey_searches_for_food_when_hungry.gd")
const GRAZER_EATS_PLANTS_WHEN_HUNGRY_TESTS := preload("res://tests/integration/test_grazer_eats_plants_when_hungry.gd")
const VARNAK_HUNTS_PREY_WHEN_HUNGRY_TESTS := preload("res://tests/integration/test_varnak_hunts_prey_when_hungry.gd")
const ANIMAL_DEATH_CREATES_MEAT_DROP_TESTS := preload("res://tests/integration/test_animal_death_creates_meat_drop.gd")
const RESOURCE_REGROWTH_ADVANCES_AFTER_DAY_PROGRESSION_TESTS := preload("res://tests/integration/test_resource_regrowth_advances_after_day_progression.gd")
const SAVE_LOAD_RESTORES_ECOSYSTEM_STATE_TESTS := preload("res://tests/integration/test_save_load_restores_ecosystem_state.gd")
const MINIMAP_RENDERS_WITH_LANDMARKS_TESTS := preload("res://tests/integration/test_minimap_renders_with_landmarks.gd")


func _ready() -> void:
	var failures: Array[String] = []
	failures.append_array(await NEW_GAME_TESTS.new().run())
	failures.append_array(await VEGETATION_POND_WATER_TESTS.new().run())
	failures.append_array(await ANIMALS_DO_NOT_SPAWN_IN_POND_WATER_TESTS.new().run())
	failures.append_array(await ANIMALS_REMAIN_INSIDE_WORLD_BOUNDS_TESTS.new().run())
	failures.append_array(await SMALL_PREY_SEARCHES_FOR_FOOD_WHEN_HUNGRY_TESTS.new().run())
	failures.append_array(await GRAZER_EATS_PLANTS_WHEN_HUNGRY_TESTS.new().run())
	failures.append_array(await VARNAK_HUNTS_PREY_WHEN_HUNGRY_TESTS.new().run())
	failures.append_array(await ANIMAL_DEATH_CREATES_MEAT_DROP_TESTS.new().run())
	failures.append_array(await RESOURCE_REGROWTH_ADVANCES_AFTER_DAY_PROGRESSION_TESTS.new().run())
	failures.append_array(await SAVE_LOAD_RESTORES_ECOSYSTEM_STATE_TESTS.new().run())
	failures.append_array(await MINIMAP_RENDERS_WITH_LANDMARKS_TESTS.new().run())
	if failures.is_empty():
		print("[IntegrationTests] All integration tests passed.")
		get_tree().quit(0)
		return
	push_error("[IntegrationTests] %d failure(s):" % failures.size())
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)
