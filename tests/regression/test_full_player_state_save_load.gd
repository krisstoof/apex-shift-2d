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
	if main == null:
		return ["Current scene is null after New Game"]

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

	var player_2d := player as Node2D
	if player_2d == null:
		return ["Player is not Node2D."]
	var safe_position := _get_safe_test_position(world, player)
	player_2d.global_position = safe_position

	var player_inventory: Object = player.get("inventory") as Object
	if player_inventory == null:
		return ["Player inventory is missing."]
	player_inventory.call("clear")
	player_inventory.call("add_item", "wood", 7)
	player_inventory.call("add_item", "stone", 3)
	player_inventory.call("add_item", "fiber", 5)
	player_inventory.call("add_item", "meat", 2)
	player_inventory.call("add_item", "bone", 1)

	player.set("has_spear", true)
	player.set("has_bow", true)
	player.set("torch_active", true)
	player.set("torch_remaining_seconds", 22.5)
	player.stats.health = 64.0
	player.stats.hunger = 41.0
	player.stats.stamina = 73.0
	player.stats.rest = 52.0

	var expected_state := _capture_player_state(player)
	_refresh_hud_for_test(hud, tree)
	_assert_hud_after_load(failures, hud, true)
	_assert_hud_resource_count(failures, hud, "wood", 7)
	_assert_hud_resource_count(failures, hud, "stone", 3)
	_assert_hud_resource_count(failures, hud, "fiber", 5)
	_assert_hud_resource_count(failures, hud, "meat", 2)
	_assert_hud_resource_count(failures, hud, "bone", 1)

	if save_system == null or not save_system.has_method("save_game"):
		return ["SaveSystem.save_game() is missing."]
	save_system.call("save_game")
	await Utils.wait_frames(tree, 6)
	if not FileAccess.file_exists(SAVE_PATH):
		return ["Save file was not created after save_game()."]

	player_2d.global_position += Vector2(300.0, 180.0)
	player.stats.health = 12.0
	player.stats.hunger = 8.0
	player.stats.stamina = 5.0
	player.stats.rest = 9.0
	player_inventory.call("clear")
	player_inventory.call("add_item", "wood", 1)
	player.set("has_spear", false)
	player.set("has_bow", false)
	player.set("torch_active", false)
	player.set("torch_remaining_seconds", 0.0)

	save_system.call("load_game")
	await Utils.wait_frames(tree, 16)
	_refresh_hud_for_test(hud, tree)

	_assert_player_state_matches(failures, player, expected_state, "restored active torch state")
	_assert_hud_after_load(failures, hud, true)
	_assert_hud_resource_count(failures, hud, "wood", 7)
	_assert_hud_resource_count(failures, hud, "stone", 3)
	_assert_hud_resource_count(failures, hud, "fiber", 5)
	_assert_hud_resource_count(failures, hud, "meat", 2)
	_assert_hud_resource_count(failures, hud, "bone", 1)

	player.set("torch_active", false)
	player.set("torch_remaining_seconds", 0.0)
	save_system.call("save_game")
	await Utils.wait_frames(tree, 6)

	player.set("torch_active", true)
	player.set("torch_remaining_seconds", 12.0)
	save_system.call("load_game")
	await Utils.wait_frames(tree, 16)
	_refresh_hud_for_test(hud, tree)

	var inactive_state := _capture_player_state(player)
	if bool(inactive_state.get("torch_active", true)) == true:
		failures.append("Inactive torch was restored as active.")
	if absf(float(inactive_state.get("torch_remaining_seconds", -1.0))) > 0.01:
		failures.append("Inactive torch remaining time was not restored to 0.")
	_assert_hud_after_load(failures, hud, false)

	await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
	Utils.cleanup_save_file()
	return failures


