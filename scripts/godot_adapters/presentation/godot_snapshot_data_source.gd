extends RefCounted
class_name GodotSnapshotDataSource


func build_player_input(player: Node) -> Dictionary:
	var position := Vector2.ZERO
	if player != null and is_instance_valid(player) and player is Node2D:
		position = (player as Node2D).global_position
	return {
		"position": position,
		"health": _read_float(player, "health", 0.0),
		"hunger": _read_float(player, "hunger", 0.0),
		"stamina": _read_float(player, "stamina", 0.0),
		"rest": _read_float(player, "rest", 0.0),
		"condition_text": _call_string(player, "get_condition_text", ""),
		"prompt_text": _call_string(player, "get_prompt_text", ""),
		"campfire_regen_active": _read_bool(player, "campfire_regen_active", false),
		"campfire_regen_distance": _read_float(player, "campfire_regen_distance", -1.0),
		"inventory": build_inventory_input(player),
		"has_spear": _read_bool(player, "has_spear", false),
		"has_bow": _read_bool(player, "has_bow", false),
		"torch_active": _read_bool(player, "torch_active", false),
		"torch_remaining_seconds": _call_float(player, "get_torch_remaining_seconds", 0.0)
	}


func build_inventory_input(player: Node) -> Dictionary:
	var inventory: Variant = _read_variant(player, "inventory", null)
	if inventory == null:
		return {"wood": 0, "stone": 0, "fiber": 0, "meat": 0, "hide": 0, "bone": 0, "torch": 0}
	return {
		"wood": _read_inventory_amount(inventory, "wood"),
		"stone": _read_inventory_amount(inventory, "stone"),
		"fiber": _read_inventory_amount(inventory, "fiber"),
		"meat": _read_inventory_amount(inventory, "meat"),
		"hide": _read_inventory_amount(inventory, "hide"),
		"bone": _read_inventory_amount(inventory, "bone"),
		"torch": _read_inventory_amount(inventory, "torch")
	}


func build_time_input(day_night_system: Node) -> Dictionary:
	var time_label := _call_string(day_night_system, "get_time_label", "")
	return {
		"day": _call_int(day_night_system, "get_day", 1),
		"clock_time": _call_string(day_night_system, "get_clock_time", "--:--"),
		"time_label": time_label,
		"phase_label": _resolve_phase_label(time_label),
		"night_amount": _call_float(day_night_system, "get_night_amount", 0.0)
	}


func build_world_input(world: Node, player_position: Vector2) -> Dictionary:
	if world == null or not is_instance_valid(world):
		return {}
	return {
		"world_rect": _call_variant(world, "get_world_rect", Rect2()),
		"biome_zones": _call_array(world, "get_biome_zones"),
		"landmarks": _call_array(world, "get_landmarks"),
		"landmark_counts": _call_dictionary(world, "get_landmark_counts"),
		"world_seed": _call_int(world, "get_world_seed", 0),
		"current_biome_name": _resolve_current_biome_name(world, player_position),
		"current_biome_texture_id": _call_with_position_string(world, "get_current_biome_texture_id", player_position, "none"),
		"nearest_landmark": _call_with_position_dictionary(world, "get_nearest_landmark_data", player_position),
		"out_of_bounds_count": _call_int(world, "get_creatures_out_of_bounds_count", 0),
		"resource_counts": build_resource_counts(world),
		"building_counts": build_building_counts(world),
		"biome_texture_cache": _call_dictionary(world, "get_biome_texture_cache_status"),
		"small_prey_spawn_sync": _call_dictionary(world, "get_small_prey_spawn_sync_debug"),
		"varnak_spawn_sync": _call_dictionary(world, "get_varnak_spawn_sync_debug"),
		"varnak_population": _call_dictionary(world, "get_varnak_population_status"),
		"creature_ai_state_counts": build_creature_ai_state_counts(world),
		"visibility_culling": _call_dictionary(world, "get_visibility_culling_debug"),
		"vegetation_spawn": _call_dictionary(world, "get_vegetation_spawn_debug_summary"),
		"runtime_context": _call_dictionary(world, "get_runtime_context_debug_status"),
		"landmark_overlay_enabled": _call_bool(world, "is_landmark_debug_overlay_enabled", false),
		"biome_textures_enabled": _call_bool(world, "are_biome_textures_enabled", true),
		"biome_terrain_accents_enabled": _call_bool(world, "are_biome_terrain_accents_enabled", false),
		"low_end_rendering": _call_bool(world, "is_low_end_rendering_enabled", false)
	}


