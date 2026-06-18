extends RefCounted

const BENCHMARK_RUNNER := preload("res://scripts/systems/benchmark_runner.gd")
const RUNTIME_PROFILER := preload("res://scripts/debug/runtime_profiler.gd")
const RESOURCE_NODE_SCENE := preload("res://scenes/world/resource_node.tscn")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


class CountingBenchmarkRunner:
	extends BENCHMARK_RUNNER

	var record_calls := 0

	func _record_sample() -> void:
		record_calls += 1


class FakeWorld extends Node:

	var landmarks: Array[Dictionary] = [
		{"type": "pond"},
		{"type": "hill"},
		{"type": "hill"}
	]
	var resources: Array[Node] = []

	func get_world_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(100.0, 100.0))

	func get_creatures_out_of_bounds_count() -> int:
		return 2

	func get_biome_zones() -> Array[Dictionary]:
		return [{"name": "Westwood", "points": PackedVector2Array([
			Vector2(-10.0, -10.0),
			Vector2(110.0, -10.0),
			Vector2(110.0, 110.0),
			Vector2(-10.0, 110.0)
		])}]

	func get_landmarks() -> Array[Dictionary]:
		return landmarks

	func get_boot_progress_state() -> Dictionary:
		return {
			"message": "Rendering world...",
			"progress": 0.94,
			"boot_ready": false
		}

	func is_boot_ready() -> bool:
		return false

	func get_biome_texture_cache_status() -> Dictionary:
		return {
			"textures_enabled": true,
			"has_blend_texture": true,
			"blend_texture_size": Vector2i(384, 236),
			"sample_image_cache_count": 5,
			"accent_cache_count": 5,
			"pending_biomes": 0,
			"build_running": false,
			"blend_colors_key": "abc123",
			"rebuild_count": 7,
			"last_build_ms": 12.5,
			"rebuild_blocked_count": 3,
			"dirty_key_pending": true,
			"freeze_after_first_build": true
		}

	func get_varnak_spawn_sync_debug() -> Dictionary:
		return {
			"retry_timer": 0.0,
			"warning_printed": false,
			"attempt_count": 1,
			"failed_count": 0,
			"skipped_by_cooldown_count": 0,
			"last_requested": 2,
			"last_failed": 0,
			"last_success": 2
		}

	func get_visibility_culling_debug() -> Dictionary:
		return {
			"enabled": true,
			"interval_seconds": 0.35,
			"margin": 384.0,
			"visible_resources": 3,
			"hidden_resources": 8,
			"visible_creatures": 2,
			"hidden_creatures": 6
		}

	func get_terrain_renderer_debug() -> Dictionary:
		return {
			"terrain_surface_chunk_visible_count": 9,
			"terrain_surface_chunk_cached_count": 12,
			"terrain_surface_chunk_pending_count": 2,
			"terrain_surface_chunks_built_last_frame": 1,
			"terrain_chunk_count_visible": 4,
			"terrain_chunk_drawn_cell_count": 128,
			"biome_shape_renderer_drawn_polygon_count": 5,
			"biome_shape_renderer_drawn_detail_count": 17
		}

	func get_landmark_counts() -> Dictionary:
		return {"generated": 3, "pond": 1, "hill": 2}

	func get_topography_feature_counts() -> Dictionary:
		return {"pond": 2, "highland": 1, "rocky_patch": 1}

	func get_registered_resources() -> Array:
		return [Node.new(), Node.new(), Node.new()]

	func get_registered_buildings() -> Array:
		return [Node.new()]

	func are_biome_textures_enabled() -> bool:
		return true

	func is_landmark_debug_overlay_enabled() -> bool:
		return false

	func are_biome_terrain_accents_enabled() -> bool:
		return false

	func is_low_end_rendering_enabled() -> bool:
		return true

	func get_ecosystem_state_source() -> String:
		return "generated"

	func get_resource_spawn_rejection_debug() -> Dictionary:
		return {"tree": {"blocked_by_water": 3, "outside_biome": 2}}

	func get_cached_group_nodes(group_name: String) -> Array:
		match group_name:
			"small_prey":
				return _get_group_children("small_prey")
			"grazer":
				return _get_group_children("grazer")
			"varnak":
				return _get_group_children("varnak")
			"trees":
				return [Node.new()]
			"bushes":
				return [Node.new()]
			"grass":
				return [Node.new()]
			"rocks":
				return [Node.new()]
			"pond_vegetation":
				return [Node.new()]
			"edible_vegetation":
				return [Node.new(), Node.new()]
			"resources":
				return resources
		return []

	func _get_group_children(group_name: String) -> Array:
		var result: Array = []
		for child in get_children():
			if child is Node and child.is_in_group(group_name):
				result.append(child)
		return result


