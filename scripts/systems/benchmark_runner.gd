extends Node
class_name BenchmarkRunner

signal finished(log_path: String, json_path: String)
signal benchmark_progress(elapsed_seconds: float, remaining_seconds: float)

const BENCHMARK_DURATION_SECONDS := 60.0
const SAMPLE_INTERVAL_SECONDS := 1.0
const LOG_DIRECTORY := "user://benchmark_logs"
const BENCHMARK_THRESHOLDS_PATH := "res://config/benchmark_thresholds.json"
const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")

const PERFORMANCE_MONITORS := {
	"fps": Performance.TIME_FPS,
	"frame_time_s": Performance.TIME_PROCESS,
	"physics_time_s": Performance.TIME_PHYSICS_PROCESS,
	"navigation_time_s": Performance.TIME_NAVIGATION_PROCESS,
	"object_count": Performance.OBJECT_COUNT,
	"resource_count": Performance.OBJECT_RESOURCE_COUNT,
	"node_count": Performance.OBJECT_NODE_COUNT,
	"orphan_node_count": Performance.OBJECT_ORPHAN_NODE_COUNT,
	"render_objects": Performance.RENDER_TOTAL_OBJECTS_IN_FRAME,
	"render_primitives": Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME,
	"draw_calls": Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME,
	"video_mem_used": Performance.RENDER_VIDEO_MEM_USED,
	"texture_mem_used": Performance.RENDER_TEXTURE_MEM_USED,
	"buffer_mem_used": Performance.RENDER_BUFFER_MEM_USED,
	"physics_2d_active": Performance.PHYSICS_2D_ACTIVE_OBJECTS,
	"physics_2d_collision_pairs": Performance.PHYSICS_2D_COLLISION_PAIRS,
	"physics_2d_islands": Performance.PHYSICS_2D_ISLAND_COUNT
}

var running := false
var elapsed_seconds := 0.0
var sample_timer := 0.0
var start_ticks_usec := 0
var start_unix_time := 0.0
var benchmark_base_name := ""
var samples: Array = []
var last_process_ticks_msec := 0
var realtime_hitch_count := 0
var max_realtime_delta_ms := 0
var realtime_hitches: Array = []

# HITCH LOGGER COUNTERS
var benchmark_sample_build_ms: float = 0.0
var benchmark_file_write_ms: float = 0.0
var last_reported_second := -1

var scene: Node
var world: Node
var minimap: Node
var map_screen: Node
var player: Node2D
var evolution_director: Node
var day_night_system: Node
var ecosystem_director: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func start() -> bool:
	if running:
		return false
	if not _capture_context():
		_post_message("Benchmark could not start: missing game state")
		queue_free()
		return false
	running = true
	elapsed_seconds = 0.0
	sample_timer = 0.0
	start_ticks_usec = Time.get_ticks_usec()
	start_unix_time = Time.get_unix_time_from_system()
	benchmark_base_name = "benchmark_%d" % int(start_unix_time)
	samples.clear()
	last_process_ticks_msec = 0
	realtime_hitch_count = 0
	max_realtime_delta_ms = 0
	realtime_hitches.clear()
	last_reported_second = -1
	benchmark_progress.emit(0.0, BENCHMARK_DURATION_SECONDS)
	return true


func _process(delta: float) -> void:
	if not running:
		return
	var now_ticks := Time.get_ticks_msec()
	_capture_realtime_hitch(now_ticks, delta)
	_log_hitch(delta, "BenchmarkRunner", {
		"running": running,
		"sample_timer": sample_timer,
		"samples": samples.size()
	})
	elapsed_seconds = float(Time.get_ticks_usec() - start_ticks_usec) / 1000000.0
	sample_timer += delta
	if sample_timer >= SAMPLE_INTERVAL_SECONDS and running:
		sample_timer -= SAMPLE_INTERVAL_SECONDS
		_record_sample()
		elapsed_seconds = float(Time.get_ticks_usec() - start_ticks_usec) / 1000000.0
	_report_progress()
	if elapsed_seconds >= BENCHMARK_DURATION_SECONDS:
		_finish()


func _capture_realtime_hitch(now_ticks: int, delta: float) -> void:
	if last_process_ticks_msec > 0:
		var realtime_delta_ms: int = now_ticks - last_process_ticks_msec
		if realtime_delta_ms > 250:
			realtime_hitch_count += 1
			max_realtime_delta_ms = maxi(max_realtime_delta_ms, realtime_delta_ms)
			var hitch := {
				"elapsed_seconds": elapsed_seconds,
				"realtime_delta_ms": realtime_delta_ms,
				"engine_delta_ms": delta * 1000.0,
				"sample_count": samples.size(),
				"sample_timer": sample_timer,
				"world_debug": _capture_lightweight_world_debug()
			}
			realtime_hitches.append(hitch)
			if realtime_hitches.size() > 20:
				realtime_hitches.pop_front()
			push_warning("[REALTIME_HITCH] %d ms engine_delta=%.1f sample_count=%d" % [
				realtime_delta_ms,
				delta * 1000.0,
				samples.size()
			])
	last_process_ticks_msec = now_ticks


func _capture_context() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	scene = tree.current_scene
	if not is_instance_valid(scene):
		scene = _find_active_scene(tree.root)
	if not is_instance_valid(scene):
		return false
	world = scene.get_node_or_null("World")
	minimap = scene.get_node_or_null("HUD/Minimap")
	map_screen = scene.get_node_or_null("HUD/MapScreen")
	player = scene.get_node_or_null("Player") as Node2D
	evolution_director = scene.get_node_or_null("EvolutionDirector")
	day_night_system = scene.get_node_or_null("DayNightSystem")
	ecosystem_director = scene.get_node_or_null("EcosystemDirector")
	return is_instance_valid(world) and is_instance_valid(player) and is_instance_valid(evolution_director) and is_instance_valid(day_night_system) and is_instance_valid(ecosystem_director)


func _find_active_scene(root: Node) -> Node:
	if root == null:
		return null
	for child in root.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		if child_node.get_node_or_null("World") != null and child_node.get_node_or_null("HUD") != null:
			return child_node
	return root.get_child(0) if root.get_child_count() > 0 else null


func _record_sample() -> void:
	if not running:
		return
	var sample_start_ms: int = Time.get_ticks_msec()
	var sample: Dictionary = _capture_sample()
	benchmark_sample_build_ms = float(Time.get_ticks_msec() - sample_start_ms)
	sample["benchmark_sample_build_ms"] = benchmark_sample_build_ms
	samples.append(sample)


func _report_progress() -> void:
	if not running:
		return
	var current_second: int = int(floor(elapsed_seconds))
	if current_second == last_reported_second:
		return
	last_reported_second = current_second
	var remaining_seconds: float = maxf(BENCHMARK_DURATION_SECONDS - elapsed_seconds, 0.0)
	benchmark_progress.emit(elapsed_seconds, remaining_seconds)


func _capture_sample() -> Dictionary:
	var sample: Dictionary = {}
	sample["sample_index"] = samples.size() + 1
	sample["elapsed_seconds"] = elapsed_seconds
	sample["time_label"] = _format_time(elapsed_seconds)
	sample["performance"] = _capture_performance_stats()
	sample["world"] = _capture_world_stats()
	sample["minimap"] = _capture_minimap_stats()
	sample["map_screen"] = _capture_map_screen_stats()
	sample["player"] = _capture_player_stats()
	sample["ecosystem"] = _capture_ecosystem_stats()
	sample["ai_decisions"] = _capture_ai_decision_stats()
	sample["driver_scores"] = _calculate_driver_scores(sample)
	sample["likely_driver"] = _pick_likely_driver(Dictionary(sample.get("driver_scores", {})))
	sample["load_score"] = _calculate_load_score(sample)
	return sample


func _capture_performance_stats() -> Dictionary:
	var stats: Dictionary = {}
	for key in PERFORMANCE_MONITORS.keys():
		var monitor_id: int = int(PERFORMANCE_MONITORS[key])
		var value := Performance.get_monitor(monitor_id)
		match str(key):
			"fps":
				stats[key] = int(round(float(value)))
			"frame_time_s", "physics_time_s", "navigation_time_s":
				stats[key] = float(value)
			_:
				stats[key] = int(round(float(value)))
	stats["window_focused"] = DisplayServer.window_is_focused()
	return stats


