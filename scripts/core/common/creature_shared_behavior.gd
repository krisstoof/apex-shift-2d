extends RefCounted
class_name CoreCreatureSharedBehavior

static func safe_float(data: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = data.get(key, fallback)
	if value == null:
		return fallback
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	if typeof(value) == TYPE_STRING and str(value).is_valid_float():
		return float(value)
	return fallback

static func safe_int(data: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = data.get(key, fallback)
	if value == null:
		return fallback
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	if typeof(value) == TYPE_STRING and str(value).is_valid_int():
		return int(value)
	return fallback

static func safe_bool(data: Dictionary, key: String, fallback: bool) -> bool:
	var value: Variant = data.get(key, fallback)
	if value == null:
		return fallback
	if typeof(value) == TYPE_BOOL:
		return bool(value)
	if typeof(value) == TYPE_STRING:
		var normalized := str(value).to_lower()
		if normalized == "true":
			return true
		if normalized == "false":
			return false
	return fallback

static func vector_to_data(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}

static func data_to_vector(data: Variant, fallback := Vector2.ZERO) -> Vector2:
	if typeof(data) != TYPE_DICTIONARY:
		return fallback
	var x_raw: Variant = data.get("x", fallback.x)
	var y_raw: Variant = data.get("y", fallback.y)
	var x_value := fallback.x
	var y_value := fallback.y
	if x_raw != null:
		x_value = float(x_raw)
	if y_raw != null:
		y_value = float(y_raw)
	return Vector2(x_value, y_value)

static func get_scene_tree(owner: Node) -> SceneTree:
	if is_instance_valid(owner) and owner.is_inside_tree():
		return owner.get_tree()
	return Engine.get_main_loop() as SceneTree

static func get_world_node(tree: SceneTree, cached_world: Node = null) -> Node2D:
	if is_instance_valid(cached_world):
		return cached_world as Node2D
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.get_node_or_null("World") as Node2D

static func get_ecosystem(tree: SceneTree, cached_ecosystem: Node = null) -> Node:
	if is_instance_valid(cached_ecosystem):
		return cached_ecosystem
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.get_node_or_null("EcosystemDirector")

static func get_debug_panel(tree: SceneTree, cached_debug_panel: Node = null) -> Node:
	if is_instance_valid(cached_debug_panel):
		return cached_debug_panel
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.get_node_or_null("HUD/DebugPanel")

static func is_debug_overlay_visible(tree: SceneTree, cached_debug_panel: Node = null) -> bool:
	var panel := get_debug_panel(tree, cached_debug_panel)
	return is_instance_valid(panel) and panel.visible

static func get_cached_group_nodes(tree: SceneTree, world_node: Node, group_name: String) -> Array:
	if is_instance_valid(world_node) and world_node.has_method("get_cached_group_nodes"):
		return world_node.get_cached_group_nodes(group_name)
	if tree == null:
		return []
	return tree.get_nodes_in_group(group_name)

static func get_world_query(cached_world_query: Variant, world_node: Node) -> Variant:
	if cached_world_query != null:
		return cached_world_query
	if is_instance_valid(world_node) and world_node.has_method("get_query_service"):
		return world_node.get_query_service()
	return world_node

static func get_biome_id_at(world_node: Node, world_position: Vector2) -> String:
	if is_instance_valid(world_node) and world_node.has_method("get_biome_id_at"):
		return str(world_node.get_biome_id_at(world_position))
	return ""

static func is_position_in_biome(world_node: Node, world_position: Vector2, target_biome_id: String, fallback_rect: Rect2) -> bool:
	if target_biome_id.is_empty():
		return fallback_rect.has_point(world_position)
	return get_biome_id_at(world_node, world_position) == target_biome_id

static func clamp_to_rect(world_point: Vector2, rect: Rect2) -> Vector2:
	return Vector2(
		clamp(world_point.x, rect.position.x, rect.end.x),
		clamp(world_point.y, rect.position.y, rect.end.y)
	)

static func clamp_target_distance(origin: Vector2, target: Vector2, max_distance: float) -> Vector2:
	var offset := target - origin
	if offset.length() <= max_distance:
		return target
	return origin + offset.normalized() * max_distance

static func is_navigation_blocked(world_query: Variant, world_position: Vector2) -> bool:
	return (
		world_query
		and world_query.has_method("is_creature_navigation_blocked")
		and world_query.is_creature_navigation_blocked(world_position) == true
	)

static func is_navigation_position_valid(
	world_position: Vector2,
	world_rect: Rect2,
	world_query: Variant,
	walls: Array = [],
	wall_avoid_radius: float = 0.0,
	wall_distance_multiplier: float = 0.72
) -> bool:
	var clamped_position := clamp_to_rect(world_position, world_rect)
	if clamped_position.distance_squared_to(world_position) > 0.01:
		return false
	if is_navigation_blocked(world_query, world_position):
		return false
	if wall_avoid_radius > 0.0:
		for wall in walls:
			var wall_node := wall as Node2D
			if is_instance_valid(wall_node) and world_position.distance_to(wall_node.global_position) < wall_avoid_radius * wall_distance_multiplier:
				return false
	return true

static func update_spatial_entity_cell(world_node: Node, entity: Node) -> void:
	if is_instance_valid(world_node) and world_node.has_method("update_spatial_entity_cell"):
		world_node.update_spatial_entity_cell(entity)
