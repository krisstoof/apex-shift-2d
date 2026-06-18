extends Node
class_name BenchmarkRunner

signal finished(log_path: String, json_path: String)
signal benchmark_progress(elapsed_seconds: float, remaining_seconds: float)

const BENCHMARK_DURATION_SECONDS := 60.0
const SAMPLE_INTERVAL_SECONDS := 1.0
const LOG_DIRECTORY := "user://benchmark_logs"
const BENCHMARK_THRESHOLDS_PATH := "res://config/benchmark_thresholds.json"
const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const RUNTIME_PROFILER := preload("res://scripts/debug/runtime_profiler.gd")

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
var active_preset_name := "normal"

# HITCH LOGGER COUNTERS
var benchmark_sample_build_ms: float = 0.0
var benchmark_sample_collection_ms: float = 0.0
var benchmark_world_debug_collection_ms: float = 0.0
var benchmark_hitch_capture_ms: float = 0.0
var benchmark_report_build_ms: float = 0.0
var deep_debug := false
var benchmark_file_write_ms: float = 0.0
var last_reported_second := -1

var scene: Node
var world: Node
var minimap: Node
var map_screen: Node
var hud: Node
var player: Node2D
var evolution_director: Node
var day_night_system: Node
var ecosystem_director: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func start(preset_name: String = "normal") -> bool:
	if running:
		return false
	active_preset_name = preset_name
	if not _capture_context():
		_post_message("Benchmark could not start: missing game state")
		queue_free()
		return false
	_apply_biome_textures_preset(preset_name)
	if preset_name == "map_open":
		_open_map_screen_for_benchmark()
	running = true
	elapsed_seconds = 0.0
	sample_timer = 0.0
	deep_debug = preset_name == "deep_debug"
	RUNTIME_PROFILER.reset()
	start_ticks_usec = Time.get_ticks_usec()
	start_unix_time = Time.get_unix_time_from_system()
	benchmark_base_name = "benchmark_%s_%d" % [preset_name, int(start_unix_time)]
	samples.clear()
	last_process_ticks_msec = 0
	realtime_hitch_count = 0
	max_realtime_delta_ms = 0
	realtime_hitches.clear()
	benchmark_sample_build_ms = 0.0
	benchmark_sample_collection_ms = 0.0
	benchmark_world_debug_collection_ms = 0.0
	benchmark_hitch_capture_ms = 0.0
	benchmark_report_build_ms = 0.0
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
	var hitch_start := Time.get_ticks_usec()
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
				"sample_timer": sample_timer
			}
			if deep_debug:
				hitch["world_debug"] = _capture_lightweight_world_debug()
			realtime_hitches.append(hitch)
			if realtime_hitches.size() > (40 if deep_debug else 12):
				realtime_hitches.pop_front()
			push_warning("[REALTIME_HITCH] %d ms engine_delta=%.1f sample_count=%d" % [
				realtime_delta_ms,
				delta * 1000.0,
				samples.size()
			])
	benchmark_hitch_capture_ms = float(Time.get_ticks_usec() - hitch_start) / 1000.0
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
	hud = scene.get_node_or_null("HUD")
	minimap = scene.get_node_or_null("HUD/Minimap")
	map_screen = scene.get_node_or_null("HUD/MapScreen")
	player = scene.get_node_or_null("Player") as Node2D
	evolution_director = scene.get_node_or_null("EvolutionDirector")
	day_night_system = scene.get_node_or_null("DayNightSystem")
	ecosystem_director = scene.get_node_or_null("EcosystemDirector")
	return is_instance_valid(world) and is_instance_valid(player) and is_instance_valid(evolution_director) and is_instance_valid(day_night_system) and is_instance_valid(ecosystem_director)


func _open_map_screen_for_benchmark() -> bool:
	if not is_instance_valid(hud) or not hud.has_method("_set_map_screen_open"):
		return false
	hud.call("_set_map_screen_open", true)
	return true


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


