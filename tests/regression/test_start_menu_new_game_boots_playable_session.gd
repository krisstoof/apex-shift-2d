extends RefCounted

const START_MENU_SCENE_PATH := "res://scenes/ui/start_menu.tscn"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAX_SCENE_CHANGE_FRAMES := 120
const MAX_WORLD_BOOT_FRAMES := 600


func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []

	await _cleanup_save_file()
	await _cleanup_tree(tree)

	var start_menu_scene := load(START_MENU_SCENE_PATH) as PackedScene
	if start_menu_scene == null:
		return ["Could not load %s" % START_MENU_SCENE_PATH]

	var start_menu := start_menu_scene.instantiate()
	if start_menu == null:
		return ["Could not instantiate StartMenu"]

	tree.root.add_child(start_menu)
	tree.current_scene = start_menu

	await tree.process_frame
	await tree.process_frame

	if start_menu.name != "StartMenu":
		failures.append("Expected StartMenu root node, got: %s" % start_menu.name)

	var game_session := tree.root.get_node_or_null("GameSession")
	if game_session == null:
		failures.append("GameSession autoload is missing. Start menu flow must not skip GameSession.")
		await _cleanup_tree(tree)
		await _cleanup_save_file()
		return failures

	var new_game_button := _find_button_by_text(start_menu, "New Game")
	if new_game_button == null:
		failures.append("New Game button was not found in StartMenu.")
		await _cleanup_tree(tree)
		await _cleanup_save_file()
		return failures

	new_game_button.grab_focus()
	new_game_button.emit_signal("pressed")

	var scene_changed := await _wait_for_scene_path(tree, MAIN_SCENE_PATH, MAX_SCENE_CHANGE_FRAMES)
	if not scene_changed:
		failures.append("Clicking New Game did not change scene to %s." % MAIN_SCENE_PATH)
		await _cleanup_tree(tree)
		await _cleanup_save_file()
		return failures

	if game_session == null or not is_instance_valid(game_session):
		failures.append("GameSession became invalid after New Game.")

	if game_session != null and is_instance_valid(game_session):
		if game_session.get("load_save_requested") == true:
			failures.append("New Game incorrectly left GameSession.load_save_requested = true.")
		if int(game_session.get("pending_world_seed")) == 0:
			failures.append("New Game did not prepare GameSession.pending_world_seed.")

	var main := tree.current_scene
	if main == null:
		failures.append("Current scene is null after New Game.")
		await _cleanup_tree(tree)
		await _cleanup_save_file()
		return failures

	if main.scene_file_path != MAIN_SCENE_PATH:
		failures.append("Expected current scene path %s, got %s." % [MAIN_SCENE_PATH, main.scene_file_path])

	var world := main.get_node_or_null("World")
	var player := main.get_node_or_null("Player")
	var hud := main.get_node_or_null("HUD")
	var game_manager := main.get_node_or_null("GameManager")
	var ecosystem_director := main.get_node_or_null("EcosystemDirector")
	var day_night_system := main.get_node_or_null("DayNightSystem")
	var save_system := main.get_node_or_null("SaveSystem")

	_assert_node_exists(failures, world, "World")
	_assert_node_exists(failures, player, "Player")
	_assert_node_exists(failures, hud, "HUD")
	_assert_node_exists(failures, game_manager, "GameManager")
	_assert_node_exists(failures, ecosystem_director, "EcosystemDirector")
	_assert_node_exists(failures, day_night_system, "DayNightSystem")
	_assert_node_exists(failures, save_system, "SaveSystem")

	if world == null:
		await _cleanup_tree(tree)
		await _cleanup_save_file()
		return failures

	var booted := await _wait_for_world_boot(world, tree, MAX_WORLD_BOOT_FRAMES)
	if not booted:
		failures.append("World did not finish booting.")

	if hud == null or not is_instance_valid(hud):
		failures.append("HUD is missing after world boot.")
	elif hud is CanvasItem and not hud.visible:
		failures.append("HUD exists but is not visible after world boot.")

	if player == null or not is_instance_valid(player):
		failures.append("Player is missing after world boot.")
	else:
		var player_2d := player as Node2D
		if player_2d == null:
			failures.append("Player is not a Node2D.")
		elif world.has_method("get_world_rect"):
			var world_rect: Rect2 = world.call("get_world_rect")
			if not world_rect.has_point(player_2d.global_position):
				failures.append(
					"Player starts outside world bounds. position=%s world_rect=%s"
					% [player_2d.global_position, world_rect]
				)

	if tree.paused:
		failures.append("SceneTree remained paused after booting playable session.")

	await _cleanup_tree(tree)
	await _cleanup_save_file()

	return failures


func _assert_node_exists(failures: Array[String], node: Node, node_name: String) -> void:
	if node == null or not is_instance_valid(node):
		failures.append("%s node is missing." % node_name)


func _find_button_by_text(root: Node, text: String) -> Button:
	if root is Button and root.text == text:
		return root

	for child in root.get_children():
		var result := _find_button_by_text(child, text)
		if result != null:
			return result

	return null


func _wait_for_scene_path(tree: SceneTree, expected_path: String, max_frames: int) -> bool:
	for _i in max_frames:
		await tree.process_frame

		var current := tree.current_scene
		if current != null and current.scene_file_path == expected_path:
			return true

	return false


func _wait_for_world_boot(world: Node, tree: SceneTree, max_frames: int) -> bool:
	if world == null:
		return false

	if world.has_method("is_boot_ready") and bool(world.call("is_boot_ready")):
		return true

	if world.has_signal("world_initialized"):
		var world_ready := false
		world.world_initialized.connect(func() -> void:
			world_ready = true
		, CONNECT_ONE_SHOT)

		for _i in max_frames:
			if not is_instance_valid(world):
				return false
			if world_ready:
				return true
			if world.has_method("is_boot_ready") and bool(world.call("is_boot_ready")):
				return true
			await tree.process_frame
		return world_ready or (world.has_method("is_boot_ready") and bool(world.call("is_boot_ready")))

	for _i in max_frames:
		if not is_instance_valid(world):
			return false

		if world.has_method("is_boot_ready") and bool(world.call("is_boot_ready")):
			return true

		await tree.process_frame

	return false


func _cleanup_tree(tree: SceneTree) -> void:
	if tree == null:
		return

	var current_scene := tree.current_scene
	if is_instance_valid(current_scene):
		current_scene.queue_free()

	tree.current_scene = null

	for child in tree.root.get_children():
		if child.name in ["GameSession", "EventBus", "GraphicsSettings"]:
			continue
		if child != current_scene and is_instance_valid(child):
			child.queue_free()

	for _i in 4:
		await tree.process_frame


func _cleanup_save_file() -> void:
	var save_path := "user://savegame.json"

	if FileAccess.file_exists(save_path):
		var absolute_path := ProjectSettings.globalize_path(save_path)
		var err := DirAccess.remove_absolute(absolute_path)
		if err != OK:
			push_warning("[RegressionTests] Could not remove save file %s. Error: %s" % [save_path, err])
