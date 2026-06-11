extends RefCounted

const Utils := preload("res://tests/regression/regression_test_utils.gd")
const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const SAVE_PATH := "user://savegame.json"

const CRAFT_SEQUENCE := [
	"campfire",
	"spear",
	"trap",
	"wall",
	"storage_box",
	"tent",
	"torch",
	"bow"
]

const BUILDING_ITEMS := ["campfire", "trap", "wall", "storage_box", "tent"]
const FORBIDDEN_MESSAGES := ["Missing resources", "Unknown recipe", "Inventory full"]


func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var messages: Array[String] = []

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
	_connect_message_capture(tree, messages)

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
	await Utils.wait_frames(tree, 4)
	_refresh_hud(hud)
	_assert_hud_matches_inventory(failures, player, hud, ["wood", "stone", "fiber", "bone"])

	_collect_test_resource(tree, world, player, "conifer_tree", 30)
	_collect_test_resource(tree, world, player, "rock", 10)
	_collect_test_resource(tree, world, player, "bush", 20)
	_collect_test_resource(tree, world, player, "bone_drop", 1)

	if int(player_inventory.call("get_amount", "wood")) <= 0:
		failures.append("Player did not collect wood")
	if int(player_inventory.call("get_amount", "stone")) <= 0:
		failures.append("Player did not collect stone")
	if int(player_inventory.call("get_amount", "fiber")) <= 0:
		failures.append("Player did not collect fiber")

	await Utils.wait_frames(tree, 8)
	_refresh_hud(hud)
	_assert_hud_matches_inventory(failures, player, hud, ["wood", "stone", "fiber", "bone"])

	var before_building_counts: Dictionary = {}
	for item_id in BUILDING_ITEMS:
		before_building_counts[item_id] = _get_registered_building_count(world, item_id)

	for item_id in CRAFT_SEQUENCE:
		var before_inventory := _get_inventory_counts(player)
		var recipe: Dictionary = Dictionary(GAME_BALANCE.CRAFTING_COSTS.get(item_id, {}))
		if recipe.is_empty():
			failures.append("Missing crafting recipe in GameBalance for %s" % item_id)
			continue

		player.call("_craft", item_id)
		await Utils.wait_frames(tree, 6)

		var after_inventory := _get_inventory_counts(player)
		_assert_recipe_cost_paid(failures, before_inventory, after_inventory, recipe, item_id)

		if BUILDING_ITEMS.has(item_id):
			var after_count := _get_registered_building_count(world, item_id)
			var before_count := int(before_building_counts.get(item_id, 0))
			if after_count <= before_count:
				failures.append("Crafted building did not appear in world: %s" % item_id)
			before_building_counts[item_id] = after_count

		if item_id == "spear" and player.get("has_spear") != true:
			failures.append("Crafting spear did not set player.has_spear")
		if item_id == "bow" and player.get("has_bow") != true:
			failures.append("Crafting bow did not set player.has_bow")
		if item_id == "torch" and int(player_inventory.call("get_amount", "torch")) <= 0:
			failures.append("Crafting torch did not add torch to inventory")

		_refresh_hud(hud)
		_assert_hud_matches_inventory(failures, player, hud, ["wood", "stone", "fiber", "bone", "torch"])

	_assert_no_forbidden_messages(failures, messages)

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


func _connect_message_capture(tree: SceneTree, messages: Array[String]) -> void:
	var event_bus := tree.root.get_node_or_null("EventBus")
	if event_bus == null:
		return
	if event_bus.has_signal("message_posted"):
		event_bus.message_posted.connect(func(message: String) -> void:
			messages.append(message)
		)


func _collect_test_resource(tree: SceneTree, world: Node, player: Node, resource_kind: String, amount: int) -> void:
	var player_2d := player as Node2D
	if player_2d == null:
		return
	var resource := _spawn_resource_for_collection(world, resource_kind, player_2d.global_position + Vector2(48.0, 0.0), amount)
	await Utils.wait_frames(tree, 2)
	if resource != null and resource.has_method("interact"):
		resource.call("interact", player)
	await Utils.wait_frames(tree, 4)


