extends RefCounted

const BENCHMARK_RUNNER := preload("res://scripts/systems/benchmark_runner.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


class FakeWorld extends Node:

	var landmarks: Array[Dictionary] = [
		{"type": "pond"},
		{"type": "hill"},
		{"type": "hill"}
	]

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
			"blend_colors_key": "abc123"
		}

	func get_landmark_counts() -> Dictionary:
		return {"generated": 3, "pond": 1, "hill": 2}

	func get_registered_resources() -> Array:
		return [Node.new(), Node.new(), Node.new()]

	func get_registered_buildings() -> Array:
		return [Node.new()]

	func are_biome_textures_enabled() -> bool:
		return true

	func is_landmark_debug_overlay_enabled() -> bool:
		return false

	func get_cached_group_nodes(group_name: String) -> Array:
		match group_name:
			"small_prey":
				return [Node.new(), Node.new()]
			"grazer":
				return [Node.new()]
			"varnak":
				return []
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
		return []


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_benchmark_runner_captures_world_diagnostics(failures)
	_test_benchmark_runner_formats_diagnostics_into_text_log(failures)
	return failures


func _test_benchmark_runner_captures_world_diagnostics(failures: Array[String]) -> void:
	var runner := BENCHMARK_RUNNER.new()
	runner.world = FakeWorld.new()
	var player := Node2D.new()
	player.global_position = Vector2.ZERO
	runner.player = player
	var stats: Dictionary = runner.call("_capture_world_stats")
	var boot: Dictionary = Dictionary(stats.get("boot", {}))
	var texture_cache: Dictionary = Dictionary(stats.get("biome_texture_cache", {}))
	var registry: Dictionary = Dictionary(stats.get("registry", {}))
	var render_flags: Dictionary = Dictionary(stats.get("render_flags", {}))
	TEST_UTILS.expect_equal(str(boot.get("stage_message", "")), "Rendering world...", failures, "Benchmark runner should capture the current world boot stage")
	TEST_UTILS.expect_close(float(boot.get("progress", 0.0)), 0.94, failures, "Benchmark runner should capture the current world boot progress")
	TEST_UTILS.expect(texture_cache.get("has_blend_texture", false) == true, failures, "Benchmark runner should capture whether the world blend texture cache exists")
	TEST_UTILS.expect_equal(int(texture_cache.get("accent_cache_count", 0)), 5, failures, "Benchmark runner should capture biome accent cache size")
	TEST_UTILS.expect_equal(int(registry.get("registered_resources", 0)), 3, failures, "Benchmark runner should capture registered resource totals")
	TEST_UTILS.expect(render_flags.get("biome_textures_enabled", false) == true, failures, "Benchmark runner should capture whether biome textures are enabled")


func _test_benchmark_runner_formats_diagnostics_into_text_log(failures: Array[String]) -> void:
	var runner := BENCHMARK_RUNNER.new()
	var sample := {
		"time_label": "00:10",
		"likely_driver": "render",
		"load_score": 123.4,
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
				"biome_textures_enabled": true,
				"landmark_debug_overlay_enabled": false
			}
		}
	}
	var line := str(runner.call("_format_sample_diagnostics", sample))
	var sample_line := str(runner.call("_format_sample_line", sample))
	TEST_UTILS.expect(line.contains("boot=loading 94%"), failures, "Benchmark runner diagnostics should include boot progress")
	TEST_UTILS.expect(line.contains("textures=on blend=yes"), failures, "Benchmark runner diagnostics should include biome texture cache state")
	TEST_UTILS.expect(line.contains("registry resources=3 buildings=1"), failures, "Benchmark runner diagnostics should include registry totals")
	TEST_UTILS.expect(sample_line.contains("focused=true"), failures, "Benchmark runner sample lines should report whether the game window had focus")
