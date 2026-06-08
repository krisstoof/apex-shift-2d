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
const INVENTORY_TESTS := preload("res://tests/unit/test_inventory.gd")
const ECOSYSTEM_DIRECTOR_TESTS := preload("res://tests/unit/test_ecosystem_director.gd")
const ECOSYSTEM_COMMAND_DELTA_TESTS := preload("res://tests/unit/test_ecosystem_command_delta.gd")
const PLAYER_TESTS := preload("res://tests/unit/test_player.gd")
const CAMPFIRE_TESTS := preload("res://tests/unit/test_campfire.gd")
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
const ERROR_DRAIN_MAX_FRAMES := 8
const ERROR_DRAIN_STABLE_FRAMES := 2


var _unit_test_error_logger: UnitTestErrorLogger
var _unit_test_error_cursor := 0
var _mock_event_bus: Node


class UnitTestErrorLogger:
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


class MockEventBus:
	extends Node

	var messages: Array[String] = []
	var events: Array[Dictionary] = []

	func _init() -> void:
		name = "EventBus"

	func post_message(message: String) -> void:
		messages.append(message)

	func emit_game_event(event_name: String, payload: Dictionary = {}) -> void:
		events.append({
			"name": event_name,
			"payload": payload.duplicate(true)
		})

	func clear() -> void:
		messages.clear()
		events.clear()


func _enter_tree() -> void:
	_unit_test_error_logger = UnitTestErrorLogger.new()
	OS.add_logger(_unit_test_error_logger)


func _exit_tree() -> void:
	_remove_unit_test_error_logger()


func _ready() -> void:
	_ensure_mock_event_bus()
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failures: Array[String] = []
	await _run_suite("WorldConfig", WORLD_CONFIG_TESTS.new(), failures)
	await _run_suite("World", WORLD_TESTS.new(), failures)
	await _run_suite("WorldQueryService", WORLD_QUERY_SERVICE_TESTS.new(), failures)
	await _run_suite("WorldRenderController", WORLD_RENDER_CONTROLLER_TESTS.new(), failures)
	await _run_suite("LandmarkService", LANDMARK_SERVICE_TESTS.new(), failures)
	await _run_suite("ResourceService", RESOURCE_SERVICE_TESTS.new(), failures)
	await _run_suite("BenchmarkRunner", BENCHMARK_RUNNER_TESTS.new(), failures)
	await _run_suite("GameSession", GAME_SESSION_TESTS.new(), failures)
	await _run_suite("HungerDiet", HUNGER_DIET_TESTS.new(), failures)
	await _run_suite("ResourceNode", RESOURCE_NODE_TESTS.new(), failures)
	await _run_suite("Inventory", INVENTORY_TESTS.new(), failures)
	await _run_suite("EcosystemDirector", ECOSYSTEM_DIRECTOR_TESTS.new(), failures)
	await _run_suite("EcosystemCommandDelta", ECOSYSTEM_COMMAND_DELTA_TESTS.new(), failures)
	await _run_suite("Player", PLAYER_TESTS.new(), failures)
	await _run_suite("Campfire", CAMPFIRE_TESTS.new(), failures)
	await _run_suite("HUD", HUD_TESTS.new(), failures)
	await _run_suite("LoadingOverlay", LOADING_OVERLAY_TESTS.new(), failures)
	await _run_suite("Minimap", MINIMAP_TESTS.new(), failures)
	await _run_suite("MapScreen", MAP_SCREEN_TESTS.new(), failures)
	await _run_suite("WorldSnapshotService", WORLD_SNAPSHOT_SERVICE_TESTS.new(), failures)
	await _run_suite("DebugPanel", DEBUG_PANEL_TESTS.new(), failures)
	await _run_suite("StartMenu", START_MENU_TESTS.new(), failures)
	await _run_suite("GraphicsSettings", GRAPHICS_SETTINGS_TESTS.new(), failures)
	await _run_suite("SmallPrey", SMALL_PREY_TESTS.new(), failures)
	await _run_suite("Grazer", GRAZER_TESTS.new(), failures)
	await _run_suite("Varnak", VARNAK_TESTS.new(), failures)
	await _run_suite("SaveSystem", SAVE_SYSTEM_TESTS.new(), failures)
	await _drain_runtime_errors()
	_append_logged_errors(failures, "", _unit_test_error_cursor)
	_remove_unit_test_error_logger()
	if failures.is_empty():
		print("[UnitTests] All helper tests passed.")
		get_tree().quit(0)
		return
	push_error("[UnitTests] %d failure(s):" % failures.size())
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)


