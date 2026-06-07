extends RefCounted

const WORLD_RENDER_CONTROLLER := preload("res://scripts/world/world_render_controller.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


class MutableBiomeSource:
	extends RefCounted

	var current_key := "test:1"

	func get_biome_zones() -> Array:
		return [{
			"id": "biome_alpha",
			"points": PackedVector2Array([
				Vector2.ZERO,
				Vector2(100.0, 0.0),
				Vector2(100.0, 100.0),
				Vector2(0.0, 100.0)
			])
		}]

	func get_biome_colors_key() -> String:
		return current_key

	func get_biome_surface_color(position: Vector2, _biome_zones: Array) -> Color:
		return Color(position.x / 100.0, position.y / 100.0, 0.5, 1.0)


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_render_controller_tracks_redraw_timing_and_blend_cache(failures)
	return failures


func _test_render_controller_tracks_redraw_timing_and_blend_cache(failures: Array[String]) -> void:
	var source := MutableBiomeSource.new()
	var controller := WORLD_RENDER_CONTROLLER.new()
	controller.bind_world(
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		Callable(source, "get_biome_zones"),
		Callable(source, "get_biome_colors_key"),
		Callable(source, "get_biome_surface_color")
	)
	var initial_status := controller.get_biome_texture_cache_status()
	TEST_UTILS.expect_equal(bool(initial_status.get("has_texture", false)), false, failures, "Render controller should start without a cached blend texture")
	TEST_UTILS.expect_equal(bool(initial_status.get("freeze_after_first_build", false)), true, failures, "Render controller should freeze blend texture rebuilds after the first build")
	var texture := controller.ensure_biome_blend_texture()
	TEST_UTILS.expect(texture != null, failures, "Render controller should build a biome blend texture on demand")
	var cached_status := controller.get_biome_texture_cache_status()
	TEST_UTILS.expect_equal(bool(cached_status.get("has_texture", false)), true, failures, "Render controller should report a cached blend texture after building it")
	TEST_UTILS.expect_equal(str(cached_status.get("colors_key", "")), "test:1", failures, "Render controller should cache the biome color key")
	TEST_UTILS.expect_equal(int(cached_status.get("rebuild_count", 0)), 1, failures, "Render controller should count the first biome texture build")
	source.current_key = "test:2"
	var blocked_texture := controller.ensure_biome_blend_texture()
	TEST_UTILS.expect(blocked_texture == texture, failures, "Render controller should reuse the existing biome texture when the cache is frozen")
	var blocked_status := controller.get_biome_texture_cache_status()
	TEST_UTILS.expect_equal(int(blocked_status.get("rebuild_count", 0)), 1, failures, "Render controller should not rebuild the blend texture after the key changes")
	TEST_UTILS.expect_equal(int(blocked_status.get("rebuild_blocked_count", 0)), 1, failures, "Render controller should count blocked rebuild attempts")
	TEST_UTILS.expect_equal(bool(blocked_status.get("dirty_key_pending", false)), true, failures, "Render controller should remember the pending dirty key after blocking a rebuild")
	TEST_UTILS.expect_equal(str(blocked_status.get("colors_key", "")), "test:1", failures, "Render controller should keep the last built color key while rebuilds are frozen")
	var forced_texture := controller.force_rebuild_biome_blend_texture()
	TEST_UTILS.expect(forced_texture != null, failures, "Render controller should allow a manual force rebuild")
	var forced_status := controller.get_biome_texture_cache_status()
	TEST_UTILS.expect_equal(int(forced_status.get("rebuild_count", 0)), 2, failures, "Render controller should count the forced rebuild")
	TEST_UTILS.expect_equal(bool(forced_status.get("dirty_key_pending", true)), false, failures, "Render controller should clear the dirty key after a forced rebuild")
	TEST_UTILS.expect_equal(str(forced_status.get("colors_key", "")), "test:2", failures, "Render controller should update the cached color key after a forced rebuild")
	TEST_UTILS.expect(not controller.process(0.10, 0.0), failures, "Render controller should not request redraw before the interval elapses")
	TEST_UTILS.expect(controller.process(0.11, 0.0), failures, "Render controller should request redraw when the redraw interval elapses")
	TEST_UTILS.expect(not controller.process(0.05, 0.0), failures, "Render controller should reset its redraw timer after requesting redraw")
	controller.invalidate_biome_blend_texture()
	var reset_status := controller.get_biome_texture_cache_status()
	TEST_UTILS.expect_equal(bool(reset_status.get("has_texture", false)), false, failures, "Render controller should clear the cached texture when invalidated")
