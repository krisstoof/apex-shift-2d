extends RefCounted

const Utils := preload("res://tests/regression/regression_test_utils.gd")
const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const SAVE_PATH := "user://savegame.json"


func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []

	Utils.cleanup_save_file()
	await Utils.cleanup_context({"tree": tree, "nodes": []})

	var menu_result: Dictionary = await Utils.boot_start_menu(tree)
	if not bool(menu_result.get("ok", false)):
		return [String(menu_result.get("reason", "Could not boot start menu"))]

	var menu: Node = menu_result.get("scene") as Node
	var new_game_error: String = await _click_new_game(menu, tree)
	if new_game_error != "":
		return [new_game_error]

	if not await _wait_for_scene_path(tree, MAIN_SCENE_PATH, 180):
		return ["New Game did not switch to main.tscn"]

	var main: Node = tree.current_scene
	if not await Utils.wait_for_world_boot(main):
		return ["World did not boot"]

	await Utils.wait_frames(tree, 8)

	var world: Node = main.get_node_or_null("World")
	var player: Node = main.get_node_or_null("Player")
	var hud: Node = main.get_node_or_null("HUD")
	var save_system: Node = main.get_node_or_null("SaveSystem")

	_assert_node_exists(failures, world, "World")
	_assert_node_exists(failures, player, "Player")
	_assert_node_exists(failures, hud, "HUD")
	_assert_node_exists(failures, save_system, "SaveSystem")
	if not failures.is_empty():
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	var player_inventory: Object = player.get("inventory") as Object
	if player_inventory == null:
		return ["Player inventory is missing."]

	player_inventory.call("clear")
	player_inventory.call("add_item", "wood", 20)
	player_inventory.call("add_item", "stone", 12)
	player_inventory.call("add_item", "fiber", 12)
	player_inventory.call("add_item", "bone", 2)

	var before_storage_count: int = _get_storage_box_count(tree, world)
	player.call("_craft", "storage_box")
	await Utils.wait_frames(tree, 8)

	var after_storage_count: int = _get_storage_box_count(tree, world)
	if after_storage_count <= before_storage_count:
		failures.append("Storage box was not created by crafting.")

	var storage_box := _find_latest_storage_box(tree, world)
	if storage_box == null:
		failures.append("Storage box node was not found after crafting.")
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	if not storage_box.is_in_group("storage_boxes"):
		failures.append("Storage box is not in storage_boxes group.")
	if not storage_box.has_method("get_save_data"):
		failures.append("Storage box does not expose get_save_data().")
	if not storage_box.has_method("restore_from_data"):
		failures.append("Storage box does not expose restore_from_data().")
	if storage_box.get("inventory") == null:
		failures.append("Storage box inventory is missing.")
	if not failures.is_empty():
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	storage_box.call("interact", player)
	await Utils.wait_frames(tree, 6)

	var storage_screen := _get_storage_screen(hud)
	if storage_screen == null:
		failures.append("Storage box UI node was not found in HUD.")
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	if not storage_screen.visible:
		failures.append("Storage box UI did not become visible after storage_box.interact(player).")
	if not tree.paused:
		failures.append("Opening storage box did not pause the game.")

	var storage_inventory: Object = storage_box.get("inventory") as Object
	if storage_inventory == null:
		return ["Storage box inventory is missing after open."]

	storage_screen.call("_transfer_item", player_inventory, storage_inventory, "wood", 5, "Storage box full", "Stored")
	await Utils.wait_frames(tree, 4)
	if int(player_inventory.call("get_amount", "wood")) != 15:
		failures.append("Transfer player -> storage did not decrease player inventory correctly.")
	if int(storage_inventory.call("get_amount", "wood")) != 5:
		failures.append("Transfer player -> storage did not increase storage inventory correctly.")

	var player_before_take := int(player_inventory.call("get_amount", "wood"))
	var storage_before_take := int(storage_inventory.call("get_amount", "wood"))
	storage_screen.call("_transfer_item", storage_inventory, player_inventory, "wood", 2, "Inventory full", "Took")
	await Utils.wait_frames(tree, 4)
	if int(player_inventory.call("get_amount", "wood")) != player_before_take + 2:
		failures.append("Transfer storage -> player did not increase player inventory correctly.")
	if int(storage_inventory.call("get_amount", "wood")) != storage_before_take - 2:
		failures.append("Transfer storage -> player did not decrease storage inventory correctly.")

	_assert_no_item_loss_when_destination_full(failures, storage_screen, player_inventory, storage_inventory, tree)
	_assert_partial_transfer(failures, storage_screen, player_inventory, storage_inventory, tree)

	if hud.has_method("close_storage_box"):
		hud.call("close_storage_box")
	elif storage_screen.has_method("close_storage_box"):
		storage_screen.call("close_storage_box")
	await Utils.wait_frames(tree, 4)

	if storage_screen.visible:
		failures.append("Storage box UI remained visible after close.")
	if tree.paused:
		failures.append("Closing storage box did not unpause the game.")

	storage_inventory.call("clear")
	storage_inventory.call("add_item", "wood", 6)
	storage_inventory.call("add_item", "stone", 4)

	var expected_storage_position: Vector2 = (storage_box as Node2D).global_position
	var expected_storage_inventory: Dictionary = Dictionary(storage_inventory.call("to_save_data")).duplicate(true)

	save_system.call("save_game")
	await Utils.wait_frames(tree, 6)

	storage_inventory.call("clear")
	storage_inventory.call("add_item", "fiber", 9)
	(storage_box as Node2D).global_position += Vector2(333, 222)

	save_system.call("load_game")
	await Utils.wait_frames(tree, 16)

	var loaded_storage_box := _find_latest_storage_box(tree, world)
	if loaded_storage_box == null:
		failures.append("Storage box missing after load.")
	else:
		var loaded_pos: Vector2 = (loaded_storage_box as Node2D).global_position
		if loaded_pos.distance_to(expected_storage_position) > 2.0:
			failures.append("Storage box position was not restored. expected=%s actual=%s" % [expected_storage_position, loaded_pos])

		var loaded_inventory: Dictionary = Dictionary((loaded_storage_box.get("inventory") as Object).call("to_save_data"))
		if JSON.stringify(loaded_inventory) != JSON.stringify(expected_storage_inventory):
			failures.append("Storage box inventory was not restored. expected=%s actual=%s" % [JSON.stringify(expected_storage_inventory), JSON.stringify(loaded_inventory)])

		if int((loaded_storage_box.get("inventory") as Object).call("get_amount", "wood")) != 6:
			failures.append("Storage box wood amount was not restored.")
		if int((loaded_storage_box.get("inventory") as Object).call("get_amount", "stone")) != 4:
			failures.append("Storage box stone amount was not restored.")
		if int((loaded_storage_box.get("inventory") as Object).call("get_amount", "fiber")) != 0:
			failures.append("Storage box kept mutated fiber state after load.")

	await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
	Utils.cleanup_save_file()
	return failures


