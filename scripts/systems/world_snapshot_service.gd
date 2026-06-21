extends RefCounted
class_name WorldSnapshotService

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const WorldSnapshotBuilder := preload("res://scripts/core/presentation/world_snapshot_builder.gd")
const GodotSnapshotDataSource := preload("res://scripts/godot_adapters/presentation/godot_snapshot_data_source.gd")
const GODOT_RUNTIME_CONTEXT := preload("res://scripts/godot_runtime/runtime/godot_runtime_context.gd")

var player: Node
var evolution_director: Node
var day_night_system: Node
var ecosystem_director: Node
var world: Node
var runtime_context: Variant
var snapshot_builder := WorldSnapshotBuilder.new()
var godot_snapshot_data_source := GodotSnapshotDataSource.new()

var snapshot: Dictionary = {}
var hud_snapshot: Dictionary = {}
var snapshot_version := 0
var last_refresh_frame := -1
var last_hud_refresh_frame := -1


func bind(p_player: Node, p_evolution_director: Node, p_day_night_system: Node, p_ecosystem_director: Node = null, p_world: Node = null) -> void:
	player = p_player
	evolution_director = p_evolution_director
	day_night_system = p_day_night_system
	ecosystem_director = p_ecosystem_director
	world = p_world


func bind_runtime_context(context: Variant) -> void:
	runtime_context = context
	if runtime_context == null:
		return
	player = runtime_context.get_player()
	evolution_director = runtime_context.get_evolution_director()
	day_night_system = runtime_context.get_day_night_system()
	ecosystem_director = runtime_context.get_ecosystem_director()
	world = runtime_context.get_world()


func refresh(force := false) -> Dictionary:
	var current_frame := Engine.get_process_frames()
	if not force and not snapshot.is_empty() and current_frame == last_refresh_frame:
		return snapshot
	last_refresh_frame = current_frame
	snapshot = _build_snapshot()
	snapshot_version += 1
	snapshot["snapshot_version"] = snapshot_version
	return snapshot


func refresh_hud(force := false) -> Dictionary:
	var current_frame := Engine.get_process_frames()
	if not force and not hud_snapshot.is_empty() and current_frame == last_hud_refresh_frame:
		return hud_snapshot
	last_hud_refresh_frame = current_frame
	if _should_use_snapshot_builder():
		var player_input := godot_snapshot_data_source.build_player_input(player)
		var time_input := godot_snapshot_data_source.build_time_input(day_night_system)
		hud_snapshot = {
			"player": snapshot_builder.build_player_snapshot(player_input),
			"time": snapshot_builder.build_time_snapshot(time_input),
			"snapshot_version": snapshot_version
		}
	else:
		hud_snapshot = {
			"player": _build_player_snapshot(),
			"time": _build_time_snapshot(),
			"snapshot_version": snapshot_version
		}
	return hud_snapshot


func get_snapshot() -> Dictionary:
	return snapshot.duplicate(true)


func _build_snapshot() -> Dictionary:
	if _should_use_snapshot_builder():
		return _build_snapshot_with_builder()
	var player_snapshot := _build_player_snapshot()
	var world_snapshot := _build_world_snapshot(player_snapshot)
	var ecosystem_snapshot := _build_ecosystem_snapshot()
	var marker_snapshot := _build_marker_snapshot()
	return {
		"player": player_snapshot,
		"time": _build_time_snapshot(),
		"world": world_snapshot,
		"markers": marker_snapshot,
		"ecosystem": ecosystem_snapshot,
		"evolution": _build_evolution_snapshot(),
		"debug": _build_debug_snapshot(player_snapshot, world_snapshot, ecosystem_snapshot, marker_snapshot)
	}


