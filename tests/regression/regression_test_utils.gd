extends RefCounted

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const START_MENU_SCENE_PATH := "res://scenes/ui/start_menu.tscn"
const SAVE_PATH := "user://savegame.json"


static func boot_scene(scene_path: String, tree: SceneTree) -> Dictionary:
	if tree == null:
		return {
			"ok": false,
			"reason": "SceneTree is not available"
		}

	var error := tree.change_scene_to_file(scene_path)
	if error != OK:
		return {
			"ok": false,
			"reason": "Failed to change scene to %s (error %d)" % [scene_path, error]
		}

	await tree.process_frame
	await tree.process_frame

	var scene: Node = tree.current_scene
	if scene == null:
		return {
			"ok": false,
			"reason": "Current scene was not created for %s" % scene_path
		}

	return {
		"ok": true,
		"tree": tree,
		"scene": scene,
		"nodes": [scene]
	}


static func boot_main(tree: SceneTree, options := {}) -> Dictionary:
	var scene_result := await boot_scene(MAIN_SCENE_PATH, tree)
	if not bool(scene_result.get("ok", false)):
		return scene_result

	var main := scene_result.get("scene") as Node
	if main == null:
		return {
			"ok": false,
			"reason": "Main scene could not be resolved after boot"
		}

	var integration_test_mode := bool(options.get("integration_test_mode", false))
	var world := main.get_node_or_null("World")
	if world != null and integration_test_mode and world.has_method("enable_integration_test_mode"):
		world.call("enable_integration_test_mode")

	if not await wait_for_world_boot(main):
		return {
			"ok": false,
			"reason": "World did not become boot ready"
		}

	await wait_frames(tree, 2)
	return {
		"ok": true,
		"tree": tree,
		"main": main,
		"nodes": [main]
	}


static func boot_start_menu(tree: SceneTree) -> Dictionary:
	return await boot_scene(START_MENU_SCENE_PATH, tree)


static func cleanup_context(context: Dictionary) -> void:
	var tree := context.get("tree") as SceneTree
	if tree == null:
		return

	var nodes: Array = context.get("nodes", [])
	for node in nodes:
		if is_instance_valid(node):
			var node_ref := node as Node
			if node_ref != null:
				node_ref.queue_free()

	if is_instance_valid(tree.current_scene):
		tree.current_scene.queue_free()
	tree.current_scene = null
	await wait_frames(tree, 4)


static func cleanup_save_file() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		if err != OK:
			push_warning("[RegressionTests] Could not remove save file: %s, error: %s" % [SAVE_PATH, err])


static func wait_frames(tree: SceneTree, count: int) -> void:
	if tree == null:
		return
	for _i in range(max(count, 0)):
		await tree.process_frame


static func wait_for_world_boot(main: Node) -> bool:
	if main == null:
		return false
	var world := find_world(main)
	if world == null:
		return false
	if world.has_method("is_boot_ready") and bool(world.call("is_boot_ready")):
		return true
	if world.has_signal("world_initialized"):
		await world.world_initialized
		return true
	await wait_frames(main.get_tree(), 6)
	if world.has_method("is_boot_ready"):
		return bool(world.call("is_boot_ready"))
	return true


static func find_main(tree: SceneTree) -> Node:
	if tree == null:
		return null
	return tree.current_scene


static func find_world(main_or_tree: Variant) -> Node:
	if main_or_tree is SceneTree:
		var tree := main_or_tree as SceneTree
		if tree == null:
			return null
		return tree.current_scene.get_node_or_null("World") if tree.current_scene != null else null
	if main_or_tree is Node:
		var main := main_or_tree as Node
		return main.get_node_or_null("World")
	return null


static func find_player(main: Node) -> Node:
	if main == null:
		return null
	return main.get_node_or_null("Player")


static func find_button_by_text_recursive(root: Node, text: String) -> Button:
	if root == null:
		return null

	if root is Button and root.text == text:
		return root

	for child in root.get_children():
		var result := find_button_by_text_recursive(child, text)
		if result != null:
			return result

	return null


static func assert_node_exists(node: Node, message: String) -> String:
	if node == null or not is_instance_valid(node):
		return message
	return ""


static func save_game(main: Node) -> String:
	var save_system := _find_save_system(main)
	if save_system == null:
		return "SaveSystem node missing"
	if not save_system.has_method("save_game"):
		return "SaveSystem.save_game() is missing"
	save_system.call("save_game")
	await wait_frames(main.get_tree(), 2)
	if FileAccess.file_exists(SAVE_PATH):
		return ""
	return "Save file was not created after save_game()"


static func load_or_continue_from_menu(menu: Node, tree: SceneTree) -> String:
	if menu == null:
		return "Start menu node missing"
	var game_session := tree.root.get_node_or_null("GameSession")
	if game_session == null:
		return "GameSession node missing"
	if game_session.has_method("request_continue"):
		game_session.call("request_continue")
	var load_button := _find_button_by_text(menu, ["Continue", "Load Save"])
	if load_button != null:
		load_button.emit_signal("pressed")
		return ""
	var continue_button: Button = menu.get("continue_button") as Button
	if continue_button is Button:
		continue_button.emit_signal("pressed")
		return ""
	var load_button_direct: Button = menu.get("load_button") as Button
	if load_button_direct is Button:
		load_button_direct.emit_signal("pressed")
		return ""
	return "Continue button was not found"


static func click_continue_from_menu(menu: Node, tree: SceneTree) -> String:
	if menu == null:
		return "Start menu node missing"

	var continue_button := find_button_by_text_recursive(menu, "Continue")
	if continue_button == null:
		return "Continue button was not found"

	if continue_button.disabled:
		return "Continue button is disabled even though save should exist"

	continue_button.emit_signal("pressed")
	await wait_frames(tree, 2)
	return ""


static func _find_save_system(main: Node) -> Node:
	if main == null:
		return null
	return main.get_node_or_null("SaveSystem")


static func _find_button_by_text(menu: Node, labels: Array[String]) -> Button:
	for child in menu.get_children():
		var button := child as Button
		if button == null:
			continue
		for label in labels:
			if button.text == label:
				return button
	return null