func build_marker_input(world: Node) -> Dictionary:
	if world == null or not is_instance_valid(world):
		return {"resources": [], "campfires": [], "varnaks": [], "small_prey": [], "grazers": []}
	return {
		"resources": build_resource_markers_from_nodes(_get_world_group_nodes(world, "resources")),
		"campfires": build_campfire_markers_from_nodes(_get_world_group_nodes(world, "campfires")),
		"varnaks": build_creature_markers_from_nodes(_get_world_creatures(world, "varnak"), "varnak"),
		"small_prey": build_creature_markers_from_nodes(_get_world_creatures(world, "small_prey"), "small_prey"),
		"grazers": build_creature_markers_from_nodes(_get_world_creatures(world, "grazer"), "grazer")
	}


func build_resource_markers_from_nodes(nodes: Array) -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	for node_value in nodes:
		var node := node_value as Node
		if not _is_valid_node2d(node):
			continue
		var node_2d := node as Node2D
		markers.append({
			"position": node_2d.global_position,
			"type": _get_resource_kind(node),
			"kind": _get_resource_kind(node),
			"biome_id": _get_biome_id(node),
			"depleted": _read_bool(node, "depleted", false),
			"growth_stage": _read_int(node, "growth_stage", 0)
		})
	return markers


func build_campfire_markers_from_nodes(nodes: Array) -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	for node_value in nodes:
		var node := node_value as Node
		if not _is_valid_node2d(node):
			continue
		var node_2d := node as Node2D
		markers.append({
			"position": node_2d.global_position,
			"type": "campfire",
			"active": _read_bool(node, "active", _call_bool(node, "is_active", false))
		})
	return markers


func build_creature_markers_from_nodes(nodes: Array, creature_type: String) -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	for node_value in nodes:
		var node := node_value as Node
		if not _is_valid_node2d(node):
			continue
		var node_2d := node as Node2D
		markers.append({
			"position": node_2d.global_position,
			"type": creature_type,
			"state": _get_ai_state(node),
			"biome_id": _get_biome_id(node)
		})
	return markers


func build_resource_counts(world: Node) -> Dictionary:
	return {
		"trees": _get_world_group_count(world, "trees"),
		"bushes": _get_world_group_count(world, "bushes"),
		"grass": _get_world_group_count(world, "grass"),
		"rocks": _get_world_group_count(world, "rocks"),
		"pond_vegetation": _get_world_group_count(world, "pond_vegetation")
	}


func build_building_counts(world: Node) -> Dictionary:
	return {
		"campfires": _get_world_group_count(world, "campfires"),
		"traps": _get_world_group_count(world, "traps"),
		"walls": _get_world_group_count(world, "walls"),
		"storage_boxes": _get_world_group_count(world, "storage_boxes"),
		"tents": _get_world_group_count(world, "tents")
	}


func build_creature_ai_state_counts(world: Node) -> Dictionary:
	return {
		"small_prey": _count_ai_states(_get_world_creatures(world, "small_prey")),
		"grazer": _count_ai_states(_get_world_creatures(world, "grazer")),
		"varnak": _count_ai_states(_get_world_creatures(world, "varnak"))
	}


func _get_world_group_count(world: Node, group_name: String) -> int:
	if world == null or not is_instance_valid(world):
		return 0
	if world.has_method("get_cached_group_nodes"):
		return Array(world.call("get_cached_group_nodes", group_name)).size()
	if world.has_method("get_group_nodes"):
		return Array(world.call("get_group_nodes", group_name)).size()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return 0
	return tree.get_nodes_in_group(group_name).size()


func _get_world_group_nodes(world: Node, group_name: String) -> Array:
	if world == null or not is_instance_valid(world):
		return []
	if world.has_method("get_cached_group_nodes"):
		return Array(world.call("get_cached_group_nodes", group_name))
	if world.has_method("get_group_nodes"):
		return Array(world.call("get_group_nodes", group_name))
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return []
	return tree.get_nodes_in_group(group_name)


func _get_world_creatures(world: Node, creature_type: String) -> Array:
	if world == null or not is_instance_valid(world):
		return []
	if world.has_method("get_registered_creatures_by_type"):
		return Array(world.call("get_registered_creatures_by_type", creature_type))
	return _get_world_group_nodes(world, creature_type)


func _count_ai_states(nodes: Array) -> Dictionary:
	var result := {}
	for node_value in nodes:
		var node := node_value as Node
		if node == null or not is_instance_valid(node):
			continue
		var state := _get_ai_state(node)
		if state.is_empty():
			state = "unknown"
		result[state] = int(result.get(state, 0)) + 1
	return result