func _build_snapshot_with_builder() -> Dictionary:
	var player_input := godot_snapshot_data_source.build_player_input(player)
	var player_snapshot := snapshot_builder.build_player_snapshot(player_input)
	var time_input := godot_snapshot_data_source.build_time_input(day_night_system)
	var time_snapshot := snapshot_builder.build_time_snapshot(time_input)
	var player_position := Vector2(player_snapshot.get("position", Vector2.ZERO))
	var active_world := _get_world()
	var world_input := godot_snapshot_data_source.build_world_input(active_world, player_position)
	var world_snapshot := snapshot_builder.build_world_snapshot(world_input)
	var marker_input := godot_snapshot_data_source.build_marker_input(active_world)
	var marker_snapshot := snapshot_builder.build_marker_snapshot(
		Array(marker_input.get("resources", [])),
		Array(marker_input.get("campfires", [])),
		Array(marker_input.get("varnaks", [])),
		Array(marker_input.get("small_prey", [])),
		Array(marker_input.get("grazers", []))
	)
	var ecosystem_snapshot := _build_ecosystem_snapshot()
	var evolution_snapshot := _build_evolution_snapshot()
	var debug_snapshot := snapshot_builder.build_debug_snapshot(
		_build_debug_snapshot(player_snapshot, world_snapshot, ecosystem_snapshot, marker_snapshot)
	)
	return snapshot_builder.build_snapshot({
		"player": player_snapshot,
		"time": time_snapshot,
		"world": world_snapshot,
		"markers": marker_snapshot,
		"ecosystem": ecosystem_snapshot,
		"evolution": evolution_snapshot,
		"debug": debug_snapshot
	})


func _should_use_snapshot_builder() -> bool:
	return true


func _build_player_snapshot() -> Dictionary:
	var player_position: Vector2 = player.global_position if is_instance_valid(player) and player is Node2D else Vector2.ZERO
	return {
		"position": player_position,
		"health": _read_player_stat("health"),
		"hunger": _read_player_stat("hunger"),
		"stamina": _read_player_stat("stamina"),
		"rest": _read_player_stat("rest"),
		"condition_text": _get_player_condition_text(),
		"prompt_text": _get_player_prompt_text(),
		"campfire_regen_active": _read_player_stat_bool("campfire_regen_active"),
		"campfire_regen_distance": _read_player_stat_float("campfire_regen_distance", -1.0),
		"inventory": _build_inventory_snapshot(),
		"has_spear": _read_player_bool("has_spear"),
		"has_bow": _read_player_bool("has_bow"),
		"torch_active": _read_player_torch_active(),
		"torch_remaining_seconds": _read_player_torch_remaining_seconds()
	}


func _build_inventory_snapshot() -> Dictionary:
	return {
		"wood": _read_inventory_amount("wood"),
		"stone": _read_inventory_amount("stone"),
		"fiber": _read_inventory_amount("fiber"),
		"meat": _read_inventory_amount("meat"),
		"hide": _read_inventory_amount("hide"),
		"bone": _read_inventory_amount("bone"),
		"torch": _read_inventory_amount("torch")
	}


func _build_time_snapshot() -> Dictionary:
	var day_value: int = 1
	if day_night_system and day_night_system.has_method("get_day"):
		day_value = int(day_night_system.get_day())
	var clock_time: String = "--:--"
	if day_night_system and day_night_system.has_method("get_clock_time"):
		clock_time = str(day_night_system.get_clock_time())
	var time_label: String = ""
	if day_night_system and day_night_system.has_method("get_time_label"):
		time_label = str(day_night_system.get_time_label())
	return {
		"day": day_value,
		"clock_time": clock_time,
		"time_label": time_label,
		"phase_label": _get_phase_label(time_label),
		"night_amount": _get_night_amount()
	}


