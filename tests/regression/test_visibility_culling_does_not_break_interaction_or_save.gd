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
	var save_system: Node = main.get_node_or_null("SaveSystem")
	var camera: Camera2D = _get_player_camera(player)

	_assert_node_exists(failures, world, "World")
	_assert_node_exists(failures, player, "Player")
	_assert_node_exists(failures, hud, "HUD")
	_assert_node_exists(failures, save_system, "SaveSystem")
	_assert_node_exists(failures, camera, "PlayerCamera")
	if not failures.is_empty():
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	var resource_debug: Dictionary = Dictionary(world.call("get_resource_activation_debug")) if world.has_method("get_resource_activation_debug") else {}
	var resource_counts: Dictionary = Dictionary(resource_debug.get("resource_node_count_by_kind", {}))
	TEST_UTILS.expect(int(resource_debug.get("tree_node_count", 0)) > 0, failures, "Fresh world should contain tree nodes")
	TEST_UTILS.expect(int(resource_debug.get("conifer_tree_node_count", 0)) > 0, failures, "Fresh world should contain conifer_tree nodes")
	TEST_UTILS.expect(int(resource_debug.get("leafy_tree_node_count", 0)) > 0, failures, "Fresh world should contain leafy_tree nodes")
	TEST_UTILS.expect(int(resource_debug.get("dry_tree_node_count", 0)) > 0, failures, "Fresh world should contain dry_tree nodes")
	TEST_UTILS.expect(int(resource_counts.get("conifer_tree", 0)) > 0, failures, "Fresh world should report conifer_tree by kind")
	TEST_UTILS.expect(int(resource_counts.get("leafy_tree", 0)) > 0, failures, "Fresh world should report leafy_tree by kind")
	TEST_UTILS.expect(int(resource_counts.get("dry_tree", 0)) > 0, failures, "Fresh world should report dry_tree by kind")

	var world_rect: Rect2 = world.call("get_world_rect")
	var positions := _get_culling_test_positions(world, player)
	var near_pos: Vector2 = Vector2(positions.get("near", world_rect.get_center()))
	var far_pos: Vector2 = _find_safe_far_position(world, near_pos)

	var tracked_resource: Node = _spawn_test_resource(world, "conifer_tree", near_pos + Vector2(0.0, 0.0))
	var tracked_creature: Node = _spawn_test_creature(world, near_pos + Vector2(160.0, 0.0))
	await Utils.wait_frames(tree, 10)

	if tracked_resource == null:
		failures.append("Could not spawn tracked resource.")
	if tracked_creature == null:
		failures.append("Could not spawn tracked creature.")
	if not failures.is_empty():
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	var resource_position := (tracked_resource as Node2D).global_position
	var creature_position := (tracked_creature as Node2D).global_position
	_assert_valid_position(failures, tracked_resource, "spawned resource")
	_assert_valid_position(failures, tracked_creature, "spawned creature")

	await _move_player_and_wait_for_culling(tree, world, player, camera, near_pos)
	_assert_visible_and_registered(failures, world, tracked_resource, tracked_creature, "near")

	await _move_player_and_wait_for_culling(tree, world, player, camera, far_pos)
	_assert_culled_but_not_lost(failures, world, tracked_resource, tracked_creature, "far")
	_assert_valid_position(failures, tracked_creature, "far creature")

	if not failures.is_empty():
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	var save_data_before := _read_save_json()
	if save_data_before.is_empty():
		failures.append("Save JSON is empty before save.")

	save_system.call("save_game")
	await Utils.wait_frames(tree, 6)

	var hidden_save_data := _read_save_json()
	_assert_hidden_objects_exist_in_save(failures, hidden_save_data, tracked_resource, tracked_creature)

	await _move_player_and_wait_for_culling(tree, world, player, camera, near_pos)
	_assert_visible_again(failures, tracked_resource, tracked_creature, "after return near")
	_assert_resource_can_be_collected_after_culling(failures, tracked_resource, player)
	_assert_valid_position(failures, tracked_creature, "returned creature")

	if not failures.is_empty():
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	save_system.call("load_game")
	await Utils.wait_frames(tree, 24)

	world = main.get_node_or_null("World")
	player = main.get_node_or_null("Player")
	save_system = main.get_node_or_null("SaveSystem")
	camera = _get_player_camera(player)
	if world == null or player == null or save_system == null or camera == null:
		failures.append("Main scene nodes missing after load.")
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	var loaded_resource := _find_resource_after_load(world, "conifer_tree", resource_position)
	var loaded_creature := _find_creature_after_load(tree, creature_position)
	if loaded_resource == null:
		failures.append("Tracked resource saved while culled was not restored after load.")
	if loaded_creature == null:
		failures.append("Tracked creature saved while culled was not restored after load.")
	if not failures.is_empty():
		await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
		Utils.cleanup_save_file()
		return failures

	await _move_player_and_wait_for_culling(tree, world, player, camera, near_pos)
	_assert_visible_again(failures, loaded_resource, loaded_creature, "after load")
	_assert_culled_but_not_lost(failures, world, loaded_resource, loaded_creature, "after load registry")
	_assert_valid_position(failures, loaded_resource, "loaded resource")
	_assert_valid_position(failures, loaded_creature, "loaded creature")

	await Utils.cleanup_context({"tree": tree, "nodes": [menu, main]})
	Utils.cleanup_save_file()
	return failures


