extends RefCounted

const MAIN_SCENE := preload("res://scenes/main.tscn")
const RESOURCE_SCENE := preload("res://scenes/world/resource_node.tscn")
const WALL_SCENE := preload("res://scenes/buildings/wall.tscn")
const TRAP_SCENE := preload("res://scenes/buildings/trap.tscn")
const TENT_SCENE := preload("res://scenes/buildings/tent.tscn")
const STORAGE_BOX_SCENE := preload("res://scenes/buildings/storage_box.tscn")
const CAMPFIRE_SCENE := preload("res://scenes/buildings/campfire.tscn")
const SMALL_PREY_SCENE := preload("res://scenes/creatures/small_prey.tscn")
const GRAZER_SCENE := preload("res://scenes/creatures/grazer.tscn")
const VARNAK_SCENE := preload("res://scenes/creatures/varnak.tscn")
const WORLD_BOOT_TIMEOUT_FRAMES := 600


static func boot_main() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return {
			"ok": false,
			"reason": "SceneTree is not available."
		}
	tree.paused = false
	var main := MAIN_SCENE.instantiate()
	var world := main.get_node_or_null("World")
	if world != null and world.has_method("enable_integration_test_mode"):
		world.call("enable_integration_test_mode")
	var original_scene := tree.current_scene
	tree.root.call_deferred("add_child", main)
	tree.call_deferred("set_current_scene", main)
	await main.ready
	var boot_result := await _wait_for_world_boot(main, WORLD_BOOT_TIMEOUT_FRAMES)
	if not bool(boot_result.get("ok", false)):
		if is_instance_valid(main):
			main.queue_free()
			await tree.process_frame
		return {
			"ok": false,
			"reason": String(boot_result.get("reason", "World boot failed.")),
			"tree": tree,
			"main": null,
			"original_scene": original_scene
		}
	await tree.process_frame
	return {
		"ok": true,
		"tree": tree,
		"main": main,
		"original_scene": original_scene
	}


static func boot_main_sync() -> Dictionary:
	return await boot_main()


static func shutdown_main(context: Dictionary) -> void:
	var tree := context.get("tree") as SceneTree
	var main := context.get("main") as Node
	var original_scene := context.get("original_scene") as Node
	if tree == null:
		return
	tree.paused = false
	if is_instance_valid(original_scene):
		tree.current_scene = original_scene
	if is_instance_valid(main):
		main.queue_free()
		await tree.process_frame
		await tree.process_frame
		await tree.process_frame
		await tree.process_frame
	if is_instance_valid(original_scene):
		tree.current_scene = original_scene
	else:
		tree.current_scene = null
	if FileAccess.file_exists("user://savegame.json"):
		var save_path := ProjectSettings.globalize_path("user://savegame.json")
		DirAccess.remove_absolute(save_path)
	tree.paused = false


static func shutdown() -> void:
	await shutdown_main({})


static func _wait_for_world_boot(main: Node, timeout_frames := WORLD_BOOT_TIMEOUT_FRAMES) -> Dictionary:
	if main == null:
		return {
			"ok": false,
			"reason": "Main scene is null while waiting for world boot."
		}
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return {
			"ok": false,
			"reason": "SceneTree is null while waiting for world boot."
		}
	var world := main.get_node_or_null("World")
	if world == null:
		return {"ok": false, "reason": "World node missing while waiting for boot."}
	if not world.has_method("is_boot_ready"):
		return {"ok": false, "reason": "World does not expose is_boot_ready()."}
	if bool(world.call("is_boot_ready")):
		return {"ok": true}
	for _i in range(timeout_frames):
		await tree.process_frame
		if not is_instance_valid(world):
			return {"ok": false, "reason": "World was freed while waiting for boot."}
		if bool(world.call("is_boot_ready")):
			return {"ok": true}
	var boot_state := {}
	if world.has_method("get_boot_progress_state"):
		boot_state = Dictionary(world.call("get_boot_progress_state"))
	return {
		"ok": false,
		"reason": "World boot timeout after %d frames. boot_state=%s" % [timeout_frames, JSON.stringify(boot_state)]
	}


static func refresh_world_cache(world: Node) -> void:
	if world and world.has_method("clear_cached_group_nodes"):
		world.call("clear_cached_group_nodes")


static func get_first_valid_node_in_group(tree: SceneTree, group_name: String) -> Node:
	if tree == null:
		return null
	for node in tree.get_nodes_in_group(group_name):
		if is_instance_valid(node):
			return node
	return null