func _build_world_snapshot(player_snapshot: Dictionary) -> Dictionary:
	var active_world := _get_world()
	var world_rect: Rect2 = WORLD_CONFIG.WORLD_RECT
	var biome_zones: Array[Dictionary] = WORLD_CONFIG.get_biome_zones()
	var landmarks: Array[Dictionary] = WORLD_CONFIG.get_landmarks()
	var landmark_counts := {"generated": 0, "hill": 0, "pond": 0}
	var world_seed := 0
	var world_generation_debug: Dictionary = {}
	var current_biome_texture_id := "none"
	var nearest_landmark: Dictionary = {}
	var out_of_bounds_count := 0
	var resource_counts := {
		"trees": 0,
		"bushes": 0,
		"grass": 0,
		"rocks": 0,
		"pond_vegetation": 0
	}
	var building_counts := {
		"campfires": 0,
		"traps": 0,
		"walls": 0,
		"storage_boxes": 0,
		"tents": 0
	}
	var biome_texture_cache: Dictionary = {}
	var small_prey_spawn_sync: Dictionary = {}
	var varnak_spawn_sync: Dictionary = {}
	var varnak_population: Dictionary = {}
	var creature_ai_state_counts: Dictionary = {}
	var creature_debug_summaries: Dictionary = {}
	var visibility_culling: Dictionary = {}
	var resource_distribution_by_biome: Dictionary = {}
	var landmark_overlay_enabled := false
	var biome_textures_enabled := true
	var biome_terrain_accents_enabled := false
	var low_end_rendering := false
	if active_world:
		if active_world.has_method("get_world_rect"):
			world_rect = active_world.get_world_rect()
		if active_world.has_method("get_biome_zones"):
			biome_zones = active_world.get_biome_zones()
		if active_world.has_method("get_landmarks"):
			landmarks = active_world.get_landmarks()
		if active_world.has_method("get_landmark_counts"):
			landmark_counts = Dictionary(active_world.get_landmark_counts())
		if active_world.has_method("get_world_seed"):
			world_seed = int(active_world.get_world_seed())
		if active_world.has_method("get_world_generation_debug"):
			world_generation_debug = Dictionary(active_world.get_world_generation_debug())
		if active_world.has_method("get_creatures_out_of_bounds_count"):
			out_of_bounds_count = int(active_world.get_creatures_out_of_bounds_count())
		if active_world.has_method("get_current_biome_texture_id"):
			current_biome_texture_id = str(active_world.get_current_biome_texture_id(Vector2(player_snapshot.get("position", Vector2.ZERO))))
		if active_world.has_method("get_nearest_landmark_data"):
			nearest_landmark = Dictionary(active_world.get_nearest_landmark_data(Vector2(player_snapshot.get("position", Vector2.ZERO))))
		if active_world.has_method("get_biome_texture_cache_status"):
			biome_texture_cache = Dictionary(active_world.get_biome_texture_cache_status())
		if active_world.has_method("get_small_prey_spawn_sync_debug"):
			small_prey_spawn_sync = Dictionary(active_world.get_small_prey_spawn_sync_debug())
		if active_world.has_method("get_varnak_spawn_sync_debug"):
			varnak_spawn_sync = Dictionary(active_world.get_varnak_spawn_sync_debug())
		if active_world.has_method("get_varnak_population_status"):
			varnak_population = Dictionary(active_world.get_varnak_population_status())
		creature_ai_state_counts = {
			"small_prey": _count_ai_states(_get_world_creatures_from_world(active_world, "small_prey")),
			"grazer": _count_ai_states(_get_world_creatures_from_world(active_world, "grazer")),
			"varnak": _count_ai_states(_get_world_creatures_from_world(active_world, "varnak"))
		}
		creature_debug_summaries = {
			"small_prey": _build_creature_debug_summaries(_get_world_creatures_from_world(active_world, "small_prey")),
			"grazer": _build_creature_debug_summaries(_get_world_creatures_from_world(active_world, "grazer")),
			"varnak": _build_creature_debug_summaries(_get_world_creatures_from_world(active_world, "varnak"))
		}
		if active_world.has_method("get_visibility_culling_debug"):
			visibility_culling = Dictionary(active_world.get_visibility_culling_debug())
		if active_world.has_method("is_landmark_debug_overlay_enabled"):
			landmark_overlay_enabled = active_world.is_landmark_debug_overlay_enabled()
		if active_world.has_method("are_biome_textures_enabled"):
			biome_textures_enabled = active_world.are_biome_textures_enabled()
		if active_world.has_method("are_biome_terrain_accents_enabled"):
			biome_terrain_accents_enabled = active_world.are_biome_terrain_accents_enabled()
		if active_world.has_method("is_low_end_rendering_enabled"):
			low_end_rendering = active_world.is_low_end_rendering_enabled()
		if active_world.has_method("get_resource_distribution_by_biome"):
			resource_distribution_by_biome = Dictionary(active_world.get_resource_distribution_by_biome())
		resource_counts["trees"] = _get_world_group_count(active_world, "trees")
		resource_counts["bushes"] = _get_world_group_count(active_world, "bushes")
		resource_counts["grass"] = _get_world_group_count(active_world, "grass")
		resource_counts["rocks"] = _get_world_group_count(active_world, "rocks")
		resource_counts["pond_vegetation"] = _get_world_group_count(active_world, "pond_vegetation")
		building_counts["campfires"] = _get_world_group_count(active_world, "campfires")
		building_counts["traps"] = _get_world_group_count(active_world, "traps")
		building_counts["walls"] = _get_world_group_count(active_world, "walls")
		building_counts["storage_boxes"] = _get_world_group_count(active_world, "storage_boxes")
		building_counts["tents"] = _get_world_group_count(active_world, "tents")
	return {
		"world_rect": world_rect,
		"biome_zones": biome_zones.duplicate(true),
		"landmarks": landmarks.duplicate(true),
		"landmark_counts": landmark_counts,
		"world_seed": world_seed,
		"world_generation_debug": world_generation_debug,
		"current_biome_name": _get_current_biome_name(Vector2(player_snapshot.get("position", Vector2.ZERO)), biome_zones),
		"current_biome_texture_id": current_biome_texture_id,
		"nearest_landmark": nearest_landmark,
		"out_of_bounds_count": out_of_bounds_count,
		"resource_counts": resource_counts,
		"building_counts": building_counts,
		"biome_texture_cache": biome_texture_cache,
		"small_prey_spawn_sync": small_prey_spawn_sync,
		"varnak_spawn_sync": varnak_spawn_sync,
		"varnak_population": varnak_population,
		"creature_ai_state_counts": creature_ai_state_counts,
		"creature_debug_summaries": creature_debug_summaries,
		"visibility_culling": visibility_culling,
		"resource_distribution_by_biome": resource_distribution_by_biome,
		"landmark_overlay_enabled": landmark_overlay_enabled,
		"biome_textures_enabled": biome_textures_enabled,
		"biome_terrain_accents_enabled": biome_terrain_accents_enabled,
		"low_end_rendering": low_end_rendering
	}


