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
var last_wall_frame_delta_ms := 0
var last_engine_delta_ms := 0.0
var max_wall_frame_delta_ms := 0
var max_performance_process_ms := 0.0
var hitch_breakdown: Array = []
var hitch_breakdown_summary: Dictionary = {}
var active_preset_name := "normal"
var hitch_count_by_scope: Dictionary = {}
var max_delta_by_scope: Dictionary = {}
var last_hitch_delta_by_scope: Dictionary = {}

# HITCH LOGGER COUNTERS
var benchmark_sample_build_ms: float = 0.0
var benchmark_sample_collection_ms: float = 0.0
var benchmark_world_debug_collection_ms: float = 0.0
var benchmark_hitch_capture_ms: float = 0.0
var benchmark_hitch_log_print_ms: float = 0.0
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
var benchmark_active := false
var verbose_hitch_logging := false
var last_hitch_summary_ms := 0
var benchmark_duration_seconds := BENCHMARK_DURATION_SECONDS
var benchmark_world_ready_elapsed_seconds := -1.0
@export var disable_minimap_for_benchmark := false
@export var disable_terrain_surface_refine_for_benchmark := false
var _original_minimap_visible := true
var _original_minimap_process_mode := Node.PROCESS_MODE_INHERIT
var _benchmark_isolation_applied := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED


func start(preset_name: String = "normal") -> bool:
	if running:
		return false
	active_preset_name = preset_name
	benchmark_active = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _capture_context():
		_post_message("Benchmark could not start: missing game state")
		queue_free()
		return false
	_load_benchmark_isolation_flags_from_environment()
	_apply_biome_textures_preset(preset_name)
	if preset_name == "map_open":
		_open_map_screen_for_benchmark()
	_apply_benchmark_isolation_flags()
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
	last_wall_frame_delta_ms = 0
	last_engine_delta_ms = 0.0
	max_wall_frame_delta_ms = 0
	max_performance_process_ms = 0.0
	hitch_breakdown.clear()
	hitch_breakdown_summary = {}
	benchmark_sample_build_ms = 0.0
	benchmark_sample_collection_ms = 0.0
	benchmark_world_debug_collection_ms = 0.0
	benchmark_hitch_capture_ms = 0.0
	benchmark_hitch_log_print_ms = 0.0
	benchmark_report_build_ms = 0.0
	last_reported_second = -1
	benchmark_world_ready_elapsed_seconds = -1.0
	benchmark_progress.emit(0.0, benchmark_duration_seconds)
	return true


func _process(delta: float) -> void:
	if not running:
		return
	if bool(GAME_BALANCE.DEBUG_HITCH_VERBOSE_LOGGING):
		RUNTIME_PROFILER.begin_scope("benchmark_runner_process_ms")
	var now_ticks := Time.get_ticks_msec()
	var frame_snapshot := RUNTIME_PROFILER.consume_frame_snapshot()
	RUNTIME_PROFILER.record_frame_snapshot(frame_snapshot)
	_capture_realtime_hitch(now_ticks, delta, frame_snapshot)
	_log_hitch(delta, "BenchmarkRunner", {
		"running": running,
		"sample_timer": sample_timer,
		"samples": samples.size()
	})
	elapsed_seconds = float(Time.get_ticks_usec() - start_ticks_usec) / 1000000.0
	_update_world_ready_elapsed_seconds()
	sample_timer += delta
	if sample_timer >= SAMPLE_INTERVAL_SECONDS and running:
		sample_timer -= SAMPLE_INTERVAL_SECONDS
		_record_sample()
		elapsed_seconds = float(Time.get_ticks_usec() - start_ticks_usec) / 1000000.0
	_report_progress()
	if elapsed_seconds >= benchmark_duration_seconds:
		_finish()
	if bool(GAME_BALANCE.DEBUG_HITCH_VERBOSE_LOGGING):
		RUNTIME_PROFILER.end_scope("benchmark_runner_process_ms")


func _capture_realtime_hitch(now_ticks: int, delta: float, frame_snapshot: Dictionary) -> void:
	var hitch_start := Time.get_ticks_usec()
	last_engine_delta_ms = delta * 1000.0
	if last_process_ticks_msec > 0:
		last_wall_frame_delta_ms = now_ticks - last_process_ticks_msec
		max_wall_frame_delta_ms = maxi(max_wall_frame_delta_ms, last_wall_frame_delta_ms)
		if last_wall_frame_delta_ms >= int(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_THRESHOLD_MS):
			realtime_hitch_count += 1
			max_realtime_delta_ms = maxi(max_realtime_delta_ms, last_wall_frame_delta_ms)
			hitch_count_by_scope["BenchmarkRunner"] = int(hitch_count_by_scope.get("BenchmarkRunner", 0)) + 1
			max_delta_by_scope["BenchmarkRunner"] = maxi(int(max_delta_by_scope.get("BenchmarkRunner", 0)), last_wall_frame_delta_ms)
			last_hitch_delta_by_scope["BenchmarkRunner"] = last_wall_frame_delta_ms
			var frame_breakdown := frame_snapshot.duplicate(true)
			var top_scopes := RUNTIME_PROFILER.get_top_scopes_from_snapshot(frame_breakdown, 8)
			var likely_subsystem := RUNTIME_PROFILER.get_top_scope_from_snapshot(frame_breakdown)
			var performance_process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			var performance_physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			var profiler_snapshot_total_ms := RUNTIME_PROFILER.get_snapshot_total_ms(frame_breakdown)
			var profiler_max_scope := Dictionary(RUNTIME_PROFILER.get_snapshot_max_scope(frame_breakdown))
			var profiler_snapshot_max_scope := str(profiler_max_scope.get("name", ""))
			var profiler_snapshot_max_scope_ms := float(profiler_max_scope.get("ms", 0.0))
			var profiler_snapshot_suspect := RUNTIME_PROFILER.is_snapshot_suspect(frame_breakdown, float(last_wall_frame_delta_ms), performance_process_ms)
			var profiled_runtime_ms := maxf(performance_process_ms, profiler_snapshot_max_scope_ms)
			var frame_stall_unattributed_ms := maxf(float(last_wall_frame_delta_ms) - profiled_runtime_ms, 0.0)
			if profiler_snapshot_suspect:
				likely_subsystem = "frame_stall_unattributed:%.1fms profiler_snapshot_suspect top=%s %.1fms" % [
					frame_stall_unattributed_ms,
					profiler_snapshot_max_scope,
					profiler_snapshot_max_scope_ms
				]
			var hitch := {
				"elapsed_seconds": elapsed_seconds,
				"phase": _get_benchmark_phase(),
				"realtime_delta_ms": last_wall_frame_delta_ms,
				"wall_frame_delta_ms": last_wall_frame_delta_ms,
				"engine_delta_ms": last_engine_delta_ms,
				"performance_process_ms": performance_process_ms,
				"performance_physics_ms": performance_physics_ms,
				"profiler_snapshot_total_ms": profiler_snapshot_total_ms,
				"profiler_snapshot_max_scope": profiler_snapshot_max_scope,
				"profiler_snapshot_max_scope_ms": profiler_snapshot_max_scope_ms,
				"profiler_snapshot_suspect": profiler_snapshot_suspect,
				"frame_stall_unattributed_ms": frame_stall_unattributed_ms,
				"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				"render_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				"render_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				"texture_mem_used": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
				"video_mem_used": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
				"runtime_profiler_top_subsystem": str(Dictionary(RUNTIME_PROFILER.get_rolling_summary()).get("top_subsystem", "")),
				"world_summary": _capture_world_summary(),
				"frame_breakdown": frame_breakdown,
				"likely_subsystem": likely_subsystem,
				"top_scopes": top_scopes,
				"performance": _capture_performance_stats(),
				"sample_count": samples.size(),
				"sample_timer": sample_timer
			}
			if deep_debug:
				hitch["world_debug"] = _capture_lightweight_world_debug()
			realtime_hitches.append(hitch)
			hitch_breakdown.append(hitch)
			if hitch_breakdown.size() > int(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_MAX_STORED):
				hitch_breakdown.pop_front()
			if realtime_hitches.size() > (40 if deep_debug else 12):
				realtime_hitches.pop_front()
			_update_hitch_breakdown_summary(hitch, frame_breakdown, top_scopes)
			if bool(GAME_BALANCE.DEBUG_HITCH_VERBOSE_LOGGING) or verbose_hitch_logging:
				var log_start := Time.get_ticks_usec()
				print(_format_hitch_detail_text(hitch, top_scopes))
				benchmark_hitch_log_print_ms = float(Time.get_ticks_usec() - log_start) / 1000.0
			if verbose_hitch_logging:
				print_debug("[REALTIME_HITCH] %d ms engine_delta=%.1f sample_count=%d" % [
					last_wall_frame_delta_ms,
					last_engine_delta_ms,
					samples.size()
				])
			if last_hitch_summary_ms == 0 or now_ticks - last_hitch_summary_ms >= 15000:
				last_hitch_summary_ms = now_ticks
				print_debug("[REALTIME_HITCH_SUMMARY] count=%d max_delta=%d" % [realtime_hitch_count, max_realtime_delta_ms])
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


func _load_benchmark_isolation_flags_from_environment() -> void:
	var env_disable_minimap := OS.get_environment("APEX_BENCH_DISABLE_MINIMAP")
	var env_disable_terrain_refine := OS.get_environment("APEX_BENCH_DISABLE_TERRAIN_REFINE")
	if env_disable_minimap == "1" or env_disable_minimap.to_lower() == "true":
		disable_minimap_for_benchmark = true
	if env_disable_terrain_refine == "1" or env_disable_terrain_refine.to_lower() == "true":
		disable_terrain_surface_refine_for_benchmark = true


func _apply_benchmark_isolation_flags() -> void:
	if _benchmark_isolation_applied:
		return
	_benchmark_isolation_applied = true
	if disable_minimap_for_benchmark and is_instance_valid(minimap):
		_original_minimap_visible = minimap.visible
		_original_minimap_process_mode = minimap.process_mode
		if minimap.has_method("set_benchmark_disabled"):
			minimap.call("set_benchmark_disabled", true)
		else:
			minimap.visible = false
			minimap.process_mode = Node.PROCESS_MODE_DISABLED
		print("[BENCHMARK] Minimap disabled for benchmark isolation")
	if disable_terrain_surface_refine_for_benchmark and is_instance_valid(world):
		_disable_terrain_surface_refine_for_benchmark()


func _disable_terrain_surface_refine_for_benchmark() -> void:
	if world == null or not is_instance_valid(world):
		return
	if world.has_method("set_terrain_surface_refine_enabled"):
		world.call("set_terrain_surface_refine_enabled", false)
		print("[BENCHMARK] Terrain surface refine disabled through World API")
		return
	if world.has_method("set_surface_refine_enabled"):
		world.call("set_surface_refine_enabled", false)
		print("[BENCHMARK] Terrain surface refine disabled through surface API")
		return
	var render_controller: Variant = null
	if world.has_method("get_render_controller"):
		render_controller = world.call("get_render_controller")
	elif world.has_method("get_world_render_controller"):
		render_controller = world.call("get_world_render_controller")
	if render_controller != null and render_controller.has_method("set_terrain_surface_refine_enabled"):
		render_controller.call("set_terrain_surface_refine_enabled", false)
		print("[BENCHMARK] Terrain surface refine disabled through render controller")
		return
	print("[BENCHMARK] Requested terrain surface refine isolation, but no compatible API was found")