func _click_new_game(menu: Node, tree: SceneTree) -> String:
	if menu == null:
		return "Start menu node missing"
	var new_game_button: Button = Utils.find_button_by_text_recursive(menu, "New Game")
	if new_game_button == null:
		return "New Game button was not found"
	new_game_button.emit_signal("pressed")
	await Utils.wait_frames(tree, 2)
	return ""


func _wait_for_scene_path(tree: SceneTree, expected_path: String, max_frames: int) -> bool:
	for _i in range(max_frames):
		await tree.process_frame
		var current := tree.current_scene
		if current != null and current.scene_file_path == expected_path:
			return true
	return false


func _get_storage_box_count(tree: SceneTree, world: Node) -> int:
	if world != null and world.has_method("get_registered_buildings_by_type"):
		var registered: Array = Array(world.call("get_registered_buildings_by_type", "storage_box"))
		return registered.size()
	return tree.get_nodes_in_group("storage_boxes").size()


func _find_latest_storage_box(tree: SceneTree, world: Node) -> Node:
	if world != null and world.has_method("get_registered_buildings_by_type"):
		var registered: Array = Array(world.call("get_registered_buildings_by_type", "storage_box"))
		for i in range(registered.size() - 1, -1, -1):
			var candidate := registered[i] as Node
			if candidate != null and is_instance_valid(candidate):
				return candidate

	var boxes := tree.get_nodes_in_group("storage_boxes")
	for i in range(boxes.size() - 1, -1, -1):
		var candidate := boxes[i] as Node
		if candidate != null and is_instance_valid(candidate):
			return candidate
	return null


