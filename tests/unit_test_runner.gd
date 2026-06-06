extends Node

const WORLD_CONFIG_TESTS := preload("res://tests/unit/test_world_config.gd")
const WORLD_TESTS := preload("res://tests/unit/test_world.gd")
const WORLD_QUERY_SERVICE_TESTS := preload("res://tests/unit/test_world_query_service.gd")
const WORLD_RENDER_CONTROLLER_TESTS := preload("res://tests/unit/test_world_render_controller.gd")
const LANDMARK_SERVICE_TESTS := preload("res://tests/unit/test_landmark_service.gd")
const RESOURCE_SERVICE_TESTS := preload("res://tests/unit/test_resource_service.gd")
const BENCHMARK_RUNNER_TESTS := preload("res://tests/unit/test_benchmark_runner.gd")
const GAME_SESSION_TESTS := preload("res://tests/unit/test_game_session.gd")
const HUNGER_DIET_TESTS := preload("res://tests/unit/test_hunger_diet.gd")
const RESOURCE_NODE_TESTS := preload("res://tests/unit/test_resource_node.gd")
const ECOSYSTEM_DIRECTOR_TESTS := preload("res://tests/unit/test_ecosystem_director.gd")
const ECOSYSTEM_COMMAND_DELTA_TESTS := preload("res://tests/unit/test_ecosystem_command_delta.gd")
const PLAYER_TESTS := preload("res://tests/unit/test_player.gd")
const HUD_TESTS := preload("res://tests/unit/test_hud.gd")
const LOADING_OVERLAY_TESTS := preload("res://tests/unit/test_loading_overlay.gd")
const MINIMAP_TESTS := preload("res://tests/unit/test_minimap.gd")
const MAP_SCREEN_TESTS := preload("res://tests/unit/test_map_screen.gd")
const WORLD_SNAPSHOT_SERVICE_TESTS := preload("res://tests/unit/test_world_snapshot_service.gd")
const DEBUG_PANEL_TESTS := preload("res://tests/unit/test_debug_panel.gd")
const START_MENU_TESTS := preload("res://tests/unit/test_start_menu.gd")
const GRAPHICS_SETTINGS_TESTS := preload("res://tests/unit/test_graphics_settings.gd")
const SMALL_PREY_TESTS := preload("res://tests/unit/test_small_prey.gd")
const GRAZER_TESTS := preload("res://tests/unit/test_grazer.gd")
const VARNAK_TESTS := preload("res://tests/unit/test_varnak.gd")
const SAVE_SYSTEM_TESTS := preload("res://tests/unit/test_save_system.gd")


func _ready() -> void:
	var failures: Array[String] = []
	_run_suite("WorldConfig", WORLD_CONFIG_TESTS.new(), failures)
	_run_suite("World", WORLD_TESTS.new(), failures)
	_run_suite("WorldQueryService", WORLD_QUERY_SERVICE_TESTS.new(), failures)
	_run_suite("WorldRenderController", WORLD_RENDER_CONTROLLER_TESTS.new(), failures)
	_run_suite("LandmarkService", LANDMARK_SERVICE_TESTS.new(), failures)
	_run_suite("ResourceService", RESOURCE_SERVICE_TESTS.new(), failures)
	_run_suite("BenchmarkRunner", BENCHMARK_RUNNER_TESTS.new(), failures)
	_run_suite("GameSession", GAME_SESSION_TESTS.new(), failures)
	_run_suite("HungerDiet", HUNGER_DIET_TESTS.new(), failures)
	_run_suite("ResourceNode", RESOURCE_NODE_TESTS.new(), failures)
	_run_suite("EcosystemDirector", ECOSYSTEM_DIRECTOR_TESTS.new(), failures)
	_run_suite("EcosystemCommandDelta", ECOSYSTEM_COMMAND_DELTA_TESTS.new(), failures)
	_run_suite("Player", PLAYER_TESTS.new(), failures)
	_run_suite("HUD", HUD_TESTS.new(), failures)
	_run_suite("LoadingOverlay", LOADING_OVERLAY_TESTS.new(), failures)
	_run_suite("Minimap", MINIMAP_TESTS.new(), failures)
	_run_suite("MapScreen", MAP_SCREEN_TESTS.new(), failures)
	_run_suite("WorldSnapshotService", WORLD_SNAPSHOT_SERVICE_TESTS.new(), failures)
	_run_suite("DebugPanel", DEBUG_PANEL_TESTS.new(), failures)
	_run_suite("StartMenu", START_MENU_TESTS.new(), failures)
	_run_suite("GraphicsSettings", GRAPHICS_SETTINGS_TESTS.new(), failures)
	_run_suite("SmallPrey", SMALL_PREY_TESTS.new(), failures)
	_run_suite("Grazer", GRAZER_TESTS.new(), failures)
	_run_suite("Varnak", VARNAK_TESTS.new(), failures)
	_run_suite("SaveSystem", SAVE_SYSTEM_TESTS.new(), failures)
	if failures.is_empty():
		print("[UnitTests] All helper tests passed.")
		get_tree().quit(0)
		return
	push_error("[UnitTests] %d failure(s):" % failures.size())
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)


func _run_suite(name: String, suite: Object, failures: Array[String]) -> void:
	if not suite.has_method("run"):
		failures.append("%s suite does not implement run()" % name)
		return
	var suite_failures: Array[String] = suite.call("run")
	if suite_failures.is_empty():
		print("[UnitTests] %s: OK" % name)
		return
	print("[UnitTests] %s: %d failure(s)" % [name, suite_failures.size()])
	for failure in suite_failures:
		failures.append("%s: %s" % [name, failure])