func _get_culling_test_positions(world: Node, player: Node) -> Dictionary:
	var world_rect: Rect2 = world.call("get_world_rect")
	var near_pos := (player as Node2D).global_position + Vector2(180.0, 0.0)
	if not world_rect.has_point(near_pos):
		near_pos = world_rect.position + world_rect.size * 0.35
	var far_pos := world_rect.position + world_rect.size * 0.82
	return {
		"near": near_pos,
		"far": far_pos
	}


func _find_safe_far_position(world: Node, origin: Vector2) -> Vector2:
	var world_rect: Rect2 = world.call("get_world_rect")
	var candidates := [
		world_rect.position + world_rect.size * 0.82,
		world_rect.position + Vector2(world_rect.size.x * 0.18, world_rect.size.y * 0.82),
		world_rect.position + Vector2(world_rect.size.x * 0.82, world_rect.size.y * 0.18),
		world_rect.position + world_rect.size * 0.50
	]
	for candidate in candidates:
		if candidate.distance_to(origin) < 1800.0:
			continue
		if world.has_method("is_creature_navigation_blocked") and bool(world.call("is_creature_navigation_blocked", candidate)):
			continue
		return candidate
	return world_rect.position + world_rect.size * 0.75


func _spawn_test_resource(world: Node, kind: String, position: Vector2) -> Node:
	if world.has_method("spawn_resource_for_tests"):
		var spawned: Node = world.call("spawn_resource_for_tests", kind, position) as Node
		if spawned != null and spawned is Node2D:
			(spawned as Node2D).global_position = position
		return spawned

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


func _spawn_test_creature(world: Node, position: Vector2) -> Node:
	if world.has_method("spawn_small_prey_for_tests"):
		return world.call("spawn_small_prey_for_tests", position, "hearth_meadow") as Node
	if world.has_method("force_spawn_small_prey_for_tests"):
		var spawned: Array = Array(world.call("force_spawn_small_prey_for_tests", 1, position))
		if not spawned.is_empty():
			return spawned[0] as Node
	return null


func _move_player_and_wait_for_culling(
	tree: SceneTree,
	world: Node,
	player: Node,
	camera: Camera2D,
	position: Vector2
) -> void:
	var player_2d := player as Node2D
	if player_2d != null:
		player_2d.global_position = position
	if camera != null:
		camera.global_position = position
	if player.has_method("set_default_camera_zoom"):
		player.call("set_default_camera_zoom")
	await Utils.wait_frames(tree, 30)
	if world.has_method("_update_world_object_visibility"):
		world.call("_update_world_object_visibility")
	await Utils.wait_frames(tree, 8)