func _get_resource_kind(node: Node) -> String:
	if node == null:
		return "unknown"
	if _has_property(node, "resource_kind"):
		return str(node.get("resource_kind"))
	if node.has_method("get_resource_kind"):
		return str(node.call("get_resource_kind"))
	return "unknown"


func _get_ai_state(node: Node) -> String:
	if node == null:
		return ""
	if _has_property(node, "current_ai_state"):
		return str(node.get("current_ai_state"))
	if node.has_method("get_ai_state"):
		return str(node.call("get_ai_state"))
	if node.has_method("get_current_ai_state"):
		return str(node.call("get_current_ai_state"))
	return ""


func _get_biome_id(node: Node) -> String:
	if node == null:
		return ""
	if node.has_meta("biome_id"):
		return str(node.get_meta("biome_id"))
	if _has_property(node, "biome_id"):
		return str(node.get("biome_id"))
	return ""


func _resolve_current_biome_name(world: Node, position: Vector2) -> String:
	if world == null or not is_instance_valid(world):
		return ""
	if world.has_method("get_current_biome_name"):
		return str(world.call("get_current_biome_name", position))
	if world.has_method("get_biome_name_for_position"):
		return str(world.call("get_biome_name_for_position", position))
	return ""


func _resolve_phase_label(time_label: String) -> String:
	var normalized := time_label.to_lower()
	if normalized.contains("night"):
		return "Night"
	if normalized.contains("dawn"):
		return "Dawn"
	if normalized.contains("dusk"):
		return "Dusk"
	if normalized.contains("evening"):
		return "Evening"
	if normalized.contains("morning"):
		return "Morning"
	if normalized.contains("noon") or normalized.contains("day"):
		return "Day"
	return time_label


func _is_valid_node2d(node: Node) -> bool:
	return node != null and is_instance_valid(node) and not node.is_queued_for_deletion() and node is Node2D


func _read_inventory_amount(inventory: Variant, item_id: String) -> int:
	if inventory == null:
		return 0
	if inventory.has_method("get_amount"):
		return int(inventory.call("get_amount", item_id))
	if inventory.has_method("get_item_count"):
		return int(inventory.call("get_item_count", item_id))
	if inventory.has_method("count"):
		return int(inventory.call("count", item_id))
	return 0


func _read_variant(node: Node, property_name: String, default_value: Variant = null) -> Variant:
	if node == null or not is_instance_valid(node):
		return default_value
	if not _has_property(node, property_name):
		return default_value
	return node.get(property_name)


func _read_float(node: Node, property_name: String, default_value: float = 0.0) -> float:
	return float(_read_variant(node, property_name, default_value))


func _read_int(node: Node, property_name: String, default_value: int = 0) -> int:
	return int(_read_variant(node, property_name, default_value))


func _read_bool(node: Node, property_name: String, default_value: bool = false) -> bool:
	return bool(_read_variant(node, property_name, default_value))


func _call_variant(node: Node, method_name: String, default_value: Variant = null) -> Variant:
	if node == null or not is_instance_valid(node):
		return default_value
	if not node.has_method(method_name):
		return default_value
	return node.call(method_name)


func _call_array(node: Node, method_name: String) -> Array:
	return Array(_call_variant(node, method_name, []))


func _call_dictionary(node: Node, method_name: String) -> Dictionary:
	return Dictionary(_call_variant(node, method_name, {}))


func _call_string(node: Node, method_name: String, default_value: String = "") -> String:
	return str(_call_variant(node, method_name, default_value))


func _call_int(node: Node, method_name: String, default_value: int = 0) -> int:
	return int(_call_variant(node, method_name, default_value))


func _call_float(node: Node, method_name: String, default_value: float = 0.0) -> float:
	return float(_call_variant(node, method_name, default_value))


func _call_bool(node: Node, method_name: String, default_value: bool = false) -> bool:
	return bool(_call_variant(node, method_name, default_value))


func _call_with_position_string(node: Node, method_name: String, position: Vector2, default_value: String = "") -> String:
	if node == null or not is_instance_valid(node) or not node.has_method(method_name):
		return default_value
	return str(node.call(method_name, position))


func _call_with_position_dictionary(node: Node, method_name: String, position: Vector2) -> Dictionary:
	if node == null or not is_instance_valid(node) or not node.has_method(method_name):
		return {}
	return Dictionary(node.call(method_name, position))


func _has_property(object: Object, property_name: String) -> bool:
	if object == null:
		return false
	for property_data in object.get_property_list():
		var data := Dictionary(property_data)
		if str(data.get("name", "")) == property_name:
			return true
	return false