func _restore_benchmark_isolation_flags() -> void:
	if not _benchmark_isolation_applied:
		return
	if disable_minimap_for_benchmark and is_instance_valid(minimap):
		if minimap.has_method("set_benchmark_disabled"):
			minimap.call("set_benchmark_disabled", false)
		minimap.visible = _original_minimap_visible
		minimap.process_mode = _original_minimap_process_mode
	if disable_terrain_surface_refine_for_benchmark and is_instance_valid(world):
		if world.has_method("set_terrain_surface_refine_enabled"):
			world.call("set_terrain_surface_refine_enabled", true)
		elif world.has_method("set_surface_refine_enabled"):
			world.call("set_surface_refine_enabled", true)
		else:
			var render_controller: Variant = null
			if world.has_method("get_render_controller"):
				render_controller = world.call("get_render_controller")
			elif world.has_method("get_world_render_controller"):
				render_controller = world.call("get_world_render_controller")
			if render_controller != null and render_controller.has_method("set_terrain_surface_refine_enabled"):
				render_controller.call("set_terrain_surface_refine_enabled", true)
	_benchmark_isolation_applied = false


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
	sample["benchmark_hitch_log_print_ms"] = benchmark_hitch_log_print_ms
	samples.append(sample)


func _report_progress() -> void:
	if not running:
		return
	var current_second: int = int(floor(elapsed_seconds))
	if current_second == last_reported_second:
		return
	last_reported_second = current_second
	var remaining_seconds: float = maxf(benchmark_duration_seconds - elapsed_seconds, 0.0)
	benchmark_progress.emit(elapsed_seconds, remaining_seconds)


func _capture_sample() -> Dictionary:
	var sample_collection_start := Time.get_ticks_usec()
	var sample: Dictionary = {}
	sample["sample_index"] = samples.size() + 1
	sample["elapsed_seconds"] = elapsed_seconds
	sample["phase"] = _get_benchmark_phase()
	sample["time_label"] = _format_time(elapsed_seconds)
	sample["performance"] = _capture_performance_stats()
	var performance: Dictionary = Dictionary(sample.get("performance", {}))
	sample["timing"] = {
		"wall_frame_delta_ms": last_wall_frame_delta_ms,
		"engine_delta_ms": last_engine_delta_ms,
		"performance_process_ms": float(performance.get("frame_time_s", 0.0)) * 1000.0,
		"performance_physics_ms": float(performance.get("physics_time_s", 0.0)) * 1000.0
	}
	sample["world_summary"] = _capture_world_summary()
	sample["resource_spawn_failure"] = _capture_world_resource_spawn_failure_debug()
	if deep_debug:
		var world_debug_start := Time.get_ticks_usec()
		sample["world"] = _capture_world_stats(true)
		sample["world_deep_debug"] = _capture_world_stats_deep()
		sample["minimap"] = _capture_minimap_stats()
		sample["map_screen"] = _capture_map_screen_stats()
		sample["player"] = _capture_player_stats()
		sample["ecosystem"] = _capture_ecosystem_stats()
		sample["ai_decisions"] = _capture_ai_decision_stats()
		benchmark_world_debug_collection_ms = float(Time.get_ticks_usec() - world_debug_start) / 1000.0
	else:
		benchmark_world_debug_collection_ms = 0.0
	sample["driver_scores"] = _calculate_driver_scores(sample)
	sample["likely_driver"] = _pick_likely_driver(Dictionary(sample.get("driver_scores", {})))
	sample["load_score"] = _calculate_load_score(sample)
	benchmark_sample_collection_ms = float(Time.get_ticks_usec() - sample_collection_start) / 1000.0
	sample["render_attribution"] = _get_lightweight_render_attribution_summary()
	sample["graphics_preset"] = _get_active_graphics_preset()
	return sample


func _get_active_graphics_preset() -> String:
	if not is_inside_tree():
		return "normal"

	var tree := get_tree()
	if tree == null or tree.root == null:
		return "normal"

	var graphics_settings := tree.root.get_node_or_null("GraphicsSettings")
	if graphics_settings != null and graphics_settings.has_method("get_graphics_preset_name"):
		return str(graphics_settings.get_graphics_preset_name())

	return "normal"


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
		stats["resource_spawn"] = _capture_world_resource_spawn_summary()
		stats["creature_simulation"] = _capture_creature_simulation_stats()
		stats["biome_query"] = _capture_world_biome_query_stats()
	return stats


func _capture_world_summary() -> Dictionary:
	if not is_instance_valid(world):
		return {}
	var terrain := _capture_world_terrain_renderer_stats()
	var visibility := _capture_world_visibility_culling_stats()
	var activation := _capture_world_resource_render_mode_stats()
	var biome_cache := _capture_world_biome_texture_cache_stats()
	var minimap := _capture_minimap_stats()
	var vegetation := _capture_world_vegetation_stats()
	return {
		"world_surface_texture_build_count": int(terrain.get("world_surface_texture_build_count", terrain.get("terrain_surface_refined_build_count", 0))),
		"world_surface_texture_last_build_ms": float(terrain.get("world_surface_texture_last_build_ms", terrain.get("terrain_surface_last_build_ms", 0.0))),
		"surface_texture_build_running": bool(terrain.get("surface_texture_build_running", terrain.get("terrain_surface_build_running", false))),
		"visible_resources": int(visibility.get("visible_resources", 0)),
		"visible_creatures": int(visibility.get("visible_creatures", 0)),
		"visibility_cull_show_count": int(visibility.get("visibility_show_count", visibility.get("shown_this_frame", 0))),
		"visibility_cull_hide_count": int(visibility.get("visibility_hide_count", visibility.get("hidden_this_frame", 0))),
		"visibility_cull_ms": float(visibility.get("visibility_queue_ms", 0.0)),
		"visibility_pending_count": int(visibility.get("pending_show_count", 0)) + int(visibility.get("pending_hide_count", 0)),
		"visibility_processed_this_frame": int(visibility.get("visibility_processed_this_frame", 0)),
		"visibility_pending_dropped_invalid": int(visibility.get("visibility_pending_dropped_invalid", 0)),
		"visibility_queue_ms": float(visibility.get("visibility_queue_ms", 0.0)),
		"active_resource_collisions": int(activation.get("active_resource_collisions", 0)),
		"world_surface_texture_chunks_built": int(terrain.get("terrain_surface_chunks_built_last_frame", 0)),
		"world_surface_texture_max_build_ms_per_frame": float(terrain.get("terrain_surface_max_build_ms_per_frame", 0.0)),
		"world_surface_texture_pending_chunks": int(terrain.get("terrain_surface_chunk_pending_count", 0)),
		"world_biome_texture_build_count": int(biome_cache.get("world_biome_texture_build_count", 0)),
		"minimap_build_ms": float(minimap.get("texture_last_build_ms", 0.0)),
		"minimap_build_count": int(minimap.get("texture_build_count", 0)),
		"terrain_surface_refined_build_count": int(terrain.get("terrain_surface_refined_build_count", 0)),
		"terrain_surface_refine_jobs_started": int(terrain.get("terrain_surface_refine_jobs_started", 0)),
		"terrain_surface_refine_jobs_completed": int(terrain.get("terrain_surface_refine_jobs_completed", 0)),
		"terrain_surface_refine_pending_count": int(terrain.get("terrain_surface_refine_pending_count", 0)),
		"terrain_surface_active_refine_count": int(terrain.get("terrain_surface_active_refine_count", 0)),
		"terrain_surface_refine_blocked_reason": str(terrain.get("terrain_surface_refine_blocked_reason", "")),
		"biome_blend_texture_cache_hit": bool(biome_cache.get("biome_blend_texture_cache_hit", false)),
		"biome_blend_texture_rebuild_reason": str(biome_cache.get("biome_blend_texture_rebuild_reason", "")),
		"vegetation": vegetation
	}


func _update_world_ready_elapsed_seconds() -> void:
	if benchmark_world_ready_elapsed_seconds >= 0.0:
		return
	if not is_instance_valid(world):
		return
	var ready := false
	if world.has_method("get_boot_progress_state"):
		var state := Dictionary(world.get_boot_progress_state())
		ready = bool(state.get("boot_ready", false))
	elif world.has_method("is_boot_ready"):
		ready = bool(world.is_boot_ready())
	if ready:
		benchmark_world_ready_elapsed_seconds = elapsed_seconds


func _get_benchmark_phase() -> String:
	if benchmark_world_ready_elapsed_seconds < 0.0:
		return "pre_ready"
	var post_ready_elapsed := elapsed_seconds - benchmark_world_ready_elapsed_seconds
	if post_ready_elapsed < 10.0:
		return "boot_after_ready"
	return "stable_runtime"


func _get_lightweight_render_attribution_summary() -> Dictionary:
	var summary := Dictionary(RUNTIME_PROFILER.get_rolling_summary())
	return {
		"enabled": bool(summary.get("enabled", false)),
		"top_subsystem": _pick_likely_render_subsystem(summary),
		"samples_with_render_attribution": int(summary.get("samples_with_render_attribution", 0))
	}


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
		return {
			"world_biome_texture_build_count": 0,
			"world_biome_texture_last_build_ms": 0.0,
			"textures_enabled": false,
			"not_applicable": true
		}
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
		"biome_blend_texture_cache_hit": bool(cache_status.get("cache_hit", false)),
		"biome_blend_texture_rebuild_reason": str(cache_status.get("rebuild_reason", "")),
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


func _capture_world_resource_spawn_summary() -> Dictionary:
	if not is_instance_valid(world) or not world.has_method("_build_resource_spawn_debug_summary"):
		return {}
	return Dictionary(world.call("_build_resource_spawn_debug_summary"))