func _assert_visible_and_registered(failures: Array[String], world: Node, resource: Node, creature: Node, label: String) -> void:
	if resource == null or not is_instance_valid(resource):
		failures.append("%s: resource missing before visibility assertion." % label)
		return
	if creature == null or not is_instance_valid(creature):
		failures.append("%s: creature missing before visibility assertion." % label)
		return
	if resource is CanvasItem and not (resource as CanvasItem).visible:
		failures.append("%s: resource is unexpectedly hidden near the player." % label)
	if creature is CanvasItem and not (creature as CanvasItem).visible:
		failures.append("%s: creature is unexpectedly hidden near the player." % label)
	if world.has_method("get_registered_resources") and not (world.call("get_registered_resources") as Array).has(resource):
		failures.append("%s: resource is missing from world registry." % label)
	if world.has_method("get_registered_creatures_by_type"):
		var creature_type := _get_creature_type(creature)
		var registered: Array = Array(world.call("get_registered_creatures_by_type", creature_type))
		if not registered.has(creature):
			failures.append("%s: creature is missing from world registry." % label)


func _assert_culled_but_not_lost(failures: Array[String], world: Node, resource: Node, creature: Node, label: String) -> void:
	if resource == null or not is_instance_valid(resource):
		failures.append("%s: resource was freed/lost after culling." % label)
		return
	if creature == null or not is_instance_valid(creature):
		failures.append("%s: creature was freed/lost after culling." % label)
		return
	if not resource.is_in_group("resources"):
		failures.append("%s: hidden resource is no longer in resources group." % label)
	if not creature.is_in_group("small_prey") and not creature.is_in_group("grazer") and not creature.is_in_group("varnak"):
		failures.append("%s: hidden creature is no longer in creature group." % label)
	if world.has_method("get_registered_resources") and not (world.call("get_registered_resources") as Array).has(resource):
		failures.append("%s: hidden resource disappeared from world registry." % label)
	if world.has_method("get_registered_creatures_by_type"):
		var creature_type := _get_creature_type(creature)
		var registered: Array = Array(world.call("get_registered_creatures_by_type", creature_type))
		if not registered.has(creature):
			failures.append("%s: hidden creature disappeared from world registry." % label)
	_assert_valid_position(failures, creature, "%s hidden creature" % label)


func _assert_valid_position(failures: Array[String], node: Node, label: String) -> void:
	if node == null or not (node is Node2D):
		failures.append("%s: node is not Node2D." % label)
		return
	var pos := (node as Node2D).global_position
	if is_nan(pos.x) or is_nan(pos.y):
		failures.append("%s: position contains NaN. position=%s" % [label, pos])
	if is_inf(pos.x) or is_inf(pos.y):
		failures.append("%s: position contains INF. position=%s" % [label, pos])


func _assert_visible_again(failures: Array[String], resource: Node, creature: Node, label: String) -> void:
	if resource == null or not is_instance_valid(resource):
		failures.append("%s: resource missing before visibility restore assertion." % label)
		return
	if creature == null or not is_instance_valid(creature):
		failures.append("%s: creature missing before visibility restore assertion." % label)
		return
	if resource is CanvasItem and not (resource as CanvasItem).visible:
		failures.append("%s: resource did not become visible again after returning." % label)
	if creature is CanvasItem and not (creature as CanvasItem).visible:
		failures.append("%s: creature did not become visible again after returning." % label)
	if resource.has_method("is_player_interactable") and not bool(resource.call("is_player_interactable")):
		failures.append("%s: resource is not interactable after returning from culling." % label)


