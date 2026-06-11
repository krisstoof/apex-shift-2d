extends RefCounted

const Utils := preload("res://tests/regression/regression_test_utils.gd")
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const START_MENU_SCENE_PATH := "res://scenes/ui/start_menu.tscn"
const SAVE_PATH := "user://savegame.json"


func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []

	Utils.cleanup_save_file()
	await Utils.cleanup_context({"tree": tree, "nodes": []})

	var menu_result: Dictionary = await Utils.boot_start_menu(tree)
	if not bool(menu_result.get("ok", false)):
		return [String(menu_result.get("reason", "Could not boot start menu"))]

	var menu: Node = menu_result.get("scene") as Node
	var new_game_error: String = await _click_game_over_button(menu, "New Game", tree)
	if new_game_error != "":
		return [new_game_error]

	if not await _wait_for_scene_path(tree, MAIN_SCENE_PATH, 180):
		return ["New Game did not switch to main.tscn"]

	var main := tree.current_scene
	if main == null:
		return ["Current scene is null after New Game"]

	if not await Utils.wait_for_world_boot(main):
		return ["World did not boot"]

	await Utils.wait_frames(tree, 8)

	var context := _get_main_context(tree)
	var world: Node = context.get("world") as Node
	var player: Node = context.get("player") as Node
	var hud: Node = context.get("hud") as Node
	var save_system: Node = context.get("save_system") as Node
	var game_session: Node = tree.root.get_node_or_null("GameSession")

	if world == null:
		failures.append("World missing")
	if player == null:
		failures.append("Player missing")
	if hud == null:
		failures.append("HUD missing")
	if save_system == null:
		failures.append("SaveSystem missing")
	if game_session == null:
		failures.append("GameSession missing")
	if not failures.is_empty():
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	var expected_save_state := await _prepare_known_save(player, world, save_system, tree)
	_assert_save_file_exists(failures, "before first death")

	_kill_player(player, tree)
	var game_over_screen := _assert_game_over_visible(failures, tree, player, hud, "first death")
	if game_over_screen == null:
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	var restart_error := await _press_game_over_button(game_over_screen, "Restart", tree)
	if restart_error != "":
		failures.append(restart_error)
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	if not await _wait_for_scene_path(tree, MAIN_SCENE_PATH, 180):
		failures.append("Restart from GameOver did not switch to main.tscn.")
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	await Utils.wait_frames(tree, 12)
	context = _get_main_context(tree)
	main = context.get("main") as Node
	player = context.get("player") as Node
	hud = context.get("hud") as Node
	game_session = tree.root.get_node_or_null("GameSession")

	_assert_fresh_session_after_restart(failures, tree, main, game_session)
	if player == null or hud == null:
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	_kill_player(player, tree)
	game_over_screen = _assert_game_over_visible(failures, tree, player, hud, "second death before load save")
	if game_over_screen == null:
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	var load_button := _find_button_by_text_recursive(game_over_screen, "Load Save")
	if load_button == null:
		failures.append("Load Save button missing on GameOverScreen.")
	elif load_button.disabled:
		failures.append("Load Save button is disabled even though save file exists.")

	var load_error := await _press_game_over_button(game_over_screen, "Load Save", tree)
	if load_error != "":
		failures.append(load_error)
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	if not await _wait_for_scene_path(tree, MAIN_SCENE_PATH, 180):
		failures.append("Load Save from GameOver did not switch to main.tscn.")
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	await Utils.wait_frames(tree, 16)
	context = _get_main_context(tree)
	main = context.get("main") as Node
	player = context.get("player") as Node
	hud = context.get("hud") as Node
	game_session = tree.root.get_node_or_null("GameSession")

	if tree.paused:
		failures.append("Tree remained paused after Load Save from GameOver.")
	if game_session != null and bool(game_session.get("load_save_requested")):
		failures.append("GameSession.load_save_requested remained true after Load Save was consumed.")
	_assert_loaded_save_state(failures, player, expected_save_state)

	_kill_player(player, tree)
	game_over_screen = _assert_game_over_visible(failures, tree, player, hud, "third death before main menu")
	if game_over_screen == null:
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	var main_menu_error := await _press_game_over_button(game_over_screen, "Main Menu", tree)
	if main_menu_error != "":
		failures.append(main_menu_error)
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	if not await _wait_for_scene_path(tree, START_MENU_SCENE_PATH, 180):
		failures.append("Main Menu from GameOver did not switch to start_menu.tscn.")

	if tree.paused:
		failures.append("Tree remained paused after returning to main menu from GameOver.")
	if game_session != null and bool(game_session.get("load_save_requested")):
		failures.append("GameSession.load_save_requested remained true after returning to main menu.")
	if game_session != null and int(game_session.get("pending_world_seed")) == 0:
		failures.append("GameSession pending_world_seed was not prepared after returning to main menu.")

	await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
	Utils.cleanup_save_file()
	return failures


