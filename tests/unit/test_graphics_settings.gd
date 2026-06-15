extends RefCounted

const GRAPHICS_SETTINGS := preload("res://scripts/systems/graphics_settings.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_low_end_rendering_defaults_and_preset_application(failures)
	_test_indices_are_clamped_to_supported_values(failures)
	_test_borderless_mode_uses_desktop_resolution(failures)
	_test_exclusive_fullscreen_fits_current_screen(failures)
	_test_embedded_detection_uses_engine_runtime_state(failures)
	_test_embedded_preview_still_applies_content_resolution(failures)
	return failures


func _test_low_end_rendering_defaults_and_preset_application(failures: Array[String]) -> void:
	var settings := GRAPHICS_SETTINGS.new()
	TEST_UTILS.expect_equal(bool(settings.low_end_rendering), true, failures, "Low-end rendering should default to enabled for the prototype build")
	TEST_UTILS.expect_equal(bool(settings.low_end_static_surface_mode), true, failures, "Low-end rendering should default to static surface mode for emergency fallback")
	TEST_UTILS.expect_equal(bool(settings.get_default_biome_textures_enabled()), true, failures, "Low-end rendering should keep biome textures enabled")
	TEST_UTILS.expect_equal(bool(settings.get_default_landmark_debug_overlay_enabled()), false, failures, "Low-end rendering should disable the landmark debug overlay by default")
	TEST_UTILS.expect_equal(bool(settings.get_default_biome_terrain_accents_enabled()), false, failures, "Low-end rendering should disable biome terrain accents by default")
	settings.low_end_rendering = false
	settings.low_end_static_surface_mode = false
	settings.biome_textures_enabled = false
	settings.landmark_debug_overlay_enabled = true
	settings.biome_terrain_accents_enabled = true
	settings.apply_low_end_rendering_defaults()
	TEST_UTILS.expect_equal(bool(settings.low_end_rendering), true, failures, "Applying the low-end preset should force the low-end flag on")
	TEST_UTILS.expect_equal(bool(settings.low_end_static_surface_mode), true, failures, "Applying the low-end preset should force static surface mode on")
	TEST_UTILS.expect_equal(bool(settings.biome_textures_enabled), true, failures, "Applying the low-end preset should keep biome textures enabled")
	TEST_UTILS.expect_equal(bool(settings.landmark_debug_overlay_enabled), false, failures, "Applying the low-end preset should turn off the landmark debug overlay")
	TEST_UTILS.expect_equal(bool(settings.biome_terrain_accents_enabled), false, failures, "Applying the low-end preset should turn off biome terrain accents")
	settings.free()


func _test_indices_are_clamped_to_supported_values(failures: Array[String]) -> void:
	var settings := GRAPHICS_SETTINGS.new()
	settings.set_from_indices(999, -3)
	TEST_UTILS.expect_equal(settings.resolution_index, settings.get_resolution_count() - 1, failures, "Resolution index should clamp to the highest supported resolution")
	TEST_UTILS.expect_equal(settings.display_mode_index, settings.DISPLAY_MODE_WINDOWED, failures, "Display mode index should clamp to Windowed")
	settings.free()


func _test_borderless_mode_uses_desktop_resolution(failures: Array[String]) -> void:
	var settings := GRAPHICS_SETTINGS.new()
	TEST_UTILS.expect(settings.is_resolution_selectable(settings.DISPLAY_MODE_WINDOWED), failures, "Windowed mode should allow selecting a resolution")
	TEST_UTILS.expect(settings.is_resolution_selectable(settings.DISPLAY_MODE_FULLSCREEN), failures, "Exclusive fullscreen should allow selecting a resolution")
	TEST_UTILS.expect(not settings.is_resolution_selectable(settings.DISPLAY_MODE_BORDERLESS_FULLSCREEN), failures, "Borderless fullscreen should use the desktop resolution")
	settings.free()


func _test_exclusive_fullscreen_fits_current_screen(failures: Array[String]) -> void:
	var settings := GRAPHICS_SETTINGS.new()
	var fitted_resolution: Vector2i = settings._get_fullscreen_size_for_screen(Vector2i(2560, 1440), Vector2i(1920, 1200))
	TEST_UTILS.expect_equal(fitted_resolution, Vector2i(1920, 1080), failures, "Exclusive fullscreen should choose the largest preset supported by the current screen")
	var unchanged_resolution: Vector2i = settings._get_fullscreen_size_for_screen(Vector2i(1920, 1080), Vector2i(2560, 1440))
	TEST_UTILS.expect_equal(unchanged_resolution, Vector2i(1920, 1080), failures, "Supported exclusive fullscreen resolutions should remain unchanged")
	settings.free()


func _test_embedded_detection_uses_engine_runtime_state(failures: Array[String]) -> void:
	var script_text := FileAccess.get_file_as_string("res://scripts/systems/graphics_settings.gd")
	TEST_UTILS.expect(script_text.contains("return Engine.is_embedded_in_editor()"), failures, "Graphics settings should detect the editor-embedded game through Engine")
	TEST_UTILS.expect(not script_text.contains("display/window/subwindows/embed_subwindows"), failures, "Subwindow embedding must not disable main-window settings")


func _test_embedded_preview_still_applies_content_resolution(failures: Array[String]) -> void:
	var script_text := FileAccess.get_file_as_string("res://scripts/systems/graphics_settings.gd")
	var content_resolution_position := script_text.find("_apply_content_resolution(_resolution)")
	var embedded_guard_position := script_text.find("if is_embedded_window():", content_resolution_position)
	TEST_UTILS.expect(content_resolution_position >= 0, failures, "Graphics settings should still apply a logical content resolution hook")
	TEST_UTILS.expect(embedded_guard_position > content_resolution_position, failures, "Editor embedding should only skip physical window changes, not viewport resolution")
	TEST_UTILS.expect(script_text.contains("content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED"), failures, "Selected resolution should keep root viewport content scale disabled")
