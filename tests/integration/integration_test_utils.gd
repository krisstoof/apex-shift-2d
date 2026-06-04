extends RefCounted

const MAIN_SCENE := preload("res://scenes/main.tscn")
const RESOURCE_SCENE := preload("res://scenes/world/resource_node.tscn")
const SMALL_PREY_SCENE := preload("res://scenes/creatures/small_prey.tscn")
const GRAZER_SCENE := preload("res://scenes/creatures/grazer.tscn")
const VARNAK_SCENE := preload("res://scenes/creatures/varnak.tscn")


static func boot_main() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return {}
	var main := MAIN_SCENE.instantiate()
	var original_scene := tree.current_scene
	tree.root.call_deferred("add_child", main)
	tree.call_deferred("set_current_scene", main)
	await main.ready
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	return {
		"tree": tree,
		"main": main,
		"original_scene": original_scene
	}


static func shutdown_main(context: Dictionary) -> void:
	var tree := context.get("tree") as SceneTree
	var main := context.get("main") as Node
	var original_scene := context.get("original_scene") as Node
	if tree == null:
		return
	if is_instance_valid(main):
		main.queue_free()
		await tree.process_frame
	if is_instance_valid(original_scene):
		tree.current_scene = original_scene


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
	var resource := RESOURCE_SCENE.instantiate()
	world.add_child(resource)
	resource.global_position = position
	resource.call("setup", resource_kind)
	refresh_world_cache(world)
	return resource


static func spawn_small_prey(world: Node, biome_id: String, position: Vector2) -> Node:
	if world == null:
		return null
	var prey := SMALL_PREY_SCENE.instantiate()
	world.add_child(prey)
	prey.global_position = position
	prey.call("setup", biome_id)
	refresh_world_cache(world)
	return prey


static func spawn_grazer(world: Node, biome_id: String, position: Vector2) -> Node:
	if world == null:
		return null
	var grazer := GRAZER_SCENE.instantiate()
	world.add_child(grazer)
	grazer.global_position = position
	grazer.call("setup", biome_id)
	refresh_world_cache(world)
	return grazer


static func spawn_varnak(world: Node, position: Vector2) -> Node:
	if world == null:
		return null
	var varnak := VARNAK_SCENE.instantiate()
	world.add_child(varnak)
	varnak.global_position = position
	if varnak.has_method("apply_profile"):
		var evolution := world.get_parent().get_node_or_null("EvolutionDirector")
		if evolution and evolution.has_method("get_profile"):
			varnak.apply_profile(evolution.call("get_profile"))
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