func _capture_world_stats() -> Dictionary:
	var stats: Dictionary = {}
	if not is_instance_valid(world):
		return stats
	stats["current_biome"] = _get_current_biome_name()
	stats["world_rect"] = str(world.get_world_rect()) if world.has_method("get_world_rect") else str(WORLD_CONFIG.WORLD_RECT)
	stats["creatures_out_of_bounds_count"] = int(world.get_creatures_out_of_bounds_count()) if world.has_method("get_creatures_out_of_bounds_count") else 0
	stats["biome_count"] = world.get_biome_zones().size() if world.has_method("get_biome_zones") else 0
	var landmarks: Array[Dictionary] = world.get_landmarks() if world.has_method("get_landmarks") else []
	stats["landmark_count"] = landmarks.size()
	stats["pond_count"] = _count_landmarks_by_type(landmarks, "pond")
	stats["hill_count"] = _count_landmarks_by_type(landmarks, "hill")
	stats["boot"] = _capture_world_boot_stats()
	stats["biome_texture_cache"] = _capture_world_biome_texture_cache_stats()
	stats["small_prey_spawn_sync"] = _capture_world_small_prey_spawn_sync_stats()
	stats["varnak_spawn_sync"] = _capture_world_varnak_spawn_sync_stats()
	stats["creature_spawn_rejection_debug"] = _capture_world_creature_spawn_rejection_debug()
	stats["landmark_debug"] = _capture_world_landmark_debug_stats()
	stats["registry"] = _capture_world_registry_stats()
	stats["render_flags"] = _capture_world_render_flags()
	stats["visibility_culling"] = _capture_world_visibility_culling_stats()
	stats["creature_counts"] = _capture_group_counts(["small_prey", "grazer", "varnak"])
	stats["resource_counts"] = _capture_group_counts([
		"trees",
		"bushes",
		"grass",
		"rocks",
		"meat_drops",
		"campfires",
		"traps",
		"walls",
		"storage_boxes",
		"tents"
	])
	stats["special_resource_counts"] = _capture_group_counts([
		"pond_vegetation",
		"edible_vegetation"
	])
	stats["vegetation"] = _capture_world_vegetation_stats()
	stats["resource_render_mode"] = _capture_world_resource_render_mode_stats()
	stats["creature_simulation"] = _capture_creature_simulation_stats()
	stats["biome_query"] = _capture_world_biome_query_stats()
	stats["total_creatures"] = _sum_group_counts(stats["creature_counts"])
	stats["total_resources"] = _sum_group_counts(stats["resource_counts"])
	return stats


func _capture_minimap_stats() -> Dictionary:
	if not is_instance_valid(minimap) or not minimap.has_method("get_minimap_performance_debug"):
		return {}
	return Dictionary(minimap.call("get_minimap_performance_debug"))


func _capture_map_screen_stats() -> Dictionary:
	if not is_instance_valid(map_screen) or not map_screen.has_method("get_map_screen_performance_debug"):
		return {}
	return Dictionary(map_screen.call("get_map_screen_performance_debug"))


func _capture_ai_decision_stats() -> Dictionary:
	return {
		"small_prey": _capture_ai_decision_stats_for_group("small_prey"),
		"grazer": _capture_ai_decision_stats_for_group("grazer"),
		"varnak": _capture_ai_decision_stats_for_group("varnak")
	}


func _capture_ai_decision_stats_for_group(group_name: String) -> Dictionary:
	var creatures: Array = _get_group_nodes(group_name)
	var total_decisions := 0
	var count := 0
	for creature_value in creatures:
		var creature := creature_value as Node
		if creature == null or not is_instance_valid(creature):
			continue
		count += 1
		if creature.has_method("get_ai_performance_debug"):
			var ai_debug := Dictionary(creature.call("get_ai_performance_debug"))
			total_decisions += int(ai_debug.get("decision_count", 0))
		elif creature.has_method("get_debug_data"):
			var data := Dictionary(creature.call("get_debug_data"))
			total_decisions += int(data.get("ai_decision_count", data.get("decision_count", 0)))
	var average := float(total_decisions) / float(count) if count > 0 else 0.0
	return {
		"count": count,
		"total_decisions": total_decisions,
		"average_decisions_per_entity": average
	}


func _capture_creature_simulation_stats() -> Dictionary:
	var stats := {
		"near_creature_count": 0,
		"medium_creature_count": 0,
		"far_creature_count": 0,
		"far_simulation_tick_count": 0,
		"background_simulated_creature_count": 0
	}
	for group_name in ["small_prey", "grazer", "varnak"]:
		for creature_value in _get_group_nodes(group_name):
			var creature := creature_value as Node
			if creature == null or not is_instance_valid(creature):
				continue
			var data := Dictionary(creature.call("get_debug_data")) if creature.has_method("get_debug_data") else {}
			var sim_level := str(data.get("simulation_level", "unknown"))
			match sim_level:
				"near":
					stats["near_creature_count"] = int(stats["near_creature_count"]) + 1
				"medium":
					stats["medium_creature_count"] = int(stats["medium_creature_count"]) + 1
				"far":
					stats["far_creature_count"] = int(stats["far_creature_count"]) + 1
			if bool(data.get("is_background_simulated", false)):
				stats["background_simulated_creature_count"] = int(stats["background_simulated_creature_count"]) + 1
			stats["far_simulation_tick_count"] = int(stats["far_simulation_tick_count"]) + int(data.get("far_simulation_tick_count", data.get("background_simulation_tick_count", 0)))
	return stats


func _capture_world_boot_stats() -> Dictionary:
	if not is_instance_valid(world):
		return {}
	var boot_state := Dictionary(world.get_boot_progress_state()) if world.has_method("get_boot_progress_state") else {}
	return {
		"ready": bool(boot_state.get("boot_ready", world.is_boot_ready() if world.has_method("is_boot_ready") else false)),
		"progress": float(boot_state.get("progress", 1.0 if world.has_method("is_boot_ready") and world.is_boot_ready() else 0.0)),
		"stage_message": str(boot_state.get("message", "unknown"))
	}


func _capture_world_biome_texture_cache_stats() -> Dictionary:
	if not is_instance_valid(world) or not world.has_method("get_biome_texture_cache_status"):
		return {}
	var cache_status := Dictionary(world.get_biome_texture_cache_status())
	var world_build_count := int(cache_status.get("world_biome_texture_build_count", cache_status.get("rebuild_count", 0)))
	var world_last_build_ms := float(cache_status.get("world_biome_texture_last_build_ms", cache_status.get("last_build_ms", 0.0)))
	return {
		"textures_enabled": bool(cache_status.get("textures_enabled", true)),
		"has_blend_texture": bool(cache_status.get("has_blend_texture", false)),
		"blend_texture_size": str(cache_status.get("blend_texture_size", Vector2i.ZERO)),
		"sample_image_cache_count": int(cache_status.get("sample_image_cache_count", 0)),
		"accent_cache_count": int(cache_status.get("accent_cache_count", 0)),
		"pending_biomes": int(cache_status.get("pending_biomes", 0)),
		"build_running": bool(cache_status.get("build_running", false)),
		"blend_colors_key_length": str(cache_status.get("blend_colors_key", "")).length(),
		"world_biome_texture_build_count": world_build_count,
		"rebuild_count": int(cache_status.get("rebuild_count", world_build_count)),
		"world_biome_texture_last_build_ms": world_last_build_ms,
		"last_build_ms": float(cache_status.get("last_build_ms", world_last_build_ms)),
		"rebuild_blocked_count": int(cache_status.get("rebuild_blocked_count", 0)),
		"dirty_key_pending": bool(cache_status.get("dirty_key_pending", false)),
		"freeze_after_first_build": bool(cache_status.get("freeze_after_first_build", false)),
		"biome_detail_overlay_enabled": bool(cache_status.get("biome_detail_overlay_enabled", false)),
		"biome_detail_overlay_low_end_disabled": bool(cache_status.get("biome_detail_overlay_low_end_disabled", false)),
		"biome_detail_overlay_visible_chunk_count": int(cache_status.get("biome_detail_overlay_visible_chunk_count", 0)),
		"biome_detail_overlay_pending_chunk_count": int(cache_status.get("biome_detail_overlay_pending_chunk_count", 0)),
		"biome_detail_overlay_cached_chunk_count": int(cache_status.get("biome_detail_overlay_cached_chunk_count", 0)),
		"biome_detail_overlay_build_budget_per_frame": int(cache_status.get("biome_detail_overlay_build_budget_per_frame", 0)),
		"biome_detail_overlay_chunks_built_last_frame": int(cache_status.get("biome_detail_overlay_chunks_built_last_frame", 0)),
		"biome_detail_overlay_total_build_count": int(cache_status.get("biome_detail_overlay_total_build_count", 0)),
		"biome_detail_overlay_rebuild_count": int(cache_status.get("biome_detail_overlay_rebuild_count", 0)),
		"biome_detail_overlay_cache_hit_count": int(cache_status.get("biome_detail_overlay_cache_hit_count", 0)),
		"biome_detail_overlay_cache_miss_count": int(cache_status.get("biome_detail_overlay_cache_miss_count", 0)),
		"biome_detail_overlay_last_build_ms": float(cache_status.get("biome_detail_overlay_last_build_ms", 0.0)),
		"biome_detail_overlay_max_build_ms": float(cache_status.get("biome_detail_overlay_max_build_ms", 0.0)),
		"biome_detail_overlay_last_update_skipped_reason": str(cache_status.get("biome_detail_overlay_last_update_skipped_reason", "")),
		"biome_detail_overlay_last_visible_signature_length": int(cache_status.get("biome_detail_overlay_last_visible_signature_length", 0)),
		"biome_detail_overlay_pruned_chunk_count": int(cache_status.get("biome_detail_overlay_pruned_chunk_count", 0)),
		"biome_detail_overlay_last_prune_ms": float(cache_status.get("biome_detail_overlay_last_prune_ms", 0.0)),
		"biome_detail_overlay_last_camera_move_distance": float(cache_status.get("biome_detail_overlay_last_camera_move_distance", 0.0))
	}