func _prepare_known_save(player: Node, world: Node, save_system: Node, tree: SceneTree) -> Dictionary:
	var player_2d := player as Node2D
	var saved_position := _get_safe_test_position(world, player)
	if player_2d != null:
		player_2d.global_position = saved_position

	var player_inventory := player.get("inventory") as Object
	if player_inventory != null:
		player_inventory.call("clear")
		player_inventory.call("add_item", "wood", 11)
		player_inventory.call("add_item", "stone", 4)
		player_inventory.call("add_item", "fiber", 2)

	player.set("has_spear", true)
	player.set("has_bow", false)

	if save_system != null and save_system.has_method("save_game"):
		save_system.call("save_game")
	await Utils.wait_frames(tree, 4)

	return {
		"position": saved_position,
		"wood": 11,
		"stone": 4,
		"fiber": 2,
		"has_spear": true,
		"has_bow": false
	}


func _get_safe_test_position(world: Node, player: Node) -> Vector2:
	if world != null and world.has_method("get_safe_player_start_position"):
		var safe := Vector2(world.call("get_safe_player_start_position")) + Vector2(48.0, 32.0)
		if world.has_method("get_world_rect"):
			var rect: Rect2 = world.call("get_world_rect")
			if rect.has_point(safe):
				return safe
		return safe

	if world != null and world.has_method("get_world_rect"):
		var rect2: Rect2 = world.call("get_world_rect")
		return rect2.position + rect2.size * 0.5

	return (player as Node2D).global_position if player is Node2D else Vector2.ZERO


func _kill_player(player: Node, tree: SceneTree) -> void:
	if player.has_method("set_god_mode"):
		player.call("set_god_mode", false)

	if player.get("stats") != null:
		player.stats.health = 1.0

	if player.has_method("receive_damage"):
		player.call("receive_damage", 9999.0, "test")
	else:
		player.stats.health = 0.0
		if player.has_method("_die"):
			player.call("_die", "test")

	await Utils.wait_frames(tree, 6)


func _get_main_context(tree: SceneTree) -> Dictionary:
	var main := tree.current_scene
	if main == null:
		return {}

	return {
		"main": main,
		"world": main.get_node_or_null("World"),
		"player": main.get_node_or_null("Player"),
		"hud": main.get_node_or_null("HUD"),
		"save_system": main.get_node_or_null("SaveSystem"),
		"game_manager": main.get_node_or_null("GameManager")
	}


func _assert_game_over_visible(failures: Array[String], tree: SceneTree, player: Node, hud: Node, label: String) -> Node:
	var game_over_screen := _get_game_over_screen(hud)
	if game_over_screen == null:
		failures.append("%s: GameOverScreen missing." % label)
		return null
	if not bool(game_over_screen.visible):
		failures.append("%s: GameOverScreen is not visible after death." % label)
	if tree.paused != true:
		failures.append("%s: tree.paused is not true after death." % label)
	if bool(player.get("is_dead")) != true:
		failures.append("%s: player.is_dead is not true after death." % label)
	var velocity: Vector2 = player.get("velocity")
	if velocity.length_squared() > 0.01:
		failures.append("%s: player velocity is not zero after death." % label)
	if player.is_processing():
		failures.append("%s: player processing is still enabled after death." % label)
	if player.is_physics_processing():
		failures.append("%s: player physics processing is still enabled after death." % label)
	return game_over_screen


