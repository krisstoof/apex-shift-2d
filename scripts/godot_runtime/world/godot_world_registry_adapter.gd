class_name GodotWorldRegistryAdapter
extends RefCounted

const CORE_REGISTRY_SCRIPT := preload("res://scripts/core/world/world_entity_registry.gd")

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
	"meat_drop": "meat_drops",
	"item_drop": "item_drops"
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
	"item_drops": true,
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

var core_registry = CORE_REGISTRY_SCRIPT.new()
var spatial_index = null
var _biome_id_resolver := Callable()
var _node_refs_by_entity_id: Dictionary = {}
var _entity_id_by_instance_id: Dictionary = {}
var _registered_node_records_by_id: Dictionary = {}


func _init() -> void:
	spatial_index = core_registry.spatial_index


func set_biome_id_resolver(resolver: Callable) -> void:
	_biome_id_resolver = resolver


func register_resource(node: Node) -> void:
	var resource_kind := _get_resource_kind(node)
	var category := "meat" if resource_kind == "meat_drop" else "resource"
	if _register_node(node, category, resource_kind):
		resource_version += 1


func unregister_resource(node: Node) -> void:
	_unregister_node(node)
	resource_version += 1


func update_entity_cell(node: Node) -> void:
	if not _is_live_node_2d(node):
		return
	var entity_id := node.get_instance_id()
	core_registry.update_entity_position(entity_id, node.global_position)


func get_resources() -> Array:
	return _records_to_live_nodes(core_registry.get_entities(["resource", "meat"]))


func get_resources_by_kind(kind: String) -> Array:
	if kind.is_empty():
		return get_resources()
	var category_filter: Variant = ["resource", "meat"]
	if kind == "meat_drop":
		category_filter = "meat"
	return _records_to_live_nodes(core_registry.get_entities(category_filter, kind))


func get_resources_by_biome(biome_id: String) -> Array:
	return _records_to_live_nodes(core_registry.get_entities_by_biome(["resource", "meat"], biome_id))


func register_creature(node: Node, creature_type: String, _biome_id: String = "") -> void:
	if _register_node(node, "creature", creature_type):
		creature_version += 1


func unregister_creature(node: Node) -> void:
	_unregister_node(node)
	creature_version += 1


func get_creatures_by_type(creature_type: String) -> Array:
	return _records_to_live_nodes(core_registry.get_entities("creature", creature_type))


func get_creatures_by_biome(biome_id: String, creature_type: String = "") -> Array:
	return _records_to_live_nodes(core_registry.get_entities_by_biome("creature", biome_id, creature_type))


func register_building(node: Node, building_type: String) -> void:
	if _register_node(node, "building", building_type):
		building_version += 1


func unregister_building(node: Node) -> void:
	_unregister_node(node)
	building_version += 1


func get_buildings() -> Array:
	return _records_to_live_nodes(core_registry.get_entities("building"))


func get_buildings_by_type(building_type: String) -> Array:
	return _records_to_live_nodes(core_registry.get_entities("building", building_type))


func get_campfires() -> Array:
	return get_buildings_by_type("campfire")


func supports_group(group_name: String) -> bool:
	return SUPPORTED_RESOURCE_GROUPS.has(group_name) or SUPPORTED_CREATURE_GROUPS.has(group_name) or BUILDING_GROUP_TO_KIND.has(group_name)


func get_group_nodes(group_name: String) -> Array:
	if SUPPORTED_RESOURCE_GROUPS.has(group_name):
		return _get_resource_group_nodes(group_name)
	if SUPPORTED_CREATURE_GROUPS.has(group_name):
		return get_creatures_by_type(group_name)
	if BUILDING_GROUP_TO_KIND.has(group_name):
		return get_buildings_by_type(str(BUILDING_GROUP_TO_KIND[group_name]))
	return []


func get_resources_near(position: Vector2, radius: float, kind_filter: Variant = null) -> Array:
	return _records_to_live_nodes(core_registry.get_resources_near(position, radius, kind_filter))


func get_creatures_near(position: Vector2, radius: float, creature_type_filter: Variant = null) -> Array:
	return _records_to_live_nodes(core_registry.get_creatures_near(position, radius, creature_type_filter))


func get_meat_near(position: Vector2, radius: float) -> Array:
	return _records_to_live_nodes(core_registry.get_meat_near(position, radius))


func get_buildings_near(position: Vector2, radius: float, building_type_filter: Variant = null) -> Array:
	return _records_to_live_nodes(core_registry.get_buildings_near(position, radius, building_type_filter))


func get_resources_in_rect(rect: Rect2, kind_filter: Variant = null) -> Array:
	return _records_to_live_nodes(core_registry.get_resources_in_rect(rect, kind_filter))


func get_creatures_in_rect(rect: Rect2, creature_type_filter: Variant = null) -> Array:
	return _records_to_live_nodes(core_registry.get_creatures_in_rect(rect, creature_type_filter))