func _capture_world_resource_spawn_failure_debug() -> Dictionary:
	if not is_instance_valid(world) or not world.has_method("get_resource_spawn_debug"):
		return {}
	return Dictionary(world.call("get_resource_spawn_debug"))


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
		var stats := Dictionary(world.get_terrain_renderer_debug())
		stats["world_surface_texture_build_count"] = int(stats.get("world_surface_texture_build_count", stats.get("terrain_surface_refined_build_count", 0)))
		stats["world_surface_texture_last_build_ms"] = float(stats.get("world_surface_texture_last_build_ms", stats.get("terrain_surface_last_build_ms", 0.0)))
		stats["surface_texture_build_running"] = bool(stats.get("surface_texture_build_running", stats.get("terrain_surface_build_running", false)))
		return stats
	return {
		"terrain_surface_chunks_built_last_frame": 0,
		"terrain_surface_max_build_ms_per_frame": 0.0,
		"terrain_surface_chunk_pending_count": 0,
		"world_surface_texture_build_count": 0,
		"world_surface_texture_last_build_ms": 0.0,
		"surface_texture_build_running": false,
		"not_applicable": true
	}


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
		var is_render_only := false
		if resource.has_method("get"):
			is_render_only = resource.get("render_only") == true
		match resource_kind:
			"grass_patch":
				if not is_render_only:
					result["grass_patch_node_count"] = int(result["grass_patch_node_count"]) + 1
				result["decorative_grass_node_count"] = int(result["decorative_grass_node_count"]) + 1
			"dense_grass":
				if not is_render_only:
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
		result["vegetation_draw_ms"] = float(visual_debug.get("draw_ms", visual_debug.get("vegetation_draw_ms", 0.0)))
		result["vegetation_candidate_count"] = int(visual_debug.get("candidate_count_before_cap", visual_debug.get("vegetation_candidate_count", 0)))
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
	var timing: Dictionary = Dictionary(sample.get("timing", {}))
	var world_stats: Dictionary = Dictionary(sample.get("world", {}))
	var world_summary: Dictionary = Dictionary(sample.get("world_summary", {}))
	var ecosystem_stats: Dictionary = Dictionary(sample.get("ecosystem", {}))
	var frame_breakdown: Dictionary = Dictionary(sample.get("frame_breakdown", {}))
	var creature_counts: Dictionary = Dictionary(world_stats.get("creature_counts", {}))
	var resource_counts: Dictionary = Dictionary(world_stats.get("resource_counts", {}))
	var special_resource_counts: Dictionary = Dictionary(world_stats.get("special_resource_counts", {}))
	var total_creatures := float(world_stats.get("total_creatures", world_summary.get("visible_creatures", 0.0)))
	var total_resources := float(world_stats.get("total_resources", world_summary.get("visible_resources", 0.0)))
	var vegetation_stats: Dictionary = Dictionary(world_stats.get("vegetation", {}))
	var draw_calls := float(performance.get("draw_calls", 0))
	var render_primitives := float(performance.get("render_primitives", 0))
	var render_objects := float(performance.get("render_objects", 0))
	var frame_time_ms := float(performance.get("frame_time_s", 0.0)) * 1000.0
	var physics_time_ms := float(performance.get("physics_time_s", 0.0)) * 1000.0
	var wall_frame_ms := float(timing.get("wall_frame_delta_ms", frame_time_ms))
	var performance_process_ms := float(timing.get("performance_process_ms", frame_time_ms))
	var node_count := float(performance.get("node_count", 0))
	var physics_pairs := float(performance.get("physics_2d_collision_pairs", 0))
	var physics_active := float(performance.get("physics_2d_active", 0))
	var world_process_ms := float(frame_breakdown.get("world_process_total_ms", 0.0))
	var visibility_cull_ms := float(frame_breakdown.get("visibility_cull_ms", frame_breakdown.get("world_visibility_controller_ms", 0.0)))
	var resource_activation_ms := float(frame_breakdown.get("resource_activation_update_ms", 0.0))
	var spatial_index_ms := float(frame_breakdown.get("spatial_index_refresh_ms", 0.0))
	var spawn_sync_ms := float(frame_breakdown.get("small_prey_spawn_ms", 0.0)) + float(frame_breakdown.get("grazer_spawn_ms", 0.0)) + float(frame_breakdown.get("varnak_sync_ms", 0.0)) + float(frame_breakdown.get("world_sync_periodic_rock_spawn_ms", 0.0))
	var ai_sync_ms := float(frame_breakdown.get("small_prey_sync_ms", 0.0)) + float(frame_breakdown.get("varnak_sync_ms", 0.0))
	var creature_process_ms := float(frame_breakdown.get("small_prey_process_ms", 0.0)) + float(frame_breakdown.get("grazer_process_ms", 0.0)) + float(frame_breakdown.get("varnak_process_ms", 0.0))
	var creature_physics_ms := float(frame_breakdown.get("small_prey_physics_process_ms", 0.0)) + float(frame_breakdown.get("grazer_physics_process_ms", 0.0)) + float(frame_breakdown.get("varnak_physics_process_ms", 0.0))
	var creature_pressure := total_creatures * 1.2 + float(creature_counts.get("varnak", 0)) * 1.0 + creature_process_ms * 6.0 + creature_physics_ms * 5.0 + ai_sync_ms * 4.0
	var decorative_grass_nodes := float(vegetation_stats.get("decorative_grass_node_count", 0))
	var drawn_visual_grass_instances := float(vegetation_stats.get("decorative_vegetation_drawn_instance_count", 0))
	var resource_pressure := total_resources * 0.7 + float(resource_counts.get("pond_vegetation", 0)) * 0.6 + float(special_resource_counts.get("edible_vegetation", 0)) * 0.4
	resource_pressure += drawn_visual_grass_instances * 0.02
	resource_pressure += decorative_grass_nodes * 0.4
	var vegetation_draw_ms := float(frame_breakdown.get("vegetation_draw_total_ms", 0.0)) + float(frame_breakdown.get("vegetation_draw_loop_ms", 0.0))
	var terrain_draw_ms := float(frame_breakdown.get("terrain_surface_chunk_draw_ms", 0.0)) + float(frame_breakdown.get("terrain_surface_chunk_build_ms", 0.0))
	var biome_surface_ms := float(frame_breakdown.get("world_surface_texture_ms", 0.0)) + float(frame_breakdown.get("world_render_controller_ensure_biome_blend_texture_ms", 0.0))
	var texture_build_ms := float(frame_breakdown.get("minimap_total_cpu_ms", 0.0)) + float(frame_breakdown.get("map_screen_total_ms", 0.0)) + float(frame_breakdown.get("world_surface_texture_ms", 0.0))
	var render_pressure := draw_calls * 1.4 + render_primitives * 0.015 + render_objects * 0.55 + vegetation_draw_ms * 12.0 + terrain_draw_ms * 10.0 + biome_surface_ms * 10.0 + texture_build_ms * 8.0
	var physics_pressure := physics_time_ms * 8.0 + physics_pairs * 0.06 + physics_active * 0.08
	var scene_pressure := node_count * 0.02
	var world_pressure := world_process_ms * 6.0 + visibility_cull_ms * 10.0 + resource_activation_ms * 8.0 + spatial_index_ms * 8.0 + spawn_sync_ms * 6.0
	var ui_pressure := float(frame_breakdown.get("minimap_total_cpu_ms", 0.0)) * 12.0 + float(frame_breakdown.get("map_screen_total_ms", 0.0)) * 12.0
	var ecosystem_pressure := float(ecosystem_stats.get("biome_count", 0)) * 0.8 + float(ecosystem_stats.get("highest_food_stress", 0.0)) * 5.0
	var measured_total := world_pressure + render_pressure + ui_pressure + creature_pressure + physics_pressure + scene_pressure + ecosystem_pressure
	var unattributed_pressure := 0.0
	if wall_frame_ms >= 80.0 and measured_total < wall_frame_ms * 0.5:
		unattributed_pressure = wall_frame_ms * 8.0
	return {
		"render": render_pressure,
		"ai": creature_pressure,
		"world": world_pressure,
		"ui": ui_pressure,
		"physics": physics_pressure,
		"creatures": creature_pressure,
		"resources": resource_pressure,
		"scene": scene_pressure,
		"ecosystem": ecosystem_pressure,
		"unattributed": unattributed_pressure,
		"frame_stall": maxf(wall_frame_ms, performance_process_ms)
	}


func _pick_likely_driver(driver_scores: Dictionary) -> String:
	if float(driver_scores.get("unattributed", 0.0)) > 0.0:
		return "unattributed"
	if float(driver_scores.get("frame_stall", 0.0)) >= 250.0 and float(driver_scores.get("render", 0.0)) < 600.0 and float(driver_scores.get("physics", 0.0)) < 100.0:
		return "frame_stall_unattributed"
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
	var world_summary: Dictionary = Dictionary(sample.get("world_summary", {}))
	var ecosystem_stats: Dictionary = Dictionary(sample.get("ecosystem", {}))
	var draw_calls := float(performance.get("draw_calls", 0))
	var render_primitives := float(performance.get("render_primitives", 0))
	var frame_time_ms := float(performance.get("frame_time_s", 0.0)) * 1000.0
	var physics_time_ms := float(performance.get("physics_time_s", 0.0)) * 1000.0
	var node_count := float(performance.get("node_count", 0))
	var total_creatures := float(world_stats.get("total_creatures", world_summary.get("visible_creatures", 0)))
	var total_resources := float(world_stats.get("total_resources", world_summary.get("visible_resources", 0)))
	var vegetation_stats: Dictionary = Dictionary(world_stats.get("vegetation", {}))
	var out_of_bounds := float(world_stats.get("creatures_out_of_bounds_count", 0))
	var biome_count := float(ecosystem_stats.get("biome_count", 0))
	var food_stress := float(ecosystem_stats.get("highest_food_stress", 0.0))
	var decorative_grass_nodes := float(vegetation_stats.get("decorative_grass_node_count", 0))
	var drawn_visual_grass_instances := float(vegetation_stats.get("decorative_vegetation_drawn_instance_count", 0))
	return frame_time_ms + physics_time_ms * 0.8 + draw_calls * 0.08 + render_primitives * 0.001 + node_count * 0.01 + total_creatures * 0.06 + total_resources * 0.02 + decorative_grass_nodes * 0.05 + drawn_visual_grass_instances * 0.02 + out_of_bounds * 2.0 + biome_count * 0.4 + food_stress * 5.0


