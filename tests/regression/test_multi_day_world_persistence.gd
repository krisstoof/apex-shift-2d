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
	var new_game_error: String = await _click_button(menu, "New Game", tree)
	if new_game_error != "":
		return [new_game_error]

	if not await _wait_for_scene_path(tree, MAIN_SCENE_PATH, 180):
		return ["New Game did not switch to main.tscn"]

	var main := tree.current_scene
	if main == null:
		return ["Current scene is null after New Game"]

	if not await Utils.wait_for_world_boot(main):
		return ["World did not boot"]

	await Utils.wait_frames(tree, 12)

	var world: Node = main.get_node_or_null("World")
	var player: Node = main.get_node_or_null("Player")
	var hud: Node = main.get_node_or_null("HUD")
	var day_night_system: Node = main.get_node_or_null("DayNightSystem")
	var save_system: Node = main.get_node_or_null("SaveSystem")

	_assert_node_exists(failures, world, "World")
	_assert_node_exists(failures, player, "Player")
	_assert_node_exists(failures, hud, "HUD")
	_assert_node_exists(failures, day_night_system, "DayNightSystem")
	_assert_node_exists(failures, save_system, "SaveSystem")
	if not failures.is_empty():
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	var player_inventory := player.get("inventory") as Object
	if player_inventory == null:
		return ["Player inventory is missing."]

	player_inventory.call("clear")
	player_inventory.call("add_item", "wood", 60)
	player_inventory.call("add_item", "stone", 30)
	player_inventory.call("add_item", "fiber", 40)
	player_inventory.call("add_item", "bone", 5)
	player_inventory.call("add_item", "meat", 5)

	var world_rect: Rect2 = world.call("get_world_rect")
	var player_2d := player as Node2D
	if player_2d != null:
		player_2d.global_position = world_rect.get_center()

	var base_pos: Vector2 = player_2d.global_position + Vector2(160.0, 0.0)
	var test_tree: Node = _spawn_test_resource(world, "conifer_tree", base_pos + Vector2(0.0, 0.0))
	var test_rock: Node = _spawn_test_resource(world, "rock", base_pos + Vector2(80.0, 0.0))
	var test_bush: Node = _spawn_test_resource(world, "bush", base_pos + Vector2(160.0, 0.0))
	await Utils.wait_frames(tree, 6)

	if test_tree == null or test_rock == null or test_bush == null:
		return ["Could not spawn deterministic test resources."]

	test_tree.call("interact", player)
	test_rock.call("interact", player)
	test_bush.call("interact", player)
	await Utils.wait_frames(tree, 6)

	if bool(test_tree.get("can_be_harvested")):
		failures.append("Tracked resource remained harvestable immediately after being harvested.")
	if int(test_tree.get("growth_stage")) != 0:
		failures.append("Tracked resource did not enter harvested growth stage.")

	var meat_drop: Node = world.call("spawn_meat_drop_for_animal", "grazer", player_2d.global_position + Vector2(220.0, 80.0)) if world.has_method("spawn_meat_drop_for_animal") else null
	await Utils.wait_frames(tree, 4)
	if meat_drop == null:
		failures.append("Could not create meat drop for persistence test.")
	else:
		meat_drop.add_to_group("meat")

	var building_items: Array[String] = ["campfire", "trap", "wall", "tent", "storage_box"]
	for item_id in building_items:
		var before_count: int = _get_building_count(tree, world, item_id)
		player.call("_craft", item_id)
		await Utils.wait_frames(tree, 8)
		var after_count: int = _get_building_count(tree, world, item_id)
		if after_count <= before_count:
			failures.append("Crafting %s did not create building." % item_id)

	var storage_box := _find_latest_storage_box(tree, world)
	if storage_box == null:
		failures.append("Storage box missing after crafting.")
	else:
		storage_box.inventory.clear()
		storage_box.inventory.add_item("wood", 9)
		storage_box.inventory.add_item("stone", 4)
		storage_box.inventory.add_item("fiber", 6)

	if world.has_method("force_spawn_small_prey_for_tests"):
		world.call("force_spawn_small_prey_for_tests", 2, player_2d.global_position + Vector2(400.0, -80.0))
	if world.has_method("force_spawn_grazers_for_tests"):
		world.call("force_spawn_grazers_for_tests", 2, player_2d.global_position + Vector2(-260.0, 140.0))
	if world.has_method("force_spawn_varnaks_for_tests"):
		world.call("force_spawn_varnaks_for_tests", 4, player_2d.global_position + Vector2(320.0, -200.0))
	await Utils.wait_frames(tree, 8)

	var start_day: int = int(day_night_system.call("get_day"))
	for i in range(3):
		if not day_night_system.has_method("debug_next_day"):
			failures.append("DayNightSystem.debug_next_day() missing.")
			return failures
		day_night_system.call("debug_next_day")
		await Utils.wait_frames(tree, 8)
		if world.has_method("advance_resource_growth_days"):
			world.call("advance_resource_growth_days", 1.0)

	var expected_day: int = start_day + 3
	var actual_day: int = int(day_night_system.call("get_day"))
	if actual_day != expected_day:
		failures.append("Day did not advance correctly. expected=%d actual=%d" % [expected_day, actual_day])

	_refresh_hud_for_test(hud, tree)
	_assert_hud_day(failures, hud, expected_day)

	if bool(test_tree.get("can_be_harvested")) != true:
		failures.append("Tracked resource is not harvestable after 3 days of regrowth.")
	if int(test_tree.get("growth_stage")) <= 0:
		failures.append("Tracked resource growth_stage did not advance after 3 days.")
	if test_tree.has_method("is_player_interactable") and bool(test_tree.call("is_player_interactable")) != true:
		failures.append("Tracked resource is not player-interactable after full regrowth.")

	_assert_creatures_inside_world(failures, tree, world, "before save")
	_assert_varnak_population_limit(failures, world, "before save")

	if not failures.is_empty():
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	var tracked_resource_state: Dictionary = Dictionary(test_tree.call("get_save_data")).duplicate(true) if test_tree.has_method("get_save_data") else {}
	var expected_world_state := {
		"day": int(day_night_system.call("get_day")),
		"world_seed": int(world.call("get_world_seed")) if world.has_method("get_world_seed") else 0,
		"building_counts": _capture_building_counts(tree, world),
		"storage": _capture_storage_state(tree, world),
		"varnak_status": Dictionary(world.call("get_varnak_population_status")) if world.has_method("get_varnak_population_status") else {},
		"tracked_resource": tracked_resource_state,
		"meat_count": _get_meat_count(tree, world)
	}

	save_system.call("save_game")
	await Utils.wait_frames(tree, 6)
	if not FileAccess.file_exists(SAVE_PATH):
		failures.append("Save file was not created.")
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	player_inventory.call("clear")
	var storage_box_after_save := _find_latest_storage_box(tree, world)
	if storage_box_after_save != null:
		storage_box_after_save.inventory.clear()
		storage_box_after_save.inventory.add_item("wood", 1)
	var buildings_to_mutate: Array = world.call("get_registered_buildings_by_type", "wall") if world.has_method("get_registered_buildings_by_type") else tree.get_nodes_in_group("walls")
	if not buildings_to_mutate.is_empty():
		var wall := buildings_to_mutate[0] as Node
		if wall != null and is_instance_valid(wall):
			wall.queue_free()
	await Utils.wait_frames(tree, 6)

	save_system.call("load_game")
	await Utils.wait_frames(tree, 24)

	if world.has_method("is_boot_ready") and not bool(world.call("is_boot_ready")):
		failures.append("World is not boot-ready after load.")

	_assert_world_state_after_load(failures, tree, world, day_night_system, expected_world_state)
	_refresh_hud_for_test(hud, tree)
	_assert_hud_day(failures, hud, expected_day)
	_assert_storage_after_load(failures, tree, world)
	_assert_meat_drop_exists(failures, tree, world)
	_assert_creatures_inside_world(failures, tree, world, "after load")
	_assert_varnak_population_limit(failures, world, "after load")

	await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
	Utils.cleanup_save_file()
	return failures


