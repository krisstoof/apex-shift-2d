extends RefCounted

const Utils := preload("res://tests/regression/regression_test_utils.gd")
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
	if world == null:
		failures.append("World missing")
	if player == null:
		failures.append("Player missing")
	if hud == null:
		failures.append("HUD missing")
	if not failures.is_empty():
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	var inventory_screen := _get_inventory_screen(hud)
	var map_screen := _get_map_screen(hud)
	var pause_menu := _get_pause_menu(hud)
	var storage_screen := _get_storage_screen(hud)

	_assert_node_exists(failures, inventory_screen, "InventoryScreen")
	_assert_node_exists(failures, map_screen, "MapScreen")
	_assert_node_exists(failures, pause_menu, "PauseMenu")
	_assert_node_exists(failures, storage_screen, "StorageBoxScreen")
	if not failures.is_empty():
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	_assert_modal_state(failures, "initial", tree, inventory_screen, map_screen, pause_menu, storage_screen, false, false, false, false, false)
	_assert_no_conflicting_modals(failures, "initial", inventory_screen, map_screen, pause_menu, storage_screen)

	# I opens inventory.
	await _send_input_to_hud(hud, tree, _make_action_event("toggle_inventory"), "toggle_inventory")
	_assert_modal_state(failures, "after I opens inventory", tree, inventory_screen, map_screen, pause_menu, storage_screen, true, false, false, false, true)
	_assert_no_conflicting_modals(failures, "after I opens inventory", inventory_screen, map_screen, pause_menu, storage_screen)

	# I closes inventory.
	await _send_input_to_hud(hud, tree, _make_action_event("toggle_inventory"), "toggle_inventory")
	_assert_modal_state(failures, "after second I closes inventory", tree, inventory_screen, map_screen, pause_menu, storage_screen, false, false, false, false, false)

	# M opens map.
	await _send_input_to_hud(hud, tree, _make_key_event(KEY_M), "KEY_M")
	_assert_modal_state(failures, "after M opens map", tree, inventory_screen, map_screen, pause_menu, storage_screen, false, true, false, false, true)
	_assert_no_conflicting_modals(failures, "after M opens map", inventory_screen, map_screen, pause_menu, storage_screen)

	# Esc behavior with map open should follow current code and not leave conflicting modals.
	await _send_input_to_hud(hud, tree, _make_key_event(KEY_ESCAPE), "KEY_ESCAPE")
	_assert_no_conflicting_modals(failures, "after Esc with map open", inventory_screen, map_screen, pause_menu, storage_screen)

	# Explicit pause menu via Esc when no other modal exists.
	await _ensure_all_modals_closed(hud, tree, inventory_screen, map_screen, pause_menu, storage_screen)
	await _send_input_to_hud(hud, tree, _make_key_event(KEY_ESCAPE), "KEY_ESCAPE")
	if not _is_visible(pause_menu):
		failures.append("Esc did not open pause menu when no modal was active.")
	if not tree.paused:
		failures.append("Esc did not pause the game when opening pause menu.")

	# M closes pause menu and opens map.
	await _send_input_to_hud(hud, tree, _make_key_event(KEY_M), "KEY_M")
	_assert_modal_state(failures, "M closes pause and opens map", tree, inventory_screen, map_screen, pause_menu, storage_screen, false, true, false, false, true)
	_assert_no_conflicting_modals(failures, "M closes pause and opens map", inventory_screen, map_screen, pause_menu, storage_screen)

	# M closes map.
	await _send_input_to_hud(hud, tree, _make_key_event(KEY_M), "KEY_M")
	_assert_modal_state(failures, "M closes map", tree, inventory_screen, map_screen, pause_menu, storage_screen, false, false, false, false, false)

	# Open map, then I closes map and opens inventory.
	await _send_input_to_hud(hud, tree, _make_key_event(KEY_M), "KEY_M")
	await _send_input_to_hud(hud, tree, _make_action_event("toggle_inventory"), "toggle_inventory")
	_assert_modal_state(failures, "I closes map and opens inventory", tree, inventory_screen, map_screen, pause_menu, storage_screen, true, false, false, false, true)
	_assert_no_conflicting_modals(failures, "I closes map and opens inventory", inventory_screen, map_screen, pause_menu, storage_screen)

	# Close inventory.
	await _send_input_to_hud(hud, tree, _make_action_event("toggle_inventory"), "toggle_inventory")
	_assert_modal_state(failures, "inventory closed", tree, inventory_screen, map_screen, pause_menu, storage_screen, false, false, false, false, false)

	var storage_box := await _create_storage_box_for_test(tree, world, player)
	if storage_box == null:
		failures.append("Could not create storage box for UI modal stack test.")
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	# Open inventory before storage.
	await _send_input_to_hud(hud, tree, _make_action_event("toggle_inventory"), "toggle_inventory")
	_assert_modal_state(failures, "inventory before storage", tree, inventory_screen, map_screen, pause_menu, storage_screen, true, false, false, false, true)

	storage_box.call("interact", player)
	await Utils.wait_frames(tree, 6)

	_assert_modal_state(failures, "storage opens and closes inventory", tree, inventory_screen, map_screen, pause_menu, storage_screen, false, false, false, true, true)
	_assert_no_conflicting_modals(failures, "storage opens and closes inventory", inventory_screen, map_screen, pause_menu, storage_screen)

	# E closes storage.
	await _send_input_to_hud(hud, tree, _make_key_event(KEY_E), "KEY_E")
	_assert_modal_state(failures, "E closes storage", tree, inventory_screen, map_screen, pause_menu, storage_screen, false, false, false, false, false)

	# Esc closes storage.
	storage_box.call("interact", player)
	await Utils.wait_frames(tree, 6)
	_assert_modal_state(failures, "storage opened before Esc", tree, inventory_screen, map_screen, pause_menu, storage_screen, false, false, false, true, true)

	await _send_input_to_hud(hud, tree, _make_key_event(KEY_ESCAPE), "KEY_ESCAPE")
	_assert_modal_state(failures, "Esc closes storage", tree, inventory_screen, map_screen, pause_menu, storage_screen, false, false, false, false, false)

	# Esc closes inventory.
	await _send_input_to_hud(hud, tree, _make_action_event("toggle_inventory"), "toggle_inventory")
	_assert_modal_state(failures, "inventory reopened", tree, inventory_screen, map_screen, pause_menu, storage_screen, true, false, false, false, true)
	await _send_input_to_hud(hud, tree, _make_key_event(KEY_ESCAPE), "KEY_ESCAPE")
	_assert_modal_state(failures, "Esc closes inventory", tree, inventory_screen, map_screen, pause_menu, storage_screen, false, false, false, false, false)

	_assert_no_conflicting_modals(failures, "final", inventory_screen, map_screen, pause_menu, storage_screen)
	if tree.paused:
		failures.append("Tree remained paused after closing all UI screens.")

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