func _capture_player_state(player: Node) -> Dictionary:
	var player_2d := player as Node2D
	var inventory: Object = player.get("inventory") as Object
	return {
		"position": player_2d.global_position if player_2d != null else Vector2.ZERO,
		"health": float(player.stats.health),
		"hunger": float(player.stats.hunger),
		"stamina": float(player.stats.stamina),
		"rest": float(player.stats.rest),
		"inventory": Dictionary(inventory.call("to_save_data")).duplicate(true) if inventory != null else {},
		"has_spear": player.get("has_spear") == true,
		"has_bow": player.get("has_bow") == true,
		"torch_active": player.get("torch_active") == true,
		"torch_remaining_seconds": float(player.get("torch_remaining_seconds"))
	}


func _assert_player_state_matches(failures: Array[String], player: Node, expected: Dictionary, label: String) -> void:
	var actual := _capture_player_state(player)
	var expected_position := Vector2(expected.get("position", Vector2.ZERO))
	var actual_position := Vector2(actual.get("position", Vector2.ZERO))
	if actual_position.distance_to(expected_position) > 2.0:
		failures.append("%s: position mismatch expected=%s actual=%s" % [label, expected_position, actual_position])
	_assert_float_close(failures, actual.get("health", 0.0), expected.get("health", 0.0), 0.01, "%s: health" % label)
	_assert_float_close(failures, actual.get("hunger", 0.0), expected.get("hunger", 0.0), 0.01, "%s: hunger" % label)
	_assert_float_close(failures, actual.get("stamina", 0.0), expected.get("stamina", 0.0), 0.01, "%s: stamina" % label)
	_assert_float_close(failures, actual.get("rest", 0.0), expected.get("rest", 0.0), 0.01, "%s: rest" % label)

	var expected_inventory := Dictionary(expected.get("inventory", {}))
	var actual_inventory := Dictionary(actual.get("inventory", {}))
	if JSON.stringify(actual_inventory) != JSON.stringify(expected_inventory):
		failures.append("%s: inventory mismatch expected=%s actual=%s" % [
			label,
			JSON.stringify(expected_inventory),
			JSON.stringify(actual_inventory)
		])
	if bool(actual.get("has_spear", false)) != bool(expected.get("has_spear", false)):
		failures.append("%s: has_spear mismatch expected=%s actual=%s" % [label, expected.get("has_spear", false), actual.get("has_spear", false)])
	if bool(actual.get("has_bow", false)) != bool(expected.get("has_bow", false)):
		failures.append("%s: has_bow mismatch expected=%s actual=%s" % [label, expected.get("has_bow", false), actual.get("has_bow", false)])
	if bool(actual.get("torch_active", false)) != bool(expected.get("torch_active", false)):
		failures.append("%s: torch_active mismatch expected=%s actual=%s" % [label, expected.get("torch_active", false), actual.get("torch_active", false)])
	_assert_float_close(
		failures,
		actual.get("torch_remaining_seconds", 0.0),
		expected.get("torch_remaining_seconds", 0.0),
		0.05,
		"%s: torch_remaining_seconds" % label
	)


func _assert_float_close(failures: Array[String], actual: Variant, expected: Variant, tolerance: float, label: String) -> void:
	if absf(float(actual) - float(expected)) > tolerance:
		failures.append("%s mismatch expected=%.3f actual=%.3f" % [label, float(expected), float(actual)])


func _get_safe_test_position(world: Node, player: Node) -> Vector2:
	var world_rect := Rect2(Vector2.ZERO, Vector2(1024.0, 768.0))
	if world != null and world.has_method("get_world_rect"):
		world_rect = Rect2(world.call("get_world_rect"))
	var safe_position := world_rect.position + world_rect.size * 0.5
	if world != null and world.has_method("get_safe_player_start_position"):
		safe_position = Vector2(world.call("get_safe_player_start_position"))
		if not world_rect.has_point(safe_position):
			safe_position = world_rect.get_center()
	if player is Node2D and not world_rect.has_point(safe_position):
		safe_position = world_rect.get_center()
	return safe_position