class FakeMinimap extends Node:
	func get_minimap_performance_debug() -> Dictionary:
		return {
			"redraw_count": 4,
			"static_redraw_count": 1,
			"dynamic_redraw_count": 3,
			"player_marker_redraw_count": 3,
			"static_cache_rebuild_count": 8,
			"marker_cache_rebuild_count": 5,
			"landmark_cache_rebuild_count": 6,
			"texture_build_count": 7,
			"texture_last_build_ms": 3.5,
			"minimap_static_map_dirty": false,
			"minimap_marker_cache_dirty": false,
			"minimap_shoreline_cache_dirty": false,
			"minimap_player_layer_dirty": false,
			"minimap_view_dirty": false,
			"minimap_marker_cache_check_count": 4,
			"minimap_marker_cache_skipped_unchanged_count": 3,
			"minimap_shoreline_check_count": 2,
			"minimap_shoreline_skipped_unchanged_count": 1,
			"minimap_queue_static_redraw_count": 1,
			"minimap_queue_marker_redraw_count": 3,
			"minimap_queue_player_redraw_count": 3,
			"minimap_biome_texture_sync_check_count": 5,
			"minimap_biome_texture_sync_skipped_count": 4,
			"minimap_biome_texture_dirty_count": 1,
			"minimap_player_marker_redraw_count": 3
		}


class FakeMapScreen extends Node:
	func get_map_screen_performance_debug() -> Dictionary:
		return {
			"redraw_count": 8,
			"cache_rebuild_count": 9,
			"skipped_update_hidden_count": 2,
			"texture_build_count": 10,
			"texture_last_build_ms": 4.5,
			"map_screen_marker_cache_check_count": 6,
			"map_screen_marker_cache_rebuild_count": 2,
			"map_screen_marker_cache_skipped_unchanged_count": 4,
			"map_screen_shoreline_check_count": 5,
			"map_screen_shoreline_build_count": 1,
			"map_screen_shoreline_skipped_unchanged_count": 4
		}


class FakeHud extends Node:
	var map_open_requests := 0
	var last_map_open_state := false

	func _set_map_screen_open(open: bool) -> void:
		map_open_requests += 1
		last_map_open_state = open


class FakeCreature extends Node:
	var ai_decision_count := 0

	func get_ai_performance_debug() -> Dictionary:
		return {
			"decision_count": ai_decision_count
		}


func _make_resource(kind: String) -> Node:
	var resource := RESOURCE_NODE_SCENE.instantiate() as Node
	resource.call("setup", kind)
	return resource


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_benchmark_runner_captures_world_diagnostics(failures)
	_test_benchmark_runner_formats_diagnostics_into_text_log(failures)
	_test_benchmark_runner_formats_threshold_validation_into_text_log(failures)
	_test_benchmark_runner_records_at_most_one_sample_per_frame(failures)
	_test_benchmark_runner_captures_realtime_hitch_summary(failures)
	_test_benchmark_runner_defaults_realtime_hitch_count_to_zero(failures)
	_test_benchmark_runner_opens_map_screen_for_map_open_preset(failures)
	_test_benchmark_runner_captures_ecosystem_and_spawn_debug(failures)
	return failures


