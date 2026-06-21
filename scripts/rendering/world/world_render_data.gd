extends RefCounted
class_name WorldRenderData

var visible_rect := Rect2()
var world_rect := Rect2()
var world_seed := 0
var biome_zones: Array[Dictionary] = []
var topography_features: Array[Dictionary] = []
var terrain_chunks: Array[Dictionary] = []
var water_features: Array[Dictionary] = []
var resource_visuals: Array[Dictionary] = []
var creature_visuals: Array[Dictionary] = []
var building_visuals: Array[Dictionary] = []
var render_flags: Dictionary = {}
var debug_data: Dictionary = {}


static func from_world(world: Node, p_visible_rect: Rect2 = Rect2()) -> WorldRenderData:
	var data := WorldRenderData.new()
	data.capture_from_world(world, p_visible_rect)
	return data


func capture_from_world(world: Node, p_visible_rect: Rect2 = Rect2()) -> void:
	visible_rect = p_visible_rect
	world_rect = _read_world_rect(world)
	if visible_rect.size == Vector2.ZERO:
		visible_rect = world_rect
	world_seed = _read_int(world, "get_world_seed", 0)
	biome_zones = _read_dictionary_array(world, "get_biome_zones")
	topography_features = _read_dictionary_array(world, "get_topography_features")
	water_features = _extract_water_features(topography_features)
	terrain_chunks = _build_terrain_chunks(world)
	resource_visuals = _capture_resource_visuals(world)
	creature_visuals = _capture_creature_visuals(world)
	building_visuals = _capture_building_visuals(world)
	render_flags = _capture_render_flags(world)
	debug_data = {
		"visible_rect": _rect_to_data(visible_rect),
		"world_rect": _rect_to_data(world_rect),
		"world_seed": world_seed,
		"biome_count": biome_zones.size(),
		"topography_feature_count": topography_features.size(),
		"water_feature_count": water_features.size(),
		"terrain_chunk_count": terrain_chunks.size(),
		"resource_visual_count": resource_visuals.size(),
		"creature_visual_count": creature_visuals.size(),
		"building_visual_count": building_visuals.size()
	}


func to_debug_data() -> Dictionary:
	return debug_data.duplicate(true)


func has_visible_rect() -> bool:
	return visible_rect.size.x > 0.0 and visible_rect.size.y > 0.0


func get_visible_biome_ids() -> Array[String]:
	var ids: Array[String] = []
	for biome in biome_zones:
		var biome_id := str(biome.get("id", biome.get("biome_id", "")))
		if biome_id.is_empty():
			continue
		var bounds := _dictionary_bounds_to_rect(biome)
		if bounds.size != Vector2.ZERO and not bounds.intersects(visible_rect):
			continue
		if not ids.has(biome_id):
			ids.append(biome_id)
	return ids