func _refresh_hud_for_test(hud: Node, tree: SceneTree) -> void:
	if hud == null:
		return
	if hud.has_method("_refresh_resource_panel"):
		hud.call("_refresh_resource_panel")
	if hud.has_method("_refresh_hud_text"):
		hud.call("_refresh_hud_text")
	await Utils.wait_frames(tree, 2)


func _assert_hud_after_load(failures: Array[String], hud: Node, torch_active: bool) -> void:
	if hud == null:
		failures.append("HUD is missing.")
		return
	var stats_label := hud.get_node_or_null("Panel/StatsLabel") as Label
	if stats_label == null:
		failures.append("HUD stats label is missing.")
		return
	var text := stats_label.text
	_assert_text_contains(failures, text, "HP: 64", "HUD stats")
	_assert_text_contains(failures, text, "Bow: Yes", "HUD stats")
	_assert_text_contains(failures, text, "Spear: Yes", "HUD stats")
	_assert_text_contains(failures, text, "Torch: %s" % ("active" if torch_active else "inactive"), "HUD stats")
	_assert_text_contains(failures, text, "Wood: 7", "HUD stats")
	_assert_text_contains(failures, text, "Stone: 3", "HUD stats")
	_assert_text_contains(failures, text, "Fiber: 5", "HUD stats")
	_assert_text_contains(failures, text, "Meat: 2", "HUD stats")
	var wood_label := hud.get_node_or_null("ResourcePanel/ResourceHBox/WoodItem/CountLabel") as Label
	var stone_label := hud.get_node_or_null("ResourcePanel/ResourceHBox/StoneItem/CountLabel") as Label
	var fiber_label := hud.get_node_or_null("ResourcePanel/ResourceHBox/FiberItem/CountLabel") as Label
	var meat_label := hud.get_node_or_null("ResourcePanel/ResourceHBox/MeatItem/CountLabel") as Label
	var bone_label := hud.get_node_or_null("ResourcePanel/ResourceHBox/BoneItem/CountLabel") as Label
	_assert_label_text(failures, wood_label, "7", "wood HUD count")
	_assert_label_text(failures, stone_label, "3", "stone HUD count")
	_assert_label_text(failures, fiber_label, "5", "fiber HUD count")
	_assert_label_text(failures, meat_label, "2", "meat HUD count")
	_assert_label_text(failures, bone_label, "1", "bone HUD count")


func _assert_hud_resource_count(failures: Array[String], hud: Node, item_id: String, expected_amount: int) -> void:
	var path_by_item := {
		"wood": "ResourcePanel/ResourceHBox/WoodItem/CountLabel",
		"stone": "ResourcePanel/ResourceHBox/StoneItem/CountLabel",
		"fiber": "ResourcePanel/ResourceHBox/FiberItem/CountLabel",
		"meat": "ResourcePanel/ResourceHBox/MeatItem/CountLabel",
		"bone": "ResourcePanel/ResourceHBox/BoneItem/CountLabel"
	}
	if not path_by_item.has(item_id):
		failures.append("Unknown HUD resource item: %s" % item_id)
		return
	var label := hud.get_node_or_null(String(path_by_item[item_id])) as Label
	_assert_label_text(failures, label, str(expected_amount), "%s HUD count" % item_id)


func _assert_label_text(failures: Array[String], label: Label, expected_text: String, label_name: String) -> void:
	if label == null:
		failures.append("%s is missing." % label_name)
		return
	if label.text.strip_edges() != expected_text:
		failures.append("%s mismatch expected=%s actual=%s" % [label_name, expected_text, label.text])


func _assert_text_contains(failures: Array[String], text: String, expected_fragment: String, label_name: String) -> void:
	if text.find(expected_fragment) < 0:
		failures.append("%s missing fragment: %s" % [label_name, expected_fragment])


func _assert_node_exists(failures: Array[String], node: Node, node_name: String) -> void:
	if node == null or not is_instance_valid(node):
		failures.append("%s node is missing." % node_name)


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
