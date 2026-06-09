extends RefCounted
class_name WorldRegistry

const WORLD_SPATIAL_INDEX_SCRIPT := preload("res://scripts/world/world_spatial_index.gd")
const RESOURCE_GROUPS_BY_KIND := {
	"conifer_tree": "trees",
	"leafy_tree": "trees",
	"tree": "trees",
	"bush": "bushes",
	"dry_bush": "bushes",
	"small_bush": "bushes",
	"berry_bush": "bushes",
	"grass_patch": "grass",
	"dense_grass": "grass",
	"rock": "rocks",
	"meat_drop": "meat_drops"
}
const BUILDING_GROUP_TO_KIND := {
	"campfires": "campfire",
	"traps": "trap",
	"walls": "wall",
	"storage_boxes": "storage_box",
	"tents": "tent"
}
const SUPPORTED_RESOURCE_GROUPS := {
	"resources": true,
	"trees": true,
	"bushes": true,
	"grass": true,
	"rocks": true,
	"meat_drops": true,
	"edible_vegetation": true,
	"pond_vegetation": true
}
const SUPPORTED_CREATURE_GROUPS := {
	"varnak": true,
	"small_prey": true,
	"grazer": true
}

var resource_version := 0
var creature_version := 0
var building_version := 0

var _biome_id_resolver := Callable()
var spatial_index = WORLD_SPATIAL_INDEX_SCRIPT.new()
var _resource_nodes: Array[Node] = []
var _creature_nodes_by_type: Dictionary = {}
var _building_nodes_by_type: Dictionary = {}
var _tracked_entries: Dictionary = {}


func set_biome_id_resolver(resolver: Callable) -> void:
	_biome_id_resolver = resolver


func register_resource(node: Node) -> void:
	_register_node(node, "resource", _get_resource_kind(node))


func unregister_resource(node: Node) -> void:
	_unregister_node(node)


func update_entity_cell(node: Node) -> void:
	if spatial_index != null:
		spatial_index.update_entity_cell(node)


func get_resources() -> Array:
	return _get_live_nodes(_resource_nodes)


func get_resources_by_kind(kind: String) -> Array:
	if kind.is_empty():
		return get_resources()
	var filtered: Array = []
	for resource in get_resources():
		if _get_resource_kind(resource) == kind:
			filtered.append(resource)
	return filtered


func get_resources_by_biome(biome_id: String) -> Array:
	return _filter_nodes_by_biome(get_resources(), biome_id)


func register_creature(node: Node, creature_type: String, _biome_id: String = "") -> void:
	_register_node(node, "creature", creature_type)


func unregister_creature(node: Node) -> void:
	_unregister_node(node)


func get_creatures_by_type(creature_type: String) -> Array:
	if creature_type.is_empty():
		var all_creatures: Array = []
		for typed_nodes in _creature_nodes_by_type.values():
			all_creatures.append_array(_get_live_nodes(Array(typed_nodes)))
		return all_creatures
	if not _creature_nodes_by_type.has(creature_type):
		return []
	return _get_live_nodes(Array(_creature_nodes_by_type.get(creature_type, [])))


func get_creatures_by_biome(biome_id: String, creature_type: String = "") -> Array:
	return _filter_nodes_by_biome(get_creatures_by_type(creature_type), biome_id)


func register_building(node: Node, building_type: String) -> void:
	_register_node(node, "building", building_type)


func unregister_building(node: Node) -> void:
	_unregister_node(node)


func get_buildings() -> Array:
	var all_buildings: Array = []
	for typed_nodes in _building_nodes_by_type.values():
		all_buildings.append_array(_get_live_nodes(Array(typed_nodes)))
	return all_buildings


func get_buildings_by_type(building_type: String) -> Array:
	if building_type.is_empty():
		return get_buildings()
	if not _building_nodes_by_type.has(building_type):
		return []
	return _get_live_nodes(Array(_building_nodes_by_type.get(building_type, [])))


