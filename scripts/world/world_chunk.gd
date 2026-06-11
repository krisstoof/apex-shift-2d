extends RefCounted
class_name WorldChunk

var chunk_coord: Vector2i = Vector2i.ZERO
var world_rect: Rect2 = Rect2()
var is_active := false
var terrain_data: Dictionary = {}
var water_data: Dictionary = {}
var biome_data: Dictionary = {}
var landmarks: Array[Dictionary] = []
var resources: Array[Node] = []
var creatures: Array[Node] = []
var decorations: Array[Node] = []


func configure(p_chunk_coord: Vector2i, p_world_rect: Rect2) -> void:
	chunk_coord = p_chunk_coord
	world_rect = p_world_rect


func add_entity(entity: Node, entity_group: String) -> void:
	if not is_instance_valid(entity):
		return
	if _contains_entity(entity):
		return
	match entity_group:
		"resources":
			resources.append(entity)
		"creatures":
			creatures.append(entity)
		_:
			decorations.append(entity)


func remove_entity(entity: Node) -> void:
	_remove_from_array(resources, entity)
	_remove_from_array(creatures, entity)
	_remove_from_array(decorations, entity)


func cleanup_invalid_refs() -> void:
	_filter_live_nodes(resources)
	_filter_live_nodes(creatures)
	_filter_live_nodes(decorations)


func get_entity_count() -> int:
	cleanup_invalid_refs()
	return resources.size() + creatures.size() + decorations.size()


func set_active(active: bool) -> void:
	is_active = active


func get_debug_data() -> Dictionary:
	cleanup_invalid_refs()
	return {
		"chunk_coord": chunk_coord,
		"world_rect": world_rect,
		"is_active": is_active,
		"terrain_data": terrain_data,
		"water_data": water_data,
		"biome_data": biome_data,
		"landmarks": landmarks.size(),
		"resources": resources.size(),
		"creatures": creatures.size(),
		"decorations": decorations.size()
	}


func _get_live_nodes(nodes: Array) -> Array:
	var live_nodes: Array = []
	for node_value in nodes:
		if typeof(node_value) != TYPE_OBJECT:
			continue
		if not is_instance_valid(node_value):
			continue
		var node := node_value as Node
		if node == null or node.is_queued_for_deletion():
			continue
		live_nodes.append(node)
	return live_nodes


func _filter_live_nodes(nodes: Array) -> void:
	var live_nodes: Array = _get_live_nodes(nodes)
	nodes.clear()
	nodes.append_array(live_nodes)


func _remove_from_array(nodes: Array, target: Node) -> void:
	for index in range(nodes.size() - 1, -1, -1):
		if nodes[index] == target:
			nodes.remove_at(index)


func _contains_entity(entity: Node) -> bool:
	return entity in resources or entity in creatures or entity in decorations