func get_resource_visuals_by_kind(kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for visual in resource_visuals:
		if str(visual.get("kind", "")) == kind:
			result.append(visual.duplicate(true))
	return result


func get_creature_visuals_by_type(creature_type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for visual in creature_visuals:
		if str(visual.get("type", "")) == creature_type:
			result.append(visual.duplicate(true))
	return result


static func _read_world_rect(world: Node) -> Rect2:
	if world != null and world.has_method("get_world_rect"):
		return Rect2(world.call("get_world_rect"))
	return Rect2()


static func _read_int(world: Node, method_name: String, fallback: int) -> int:
	if world != null and world.has_method(method_name):
		return int(world.call(method_name))
	return fallback


static func _read_dictionary_array(world: Node, method_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if world == null or not world.has_method(method_name):
		return result
	for value in Array(world.call(method_name)):
		if typeof(value) == TYPE_DICTIONARY:
			result.append(Dictionary(value).duplicate(true))
	return result


static func _extract_water_features(features: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for feature in features:
		var feature_type := str(feature.get("type", feature.get("feature_type", "")))
		if feature_type == "pond" or feature_type == "water":
			result.append(feature.duplicate(true))
	return result


static func _build_terrain_chunks(world: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if world == null:
		return result
	for biome_value in Array(world.call("get_biome_zones")) if world.has_method("get_biome_zones") else []:
		if typeof(biome_value) != TYPE_DICTIONARY:
			continue
		var biome := Dictionary(biome_value)
		result.append({
			"kind": "biome_region",
			"biome_id": str(biome.get("id", biome.get("biome_id", ""))),
			"bounds": _rect_to_data(_dictionary_bounds_to_rect(biome)),
			"points": Array(biome.get("points", [])).duplicate(true)
		})
	return result


static func _capture_resource_visuals(world: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var resources := _read_node_array(world, "get_registered_resources")
	if resources.is_empty() and world != null and world.has_method("get_cached_group_nodes"):
		resources = Array(world.call("get_cached_group_nodes", "resources"))
	for node in resources:
		if not _is_live_node_2d(node):
			continue
		result.append({
			"kind": _read_node_string(node, "get_resource_kind", "resource_kind", ""),
			"position": (node as Node2D).global_position,
			"visible": bool(node.get("visible")),
			"render_only": bool(node.get("render_only")) if node.get("render_only") != null else false,
			"biome_id": str(node.get("biome_id")) if node.get("biome_id") != null else ""
		})
	return result


static func _capture_creature_visuals(world: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for creature_type in ["small_prey", "grazer", "varnak"]:
		var creatures := _read_node_array_with_arg(world, "get_registered_creatures_by_type", creature_type)
		for node in creatures:
			if not _is_live_node_2d(node):
				continue
			result.append({
				"type": creature_type,
				"position": (node as Node2D).global_position,
				"visible": bool(node.get("visible")),
				"state": str(node.get("state")) if node.get("state") != null else "",
				"biome_id": str(node.get("biome_id")) if node.get("biome_id") != null else str(node.get("population_biome_id"))
			})
	return result


static func _capture_building_visuals(world: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var buildings := _read_node_array(world, "get_registered_buildings")
	if buildings.is_empty() and world != null and world.has_method("get_tree"):
		var tree := world.get_tree()
		if tree != null:
			for group_name in ["campfires", "traps", "walls", "storage_boxes", "tents"]:
				buildings.append_array(tree.get_nodes_in_group(group_name))
	for node in buildings:
		if not _is_live_node_2d(node):
			continue
		result.append({
			"kind": _resolve_building_kind(node),
			"position": (node as Node2D).global_position,
			"visible": bool(node.get("visible"))
		})
	return result


static func _capture_render_flags(world: Node) -> Dictionary:
	return {
		"biome_textures_enabled": bool(world.call("are_biome_textures_enabled")) if world != null and world.has_method("are_biome_textures_enabled") else false,
		"biome_terrain_accents_enabled": bool(world.call("are_biome_terrain_accents_enabled")) if world != null and world.has_method("are_biome_terrain_accents_enabled") else false,
		"low_end_rendering_enabled": bool(world.call("is_low_end_rendering_enabled")) if world != null and world.has_method("is_low_end_rendering_enabled") else false
	}


static func _read_node_array(world: Node, method_name: String) -> Array:
	if world != null and world.has_method(method_name):
		return Array(world.call(method_name))
	return []


static func _read_node_array_with_arg(world: Node, method_name: String, arg: Variant) -> Array:
	if world != null and world.has_method(method_name):
		return Array(world.call(method_name, arg))
	return []


static func _is_live_node_2d(node: Variant) -> bool:
	return node is Node2D and is_instance_valid(node) and not node.is_queued_for_deletion()


static func _read_node_string(node: Node, method_name: String, property_name: String, fallback: String) -> String:
	if node.has_method(method_name):
		return str(node.call(method_name))
	var value = node.get(property_name)
	return fallback if value == null else str(value)


static func _resolve_building_kind(node: Node) -> String:
	for group_name in ["campfires", "traps", "walls", "storage_boxes", "tents"]:
		if node.is_in_group(group_name):
			return group_name.trim_suffix("s")
	return str(node.get("building_kind")) if node.get("building_kind") != null else ""


static func _dictionary_bounds_to_rect(data: Dictionary) -> Rect2:
	if data.has("bounds") and data.get("bounds") is Rect2:
		return Rect2(data.get("bounds"))
	if data.has("rect") and data.get("rect") is Rect2:
		return Rect2(data.get("rect"))
	if data.has("position") and data.has("size"):
		return Rect2(Vector2(data.get("position")), Vector2(data.get("size")))
	return Rect2()


static func _rect_to_data(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y}