func get_campfires() -> Array:
	return get_buildings_by_type("campfire")


func supports_group(group_name: String) -> bool:
	return (
		SUPPORTED_RESOURCE_GROUPS.has(group_name)
		or SUPPORTED_CREATURE_GROUPS.has(group_name)
		or BUILDING_GROUP_TO_KIND.has(group_name)
	)


func get_group_nodes(group_name: String) -> Array:
	if SUPPORTED_RESOURCE_GROUPS.has(group_name):
		return _get_resource_group_nodes(group_name)
	if SUPPORTED_CREATURE_GROUPS.has(group_name):
		return get_creatures_by_type(group_name)
	if BUILDING_GROUP_TO_KIND.has(group_name):
		return get_buildings_by_type(str(BUILDING_GROUP_TO_KIND[group_name]))
	return []


func get_resources_near(position: Vector2, radius: float, kind_filter: Variant = null) -> Array:
	if spatial_index == null:
		return get_resources_by_kind(str(kind_filter)) if kind_filter != null and typeof(kind_filter) == TYPE_STRING else get_resources()
	return spatial_index.query_resources_near(position, radius, kind_filter)


func get_creatures_near(position: Vector2, radius: float, creature_type_filter: Variant = null) -> Array:
	if spatial_index == null:
		return get_creatures_by_type(str(creature_type_filter)) if creature_type_filter != null and typeof(creature_type_filter) == TYPE_STRING else get_creatures_by_type("")
	return spatial_index.query_creatures_near(position, radius, creature_type_filter)


func get_meat_near(position: Vector2, radius: float) -> Array:
	if spatial_index == null:
		return get_resources_by_kind("meat_drop")
	return spatial_index.query_meat_near(position, radius)


func get_resources_in_rect(rect: Rect2, kind_filter: Variant = null) -> Array:
	if spatial_index == null:
		return []
	return spatial_index.query_resources_in_rect(rect, kind_filter)


func get_creatures_in_rect(rect: Rect2, creature_type_filter: Variant = null) -> Array:
	if spatial_index == null:
		return []
	return spatial_index.query_creatures_in_rect(rect, creature_type_filter)


func get_meat_in_rect(rect: Rect2) -> Array:
	if spatial_index == null:
		return []
	return spatial_index.query_meat_in_rect(rect)


func _register_node(node: Node, category: String, type_name: String) -> void:
	if not is_instance_valid(node):
		return
	var instance_id := node.get_instance_id()
	if _tracked_entries.has(instance_id):
		var existing_entry := Dictionary(_tracked_entries[instance_id])
		if str(existing_entry.get("category", "")) == category and str(existing_entry.get("type_name", "")) == type_name:
			return
		_remove_entry(instance_id)
	var entry := {
		"node": node,
		"category": category,
		"type_name": type_name
	}
	_tracked_entries[instance_id] = entry
	match category:
		"resource":
			_resource_nodes.append(node)
			resource_version += 1
		"creature":
			if not _creature_nodes_by_type.has(type_name):
				_creature_nodes_by_type[type_name] = []
			var creature_nodes: Array = Array(_creature_nodes_by_type[type_name])
			creature_nodes.append(node)
			_creature_nodes_by_type[type_name] = creature_nodes
			creature_version += 1
		"building":
			if not _building_nodes_by_type.has(type_name):
				_building_nodes_by_type[type_name] = []
			var building_nodes: Array = Array(_building_nodes_by_type[type_name])
			building_nodes.append(node)
			_building_nodes_by_type[type_name] = building_nodes
			building_version += 1
	if spatial_index != null:
		var spatial_category := category
		var spatial_type := type_name
		if category == "resource" and type_name == "meat_drop":
			spatial_category = "meat"
		spatial_index.register_entity(node, spatial_category, spatial_type)
	node.tree_exited.connect(_on_registered_node_tree_exited.bind(instance_id), CONNECT_ONE_SHOT)


