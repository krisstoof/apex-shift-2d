extends RefCounted
const GodotRuntimeContext := preload("res://scripts/godot_runtime/runtime/godot_runtime_context.gd")


func build_from_scene_tree(tree: SceneTree) -> Variant:
	var context := GodotRuntimeContext.new()
	if tree == null:
		return context

	var current_scene := tree.current_scene

	_set_if_found(context, GodotRuntimeContext.KEY_WORLD, _find_world(tree, current_scene))
	_set_if_found(context, GodotRuntimeContext.KEY_PLAYER, _find_player(tree, current_scene))
	_set_if_found(context, GodotRuntimeContext.KEY_DAY_NIGHT_SYSTEM, _find_named_node(current_scene, "DayNightSystem"))
	_set_if_found(context, GodotRuntimeContext.KEY_ECOSYSTEM_DIRECTOR, _find_named_node(current_scene, "EcosystemDirector"))
	_set_if_found(context, GodotRuntimeContext.KEY_EVOLUTION_DIRECTOR, _find_named_node(current_scene, "EvolutionDirector"))
	_set_if_found(context, GodotRuntimeContext.KEY_SAVE_SYSTEM, _find_named_node(current_scene, "SaveSystem"))
	_set_if_found(context, GodotRuntimeContext.KEY_UI_ROOT, _find_named_node(current_scene, "UI"))
	_set_if_found(context, GodotRuntimeContext.KEY_EVENT_BUS, tree.root.get_node_or_null("EventBus"))
	_set_if_found(context, GodotRuntimeContext.KEY_GAME_SESSION, tree.root.get_node_or_null("GameSession"))

	return context


func _set_if_found(context: Variant, key: String, value: Variant) -> void:
	if context == null or key.is_empty() or value == null:
		return
	if value is Object and not is_instance_valid(value):
		return
	context.set_service(key, value)


func inject_into_known_services(context: Variant) -> void:
	if context == null:
		return

	_bind_if_supported(context.get_world(), context)
	_bind_if_supported(context.get_player(), context)
	_bind_if_supported(context.get_day_night_system(), context)
	_bind_if_supported(context.get_ecosystem_director(), context)
	_bind_if_supported(context.get_evolution_director(), context)
	_bind_if_supported(context.get_save_system(), context)

	var snapshot_service: Variant = context.get_snapshot_service()
	_bind_if_supported(snapshot_service, context)


func _bind_if_supported(value: Variant, context: Variant) -> void:
	if value == null:
		return
	if not is_instance_valid(value):
		return
	if value.has_method("bind_runtime_context"):
		value.bind_runtime_context(context)


func _find_world(tree: SceneTree, current_scene: Node) -> Node:
	if current_scene != null:
		var direct := _find_named_node(current_scene, "World")
		if direct != null:
			return direct
	var grouped := tree.get_first_node_in_group("world")
	if grouped != null:
		return grouped
	return null


func _find_player(tree: SceneTree, current_scene: Node) -> Node:
	if current_scene != null:
		var direct := _find_named_node(current_scene, "Player")
		if direct != null:
			return direct
	var grouped := tree.get_first_node_in_group("player")
	if grouped != null:
		return grouped
	return null


func _find_named_node(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	if root.name == node_name:
		return root
	var direct := root.get_node_or_null(node_name)
	if direct != null:
		return direct
	return _find_named_node_recursive(root, node_name)


func _find_named_node_recursive(root: Node, node_name: String) -> Node:
	for child in root.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		if child_node.name == node_name:
			return child_node
		var found := _find_named_node_recursive(child_node, node_name)
		if found != null:
			return found
	return null