func _test_benchmark_runner_captures_world_diagnostics(failures: Array[String]) -> void:
	var runner := BENCHMARK_RUNNER.new()
	var fake_world := FakeWorld.new()
	var fake_minimap := FakeMinimap.new()
	var fake_map_screen := FakeMapScreen.new()
	fake_world.resources = [
		_make_resource("grass_patch"),
		_make_resource("dense_grass"),
		_make_resource("bush")
	]
	runner.world = fake_world
	runner.minimap = fake_minimap
	runner.map_screen = fake_map_screen
	var player := Node2D.new()
	player.global_position = Vector2.ZERO
	runner.player = player
	var small_prey := FakeCreature.new()
	small_prey.ai_decision_count = 12
	small_prey.add_to_group("small_prey")
	var grazer := FakeCreature.new()
	grazer.ai_decision_count = 6
	grazer.add_to_group("grazer")
	var varnak := FakeCreature.new()
	varnak.ai_decision_count = 9
	varnak.add_to_group("varnak")
	fake_world.add_child(small_prey)
	fake_world.add_child(grazer)
	fake_world.add_child(varnak)
	var stats: Dictionary = runner.call("_capture_world_stats")
	var boot: Dictionary = Dictionary(stats.get("boot", {}))
	var texture_cache: Dictionary = Dictionary(stats.get("biome_texture_cache", {}))
	var varnak_sync: Dictionary = Dictionary(stats.get("varnak_spawn_sync", {}))
	var registry: Dictionary = Dictionary(stats.get("registry", {}))
	var render_flags: Dictionary = Dictionary(stats.get("render_flags", {}))
	var visibility_culling: Dictionary = Dictionary(stats.get("visibility_culling", {}))
	var terrain_renderer: Dictionary = Dictionary(stats.get("terrain_renderer", {}))
	var render_pressure: Dictionary = Dictionary(stats.get("render_pressure", {}))
	var resource_render_mode: Dictionary = Dictionary(stats.get("resource_render_mode", {}))
	var minimap_stats: Dictionary = runner.call("_capture_minimap_stats")
	var map_screen_stats: Dictionary = runner.call("_capture_map_screen_stats")
	var ai_stats: Dictionary = runner.call("_capture_ai_decision_stats")
	TEST_UTILS.expect_equal(str(boot.get("stage_message", "")), "Rendering world...", failures, "Benchmark runner should capture the current world boot stage")
	TEST_UTILS.expect_close(float(boot.get("progress", 0.0)), 0.94, failures, "Benchmark runner should capture the current world boot progress")
	TEST_UTILS.expect(texture_cache.get("has_blend_texture", false) == true, failures, "Benchmark runner should capture whether the world blend texture cache exists")
	TEST_UTILS.expect_equal(int(texture_cache.get("world_biome_texture_build_count", 0)), 7, failures, "Benchmark runner should capture the world biome texture build count")
	TEST_UTILS.expect_equal(int(texture_cache.get("rebuild_count", 0)), 7, failures, "Benchmark runner should preserve the raw biome texture rebuild count")
	TEST_UTILS.expect_close(float(texture_cache.get("world_biome_texture_last_build_ms", 0.0)), 12.5, failures, "Benchmark runner should capture the world biome texture build time")
	TEST_UTILS.expect_close(float(texture_cache.get("last_build_ms", 0.0)), 12.5, failures, "Benchmark runner should preserve the raw biome texture build time")
	TEST_UTILS.expect_equal(int(texture_cache.get("rebuild_blocked_count", 0)), 3, failures, "Benchmark runner should capture blocked biome texture rebuild attempts")
	TEST_UTILS.expect_equal(bool(texture_cache.get("dirty_key_pending", false)), true, failures, "Benchmark runner should capture whether a dirty biome texture key is pending")
	TEST_UTILS.expect_equal(bool(texture_cache.get("freeze_after_first_build", false)), true, failures, "Benchmark runner should capture whether biome texture rebuilds freeze after the first build")
	TEST_UTILS.expect_equal(int(texture_cache.get("accent_cache_count", 0)), 5, failures, "Benchmark runner should capture biome accent cache size")
	TEST_UTILS.expect_equal(int(varnak_sync.get("attempt_count", 0)), 1, failures, "Benchmark runner should capture Varnak spawn sync diagnostics")
	TEST_UTILS.expect_equal(int(registry.get("registered_resources", 0)), 3, failures, "Benchmark runner should capture registered resource totals")
	TEST_UTILS.expect(render_flags.get("biome_textures_enabled", false) == true, failures, "Benchmark runner should capture whether biome textures are enabled")
	TEST_UTILS.expect(render_flags.get("low_end_rendering", false) == true, failures, "Benchmark runner should capture whether low-end rendering is enabled")
	TEST_UTILS.expect(render_flags.get("biome_terrain_accents_enabled", true) == false, failures, "Benchmark runner should capture whether biome terrain accents are enabled")
	TEST_UTILS.expect_equal(int(visibility_culling.get("visible_resources", 0)), 3, failures, "Benchmark runner should capture visible resource counts")
	TEST_UTILS.expect_equal(int(visibility_culling.get("hidden_resources", 0)), 8, failures, "Benchmark runner should capture hidden resource counts")
	TEST_UTILS.expect_equal(int(visibility_culling.get("visible_creatures", 0)), 2, failures, "Benchmark runner should capture visible creature counts")
	TEST_UTILS.expect_equal(int(visibility_culling.get("hidden_creatures", 0)), 6, failures, "Benchmark runner should capture hidden creature counts")
	TEST_UTILS.expect_equal(int(terrain_renderer.get("terrain_surface_chunk_visible_count", 0)), 9, failures, "Benchmark runner should capture terrain surface visible chunks")
	TEST_UTILS.expect_equal(int(render_pressure.get("terrain_surface_visible_chunks", 0)), 9, failures, "Benchmark runner should attribute terrain surface visible chunks in render pressure")
	TEST_UTILS.expect_equal(int(render_pressure.get("terrain_cell_drawn_cells", 0)), 128, failures, "Benchmark runner should attribute cell terrain draw pressure")
	TEST_UTILS.expect_equal(int(render_pressure.get("biome_shape_drawn_details", 0)), 17, failures, "Benchmark runner should attribute biome shape detail draw pressure")
	TEST_UTILS.expect_equal(int(render_pressure.get("minimap_static_redraw_count", 0)), 1, failures, "Benchmark runner should attribute static minimap redraws")
	TEST_UTILS.expect_equal(int(render_pressure.get("minimap_dynamic_redraw_count", 0)), 3, failures, "Benchmark runner should attribute dynamic minimap redraws")
	TEST_UTILS.expect_equal(int(resource_render_mode.get("render_only_resources", 0)), 2, failures, "Benchmark runner should capture render-only resource counts")
	TEST_UTILS.expect_equal(int(resource_render_mode.get("render_only_grass", 0)), 2, failures, "Benchmark runner should capture render-only grass counts")
	TEST_UTILS.expect_equal(int(resource_render_mode.get("active_resource_collisions", 0)), 1, failures, "Benchmark runner should capture active resource collision counts")
	TEST_UTILS.expect_equal(int(minimap_stats.get("texture_build_count", 0)), 7, failures, "Benchmark runner should capture minimap texture build counts")
	TEST_UTILS.expect_equal(int(map_screen_stats.get("texture_build_count", 0)), 10, failures, "Benchmark runner should capture map screen texture build counts")
	TEST_UTILS.expect_equal(int(minimap_stats.get("minimap_marker_cache_check_count", 0)), 4, failures, "Benchmark runner should capture minimap marker cache checks")
	TEST_UTILS.expect_equal(int(minimap_stats.get("minimap_shoreline_check_count", 0)), 2, failures, "Benchmark runner should capture minimap shoreline checks")
	TEST_UTILS.expect_equal(int(minimap_stats.get("minimap_queue_player_redraw_count", 0)), 3, failures, "Benchmark runner should capture minimap player redraw queue counts")
	TEST_UTILS.expect_equal(int(map_screen_stats.get("map_screen_marker_cache_check_count", 0)), 6, failures, "Benchmark runner should capture map screen marker cache checks")
	TEST_UTILS.expect_equal(int(map_screen_stats.get("map_screen_shoreline_build_count", 0)), 1, failures, "Benchmark runner should capture map screen shoreline builds")
	TEST_UTILS.expect_equal(int(Dictionary(ai_stats.get("small_prey", {})).get("total_decisions", 0)), 12, failures, "Benchmark runner should capture small prey AI decision counts")
	TEST_UTILS.expect_equal(int(Dictionary(ai_stats.get("grazer", {})).get("total_decisions", 0)), 6, failures, "Benchmark runner should capture grazer AI decision counts")
	TEST_UTILS.expect_equal(int(Dictionary(ai_stats.get("varnak", {})).get("total_decisions", 0)), 9, failures, "Benchmark runner should capture Varnak AI decision counts")
	for resource in fake_world.resources:
		resource.free()
	small_prey.queue_free()
	grazer.queue_free()
	varnak.queue_free()