func _unregister_node(node: Node) -> void:
	if not is_instance_valid(node):
		return
	_remove_entry(node.get_instance_id())


func _remove_entry(instance_id: int) -> void:
	if not _tracked_entries.has(instance_id):
		return
	var entry := Dictionary(_tracked_entries[instance_id])
	var node := entry.get("node") as Node
	var category := str(entry.get("category", ""))
	var type_name := str(entry.get("type_name", ""))
	match category:
		"resource":
			_remove_node_from_array(_resource_nodes, node)
			resource_version += 1
		"creature":
			if _creature_nodes_by_type.has(type_name):
				var creature_nodes: Array = Array(_creature_nodes_by_type[type_name])
				_remove_node_from_array(creature_nodes, node)
				_creature_nodes_by_type[type_name] = creature_nodes
			creature_version += 1
		"building":
			if _building_nodes_by_type.has(type_name):
				var building_nodes: Array = Array(_building_nodes_by_type[type_name])
				_remove_node_from_array(building_nodes, node)
				_building_nodes_by_type[type_name] = building_nodes
			building_version += 1
	if spatial_index != null and node != null:
		spatial_index.unregister_entity(node)
	_tracked_entries.erase(instance_id)


func _remove_node_from_array(nodes: Array, target_node: Node) -> void:
	for index in range(nodes.size() - 1, -1, -1):
		if nodes[index] == target_node:
			nodes.remove_at(index)


func _on_registered_node_tree_exited(instance_id: int) -> void:
	_remove_entry(instance_id)


func _get_live_nodes(nodes: Array) -> Array:
	var live_nodes: Array = []
	var stale_instance_ids: Array[int] = []
	for node_value in nodes:
		var node := node_value as Node
		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
			if node != null and is_instance_valid(node):
				stale_instance_ids.append(node.get_instance_id())
			continue
		live_nodes.append(node)
	for stale_instance_id in stale_instance_ids:
		_remove_entry(stale_instance_id)
	return live_nodes


func _filter_nodes_by_biome(nodes: Array, biome_id: String) -> Array:
	if biome_id.is_empty():
		return nodes
	var filtered: Array = []
	for node_value in nodes:
		var node := node_value as Node
		if _resolve_node_biome_id(node) == biome_id:
			filtered.append(node)
	return filtered


func _resolve_node_biome_id(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return ""
	var direct_biome_id := str(node.get("biome_id"))
	if not direct_biome_id.is_empty():
		return direct_biome_id
	var population_biome_id := str(node.get("population_biome_id"))
	if not population_biome_id.is_empty():
		return population_biome_id
	var home_biome_id := str(node.get("home_biome_id"))
	if not home_biome_id.is_empty():
		return home_biome_id
	var node_2d := node as Node2D
	if node_2d != null and _biome_id_resolver.is_valid():
		return str(_biome_id_resolver.call(node_2d.global_position))
	return ""


func _get_resource_kind(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return ""
	return str(node.get("resource_kind"))


func _get_resource_group_nodes(group_name: String) -> Array:
	match group_name:
		"resources":
			return get_resources()
		"edible_vegetation":
			return _filter_resources(func(resource: Node) -> bool:
				return resource.get("is_edible_by_herbivores") == true
			)
		"pond_vegetation":
			return _filter_resources(func(resource: Node) -> bool:
				return resource.get("is_pond_vegetation") == true
			)
		"meat_drops":
			return get_resources_by_kind("meat_drop")
		"trees", "bushes", "grass", "rocks":
			return _filter_resources(func(resource: Node) -> bool:
				return str(RESOURCE_GROUPS_BY_KIND.get(_get_resource_kind(resource), "")) == group_name
			)
	return []


func _filter_resources(predicate: Callable) -> Array:
	var filtered: Array = []
	for resource in get_resources():
		if predicate.call(resource):
			filtered.append(resource)
	return filtered
