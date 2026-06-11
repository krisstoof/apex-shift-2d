extends RefCounted

const Utils := preload("res://tests/regression/regression_test_utils.gd")
const START_MENU_SCENE_PATH := "res://scenes/ui/start_menu.tscn"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const SAVE_PATH := "user://savegame.json"
const MAX_SCENE_CHANGE_FRAMES := 180
const MAX_WORLD_BOOT_FRAMES := 600


func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []

	await _cleanup_save_file()
	await Utils.cleanup_context({"tree": tree, "nodes": []})

	var menu_result: Dictionary = await Utils.boot_start_menu(tree)
	if not bool(menu_result.get("ok", false)):
		return [String(menu_result.get("reason", "Could not boot start menu"))]

	var start_menu: Node = menu_result.get("scene") as Node
	if start_menu == null:
		return ["Could not resolve StartMenu after boot"]

	if start_menu.name != "StartMenu":
		failures.append("Expected StartMenu root node, got: %s" % start_menu.name)

	var start_menu_game_session := tree.root.get_node_or_null("GameSession")
	if start_menu_game_session == null:
		failures.append("GameSession autoload is missing. Start menu flow must not skip GameSession.")

	var new_game_button: Button = Utils.find_button_by_text_recursive(start_menu, "New Game")
	if new_game_button == null:
		failures.append("New Game button was not found in StartMenu.")
		await Utils.cleanup_context({"tree": tree, "nodes": [start_menu]})
		await _cleanup_save_file()
		return failures

	new_game_button.grab_focus()
	new_game_button.emit_signal("pressed")

	var scene_changed := await _wait_for_scene_path(tree, MAIN_SCENE_PATH, MAX_SCENE_CHANGE_FRAMES)
	if not scene_changed:
		failures.append("New Game did not switch to %s." % MAIN_SCENE_PATH)
		await Utils.cleanup_context({"tree": tree, "nodes": [start_menu]})
		await _cleanup_save_file()
		return failures

	var main: Node = tree.current_scene
	if main == null:
		failures.append("Current scene is null after New Game.")
		await Utils.cleanup_context({"tree": tree, "nodes": [start_menu]})
		await _cleanup_save_file()
		return failures

	var world: Node = main.get_node_or_null("World")
	var player: Node = main.get_node_or_null("Player")
	var hud: Node = main.get_node_or_null("HUD")
	var game_manager: Node = main.get_node_or_null("GameManager")
	var ecosystem_director: Node = main.get_node_or_null("EcosystemDirector")
	var day_night_system: Node = main.get_node_or_null("DayNightSystem")
	var save_system: Node = main.get_node_or_null("SaveSystem")

	_assert_node_exists(failures, world, "World")
	_assert_node_exists(failures, player, "Player")
	_assert_node_exists(failures, hud, "HUD")
	_assert_node_exists(failures, game_manager, "GameManager")
	_assert_node_exists(failures, ecosystem_director, "EcosystemDirector")
	_assert_node_exists(failures, day_night_system, "DayNightSystem")
	_assert_node_exists(failures, save_system, "SaveSystem")

	if world == null or player == null or day_night_system == null or save_system == null:
		await Utils.cleanup_context({"tree": tree, "nodes": [start_menu, main]})
		await _cleanup_save_file()
		return failures

	if not await Utils.wait_for_world_boot(main):
		failures.append("World did not finish booting before save.")
		await Utils.cleanup_context({"tree": tree, "nodes": [start_menu, main]})
		await _cleanup_save_file()
		return failures

	await Utils.wait_frames(tree, 4)

	var expected_world_seed: int = int(world.call("get_world_seed"))
	var expected_landmarks: Array = Array(world.call("get_landmarks")).duplicate(true)
	var expected_landmarks_json := _normalize_landmarks(expected_landmarks)

	var world_rect: Rect2 = world.call("get_world_rect")
	var expected_player_position: Vector2 = world_rect.get_center()
	if world.has_method("get_safe_player_start_position"):
		expected_player_position = Vector2(world.call("get_safe_player_start_position")) + Vector2(24.0, 0.0)
		if not world_rect.has_point(expected_player_position):
			expected_player_position = Vector2(expected_player_position) - Vector2(48.0, 0.0)
	player.global_position = expected_player_position

	var player_inventory: Object = player.get("inventory") as Object
	if player_inventory == null:
		failures.append("Player inventory is missing before save.")
		await Utils.cleanup_context({"tree": tree, "nodes": [start_menu, main]})
		await _cleanup_save_file()
		return failures
	player_inventory.call("clear")
	player_inventory.call("add_item", "wood", 7)
	player_inventory.call("add_item", "stone", 3)
	player_inventory.call("add_item", "fiber", 2)
	var expected_inventory: Dictionary = Dictionary(player_inventory.call("to_save_data")).duplicate(true)

	day_night_system.set("day", 4)
	day_night_system.set("time_of_day", 92.5)

	var expected_day := int(day_night_system.day)
	var expected_time_of_day := float(day_night_system.time_of_day)

	var save_error := _save_game(main)
	if save_error != "":
		failures.append(save_error)
		await Utils.cleanup_context({"tree": tree, "nodes": [start_menu, main]})
		await _cleanup_save_file()
		return failures

	await Utils.wait_frames(tree, 4)
	if not FileAccess.file_exists(SAVE_PATH):
		failures.append("Save file was not created before Continue.")
		await Utils.cleanup_context({"tree": tree, "nodes": [start_menu, main]})
		await _cleanup_save_file()
		return failures

	await Utils.cleanup_context({"tree": tree, "nodes": [main]})

	var continue_menu_result: Dictionary = await Utils.boot_start_menu(tree)
	if not bool(continue_menu_result.get("ok", false)):
		return [String(continue_menu_result.get("reason", "Could not boot start menu before Continue"))]

	var continue_menu: Node = continue_menu_result.get("scene") as Node
	var continue_button: Button = Utils.find_button_by_text_recursive(continue_menu, "Continue")
	if continue_button == null:
		failures.append("Continue button was not found.")
	elif continue_button.disabled:
		failures.append("Continue button is disabled even though save file exists.")

	var continue_error: String = await Utils.click_continue_from_menu(continue_menu, tree)
	if continue_error != "":
		failures.append(continue_error)
		await Utils.cleanup_context({"tree": tree, "nodes": [continue_menu]})
		await _cleanup_save_file()
		return failures

	var continue_scene_changed := await _wait_for_scene_path(tree, MAIN_SCENE_PATH, MAX_SCENE_CHANGE_FRAMES)
	if not continue_scene_changed:
		failures.append("Continue did not switch to main.tscn.")
		await Utils.cleanup_context({"tree": tree, "nodes": [continue_menu]})
		await _cleanup_save_file()
		return failures

	var loaded_main: Node = tree.current_scene
	if loaded_main == null:
		failures.append("Current scene is null after Continue.")
		await Utils.cleanup_context({"tree": tree, "nodes": [continue_menu]})
		await _cleanup_save_file()
		return failures

	if not await Utils.wait_for_world_boot(loaded_main):
		failures.append("World did not boot after Continue.")

	await Utils.wait_frames(tree, 8)

	var loaded_world: Node = loaded_main.get_node_or_null("World")
	var loaded_player: Node = loaded_main.get_node_or_null("Player")
	var loaded_day_night_system: Node = loaded_main.get_node_or_null("DayNightSystem")
	var loaded_hud: Node = loaded_main.get_node_or_null("HUD")

	_assert_node_exists(failures, loaded_world, "World")
	_assert_node_exists(failures, loaded_player, "Player")
	_assert_node_exists(failures, loaded_day_night_system, "DayNightSystem")
	_assert_node_exists(failures, loaded_hud, "HUD")

	if loaded_world == null or loaded_player == null or loaded_day_night_system == null:
		await Utils.cleanup_context({"tree": tree, "nodes": [continue_menu, loaded_main]})
		await _cleanup_save_file()
		return failures

	if int(loaded_world.call("get_world_seed")) != expected_world_seed:
		failures.append("World seed changed after Continue. expected=%d actual=%d" % [expected_world_seed, int(loaded_world.call("get_world_seed"))])

	var actual_landmarks_json: String = _normalize_landmarks(Array(loaded_world.call("get_landmarks")))
	if actual_landmarks_json != expected_landmarks_json:
		failures.append("Landmarks changed after Continue.")

	if loaded_player.global_position.distance_to(Vector2(expected_player_position)) > 2.0:
		failures.append("Player position was not restored. expected=%s actual=%s" % [
			Vector2(expected_player_position),
			loaded_player.global_position
		])

	var loaded_inventory_object: Object = loaded_player.get("inventory") as Object
	if loaded_inventory_object == null:
		failures.append("Loaded player inventory is missing.")
	else:
		var loaded_inventory: Dictionary = Dictionary(loaded_inventory_object.call("to_save_data"))
		if JSON.stringify(loaded_inventory) != JSON.stringify(expected_inventory):
			failures.append("Inventory was not restored. expected=%s actual=%s" % [
				JSON.stringify(expected_inventory),
				JSON.stringify(loaded_inventory)
			])

	if int(loaded_day_night_system.day) != expected_day:
		failures.append("Day was not restored. expected=%d actual=%d" % [expected_day, int(loaded_day_night_system.day)])

	if absf(float(loaded_day_night_system.time_of_day) - expected_time_of_day) > 0.5:
		failures.append("Time of day was not restored. expected=%.3f actual=%.3f" % [
			expected_time_of_day,
			float(loaded_day_night_system.time_of_day)
		])

	var loaded_game_session: Node = tree.root.get_node_or_null("GameSession")
	if loaded_game_session == null:
		failures.append("GameSession missing after Continue.")
	else:
		if int(loaded_game_session.call("get_bootstrap_world_seed")) != expected_world_seed:
			failures.append("GameSession bootstrap seed mismatch. expected=%d actual=%d" % [
				expected_world_seed,
				int(loaded_game_session.call("get_bootstrap_world_seed"))
			])
		var bootstrap_landmarks_json := _normalize_landmarks(Array(loaded_game_session.call("get_bootstrap_landmarks")))
		if bootstrap_landmarks_json != expected_landmarks_json:
			failures.append("GameSession bootstrap landmarks changed after Continue.")

	if loaded_hud is CanvasItem and not loaded_hud.visible:
		failures.append("HUD is not visible after Continue.")

	if tree.paused:
		failures.append("SceneTree is paused after Continue.")

	await Utils.cleanup_context({"tree": tree, "nodes": [continue_menu, loaded_main]})
	await _cleanup_save_file()

	return failures


func _assert_node_exists(failures: Array[String], node: Node, node_name: String) -> void:
	if node == null or not is_instance_valid(node):
		failures.append("%s node is missing." % node_name)


func _wait_for_scene_path(tree: SceneTree, expected_path: String, max_frames: int) -> bool:
	for _i in range(max_frames):
		await tree.process_frame
		var current := tree.current_scene
		if current != null and current.scene_file_path == expected_path:
			return true
	return false


func _normalize_landmarks(landmarks: Array) -> String:
	var normalized: Array = []
	for entry in landmarks:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		normalized.append(Dictionary(entry).duplicate(true))

	normalized.sort_custom(func(a, b):
		return JSON.stringify(a) < JSON.stringify(b)
	)
	return JSON.stringify(normalized)


func _save_game(main: Node) -> String:
	var save_system := main.get_node_or_null("SaveSystem")
	if save_system == null:
		return "SaveSystem missing before save."
	if not save_system.has_method("save_game"):
		return "SaveSystem.save_game() is missing."
	save_system.call("save_game")
	return ""


func _cleanup_save_file() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		if err != OK:
			push_warning("[RegressionTests] Could not remove save file %s. Error: %s" % [SAVE_PATH, err])