func _assert_resource_can_be_collected_after_culling(
	failures: Array[String],
	resource: Node,
	player: Node
) -> void:
	if resource == null or not is_instance_valid(resource):
		failures.append("Resource missing before interaction check.")
		return
	var item_name := str(resource.get("item_name"))
	var before_amount := int(player.inventory.get_amount(item_name))
	resource.call("interact", player)
	await Utils.wait_frames(resource.get_tree(), 4)
	var after_amount := int(player.inventory.get_amount(item_name))
	if after_amount <= before_amount:
		failures.append("Resource interaction after culling did not add item to inventory. item=%s before=%d after=%d" % [
			item_name,
			before_amount,
			after_amount
		])


func _assert_hidden_objects_exist_in_save(failures: Array[String], save_data: Dictionary, resource: Node, creature: Node) -> void:
	if save_data.is_empty():
		failures.append("Save file is empty while checking hidden objects.")
		return
	var resources: Array = Array(save_data.get("resources", []))
	var small_prey: Array = Array(save_data.get("small_prey", []))
	var grazers: Array = Array(save_data.get("grazers", []))
	var varnaks: Array = Array(save_data.get("varnaks", []))
	var resource_pos := (resource as Node2D).global_position
	var creature_pos := (creature as Node2D).global_position
	if not _save_array_contains_position(resources, resource_pos, 2.0):
		failures.append("Hidden resource was not written to save resources array.")
	var creature_saved := false
	creature_saved = creature_saved or _save_array_contains_position(small_prey, creature_pos, 2.0)
	creature_saved = creature_saved or _save_array_contains_position(grazers, creature_pos, 2.0)
	creature_saved = creature_saved or _save_array_contains_position(varnaks, creature_pos, 2.0)
	if not creature_saved:
		failures.append("Hidden creature was not written to save creature arrays.")


func _save_array_contains_position(items: Array, expected_position: Vector2, tolerance: float) -> bool:
	for item_value in items:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item := Dictionary(item_value)
		var pos_data := Dictionary(item.get("position", {}))
		var pos := Vector2(float(pos_data.get("x", INF)), float(pos_data.get("y", INF)))
		if pos.distance_to(expected_position) <= tolerance:
			return true
	return false


func _read_save_json() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return Dictionary(parsed)


func _find_resource_after_load(world: Node, kind: String, expected_position: Vector2) -> Node:
	var candidates: Array = []
	if world.has_method("get_registered_resources_by_kind"):
		candidates = Array(world.call("get_registered_resources_by_kind", kind))
	elif world.has_method("get_registered_resources"):
		candidates = Array(world.call("get_registered_resources"))
	else:
		candidates = world.get_tree().get_nodes_in_group("resources")
	var best: Node = null
	var best_distance := INF
	for node in candidates:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		if str(node.get("resource_kind")) != kind:
			continue
		var distance := (node as Node2D).global_position.distance_to(expected_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	if best_distance <= 4.0:
		return best
	return null


func _find_creature_after_load(tree: SceneTree, expected_position: Vector2) -> Node:
	var groups := ["small_prey", "grazer", "varnak"]
	var best: Node = null
	var best_distance := INF
	for group_name in groups:
		for node in tree.get_nodes_in_group(group_name):
			if not is_instance_valid(node) or not (node is Node2D):
				continue
			var distance := (node as Node2D).global_position.distance_to(expected_position)
			if distance < best_distance:
				best_distance = distance
				best = node
	if best_distance <= 8.0:
		return best
	return null


func _get_player_camera(player: Node) -> Camera2D:
	if player == null:
		return null
	var direct := player.get_node_or_null("Camera2D") as Camera2D
	if direct != null:
		return direct
	var camera_variant: Variant = player.get("player_camera")
	if camera_variant is Camera2D:
		return camera_variant
	return null


func _get_creature_type(creature: Node) -> String:
	if creature.is_in_group("grazer"):
		return "grazer"
	if creature.is_in_group("varnak"):
		return "varnak"
	return "small_prey"


func _assert_node_exists(failures: Array[String], node: Variant, node_name: String) -> void:
	if node == null or not is_instance_valid(node):
		failures.append("%s node is missing." % node_name)


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