func _build_marker_snapshot() -> Dictionary:
	return {
		"resources": _build_resource_markers(),
		"campfires": _build_campfire_markers(),
		"varnaks": _build_creature_markers("varnak"),
		"small_prey": _build_creature_markers("small_prey"),
		"grazers": _build_creature_markers("grazer")
	}


func _build_campfire_markers() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return markers

	for campfire_value in tree.get_nodes_in_group("campfires"):
		var campfire := campfire_value as Node2D
		if campfire == null or not is_instance_valid(campfire):
			continue
		if campfire.is_queued_for_deletion():
			continue

		markers.append({
			"position": campfire.global_position,
			"type": "campfire",
			"active": _read_campfire_active(campfire)
		})

	return markers


func _build_resource_markers() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	for resource_value in _get_world_resources():
		var resource := resource_value as Node2D
		if resource == null or not is_instance_valid(resource):
			continue
		var resource_kind := str(resource.get("resource_kind"))
		if resource_kind in ["grass_patch", "dense_grass", "berry_bush"]:
			continue
		if resource.get("player_harvestable") == false:
			continue
		markers.append({
			"position": resource.global_position,
			"resource_kind": resource_kind,
			"item_name": str(resource.get("item_name")),
			"player_harvestable": resource.get("player_harvestable") != false
		})
	return markers