func _spawn_test_resource(world: Node, kind: String, position: Vector2) -> Node:
	if world == null:
		return null
	if world.has_method("spawn_resource_for_tests"):
		var resource := world.call("spawn_resource_for_tests", kind, position) as Node
		if resource != null:
			resource.global_position = position
		return resource

	var scene := load("res://scenes/world/resource_node.tscn") as PackedScene
	if scene == null:
		return null
	var node := scene.instantiate() as Node
	if node == null:
		return null
	world.add_child(node)
	if node is Node2D:
		(node as Node2D).global_position = position
	if node.has_method("setup"):
		node.call("setup", kind)
	if world.has_method("register_resource_node"):
		world.call("register_resource_node", node)
	return node


func _assert_node_exists(failures: Array[String], node: Node, node_name: String) -> void:
	if node == null or not is_instance_valid(node):
		failures.append("%s node is missing." % node_name)


func _get_building_count(tree: SceneTree, world: Node, building_type: String) -> int:
	if world != null and world.has_method("get_registered_buildings_by_type"):
		return (world.call("get_registered_buildings_by_type", building_type) as Array).size()
	var group_by_type := {
		"campfire": "campfires",
		"trap": "traps",
		"wall": "walls",
		"tent": "tents",
		"storage_box": "storage_boxes"
	}
	var group_name := str(group_by_type.get(building_type, ""))
	if group_name.is_empty():
		return 0
	return tree.get_nodes_in_group(group_name).size()


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