func _capture_world_biome_query_stats() -> Dictionary:
	if not is_instance_valid(world) or not world.has_method("get_biome_query_debug_data"):
		return {}
	return Dictionary(world.get_biome_query_debug_data())


func _capture_world_small_prey_spawn_sync_stats() -> Dictionary:
	if not is_instance_valid(world) or not world.has_method("get_small_prey_spawn_sync_debug"):
		return {}
	return Dictionary(world.get_small_prey_spawn_sync_debug())


func _capture_world_varnak_spawn_sync_stats() -> Dictionary:
	if not is_instance_valid(world) or not world.has_method("get_varnak_spawn_sync_debug"):
		return {}
	return Dictionary(world.get_varnak_spawn_sync_debug())


func _capture_world_creature_spawn_rejection_debug() -> Dictionary:
	if not is_instance_valid(world) or not world.has_method("get_creature_spawn_rejection_debug"):
		return {}
	return Dictionary(world.get_creature_spawn_rejection_debug())


func _capture_lightweight_world_debug() -> Dictionary:
	var scene_tree := get_tree()
	if scene_tree == null:
		return {}
	var active_world: Node = scene_tree.get_first_node_in_group("world")
	if active_world == null and scene_tree.current_scene != null:
		active_world = scene_tree.current_scene.get_node_or_null("World")
	if active_world == null:
		return {}
	var result: Dictionary = {}
	if active_world.has_method("get_small_prey_spawn_sync_debug"):
		result["small_prey_spawn_sync"] = active_world.get_small_prey_spawn_sync_debug()
	if active_world.has_method("get_varnak_spawn_sync_debug"):
		result["varnak_spawn_sync"] = active_world.get_varnak_spawn_sync_debug()
	if active_world.has_method("get_biome_texture_cache_debug"):
		result["biome_texture_cache"] = active_world.get_biome_texture_cache_debug()
	if active_world.has_method("get_visibility_culling_debug"):
		result["visibility_culling"] = active_world.get_visibility_culling_debug()
	return result


func _capture_world_landmark_debug_stats() -> Dictionary:
	if not is_instance_valid(world) or not world.has_method("get_landmark_counts"):
		return {}
	var landmark_counts := Dictionary(world.get_landmark_counts())
	return {
		"generated": int(landmark_counts.get("generated", 0)),
		"pond": int(landmark_counts.get("pond", 0)),
		"hill": int(landmark_counts.get("hill", 0))
	}


func _capture_world_registry_stats() -> Dictionary:
	if not is_instance_valid(world):
		return {}
	var resource_total: int = world.get_registered_resources().size() if world.has_method("get_registered_resources") else 0
	var building_total: int = world.get_registered_buildings().size() if world.has_method("get_registered_buildings") else 0
	return {
		"registered_resources": resource_total,
		"registered_buildings": building_total
	}


func _capture_world_render_flags() -> Dictionary:
	if not is_instance_valid(world):
		return {}
	return {
		"low_end_rendering": world.is_low_end_rendering_enabled() if world.has_method("is_low_end_rendering_enabled") else false,
		"biome_textures_enabled": world.are_biome_textures_enabled() if world.has_method("are_biome_textures_enabled") else true,
		"landmark_debug_overlay_enabled": world.is_landmark_debug_overlay_enabled() if world.has_method("is_landmark_debug_overlay_enabled") else false,
		"biome_terrain_accents_enabled": world.are_biome_terrain_accents_enabled() if world.has_method("are_biome_terrain_accents_enabled") else false
	}


func _capture_world_visibility_culling_stats() -> Dictionary:
	if not is_instance_valid(world) or not world.has_method("get_visibility_culling_debug"):
		return {}
	return Dictionary(world.get_visibility_culling_debug())


func _capture_world_resource_render_mode_stats() -> Dictionary:
	if not is_instance_valid(world):
		return {}
	var resources: Array = []
	if world.has_method("get_cached_group_nodes"):
		resources = Array(world.call("get_cached_group_nodes", "resources"))
	else:
		resources = get_tree().get_nodes_in_group("resources")
	var render_only_resources := 0
	var render_only_grass := 0
	var active_resource_collisions := 0
	for resource_value in resources:
		var resource := resource_value as Node
		if resource == null:
			continue
		var is_render_only := false
		if resource.has_method("is_render_only_resource"):
			is_render_only = resource.call("is_render_only_resource") == true
		elif resource.has_method("get"):
			is_render_only = resource.get("render_only") == true
		if is_render_only:
			render_only_resources += 1
		var resource_kind := str(resource.get("resource_kind")) if resource.has_method("get") else ""
		if is_render_only and resource_kind in ["grass_patch", "dense_grass"]:
			render_only_grass += 1
		var collision_shape := resource.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision_shape != null and collision_shape.disabled == false:
			active_resource_collisions += 1
	return {
		"render_only_resources": render_only_resources,
		"render_only_grass": render_only_grass,
		"active_resource_collisions": active_resource_collisions
	}


func _capture_world_vegetation_stats() -> Dictionary:
	var result := {
		"grass_patch_node_count": 0,
		"dense_grass_node_count": 0,
		"decorative_grass_node_count": 0,
		"decorative_vegetation_visual_instance_count": 0,
		"decorative_vegetation_total_instance_count": 0,
		"decorative_vegetation_drawn_instance_count": 0,
		"decorative_vegetation_skipped_by_cap_count": 0,
		"decorative_vegetation_skipped_by_far_lod_count": 0,
		"decorative_vegetation_near_lod_count": 0,
		"decorative_vegetation_mid_lod_count": 0,
		"decorative_vegetation_far_lod_count": 0,
		"decorative_vegetation_max_drawn_instances": 0,
		"decorative_vegetation_visible_chunk_count": 0,
		"decorative_vegetation_total_chunk_count": 0,
		"decorative_vegetation_visual_count_by_kind": {},
		"edible_vegetation_node_count": 0,
		"interactive_resource_node_count": 0,
		"total_resource_node_count": 0
	}
	var resources: Array = []
	if is_instance_valid(world) and world.has_method("get_cached_group_nodes"):
		resources = Array(world.call("get_cached_group_nodes", "resources"))
	else:
		resources = get_tree().get_nodes_in_group("resources")
	for resource_value in resources:
		var resource := resource_value as Node
		if resource == null:
			continue
		result["total_resource_node_count"] = int(result["total_resource_node_count"]) + 1
		var resource_kind := ""
		if resource.has_method("get"):
			resource_kind = str(resource.get("resource_kind"))
		match resource_kind:
			"grass_patch":
				result["grass_patch_node_count"] = int(result["grass_patch_node_count"]) + 1
				result["decorative_grass_node_count"] = int(result["decorative_grass_node_count"]) + 1
			"dense_grass":
				result["dense_grass_node_count"] = int(result["dense_grass_node_count"]) + 1
				result["decorative_grass_node_count"] = int(result["decorative_grass_node_count"]) + 1
			_:
				result["interactive_resource_node_count"] = int(result["interactive_resource_node_count"]) + 1
		if resource.is_in_group("edible_vegetation"):
			result["edible_vegetation_node_count"] = int(result["edible_vegetation_node_count"]) + 1
	if is_instance_valid(world) and world.has_method("get_vegetation_visual_debug"):
		var visual_debug := Dictionary(world.call("get_vegetation_visual_debug"))
		result["decorative_vegetation_visual_instance_count"] = int(visual_debug.get("visual_instance_count", 0))
		result["decorative_vegetation_total_instance_count"] = int(visual_debug.get("total_instance_count", visual_debug.get("visual_instance_count", 0)))
		result["decorative_vegetation_drawn_instance_count"] = int(visual_debug.get("drawn_instance_count", 0))
		result["decorative_vegetation_skipped_by_cap_count"] = int(visual_debug.get("skipped_by_cap_count", 0))
		result["decorative_vegetation_skipped_by_far_lod_count"] = int(visual_debug.get("skipped_by_far_lod_count", 0))
		result["decorative_vegetation_near_lod_count"] = int(visual_debug.get("near_lod_count", 0))
		result["decorative_vegetation_mid_lod_count"] = int(visual_debug.get("mid_lod_count", 0))
		result["decorative_vegetation_far_lod_count"] = int(visual_debug.get("far_lod_count", 0))
		result["decorative_vegetation_max_drawn_instances"] = int(visual_debug.get("max_drawn_instances", 0))
		result["decorative_vegetation_visible_chunk_count"] = int(visual_debug.get("visible_chunk_count", 0))
		result["decorative_vegetation_total_chunk_count"] = int(visual_debug.get("total_chunk_count", 0))
		result["decorative_vegetation_visual_count_by_kind"] = Dictionary(visual_debug.get("count_by_kind", {}))
	return result


