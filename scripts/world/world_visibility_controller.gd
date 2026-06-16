extends RefCounted
class_name WorldVisibilityController

var world: Node
var registry: RefCounted
var spatial_index: RefCounted
var enabled := true
var interval_seconds := 0.35
var margin := 384.0
var update_timer := 0.0
var last_visible_nodes: Dictionary = {}
var visible_resource_count := 0
var hidden_resource_count := 0
var visible_creature_count := 0
var hidden_creature_count := 0
var last_visible_rect := Rect2()


func setup(config: Dictionary) -> void:
	world = config.get("world", world)
	registry = config.get("registry", registry)
	spatial_index = config.get("spatial_index", spatial_index)
	enabled = bool(config.get("enabled", enabled))
	interval_seconds = float(config.get("interval_seconds", interval_seconds))
	margin = float(config.get("margin", margin))


func process(delta: float) -> void:
	if not enabled or not is_instance_valid(world):
		return
	update_timer += delta
	if update_timer < interval_seconds:
		return
	update_timer = 0.0
	_update_visibility()


func force_update() -> void:
	if not enabled or not is_instance_valid(world):
		return
	update_timer = 0.0
	_update_visibility()


func get_debug_data() -> Dictionary:
	return {
		"enabled": enabled,
		"interval_seconds": interval_seconds,
		"margin": margin,
		"visible_resources": visible_resource_count,
		"hidden_resources": hidden_resource_count,
		"visible_creatures": visible_creature_count,
		"hidden_creatures": hidden_creature_count
	}


func reset() -> void:
	update_timer = 0.0
	last_visible_nodes = {}
	visible_resource_count = 0
	hidden_resource_count = 0
	visible_creature_count = 0
	hidden_creature_count = 0
	last_visible_rect = Rect2()


func _update_visibility() -> void:
	if not is_instance_valid(world):
		return
	var visible_rect := _get_expanded_visible_rect()
	if visible_rect == Rect2():
		return
	var current_visible_nodes: Dictionary = {}
	visible_resource_count = 0
	hidden_resource_count = 0
	visible_creature_count = 0
	hidden_creature_count = 0
	var query_rect := visible_rect.grow(48.0)
	for node in _query_resources(query_rect):
		_mark_visible(node, true, current_visible_nodes)
	for node in _query_meat(query_rect):
		_mark_visible(node, true, current_visible_nodes)
	for creature_type in ["small_prey", "grazer", "varnak"]:
		for node in _query_creatures(query_rect, creature_type):
			_mark_visible(node, false, current_visible_nodes)
	_hide_nodes_that_left_visibility_rect(current_visible_nodes)
	last_visible_nodes = current_visible_nodes
	last_visible_rect = visible_rect


func _get_expanded_visible_rect() -> Rect2:
	if not is_instance_valid(world):
		return Rect2()
	if not world.has_method("get_camera_visible_world_rect"):
		return Rect2()
	return world.get_camera_visible_world_rect(margin)


func _query_resources(rect: Rect2) -> Array:
	if is_instance_valid(registry) and registry.has_method("query_resources_in_rect"):
		return Array(registry.query_resources_in_rect(rect))
	if world.has_method("get_resources_in_rect"):
		return Array(world.get_resources_in_rect(rect))
	return []


func _query_meat(rect: Rect2) -> Array:
	if is_instance_valid(registry) and registry.has_method("query_meat_in_rect"):
		return Array(registry.query_meat_in_rect(rect))
	if world.has_method("get_meat_in_rect"):
		return Array(world.get_meat_in_rect(rect))
	return []


func _query_creatures(rect: Rect2, creature_type: String) -> Array:
	if is_instance_valid(registry) and registry.has_method("query_creatures_in_rect"):
		return Array(registry.query_creatures_in_rect(rect, creature_type))
	if world.has_method("get_creatures_in_rect"):
		return Array(world.get_creatures_in_rect(rect, creature_type))
	return []


func _mark_visible(node: Node, is_resource: bool, current_visible_nodes: Dictionary) -> void:
	if not is_instance_valid(node):
		return
	current_visible_nodes[node.get_instance_id()] = node
	_set_visibility(node, true)
	if is_resource:
		visible_resource_count += 1
	else:
		visible_creature_count += 1


func _hide_nodes_that_left_visibility_rect(current_visible_nodes: Dictionary) -> void:
	for previous_id in last_visible_nodes.keys():
		if current_visible_nodes.has(previous_id):
			continue
		var previous_node: Variant = last_visible_nodes.get(previous_id, null)
		if previous_node == null or not is_instance_valid(previous_node):
			continue
		var node := previous_node as Node
		if node == null:
			continue
		var is_resource := node.is_in_group("resources")
		_set_visibility(node, false)
		if is_resource:
			hidden_resource_count += 1
		else:
			hidden_creature_count += 1


func _set_visibility(node: Node, should_be_visible: bool) -> void:
	if not is_instance_valid(node):
		return
	if node.has_method("set_visibility_culled"):
		node.call("set_visibility_culled", should_be_visible)
	elif node is Node2D:
		(node as Node2D).visible = should_be_visible