func _send_input_to_hud(hud: Node, tree: SceneTree, event: InputEvent, action_name: String = "") -> void:
	if hud == null:
		return
	var before_state := _snapshot_modal_state(tree, hud)
	Input.parse_input_event(event)
	await Utils.wait_frames(tree, 4)
	var after_state := _snapshot_modal_state(tree, hud)
	if before_state == after_state:
		hud.call("_unhandled_input", event)
		await Utils.wait_frames(tree, 4)


func _make_action_event(action_name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	return event


func _make_key_event(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	event.echo = false
	return event


func _snapshot_modal_state(tree: SceneTree, hud: Node) -> String:
	var inventory_screen := _get_inventory_screen(hud)
	var map_screen := _get_map_screen(hud)
	var pause_menu := _get_pause_menu(hud)
	var storage_screen := _get_storage_screen(hud)
	return "%s|%s|%s|%s|%s" % [
		_is_visible(inventory_screen),
		_is_visible(map_screen),
		_is_visible(pause_menu),
		_is_visible(storage_screen),
		tree.paused
	]


func _ensure_all_modals_closed(hud: Node, tree: SceneTree, inventory_screen: Node, map_screen: Node, pause_menu: Node, storage_screen: Node) -> void:
	if _is_visible(storage_screen) and hud.has_method("close_storage_box"):
		hud.call("close_storage_box")
	if _is_visible(inventory_screen):
		if inventory_screen.has_method("close_inventory"):
			inventory_screen.call("close_inventory")
		else:
			inventory_screen.visible = false
	if _is_visible(map_screen) and hud.has_method("_set_map_screen_open"):
		hud.call("_set_map_screen_open", false)
	if _is_visible(pause_menu) and hud.has_method("_set_pause_menu_open"):
		hud.call("_set_pause_menu_open", false)
	await Utils.wait_frames(tree, 4)


func _is_visible(node: Node) -> bool:
	if node == null:
		return false
	if node is CanvasItem:
		return (node as CanvasItem).visible
	var visible_value: Variant = node.get("visible")
	if visible_value != null:
		return bool(visible_value)
	return false


func _assert_modal_state(
	failures: Array[String],
	label: String,
	tree: SceneTree,
	inventory_screen: Node,
	map_screen: Node,
	pause_menu: Node,
	storage_screen: Node,
	expected_inventory: bool,
	expected_map: bool,
	expected_pause: bool,
	expected_storage: bool,
	expected_paused: bool
) -> void:
	var actual_inventory := _is_visible(inventory_screen)
	var actual_map := _is_visible(map_screen)
	var actual_pause := _is_visible(pause_menu)
	var actual_storage := _is_visible(storage_screen)
	var actual_paused := tree.paused

	if actual_inventory != expected_inventory:
		failures.append("%s: inventory visible expected=%s actual=%s" % [label, expected_inventory, actual_inventory])
	if actual_map != expected_map:
		failures.append("%s: map visible expected=%s actual=%s" % [label, expected_map, actual_map])
	if actual_pause != expected_pause:
		failures.append("%s: pause menu visible expected=%s actual=%s" % [label, expected_pause, actual_pause])
	if actual_storage != expected_storage:
		failures.append("%s: storage visible expected=%s actual=%s" % [label, expected_storage, actual_storage])
	if actual_paused != expected_paused:
		failures.append("%s: tree.paused expected=%s actual=%s" % [label, expected_paused, actual_paused])


func _assert_no_conflicting_modals(
	failures: Array[String],
	label: String,
	inventory_screen: Node,
	map_screen: Node,
	pause_menu: Node,
	storage_screen: Node
) -> void:
	var inventory_open := _is_visible(inventory_screen)
	var map_open := _is_visible(map_screen)
	var pause_open := _is_visible(pause_menu)
	var storage_open := _is_visible(storage_screen)

	if storage_open and inventory_open:
		failures.append("%s: storage and inventory are open at the same time." % label)
	if map_open and pause_open:
		failures.append("%s: map and pause menu are open at the same time." % label)


func _get_inventory_screen(hud: Node) -> Node:
	if hud == null:
		return null
	return hud.get_node_or_null("InventoryScreen")


func _get_map_screen(hud: Node) -> Node:
	if hud == null:
		return null
	return hud.get_node_or_null("MapScreen")


func _get_pause_menu(hud: Node) -> Node:
	if hud == null:
		return null
	return hud.get_node_or_null("PauseMenu")


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


func _create_storage_box_for_test(tree: SceneTree, world: Node, player: Node) -> Node:
	var player_inventory: Object = player.get("inventory") as Object
	if player_inventory == null:
		return null
	player_inventory.call("clear")
	player_inventory.call("add_item", "wood", 20)
	var before_count := _get_storage_box_count(tree, world)
	player.call("_craft", "storage_box")
	await Utils.wait_frames(tree, 8)
	var after_count := _get_storage_box_count(tree, world)
	if after_count <= before_count:
		return null
	return _find_latest_storage_box(tree, world)


func _get_storage_box_count(tree: SceneTree, world: Node) -> int:
	if world != null and world.has_method("get_registered_buildings_by_type"):
		return (world.call("get_registered_buildings_by_type", "storage_box") as Array).size()
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


func _assert_node_exists(failures: Array[String], node: Node, node_name: String) -> void:
	if node == null or not is_instance_valid(node):
		failures.append("%s node is missing." % node_name)