func _test_benchmark_runner_formats_diagnostics_into_text_log(failures: Array[String]) -> void:
	var runner := BENCHMARK_RUNNER.new()
	var sample := {
		"time_label": "00:10",
		"likely_driver": "render",
		"likely_render_subsystem": "terrain_surface_chunk_draw_ms",
		"likely_render_subsystem_reason": "highest avg/max render attribution in sample window",
		"load_score": 123.4,
		"render_attribution": {
			"enabled": true,
			"window_seconds": 1.0,
			"top_subsystem": "terrain_surface_chunk_draw_ms",
			"top_subsystem_avg_ms": 4.25,
			"top_subsystem_max_ms": 7.75,
			"samples_with_render_attribution": 3,
			"subsystems": {
				"terrain_surface_chunk_draw_ms": {
					"avg": 4.25,
					"max": 7.75,
					"count": 3
				}
			},
			"benchmark_sample_collection_ms": 0.18
		},
		"performance": {
			"fps": 12,
			"frame_time_s": 0.02,
			"physics_time_s": 0.01,
			"draw_calls": 900,
			"render_primitives": 21000,
			"node_count": 700,
			"window_focused": true
		},
		"world": {
			"total_creatures": 3,
			"total_resources": 10,
			"creatures_out_of_bounds_count": 0,
			"current_biome": "Westwood",
			"world_rect": "Rect2(0, 0, 100, 100)",
			"boot": {
				"ready": false,
				"progress": 0.94,
				"stage_message": "Rendering world..."
			},
			"biome_texture_cache": {
				"textures_enabled": true,
				"has_blend_texture": true,
				"blend_texture_size": "Vector2i(384, 236)",
				"accent_cache_count": 5,
				"pending_biomes": 0,
				"build_running": false,
				"sample_image_cache_count": 5,
				"blend_colors_key_length": 6
			},
			"landmark_debug": {
				"generated": 3,
				"pond": 1,
				"hill": 2
			},
			"registry": {
				"registered_resources": 3,
				"registered_buildings": 1
			},
			"render_flags": {
				"low_end_rendering": true,
				"biome_textures_enabled": true,
				"landmark_debug_overlay_enabled": false,
				"biome_terrain_accents_enabled": false
			},
			"visibility_culling": {
				"enabled": true,
				"interval_seconds": 0.35,
				"margin": 384.0,
				"visible_resources": 3,
				"hidden_resources": 8,
				"visible_creatures": 2,
				"hidden_creatures": 6
			},
			"resource_render_mode": {
				"render_only_resources": 2,
				"render_only_grass": 2,
				"active_resource_collisions": 1
			},
			"vegetation": {
				"decorative_grass_node_count": 11,
				"decorative_vegetation_visual_instance_count": 22,
				"decorative_vegetation_total_instance_count": 33,
				"decorative_vegetation_drawn_instance_count": 18,
				"decorative_vegetation_visible_chunk_count": 4,
				"edible_vegetation_node_count": 4,
				"interactive_resource_node_count": 6
			},
			"terrain_renderer": {
				"terrain_surface_chunk_visible_count": 9,
				"terrain_surface_chunk_cached_count": 12,
				"terrain_surface_chunk_pending_count": 2,
				"terrain_surface_chunks_built_last_frame": 1,
				"terrain_chunk_count_visible": 4,
				"terrain_chunk_drawn_cell_count": 128,
				"biome_shape_renderer_drawn_polygon_count": 5,
				"biome_shape_renderer_drawn_detail_count": 17
			}
		},
		"minimap": {
			"redraw_count": 4,
			"static_redraw_count": 1,
			"dynamic_redraw_count": 3,
			"player_marker_redraw_count": 3,
			"static_cache_rebuild_count": 8,
			"marker_cache_rebuild_count": 5,
			"landmark_cache_rebuild_count": 6,
			"texture_build_count": 7,
			"texture_last_build_ms": 3.5
		},
		"map_screen": {
			"redraw_count": 8,
			"cache_rebuild_count": 9,
			"skipped_update_hidden_count": 2,
			"texture_build_count": 10,
			"texture_last_build_ms": 4.5
		},
		"ai_decisions": {
			"small_prey": {"count": 2, "total_decisions": 12, "average_decisions_per_entity": 6.0},
			"grazer": {"count": 1, "total_decisions": 6, "average_decisions_per_entity": 6.0},
			"varnak": {"count": 1, "total_decisions": 9, "average_decisions_per_entity": 9.0}
		}
	}
	var line := str(runner.call("_format_sample_diagnostics", sample))
	var sample_line := str(runner.call("_format_sample_line", sample))
	TEST_UTILS.expect(line.contains("boot=loading 94%"), failures, "Benchmark runner diagnostics should include boot progress")
	TEST_UTILS.expect(line.contains("textures=on blend=yes"), failures, "Benchmark runner diagnostics should include biome texture cache state")
	TEST_UTILS.expect(line.contains("flags low_end=true biome_textures=true landmark_overlay=false biome_terrain_accents=false"), failures, "Benchmark runner diagnostics should include low-end render flags")
	TEST_UTILS.expect(line.contains("culling enabled=true visible_resources=3 hidden_resources=8 visible_creatures=2 hidden_creatures=6"), failures, "Benchmark runner diagnostics should include visibility culling counts")
	TEST_UTILS.expect(line.contains("resource_render_mode render_only_resources=2 render_only_grass=2 active_resource_collisions=1"), failures, "Benchmark runner diagnostics should include render-only resource mode counts")
	TEST_UTILS.expect(line.contains("registry resources=3 buildings=1"), failures, "Benchmark runner diagnostics should include registry totals")
	TEST_UTILS.expect(line.contains("terrain surface_visible=9 surface_cached=12 surface_pending=2 surface_built=1 cell_visible=4 cell_drawn=128 shape_polygons=5 shape_details=17"), failures, "Benchmark runner diagnostics should include terrain renderer attribution")
	TEST_UTILS.expect(line.contains("render_attribution top=terrain_surface_chunk_draw_ms avg=4.25 max=7.75 sample_ms=0.18"), failures, "Benchmark runner diagnostics should include render attribution summary")
	TEST_UTILS.expect(line.contains("render_likely subsystem=terrain_surface_chunk_draw_ms reason=highest avg/max render attribution in sample window"), failures, "Benchmark runner diagnostics should include likely render subsystem text")
	TEST_UTILS.expect(line.contains("minimap redraw=4 static=1 dynamic=3 player=3 static_cache=8 marker_cache=5 landmark_cache=6 texture_builds=7 last_build_ms=3.50"), failures, "Benchmark runner diagnostics should include minimap metrics")
	TEST_UTILS.expect(line.contains("checks=4/3 shoreline=2/1 queue=1/3/3 dirty=false/false/false/false/false"), failures, "Benchmark runner diagnostics should include minimap cache counters")
	TEST_UTILS.expect(line.contains("map_screen redraw=8 cache=9 skipped_hidden=2 texture_builds=10 last_build_ms=4.50"), failures, "Benchmark runner diagnostics should include map screen metrics")
	TEST_UTILS.expect(line.contains("checks=6/4 shoreline=5/4"), failures, "Benchmark runner diagnostics should include map screen cache counters")
	TEST_UTILS.expect(line.contains("ai small_prey=2/12 avg=6.0 grazer=1/6 avg=6.0 varnak=1/9 avg=9.0"), failures, "Benchmark runner diagnostics should include AI decision counts")
	TEST_UTILS.expect(line.contains("world biome=Westwood rect=Rect2(0, 0, 100, 100) total_resources=10 total_creatures=3 oob=0"), failures, "Benchmark runner diagnostics should include world summary metrics")
	TEST_UTILS.expect(sample_line.contains("focused=true"), failures, "Benchmark runner sample lines should report whether the game window had focus")