func _capture_building_counts(tree: SceneTree, world: Node) -> Dictionary:
	var result: Dictionary = {}
	for kind in ["campfire", "trap", "wall", "tent", "storage_box"]:
		result[kind] = _get_building_count(tree, world, kind)
	return result


func _capture_storage_state(tree: SceneTree, world: Node) -> Dictionary:
	var storage_box := _find_latest_storage_box(tree, world)
	if storage_box == null:
		return {}
	return {
		"position": (storage_box as Node2D).global_position if storage_box is Node2D else Vector2.ZERO,
		"inventory": Dictionary(storage_box.inventory.to_save_data()).duplicate(true)
	}


func _get_meat_count(tree: SceneTree, world: Node) -> int:
	var count := 0
	for node in tree.get_nodes_in_group("meat"):
		if is_instance_valid(node):
			count += 1
	if count <= 0 and world != null and world.has_method("get_meat_in_rect"):
		var world_rect: Rect2 = world.call("get_world_rect")
		var meat_nodes: Array = world.call("get_meat_in_rect", world_rect)
		for node in meat_nodes:
			if is_instance_valid(node):
				count += 1
	return count


func _assert_world_state_after_load(
	failures: Array[String],
	tree: SceneTree,
	world: Node,
	day_night_system: Node,
	expected: Dictionary
) -> void:
	var expected_day: int = int(expected.get("day", 0))
	var actual_day: int = int(day_night_system.call("get_day"))
	if actual_day != expected_day:
		failures.append("Day mismatch after load. expected=%d actual=%d" % [expected_day, actual_day])

	if world.has_method("get_world_seed"):
		var expected_seed: int = int(expected.get("world_seed", 0))
		var actual_seed: int = int(world.call("get_world_seed"))
		if expected_seed != 0 and actual_seed != expected_seed:
			failures.append("World seed mismatch after load. expected=%d actual=%d" % [expected_seed, actual_seed])

	var expected_counts: Dictionary = Dictionary(expected.get("building_counts", {}))
	var actual_counts: Dictionary = _capture_building_counts(tree, world)
	for kind in expected_counts.keys():
		var expected_count: int = int(expected_counts[kind])
		var actual_count: int = int(actual_counts.get(kind, 0))
		if actual_count < expected_count:
			failures.append("Building count mismatch after load for %s. expected at least=%d actual=%d" % [kind, expected_count, actual_count])