func _capture_player_stats() -> Dictionary:
	var stats: Dictionary = {}
	if not is_instance_valid(player):
		return stats
	stats["position"] = {"x": player.global_position.x, "y": player.global_position.y}
	stats["biome"] = _get_current_biome_name()
	var player_stats: Variant = player.get("stats")
	if player_stats is PlayerStats:
		var stats_ref: PlayerStats = player_stats
		stats["health"] = int(round(stats_ref.health))
		stats["hunger"] = int(round(stats_ref.hunger))
		stats["stamina"] = int(round(stats_ref.stamina))
		stats["rest"] = int(round(stats_ref.rest))
		stats["condition"] = stats_ref.get_condition_text()
	if player.has_method("get"):
		stats["has_spear"] = player.get("has_spear") == true
		stats["has_bow"] = player.get("has_bow") == true
	if player.has_method("get_torch_remaining_seconds"):
		stats["torch_remaining_seconds"] = float(player.get_torch_remaining_seconds())
	return stats


func _capture_ecosystem_stats() -> Dictionary:
	var stats: Dictionary = {}
	if not is_instance_valid(ecosystem_director) or not ecosystem_director.has_method("get_biome_states"):
		return stats
	var biome_states: Dictionary = ecosystem_director.get_biome_states()
	var biome_details: Dictionary = {}
	var total_biomass_percent := 0.0
	var total_population := 0.0
	var total_food_stress := 0.0
	var min_biomass_percent := 100.0
	var max_food_stress := 0.0
	var stressed_biome := ""
	for biome_id_value in biome_states.keys():
		var biome_id := str(biome_id_value)
		var state: Dictionary = Dictionary(biome_states[biome_id_value])
		var biomass_percent := float(state.get("plant_biomass_percent", 0.0))
		var food_stress := float(state.get("food_stress", 0.0))
		var population_count := float(state.get("population_count", 0.0))
		total_biomass_percent += biomass_percent
		total_population += population_count
		total_food_stress += food_stress
		if biomass_percent < min_biomass_percent:
			min_biomass_percent = biomass_percent
		if food_stress > max_food_stress:
			max_food_stress = food_stress
			stressed_biome = biome_id
		biome_details[biome_id] = {
			"name": str(state.get("name", biome_id)),
			"status": str(state.get("status", "unknown")),
			"current_niche": str(state.get("current_niche", "HERBIVORE")),
			"plant_biomass_percent": biomass_percent,
			"food_stress": food_stress,
			"population_count": population_count,
			"small_prey_population": float(state.get("small_prey_population", 0.0)),
			"grazer_population": float(state.get("grazer_population", 0.0)),
			"varnak_population": float(state.get("varnak_population", 0.0)),
			"predator_pressure": float(state.get("predator_pressure", 0.0)),
			"overgrazing_level": float(state.get("overgrazing_level", 0.0))
		}
	var biome_count := biome_details.size()
	stats["biome_count"] = biome_count
	stats["average_biomass_percent"] = total_biomass_percent / float(biome_count) if biome_count > 0 else 0.0
	stats["average_population"] = total_population / float(biome_count) if biome_count > 0 else 0.0
	stats["average_food_stress"] = total_food_stress / float(biome_count) if biome_count > 0 else 0.0
	stats["lowest_biomass_percent"] = min_biomass_percent if biome_count > 0 else 0.0
	stats["highest_food_stress"] = max_food_stress
	stats["most_stressed_biome"] = stressed_biome
	stats["biomes"] = biome_details
	return stats


func _calculate_driver_scores(sample: Dictionary) -> Dictionary:
	var performance: Dictionary = Dictionary(sample.get("performance", {}))
	var world_stats: Dictionary = Dictionary(sample.get("world", {}))
	var ecosystem_stats: Dictionary = Dictionary(sample.get("ecosystem", {}))
	var creature_counts: Dictionary = Dictionary(world_stats.get("creature_counts", {}))
	var resource_counts: Dictionary = Dictionary(world_stats.get("resource_counts", {}))
	var special_resource_counts: Dictionary = Dictionary(world_stats.get("special_resource_counts", {}))
	var total_creatures := float(world_stats.get("total_creatures", 0.0))
	var total_resources := float(world_stats.get("total_resources", 0.0))
	var vegetation_stats: Dictionary = Dictionary(world_stats.get("vegetation", {}))
	var draw_calls := float(performance.get("draw_calls", 0))
	var render_primitives := float(performance.get("render_primitives", 0))
	var render_objects := float(performance.get("render_objects", 0))
	var frame_time_ms := float(performance.get("frame_time_s", 0.0)) * 1000.0
	var physics_time_ms := float(performance.get("physics_time_s", 0.0)) * 1000.0
	var node_count := float(performance.get("node_count", 0))
	var physics_pairs := float(performance.get("physics_2d_collision_pairs", 0))
	var physics_active := float(performance.get("physics_2d_active", 0))
	var creature_pressure := total_creatures * 1.8 + float(creature_counts.get("varnak", 0)) * 1.4
	var decorative_grass_nodes := float(vegetation_stats.get("decorative_grass_node_count", 0))
	var drawn_visual_grass_instances := float(vegetation_stats.get("decorative_vegetation_drawn_instance_count", 0))
	var resource_pressure := total_resources * 0.8 + float(resource_counts.get("pond_vegetation", 0)) * 0.6 + float(special_resource_counts.get("edible_vegetation", 0)) * 0.4
	resource_pressure += drawn_visual_grass_instances * 0.03
	resource_pressure += decorative_grass_nodes * 0.5
	resource_pressure += float(vegetation_stats.get("decorative_vegetation_skipped_by_cap_count", 0)) * 0.01
	var render_pressure := draw_calls * 1.9 + render_primitives * 0.02 + render_objects * 0.8
	var physics_pressure := physics_time_ms * 8.0 + physics_pairs * 0.06 + physics_active * 0.08
	var scene_pressure := node_count * 0.02
	var ecosystem_pressure := float(ecosystem_stats.get("biome_count", 0)) * 0.8 + float(ecosystem_stats.get("highest_food_stress", 0.0)) * 5.0
	return {
		"render": render_pressure + frame_time_ms * 0.5,
		"physics": physics_pressure + frame_time_ms * 0.25,
		"creatures": creature_pressure + frame_time_ms * 0.2,
		"resources": resource_pressure + frame_time_ms * 0.15,
		"scene": scene_pressure + frame_time_ms * 0.1,
		"ecosystem": ecosystem_pressure + frame_time_ms * 0.12
	}


func _pick_likely_driver(driver_scores: Dictionary) -> String:
	var best_driver := "unknown"
	var best_score := -INF
	for key in driver_scores.keys():
		var score := float(driver_scores.get(key, 0.0))
		if score > best_score:
			best_score = score
			best_driver = str(key)
	return best_driver


func _calculate_load_score(sample: Dictionary) -> float:
	var performance: Dictionary = Dictionary(sample.get("performance", {}))
	var world_stats: Dictionary = Dictionary(sample.get("world", {}))
	var ecosystem_stats: Dictionary = Dictionary(sample.get("ecosystem", {}))
	var draw_calls := float(performance.get("draw_calls", 0))
	var render_primitives := float(performance.get("render_primitives", 0))
	var frame_time_ms := float(performance.get("frame_time_s", 0.0)) * 1000.0
	var physics_time_ms := float(performance.get("physics_time_s", 0.0)) * 1000.0
	var node_count := float(performance.get("node_count", 0))
	var total_creatures := float(world_stats.get("total_creatures", 0))
	var total_resources := float(world_stats.get("total_resources", 0))
	var vegetation_stats: Dictionary = Dictionary(world_stats.get("vegetation", {}))
	var out_of_bounds := float(world_stats.get("creatures_out_of_bounds_count", 0))
	var biome_count := float(ecosystem_stats.get("biome_count", 0))
	var food_stress := float(ecosystem_stats.get("highest_food_stress", 0.0))
	var decorative_grass_nodes := float(vegetation_stats.get("decorative_grass_node_count", 0))
	var drawn_visual_grass_instances := float(vegetation_stats.get("decorative_vegetation_drawn_instance_count", 0))
	return frame_time_ms + physics_time_ms * 0.8 + draw_calls * 0.08 + render_primitives * 0.001 + node_count * 0.01 + total_creatures * 0.06 + total_resources * 0.02 + decorative_grass_nodes * 0.05 + drawn_visual_grass_instances * 0.02 + out_of_bounds * 2.0 + biome_count * 0.4 + food_stress * 5.0