static func get_valid_nodes_in_group(tree: SceneTree, group_name: String) -> Array[Node]:
	var nodes: Array[Node] = []
	if tree == null:
		return nodes
	for node in tree.get_nodes_in_group(group_name):
		if is_instance_valid(node):
			nodes.append(node)
	return nodes


static func find_point_in_biome(world: Node, biome_id: String, prefer_land: bool = true) -> Vector2:
	if world == null or not world.has_method("get_biome_zones") or not world.has_method("get_world_rect"):
		return Vector2.ZERO
	var zones: Array = world.call("get_biome_zones")
	var target_biome: Dictionary = {}
	for zone_value in zones:
		if typeof(zone_value) != TYPE_DICTIONARY:
			continue
		var zone := Dictionary(zone_value)
		if str(zone.get("name", "")).to_snake_case() == biome_id:
			target_biome = zone
			break
	if target_biome.is_empty():
		return Vector2.ZERO
	return _find_point_in_polygon(world, target_biome, prefer_land)


static func find_point_in_dangerous_biome(world: Node, prefer_land: bool = true) -> Vector2:
	if world == null or not world.has_method("get_biome_zones") or not world.has_method("get_world_rect"):
		return Vector2.ZERO
	var zones: Array = world.call("get_biome_zones")
	for zone_value in zones:
		if typeof(zone_value) != TYPE_DICTIONARY:
			continue
		var zone := Dictionary(zone_value)
		if zone.get("dangerous", false) != true:
			continue
		var point := _find_point_in_polygon(world, zone, prefer_land)
		if point != Vector2.ZERO:
			return point
	return Vector2.ZERO


static func _find_point_in_polygon(world: Node, biome: Dictionary, prefer_land: bool) -> Vector2:
	var rect: Rect2 = world.call("get_world_rect")
	var points := PackedVector2Array(biome.get("points", []))
	if points.is_empty():
		return Vector2.ZERO
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	var step_x: float = maxf(bounds.size.x / 18.0, 24.0)
	var step_y: float = maxf(bounds.size.y / 18.0, 24.0)
	for y_index in range(19):
		for x_index in range(19):
			var candidate := Vector2(
				bounds.position.x + min(bounds.size.x, step_x * float(x_index)),
				bounds.position.y + min(bounds.size.y, step_y * float(y_index))
			)
			candidate.x = clamp(candidate.x, rect.position.x, rect.end.x)
			candidate.y = clamp(candidate.y, rect.position.y, rect.end.y)
			if not Geometry2D.is_point_in_polygon(candidate, points):
				continue
			if prefer_land and world.has_method("is_position_in_water") and world.call("is_position_in_water", candidate):
				continue
			return candidate
	return Vector2.ZERO


static func spawn_resource(world: Node, resource_kind: String, position: Vector2) -> Node:
	if world == null:
		return null
	var resource := world.call("spawn_resource_for_tests", resource_kind, position) as Node
	refresh_world_cache(world)
	return resource


static func spawn_creature(world: Node, creature_type: String, position: Vector2) -> Node:
	if world == null:
		return null
	var creature: Node = null
	match creature_type:
		"small_prey":
			creature = world.call("spawn_small_prey_for_tests", position, "test_biome")
		"grazer":
			creature = world.call("spawn_grazer_for_tests", position, "test_biome")
		"varnak":
			creature = world.call("spawn_varnak_for_tests", position)
	refresh_world_cache(world)
	return creature


static func spawn_building(world: Node, building_type: String, position: Vector2) -> Node:
	if world == null:
		return null
	var scene: PackedScene = null
	match building_type:
		"wall":
			scene = WALL_SCENE
		"trap":
			scene = TRAP_SCENE
		"tent":
			scene = TENT_SCENE
		"storage_box":
			scene = STORAGE_BOX_SCENE
		"campfire":
			scene = CAMPFIRE_SCENE
	if scene == null:
		return null
	var building := scene.instantiate() as Node
	if building == null:
		return null
	if building is Node2D:
		(building as Node2D).global_position = position
	world.add_child(building)
	refresh_world_cache(world)
	return building


static func wait_frames(frame_count: int = 1) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for _i in range(maxi(frame_count, 1)):
		await tree.process_frame


static func spawn_small_prey(world: Node, biome_id: String, position: Vector2) -> Node:
	if world == null:
		return null
	var prey := world.call("spawn_small_prey_for_tests", position, biome_id) as Node
	refresh_world_cache(world)
	return prey