func _test_benchmark_runner_formats_threshold_validation_into_text_log(failures: Array[String]) -> void:
	var runner := BENCHMARK_RUNNER.new()
	var report := {
		"average_fps": 99.72,
		"max_frame_time_ms": 18.5,
		"realtime_hitch_count": 0,
		"max_realtime_delta_ms": 0,
		"heaviest_sample": {},
		"top_samples": [],
		"samples": [
			{
				"performance": {
					"node_count": 1022
				},
				"world": {
					"resource_render_mode": {
						"active_resource_collisions": 28
					},
					"biome_texture_cache": {
						"world_biome_texture_build_count": 1
					}
				},
				"minimap": {
					"texture_build_count": 0
				},
				"map_screen": {
					"texture_build_count": 1
				}
			}
		],
		"threshold_validation": {
			"status": "passed",
			"fail_on_regression": false,
			"metrics": {
				"average_fps": 99.72,
				"max_frame_time_ms": 18.5,
				"realtime_hitch_count": 0,
				"max_realtime_delta_ms": 0,
				"minimap_texture_build_count": 0,
				"map_screen_texture_build_count": 1,
				"world_biome_texture_build_count": 1,
				"active_resource_collisions": 28,
				"node_count": 1022
			},
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
			},
			"violations": [],
			"warnings": [],
			"missing_metrics": []
		}
	}
	var text := str(runner.call("_format_threshold_validation_text", report))
	TEST_UTILS.expect(text.contains("Threshold validation: PASSED"), failures, "Benchmark runner should report a passed threshold validation state")
	TEST_UTILS.expect(text.contains("- average_fps: 99.72 >= 50 OK"), failures, "Benchmark runner should include threshold comparison lines")
	TEST_UTILS.expect(text.contains("Fail on regression: false"), failures, "Benchmark runner should include the fail-on-regression flag")