func _finish() -> void:
	running = false
	benchmark_progress.emit(BENCHMARK_DURATION_SECONDS, 0.0)
	var output_paths := _write_logs()
	if output_paths.is_empty():
		_post_message("Benchmark finished, but log writing failed")
		queue_free()
		return
	emit_signal("finished", str(output_paths.get("text", "")), str(output_paths.get("json", "")))
	queue_free()


func _write_logs() -> Dictionary:
	var output: Dictionary = {}
	var absolute_dir := ProjectSettings.globalize_path(LOG_DIRECTORY)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK:
		push_error("Could not create benchmark log directory: %s (error %d)" % [absolute_dir, dir_error])
		return output
	var text_path := "%s/%s.log" % [absolute_dir, benchmark_base_name]
	var json_path := "%s/%s.json" % [absolute_dir, benchmark_base_name]
	var report := _build_report()
	# Track benchmark file write timing for hitch logging
	var write_start_ms := Time.get_ticks_msec()
	var text_file := FileAccess.open(text_path, FileAccess.WRITE)
	if not text_file:
		push_error("Could not open benchmark log file for writing: %s (error %d)" % [text_path, FileAccess.get_open_error()])
		return output
	text_file.store_string(_format_report_text(report))
	text_file.flush()
	var json_file := FileAccess.open(json_path, FileAccess.WRITE)
	if not json_file:
		push_error("Could not open benchmark JSON file for writing: %s (error %d)" % [json_path, FileAccess.get_open_error()])
		return output
	json_file.store_string(JSON.stringify(report, "\t"))
	json_file.flush()
	benchmark_file_write_ms = float(Time.get_ticks_msec() - write_start_ms)
	output["text"] = text_path
	output["json"] = json_path
	return output


func _build_report() -> Dictionary:
	var top_samples := _get_top_samples(5)
	var heaviest_sample := Dictionary(top_samples[0]) if not top_samples.is_empty() else {}
	var total_samples := samples.size()
	var total_fps := 0.0
	var min_fps := 999999.0
	var max_fps := 0.0
	var max_frame_time_ms := 0.0
	var max_physics_time_ms := 0.0
	for sample_value in samples:
		var sample: Dictionary = Dictionary(sample_value)
		var performance: Dictionary = Dictionary(sample.get("performance", {}))
		var fps := float(performance.get("fps", 0))
		var frame_time_ms := float(performance.get("frame_time_s", 0.0)) * 1000.0
		var physics_time_ms := float(performance.get("physics_time_s", 0.0)) * 1000.0
		total_fps += fps
		min_fps = min(min_fps, fps)
		max_fps = max(max_fps, fps)
		max_frame_time_ms = max(max_frame_time_ms, frame_time_ms)
		max_physics_time_ms = max(max_physics_time_ms, physics_time_ms)
	var report := {
		"benchmark_name": "apex_shift_60_second_debug_benchmark",
		"duration_target_seconds": BENCHMARK_DURATION_SECONDS,
		"actual_duration_seconds": elapsed_seconds,
		"started_unix_time": int(start_unix_time),
		"sample_interval_seconds": SAMPLE_INTERVAL_SECONDS,
		"sample_count": total_samples,
		"average_fps": total_fps / float(total_samples) if total_samples > 0 else 0.0,
		"min_fps": min_fps if total_samples > 0 else 0.0,
		"max_fps": max_fps,
		"max_frame_time_ms": max_frame_time_ms,
		"max_physics_time_ms": max_physics_time_ms,
		"realtime_hitch_count": realtime_hitch_count,
		"max_realtime_delta_ms": max_realtime_delta_ms,
		"realtime_hitches": realtime_hitches,
		"heaviest_sample": heaviest_sample,
		"top_samples": top_samples,
		"samples": samples
	}
	report["threshold_validation"] = _validate_benchmark_thresholds(report)
	return report


func _get_top_samples(limit: int) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	for sample_value in samples:
		ranked.append(Dictionary(sample_value))
	ranked.sort_custom(Callable(self, "_sort_sample_descending"))
	if ranked.size() > limit:
		ranked.resize(limit)
	return ranked


func _sort_sample_descending(left: Dictionary, right: Dictionary) -> bool:
	return float(left.get("load_score", 0.0)) > float(right.get("load_score", 0.0))


