# Regression tests runner.
#
# Run from project root:
#   godot --headless --path . -s res://tests/regression/regression_test_runner.gd
#   godot4 --headless --path . -s res://tests/regression/regression_test_runner.gd
#
# Expected exit codes:
#   0 - all regression scenarios passed
#   1 - at least one regression scenario failed

extends SceneTree

const Utils := preload("res://tests/regression/regression_test_utils.gd")
const START_MENU_NEW_GAME_BOOTS_PLAYABLE_SESSION_TEST := preload("res://tests/regression/test_start_menu_new_game_boots_playable_session.gd")
const CONTINUE_RESTORES_SAVED_WORLD_BOOTSTRAP_TEST := preload("res://tests/regression/test_continue_restores_saved_world_bootstrap.gd")
const BASIC_SURVIVAL_LOOP_FROM_EMPTY_INVENTORY_TEST := preload("res://tests/regression/test_basic_survival_loop_from_empty_inventory.gd")
const STORAGE_BOX_TRANSFER_SAVE_LOAD_TEST := preload("res://tests/regression/test_storage_box_transfer_save_load.gd")
const UI_MODAL_STACK_TEST := preload("res://tests/regression/test_ui_modal_stack_inventory_map_pause_storage.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	var scenarios := [
		{"name": "UI_ModalStack_Inventory_Map_Pause_Storage", "method": "_scenario_ui_modal_stack_inventory_map_pause_storage"},
		{"name": "StorageBox_Transfer_SaveLoad", "method": "_scenario_storage_box_transfer_save_load"},
		{"name": "BasicSurvivalLoop_FromEmptyInventory", "method": "_scenario_basic_survival_loop_from_empty_inventory"},
		{"name": "StartMenu_Continue_RestoresSavedWorldBootstrap", "method": "_scenario_continue_restores_saved_world_bootstrap"},
		{"name": "StartMenu_NewGame_BootsPlayableSession", "method": "_scenario_start_menu_new_game_boots_playable_session"},
		{"name": "StartMenu_NewGame_WorldBoot", "method": "_scenario_start_menu_new_game_world_boot"},
		{"name": "DirectMain_WorldBoot_GameplaySmoke", "method": "_scenario_direct_main_world_boot_gameplay_smoke"},
		{"name": "Save_Load_Continue_Flow", "method": "_scenario_save_load_continue_flow"}
	]

	for scenario in scenarios:
		await _run_scenario(scenario)

	if _failures.is_empty():
		print("[RegressionTests] All regression tests passed.")
		quit(0)
		return

	push_error("[RegressionTests] %d failure(s):" % _failures.size())
	for failure in _failures:
		push_error(failure)
	quit(1)


func _run_scenario(scenario: Dictionary) -> void:
	var name := String(scenario.get("name", "UnnamedScenario"))
	var method_name := String(scenario.get("method", ""))
	print("[RegressionTests] Running %s..." % name)
	Utils.cleanup_save_file()

	if not has_method(method_name):
		var missing_method := "%s: runner method missing: %s" % [name, method_name]
		_failures.append(missing_method)
		push_error("[RegressionTests] %s: FAILED - %s" % [name, missing_method])
		Utils.cleanup_save_file()
		await Utils.wait_frames(self, 4)
		return

	var result: Dictionary = await call(method_name)
	Utils.cleanup_save_file()
	await Utils.wait_frames(self, 4)

	if bool(result.get("ok", false)):
		print("[RegressionTests] %s: OK" % name)
		return

	var reason := String(result.get("reason", "Unknown failure"))
	_failures.append("%s: %s" % [name, reason])
	push_error("[RegressionTests] %s: FAILED - %s" % [name, reason])


func _scenario_start_menu_new_game_world_boot() -> Dictionary:
	var tree: SceneTree = self
	var menu_result := await Utils.boot_start_menu(tree)
	if not bool(menu_result.get("ok", false)):
		return menu_result
	var menu := menu_result.get("scene") as Node
	var load_error := await _press_new_game(menu, tree)
	if load_error != "":
		return {"ok": false, "reason": load_error}
	await Utils.wait_frames(tree, 3)

	var main := Utils.find_main(tree)
	if main == null:
		return {"ok": false, "reason": "Main scene was not reached after New Game"}
	var world := Utils.find_world(main)
	var player := Utils.find_player(main)
	var hud := main.get_node_or_null("HUD")
	var game_manager := main.get_node_or_null("GameManager")
	var save_system := main.get_node_or_null("SaveSystem")
	var checks: Array[String] = [
		Utils.assert_node_exists(main, "Main scene missing after New Game"),
		Utils.assert_node_exists(world, "World node missing after boot"),
		Utils.assert_node_exists(player, "Player node missing after boot"),
		Utils.assert_node_exists(hud, "HUD node missing after boot"),
		Utils.assert_node_exists(game_manager, "GameManager node missing after boot"),
		Utils.assert_node_exists(save_system, "SaveSystem node missing after boot")
	]
	for check in checks:
		if check != "":
			return {"ok": false, "reason": check}
	if world.has_method("is_boot_ready") and not bool(world.call("is_boot_ready")):
		await Utils.wait_frames(tree, 4)
		if not bool(world.call("is_boot_ready")):
			return {"ok": false, "reason": "World did not become boot ready"}
	if world.has_signal("world_initialized") and not bool(world.call("is_boot_ready")):
		await world.world_initialized
	if world.has_method("get_world_rect") and player is Node2D:
		var world_rect: Rect2 = world.call("get_world_rect")
		if not world_rect.has_point((player as Node2D).global_position):
			return {"ok": false, "reason": "Player spawned outside world bounds"}
	await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
	return {"ok": true}