func _apply_biome_textures_preset(preset_name: String) -> void:
	"""Apply BIOME_TEXTURES preset and sync graphics settings (debug/benchmark only)."""
	if not is_instance_valid(world):
		return
	
	# Get preset configuration
	var preset_config: Dictionary = Dictionary(GAME_BALANCE.get_biome_textures_with_preset(preset_name))
	
	# Apply key preset values to world
	if "biome_textures_enabled" in preset_config:
		if world.has_method("debug_toggle_biome_textures"):
			var current_state: bool = world.are_biome_textures_enabled() if world.has_method("are_biome_textures_enabled") else true
			var target_state := bool(preset_config["biome_textures_enabled"])
			if current_state != target_state:
				world.debug_toggle_biome_textures()
	
	# Store preset in world for reporting
	if world.has_method("set_benchmark_preset_name"):
		world.set_benchmark_preset_name(preset_name)
	
	_post_message("Applied BIOME_TEXTURES preset: %s" % preset_name)


func _record_sample() -> void:
	if not running:
		return
	var sample_start_ms: int = Time.get_ticks_msec()
	var sample: Dictionary = _capture_sample()
	benchmark_sample_build_ms = float(Time.get_ticks_msec() - sample_start_ms)
	sample["benchmark_sample_build_ms"] = benchmark_sample_build_ms
	sample["benchmark_sample_collection_ms"] = benchmark_sample_collection_ms
	sample["benchmark_world_debug_collection_ms"] = benchmark_world_debug_collection_ms
	sample["benchmark_hitch_capture_ms"] = benchmark_hitch_capture_ms
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
	var sample_collection_start := Time.get_ticks_usec()
	var sample: Dictionary = {}
	sample["sample_index"] = samples.size() + 1
	sample["elapsed_seconds"] = elapsed_seconds
	sample["time_label"] = _format_time(elapsed_seconds)
	sample["performance"] = _capture_performance_stats()
	sample["world"] = _capture_world_stats(deep_debug)
	sample["minimap"] = _capture_minimap_stats()
	sample["map_screen"] = _capture_map_screen_stats()
	sample["player"] = _capture_player_stats()
	if deep_debug:
		var world_debug_start := Time.get_ticks_usec()
		sample["world_deep_debug"] = _capture_world_stats_deep()
		sample["ecosystem"] = _capture_ecosystem_stats()
		sample["ai_decisions"] = _capture_ai_decision_stats()
		benchmark_world_debug_collection_ms = float(Time.get_ticks_usec() - world_debug_start) / 1000.0
	else:
		benchmark_world_debug_collection_ms = 0.0
	sample["driver_scores"] = _calculate_driver_scores(sample)
	sample["likely_driver"] = _pick_likely_driver(Dictionary(sample.get("driver_scores", {})))
	sample["load_score"] = _calculate_load_score(sample)
	var render_attribution := RUNTIME_PROFILER.get_rolling_summary()
	benchmark_sample_collection_ms = float(Time.get_ticks_usec() - sample_collection_start) / 1000.0
	render_attribution["benchmark_sample_collection_ms"] = benchmark_sample_collection_ms
	render_attribution["benchmark_world_debug_collection_ms"] = benchmark_world_debug_collection_ms
	render_attribution["benchmark_hitch_capture_ms"] = benchmark_hitch_capture_ms
	sample["render_attribution"] = render_attribution
	var likely_render_subsystem := _pick_likely_render_subsystem(render_attribution)
	if not likely_render_subsystem.is_empty():
		sample["likely_render_subsystem"] = likely_render_subsystem
		var parent_scope := _pick_likely_render_parent_scope(render_attribution, likely_render_subsystem)
		if not parent_scope.is_empty():
			sample["likely_render_parent_scope"] = parent_scope
	if str(sample.get("likely_driver", "")) == "render" and not likely_render_subsystem.is_empty():
		sample["likely_render_subsystem"] = likely_render_subsystem
		sample["likely_render_subsystem_reason"] = "highest avg/max render attribution in sample window"
	return sample


func _capture_world_stats_deep() -> Dictionary:
	var stats: Dictionary = {}
	if not is_instance_valid(world):
		return stats
	stats["world_generation_debug"] = Dictionary(world.get_world_generation_debug()) if world.has_method("get_world_generation_debug") else {}
	stats["resource_activation_debug"] = Dictionary(world.get_resource_activation_debug()) if world.has_method("get_resource_activation_debug") else {}
	stats["landmark_debug"] = _capture_world_landmark_debug_stats()
	stats["registry"] = _capture_world_registry_stats()
	stats["terrain_renderer"] = _capture_world_terrain_renderer_stats()
	stats["resource_spawn_rejection_debug"] = _capture_world_resource_spawn_rejection_debug()
	stats["ecosystem_state_source"] = _capture_world_ecosystem_state_source()
	return stats


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