func _test_benchmark_runner_records_at_most_one_sample_per_frame(failures: Array[String]) -> void:
	var runner := CountingBenchmarkRunner.new()
	runner.running = true
	runner.start_ticks_usec = Time.get_ticks_usec()
	runner.sample_timer = 3.2
	runner.elapsed_seconds = 12.0
	runner._process(0.0)
	TEST_UTILS.expect_equal(runner.record_calls, 1, failures, "Benchmark runner should record at most one sample per frame even after a hitch")


func _test_benchmark_runner_captures_realtime_hitch_summary(failures: Array[String]) -> void:
	var runner := BENCHMARK_RUNNER.new()
	runner.realtime_hitch_count = 2
	runner.max_realtime_delta_ms = 612
	runner.realtime_hitches = [
		{
			"elapsed_seconds": 1.0,
			"realtime_delta_ms": 612,
			"engine_delta_ms": 16.0,
			"sample_count": 8,
			"sample_timer": 0.2,
			"world_debug": {}
		}
	]
	runner.samples = [
		{
			"performance": {
				"fps": 60,
				"frame_time_s": 0.016,
				"physics_time_s": 0.006,
				"draw_calls": 300,
				"render_primitives": 12000,
				"node_count": 200,
				"window_focused": true
			},
			"world": {
				"total_creatures": 2,
				"total_resources": 3,
				"creatures_out_of_bounds_count": 0
			},
			"load_score": 1.0
		}
	]
	var report: Dictionary = runner.call("_build_report")
	TEST_UTILS.expect_equal(int(report.get("realtime_hitch_count", 0)), 2, failures, "Benchmark report should include the realtime hitch count")
	TEST_UTILS.expect_equal(int(report.get("max_realtime_delta_ms", 0)), 612, failures, "Benchmark report should include the max realtime hitch delta")
	TEST_UTILS.expect_equal(Array(report.get("realtime_hitches", [])).size(), 1, failures, "Benchmark report should include realtime hitch samples")