func _build_creature_markers(creature_type: String) -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	for creature_value in _get_world_creatures(creature_type):
		var creature := creature_value as Node2D
		if creature == null or not is_instance_valid(creature):
			continue
		if creature.is_queued_for_deletion():
			continue
		if _is_creature_dead_for_marker(creature):
			continue
		markers.append({
			"position": creature.global_position,
			"type": creature_type
		})
	return markers


func _read_campfire_active(campfire: Node) -> bool:
	if campfire == null:
		return false
	if campfire.has_method("is_active"):
		return campfire.call("is_active") == true
	if campfire.has_method("is_lit"):
		return campfire.call("is_lit") == true
	var active_value: Variant = campfire.get("active")
	if active_value != null:
		return active_value == true
	var lit_value: Variant = campfire.get("lit")
	if lit_value != null:
		return lit_value == true
	return true


func _is_creature_dead_for_marker(creature: Node) -> bool:
	if creature == null:
		return true
	if creature.has_method("is_dead"):
		return creature.call("is_dead") == true
	if creature.has_method("is_alive"):
		return creature.call("is_alive") != true
	if creature.has_method("get_health"):
		return float(creature.call("get_health")) <= 0.0
	var dead_value: Variant = creature.get("dead")
	if dead_value != null:
		return dead_value == true
	var is_dead_value: Variant = creature.get("is_dead")
	if is_dead_value != null:
		return is_dead_value == true
	var health_value: Variant = creature.get("health")
	if health_value != null:
		return float(health_value) <= 0.0
	return false


func _get_world_creatures_from_world(active_world: Node, creature_type: String) -> Array:
	if active_world == null:
		return []
	if active_world.has_method("get_registered_creatures_by_type"):
		return active_world.get_registered_creatures_by_type(creature_type)
	return []


func _count_ai_states(nodes: Array) -> Dictionary:
	var counts: Dictionary = {}
	for node in nodes:
		if not is_instance_valid(node):
			continue
		var state_name := ""
		var adapter_data := _get_creature_adapter_debug_data(node)
		if not adapter_data.is_empty():
			state_name = str(adapter_data.get("last_decision", {}).get("behavior", ""))
			if state_name.is_empty():
				state_name = str(adapter_data.get("last_context", {}).get("current_behavior", ""))
		elif node.has_method("get_debug_ai_state"):
			state_name = str(node.get_debug_ai_state())
		elif node.has_method("get_debug_data"):
			var data: Dictionary = node.get_debug_data()
			state_name = str(data.get("state", ""))
		if state_name.is_empty():
			continue
		state_name = _normalize_ai_state_label(state_name)
		if state_name.is_empty():
			continue
		counts[state_name] = int(counts.get(state_name, 0)) + 1
	return counts


func _normalize_ai_state_label(state_name: String) -> String:
	var normalized := state_name.strip_edges().to_lower()
	if normalized.is_empty():
		return ""
	if normalized.contains("flee"):
		return "fleeing"
	if normalized.contains("eat"):
		return "eating"
	if normalized.contains("hunt") or normalized.contains("stalk") or normalized.contains("chase") or normalized.contains("attack"):
		return "hunting"
	if normalized.contains("hungry") or normalized.contains("starv"):
		return "hungry"
	return "wandering" if normalized.contains("wander") or normalized.contains("idle") else normalized


func _build_creature_debug_summaries(nodes: Array) -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for node in nodes:
		if not is_instance_valid(node):
			continue
		var summary := _get_creature_adapter_summary(node)
		if summary.is_empty():
			continue
		summaries.append(summary)
	return summaries


func _get_creature_adapter_summary(node: Node) -> Dictionary:
	if node == null or not node.has_method("get"):
		return {}
	var adapter_value: Variant = node.get("creature_adapter")
	if adapter_value == null:
		return {}
	var adapter := adapter_value as RefCounted
	if adapter == null or not adapter.has_method("get_snapshot_summary"):
		return {}
	return Dictionary(adapter.call("get_snapshot_summary"))