func _finish() -> void:
	running = false
	benchmark_active = false
	_restore_benchmark_isolation_flags()
	process_mode = Node.PROCESS_MODE_DISABLED
	benchmark_progress.emit(benchmark_duration_seconds, 0.0)
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
	var max_wall_frame_delta_ms_report := 0
	var max_performance_process_ms_report := 0.0
	var max_physics_time_ms := 0.0
	for sample_value in samples:
		var sample: Dictionary = Dictionary(sample_value)
		var performance: Dictionary = Dictionary(sample.get("performance", {}))
		var timing: Dictionary = Dictionary(sample.get("timing", {}))
		var fps := float(performance.get("fps", 0))
		var frame_time_ms := float(timing.get("performance_process_ms", float(performance.get("frame_time_s", 0.0)) * 1000.0))
		var physics_time_ms := float(timing.get("performance_physics_ms", float(performance.get("physics_time_s", 0.0)) * 1000.0))
		var wall_frame_delta_ms := int(timing.get("wall_frame_delta_ms", 0))
		total_fps += fps
		min_fps = min(min_fps, fps)
		max_fps = max(max_fps, fps)
		max_frame_time_ms = max(max_frame_time_ms, maxf(float(wall_frame_delta_ms), frame_time_ms))
		max_wall_frame_delta_ms_report = maxi(max_wall_frame_delta_ms_report, wall_frame_delta_ms)
		max_performance_process_ms_report = max(max_performance_process_ms_report, frame_time_ms)
		max_physics_time_ms = max(max_physics_time_ms, physics_time_ms)
	var report := {
		"benchmark_name": "apex_shift_60_second_debug_benchmark",
		"benchmark_preset": active_preset_name,
		"benchmark_isolation": {
			"disable_minimap_for_benchmark": disable_minimap_for_benchmark,
			"disable_terrain_surface_refine_for_benchmark": disable_terrain_surface_refine_for_benchmark
		},
		"benchmark_hitch_log_print_ms": benchmark_hitch_log_print_ms,
		"duration_target_seconds": benchmark_duration_seconds,
		"actual_duration_seconds": elapsed_seconds,
		"started_unix_time": int(start_unix_time),
		"sample_interval_seconds": SAMPLE_INTERVAL_SECONDS,
		"sample_count": total_samples,
		"average_fps": total_fps / float(total_samples) if total_samples > 0 else 0.0,
		"min_fps": min_fps if total_samples > 0 else 0.0,
		"max_fps": max_fps,
		"max_frame_time_ms": max_frame_time_ms,
		"max_wall_frame_delta_ms": maxi(max_wall_frame_delta_ms_report, max_wall_frame_delta_ms),
		"max_performance_process_ms": max_performance_process_ms_report,
		"max_physics_time_ms": max_physics_time_ms,
		"realtime_hitch_count": realtime_hitch_count,
		"max_realtime_delta_ms": max_realtime_delta_ms,
		"realtime_hitches": realtime_hitches,
		"hitch_breakdown": hitch_breakdown,
		"hitch_breakdown_summary": _build_hitch_breakdown_summary(),
		"runtime_profiler_summary": RUNTIME_PROFILER.get_rolling_summary(),
		"heaviest_sample": heaviest_sample,
		"top_samples": top_samples,
		"samples": samples,
		"render_attribution_summary": _build_render_attribution_summary(),
		"graphics_preset": _get_active_graphics_preset()
	}
	report["resource_spawn_failure_debug"] = _capture_latest_resource_spawn_failure_debug()
	report["resource_spawn_failure_breakdown"] = _build_resource_spawn_failure_breakdown(report)
	report["resource_spawn_failure_summary_text"] = _format_resource_spawn_failure_text(report)
	report["phase_metrics"] = _build_phase_metrics(report)
	report["top_hitch_sections"] = _build_top_hitch_sections(Array(report.get("hitch_breakdown", [])), "")
	report["active_benchmark_thresholds"] = _get_active_benchmark_thresholds(report)
	report["threshold_source_breakdown"] = _build_threshold_source_breakdown(report)
	benchmark_report_build_ms = float(Time.get_ticks_msec() - report_start_ms)
	report["benchmark_report_build_ms"] = benchmark_report_build_ms
	report["runtime_hitch_summary"] = {
		"count": realtime_hitch_count,
		"max_realtime_delta_ms": max_realtime_delta_ms,
		"hitch_count_by_scope": hitch_count_by_scope.duplicate(true),
		"max_delta_by_scope": max_delta_by_scope.duplicate(true),
		"last_hitch_delta_by_scope": last_hitch_delta_by_scope.duplicate(true)
	}
	report["threshold_validation"] = _validate_benchmark_thresholds(report)
	return report


func _build_phase_metrics(report: Dictionary) -> Dictionary:
	var result := {
		"pre_ready": _build_phase_metric_bucket(),
		"boot_after_ready": _build_phase_metric_bucket(),
		"stable_runtime": _build_phase_metric_bucket()
	}
	var phase_map := {
		"pre_ready": "pre_ready",
		"boot_after_ready": "boot_after_ready",
		"stable_runtime": "stable_runtime"
	}
	var samples_array := Array(report.get("samples", []))
	var hitches_array := Array(report.get("hitch_breakdown", []))
	for sample_value in samples_array:
		var sample := Dictionary(sample_value)
		var phase := str(sample.get("phase", "pre_ready"))
		if not phase_map.has(phase):
			continue
		var bucket: Dictionary = Dictionary(result[phase])
		_build_phase_metric_bucket_update(bucket, sample, false)
		result[phase] = bucket
	for hitch_value in hitches_array:
		var hitch := Dictionary(hitch_value)
		var phase := str(hitch.get("phase", "pre_ready"))
		if not phase_map.has(phase):
			continue
		var bucket: Dictionary = Dictionary(result[phase])
		_build_phase_metric_bucket_update(bucket, hitch, true)
		result[phase] = bucket
	for phase in result.keys():
		var bucket := Dictionary(result[phase])
		bucket["average_fps"] = float(bucket.get("total_fps", 0.0)) / float(bucket.get("sample_count", 1)) if int(bucket.get("sample_count", 0)) > 0 else 0.0
		if float(bucket.get("min_fps", 999999.0)) >= 999999.0:
			bucket["min_fps"] = 0.0
		bucket["top_5_hitch_sections"] = _build_top_hitch_sections(hitches_array, str(phase))
		result[phase] = bucket
	return result


func _build_phase_metric_bucket() -> Dictionary:
	return {
		"sample_count": 0,
		"total_fps": 0.0,
		"min_fps": 999999.0,
		"max_frame_time_ms": 0.0,
		"max_realtime_delta_ms": 0,
		"realtime_hitch_count": 0,
		"max_world_surface_texture_last_build_ms": 0.0,
		"max_visibility_cull_ms": 0.0,
		"max_vegetation_draw_ms": 0.0,
		"max_minimap_build_ms": 0.0
	}


func _build_phase_metric_bucket_update(bucket: Dictionary, entry: Dictionary, is_hitch: bool) -> void:
	if not is_hitch:
		var performance: Dictionary = Dictionary(entry.get("performance", {}))
		var world_summary: Dictionary = Dictionary(entry.get("world_summary", {}))
		bucket["sample_count"] = int(bucket.get("sample_count", 0)) + 1
		bucket["total_fps"] = float(bucket.get("total_fps", 0.0)) + float(performance.get("fps", 0))
		bucket["min_fps"] = min(float(bucket.get("min_fps", 999999.0)), float(performance.get("fps", 0)))
		var frame_time_ms := float(Dictionary(entry.get("timing", {})).get("performance_process_ms", 0.0))
		bucket["max_frame_time_ms"] = max(float(bucket.get("max_frame_time_ms", 0.0)), frame_time_ms)
		bucket["max_world_surface_texture_last_build_ms"] = max(float(bucket.get("max_world_surface_texture_last_build_ms", 0.0)), float(world_summary.get("world_surface_texture_last_build_ms", 0.0)))
		bucket["max_visibility_cull_ms"] = max(float(bucket.get("max_visibility_cull_ms", 0.0)), float(world_summary.get("visibility_cull_ms", 0.0)))
		var vegetation: Dictionary = Dictionary(world_summary.get("vegetation", {}))
		bucket["max_vegetation_draw_ms"] = max(float(bucket.get("max_vegetation_draw_ms", 0.0)), float(vegetation.get("vegetation_draw_ms", 0.0)))
		bucket["max_minimap_build_ms"] = max(float(bucket.get("max_minimap_build_ms", 0.0)), float(world_summary.get("minimap_build_ms", 0.0)))
	else:
		bucket["realtime_hitch_count"] = int(bucket.get("realtime_hitch_count", 0)) + 1
		bucket["max_realtime_delta_ms"] = maxi(int(bucket.get("max_realtime_delta_ms", 0)), int(entry.get("realtime_delta_ms", 0)))


func _build_top_hitch_sections(hitches: Array, phase: String = "") -> Array:
	var totals: Dictionary = {}
	for hitch_value in hitches:
		var hitch := Dictionary(hitch_value)
		var hitch_phase := str(hitch.get("phase", "boot"))
		if not phase.is_empty() and hitch_phase != phase:
			continue
		var breakdown: Dictionary = Dictionary(hitch.get("frame_breakdown", {}))
		for key in breakdown.keys():
			var section := str(key)
			totals[section] = float(totals.get(section, 0.0)) + float(breakdown.get(key, 0.0))
	var ranked: Array[Dictionary] = []
	for key in totals.keys():
		ranked.append({"section": str(key), "total_ms": float(totals.get(key, 0.0))})
	ranked.sort_custom(Callable(self, "_sort_hitch_section_descending"))
	if ranked.size() > 5:
		ranked.resize(5)
	return ranked


func _sort_hitch_section_descending(left: Dictionary, right: Dictionary) -> bool:
	return float(left.get("total_ms", 0.0)) > float(right.get("total_ms", 0.0))


func _update_hitch_breakdown_summary(hitch: Dictionary, frame_breakdown: Dictionary, top_scopes: Array[Dictionary]) -> void:
	var scope_totals: Dictionary = Dictionary(hitch_breakdown_summary.get("scope_totals", {}))
	var scope_max: Dictionary = Dictionary(hitch_breakdown_summary.get("scope_max", {}))
	var top_name := str(hitch.get("likely_subsystem", ""))
	var hitch_ms := int(hitch.get("realtime_delta_ms", 0))
	var measured_total := RuntimeProfiler.get_snapshot_total_ms(frame_breakdown)
	var unattributed_count := int(hitch_breakdown_summary.get("unattributed_hitch_count", 0))
	if top_name.is_empty() or measured_total < float(hitch_ms) * 0.5:
		unattributed_count += 1
	for scope_value in top_scopes:
		var scope := Dictionary(scope_value)
		var name := str(scope.get("name", ""))
		var ms := float(scope.get("ms", 0.0))
		if name.is_empty():
			continue
		scope_totals[name] = float(scope_totals.get(name, 0.0)) + ms
		scope_max[name] = maxf(float(scope_max.get(name, 0.0)), ms)
	hitch_breakdown_summary = {
		"count": int(hitch_breakdown_summary.get("count", 0)) + 1,
		"threshold_ms": int(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_THRESHOLD_MS),
		"top_scope_by_total_ms": _pick_scope_by_total_ms(scope_totals),
		"top_scope_by_max_ms": _pick_scope_by_max_ms(scope_max),
		"max_hitch_ms": maxi(int(hitch_breakdown_summary.get("max_hitch_ms", 0)), hitch_ms),
		"unattributed_hitch_count": unattributed_count,
		"scope_totals": scope_totals,
		"scope_max": scope_max
	}


func _build_hitch_breakdown_summary() -> Dictionary:
	var summary := hitch_breakdown_summary.duplicate(true)
	summary.erase("scope_totals")
	summary.erase("scope_max")
	return summary


func _pick_scope_by_total_ms(scope_totals: Dictionary) -> String:
	var best_name := "unattributed"
	var best_ms := -1.0
	for key_value in scope_totals.keys():
		var name := str(key_value)
		var ms := float(scope_totals.get(key_value, 0.0))
		if ms > best_ms:
			best_ms = ms
			best_name = name
	return best_name


func _pick_scope_by_max_ms(scope_max: Dictionary) -> String:
	var best_name := "unattributed"
	var best_ms := -1.0
	for key_value in scope_max.keys():
		var name := str(key_value)
		var ms := float(scope_max.get(key_value, 0.0))
		if ms > best_ms:
			best_ms = ms
			best_name = name
	return best_name