func _capture_world_stats(include_deep_details: bool = false) -> Dictionary:
	var stats: Dictionary = {}
	if not is_instance_valid(world):
		return stats
	stats["current_biome"] = _get_current_biome_name()
	stats["world_rect"] = str(world.get_world_rect()) if world.has_method("get_world_rect") else str(WORLD_CONFIG.WORLD_RECT)
	stats["creatures_out_of_bounds_count"] = int(world.get_creatures_out_of_bounds_count()) if world.has_method("get_creatures_out_of_bounds_count") else 0
	stats["biome_count"] = world.get_biome_zones().size() if world.has_method("get_biome_zones") else 0
	stats["landmark_count"] = int(world.get_landmark_counts().get("generated", 0)) if world.has_method("get_landmark_counts") else 0
	stats["boot"] = _capture_world_boot_stats()
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
	stats["total_creatures"] = _sum_group_counts(stats["creature_counts"])
	stats["total_resources"] = _sum_group_counts(stats["resource_counts"])
	stats["render_pressure"] = _capture_world_render_pressure(stats)
	var world_debug := Dictionary(world.get_world_generation_debug()) if world.has_method("get_world_generation_debug") else {}
	stats["world_generation_total_ms"] = float(world_debug.get("world_generation_total_ms", 0.0))
	stats["world_ready_ms"] = float(world_debug.get("world_ready_ms", 0.0))
	stats["terrain_surface_initial_queue_size"] = int(world_debug.get("terrain_surface_initial_queue_size", 0))
	if include_deep_details:
		stats["pond_count"] = _count_landmarks_by_type(world.get_landmarks(), "pond") if world.has_method("get_landmarks") else 0
		stats["hill_count"] = _count_landmarks_by_type(world.get_landmarks(), "hill") if world.has_method("get_landmarks") else 0
		stats["biome_texture_cache"] = _capture_world_biome_texture_cache_stats()
		stats["small_prey_spawn_sync"] = _capture_world_small_prey_spawn_sync_stats()
		stats["varnak_spawn_sync"] = _capture_world_varnak_spawn_sync_stats()
		stats["creature_spawn_rejection_debug"] = _capture_world_creature_spawn_rejection_debug()
		stats["spatial_index"] = _capture_world_spatial_index_stats()
		stats["landmark_debug"] = _capture_world_landmark_debug_stats()
		stats["registry"] = _capture_world_registry_stats()
		stats["render_flags"] = _capture_world_render_flags()
		stats["render_budget"] = _capture_world_render_budget()
		stats["terrain_renderer"] = _capture_world_terrain_renderer_stats()
		stats["visibility_culling"] = _capture_world_visibility_culling_stats()
		stats["resource_render_mode"] = _capture_world_resource_render_mode_stats()
		stats["creature_simulation"] = _capture_creature_simulation_stats()
		stats["biome_query"] = _capture_world_biome_query_stats()
	return stats


func _capture_minimap_stats() -> Dictionary:
	if not is_instance_valid(minimap) or not minimap.has_method("get_minimap_performance_debug"):
		return {}
	return Dictionary(minimap.call("get_minimap_performance_debug"))


func _capture_map_screen_stats() -> Dictionary:
	if not is_instance_valid(map_screen) or not map_screen.has_method("get_map_screen_performance_debug"):
		return {}
	var stats := Dictionary(map_screen.call("get_map_screen_performance_debug"))
	stats["map_screen_first_open_ms"] = float(stats.get("map_screen_first_open_ms", 0.0))
	stats["map_screen_surface_build_mode"] = str(stats.get("map_screen_surface_build_mode", "unknown"))
	stats["map_screen_surface_build_async"] = bool(stats.get("map_screen_surface_build_async", false))
	stats["map_screen_texture_reused_from_minimap_world"] = bool(stats.get("map_screen_texture_reused_from_minimap_world", false))
	stats["map_screen_open_hitch_count"] = int(stats.get("map_screen_open_hitch_count", 0))
	return stats


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


