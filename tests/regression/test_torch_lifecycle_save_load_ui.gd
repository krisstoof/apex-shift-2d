extends RefCounted

const Utils := preload("res://tests/regression/regression_test_utils.gd")
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const SAVE_PATH := "user://savegame.json"


func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var messages: Array[String] = []

	Utils.cleanup_save_file()
	await Utils.cleanup_context({"tree": tree, "nodes": []})

	_connect_message_capture(tree, messages)

	var menu_result: Dictionary = await Utils.boot_start_menu(tree)
	if menu_result.get("ok", false) != true:
		return [String(menu_result.get("reason", "Could not boot start menu"))]

	var menu := menu_result.get("scene") as Node
	var new_game_error := await _click_new_game(menu, tree)
	if new_game_error != "":
		return [new_game_error]

	if not await _wait_for_scene_path(tree, MAIN_SCENE_PATH, 180):
		return ["New Game did not switch to main.tscn"]

	var main := tree.current_scene
	if not await Utils.wait_for_world_boot(main):
		return ["World did not boot"]

	await Utils.wait_frames(tree, 8)

	var world := main.get_node_or_null("World")
	var player := main.get_node_or_null("Player")
	var hud := main.get_node_or_null("HUD")
	var save_system := main.get_node_or_null("SaveSystem")

	if world == null:
		failures.append("World missing")
	if player == null:
		failures.append("Player missing")
	if hud == null:
		failures.append("HUD missing")
	if save_system == null:
		failures.append("SaveSystem missing")
	if not failures.is_empty():
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	var player_inventory := player.get("inventory") as Object
	if player_inventory == null:
		return ["Player inventory missing"]

	player_inventory.call("clear")
	player_inventory.call("add_item", "wood", 3)
	player_inventory.call("add_item", "fiber", 3)

	var torch_before_craft := int(player_inventory.call("get_amount", "torch"))
	player.call("_craft", "torch")
	await Utils.wait_frames(tree, 6)

	var torch_after_craft := int(player_inventory.call("get_amount", "torch"))
	if torch_after_craft != torch_before_craft + 1:
		failures.append("Crafting torch did not add torch to inventory. before=%d after=%d" % [torch_before_craft, torch_after_craft])

	_refresh_hud_for_test(hud, tree)
	_assert_hud_shows_torch_state(failures, hud, "inactive")

	var light: PointLight2D = _get_torch_light(player)
	if light == null:
		failures.append("TorchLight node missing after craft.")
	elif light.visible or light.enabled:
		failures.append("TorchLight should be hidden before activation.")

	var torch_before_activation := int(player_inventory.call("get_amount", "torch"))
	var activated: bool = player.call("activate_torch") == true
	await Utils.wait_frames(tree, 6)

	if activated != true:
		failures.append("player.activate_torch() returned false even though torch existed in inventory.")

	var torch_after_activation := int(player_inventory.call("get_amount", "torch"))
	if torch_after_activation != torch_before_activation - 1:
		failures.append("Activating torch did not remove exactly one torch from inventory. before=%d after=%d" % [torch_before_activation, torch_after_activation])

	if player.get("torch_active") != true:
		failures.append("torch_active was not set to true after activation.")

	if float(player.get("torch_remaining_seconds")) <= 0.0:
		failures.append("torch_remaining_seconds was not set after activation.")

	if player.has_method("is_torch_active") and player.call("is_torch_active") != true:
		failures.append("player.is_torch_active() returned false after activation.")

	_refresh_hud_for_test(hud, tree)
	_assert_hud_shows_torch_state(failures, hud, "active")
	_assert_torch_light_state(failures, player, true, "after activation")
	_assert_contains_message(failures, messages, "Crafted torch")
	_assert_contains_message(failures, messages, "Torch activated")

	var expected_remaining_before_save := float(player.get("torch_remaining_seconds"))
	save_system.call("save_game")
	await Utils.wait_frames(tree, 4)

	if not FileAccess.file_exists(SAVE_PATH):
		failures.append("Save file was not created.")
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	player.set("torch_active", false)
	player.set("torch_remaining_seconds", 0.0)
	player_inventory.call("clear")
	player_inventory.call("add_item", "wood", 1)

	save_system.call("load_game")
	await Utils.wait_frames(tree, 16)
	_refresh_hud_for_test(hud, tree)

	if player.get("torch_active") != true:
		failures.append("Active torch was not restored after load.")

	var restored_remaining := float(player.get("torch_remaining_seconds"))
	if restored_remaining <= 0.0:
		failures.append("Restored active torch has non-positive remaining time.")
	if restored_remaining > expected_remaining_before_save + 0.5:
		failures.append("Restored torch remaining time is greater than saved time. saved=%.3f restored=%.3f" % [expected_remaining_before_save, restored_remaining])

	_assert_hud_shows_torch_state(failures, hud, "active")
	_assert_torch_light_state(failures, player, true, "after active torch load")

	var timer_before_wait := float(player.get("torch_remaining_seconds"))
	await Utils.wait_frames(tree, 20)
	var timer_after_wait := float(player.get("torch_remaining_seconds"))
	if timer_after_wait >= timer_before_wait:
		failures.append("Torch timer did not decrease over time. before=%.3f after=%.3f" % [timer_before_wait, timer_after_wait])

	player.set("torch_remaining_seconds", 0.15)
	player.set("torch_active", true)
	await _wait_until_torch_expired(tree, player, 120)

	if player.get("torch_active") == true:
		failures.append("torch_active remained true after expiration.")
	if float(player.get("torch_remaining_seconds")) > 0.01:
		failures.append("torch_remaining_seconds was not reduced to 0 after expiration. actual=%.3f" % float(player.get("torch_remaining_seconds")))
	if player.has_method("is_torch_active") and player.call("is_torch_active") == true:
		failures.append("player.is_torch_active() returned true after expiration.")

	_assert_torch_light_state(failures, player, false, "after expiration")
	_refresh_hud_for_test(hud, tree)
	_assert_hud_shows_torch_state(failures, hud, "inactive")
	_assert_contains_message(failures, messages, "Torch burned out")

	player_inventory.call("clear")
	var torch_count_before_empty_activation: int = int(player_inventory.call("get_amount", "torch"))
	var empty_activation_result: bool = player.call("activate_torch") == true
	await Utils.wait_frames(tree, 6)

	if empty_activation_result == true:
		failures.append("player.activate_torch() returned true without torch in inventory.")
	if player.get("torch_active") == true:
		failures.append("Torch became active without torch in inventory.")
	if float(player.get("torch_remaining_seconds")) > 0.01:
		failures.append("Torch remaining time changed without torch in inventory. actual=%.3f" % float(player.get("torch_remaining_seconds")))

	var torch_count_after_empty_activation: int = int(player_inventory.call("get_amount", "torch"))
	if torch_count_after_empty_activation != torch_count_before_empty_activation:
		failures.append("Torch inventory count changed during empty activation attempt. before=%d after=%d" % [torch_count_before_empty_activation, torch_count_after_empty_activation])

	_assert_torch_light_state(failures, player, false, "after empty activation attempt")
	_assert_contains_message(failures, messages, "No torch to activate")

	await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
	Utils.cleanup_save_file()
	return failures