func _scenario_start_menu_new_game_boots_playable_session() -> Dictionary:
	var suite := START_MENU_NEW_GAME_BOOTS_PLAYABLE_SESSION_TEST.new()
	var failures: Array[String] = await suite.run(self)
	if failures.is_empty():
		return {"ok": true}
	return {"ok": false, "reason": failures[0]}


func _scenario_continue_restores_saved_world_bootstrap() -> Dictionary:
	var suite := CONTINUE_RESTORES_SAVED_WORLD_BOOTSTRAP_TEST.new()
	var failures: Array[String] = await suite.run(self)
	if failures.is_empty():
		return {"ok": true}
	return {"ok": false, "reason": failures[0]}


func _scenario_basic_survival_loop_from_empty_inventory() -> Dictionary:
	var suite := BASIC_SURVIVAL_LOOP_FROM_EMPTY_INVENTORY_TEST.new()
	var failures: Array[String] = await suite.run(self)
	if failures.is_empty():
		return {"ok": true}
	return {"ok": false, "reason": failures[0]}


func _scenario_storage_box_transfer_save_load() -> Dictionary:
	var suite := STORAGE_BOX_TRANSFER_SAVE_LOAD_TEST.new()
	var failures: Array[String] = await suite.run(self)
	if failures.is_empty():
		return {"ok": true}
	return {"ok": false, "reason": failures[0]}


func _scenario_ui_modal_stack_inventory_map_pause_storage() -> Dictionary:
	var suite := UI_MODAL_STACK_TEST.new()
	var failures: Array[String] = await suite.run(self)
	if failures.is_empty():
		return {"ok": true}
	return {"ok": false, "reason": failures[0]}


func _scenario_direct_main_world_boot_gameplay_smoke() -> Dictionary:
	var tree: SceneTree = self
	var main_result := await Utils.boot_main(tree, {"integration_test_mode": false})
	if not bool(main_result.get("ok", false)):
		return main_result
	var main := main_result.get("main") as Node
	var world := Utils.find_world(main)
	var player := Utils.find_player(main)
	var hud := main.get_node_or_null("HUD")
	var game_manager := main.get_node_or_null("GameManager")
	var save_system := main.get_node_or_null("SaveSystem")
	var ecosystem_director := main.get_node_or_null("EcosystemDirector")
	for message in [
		Utils.assert_node_exists(world, "World node missing after direct main boot"),
		Utils.assert_node_exists(player, "Player node missing after direct main boot"),
		Utils.assert_node_exists(hud, "HUD node missing after direct main boot"),
		Utils.assert_node_exists(game_manager, "GameManager node missing after direct main boot"),
		Utils.assert_node_exists(save_system, "SaveSystem node missing after direct main boot"),
		Utils.assert_node_exists(ecosystem_director, "EcosystemDirector node missing after direct main boot")
	]:
		if message != "":
			return {"ok": false, "reason": message}
	await Utils.wait_frames(tree, 6)
	if not is_instance_valid(main) or main.get_parent() == null:
		return {"ok": false, "reason": "Main scene was freed during gameplay smoke"}
	if not is_instance_valid(player):
		return {"ok": false, "reason": "Player vanished during gameplay smoke"}
	return {"ok": true}


func _scenario_save_load_continue_flow() -> Dictionary:
	var tree: SceneTree = self
	var menu_result := await Utils.boot_start_menu(tree)
	if not bool(menu_result.get("ok", false)):
		return menu_result
	var menu := menu_result.get("scene") as Node
	var new_game_error := await _press_new_game(menu, tree)
	if new_game_error != "":
		return {"ok": false, "reason": new_game_error}
	await Utils.wait_frames(tree, 4)
	var main := Utils.find_main(tree)
	var world := Utils.find_world(main)
	var player := Utils.find_player(main)
	if main == null or world == null or player == null:
		return {"ok": false, "reason": "Main, World, or Player missing before save"}
	if player is Node2D:
		(player as Node2D).global_position += Vector2(18.0, -12.0)
	var save_error := await Utils.save_game(main)
	if save_error != "":
		return {"ok": false, "reason": save_error}
	if not FileAccess.file_exists("user://savegame.json"):
		return {"ok": false, "reason": "Save file was not found after saving"}
	await Utils.cleanup_context({"tree": tree, "nodes": [main]})
	var continue_menu_result := await Utils.boot_start_menu(tree)
	if not bool(continue_menu_result.get("ok", false)):
		return continue_menu_result
	var continue_menu := continue_menu_result.get("scene") as Node
	var continue_error := await Utils.load_or_continue_from_menu(continue_menu, tree)
	if continue_error != "":
		return {"ok": false, "reason": continue_error}
	await Utils.wait_frames(tree, 4)
	main = Utils.find_main(tree)
	world = Utils.find_world(main)
	player = Utils.find_player(main)
	if main == null or world == null or player == null:
		return {"ok": false, "reason": "Main, World, or Player missing after continue"}
	if world.has_method("is_boot_ready") and not bool(world.call("is_boot_ready")):
		await Utils.wait_frames(tree, 4)
		if not bool(world.call("is_boot_ready")):
			return {"ok": false, "reason": "World did not boot after continue"}
	await Utils.cleanup_context({"tree": tree, "nodes": [continue_menu, main]})
	return {"ok": true}


func _press_new_game(menu: Node, tree: SceneTree) -> String:
	if menu == null:
		return "Start menu node missing"
	var new_game_button: Button = menu.get("new_game_button") as Button
	if new_game_button is Button:
		new_game_button.emit_signal("pressed")
		await Utils.wait_frames(tree, 2)
		return ""
	for child in menu.get_children():
		var button := child as Button
		if button != null and button.text == "New Game":
			button.emit_signal("pressed")
			await Utils.wait_frames(tree, 2)
			return ""
	return "New Game button was not found"