func _capture_world_spatial_index_stats() -> Dictionary:
	if not is_instance_valid(world) or not world.has_method("get_spatial_index_debug_data"):
		return {}
	var data := Dictionary(world.get_spatial_index_debug_data())
	return {
		"resource_cells": int(data.get("resource_cells", 0)),
		"creature_cells": int(data.get("creature_cells", 0)),
		"meat_cells": int(data.get("meat_cells", 0)),
		"tracked_entities": int(data.get("tracked_entities", 0)),
		"resources_total": int(data.get("resources_total", 0)),
		"creatures_total": int(data.get("creatures_total", 0)),
		"meat_total": int(data.get("meat_total", 0)),
		"stale_entries_removed_last_cleanup": int(data.get("stale_entries_removed_last_cleanup", 0)),
		"average_entities_per_cell": float(data.get("average_entities_per_cell", 0.0)),
		"max_entities_in_cell": int(data.get("max_entities_in_cell", 0)),
		"last_refresh_ms": float(data.get("last_refresh_ms", 0.0)),
		"refresh_interval_seconds": float(data.get("refresh_interval_seconds", 0.0))
	}


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
	var topography_counts := Dictionary(world.get_topography_feature_counts()) if world.has_method("get_topography_feature_counts") else {}
	return {
		"generated": int(landmark_counts.get("generated", 0)),
		"pond": int(landmark_counts.get("pond", 0)),
		"hill": int(landmark_counts.get("hill", 0)),
		"topography_pond": int(topography_counts.get("pond", 0)),
		"topography_hill": int(topography_counts.get("highland", 0)),
		"topography_rocky_patch": int(topography_counts.get("rocky_patch", 0))
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


func _capture_world_ecosystem_state_source() -> String:
	if not is_instance_valid(world) or not world.has_method("get_ecosystem_state_source"):
		return ""
	return str(world.get_ecosystem_state_source())


func _capture_world_resource_spawn_rejection_debug() -> Dictionary:
	if not is_instance_valid(world) or not world.has_method("get_resource_spawn_rejection_debug"):
		return {}
	return Dictionary(world.get_resource_spawn_rejection_debug())


func _capture_world_render_flags() -> Dictionary:
	if not is_instance_valid(world):
		return {}
	return {
		"low_end_rendering": world.is_low_end_rendering_enabled() if world.has_method("is_low_end_rendering_enabled") else false,
		"biome_textures_enabled": world.are_biome_textures_enabled() if world.has_method("are_biome_textures_enabled") else true,
		"landmark_debug_overlay_enabled": world.is_landmark_debug_overlay_enabled() if world.has_method("is_landmark_debug_overlay_enabled") else false,
		"biome_terrain_accents_enabled": world.are_biome_terrain_accents_enabled() if world.has_method("are_biome_terrain_accents_enabled") else false
	}


func _capture_world_render_budget() -> Dictionary:
	if not is_instance_valid(world):
		return {}
	if world.has_method("get_render_budget_debug"):
		return Dictionary(world.get_render_budget_debug())
	return {}


func _capture_world_terrain_renderer_stats() -> Dictionary:
	if not is_instance_valid(world):
		return {}
	if world.has_method("get_terrain_renderer_debug"):
		return Dictionary(world.get_terrain_renderer_debug())
	return {}


func _capture_world_render_pressure(world_stats: Dictionary) -> Dictionary:
	var result := {}
	var vegetation := Dictionary(world_stats.get("vegetation", {}))
	var visibility := Dictionary(world_stats.get("visibility_culling", {}))
	var terrain := Dictionary(world_stats.get("terrain_renderer", {}))
	var minimap := Dictionary(_capture_minimap_stats())
	result["draw_calls"] = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	result["render_primitives"] = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	result["render_objects"] = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	result["visible_resources"] = int(visibility.get("visible_resources", 0))
	result["visible_creatures"] = int(visibility.get("visible_creatures", 0))
	result["decorative_drawn"] = int(vegetation.get("decorative_vegetation_drawn_instance_count", 0))
	result["decorative_visible_chunks"] = int(vegetation.get("decorative_vegetation_visible_chunk_count", 0))
	result["terrain_surface_visible_chunks"] = int(terrain.get("terrain_surface_chunk_visible_count", 0))
	result["terrain_surface_cached_chunks"] = int(terrain.get("terrain_surface_chunk_cached_count", 0))
	result["terrain_surface_pending_chunks"] = int(terrain.get("terrain_surface_chunk_pending_count", 0))
	result["terrain_surface_chunks_built_last_frame"] = int(terrain.get("terrain_surface_chunks_built_last_frame", 0))
	# World surface texture metrics (separate category)
	result["world_surface_texture_chunks_built"] = int(terrain.get("terrain_surface_chunks_built_last_frame", 0))
	result["world_surface_texture_max_build_ms_per_frame"] = float(terrain.get("terrain_surface_max_build_ms_per_frame", 0))
	result["world_surface_texture_pending_chunks"] = int(terrain.get("terrain_surface_chunk_pending_count", 0))
	result["world_surface_texture_total_build_count"] = int(terrain.get("terrain_surface_chunk_total_build_count", 0))
	result["world_surface_texture_active_builds"] = int(terrain.get("terrain_surface_active_build_count", 0))
	result["world_surface_texture_preview_enabled"] = bool(terrain.get("terrain_surface_preview_enabled", true))
	result["world_surface_texture_refined_chunks"] = int(terrain.get("terrain_surface_refined_chunks_built_last_frame", 0))
	result["world_surface_texture_hard_budget_exceeded"] = int(terrain.get("terrain_surface_build_hard_budget_exceeded_count", 0))
	result["terrain_cell_visible_chunks"] = int(terrain.get("terrain_chunk_count_visible", 0))
	result["terrain_cell_drawn_cells"] = int(terrain.get("terrain_chunk_drawn_cell_count", 0))
	result["biome_shape_drawn_polygons"] = int(terrain.get("biome_shape_renderer_drawn_polygon_count", 0))
	result["biome_shape_drawn_details"] = int(terrain.get("biome_shape_renderer_drawn_detail_count", 0))
	result["camera_zoom"] = _capture_camera_zoom()
	result["viewport_size"] = _capture_viewport_size()
	result["minimap_redraw_count"] = int(minimap.get("redraw_count", 0))
	result["minimap_static_redraw_count"] = int(minimap.get("static_redraw_count", 0))
	result["minimap_dynamic_redraw_count"] = int(minimap.get("dynamic_redraw_count", 0))
	result["minimap_static_cache_rebuild_count"] = int(minimap.get("static_cache_rebuild_count", 0))
	result["minimap_player_marker_redraw_count"] = int(minimap.get("player_marker_redraw_count", 0))
	result["shoreline_build_count"] = int(minimap.get("shoreline_build_count", 0))
	return result


func _capture_camera_zoom() -> Dictionary:
	var camera: Camera2D = get_viewport().get_camera_2d() if get_viewport() != null else null
	if camera == null and is_instance_valid(player):
		camera = player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return {"x": 0.0, "y": 0.0}
	return {"x": camera.zoom.x, "y": camera.zoom.y}


func _capture_viewport_size() -> Dictionary:
	var viewport := get_viewport()
	var viewport_size := viewport.get_visible_rect().size if viewport != null else Vector2.ZERO
	return {"x": viewport_size.x, "y": viewport_size.y}


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
	var resource_activation_debug := {}
	if world.has_method("get_resource_activation_debug"):
		resource_activation_debug = Dictionary(world.call("get_resource_activation_debug"))
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
		"active_resource_collisions": active_resource_collisions,
		"resource_activation_debug": resource_activation_debug
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
	var report_start_ms := Time.get_ticks_msec()
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
		"benchmark_preset": active_preset_name,
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
		"samples": samples,
		"render_attribution_summary": _build_render_attribution_summary()
	}
	benchmark_report_build_ms = float(Time.get_ticks_msec() - report_start_ms)
	report["benchmark_report_build_ms"] = benchmark_report_build_ms
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