func _spawn_resource_for_collection(world: Node, kind: String, position: Vector2, forced_amount: int) -> Node:
	var resource: Node = null
	if world.has_method("spawn_resource_for_tests"):
		resource = world.call("spawn_resource_for_tests", kind, position)
	else:
		var resource_scene := load("res://scenes/world/resource_node.tscn") as PackedScene
		resource = resource_scene.instantiate()
		world.add_child(resource)
		resource.global_position = position
		if resource.has_method("setup"):
			resource.call("setup", kind)

	if resource != null:
		resource.global_position = position
		resource.set("amount", forced_amount)
		if resource.has_method("set_visibility_culled"):
			resource.call("set_visibility_culled", true)
		else:
			resource.visible = true
	return resource


func _get_inventory_counts(player: Node) -> Dictionary:
	var inventory: Object = player.get("inventory") as Object
	return {
		"wood": int(inventory.call("get_amount", "wood")),
		"stone": int(inventory.call("get_amount", "stone")),
		"fiber": int(inventory.call("get_amount", "fiber")),
		"bone": int(inventory.call("get_amount", "bone")),
		"torch": int(inventory.call("get_amount", "torch"))
	}


func _assert_recipe_cost_paid(failures: Array[String], before: Dictionary, after: Dictionary, recipe: Dictionary, item_id: String) -> void:
	for resource_id in recipe.keys():
		var expected := int(before.get(resource_id, 0)) - int(recipe[resource_id])
		var actual := int(after.get(resource_id, 0))
		if actual != expected:
			failures.append(
				"Crafting %s did not subtract %s correctly. expected=%d actual=%d before=%d cost=%d"
				% [item_id, resource_id, expected, actual, int(before.get(resource_id, 0)), int(recipe[resource_id])]
			)


func _get_registered_building_count(world: Node, item_id: String) -> int:
	if world != null and world.has_method("get_registered_buildings_by_type"):
		return (world.call("get_registered_buildings_by_type", item_id) as Array).size()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return 0
	return tree.get_nodes_in_group(_get_building_group(item_id)).size()


func _get_building_group(item_id: String) -> String:
	match item_id:
		"campfire":
			return "campfires"
		"trap":
			return "traps"
		"wall":
			return "walls"
		"storage_box":
			return "storage_boxes"
		"tent":
			return "tents"
		_:
			return ""


func _refresh_hud(hud: Node) -> void:
	if hud == null:
		return
	if hud.has_method("_refresh_resource_panel"):
		hud.call("_refresh_resource_panel")
	if hud.has_method("_refresh_hud_text"):
		hud.call("_refresh_hud_text")


func _get_hud_resource_count(hud: Node, item_id: String) -> int:
	var path_by_item := {
		"wood": "ResourcePanel/ResourceHBox/WoodItem/CountLabel",
		"stone": "ResourcePanel/ResourceHBox/StoneItem/CountLabel",
		"fiber": "ResourcePanel/ResourceHBox/FiberItem/CountLabel",
		"bone": "ResourcePanel/ResourceHBox/BoneItem/CountLabel",
		"torch": "ResourcePanel/ResourceHBox/MeatItem/CountLabel"
	}
	if not path_by_item.has(item_id):
		return -1
	var label := hud.get_node_or_null(path_by_item[item_id]) as Label
	if label == null:
		return -1
	return int(label.text)


func _assert_hud_matches_inventory(failures: Array[String], player: Node, hud: Node, item_ids: Array[String]) -> void:
	var inventory: Object = player.get("inventory") as Object
	for item_id in item_ids:
		if item_id == "torch" and inventory.call("get_amount", "torch") <= 0:
			continue
		var inventory_amount := int(inventory.call("get_amount", item_id))
		var hud_amount := _get_hud_resource_count(hud, item_id)
		if hud_amount != inventory_amount and hud_amount != -1:
			failures.append("HUD mismatch for %s. inventory=%d hud=%d" % [item_id, inventory_amount, hud_amount])


func _assert_no_forbidden_messages(failures: Array[String], messages: Array[String]) -> void:
	for message in messages:
		for forbidden in FORBIDDEN_MESSAGES:
			if message.findn(forbidden) >= 0:
				failures.append("Unexpected system message: %s" % message)


func _assert_node_exists(failures: Array[String], node: Node, node_name: String) -> void:
	if node == null or not is_instance_valid(node):
		failures.append("%s node is missing." % node_name)