func get_meat_in_rect(rect: Rect2) -> Array:
	return _records_to_live_nodes(core_registry.get_meat_in_rect(rect))


func get_spatial_index_debug_data() -> Dictionary:
	var registry_debug := core_registry.get_debug_counts()
	var spatial_debug := Dictionary(registry_debug.get("spatial_index", {})).duplicate(true)
	if spatial_debug.is_empty() and core_registry.spatial_index != null and core_registry.spatial_index.has_method("get_debug_counts"):
		spatial_debug = core_registry.spatial_index.get_debug_counts()
	spatial_debug["registry_tracked_entities"] = int(registry_debug.get("tracked_entities", 0))
	spatial_debug["registry_resources_total"] = int(registry_debug.get("resources_total", 0))
	spatial_debug["registry_creatures_total"] = int(registry_debug.get("creatures_total", 0))
	spatial_debug["registry_buildings_total"] = int(registry_debug.get("buildings_total", 0))
	spatial_debug["registry_meat_total"] = int(registry_debug.get("meat_total", 0))
	spatial_debug["registry_resource_version"] = int(registry_debug.get("resource_version", 0))
	spatial_debug["registry_creature_version"] = int(registry_debug.get("creature_version", 0))
	spatial_debug["registry_building_version"] = int(registry_debug.get("building_version", 0))
	spatial_debug["registry_meat_version"] = int(registry_debug.get("meat_version", 0))
	return spatial_debug


func get_visibility_query_provider() -> RefCounted:
	return core_registry.get_visibility_query_provider()


func clear_runtime() -> void:
	core_registry.clear()
	_node_refs_by_entity_id.clear()
	_entity_id_by_instance_id.clear()
	_registered_node_records_by_id.clear()
	resource_version = 0
	creature_version = 0
	building_version = 0


func get_all_registered_resources() -> Array:
	return get_resources()


func get_all_registered_creatures() -> Array:
	return get_creatures_by_type("")


func get_all_registered_decorations() -> Array:
	return get_buildings()


func _register_node(node: Node, category: String, type_name: String) -> bool:
	if not _is_live_node_2d(node):
		return false
	var entity_id := node.get_instance_id()
	var node_2d := node as Node2D
	var position := node_2d.global_position
	var biome_id := _resolve_node_biome_id(node)
	var previous := Dictionary(_registered_node_records_by_id.get(entity_id, {}))
	if not previous.is_empty():
		var previous_category := str(previous.get("category", ""))
		var previous_type := str(previous.get("type_name", ""))
		var previous_position := Vector2(previous.get("position", Vector2.INF))
		var previous_biome_id := str(previous.get("biome_id", ""))
		if previous_category == category \
		and previous_type == type_name \
		and previous_position == position \
		and previous_biome_id == biome_id \
		and core_registry.has_entity(entity_id):
			return false
	var metadata := {
		"type": type_name,
		"kind": type_name,
		"payload": node,
		"node_ref": weakref(node),
		"instance_id": entity_id
	}
	_node_refs_by_entity_id[entity_id] = weakref(node)
	_entity_id_by_instance_id[entity_id] = entity_id
	core_registry.register_entity(entity_id, category, type_name, position, biome_id, metadata, true)
	_registered_node_records_by_id[entity_id] = {
		"category": category,
		"type_name": type_name,
		"position": position,
		"biome_id": biome_id
	}
	var tree_exited_callback := _on_registered_node_tree_exited.bind(entity_id)
	if not node.tree_exited.is_connected(tree_exited_callback):
		node.tree_exited.connect(tree_exited_callback, CONNECT_ONE_SHOT)
	return true


func _unregister_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	_remove_entry(node.get_instance_id())


func _remove_entry(entity_id: int) -> void:
	core_registry.unregister_entity(entity_id)
	_node_refs_by_entity_id.erase(entity_id)
	_entity_id_by_instance_id.erase(entity_id)
	_registered_node_records_by_id.erase(entity_id)


func _on_registered_node_tree_exited(entity_id: int) -> void:
	_remove_entry(entity_id)


func _records_to_live_nodes(records: Array) -> Array:
	var nodes: Array = []
	for record_value in records:
		var record := Dictionary(record_value)
		var entity_id: Variant = record.get("entity_id", null)
		var node: Variant = null
		if _node_refs_by_entity_id.has(entity_id):
			var node_ref := _node_refs_by_entity_id[entity_id] as WeakRef
			if node_ref != null:
				node = node_ref.get_ref()
		if node == null:
			var metadata := Dictionary(record.get("metadata", {}))
			var ref_value: Variant = metadata.get("node_ref", null)
			var node_ref := ref_value as WeakRef
			if node_ref != null:
				node = node_ref.get_ref()
		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		nodes.append(node)
	return nodes


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
		"item_drops":
			return get_resources_by_kind("item_drop")
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


func _is_live_node_2d(node: Node) -> bool:
	return node != null and is_instance_valid(node) and not node.is_queued_for_deletion() and node is Node2D