func _build_render_attribution_summary() -> Dictionary:
	var summary: Dictionary = Dictionary(RUNTIME_PROFILER.get_rolling_summary())
	var top_subsystem := _pick_likely_render_subsystem(summary)
	return {
		"enabled": bool(summary.get("enabled", false)),
		"top_subsystem": top_subsystem,
		"top_subsystem_avg_ms": float(Dictionary(summary.get("subsystems", {})).get(top_subsystem, {}).get("avg", 0.0)) if not top_subsystem.is_empty() else 0.0,
		"top_subsystem_max_ms": float(Dictionary(summary.get("subsystems", {})).get(top_subsystem, {}).get("max", 0.0)) if not top_subsystem.is_empty() else 0.0,
		"samples_with_render_attribution": int(summary.get("samples_with_render_attribution", 0)),
		"subsystems": summary.get("subsystems", {})
	}


func _pick_likely_render_subsystem(render_attribution: Dictionary) -> String:
	var subsystems: Dictionary = Dictionary(render_attribution.get("subsystems", {}))
	if subsystems.is_empty():
		return ""
	var excluded := {
		"world_process_render_sync_ms": true,
		"minimap_total_ms": true,
		"map_screen_draw_ms": true,
		"hud_process_ms": true,
		"debug_panel_process_ms": true
	}
	var best_name := ""
	var best_avg := -1.0
	var best_max := -1.0
	for key_value in subsystems.keys():
		var name := str(key_value)
		if excluded.has(name):
			continue
		var stats: Dictionary = Dictionary(subsystems.get(name, {}))
		var avg := float(stats.get("avg", 0.0))
		var max_ms := float(stats.get("max", 0.0))
		if avg > best_avg or (is_equal_approx(avg, best_avg) and max_ms > best_max):
			best_avg = avg
			best_max = max_ms
			best_name = name
	return best_name if not best_name.is_empty() else str(render_attribution.get("top_subsystem", ""))


