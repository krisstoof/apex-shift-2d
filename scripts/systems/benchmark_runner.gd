extends Node
class_name BenchmarkRunner

signal finished(log_path: String, json_path: String)
signal benchmark_progress(elapsed_seconds: float, remaining_seconds: float)

const BENCHMARK_DURATION_SECONDS := 60.0
const SAMPLE_INTERVAL_SECONDS := 1.0
const LOG_DIRECTORY := "user://benchmark_logs"
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

# HITCH LOGGER COUNTERS
var benchmark_sample_build_ms: float = 0.0
var benchmark_file_write_ms: float = 0.0
var last_reported_second := -1

var scene: Node
var world: Node
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
	last_reported_second = -1
	benchmark_progress.emit(0.0, BENCHMARK_DURATION_SECONDS)
	return true


func _process(delta: float) -> void:
	if not running:
		return
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


func _capture_context() -> bool:
	scene = get_tree().current_scene
	if not is_instance_valid(scene):
		return false
	world = scene.get_node_or_null("World")
	player = scene.get_node_or_null("Player") as Node2D
	evolution_director = scene.get_node_or_null("EvolutionDirector")
	day_night_system = scene.get_node_or_null("DayNightSystem")
	ecosystem_director = scene.get_node_or_null("EcosystemDirector")
	return is_instance_valid(world) and is_instance_valid(player) and is_instance_valid(evolution_director) and is_instance_valid(day_night_system) and is_instance_valid(ecosystem_director)


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
	sample["player"] = _capture_player_stats()
	sample["ecosystem"] = _capture_ecosystem_stats()
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
	stats["landmark_debug"] = _capture_world_landmark_debug_stats()
	stats["registry"] = _capture_world_registry_stats()
	stats["render_flags"] = _capture_world_render_flags()
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
	stats["total_creatures"] = _sum_group_counts(stats["creature_counts"])
	stats["total_resources"] = _sum_group_counts(stats["resource_counts"])
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
	return {
		"textures_enabled": bool(cache_status.get("textures_enabled", true)),
		"has_blend_texture": bool(cache_status.get("has_blend_texture", false)),
		"blend_texture_size": str(cache_status.get("blend_texture_size", Vector2i.ZERO)),
		"sample_image_cache_count": int(cache_status.get("sample_image_cache_count", 0)),
		"accent_cache_count": int(cache_status.get("accent_cache_count", 0)),
		"pending_biomes": int(cache_status.get("pending_biomes", 0)),
		"build_running": bool(cache_status.get("build_running", false)),
		"blend_colors_key_length": str(cache_status.get("blend_colors_key", "")).length()
	}


func _capture_world_small_prey_spawn_sync_stats() -> Dictionary:
	if not is_instance_valid(world) or not world.has_method("get_small_prey_spawn_sync_debug"):
		return {}
	return Dictionary(world.get_small_prey_spawn_sync_debug())


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
		"biome_textures_enabled": world.are_biome_textures_enabled() if world.has_method("are_biome_textures_enabled") else true,
		"landmark_debug_overlay_enabled": world.is_landmark_debug_overlay_enabled() if world.has_method("is_landmark_debug_overlay_enabled") else false
	}


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
	var draw_calls := float(performance.get("draw_calls", 0))
	var render_primitives := float(performance.get("render_primitives", 0))
	var render_objects := float(performance.get("render_objects", 0))
	var frame_time_ms := float(performance.get("frame_time_s", 0.0)) * 1000.0
	var physics_time_ms := float(performance.get("physics_time_s", 0.0)) * 1000.0
	var node_count := float(performance.get("node_count", 0))
	var physics_pairs := float(performance.get("physics_2d_collision_pairs", 0))
	var physics_active := float(performance.get("physics_2d_active", 0))
	var creature_pressure := total_creatures * 1.8 + float(creature_counts.get("varnak", 0)) * 1.4
	var resource_pressure := total_resources * 0.8 + float(resource_counts.get("pond_vegetation", 0)) * 0.6 + float(special_resource_counts.get("edible_vegetation", 0)) * 0.4
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
	var out_of_bounds := float(world_stats.get("creatures_out_of_bounds_count", 0))
	var biome_count := float(ecosystem_stats.get("biome_count", 0))
	var food_stress := float(ecosystem_stats.get("highest_food_stress", 0.0))
	return frame_time_ms + physics_time_ms * 0.8 + draw_calls * 0.08 + render_primitives * 0.001 + node_count * 0.01 + total_creatures * 0.06 + total_resources * 0.02 + out_of_bounds * 2.0 + biome_count * 0.4 + food_stress * 5.0


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
	return {
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
		"heaviest_sample": heaviest_sample,
		"top_samples": top_samples,
		"samples": samples
	}


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
	return "\n".join(lines)


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
	var boot_stats: Dictionary = Dictionary(world_stats.get("boot", {}))
	var texture_cache: Dictionary = Dictionary(world_stats.get("biome_texture_cache", {}))
	var landmark_debug: Dictionary = Dictionary(world_stats.get("landmark_debug", {}))
	var registry_stats: Dictionary = Dictionary(world_stats.get("registry", {}))
	var render_flags: Dictionary = Dictionary(world_stats.get("render_flags", {}))
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
		diagnostics.append("flags biome_textures=%s landmark_overlay=%s" % [
			"true" if bool(render_flags.get("biome_textures_enabled", true)) else "false",
			"true" if bool(render_flags.get("landmark_debug_overlay_enabled", false)) else "false"
		])
	return "  diagnostics %s" % " | ".join(diagnostics)


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
	var minutes := whole_seconds / 60
	var remainder := whole_seconds % 60
	return "%02d:%02d" % [minutes, remainder]


func _post_message(message: String) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_method("post_message"):
		event_bus.post_message(message)