func _format_hitch_detail_text(hitch: Dictionary, top_scopes: Array[Dictionary]) -> String:
	var top_text := "none"
	if not top_scopes.is_empty():
		var top := Dictionary(top_scopes[0])
		top_text = "%s:%.1fms" % [str(top.get("name", "")), float(top.get("ms", 0.0))]
	var frame_breakdown: Dictionary = Dictionary(hitch.get("frame_breakdown", {}))
	var world_summary: Dictionary = Dictionary(hitch.get("world_summary", {}))
	var performance: Dictionary = Dictionary(hitch.get("performance", {}))
	var world_debug: Dictionary = Dictionary(hitch.get("world_debug", {}))
	var visibility_ms := float(frame_breakdown.get("visibility_cull_ms", frame_breakdown.get("world_visibility_controller_ms", 0.0)))
	var vegetation_draw_ms := float(frame_breakdown.get("vegetation_draw_total_ms", 0.0))
	var vegetation_sort_ms := float(frame_breakdown.get("vegetation_sort_candidates_ms", 0.0))
	var vegetation_collect_ms := float(frame_breakdown.get("vegetation_collect_candidates_ms", 0.0))
	var surface_texture_ms := float(frame_breakdown.get("world_surface_texture_ms", 0.0))
	var biome_blend_ms := float(frame_breakdown.get("world_render_controller_ensure_biome_blend_texture_ms", 0.0))
	var world_process_ms := float(frame_breakdown.get("world_process_total_ms", 0.0))
	var ai_sync_ms := float(frame_breakdown.get("world_sync_visible_small_prey_ms", 0.0)) + float(frame_breakdown.get("world_sync_visible_grazers_ms", 0.0)) + float(frame_breakdown.get("world_sync_visible_varnaks_ms", 0.0))
	var terrain_surface_ms := float(frame_breakdown.get("terrain_surface_process_visibility_ms", 0.0)) + float(frame_breakdown.get("terrain_surface_rebuild_visible_chunks_ms", 0.0)) + float(frame_breakdown.get("terrain_surface_build_chunks_ms", 0.0))
	var minimap_ms := float(frame_breakdown.get("minimap_total_cpu_ms", 0.0))
	var minimap_process_ms := float(frame_breakdown.get("minimap_process_ms", 0.0))
	var minimap_draw_ms := float(frame_breakdown.get("minimap_draw_ms", 0.0))
	var minimap_static_texture_ms := float(frame_breakdown.get("minimap_static_layer_draw_ms", 0.0)) + float(frame_breakdown.get("minimap_static_texture_build_ms", 0.0))
	var minimap_dynamic_markers_ms := float(frame_breakdown.get("minimap_dynamic_layer_draw_ms", 0.0)) + float(frame_breakdown.get("minimap_resources_draw_ms", 0.0)) + float(frame_breakdown.get("minimap_player_draw_ms", 0.0))
	var map_screen_ms := float(frame_breakdown.get("map_screen_total_ms", 0.0))
	var vegetation_candidates := int(Dictionary(world_debug.get("vegetation", {})).get("candidate_count_before_cap", 0))
	var vegetation_drawn := int(Dictionary(world_debug.get("vegetation", {})).get("drawn_instance_count", 0))
	return "[HITCH_DETAIL] frame=%dms engine_delta=%.1fms top=%s world_process=%.0fms visibility_cull=%.0fms show=%d hide=%d pending=%d dropped_invalid=%d decorative_visible_rect=%.0fms candidates=%d drawn=%d sort=%.1fms draw_loop=%.1fms surface_texture=%.0fms build_running=%s build_count=%d biome_blend=%.0fms cache_hit=%s ai_sync=%.1fms terrain_surface=%.0fms chunks_built=%d pending=%d minimap_total_cpu=%.0fms minimap_process=%.0fms minimap_draw=%.0fms minimap_static=%.0fms minimap_markers=%.0fms build_count=%d map_screen=%.0fms night_overlay=%.1fms total_resources=%d total_creatures=%d fps=%d performance_process=%.1fms physics=%.1fms prof_total=%.1fms prof_max=%s:%.1fms prof_suspect=%s unattributed=%.1fms" % [
		int(hitch.get("realtime_delta_ms", 0)),
		float(hitch.get("engine_delta_ms", 0.0)),
		top_text,
		world_process_ms,
		visibility_ms,
		int(world_summary.get("visibility_show_count", world_summary.get("shown_this_frame", 0))),
		int(world_summary.get("visibility_hide_count", world_summary.get("hidden_this_frame", 0))),
		int(world_summary.get("visibility_pending_show_count", world_summary.get("pending_show_count", 0))),
		int(world_summary.get("visibility_dropped_invalid_count", world_summary.get("visibility_pending_dropped_invalid", 0))),
		float(frame_breakdown.get("world_decorative_visible_rect_ms", 0.0)),
		vegetation_candidates,
		vegetation_drawn,
		vegetation_sort_ms,
		float(frame_breakdown.get("vegetation_draw_loop_ms", 0.0)),
		surface_texture_ms,
		str(frame_breakdown.get("world_surface_texture_build_running", false)),
		int(frame_breakdown.get("world_surface_texture_build_count", 0)),
		biome_blend_ms,
		"true" if bool(world_summary.get("biome_blend_texture_cache_hit", false)) else "false",
		ai_sync_ms,
		terrain_surface_ms,
		int(frame_breakdown.get("terrain_surface_chunks_built_last_frame", 0)),
		int(frame_breakdown.get("terrain_surface_refine_pending_count", 0)),
		minimap_ms,
		minimap_process_ms,
		minimap_draw_ms,
		minimap_static_texture_ms,
		minimap_dynamic_markers_ms,
		int(world_summary.get("minimap_build_count", 0)),
		map_screen_ms,
		float(frame_breakdown.get("world_night_overlay_ms", 0.0)),
		int(world_summary.get("visible_resources", 0)),
		int(world_summary.get("visible_creatures", 0)),
		int(performance.get("fps", 0)),
		float(hitch.get("performance_process_ms", 0.0)),
		float(hitch.get("performance_physics_ms", 0.0)),
		float(hitch.get("profiler_snapshot_total_ms", 0.0)),
		str(hitch.get("profiler_snapshot_max_scope", "")),
		float(hitch.get("profiler_snapshot_max_scope_ms", 0.0)),
		str(hitch.get("profiler_snapshot_suspect", false)),
		float(hitch.get("frame_stall_unattributed_ms", 0.0))
	]


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
		"minimap_process_ms": true,
		"minimap_draw_ms": true,
		"minimap_total_cpu_ms": true,
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
	lines.append("Graphics preset: %s" % str(report.get("graphics_preset", "normal")))
	lines.append(_format_active_limits_text(report))
	lines.append("Samples: %d" % int(report.get("sample_count", 0)))
	lines.append("Average FPS: %.2f" % float(report.get("average_fps", 0.0)))
	lines.append("Min FPS: %.2f" % float(report.get("min_fps", 0.0)))
	lines.append("Max FPS: %.2f" % float(report.get("max_fps", 0.0)))
	lines.append("Max frame time: %.2f ms" % float(report.get("max_frame_time_ms", 0.0)))
	lines.append("Max wall frame delta: %d ms" % int(report.get("max_wall_frame_delta_ms", 0)))
	lines.append("Max performance process: %.2f ms" % float(report.get("max_performance_process_ms", 0.0)))
	lines.append("Max physics time: %.2f ms" % float(report.get("max_physics_time_ms", 0.0)))
	lines.append("Realtime hitch count: %d" % int(report.get("realtime_hitch_count", 0)))
	lines.append("Max realtime delta: %d ms" % int(report.get("max_realtime_delta_ms", 0)))
	lines.append(_format_hitch_summary_text(report))
	lines.append(_format_hitch_breakdown_summary_text(report))
	lines.append("")
	lines.append("Phase summary:")
	lines.append(_format_phase_summary_text(report))
	lines.append("")
	lines.append("Top hitch sections:")
	for item in Array(report.get("top_hitch_sections", [])):
		var section := Dictionary(item)
		lines.append("- %s: %.2f ms" % [str(section.get("section", "")), float(section.get("total_ms", 0.0))])
	lines.append("")
	lines.append(_format_threshold_validation_text(report))
	lines.append("")
	lines.append(_format_resource_spawn_failure_text(report))
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
	var profiler_summary := Dictionary(report.get("runtime_profiler_summary", {}))
	if not profiler_summary.is_empty():
		lines.append("")
		lines.append("Runtime profiler summary: %s" % JSON.stringify(profiler_summary))
	return "\n".join(lines)


func _format_resource_spawn_failure_text(report: Dictionary) -> String:
	var debug := Dictionary(report.get("resource_spawn_failure_debug", {}))
	if debug.is_empty():
		return "Resource spawn failure breakdown: unavailable"
	var lines: Array[String] = []
	lines.append("Resource spawn failure breakdown:")
	lines.append("total_failed=%d top_failure=%s top_rejection=%s" % [
		int(debug.get("total_failed", 0)),
		str(debug.get("top_failure_key", "")),
		str(debug.get("top_rejection_reason", ""))
	])
	var failed_by_key := Dictionary(debug.get("resource_spawn_failed_by_key", {}))
	var rejection_by_key := Dictionary(debug.get("resource_spawn_rejection_by_key", {}))
	var prepass_debug := Dictionary(debug.get("resource_spawn_prepass_debug", {}))
	var source_summary := Dictionary(debug.get("resource_spawn_source_summary", {}))
	var distribution_by_kind := Dictionary(debug.get("resource_spawn_distribution_by_kind", {}))
	var distribution_by_biome := Dictionary(debug.get("vegetation_distribution_by_biome_and_kind", {}))
	var distribution_by_kind_actual := Dictionary(debug.get("vegetation_distribution_by_kind", {}))
	lines.append("failed_by_key:")
	for item in _sort_dictionary_by_int_value_desc(failed_by_key, 10):
		lines.append("- %s: %d" % [str(item.get("key", "")), int(item.get("value", 0))])
	lines.append("rejection_by_key:")
	for item in _sort_dictionary_by_int_value_desc(rejection_by_key, 10):
		lines.append("- %s: %d" % [str(item.get("key", "")), int(item.get("value", 0))])
	if not prepass_debug.is_empty():
		lines.append("prepass_debug:")
		for item in _sort_dictionary_by_int_value_desc(prepass_debug, 10):
			lines.append("- %s: %s" % [str(item.get("key", "")), JSON.stringify(item.get("value", {}))])
	if not source_summary.is_empty():
		lines.append("source_summary:")
		for item in _sort_dictionary_by_int_value_desc(source_summary, 10):
			lines.append("- %s: %s" % [str(item.get("key", "")), JSON.stringify(item.get("value", {}))])
	if not distribution_by_kind.is_empty():
		lines.append("distribution_by_kind:")
		for kind in _sort_dictionary_by_int_value_desc(distribution_by_kind, 20):
			var payload := Dictionary(kind.get("value", {}))
			lines.append("- %s: total=%d %s" % [
				str(kind.get("key", "")),
				int(payload.get("total", 0)),
				JSON.stringify(payload.get("biomes", {}))
			])
	if not distribution_by_biome.is_empty():
		lines.append("vegetation_distribution_by_biome:")
		for biome in _sort_dictionary_by_int_value_desc(distribution_by_biome, 20):
			var biome_payload := Dictionary(biome.get("value", {}))
			lines.append("- %s: total=%d %s" % [
				str(biome.get("key", "")),
				int(biome_payload.get("total", 0)),
				JSON.stringify(biome_payload)
			])
	if not distribution_by_kind_actual.is_empty():
		lines.append("vegetation_distribution_by_kind:")
		for kind in _sort_dictionary_by_int_value_desc(distribution_by_kind_actual, 20):
			var kind_payload := Dictionary(kind.get("value", {}))
			lines.append("- %s: total=%d %s" % [
				str(kind.get("key", "")),
				int(kind_payload.get("total", 0)),
				JSON.stringify(kind_payload)
			])
	return "\n".join(lines)


