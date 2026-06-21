extends RefCounted
class_name GodotRuntimeContextBuilder

const GodotRuntimeContext := preload("res://scripts/godot_adapters/runtime/godot_runtime_context.gd")


func build_from_scene_tree(tree: SceneTree) -> GodotRuntimeContext:
	var context := GodotRuntimeContext.new()
	if tree == null:
		return context
	var current_scene := tree.current_scene
	context.set_service(GodotRuntimeContext.KEY_WORLD, _find_world(tree, current_scene))
	context.set_service(GodotRuntimeContext.KEY_PLAYER, _find_player(tree, current_scene))
	context.set_service(GodotRuntimeContext.KEY_DAY_NIGHT_SYSTEM, _find_named_node(current_scene, "DayNightSystem"))
	context.set_service(GodotRuntimeContext.KEY_ECOSYSTEM_DIRECTOR, _find_named_node(current_scene, "EcosystemDirector"))
	context.set_service(GodotRuntimeContext.KEY_EVOLUTION_DIRECTOR, _find_named_node(current_scene, "EvolutionDirector"))
	context.set_service(GodotRuntimeContext.KEY_SAVE_SYSTEM, _find_named_node(current_scene, "SaveSystem"))
	context.set_service(GodotRuntimeContext.KEY_UI_ROOT, _find_named_node(current_scene, "UI"))
	context.set_service(GodotRuntimeContext.KEY_EVENT_BUS, tree.root.get_node_or_null("EventBus"))
	context.set_service(GodotRuntimeContext.KEY_GAME_SESSION, tree.root.get_node_or_null("GameSession"))
	return context


func inject_into_known_services(context: GodotRuntimeContext) -> void:
	if context == null:
		return
	for service in [context.get_world(), context.get_player(), context.get_day_night_system(), context.get_ecosystem_director(), context.get_evolution_director(), context.get_save_system()]:
		if _can_bind_runtime_context(service):
			service.bind_runtime_context(context)


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


func _can_bind_runtime_context(value: Variant) -> bool:
	if value == null:
		return false
	if not is_instance_valid(value):
		return false
	return value.has_method("bind_runtime_context")