func _get_creature_adapter_debug_data(node: Node) -> Dictionary:
	if node == null:
		return {}
	if not node.has_method("get"):
		return {}
	var adapter_value: Variant = node.get("creature_adapter")
	if adapter_value == null:
		return {}
	var adapter := adapter_value as RefCounted
	if adapter == null:
		return {}
	if not adapter.has_method("get_debug_data"):
		return {}
	return Dictionary(adapter.call("get_debug_data"))


func _build_ecosystem_snapshot() -> Dictionary:
	var biome_states := {}
	if ecosystem_director and ecosystem_director.has_method("get_biome_states"):
		biome_states = ecosystem_director.get_biome_states()
	return {
		"biome_states": Dictionary(biome_states).duplicate(true),
		"warnings_text": _get_ecosystem_warnings_text(Dictionary(biome_states)),
		"population_totals": {
			"small_prey_population": _get_ecosystem_population_total(Dictionary(biome_states), "small_prey_population"),
			"grazer_population": _get_ecosystem_population_total(Dictionary(biome_states), "grazer_population"),
			"varnak_population": _get_ecosystem_population_total(Dictionary(biome_states), "varnak_population")
		}
	}


func _build_evolution_snapshot() -> Dictionary:
	var profile: Dictionary = {}
	if evolution_director and evolution_director.has_method("get_profile"):
		profile = evolution_director.get_profile()
	return {
		"profile": profile.duplicate(true),
		"generation": int(profile.get("generation", 1))
	}


func _build_debug_snapshot(
	player_snapshot: Dictionary,
	world_snapshot: Dictionary,
	ecosystem_snapshot: Dictionary,
	markers: Dictionary = {}
) -> Dictionary:
	if markers.is_empty():
		markers = _build_marker_snapshot()
	return {
		"live_varnaks": Array(markers.get("varnaks", [])).size(),
		"live_small_prey": Array(markers.get("small_prey", [])).size(),
		"live_grazers": Array(markers.get("grazers", [])).size(),
		"current_biome_name": str(world_snapshot.get("current_biome_name", "unknown")),
		"world_seed": int(world_snapshot.get("world_seed", 0)),
		"warnings_text": str(ecosystem_snapshot.get("warnings_text", "none")),
		"player_health": int(player_snapshot.get("health", 0))
	}


func _get_world() -> Node:
	if runtime_context != null:
		var context_world: Node = runtime_context.get_world()
		if context_world != null:
			world = context_world
			return world
	if is_instance_valid(world):
		return world
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return null
	world = tree.current_scene.get_node_or_null("World")
	return world


func _get_world_resources() -> Array:
	var active_world := _get_world()
	if active_world and active_world.has_method("get_registered_resources"):
		return active_world.get_registered_resources()
	return []


func _get_world_creatures(creature_type: String) -> Array:
	var active_world := _get_world()
	if active_world and active_world.has_method("get_registered_creatures_by_type"):
		return active_world.get_registered_creatures_by_type(creature_type)
	return []


func _get_world_group_count(active_world: Node, group_name: String) -> int:
	if active_world == null:
		return 0
	if active_world.has_method("get_cached_group_nodes"):
		return int((active_world.get_cached_group_nodes(group_name) as Array).size())
	return 0


func _get_current_biome_name(position: Vector2, biome_zones: Array[Dictionary]) -> String:
	var world := _get_world()
	if world != null and world.has_method("get_biome_name_at"):
		var biome_name := str(world.get_biome_name_at(position))
		if not biome_name.is_empty():
			return biome_name
		if world.has_method("get_biome_lookup_debug") and bool(Dictionary(world.get_biome_lookup_debug(position)).get("world_rect_has_point", false)) == true:
			var zone_fallback := _get_biome_name_from_zones(position, biome_zones)
			if not zone_fallback.is_empty():
				return zone_fallback
			return "unknown (lookup error)"
	var zone_name := _get_biome_name_from_zones(position, biome_zones)
	if not zone_name.is_empty():
		return zone_name
	return "outside world"