func _connect_message_capture(tree: SceneTree, messages: Array[String]) -> void:
	var event_bus := tree.root.get_node_or_null("EventBus")
	if event_bus == null:
		return
	if event_bus.has_signal("message_posted"):
		event_bus.message_posted.connect(func(message: String) -> void:
			messages.append(message)
		)


func _refresh_hud_for_test(hud: Node, tree: SceneTree) -> void:
	if hud == null:
		return
	if hud.has_method("_refresh_resource_panel"):
		hud.call("_refresh_resource_panel")
	if hud.has_method("_refresh_hud_text"):
		hud.call("_refresh_hud_text")
	await Utils.wait_frames(tree, 4)


func _assert_hud_shows_torch_state(failures: Array[String], hud: Node, expected_state: String) -> void:
	var stats_label := hud.get_node_or_null("Panel/StatsLabel") as Label
	if stats_label == null:
		failures.append("HUD StatsLabel missing.")
		return
	var text := stats_label.text
	var expected_fragment := "Torch: %s" % expected_state
	if text.find(expected_fragment) < 0:
		failures.append("HUD does not show %s torch. text=%s" % [expected_state, text])


func _assert_torch_light_state(failures: Array[String], player: Node, expected_active: bool, label: String) -> void:
	var light: PointLight2D = _get_torch_light(player)
	if light == null:
		failures.append("%s: TorchLight node missing." % label)
		return
	if light.visible != expected_active:
		failures.append("%s: TorchLight visible mismatch. expected=%s actual=%s" % [label, expected_active, light.visible])
	if light.enabled != expected_active:
		failures.append("%s: TorchLight enabled mismatch. expected=%s actual=%s" % [label, expected_active, light.enabled])


func _get_torch_light(player: Node) -> PointLight2D:
	if player == null:
		return null
	var light: PointLight2D = player.get_node_or_null("TorchLight") as PointLight2D
	if light != null:
		return light
	var direct_light: Variant = player.get("torch_light")
	if direct_light is PointLight2D:
		return direct_light
	return null


func _wait_until_torch_expired(tree: SceneTree, player: Node, max_frames: int = 120) -> void:
	for _i in range(max_frames):
		if player.get("torch_active") != true and float(player.get("torch_remaining_seconds")) <= 0.01:
			return
		await Utils.wait_frames(tree, 1)


func _assert_contains_message(failures: Array[String], messages: Array[String], fragment: String) -> void:
	for message in messages:
		if message.find(fragment) >= 0:
			return
	failures.append("Missing system message: %s" % fragment)


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