func _format_report_text(report: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("Apex Shift benchmark")
	lines.append("Target duration: %.1fs" % float(report.get("duration_target_seconds", 0.0)))
	lines.append("Actual duration: %.2fs" % float(report.get("actual_duration_seconds", 0.0)))
	lines.append("Start unix time: %d" % int(report.get("started_unix_time", 0)))
	lines.append("Samples: %d" % int(report.get("sample_count", 0)))
	lines.append("Average FPS: %.2f" % float(report.get("average_fps", 0.0)))
	lines.append("Min FPS: %.2f" % float(report.get("min_fps", 0.0)))
	lines.append("Max FPS: %.2f" % float(report.get("max_fps", 0.0)))
	lines.append("Max frame time: %.2f ms" % float(report.get("max_frame_time_ms", 0.0)))
	lines.append("Max physics time: %.2f ms" % float(report.get("max_physics_time_ms", 0.0)))
	lines.append("Realtime hitch count: %d" % int(report.get("realtime_hitch_count", 0)))
	lines.append("Max realtime delta: %d ms" % int(report.get("max_realtime_delta_ms", 0)))
	lines.append("")
	lines.append(_format_threshold_validation_text(report))
	var heaviest_sample: Dictionary = Dictionary(report.get("heaviest_sample", {}))
	if not heaviest_sample.is_empty():
		lines.append("")
		lines.append("Heaviest sample:")
		lines.append(_format_sample_line(heaviest_sample))
		lines.append(_format_driver_scores(heaviest_sample))
		lines.append(_format_sample_diagnostics(heaviest_sample))
	lines.append("")
	lines.append("Top load samples:")
	for sample_value in Array(report.get("top_samples", [])):
		var sample: Dictionary = Dictionary(sample_value)
		lines.append(_format_sample_line(sample))
		lines.append(_format_driver_scores(sample))
		lines.append(_format_sample_diagnostics(sample))
	lines.append("")
	lines.append("Sample log:")
	for sample_value in Array(report.get("samples", [])):
		var sample := Dictionary(sample_value)
		lines.append(_format_sample_line(sample))
		lines.append(_format_sample_diagnostics(sample))
	lines.append("")
	lines.append("Suspected cost drivers:")
	for item in _build_suspected_cost_driver_lines(report):
		lines.append("- %s" % item)
	return "\n".join(lines)


func _load_benchmark_thresholds() -> Dictionary:
	var defaults := {
		"enabled": true,
		"fail_on_regression_by_default": false,
		"thresholds": {
			"average_fps_min": 50,
			"max_frame_time_ms_max": 80,
			"realtime_hitch_count_max": 3,
			"max_realtime_delta_ms_max": 250,
			"minimap_texture_build_count_max": 2,
			"map_screen_texture_build_count_max": 2,
			"world_biome_texture_build_count_max": 2,
			"active_resource_collisions_max": 80,
			"node_count_max": 2500
		}
	}
	if not FileAccess.file_exists(BENCHMARK_THRESHOLDS_PATH):
		return defaults
	var file := FileAccess.open(BENCHMARK_THRESHOLDS_PATH, FileAccess.READ)
	if file == null:
		return defaults
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		var parsed_dict := Dictionary(parsed)
		if not parsed_dict.has("thresholds"):
			parsed_dict["thresholds"] = defaults["thresholds"]
		return parsed_dict
	return defaults


func _should_fail_on_regression(threshold_config: Dictionary) -> bool:
	var env_value := ""
	if OS.has_environment("APEX_BENCHMARK_FAIL_ON_REGRESSION"):
		env_value = OS.get_environment("APEX_BENCHMARK_FAIL_ON_REGRESSION")
		var normalized := env_value.to_lower()
		if normalized in ["1", "true", "yes"]:
			return true
		if normalized in ["0", "false", "no"]:
			return false
	if "--benchmark-fail-on-regression" in OS.get_cmdline_args():
		return true
	return bool(threshold_config.get("fail_on_regression_by_default", false))


func _extract_regression_metrics(report: Dictionary) -> Dictionary:
	var metrics := {
		"average_fps": float(report.get("average_fps", 0.0)),
		"max_frame_time_ms": float(report.get("max_frame_time_ms", 0.0)),
		"realtime_hitch_count": int(report.get("realtime_hitch_count", 0)),
		"max_realtime_delta_ms": int(report.get("max_realtime_delta_ms", 0)),
		"minimap_texture_build_count": 0,
		"map_screen_texture_build_count": 0,
		"world_biome_texture_build_count": 0,
		"active_resource_collisions": 0,
		"node_count": 0
	}
	var missing_metric_set: Dictionary = {}
	var samples_array := Array(report.get("samples", []))
	if samples_array.is_empty():
		metrics["missing_metrics"] = [
			"minimap_texture_build_count",
			"map_screen_texture_build_count",
			"world_biome_texture_build_count",
			"active_resource_collisions",
			"node_count"
		]
		return metrics
	for sample_value in samples_array:
		var sample: Dictionary = Dictionary(sample_value)
		var performance: Dictionary = Dictionary(sample.get("performance", {}))
		var world_stats: Dictionary = Dictionary(sample.get("world", {}))
		var minimap_stats: Dictionary = Dictionary(sample.get("minimap", {}))
		var map_screen_stats: Dictionary = Dictionary(sample.get("map_screen", {}))
		var resource_render_mode: Dictionary = Dictionary(world_stats.get("resource_render_mode", {}))
		if performance.has("node_count"):
			metrics["node_count"] = maxi(int(metrics["node_count"]), int(performance.get("node_count", 0)))
		else:
			missing_metric_set["node_count"] = true
		if resource_render_mode.has("active_resource_collisions"):
			metrics["active_resource_collisions"] = maxi(int(metrics["active_resource_collisions"]), int(resource_render_mode.get("active_resource_collisions", 0)))
		else:
			missing_metric_set["active_resource_collisions"] = true
		if minimap_stats.has("texture_build_count"):
			metrics["minimap_texture_build_count"] = maxi(int(metrics["minimap_texture_build_count"]), int(minimap_stats.get("texture_build_count", 0)))
		else:
			missing_metric_set["minimap_texture_build_count"] = true
		if map_screen_stats.has("texture_build_count"):
			metrics["map_screen_texture_build_count"] = maxi(int(metrics["map_screen_texture_build_count"]), int(map_screen_stats.get("texture_build_count", 0)))
		else:
			missing_metric_set["map_screen_texture_build_count"] = true
		var biome_cache: Dictionary = Dictionary(world_stats.get("biome_texture_cache", {}))
		if biome_cache.has("world_biome_texture_build_count"):
			metrics["world_biome_texture_build_count"] = maxi(int(metrics["world_biome_texture_build_count"]), int(biome_cache.get("world_biome_texture_build_count", 0)))
		else:
			missing_metric_set["world_biome_texture_build_count"] = true
	var missing_metrics: Array[String] = []
	for metric_name in missing_metric_set.keys():
		missing_metrics.append(str(metric_name))
	if not missing_metrics.is_empty():
		missing_metrics.sort()
		metrics["missing_metrics"] = missing_metrics
	return metrics


func _validate_benchmark_thresholds(report: Dictionary) -> Dictionary:
	var threshold_config := _load_benchmark_thresholds()
	var enabled := bool(threshold_config.get("enabled", true))
	var thresholds := Dictionary(threshold_config.get("thresholds", {}))
	var fail_on_regression := _should_fail_on_regression(threshold_config)
	var metrics := _extract_regression_metrics(report)
	var violations: Array[Dictionary] = []
	var warnings: Array[Dictionary] = []
	var missing_metrics: Array = Array(metrics.get("missing_metrics", []))
	if not enabled:
		return {
			"status": "passed",
			"fail_on_regression": fail_on_regression,
			"thresholds_path": BENCHMARK_THRESHOLDS_PATH,
			"metrics": metrics,
			"thresholds": thresholds,
			"violations": violations,
			"warnings": warnings,
			"missing_metrics": missing_metrics
		}
	_check_threshold_min(metrics, thresholds, violations, warnings, "average_fps", "average_fps_min", ">=", "average_fps %s is below required minimum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, "max_frame_time_ms", "max_frame_time_ms_max", "<=", "max_frame_time_ms %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, "realtime_hitch_count", "realtime_hitch_count_max", "<=", "realtime_hitch_count %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, "max_realtime_delta_ms", "max_realtime_delta_ms_max", "<=", "max_realtime_delta_ms %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, "minimap_texture_build_count", "minimap_texture_build_count_max", "<=", "minimap_texture_build_count %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, "map_screen_texture_build_count", "map_screen_texture_build_count_max", "<=", "map_screen_texture_build_count %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, "world_biome_texture_build_count", "world_biome_texture_build_count_max", "<=", "world_biome_texture_build_count %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, "active_resource_collisions", "active_resource_collisions_max", "<=", "active_resource_collisions %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, "node_count", "node_count_max", "<=", "node_count %s exceeds maximum %s")
	var status := "passed"
	if not violations.is_empty():
		status = "failed" if fail_on_regression else "warning"
	elif not warnings.is_empty() or not missing_metrics.is_empty():
		status = "warning"
	return {
		"status": status,
		"fail_on_regression": fail_on_regression,
		"thresholds_path": BENCHMARK_THRESHOLDS_PATH,
		"metrics": metrics,
		"thresholds": thresholds,
		"violations": violations,
		"warnings": warnings,
		"missing_metrics": missing_metrics
	}


func _check_threshold_min(metrics: Dictionary, thresholds: Dictionary, violations: Array[Dictionary], warnings: Array[Dictionary], metric_name: String, threshold_name: String, operator_text: String, message_template: String) -> void:
	if not metrics.has(metric_name):
		warnings.append({
			"metric": metric_name,
			"message": "Metric missing from benchmark report"
		})
		return
	if not thresholds.has(threshold_name):
		return
	var actual := float(metrics.get(metric_name, 0.0))
	var threshold := float(thresholds.get(threshold_name, 0.0))
	if actual < threshold:
		violations.append(_build_threshold_violation(metric_name, operator_text, threshold, actual, "warning", message_template))


func _check_threshold_max(metrics: Dictionary, thresholds: Dictionary, violations: Array[Dictionary], warnings: Array[Dictionary], metric_name: String, threshold_name: String, operator_text: String, message_template: String) -> void:
	if not metrics.has(metric_name):
		warnings.append({
			"metric": metric_name,
			"message": "Metric missing from benchmark report"
		})
		return
	if not thresholds.has(threshold_name):
		return
	var actual := float(metrics.get(metric_name, 0.0))
	var threshold := float(thresholds.get(threshold_name, 0.0))
	if actual > threshold:
		violations.append(_build_threshold_violation(metric_name, operator_text, threshold, actual, "warning", message_template))


func _build_threshold_violation(metric_name: String, operator_text: String, threshold: float, actual: float, severity: String, message_template: String) -> Dictionary:
	return {
		"metric": metric_name,
		"operator": operator_text,
		"threshold": threshold,
		"actual": actual,
		"severity": severity,
		"message": message_template % [actual, threshold]
	}


func _format_threshold_validation_text(report: Dictionary) -> String:
	var validation := Dictionary(report.get("threshold_validation", {}))
	if validation.is_empty():
		return "Threshold validation: unavailable"
	var status := str(validation.get("status", "warning")).to_upper()
	var fail_on_regression := bool(validation.get("fail_on_regression", false))
	var lines: Array[String] = []
	lines.append("Threshold validation: %s" % status)
	lines.append("Regression metrics:")
	var metrics := Dictionary(validation.get("metrics", {}))
	var thresholds := Dictionary(validation.get("thresholds", {}))
	_append_threshold_metric_line(lines, metrics, thresholds, "average_fps", "average_fps_min", ">=")
	_append_threshold_metric_line(lines, metrics, thresholds, "max_frame_time_ms", "max_frame_time_ms_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "realtime_hitch_count", "realtime_hitch_count_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "max_realtime_delta_ms", "max_realtime_delta_ms_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "minimap_texture_build_count", "minimap_texture_build_count_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "map_screen_texture_build_count", "map_screen_texture_build_count_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "world_biome_texture_build_count", "world_biome_texture_build_count_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "active_resource_collisions", "active_resource_collisions_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "node_count", "node_count_max", "<=")
	if Array(validation.get("missing_metrics", [])).size() > 0:
		lines.append("Missing metrics:")
		for metric_name in Array(validation.get("missing_metrics", [])):
			lines.append("- %s: Metric missing from benchmark report" % str(metric_name))
	if not Array(validation.get("violations", [])).is_empty():
		lines.append("Violations:")
		for violation_value in Array(validation.get("violations", [])):
			var violation := Dictionary(violation_value)
			lines.append("- %s" % str(violation.get("message", violation.get("metric", "violation"))))
	if not Array(validation.get("warnings", [])).is_empty():
		lines.append("Warnings:")
		for warning_value in Array(validation.get("warnings", [])):
			var warning := Dictionary(warning_value)
			lines.append("- %s: %s" % [str(warning.get("metric", "metric")), str(warning.get("message", "warning"))])
	lines.append("Fail on regression: %s" % ("true" if fail_on_regression else "false"))
	return "\n".join(lines)


func _append_threshold_metric_line(lines: Array[String], metrics: Dictionary, thresholds: Dictionary, metric_name: String, threshold_name: String, operator_text: String) -> void:
	if not metrics.has(metric_name) or not thresholds.has(threshold_name):
		return
	var actual := float(metrics.get(metric_name, 0.0))
	var threshold := float(thresholds.get(threshold_name, 0.0))
	var status := "OK"
	var comparison_ok := actual >= threshold if operator_text == ">=" else actual <= threshold
	if not comparison_ok:
		status = "VIOLATION"
	lines.append("- %s: %s %s %s %s" % [metric_name, _format_metric_value(actual), operator_text, _format_metric_value(threshold), status])


func _format_metric_value(value: float) -> String:
	if absf(value - round(value)) < 0.001:
		return str(int(round(value)))
	return "%.2f" % value


func _format_sample_line(sample: Dictionary) -> String:
	var performance: Dictionary = Dictionary(sample.get("performance", {}))
	var world_stats: Dictionary = Dictionary(sample.get("world", {}))
	var fps := int(performance.get("fps", 0))
	var frame_time_ms := float(performance.get("frame_time_s", 0.0)) * 1000.0
	var physics_time_ms := float(performance.get("physics_time_s", 0.0)) * 1000.0
	var draw_calls := int(performance.get("draw_calls", 0))
	var render_primitives := int(performance.get("render_primitives", 0))
	var node_count := int(performance.get("node_count", 0))
	var total_creatures := int(world_stats.get("total_creatures", 0))
	var total_resources := int(world_stats.get("total_resources", 0))
	var oob := int(world_stats.get("creatures_out_of_bounds_count", 0))
	var window_focused := bool(performance.get("window_focused", false))
	var driver := str(sample.get("likely_driver", "unknown"))
	return "[%s] fps=%d frame=%.2fms physics=%.2fms draw_calls=%d primitives=%d nodes=%d creatures=%d resources=%d oob=%d focused=%s driver=%s score=%.2f" % [
		str(sample.get("time_label", "00:00")),
		fps,
		frame_time_ms,
		physics_time_ms,
		draw_calls,
		render_primitives,
		node_count,
		total_creatures,
		total_resources,
		oob,
		"true" if window_focused else "false",
		driver,
		float(sample.get("load_score", 0.0))
	]


func _format_driver_scores(sample: Dictionary) -> String:
	var driver_scores: Dictionary = Dictionary(sample.get("driver_scores", {}))
	if driver_scores.is_empty():
		return "  driver scores unavailable"
	return "  driver_scores render=%.2f physics=%.2f creatures=%.2f resources=%.2f scene=%.2f ecosystem=%.2f" % [
		float(driver_scores.get("render", 0.0)),
		float(driver_scores.get("physics", 0.0)),
		float(driver_scores.get("creatures", 0.0)),
		float(driver_scores.get("resources", 0.0)),
		float(driver_scores.get("scene", 0.0)),
		float(driver_scores.get("ecosystem", 0.0))
	]


func _format_sample_diagnostics(sample: Dictionary) -> String:
	var world_stats: Dictionary = Dictionary(sample.get("world", {}))
	var minimap_stats: Dictionary = Dictionary(sample.get("minimap", {}))
	var map_screen_stats: Dictionary = Dictionary(sample.get("map_screen", {}))
	var ai_decisions: Dictionary = Dictionary(sample.get("ai_decisions", {}))
	var boot_stats: Dictionary = Dictionary(world_stats.get("boot", {}))
	var texture_cache: Dictionary = Dictionary(world_stats.get("biome_texture_cache", {}))
	var landmark_debug: Dictionary = Dictionary(world_stats.get("landmark_debug", {}))
	var registry_stats: Dictionary = Dictionary(world_stats.get("registry", {}))
	var render_flags: Dictionary = Dictionary(world_stats.get("render_flags", {}))
	var visibility_culling: Dictionary = Dictionary(world_stats.get("visibility_culling", {}))
	var biome_query: Dictionary = Dictionary(world_stats.get("biome_query", {}))
	var diagnostics: Array[String] = []
	if not boot_stats.is_empty():
		diagnostics.append("boot=%s %.0f%% \"%s\"" % [
			"ready" if bool(boot_stats.get("ready", false)) else "loading",
			float(boot_stats.get("progress", 0.0)) * 100.0,
			str(boot_stats.get("stage_message", "unknown"))
		])
	if not texture_cache.is_empty():
		diagnostics.append("textures=%s blend=%s size=%s accent_cache=%d pending=%d build_running=%s sample_images=%d key_len=%d" % [
			"on" if bool(texture_cache.get("textures_enabled", true)) else "off",
			"yes" if bool(texture_cache.get("has_blend_texture", false)) else "no",
			str(texture_cache.get("blend_texture_size", "Vector2i(0, 0)")),
			int(texture_cache.get("accent_cache_count", 0)),
			int(texture_cache.get("pending_biomes", 0)),
			"true" if bool(texture_cache.get("build_running", false)) else "false",
			int(texture_cache.get("sample_image_cache_count", 0)),
			int(texture_cache.get("blend_colors_key_length", 0))
		])
	if not landmark_debug.is_empty():
		diagnostics.append("landmarks generated=%d pond=%d hill=%d" % [
			int(landmark_debug.get("generated", 0)),
			int(landmark_debug.get("pond", 0)),
			int(landmark_debug.get("hill", 0))
		])
	if not registry_stats.is_empty():
		diagnostics.append("registry resources=%d buildings=%d" % [
			int(registry_stats.get("registered_resources", 0)),
			int(registry_stats.get("registered_buildings", 0))
		])
	if not render_flags.is_empty():
		diagnostics.append("flags low_end=%s biome_textures=%s landmark_overlay=%s biome_terrain_accents=%s" % [
			"true" if bool(render_flags.get("low_end_rendering", false)) else "false",
			"true" if bool(render_flags.get("biome_textures_enabled", true)) else "false",
			"true" if bool(render_flags.get("landmark_debug_overlay_enabled", false)) else "false",
			"true" if bool(render_flags.get("biome_terrain_accents_enabled", false)) else "false"
		])
	if not visibility_culling.is_empty():
		diagnostics.append("culling enabled=%s visible_resources=%d hidden_resources=%d visible_creatures=%d hidden_creatures=%d" % [
			"true" if bool(visibility_culling.get("enabled", false)) else "false",
			int(visibility_culling.get("visible_resources", 0)),
			int(visibility_culling.get("hidden_resources", 0)),
			int(visibility_culling.get("visible_creatures", 0)),
			int(visibility_culling.get("hidden_creatures", 0))
		])
	if not biome_query.is_empty():
		diagnostics.append("biome_query cell_size=%.0f cache=%d hits=%d misses=%d polygon_checks=%d" % [
			float(biome_query.get("cell_size", 0.0)),
			int(biome_query.get("cache_size", 0)),
			int(biome_query.get("cache_hit_count", 0)),
			int(biome_query.get("cache_miss_count", 0)),
			int(biome_query.get("polygon_check_count", 0))
		])
	var resource_render_mode: Dictionary = Dictionary(world_stats.get("resource_render_mode", {}))
	if not resource_render_mode.is_empty():
		diagnostics.append("resource_render_mode render_only_resources=%d render_only_grass=%d active_resource_collisions=%d" % [
			int(resource_render_mode.get("render_only_resources", 0)),
			int(resource_render_mode.get("render_only_grass", 0)),
			int(resource_render_mode.get("active_resource_collisions", 0))
		])
	var vegetation_stats: Dictionary = Dictionary(world_stats.get("vegetation", {}))
	if not vegetation_stats.is_empty():
		diagnostics.append("vegetation grass_nodes=%d visuals=%d total_visual_instances=%d drawn=%d visible_chunks=%d edible_nodes=%d interactive=%d" % [
			int(vegetation_stats.get("decorative_grass_node_count", 0)),
			int(vegetation_stats.get("decorative_vegetation_visual_instance_count", 0)),
			int(vegetation_stats.get("decorative_vegetation_total_instance_count", 0)),
			int(vegetation_stats.get("decorative_vegetation_drawn_instance_count", 0)),
			int(vegetation_stats.get("decorative_vegetation_visible_chunk_count", 0)),
			int(vegetation_stats.get("edible_vegetation_node_count", 0)),
			int(vegetation_stats.get("interactive_resource_node_count", 0))
		])
	if not minimap_stats.is_empty():
		diagnostics.append("minimap redraw=%d marker_cache=%d landmark_cache=%d texture_builds=%d last_build_ms=%.2f" % [
			int(minimap_stats.get("redraw_count", 0)),
			int(minimap_stats.get("marker_cache_rebuild_count", 0)),
			int(minimap_stats.get("landmark_cache_rebuild_count", 0)),
			int(minimap_stats.get("texture_build_count", 0)),
			float(minimap_stats.get("texture_last_build_ms", 0.0))
		])
	if not map_screen_stats.is_empty():
		diagnostics.append("map_screen redraw=%d cache=%d skipped_hidden=%d texture_builds=%d last_build_ms=%.2f" % [
			int(map_screen_stats.get("redraw_count", 0)),
			int(map_screen_stats.get("cache_rebuild_count", 0)),
			int(map_screen_stats.get("skipped_update_hidden_count", 0)),
			int(map_screen_stats.get("texture_build_count", 0)),
			float(map_screen_stats.get("texture_last_build_ms", 0.0))
		])
	if not ai_decisions.is_empty():
		diagnostics.append("ai small_prey=%d/%d avg=%.1f grazer=%d/%d avg=%.1f varnak=%d/%d avg=%.1f" % [
			int(Dictionary(ai_decisions.get("small_prey", {})).get("count", 0)),
			int(Dictionary(ai_decisions.get("small_prey", {})).get("total_decisions", 0)),
			float(Dictionary(ai_decisions.get("small_prey", {})).get("average_decisions_per_entity", 0.0)),
			int(Dictionary(ai_decisions.get("grazer", {})).get("count", 0)),
			int(Dictionary(ai_decisions.get("grazer", {})).get("total_decisions", 0)),
			float(Dictionary(ai_decisions.get("grazer", {})).get("average_decisions_per_entity", 0.0)),
			int(Dictionary(ai_decisions.get("varnak", {})).get("count", 0)),
			int(Dictionary(ai_decisions.get("varnak", {})).get("total_decisions", 0)),
			float(Dictionary(ai_decisions.get("varnak", {})).get("average_decisions_per_entity", 0.0))
		])
	var current_biome := str(world_stats.get("current_biome", "unknown"))
	var world_rect := str(world_stats.get("world_rect", "unknown"))
	diagnostics.append("world biome=%s rect=%s total_resources=%d total_creatures=%d oob=%d" % [
		current_biome,
		world_rect,
		int(world_stats.get("total_resources", 0)),
		int(world_stats.get("total_creatures", 0)),
		int(world_stats.get("creatures_out_of_bounds_count", 0))
	])
	return "  diagnostics %s" % " | ".join(diagnostics)


func _build_suspected_cost_driver_lines(report: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var heaviest_sample: Dictionary = Dictionary(report.get("heaviest_sample", {}))
	var performance: Dictionary = Dictionary(heaviest_sample.get("performance", {}))
	var world_stats: Dictionary = Dictionary(heaviest_sample.get("world", {}))
	var vegetation_stats: Dictionary = Dictionary(world_stats.get("vegetation", {}))
	var resource_render_mode: Dictionary = Dictionary(world_stats.get("resource_render_mode", {}))
	var visibility_culling: Dictionary = Dictionary(world_stats.get("visibility_culling", {}))
	var minimap_stats: Dictionary = Dictionary(heaviest_sample.get("minimap", {}))
	var map_screen_stats: Dictionary = Dictionary(heaviest_sample.get("map_screen", {}))
	var ai_decisions: Dictionary = Dictionary(heaviest_sample.get("ai_decisions", {}))
	var draw_calls := float(performance.get("draw_calls", 0))
	var render_primitives := float(performance.get("render_primitives", 0))
	var frame_time_ms := float(performance.get("frame_time_s", 0.0)) * 1000.0
	var physics_time_ms := float(performance.get("physics_time_s", 0.0)) * 1000.0
	var node_count := float(performance.get("node_count", 0))
	var total_resources := float(world_stats.get("total_resources", 0))
	var total_creatures := float(world_stats.get("total_creatures", 0))
	var active_collisions := float(resource_render_mode.get("active_resource_collisions", 0))
	var visible_resources := float(visibility_culling.get("visible_resources", 0))
	var hidden_resources := float(visibility_culling.get("hidden_resources", 0))
	var visible_creatures := float(visibility_culling.get("visible_creatures", 0))
	var hidden_creatures := float(visibility_culling.get("hidden_creatures", 0))
	var minimap_texture_builds := float(minimap_stats.get("texture_build_count", 0))
	var map_screen_texture_builds := float(map_screen_stats.get("texture_build_count", 0))
	var world_texture_builds := float(Dictionary(world_stats.get("biome_texture_cache", {})).get("world_biome_texture_build_count", 0))
	var small_prey_ai := Dictionary(ai_decisions.get("small_prey", {}))
	var grazer_ai := Dictionary(ai_decisions.get("grazer", {}))
	var varnak_ai := Dictionary(ai_decisions.get("varnak", {}))
	if draw_calls >= 700 or render_primitives >= 20000:
		lines.append("Rendering pressure looks high: draw calls and/or render primitives are elevated.")
	if physics_time_ms >= 5.0 or active_collisions >= 20.0:
		lines.append("Physics/resource collision pressure looks high: active resource collisions may be contributing.")
	if frame_time_ms >= 20.0 and (minimap_texture_builds > 0.0 or map_screen_texture_builds > 0.0 or world_texture_builds > 0.0):
		lines.append("Texture/cache rebuilds may be contributing to frame spikes.")
	if node_count >= 1000 or total_resources >= 200.0 or total_creatures >= 50.0:
		lines.append("Scene pressure looks elevated from node/resource/creature counts.")
	if int(visible_resources + hidden_resources + visible_creatures + hidden_creatures) == 0:
		lines.append("Visibility culling debug is empty, so culling instrumentation may not be wired correctly.")
	if int(minimap_texture_builds) > 0 or int(map_screen_texture_builds) > 0 or int(world_texture_builds) > 0:
		lines.append("Cache rebuild counts are present, so repeated rebuild spikes should be checked if hitching persists.")
	if int(small_prey_ai.get("total_decisions", 0)) > 0 or int(grazer_ai.get("total_decisions", 0)) > 0 or int(varnak_ai.get("total_decisions", 0)) > 0:
		lines.append("AI decision pressure is measurable; compare total decisions against entity counts for hotspots.")
	if lines.is_empty():
		lines.append("No obvious dominant driver from the current heuristics.")
	return lines


func _get_group_nodes(group_name: String) -> Array:
	if is_instance_valid(world) and world.has_method("get_cached_group_nodes"):
		return Array(world.call("get_cached_group_nodes", group_name))
	return get_tree().get_nodes_in_group(group_name)


func _capture_group_counts(group_names: Array[String]) -> Dictionary:
	var counts: Dictionary = {}
	for group_name in group_names:
		counts[group_name] = _get_group_count(group_name)
	return counts


func _get_group_count(group_name: String) -> int:
	if is_instance_valid(world) and world.has_method("get_cached_group_nodes"):
		return int((world.call("get_cached_group_nodes", group_name) as Array).size())
	return get_tree().get_nodes_in_group(group_name).size()


func _sum_group_counts(counts: Dictionary) -> int:
	var total := 0
	for key in counts.keys():
		total += int(counts.get(key, 0))
	return total


func _log_hitch(delta: float, system_name: String, flags: Dictionary = {}) -> void:
	if delta <= 0.1:
		return
	var flag_text := ""
	for key in flags.keys():
		if not flag_text.is_empty():
			flag_text += " "
		flag_text += "%s=%s" % [str(key), str(flags.get(key))]
	print("[HITCH] %s delta=%.3f %s" % [system_name, delta, flag_text])


func _count_landmarks_by_type(landmarks: Array[Dictionary], landmark_type: String) -> int:
	var count := 0
	for landmark_value in landmarks:
		var landmark: Dictionary = Dictionary(landmark_value)
		if str(landmark.get("type", "")) == landmark_type:
			count += 1
	return count


func _get_current_biome_name() -> String:
	if not is_instance_valid(player):
		return "unknown"
	for biome in WorldConfig.get_biome_zones():
		if Geometry2D.is_point_in_polygon(player.global_position, PackedVector2Array(biome.get("points", []))):
			return str(biome.get("name", "Biome"))
	return "outside world"


func _format_time(seconds: float) -> String:
	var whole_seconds := int(floor(seconds))
	var minutes := float(whole_seconds) / 60.0
	var remainder := whole_seconds % 60
	return "%02d:%02d" % [minutes, remainder]


func _post_message(message: String) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_method("post_message"):
		event_bus.post_message(message)