func _get_biome_name_from_zones(position: Vector2, biome_zones: Array[Dictionary]) -> String:
	for biome_zone_value in biome_zones:
		var biome_zone := Dictionary(biome_zone_value)
		var points := PackedVector2Array(biome_zone.get("points", []))
		if points.size() < 3:
			continue
		if Geometry2D.is_point_in_polygon(position, points):
			return str(biome_zone.get("name", ""))
	return ""


func _get_phase_label(time_label: String) -> String:
	if day_night_system and day_night_system.has_method("get_phase_label"):
		return str(day_night_system.get_phase_label())
	if not time_label.is_empty():
		return time_label
	if day_night_system and day_night_system.has_method("is_night") and day_night_system.is_night():
		return "Night"
	return "Day"


func _get_night_amount() -> float:
	if day_night_system == null:
		return 0.0
	var night_amount: Variant = day_night_system.get("night_amount")
	return float(night_amount) if night_amount != null else 0.0


func _read_player_stat(property_name: String) -> int:
	if not is_instance_valid(player):
		return 0
	var stats: Variant = player.get("stats")
	if stats == null:
		return 0
	return int(stats.get(property_name))


func _read_player_stat_float(property_name: String, fallback := 0.0) -> float:
	if not is_instance_valid(player):
		return fallback
	var stats: Variant = player.get("stats")
	if stats == null:
		return fallback
	return float(stats.get(property_name))


func _read_player_stat_bool(property_name: String) -> bool:
	if not is_instance_valid(player):
		return false
	var stats: Variant = player.get("stats")
	if stats == null:
		return false
	return stats.get(property_name) == true


func _get_player_condition_text() -> String:
	if not is_instance_valid(player):
		return "unknown"
	var stats: Variant = player.get("stats")
	if stats == null or not stats.has_method("get_condition_text"):
		return "unknown"
	return str(stats.get_condition_text())


func _get_player_prompt_text() -> String:
	if not is_instance_valid(player) or not player.has_method("get_interaction_prompt"):
		return ""
	return str(player.get_interaction_prompt())


func _read_inventory_amount(item_name: String) -> int:
	if not is_instance_valid(player):
		return 0
	var inventory: Variant = player.get("inventory")
	if inventory == null or not inventory.has_method("get_amount"):
		return 0
	return int(inventory.get_amount(item_name))


func _read_player_bool(property_name: String) -> bool:
	if not is_instance_valid(player):
		return false
	return player.get(property_name) == true


func _read_player_torch_active() -> bool:
	if not is_instance_valid(player) or not player.has_method("is_torch_active"):
		return false
	return player.is_torch_active()


func _read_player_torch_remaining_seconds() -> float:
	if not is_instance_valid(player) or not player.has_method("get_torch_remaining_seconds"):
		return 0.0
	return float(player.get_torch_remaining_seconds())


func _get_ecosystem_population_total(biome_states: Dictionary, population_key: String) -> int:
	var total := 0
	for biome_id in biome_states.keys():
		var state: Dictionary = Dictionary(biome_states[biome_id])
		total += int(round(float(state.get(population_key, 0.0))))
	return total


func _get_ecosystem_warnings_text(biome_states: Dictionary) -> String:
	if biome_states.is_empty():
		return "none"
	var warnings: Array[String] = []
	for biome_id in biome_states.keys():
		var state: Dictionary = Dictionary(biome_states[biome_id])
		var status := str(state.get("status", "unknown")).to_lower()
		if status != "healthy" and status != "stable" and status != "ok":
			warnings.append("%s:%s" % [str(state.get("name", biome_id)), status])
	return "none" if warnings.is_empty() else ", ".join(warnings)
