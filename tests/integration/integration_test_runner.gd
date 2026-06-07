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
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failures: Array[String] = []
	await _run_suite("NewGame", NEW_GAME_TESTS, failures)
	await _run_suite("VegetationPondWater", VEGETATION_POND_WATER_TESTS, failures)
	await _run_suite("AnimalsDoNotSpawnInPondWater", ANIMALS_DO_NOT_SPAWN_IN_POND_WATER_TESTS, failures)
	await _run_suite("AnimalsRemainInsideWorldBounds", ANIMALS_REMAIN_INSIDE_WORLD_BOUNDS_TESTS, failures)
	await _run_suite("SmallPreySearchesForFoodWhenHungry", SMALL_PREY_SEARCHES_FOR_FOOD_WHEN_HUNGRY_TESTS, failures)
	await _run_suite("GrazerEatsPlantsWhenHungry", GRAZER_EATS_PLANTS_WHEN_HUNGRY_TESTS, failures)
	await _run_suite("VarnakHuntsPreyWhenHungry", VARNAK_HUNTS_PREY_WHEN_HUNGRY_TESTS, failures)
	await _run_suite("AnimalDeathCreatesMeatDrop", ANIMAL_DEATH_CREATES_MEAT_DROP_TESTS, failures)
	await _run_suite("ResourceRegrowthAdvancesAfterDayProgression", RESOURCE_REGROWTH_ADVANCES_AFTER_DAY_PROGRESSION_TESTS, failures)
	await _run_suite("SaveLoadRestoresEcosystemState", SAVE_LOAD_RESTORES_ECOSYSTEM_STATE_TESTS, failures)
	await _run_suite("MinimapRendersWithLandmarks", MINIMAP_RENDERS_WITH_LANDMARKS_TESTS, failures)
	if failures.is_empty():
		_cleanup_autoloads()
		var tree := get_tree()
		if tree != null:
			tree.current_scene = null
		var parent := get_parent()
		if parent != null:
			parent.remove_child(self)
		queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		print("[IntegrationTests] All integration tests passed.")
		get_tree().quit(0)
		return
	push_error("[IntegrationTests] %d failure(s):" % failures.size())
	for failure in failures:
		push_error(failure)
	_cleanup_autoloads()
	var failure_tree := get_tree()
	if failure_tree != null:
		failure_tree.current_scene = null
	var failure_parent := get_parent()
	if failure_parent != null:
		failure_parent.remove_child(self)
	queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1)


func _cleanup_autoloads() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for autoload_name in ["GraphicsSettings", "GameSession", "EventBus"]:
		var autoload := tree.root.get_node_or_null(autoload_name)
		if autoload != null:
			autoload.queue_free()


func _run_suite(name: String, suite_script: GDScript, failures: Array[String]) -> void:
	var suite: Object = suite_script.new()
	if not suite.has_method("run"):
		failures.append("%s suite does not implement run()" % name)
		suite = null
		return
	var suite_result: Variant = await suite.call("run")
	var suite_failures: Array[String] = Array(suite_result)
	suite = null
	if suite_failures.is_empty():
		print("[IntegrationTests] %s: OK" % name)
		return
	print("[IntegrationTests] %s: %d failure(s)" % [name, suite_failures.size()])
	for failure in suite_failures:
		failures.append("%s: %s" % [name, failure])