func _get_storage_screen(hud: Node) -> Node:
	if hud == null:
		return null
	var direct := hud.get_node_or_null("StorageBoxScreen")
	if direct != null:
		return direct
	var candidates := hud.find_children("*Storage*", "Control", true, false)
	for candidate in candidates:
		if candidate != null and candidate.has_method("open_storage_box"):
			return candidate
		if candidate != null and candidate.has_method("_transfer_item"):
			return candidate
	return null


func _assert_no_item_loss_when_destination_full(
	failures: Array[String],
	storage_screen: Node,
	player_inventory: Object,
	storage_inventory: Object,
	tree: SceneTree
) -> void:
	player_inventory.call("clear")
	storage_inventory.call("clear")
	player_inventory.call("add_item", "wood", 5)
	for item_id in ["stone", "fiber", "meat", "bone", "torch"]:
		for _i in range(3):
			storage_inventory.call("add_item", item_id, 20)

	var total_before := int(player_inventory.call("get_amount", "wood")) + int(storage_inventory.call("get_amount", "wood"))
	var player_before := int(player_inventory.call("get_amount", "wood"))
	var storage_before := int(storage_inventory.call("get_amount", "wood"))

	storage_screen.call("_transfer_item", player_inventory, storage_inventory, "wood", 5, "Storage box full", "Stored")
	await Utils.wait_frames(tree, 4)

	var total_after := int(player_inventory.call("get_amount", "wood")) + int(storage_inventory.call("get_amount", "wood"))
	if total_after != total_before:
		failures.append("Item disappeared during transfer to full storage.")
	if int(player_inventory.call("get_amount", "wood")) != player_before:
		failures.append("Player inventory changed even though storage destination was full.")
	if int(storage_inventory.call("get_amount", "wood")) != storage_before:
		failures.append("Storage inventory changed even though storage destination was full.")


func _assert_partial_transfer(
	failures: Array[String],
	storage_screen: Node,
	player_inventory: Object,
	storage_inventory: Object,
	tree: SceneTree
) -> void:
	player_inventory.call("clear")
	storage_inventory.call("clear")

	storage_inventory.call("add_item", "wood", 18)
	for item_id in ["stone", "fiber", "meat", "bone", "torch"]:
		for _i in range(3):
			storage_inventory.call("add_item", item_id, 20)

	player_inventory.call("add_item", "wood", 5)

	var total_before := int(player_inventory.call("get_amount", "wood")) + int(storage_inventory.call("get_amount", "wood"))
	storage_screen.call("_transfer_item", player_inventory, storage_inventory, "wood", 5, "Storage box full", "Stored")
	await Utils.wait_frames(tree, 4)

	var player_after := int(player_inventory.call("get_amount", "wood"))
	var storage_after := int(storage_inventory.call("get_amount", "wood"))
	var total_after := player_after + storage_after

	if total_after != total_before:
		failures.append("Item count changed during partial transfer.")
	if storage_after != 20:
		failures.append("Partial transfer did not fill storage wood stack to 20. actual=%d" % storage_after)
	if player_after != 3:
		failures.append("Partial transfer removed wrong amount from player. expected=3 actual=%d" % player_after)


func _assert_node_exists(failures: Array[String], node: Node, node_name: String) -> void:
	if node == null or not is_instance_valid(node):
		failures.append("%s node is missing." % node_name)