func _test_benchmark_runner_defaults_realtime_hitch_count_to_zero(failures: Array[String]) -> void:
	var runner := BENCHMARK_RUNNER.new()
	var report: Dictionary = runner.call("_build_report")
	TEST_UTILS.expect_equal(int(report.get("realtime_hitch_count", -1)), 0, failures, "Benchmark report should default realtime hitch count to zero")


func _test_benchmark_runner_opens_map_screen_for_map_open_preset(failures: Array[String]) -> void:
	var runner := BENCHMARK_RUNNER.new()
	var fake_world := FakeWorld.new()
	var fake_hud := FakeHud.new()
	var fake_minimap := FakeMinimap.new()
	var fake_map_screen := FakeMapScreen.new()
	var scene := Node.new()
	scene.name = "BenchmarkScene"
	scene.add_child(fake_world)
	fake_world.name = "World"
	scene.add_child(fake_hud)
	fake_hud.name = "HUD"
	fake_hud.add_child(fake_minimap)
	fake_minimap.name = "Minimap"
	fake_hud.add_child(fake_map_screen)
	fake_map_screen.name = "MapScreen"
	var player := Node2D.new()
	player.name = "Player"
	scene.add_child(player)
	var evo := Node.new()
	evo.name = "EvolutionDirector"
	scene.add_child(evo)
	var day_night := Node.new()
	day_night.name = "DayNightSystem"
	scene.add_child(day_night)
	var ecosystem := Node.new()
	ecosystem.name = "EcosystemDirector"
	scene.add_child(ecosystem)
	runner.scene = scene
	runner.world = fake_world
	runner.hud = fake_hud
	runner.minimap = fake_minimap
	runner.map_screen = fake_map_screen
	runner.player = player
	runner.evolution_director = evo
	runner.day_night_system = day_night
	runner.ecosystem_director = ecosystem
	TEST_UTILS.expect_equal(bool(runner.call("_open_map_screen_for_benchmark")), true, failures, "Benchmark runner should support the map-open benchmark scenario")
	TEST_UTILS.expect_equal(fake_hud.map_open_requests, 1, failures, "Map-open benchmark preset should request the HUD to open the map")
	TEST_UTILS.expect_equal(fake_hud.last_map_open_state, true, failures, "Map-open benchmark preset should open the map")


func _test_benchmark_runner_captures_ecosystem_and_spawn_debug(failures: Array[String]) -> void:
	var runner := BENCHMARK_RUNNER.new()
	var fake_world := FakeWorld.new()
	runner.world = fake_world
	var stats: Dictionary = runner.call("_capture_world_stats_deep")
	TEST_UTILS.expect_equal(str(stats.get("ecosystem_state_source", "")), "generated", failures, "Benchmark runner should capture ecosystem state source")
	var spawn_debug: Dictionary = Dictionary(stats.get("resource_spawn_rejection_debug", {}))
	TEST_UTILS.expect_equal(int(Dictionary(spawn_debug.get("tree", {})).get("blocked_by_water", 0)), 3, failures, "Benchmark runner should capture resource spawn rejection debug")