func _format_active_limits_text(report: Dictionary) -> String:
	var active_thresholds := Dictionary(report.get("active_benchmark_thresholds", {}))
	if active_thresholds.is_empty():
		return "Active limits: unavailable"
	var base_thresholds := Dictionary(_load_benchmark_thresholds().get("thresholds", {}))
	var lines: Array[String] = []
	lines.append("Active limits for preset %s:" % str(report.get("graphics_preset", "normal")))
	for key in [
		"average_fps_min",
		"runtime_realtime_hitch_count_max",
		"runtime_max_realtime_delta_ms",
		"active_resource_collisions_max",
		"boot_max_frame_time_ms",
		"post_ready_max_frame_time_ms",
		"runtime_max_frame_time_ms",
		"world_surface_texture_max_build_ms_per_frame_max",
		"visibility_cull_ms_max",
		"vegetation_draw_ms_max"
	]:
		if not active_thresholds.has(key):
			continue
		var active_value: Variant = active_thresholds.get(key)
		var base_value: Variant = base_thresholds.get(key, null)
		if base_value == null or active_value != base_value:
			lines.append("- %s: %s" % [key, str(active_value)])
	if lines.size() == 1:
		lines.append("- no overrides from base thresholds")
	return "\n".join(lines)


func _build_resource_spawn_failure_breakdown(report: Dictionary) -> Dictionary:
	var debug := Dictionary(report.get("resource_spawn_failure_debug", {}))
	if debug.is_empty():
		return {}
	return {
		"total_failed": int(debug.get("total_failed", 0)),
		"top_failure_key": str(debug.get("top_failure_key", "")),
		"top_rejection_reason": str(debug.get("top_rejection_reason", "")),
		"failed_by_key": _sort_dictionary_by_int_value_desc(Dictionary(debug.get("resource_spawn_failed_by_key", {})), 25),
		"rejection_by_key": _sort_dictionary_by_int_value_desc(Dictionary(debug.get("resource_spawn_rejection_by_key", {})), 25),
		"prepass_debug": _build_sorted_nested_debug(Dictionary(debug.get("resource_spawn_prepass_debug", {})), 25)
	}


func _capture_latest_resource_spawn_failure_debug() -> Dictionary:
	var latest := {}
	for sample_value in Array(samples):
		var sample := Dictionary(sample_value)
		var failure_debug := Dictionary(sample.get("resource_spawn_failure", {}))
		if not failure_debug.is_empty():
			latest = failure_debug
	return Dictionary(latest)


func _build_sorted_nested_debug(data: Dictionary, limit: int) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	for key in data.keys():
		ranked.append({
			"key": str(key),
			"value": Dictionary(data.get(key, {}))
		})
	if ranked.size() > limit:
		ranked.resize(limit)
	return ranked


func _sort_dictionary_by_int_value_desc(data: Dictionary, limit: int) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	for key in data.keys():
		var raw_value: Variant = data.get(key, 0)
		var sort_value: int = 0
		if raw_value is Dictionary:
			var nested := Dictionary(raw_value)
			sort_value = int(nested.get("total_failed", nested.get("count", nested.get("samples", 0))))
		else:
			sort_value = int(raw_value)
		ranked.append({"key": str(key), "value": raw_value, "sort_value": sort_value})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("sort_value", 0)) > int(right.get("sort_value", 0))
	)
	if ranked.size() > limit:
		ranked.resize(limit)
	return ranked


func _format_phase_summary_text(report: Dictionary) -> String:
	var phase_metrics := Dictionary(report.get("phase_metrics", {}))
	if phase_metrics.is_empty():
		return "Phase summary unavailable"
	var lines: Array[String] = []
	for phase_name in ["pre_ready", "boot_after_ready", "stable_runtime"]:
		var bucket := Dictionary(phase_metrics.get(phase_name, {}))
		lines.append("%s: samples=%d avg_fps=%.2f min_fps=%.2f max_frame_time=%.2fms hitch_count=%d" % [
			phase_name,
			int(bucket.get("sample_count", 0)),
			float(bucket.get("average_fps", 0.0)),
			float(bucket.get("min_fps", 0.0)),
			float(bucket.get("max_frame_time_ms", 0.0)),
			int(bucket.get("realtime_hitch_count", 0))
		])
	return "\n".join(lines)