func _assert_storage_after_load(failures: Array[String], tree: SceneTree, world: Node) -> void:
	var storage_box := _find_latest_storage_box(tree, world)
	if storage_box == null:
		failures.append("Storage box missing after load.")
		return
	if int(storage_box.inventory.get_amount("wood")) != 9:
		failures.append("Storage box wood amount mismatch after load.")
	if int(storage_box.inventory.get_amount("stone")) != 4:
		failures.append("Storage box stone amount mismatch after load.")
	if int(storage_box.inventory.get_amount("fiber")) != 6:
		failures.append("Storage box fiber amount mismatch after load.")


func _assert_meat_drop_exists(failures: Array[String], tree: SceneTree, world: Node) -> void:
	var meat_nodes := tree.get_nodes_in_group("meat")
	if meat_nodes.is_empty() and world != null and world.has_method("get_meat_in_rect"):
		var world_rect: Rect2 = world.call("get_world_rect")
		meat_nodes = world.call("get_meat_in_rect", world_rect)
	var valid_meat_count := 0
	for node in meat_nodes:
		if is_instance_valid(node):
			valid_meat_count += 1
	if valid_meat_count <= 0:
		failures.append("Meat drop is missing after load.")


func _assert_creatures_inside_world(
	failures: Array[String],
	tree: SceneTree,
	world: Node,
	label: String
) -> void:
	var world_rect: Rect2 = world.call("get_world_rect")
	for group_name in ["small_prey", "grazer", "varnak"]:
		var nodes := tree.get_nodes_in_group(group_name)
		for node in nodes:
			if not is_instance_valid(node):
				continue
			var node_2d := node as Node2D
			if node_2d == null:
				continue
			if not world_rect.has_point(node_2d.global_position):
				failures.append("%s: creature from group %s is out of world bounds. position=%s" % [label, group_name, node_2d.global_position])


func _assert_varnak_population_limit(failures: Array[String], world: Node, label: String) -> void:
	if world == null or not world.has_method("get_varnak_population_status"):
		return
	var status: Dictionary = Dictionary(world.call("get_varnak_population_status"))
	var live := int(status.get("live", 0))
	var max_count := int(status.get("max", 0))
	if max_count > 0 and live > max_count:
		failures.append("%s: Varnak population exceeds max. live=%d max=%d status=%s" % [label, live, max_count, JSON.stringify(status)])


func _assert_hud_day(failures: Array[String], hud: Node, expected_day: int) -> void:
	var stats_label := hud.get_node_or_null("Panel/StatsLabel") as Label
	if stats_label == null:
		failures.append("HUD StatsLabel missing while checking day.")
		return
	var text := stats_label.text
	if text.find("Day: %d" % expected_day) < 0:
		failures.append("HUD does not show expected day. expected=%d text=%s" % [expected_day, text])


func _refresh_hud_for_test(hud: Node, tree: SceneTree) -> void:
	if hud == null:
		return
	if hud.has_method("_refresh_resource_panel"):
		hud.call("_refresh_resource_panel")
	if hud.has_method("_refresh_hud_text"):
		hud.call("_refresh_hud_text")
	await Utils.wait_frames(tree, 4)


func _click_button(menu: Node, label: String, tree: SceneTree) -> String:
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


func _wait_for_scene_path(tree: SceneTree, expected_path: String, max_frames: int) -> bool:
	for _i in range(max_frames):
		var scene := tree.current_scene
		if scene != null and scene.scene_file_path == expected_path:
			return true
		await Utils.wait_frames(tree, 1)
	return false