func _ensure_mock_event_bus() -> Node:
	var root := get_tree().root
	var existing := root.get_node_or_null("EventBus")
	if existing:
		_mock_event_bus = existing
		return existing

	_mock_event_bus = MockEventBus.new()
	root.add_child(_mock_event_bus)
	return _mock_event_bus


func _run_suite(name: String, suite: Object, failures: Array[String]) -> void:
	if not suite.has_method("run"):
		failures.append("%s suite does not implement run()" % name)
		return
	if _mock_event_bus and _mock_event_bus.has_method("clear"):
		_mock_event_bus.clear()
	var error_start_index := _unit_test_error_cursor
	var suite_result: Variant = await suite.call("run")
	await _drain_runtime_errors()
	if typeof(suite_result) != TYPE_ARRAY:
		failures.append("%s suite setup failed or returned an invalid result" % name)
		print("[UnitTests] %s: setup failed" % name)
		_append_logged_errors(failures, name, error_start_index)
		_unit_test_error_cursor = _get_logged_error_count()
		return
	var suite_failures: Array[String] = Array(suite_result)
	var runtime_failures := _collect_logged_errors(name, error_start_index)
	for runtime_failure in runtime_failures:
		suite_failures.append(runtime_failure)
	_unit_test_error_cursor = _get_logged_error_count()
	if suite_failures.is_empty():
		print("[UnitTests] %s: OK" % name)
		return
	print("[UnitTests] %s: %d failure(s)" % [name, suite_failures.size()])
	for failure in suite_failures:
		failures.append("%s: %s" % [name, failure])


func _append_logged_errors(failures: Array[String], suite_name: String = "", start_index: int = 0) -> void:
	var runtime_failures := _collect_logged_errors(suite_name, start_index)
	for runtime_failure in runtime_failures:
		failures.append(runtime_failure)


func _collect_logged_errors(suite_name: String = "", start_index: int = 0) -> Array[String]:
	if _unit_test_error_logger == null:
		return []
	var errors := _unit_test_error_logger.get_errors_since(start_index)
	var failures: Array[String] = []
	for error_value in errors:
		failures.append(_format_logged_error(suite_name, Dictionary(error_value)))
	return failures


func _format_logged_error(suite_name: String, error_data: Dictionary) -> String:
	var error_type := int(error_data.get("error_type", Logger.ERROR_TYPE_ERROR))
	var error_type_label := _get_error_type_label(error_type)
	var location := "%s:%d" % [
		str(error_data.get("file", "unknown")),
		int(error_data.get("line", 0))
	]
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
	if _unit_test_error_logger == null:
		return 0
	return _unit_test_error_logger.get_error_count()


func _remove_unit_test_error_logger() -> void:
	if _unit_test_error_logger == null:
		return
	OS.remove_logger(_unit_test_error_logger)
	_unit_test_error_logger = null


func _drain_runtime_errors() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var stable_frames := 0
	var last_error_count := _get_logged_error_count()
	for _i in range(ERROR_DRAIN_MAX_FRAMES):
		await tree.process_frame
		var current_error_count := _get_logged_error_count()
		if current_error_count == last_error_count:
			stable_frames += 1
			if stable_frames >= ERROR_DRAIN_STABLE_FRAMES:
				return
		else:
			stable_frames = 0
			last_error_count = current_error_count