static func spawn_grazer(world: Node, biome_id: String, position: Vector2) -> Node:
	if world == null:
		return null
	var grazer := world.call("spawn_grazer_for_tests", position, biome_id) as Node
	refresh_world_cache(world)
	return grazer


static func spawn_varnak(world: Node, position: Vector2) -> Node:
	if world == null:
		return null
	var varnak := world.call("spawn_varnak_for_tests", position) as Node
	refresh_world_cache(world)
	return varnak


static func has_property(node: Object, property_name: String) -> bool:
	if node == null:
		return false
	for property_info in node.get_property_list():
		if typeof(property_info) != TYPE_DICTIONARY:
			continue
		var property_dict := property_info as Dictionary
		if str(property_dict.get("name", "")) == property_name:
			return true
	return false


static func clear_nodes_in_group_near_position(tree: SceneTree, group_name: String, position: Vector2, radius: float) -> int:
	var removed := 0
	if tree == null:
		return removed
	for node in tree.get_nodes_in_group(group_name):
		var node_2d := node as Node2D
		if not is_instance_valid(node_2d):
			continue
		if node_2d.global_position.distance_to(position) > radius:
			continue
		node_2d.queue_free()
		removed += 1
	return removed


static func clear_nodes_in_group(tree: SceneTree, group_name: String) -> int:
	var removed := 0
	if tree == null:
		return removed
	for node in tree.get_nodes_in_group(group_name):
		var node_2d := node as Node2D
		if not is_instance_valid(node_2d):
			continue
		node_2d.queue_free()
		removed += 1
	return removed


static func assert_node_exists(failures: Array[String], node: Node, label: String) -> void:
	if node == null or not is_instance_valid(node):
		failures.append("%s missing or invalid." % label)


static func assert_true(failures: Array[String], condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


static func assert_false(failures: Array[String], condition: bool, message: String) -> void:
	if condition:
		failures.append(message)


static func assert_valid_node2d_position(failures: Array[String], node: Node, label: String) -> void:
	if node == null or not is_instance_valid(node):
		failures.append("%s missing or invalid." % label)
		return
	var node_2d := node as Node2D
	if node_2d == null:
		failures.append("%s is not Node2D." % label)
		return
	var pos := node_2d.global_position
	if is_nan(pos.x) or is_nan(pos.y):
		failures.append("%s position contains NaN: %s" % [label, pos])
	if is_inf(pos.x) or is_inf(pos.y):
		failures.append("%s position contains INF: %s" % [label, pos])


static func assert_node_inside_world_rect(failures: Array[String], world: Node, node: Node, label: String) -> void:
	if world == null or not world.has_method("get_world_rect"):
		failures.append("World missing get_world_rect while checking %s." % label)
		return
	var node_2d := node as Node2D
	if node_2d == null:
		failures.append("%s is not Node2D." % label)
		return
	var world_rect: Rect2 = world.call("get_world_rect")
	if not world_rect.has_point(node_2d.global_position):
		failures.append("%s outside world rect: %s rect=%s" % [label, node_2d.global_position, world_rect])


static func assert_resource_registered(failures: Array[String], world: Node, resource: Node, expected_kind: String, label: String) -> void:
	if resource == null or not is_instance_valid(resource):
		failures.append("%s resource missing." % label)
		return
	if not resource.is_in_group("resources"):
		failures.append("%s resource is not in resources group." % label)
	if world.has_method("get_registered_resources"):
		var resources: Array = world.call("get_registered_resources")
		if not resources.has(resource):
			failures.append("%s resource is not in world resource registry." % label)
	if expected_kind != "" and world.has_method("get_registered_resources_by_kind"):
		var by_kind: Array = world.call("get_registered_resources_by_kind", expected_kind)
		if not by_kind.has(resource):
			failures.append("%s resource is not returned by get_registered_resources_by_kind(%s)." % [label, expected_kind])


static func assert_creature_registered(failures: Array[String], world: Node, creature: Node, creature_type: String, label: String) -> void:
	if creature == null or not is_instance_valid(creature):
		failures.append("%s creature missing." % label)
		return
	if not creature.is_in_group(creature_type):
		failures.append("%s creature is not in expected group: %s." % [label, creature_type])
	if world.has_method("get_registered_creatures_by_type"):
		var registered: Array = world.call("get_registered_creatures_by_type", creature_type)
		if not registered.has(creature):
			failures.append("%s creature is not in world registry for type %s." % [label, creature_type])


static func assert_tree_unpaused(failures: Array[String], tree: SceneTree, label: String) -> void:
	if tree.paused:
		failures.append("%s left SceneTree.paused=true." % label)