func _pick_likely_render_parent_scope(render_attribution: Dictionary, likely_render_subsystem: String) -> String:
	if likely_render_subsystem.is_empty():
		return ""
	var parent_candidates := [
		"world_process_render_sync_ms",
		"map_screen_draw_ms",
		"minimap_static_layer_draw_ms",
		"minimap_dynamic_layer_draw_ms"
	]
	var subsystems: Dictionary = Dictionary(render_attribution.get("subsystems", {}))
	for candidate in parent_candidates:
		if subsystems.has(candidate):
			return candidate
	return ""


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
		"world_surface_texture_chunks_built": 0,
		"world_surface_texture_max_build_ms_per_frame": 0.0,
		"world_surface_texture_pending_chunks": 0,
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
			"world_surface_texture_chunks_built",
			"world_surface_texture_max_build_ms_per_frame",
			"world_surface_texture_pending_chunks",
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
		# World surface texture metrics
		if performance.has("world_surface_texture_chunks_built"):
			metrics["world_surface_texture_chunks_built"] = maxi(int(metrics["world_surface_texture_chunks_built"]), int(performance.get("world_surface_texture_chunks_built", 0)))
		else:
			missing_metric_set["world_surface_texture_chunks_built"] = true
		if performance.has("world_surface_texture_max_build_ms_per_frame"):
			metrics["world_surface_texture_max_build_ms_per_frame"] = max(float(metrics["world_surface_texture_max_build_ms_per_frame"]), float(performance.get("world_surface_texture_max_build_ms_per_frame", 0.0)))
		else:
			missing_metric_set["world_surface_texture_max_build_ms_per_frame"] = true
		if performance.has("world_surface_texture_pending_chunks"):
			metrics["world_surface_texture_pending_chunks"] = maxi(int(metrics["world_surface_texture_pending_chunks"]), int(performance.get("world_surface_texture_pending_chunks", 0)))
		else:
			missing_metric_set["world_surface_texture_pending_chunks"] = true
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
	# World surface texture thresholds
	_check_threshold_max(metrics, thresholds, violations, warnings, "world_surface_texture_chunks_built", "world_surface_texture_chunks_built_max", "<=", "world_surface_texture_chunks_built %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, "world_surface_texture_max_build_ms_per_frame", "world_surface_texture_max_build_ms_per_frame_max", "<=", "world_surface_texture_max_build_ms_per_frame %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, "world_surface_texture_pending_chunks", "world_surface_texture_pending_chunks_max", "<=", "world_surface_texture_pending_chunks %s exceeds maximum %s")
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
	var terrain_stats: Dictionary = Dictionary(world_stats.get("terrain_renderer", {}))
	if not terrain_stats.is_empty():
		diagnostics.append("terrain surface_visible=%d surface_cached=%d surface_pending=%d surface_built=%d cell_visible=%d cell_drawn=%d shape_polygons=%d shape_details=%d" % [
			int(terrain_stats.get("terrain_surface_chunk_visible_count", 0)),
			int(terrain_stats.get("terrain_surface_chunk_cached_count", 0)),
			int(terrain_stats.get("terrain_surface_chunk_pending_count", 0)),
			int(terrain_stats.get("terrain_surface_chunks_built_last_frame", 0)),
			int(terrain_stats.get("terrain_chunk_count_visible", 0)),
			int(terrain_stats.get("terrain_chunk_drawn_cell_count", 0)),
			int(terrain_stats.get("biome_shape_renderer_drawn_polygon_count", 0)),
			int(terrain_stats.get("biome_shape_renderer_drawn_detail_count", 0))
		])
	var render_attribution: Dictionary = Dictionary(sample.get("render_attribution", {}))
	var render_subsystem := str(sample.get("likely_render_subsystem", ""))
	if not render_attribution.is_empty():
		var top_subsystem := str(render_attribution.get("top_subsystem", ""))
		var top_avg := float(render_attribution.get("top_subsystem_avg_ms", 0.0))
		var top_max := float(render_attribution.get("top_subsystem_max_ms", 0.0))
		diagnostics.append("render_attribution top=%s avg=%.2f max=%.2f sample_ms=%.2f" % [
			top_subsystem,
			top_avg,
			top_max,
			float(render_attribution.get("benchmark_sample_collection_ms", 0.0))
		])
		if not render_subsystem.is_empty():
			diagnostics.append("render_likely subsystem=%s reason=%s" % [
				render_subsystem,
				str(sample.get("likely_render_subsystem_reason", ""))
			])
	if not minimap_stats.is_empty():
		diagnostics.append("minimap redraw=%d static=%d dynamic=%d player=%d static_cache=%d marker_cache=%d landmark_cache=%d texture_builds=%d last_build_ms=%.2f checks=%d/%d shoreline=%d/%d queue=%d/%d/%d dirty=%s/%s/%s/%s/%s" % [
			int(minimap_stats.get("redraw_count", 0)),
			int(minimap_stats.get("static_redraw_count", 0)),
			int(minimap_stats.get("dynamic_redraw_count", 0)),
			int(minimap_stats.get("player_marker_redraw_count", 0)),
			int(minimap_stats.get("static_cache_rebuild_count", 0)),
			int(minimap_stats.get("marker_cache_rebuild_count", 0)),
			int(minimap_stats.get("landmark_cache_rebuild_count", 0)),
			int(minimap_stats.get("texture_build_count", 0)),
			float(minimap_stats.get("texture_last_build_ms", 0.0)),
			int(minimap_stats.get("minimap_marker_cache_check_count", 0)),
			int(minimap_stats.get("minimap_marker_cache_skipped_unchanged_count", 0)),
			int(minimap_stats.get("minimap_shoreline_check_count", 0)),
			int(minimap_stats.get("minimap_shoreline_skipped_unchanged_count", 0)),
			int(minimap_stats.get("minimap_queue_static_redraw_count", 0)),
			int(minimap_stats.get("minimap_queue_marker_redraw_count", 0)),
			int(minimap_stats.get("minimap_queue_player_redraw_count", 0)),
			str(minimap_stats.get("minimap_static_map_dirty", false)),
			str(minimap_stats.get("minimap_marker_cache_dirty", false)),
			str(minimap_stats.get("minimap_shoreline_cache_dirty", false)),
			str(minimap_stats.get("minimap_player_layer_dirty", false)),
			str(minimap_stats.get("minimap_view_dirty", false))
		])
	if not map_screen_stats.is_empty():
		diagnostics.append("map_screen redraw=%d cache=%d skipped_hidden=%d texture_builds=%d last_build_ms=%.2f open_ms=%.2f mode=%s async=%s reused=%s checks=%d/%d shoreline=%d/%d" % [
			int(map_screen_stats.get("redraw_count", 0)),
			int(map_screen_stats.get("cache_rebuild_count", 0)),
			int(map_screen_stats.get("skipped_update_hidden_count", 0)),
			int(map_screen_stats.get("texture_build_count", 0)),
			float(map_screen_stats.get("texture_last_build_ms", 0.0)),
			float(map_screen_stats.get("map_screen_first_open_ms", 0.0)),
			str(map_screen_stats.get("map_screen_surface_build_mode", "unknown")),
			"true" if bool(map_screen_stats.get("map_screen_surface_build_async", false)) else "false",
			"true" if bool(map_screen_stats.get("map_screen_texture_reused_from_minimap_world", false)) else "false",
			int(map_screen_stats.get("map_screen_marker_cache_check_count", 0)),
			int(map_screen_stats.get("map_screen_marker_cache_skipped_unchanged_count", 0)),
			int(map_screen_stats.get("map_screen_shoreline_check_count", 0)),
			int(map_screen_stats.get("map_screen_shoreline_skipped_unchanged_count", 0))
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