func _load_benchmark_thresholds() -> Dictionary:
	var defaults := {
		"enabled": true,
		"fail_on_regression_by_default": false,
		"thresholds": {
			"boot_max_frame_time_ms": 120,
			"post_ready_max_frame_time_ms": 90,
			"runtime_max_frame_time_ms": 80,
			"runtime_realtime_hitch_count_max": 3,
			"runtime_max_realtime_delta_ms": 250,
			"realtime_hitches_after_ready_max": 3,
			"average_fps_min": 50,
			"max_frame_time_ms_max": 80,
			"max_wall_frame_delta_ms_max": 250,
			"max_performance_process_ms_max": 80,
			"minimap_build_ms_max": 60,
			"realtime_hitch_count_max": 3,
			"max_realtime_delta_ms_max": 250,
			"minimap_texture_build_count_max": 2,
			"map_screen_texture_build_count_max": 2,
			"world_biome_texture_build_count_max": 2,
			"world_surface_texture_last_build_ms_max": 20,
			"visibility_cull_ms_max": 10,
			"vegetation_draw_ms_max": 20,
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


func _get_active_benchmark_thresholds(report: Dictionary = {}) -> Dictionary:
	var threshold_config := _load_benchmark_thresholds()
	var thresholds := Dictionary(threshold_config.get("thresholds", {})).duplicate(true)
	var preset_name := str(report.get("graphics_preset", _get_active_graphics_preset()))
	var graphics_presets := Dictionary(threshold_config.get("graphics_presets", {}))
	if graphics_presets.has(preset_name):
		var preset_overrides := Dictionary(graphics_presets.get(preset_name, {}))
		for key in preset_overrides.keys():
			thresholds[key] = preset_overrides[key]
	return thresholds


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
		"max_wall_frame_delta_ms": int(report.get("max_wall_frame_delta_ms", 0)),
		"max_performance_process_ms": float(report.get("max_performance_process_ms", 0.0)),
		"realtime_hitch_count": int(report.get("realtime_hitch_count", 0)),
		"max_realtime_delta_ms": int(report.get("max_realtime_delta_ms", 0)),
		"world_surface_texture_build_count": 0,
		"world_surface_texture_last_build_ms": 0.0,
		"surface_texture_build_running": false,
		"visibility_cull_show_count": 0,
		"visibility_cull_hide_count": 0,
		"visibility_cull_ms": 0.0,
		"vegetation_draw_ms": 0.0,
		"vegetation_candidate_count": 0,
		"resource_spawn_failed_total": 0,
		"resource_spawn_failed_by_kind": {},
		"minimap_texture_build_count": 0,
		"minimap_build_ms": 0.0,
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
			"minimap_build_ms",
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
		var world_summary: Dictionary = Dictionary(sample.get("world_summary", {}))
		var minimap_stats: Dictionary = Dictionary(sample.get("minimap", {}))
		var map_screen_stats: Dictionary = Dictionary(sample.get("map_screen", {}))
		var world_vegetation: Dictionary = Dictionary(world_summary.get("vegetation", {}))
		var resource_render_mode: Dictionary = Dictionary(world_stats.get("resource_render_mode", {}))
		if performance.has("node_count"):
			metrics["node_count"] = maxi(int(metrics["node_count"]), int(performance.get("node_count", 0)))
		else:
			missing_metric_set["node_count"] = true
		if world_summary.has("active_resource_collisions"):
			metrics["active_resource_collisions"] = maxi(int(metrics["active_resource_collisions"]), int(world_summary.get("active_resource_collisions", 0)))
		elif resource_render_mode.has("active_resource_collisions"):
			metrics["active_resource_collisions"] = maxi(int(metrics["active_resource_collisions"]), int(resource_render_mode.get("active_resource_collisions", 0)))
		else:
			missing_metric_set["active_resource_collisions"] = true
		if minimap_stats.has("texture_build_count"):
			metrics["minimap_texture_build_count"] = maxi(int(metrics["minimap_texture_build_count"]), int(minimap_stats.get("texture_build_count", 0)))
			metrics["minimap_build_ms"] = max(float(metrics["minimap_build_ms"]), float(minimap_stats.get("texture_last_build_ms", 0.0)))
		else:
			metrics["minimap_texture_build_count"] = maxi(int(metrics["minimap_texture_build_count"]), int(world_summary.get("minimap_build_count", 0)))
			metrics["minimap_build_ms"] = max(float(metrics["minimap_build_ms"]), float(world_summary.get("minimap_build_ms", 0.0)))
		if map_screen_stats.has("texture_build_count"):
			metrics["map_screen_texture_build_count"] = maxi(int(metrics["map_screen_texture_build_count"]), int(map_screen_stats.get("texture_build_count", 0)))
		else:
			metrics["map_screen_texture_build_count"] = maxi(int(metrics["map_screen_texture_build_count"]), 0)
		var biome_cache: Dictionary = Dictionary(world_stats.get("biome_texture_cache", {}))
		if world_summary.has("world_biome_texture_build_count"):
			metrics["world_biome_texture_build_count"] = maxi(int(metrics["world_biome_texture_build_count"]), int(world_summary.get("world_biome_texture_build_count", 0)))
		elif biome_cache.has("world_biome_texture_build_count"):
			metrics["world_biome_texture_build_count"] = maxi(int(metrics["world_biome_texture_build_count"]), int(biome_cache.get("world_biome_texture_build_count", 0)))
		else:
			missing_metric_set["world_biome_texture_build_count"] = true
		# World surface texture metrics
		if world_summary.has("world_surface_texture_chunks_built"):
			metrics["world_surface_texture_chunks_built"] = maxi(int(metrics["world_surface_texture_chunks_built"]), int(world_summary.get("world_surface_texture_chunks_built", 0)))
		elif performance.has("world_surface_texture_chunks_built"):
			metrics["world_surface_texture_chunks_built"] = maxi(int(metrics["world_surface_texture_chunks_built"]), int(performance.get("world_surface_texture_chunks_built", 0)))
		else:
			missing_metric_set["world_surface_texture_chunks_built"] = true
		if world_summary.has("world_surface_texture_max_build_ms_per_frame"):
			metrics["world_surface_texture_max_build_ms_per_frame"] = max(float(metrics["world_surface_texture_max_build_ms_per_frame"]), float(world_summary.get("world_surface_texture_max_build_ms_per_frame", 0.0)))
		elif performance.has("world_surface_texture_max_build_ms_per_frame"):
			metrics["world_surface_texture_max_build_ms_per_frame"] = max(float(metrics["world_surface_texture_max_build_ms_per_frame"]), float(performance.get("world_surface_texture_max_build_ms_per_frame", 0.0)))
		else:
			missing_metric_set["world_surface_texture_max_build_ms_per_frame"] = true
		if world_summary.has("world_surface_texture_pending_chunks"):
			metrics["world_surface_texture_pending_chunks"] = maxi(int(metrics["world_surface_texture_pending_chunks"]), int(world_summary.get("world_surface_texture_pending_chunks", 0)))
		elif performance.has("world_surface_texture_pending_chunks"):
			metrics["world_surface_texture_pending_chunks"] = maxi(int(metrics["world_surface_texture_pending_chunks"]), int(performance.get("world_surface_texture_pending_chunks", 0)))
		else:
			missing_metric_set["world_surface_texture_pending_chunks"] = true
		metrics["world_surface_texture_build_count"] = maxi(int(metrics["world_surface_texture_build_count"]), int(world_summary.get("world_surface_texture_build_count", 0)))
		metrics["world_surface_texture_last_build_ms"] = max(float(metrics["world_surface_texture_last_build_ms"]), float(world_summary.get("world_surface_texture_last_build_ms", 0.0)))
		metrics["surface_texture_build_running"] = bool(metrics["surface_texture_build_running"]) or bool(world_summary.get("surface_texture_build_running", false))
		metrics["visibility_cull_show_count"] = maxi(int(metrics["visibility_cull_show_count"]), int(world_summary.get("visibility_cull_show_count", 0)))
		metrics["visibility_cull_hide_count"] = maxi(int(metrics["visibility_cull_hide_count"]), int(world_summary.get("visibility_cull_hide_count", 0)))
		metrics["visibility_cull_ms"] = max(float(metrics["visibility_cull_ms"]), float(world_summary.get("visibility_cull_ms", 0.0)))
		metrics["vegetation_draw_ms"] = max(float(metrics["vegetation_draw_ms"]), float(world_vegetation.get("vegetation_draw_ms", 0.0)))
		metrics["vegetation_candidate_count"] = maxi(int(metrics["vegetation_candidate_count"]), int(world_vegetation.get("vegetation_candidate_count", 0)))
		var resource_spawn_failure: Dictionary = Dictionary(sample.get("resource_spawn_failure", {}))
		metrics["resource_spawn_failed_total"] = maxi(int(metrics["resource_spawn_failed_total"]), int(resource_spawn_failure.get("total_failed", 0)))
		var failed_by_kind: Dictionary = Dictionary(resource_spawn_failure.get("failed_by_kind", {}))
		var current_failed_by_kind: Dictionary = Dictionary(metrics.get("resource_spawn_failed_by_kind", {}))
		for kind in failed_by_kind.keys():
			current_failed_by_kind[kind] = maxi(int(current_failed_by_kind.get(kind, 0)), int(failed_by_kind.get(kind, 0)))
		metrics["resource_spawn_failed_by_kind"] = current_failed_by_kind
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
	var thresholds := _get_active_benchmark_thresholds(report)
	var fail_on_regression := _should_fail_on_regression(threshold_config)
	var metrics := _extract_regression_metrics(report)
	var violations: Array[Dictionary] = []
	var warnings: Array[Dictionary] = []
	var missing_metrics_reported: Dictionary = {}
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
	_check_threshold_min(metrics, thresholds, violations, warnings, missing_metrics_reported, "average_fps", "average_fps_min", ">=", "average_fps %s is below required minimum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, missing_metrics_reported, "max_frame_time_ms", "max_frame_time_ms_max", "<=", "max_frame_time_ms %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, missing_metrics_reported, "max_wall_frame_delta_ms", "max_wall_frame_delta_ms_max", "<=", "max_wall_frame_delta_ms %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, missing_metrics_reported, "max_performance_process_ms", "max_performance_process_ms_max", "<=", "max_performance_process_ms %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, missing_metrics_reported, "realtime_hitch_count", "realtime_hitch_count_max", "<=", "realtime_hitch_count %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, missing_metrics_reported, "max_realtime_delta_ms", "max_realtime_delta_ms_max", "<=", "max_realtime_delta_ms %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, missing_metrics_reported, "minimap_texture_build_count", "minimap_texture_build_count_max", "<=", "minimap_texture_build_count %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, missing_metrics_reported, "minimap_build_ms", "minimap_build_ms_max", "<=", "minimap_build_ms %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, missing_metrics_reported, "map_screen_texture_build_count", "map_screen_texture_build_count_max", "<=", "map_screen_texture_build_count %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, missing_metrics_reported, "world_biome_texture_build_count", "world_biome_texture_build_count_max", "<=", "world_biome_texture_build_count %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, missing_metrics_reported, "world_surface_texture_build_count", "world_surface_texture_build_count_max", "<=", "world_surface_texture_build_count %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, missing_metrics_reported, "world_surface_texture_last_build_ms", "world_surface_texture_last_build_ms_max", "<=", "world_surface_texture_last_build_ms %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, missing_metrics_reported, "surface_texture_build_running", "surface_texture_build_running_max", "<=", "surface_texture_build_running %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, missing_metrics_reported, "visibility_cull_show_count", "visibility_cull_show_count_max", "<=", "visibility_cull_show_count %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, missing_metrics_reported, "visibility_cull_hide_count", "visibility_cull_hide_count_max", "<=", "visibility_cull_hide_count %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, missing_metrics_reported, "visibility_cull_ms", "visibility_cull_ms_max", "<=", "visibility_cull_ms %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, missing_metrics_reported, "vegetation_draw_ms", "vegetation_draw_ms_max", "<=", "vegetation_draw_ms %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, missing_metrics_reported, "vegetation_candidate_count", "vegetation_candidate_count_max", "<=", "vegetation_candidate_count %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, missing_metrics_reported, "resource_spawn_failed_total", "resource_spawn_failed_total_max", "<=", "resource_spawn_failed_total %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, missing_metrics_reported, "active_resource_collisions", "active_resource_collisions_max", "<=", "active_resource_collisions %s exceeds maximum %s")
	_check_threshold_max(metrics, thresholds, violations, warnings, missing_metrics_reported, "node_count", "node_count_max", "<=", "node_count %s exceeds maximum %s")
	_append_phase_threshold_checks(report, thresholds, violations, warnings, missing_metrics_reported)
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


func _append_phase_threshold_checks(report: Dictionary, thresholds: Dictionary, violations: Array[Dictionary], warnings: Array[Dictionary], missing_metrics_reported: Dictionary) -> void:
	var phase_metrics := Dictionary(report.get("phase_metrics", {}))
	var pre_ready := Dictionary(phase_metrics.get("pre_ready", {}))
	var boot_after_ready := Dictionary(phase_metrics.get("boot_after_ready", {}))
	var stable := Dictionary(phase_metrics.get("stable_runtime", {}))
	_check_phase_metric_max(pre_ready, thresholds, violations, warnings, missing_metrics_reported, "max_frame_time_ms", "pre_ready_max_frame_time_ms", "pre_ready max_frame_time_ms %s exceeds maximum %s")
	_check_phase_metric_max(boot_after_ready, thresholds, violations, warnings, missing_metrics_reported, "max_frame_time_ms", "boot_after_ready_max_frame_time_ms", "boot_after_ready max_frame_time_ms %s exceeds maximum %s")
	_check_phase_metric_max(stable, thresholds, violations, warnings, missing_metrics_reported, "max_frame_time_ms", "runtime_max_frame_time_ms", "runtime max_frame_time_ms %s exceeds maximum %s")
	_check_phase_metric_max(stable, thresholds, violations, warnings, missing_metrics_reported, "realtime_hitch_count", "runtime_realtime_hitch_count_max", "runtime realtime_hitch_count %s exceeds maximum %s")
	_check_phase_metric_max(stable, thresholds, violations, warnings, missing_metrics_reported, "max_realtime_delta_ms", "runtime_max_realtime_delta_ms", "runtime max_realtime_delta_ms %s exceeds maximum %s")
	_check_phase_metric_max(boot_after_ready, thresholds, violations, warnings, missing_metrics_reported, "realtime_hitch_count", "realtime_hitches_after_ready_max", "boot_after_ready realtime_hitch_count %s exceeds maximum %s")
	_check_phase_metric_max(stable, thresholds, violations, warnings, missing_metrics_reported, "realtime_hitch_count", "realtime_hitches_after_ready_max", "stable runtime realtime_hitch_count %s exceeds maximum %s")
	_check_phase_metric_max(boot_after_ready, thresholds, violations, warnings, missing_metrics_reported, "max_world_surface_texture_last_build_ms", "world_surface_texture_last_build_ms_max", "boot_after_ready world_surface_texture_last_build_ms %s exceeds maximum %s")
	_check_phase_metric_max(boot_after_ready, thresholds, violations, warnings, missing_metrics_reported, "max_visibility_cull_ms", "visibility_cull_ms_max", "boot_after_ready visibility_cull_ms %s exceeds maximum %s")
	_check_phase_metric_max(boot_after_ready, thresholds, violations, warnings, missing_metrics_reported, "max_vegetation_draw_ms", "vegetation_draw_ms_max", "boot_after_ready vegetation_draw_ms %s exceeds maximum %s")


func _check_phase_metric_max(bucket: Dictionary, thresholds: Dictionary, violations: Array[Dictionary], warnings: Array[Dictionary], missing_metrics_reported: Dictionary, metric_name: String, threshold_name: String, message_template: String) -> void:
	if not bucket.has(metric_name):
		_record_missing_metric_once(missing_metrics_reported, warnings, metric_name)
		return
	if not thresholds.has(threshold_name):
		return
	var actual := float(bucket.get(metric_name, 0.0))
	var threshold := float(thresholds.get(threshold_name, 0.0))
	if actual > threshold:
		violations.append(_build_threshold_violation(metric_name, "<=", threshold, actual, "warning", message_template))


func _record_missing_metric_once(missing_metrics_reported: Dictionary, warnings: Array[Dictionary], metric_name: String) -> void:
	if missing_metrics_reported.has(metric_name):
		return
	missing_metrics_reported[metric_name] = true
	warnings.append({
		"metric": metric_name,
		"message": "Metric missing from benchmark report"
	})


func _check_threshold_min(metrics: Dictionary, thresholds: Dictionary, violations: Array[Dictionary], warnings: Array[Dictionary], missing_metrics_reported: Dictionary, metric_name: String, threshold_name: String, operator_text: String, message_template: String) -> void:
	if not metrics.has(metric_name):
		_record_missing_metric_once(missing_metrics_reported, warnings, metric_name)
		return
	if not thresholds.has(threshold_name):
		return
	var actual := float(metrics.get(metric_name, 0.0))
	var threshold := float(thresholds.get(threshold_name, 0.0))
	if actual < threshold:
		violations.append(_build_threshold_violation(metric_name, operator_text, threshold, actual, "warning", message_template))


func _check_threshold_max(metrics: Dictionary, thresholds: Dictionary, violations: Array[Dictionary], warnings: Array[Dictionary], missing_metrics_reported: Dictionary, metric_name: String, threshold_name: String, operator_text: String, message_template: String) -> void:
	if not metrics.has(metric_name):
		_record_missing_metric_once(missing_metrics_reported, warnings, metric_name)
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
	lines.append(_format_threshold_source_text(report, validation))
	lines.append(_format_threshold_differences_text(report))
	lines.append("Regression metrics:")
	var metrics := Dictionary(validation.get("metrics", {}))
	var thresholds := Dictionary(validation.get("thresholds", {}))
	_append_threshold_metric_line(lines, metrics, thresholds, "average_fps", "average_fps_min", ">=")
	_append_threshold_metric_line(lines, metrics, thresholds, "max_frame_time_ms", "max_frame_time_ms_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "max_wall_frame_delta_ms", "max_wall_frame_delta_ms_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "max_performance_process_ms", "max_performance_process_ms_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "realtime_hitch_count", "realtime_hitch_count_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "max_realtime_delta_ms", "max_realtime_delta_ms_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "minimap_texture_build_count", "minimap_texture_build_count_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "minimap_build_ms", "minimap_build_ms_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "map_screen_texture_build_count", "map_screen_texture_build_count_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "world_biome_texture_build_count", "world_biome_texture_build_count_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "world_surface_texture_build_count", "world_surface_texture_build_count_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "world_surface_texture_last_build_ms", "world_surface_texture_last_build_ms_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "surface_texture_build_running", "surface_texture_build_running_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "visibility_cull_show_count", "visibility_cull_show_count_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "visibility_cull_hide_count", "visibility_cull_hide_count_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "visibility_cull_ms", "visibility_cull_ms_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "vegetation_draw_ms", "vegetation_draw_ms_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "vegetation_candidate_count", "vegetation_candidate_count_max", "<=")
	_append_threshold_metric_line(lines, metrics, thresholds, "resource_spawn_failed_total", "resource_spawn_failed_total_max", "<=")
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


func _format_threshold_source_text(report: Dictionary, validation: Dictionary) -> String:
	var source_breakdown := Dictionary(report.get("threshold_source_breakdown", {}))
	var base_thresholds := Dictionary(source_breakdown.get("base_thresholds", {}))
	var preset_overrides := Dictionary(source_breakdown.get("preset_overrides", {}))
	var effective_thresholds := Dictionary(source_breakdown.get("effective_thresholds", validation.get("thresholds", {})))
	var preset_name := str(source_breakdown.get("graphics_preset", report.get("graphics_preset", "normal")))
	var lines: Array[String] = []
	lines.append("Threshold sources:")
	lines.append("- base thresholds: %d entries" % base_thresholds.size())
	if preset_overrides.is_empty():
		lines.append("- preset overrides: none for %s" % preset_name)
	else:
		lines.append("- preset overrides for %s: %d entries" % [preset_name, preset_overrides.size()])
	lines.append("- effective thresholds: %d entries" % effective_thresholds.size())
	return "\n".join(lines)


func _format_threshold_differences_text(report: Dictionary) -> String:
	var source_breakdown := Dictionary(report.get("threshold_source_breakdown", {}))
	var differences := Array(source_breakdown.get("differences", []))
	if differences.is_empty():
		return "Threshold differences: none"
	var lines: Array[String] = []
	lines.append("Threshold differences:")
	for item_value in differences:
		var item := Dictionary(item_value)
		lines.append("- %s: base=%s preset=%s effective=%s" % [
			str(item.get("key", "")),
			str(item.get("base", "")),
			str(item.get("preset", "")),
			str(item.get("effective", ""))
		])
	return "\n".join(lines)


func _build_threshold_source_breakdown(report: Dictionary) -> Dictionary:
	var threshold_config := _load_benchmark_thresholds()
	var base_thresholds := Dictionary(threshold_config.get("thresholds", {})).duplicate(true)
	var graphics_presets := Dictionary(threshold_config.get("graphics_presets", {}))
	var preset_name := str(report.get("graphics_preset", "normal"))
	var preset_overrides := Dictionary(graphics_presets.get(preset_name, {})).duplicate(true)
	var effective_thresholds := Dictionary(_get_active_benchmark_thresholds(report)).duplicate(true)
	var interesting_keys := [
		"average_fps_min",
		"runtime_realtime_hitch_count_max",
		"runtime_max_realtime_delta_ms",
		"active_resource_collisions_max",
		"boot_max_frame_time_ms",
		"post_ready_max_frame_time_ms",
		"runtime_max_frame_time_ms",
		"world_surface_texture_max_build_ms_per_frame_max",
		"visibility_cull_ms_max",
		"vegetation_draw_ms_max"
	]
	var differences: Array[Dictionary] = []
	for key in interesting_keys:
		if not effective_thresholds.has(key):
			continue
		var base_value: Variant = base_thresholds.get(key, null)
		var preset_value: Variant = preset_overrides.get(key, base_value)
		var effective_value: Variant = effective_thresholds.get(key, base_value)
		if base_value != preset_value or base_value != effective_value:
			differences.append({
				"key": key,
				"base": base_value,
				"preset": preset_value,
				"effective": effective_value
			})
	return {
		"graphics_preset": preset_name,
		"base_thresholds": base_thresholds,
		"preset_overrides": preset_overrides,
		"effective_thresholds": effective_thresholds,
		"differences": differences
	}


func _format_hitch_summary_text(report: Dictionary) -> String:
	var summary := Dictionary(report.get("runtime_hitch_summary", {}))
	var by_scope: Dictionary = Dictionary(summary.get("hitch_count_by_scope", {}))
	if by_scope.is_empty():
		return "Hitch detector: none"
	var max_by_scope: Dictionary = Dictionary(summary.get("max_delta_by_scope", {}))
	var last_by_scope: Dictionary = Dictionary(summary.get("last_hitch_delta_by_scope", {}))
	var entries: Array[String] = []
	for scope_name in by_scope.keys():
		entries.append("%s observed_count=%d max=%d last=%d" % [
			str(scope_name),
			int(by_scope.get(scope_name, 0)),
			int(max_by_scope.get(scope_name, 0)),
			int(last_by_scope.get(scope_name, 0))
		])
	entries.sort()
	return "Hitch detector: %s" % ", ".join(entries)


func _format_hitch_breakdown_summary_text(report: Dictionary) -> String:
	var summary := Dictionary(report.get("hitch_breakdown_summary", {}))
	if summary.is_empty():
		return "Hitch breakdown: unavailable"
	return "Hitch breakdown: count=%d threshold_ms=%d top_total=%s top_max=%s max_hitch_ms=%d unattributed=%d" % [
		int(summary.get("count", 0)),
		int(summary.get("threshold_ms", 0)),
		str(summary.get("top_scope_by_total_ms", "unattributed")),
		str(summary.get("top_scope_by_max_ms", "unattributed")),
		int(summary.get("max_hitch_ms", 0)),
		int(summary.get("unattributed_hitch_count", 0))
	]


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
	var world_summary: Dictionary = Dictionary(sample.get("world_summary", {}))
	var timing: Dictionary = Dictionary(sample.get("timing", {}))
	var fps := int(performance.get("fps", 0))
	var frame_time_ms := float(timing.get("performance_process_ms", float(performance.get("frame_time_s", 0.0)) * 1000.0))
	var physics_time_ms := float(timing.get("performance_physics_ms", float(performance.get("physics_time_s", 0.0)) * 1000.0))
	var wall_frame_ms := int(timing.get("wall_frame_delta_ms", 0))
	var engine_delta_ms := float(timing.get("engine_delta_ms", 0.0))
	var draw_calls := int(performance.get("draw_calls", 0))
	var render_primitives := int(performance.get("render_primitives", 0))
	var node_count := int(performance.get("node_count", 0))
	var total_creatures := int(world_stats.get("total_creatures", world_summary.get("visible_creatures", 0)))
	var total_resources := int(world_stats.get("total_resources", world_summary.get("visible_resources", 0)))
	var oob := int(world_stats.get("creatures_out_of_bounds_count", 0))
	var window_focused := bool(performance.get("window_focused", false))
	var driver := str(sample.get("likely_driver", "unknown"))
	return "[%s] fps=%d wall=%dms engine=%.1fms frame=%.2fms physics=%.2fms draw_calls=%d primitives=%d nodes=%d creatures=%d resources=%d oob=%d focused=%s driver=%s score=%.2f" % [
		str(sample.get("time_label", "00:00")),
		fps,
		wall_frame_ms,
		engine_delta_ms,
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
	return "  driver_scores render=%.2f ai=%.2f world=%.2f ui=%.2f physics=%.2f creatures=%.2f resources=%.2f scene=%.2f ecosystem=%.2f unattributed=%.2f frame_stall=%.2f" % [
		float(driver_scores.get("render", 0.0)),
		float(driver_scores.get("ai", 0.0)),
		float(driver_scores.get("world", 0.0)),
		float(driver_scores.get("ui", 0.0)),
		float(driver_scores.get("physics", 0.0)),
		float(driver_scores.get("creatures", 0.0)),
		float(driver_scores.get("resources", 0.0)),
		float(driver_scores.get("scene", 0.0)),
		float(driver_scores.get("ecosystem", 0.0)),
		float(driver_scores.get("unattributed", 0.0)),
		float(driver_scores.get("frame_stall", 0.0))
	]


func _format_sample_diagnostics(sample: Dictionary) -> String:
	var world_stats: Dictionary = Dictionary(sample.get("world", {}))
	var world_summary: Dictionary = Dictionary(sample.get("world_summary", {}))
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
		diagnostics.append("render_attribution top=%s enabled=%s sample_count=%d" % [
			top_subsystem,
			"true" if bool(render_attribution.get("enabled", false)) else "false",
			int(render_attribution.get("samples_with_render_attribution", 0))
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
	if world_stats.is_empty() and not world_summary.is_empty():
		diagnostics.append("summary resources=%d creatures=%d visibility_pending=%d visibility_queue_ms=%.2f vegetation=%s" % [
			int(world_summary.get("visible_resources", 0)),
			int(world_summary.get("visible_creatures", 0)),
			int(world_summary.get("visibility_pending_count", 0)),
			float(world_summary.get("visibility_queue_ms", 0.0)),
			str(world_summary.get("vegetation", {}))
		])
	if not world_stats.is_empty():
		var current_biome := str(world_stats.get("current_biome", "unknown"))
		var world_rect := str(world_stats.get("world_rect", "unknown"))
		diagnostics.append("world biome=%s rect=%s total_resources=%d total_creatures=%d oob=%d" % [
			current_biome,
			world_rect,
			int(world_stats.get("total_resources", 0)),
			int(world_stats.get("total_creatures", 0)),
			int(world_stats.get("creatures_out_of_bounds_count", 0))
		])
	elif not world_summary.is_empty():
		diagnostics.append("world summary resources=%d creatures=%d oob=%d" % [
			int(world_summary.get("visible_resources", 0)),
			int(world_summary.get("visible_creatures", 0)),
			0
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
	var hitch_delta_ms := int(round(delta * 1000.0))
	hitch_count_by_scope[system_name] = int(hitch_count_by_scope.get(system_name, 0)) + 1
	max_delta_by_scope[system_name] = maxi(int(max_delta_by_scope.get(system_name, 0)), hitch_delta_ms)
	last_hitch_delta_by_scope[system_name] = hitch_delta_ms
	if not bool(GAME_BALANCE.DEBUG_HITCH_VERBOSE_LOGGING) and not verbose_hitch_logging:
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
