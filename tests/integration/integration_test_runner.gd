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
const SAVE_LOAD_ECOSYSTEM_AFTER_DAYS_TESTS := preload("res://tests/integration/test_save_load_ecosystem_after_days.gd")
const MINIMAP_RENDERS_WITH_LANDMARKS_TESTS := preload("res://tests/integration/test_minimap_renders_with_landmarks.gd")
const DECORATIVE_VEGETATION_NODE_BUDGET_TESTS := preload("res://tests/integration/test_decorative_vegetation_node_budget.gd")
const VISIBILITY_CULLING_REGISTRY_SAFETY_TESTS := preload("res://tests/integration/test_visibility_culling_registry_safety.gd")
const HUD_SAVE_LOAD_REFRESH_TESTS := preload("res://tests/integration/test_hud_save_load_refresh.gd")
const STORAGE_BOX_SAVE_DATA_TESTS := preload("res://tests/integration/test_storage_box_save_data.gd")
const ERROR_DRAIN_MAX_FRAMES := 8
const ERROR_DRAIN_STABLE_FRAMES := 2


var _integration_test_error_logger: IntegrationTestErrorLogger
var _integration_test_error_cursor := 0


class IntegrationTestErrorLogger:
	extends Logger

	var _mutex := Mutex.new()
	var _errors: Array[Dictionary] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces) -> void:
		if error_type != Logger.ERROR_TYPE_ERROR and error_type != Logger.ERROR_TYPE_SCRIPT:
			return
		_mutex.lock()
		_errors.append({
			"function": function,
			"file": file,
			"line": line,
			"code": code,
			"rationale": rationale,
			"error_type": error_type
		})
		_mutex.unlock()

	func get_error_count() -> int:
		_mutex.lock()
		var count := _errors.size()
		_mutex.unlock()
		return count

	func get_errors_since(index: int) -> Array[Dictionary]:
		_mutex.lock()
		var collected: Array[Dictionary] = []
		var start_index := maxi(index, 0)
		for i in range(start_index, _errors.size()):
			collected.append(Dictionary(_errors[i]).duplicate(true))
		_mutex.unlock()
		return collected


func _enter_tree() -> void:
	_integration_test_error_logger = IntegrationTestErrorLogger.new()
	OS.add_logger(_integration_test_error_logger)


func _exit_tree() -> void:
	_remove_integration_test_error_logger()


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
	await _run_suite("SaveLoadEcosystemAfterDays", SAVE_LOAD_ECOSYSTEM_AFTER_DAYS_TESTS, failures)
	await _run_suite("MinimapRendersWithLandmarks", MINIMAP_RENDERS_WITH_LANDMARKS_TESTS, failures)
	await _run_suite("DecorativeVegetationNodeBudget", DECORATIVE_VEGETATION_NODE_BUDGET_TESTS, failures)
	await _run_suite("VisibilityCullingRegistrySafety", VISIBILITY_CULLING_REGISTRY_SAFETY_TESTS, failures)
	await _run_suite("HUDSaveLoadRefresh", HUD_SAVE_LOAD_REFRESH_TESTS, failures)
	await _run_suite("StorageBoxSaveData", STORAGE_BOX_SAVE_DATA_TESTS, failures)
	await _drain_runtime_errors()
	_append_logged_errors(failures, "", _integration_test_error_cursor)
	_remove_integration_test_error_logger()
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
		await _cleanup_after_suite(name, failures)
		return
	var error_start_index := _integration_test_error_cursor
	var suite_result: Variant = await suite.call("run")
	await _drain_runtime_errors()
	var suite_failures: Array[String] = Array(suite_result)
	var runtime_failures := _collect_logged_errors(name, error_start_index)
	for runtime_failure in runtime_failures:
		suite_failures.append(runtime_failure)
	_integration_test_error_cursor = _get_logged_error_count()
	suite = null
	if suite_failures.is_empty():
		print("[IntegrationTests] %s: OK" % name)
		await _cleanup_after_suite(name, failures)
		return
	print("[IntegrationTests] %s: %d failure(s)" % [name, suite_failures.size()])
	for failure in suite_failures:
		failures.append("%s: %s" % [name, failure])
	await _cleanup_after_suite(name, failures)


func _cleanup_after_suite(name: String, failures: Array[String]) -> void:
	var tree := get_tree()
	if tree == null:
		return
	if tree.paused:
		failures.append("%s left SceneTree.paused=true" % name)
		tree.paused = false
	_cleanup_save_file()
	await tree.process_frame
	await tree.process_frame


func _cleanup_save_file() -> void:
	if FileAccess.file_exists("user://savegame.json"):
		var save_path := ProjectSettings.globalize_path("user://savegame.json")
		DirAccess.remove_absolute(save_path)


func _drain_runtime_errors() -> void:
	if _integration_test_error_logger == null:
		return
	var stable_frames := 0
	var previous_count := _integration_test_error_logger.get_error_count()
	for _i in range(ERROR_DRAIN_MAX_FRAMES):
		await get_tree().process_frame
		var current_count := _integration_test_error_logger.get_error_count()
		if current_count == previous_count:
			stable_frames += 1
			if stable_frames >= ERROR_DRAIN_STABLE_FRAMES:
				return
		else:
			stable_frames = 0
			previous_count = current_count


func _append_logged_errors(failures: Array[String], suite_name: String = "", start_index: int = 0) -> void:
	var runtime_failures := _collect_logged_errors(suite_name, start_index)
	for runtime_failure in runtime_failures:
		failures.append(runtime_failure)


func _collect_logged_errors(suite_name: String = "", start_index: int = 0) -> Array[String]:
	if _integration_test_error_logger == null:
		return []
	var errors := _integration_test_error_logger.get_errors_since(start_index)
	var failures: Array[String] = []
	for error_value in errors:
		failures.append(_format_logged_error(suite_name, Dictionary(error_value)))
	return failures


func _format_logged_error(suite_name: String, error_data: Dictionary) -> String:
	var error_type := int(error_data.get("error_type", Logger.ERROR_TYPE_ERROR))
	var error_type_label := _get_error_type_label(error_type)
	var location := "%s:%d" % [str(error_data.get("file", "unknown")), int(error_data.get("line", 0))]
	var function_name := str(error_data.get("function", ""))
	var rationale := str(error_data.get("rationale", ""))
	var code := str(error_data.get("code", ""))
	var message := rationale if not rationale.is_empty() else code
	message = message.replace("\n", " ").strip_edges()
	if not function_name.is_empty():
		message = "%s (%s)" % [message, function_name]
	if not suite_name.is_empty():
		return "%s runtime %s: %s - %s" % [suite_name, error_type_label, location, message]
	return "runtime %s: %s - %s" % [error_type_label, location, message]


func _get_error_type_label(error_type: int) -> String:
	match error_type:
		Logger.ERROR_TYPE_SCRIPT:
			return "SCRIPT ERROR"
		Logger.ERROR_TYPE_SHADER:
			return "SHADER ERROR"
		Logger.ERROR_TYPE_WARNING:
			return "WARNING"
		_:
			return "ERROR"


func _get_logged_error_count() -> int:
	if _integration_test_error_logger == null:
		return 0
	return _integration_test_error_logger.get_error_count()


func _remove_integration_test_error_logger() -> void:
	if _integration_test_error_logger == null:
		return
	OS.remove_logger(_integration_test_error_logger)
	_integration_test_error_logger = null