func _get_game_over_screen(hud: Node) -> Node:
	if hud == null:
		return null
	var direct := hud.get_node_or_null("GameOverScreen")
	if direct != null:
		return direct
	var candidates := hud.find_children("*GameOver*", "Control", true, false)
	for candidate in candidates:
		if candidate != null and candidate.has_method("show_game_over"):
			return candidate
	return null


func _press_game_over_button(game_over_screen: Node, label: String, tree: SceneTree) -> String:
	if game_over_screen == null:
		return "GameOverScreen missing while pressing button: %s" % label
	var button := _find_button_by_text_recursive(game_over_screen, label)
	if button == null:
		return "GameOverScreen button not found: %s" % label
	if button.disabled:
		return "GameOverScreen button is disabled: %s" % label
	button.emit_signal("pressed")
	await Utils.wait_frames(tree, 8)
	return ""


func _click_game_over_button(menu: Node, label: String, tree: SceneTree) -> String:
	if menu == null:
		return "Start menu node missing"
	var button := _find_button_by_text_recursive(menu, label)
	if button == null:
		return "Start menu button not found: %s" % label
	if button.disabled:
		return "Start menu button is disabled: %s" % label
	button.emit_signal("pressed")
	await Utils.wait_frames(tree, 4)
	return ""


func _find_button_by_text_recursive(root: Node, text: String) -> Button:
	if root == null:
		return null
	if root is Button and root.text == text:
		return root
	for child in root.get_children():
		var result := _find_button_by_text_recursive(child, text)
		if result != null:
			return result
	return null


func _wait_for_scene_path(tree: SceneTree, expected_path: String, max_frames: int = 180) -> bool:
	for _i in range(max_frames):
		var scene := tree.current_scene
		if scene != null and scene.scene_file_path == expected_path:
			return true
		await Utils.wait_frames(tree, 1)
	return false


func _assert_loaded_save_state(failures: Array[String], player: Node, expected: Dictionary) -> void:
	var actual_position := (player as Node2D).global_position
	var expected_position := expected["position"] as Vector2
	if actual_position.distance_to(expected_position) > 2.0:
		failures.append("Load Save from GameOver did not restore player position. expected=%s actual=%s" % [expected_position, actual_position])

	var player_inventory := player.get("inventory") as Object
	if player_inventory == null:
		failures.append("Loaded player inventory is missing.")
		return

	if int(player_inventory.call("get_amount", "wood")) != int(expected["wood"]):
		failures.append("Load Save from GameOver did not restore wood inventory.")
	if int(player_inventory.call("get_amount", "stone")) != int(expected["stone"]):
		failures.append("Load Save from GameOver did not restore stone inventory.")
	if int(player_inventory.call("get_amount", "fiber")) != int(expected["fiber"]):
		failures.append("Load Save from GameOver did not restore fiber inventory.")
	if bool(player.get("has_spear")) != bool(expected["has_spear"]):
		failures.append("Load Save from GameOver did not restore has_spear.")
	if bool(player.get("has_bow")) != bool(expected["has_bow"]):
		failures.append("Load Save from GameOver did not restore has_bow.")


func _assert_fresh_session_after_restart(failures: Array[String], tree: SceneTree, old_main: Node, game_session: Node) -> void:
	if tree.paused:
		failures.append("Tree remained paused after Restart from GameOver.")
	var context := _get_main_context(tree)
	var main := context.get("main") as Node
	var player := context.get("player") as Node
	var hud := context.get("hud") as Node
	if main == null:
		failures.append("Main scene missing after Restart.")
		return
	if main == old_main:
		failures.append("Restart reused the same Main node instead of creating a fresh session.")
	if player == null:
		failures.append("Player missing after Restart.")
		return
	if bool(player.get("is_dead")) == true:
		failures.append("Player is still dead after Restart.")
	if float(player.get_health()) <= 0.0:
		failures.append("Player health is not positive after Restart.")
	if game_session != null and bool(game_session.get("load_save_requested")):
		failures.append("GameSession.load_save_requested remained true after Restart.")
	var game_over_screen := _get_game_over_screen(hud)
	if game_over_screen != null and game_over_screen.visible:
		failures.append("GameOverScreen remained visible after Restart.")


func _assert_save_file_exists(failures: Array[String], label: String) -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		failures.append("Save file was not created %s." % label)
