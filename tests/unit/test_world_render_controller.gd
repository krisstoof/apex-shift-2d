extends RefCounted

const WORLD_RENDER_CONTROLLER := preload("res://scripts/world/world_render_controller.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_render_controller_tracks_redraw_timing_and_blend_cache(failures)
	return failures


func _test_render_controller_tracks_redraw_timing_and_blend_cache(failures: Array[String]) -> void:
	var controller := WORLD_RENDER_CONTROLLER.new()
	controller.bind_world(
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		func() -> Array:
			return [{
				"id": "biome_alpha",
				"points": PackedVector2Array([
					Vector2.ZERO,
					Vector2(100.0, 0.0),
					Vector2(100.0, 100.0),
					Vector2(0.0, 100.0)
				])
			}],
		func() -> String:
			return "test:1",
		func(position: Vector2, _biome_zones: Array) -> Color:
			return Color(position.x / 100.0, position.y / 100.0, 0.5, 1.0)
	)
	var initial_status := controller.get_biome_texture_cache_status()
	TEST_UTILS.expect_equal(bool(initial_status.get("has_texture", false)), false, failures, "Render controller should start without a cached blend texture")
	var texture := controller.ensure_biome_blend_texture()
	TEST_UTILS.expect(texture != null, failures, "Render controller should build a biome blend texture on demand")
	var cached_status := controller.get_biome_texture_cache_status()
	TEST_UTILS.expect_equal(bool(cached_status.get("has_texture", false)), true, failures, "Render controller should report a cached blend texture after building it")
	TEST_UTILS.expect_equal(str(cached_status.get("colors_key", "")), "test:1", failures, "Render controller should cache the biome color key")
	TEST_UTILS.expect(not controller.process(0.10, 0.0), failures, "Render controller should not request redraw before the interval elapses")
	TEST_UTILS.expect(controller.process(0.11, 0.0), failures, "Render controller should request redraw when the redraw interval elapses")
	TEST_UTILS.expect(not controller.process(0.05, 0.0), failures, "Render controller should reset its redraw timer after requesting redraw")
	controller.invalidate_biome_blend_texture()
	var reset_status := controller.get_biome_texture_cache_status()
	TEST_UTILS.expect_equal(bool(reset_status.get("has_texture", false)), false, failures, "Render controller should clear the cached texture when invalidated")
