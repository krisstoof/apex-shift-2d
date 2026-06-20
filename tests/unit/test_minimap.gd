extends RefCounted

const MINIMAP_SCRIPT := preload("res://scripts/ui/minimap.gd")
const MAP_SCREEN_SCRIPT := preload("res://scripts/ui/map_screen.gd")
const RESOURCE_MARKER_ICONS := preload("res://scripts/ui/resource_marker_icons.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


class CountingMinimap:
	extends MINIMAP_SCRIPT

	var ensure_calls := 0

	func _ensure_biome_texture() -> void:
		ensure_calls += 1


class MarkerChangedMinimap:
	extends MINIMAP_SCRIPT

	var static_dirty_calls := 0
	var dynamic_redraw_calls := 0

	func _refresh_landmarks_from_world() -> bool:
		return false

	func _update_marker_cache() -> bool:
		return true

	func _mark_static_layer_dirty() -> void:
		static_dirty_calls += 1

	func _request_dynamic_redraw() -> void:
		dynamic_redraw_calls += 1


class StableCacheMinimap:
	extends MINIMAP_SCRIPT

	var static_dirty_calls := 0
	var dynamic_redraw_calls := 0

	func _refresh_landmarks_from_world() -> bool:
		return false

	func _update_marker_cache() -> bool:
		return false

	func _mark_static_layer_dirty() -> void:
		static_dirty_calls += 1

	func _request_dynamic_redraw() -> void:
		dynamic_redraw_calls += 1


class MockResource:
	extends Node2D
	var resource_kind := "berry_bush"
	var item_name := "berries"
	var player_harvestable := true


class MockVarnak:
	extends Node2D


class MockWorld:
	extends Node
	var registered_resources: Array = []
	var registered_varnaks: Array = []
	var surface_texture := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	var surface_texture_key := "shared-surface"

	func get_registered_resources() -> Array:
		return registered_resources

	func get_registered_creatures_by_type(creature_type: String) -> Array:
		if creature_type == "varnak":
			return registered_varnaks
		return []

	func get_landmarks() -> Array[Dictionary]:
		return []

	func get_surface_texture() -> ImageTexture:
		return surface_texture

	func get_surface_texture_key() -> String:
		return surface_texture_key


class MockSnapshotService:
	extends RefCounted
	var snapshot := {}

	func get_snapshot() -> Dictionary:
		return snapshot

	func refresh(_force := false) -> Dictionary:
		return snapshot


class ShapeMapNoUnderlayStub:
	extends RefCounted

	var sample_grid_size_calls := 0
	var sample_grid_cell_world_rect_calls := 0

	func has_renderable_polygons() -> bool:
		return true

	func get_polygons_by_layer() -> Dictionary:
		return {
			"biome:test|terrain:land": [
				{
					"biome_id": "test_biome",
					"terrain_id": "land",
					"points": PackedVector2Array([Vector2.ZERO, Vector2(64.0, 0.0), Vector2(0.0, 64.0)])
				}
			]
		}

	func get_sample_grid_size() -> Vector2i:
		sample_grid_size_calls += 1
		return Vector2i(4, 4)

	func get_sample_grid_cell_world_rect(_x: int, _y: int) -> Rect2:
		sample_grid_cell_world_rect_calls += 1
		return Rect2(Vector2.ZERO, Vector2(16.0, 16.0))

	func get_sample_grid_cell(_x: int, _y: int) -> Dictionary:
		return {"biome_id": "test_biome", "terrain_id": "land"}


class GraphicsSettingsStub:
	extends Node
	var enabled := false

	func should_show_resource_markers_on_maps() -> bool:
		return enabled


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_minimap_view_rect_follows_player_and_stays_larger_than_camera(failures)
	_test_world_to_map_keeps_player_in_minimap_center(failures)
	_test_world_slice_maps_to_partial_texture_region(failures)
	_test_landmark_markers_stay_inside_minimap_content(failures)
	_test_minimap_reads_registry_resources_and_varnaks(failures)
	_test_minimap_builds_texture_outside_draw_path(failures)
	_test_minimap_shape_map_skips_sample_grid_underlay_when_polygons_exist(failures)
	_test_minimap_reuses_world_surface_texture_when_available(failures)
	_test_minimap_camera_world_size_scales_inversely_with_zoom(failures)
	_test_minimap_content_rect_reserves_footer_space(failures)
	_test_minimap_performance_debug_reports_layer_redraws(failures)
	_test_minimap_marker_cache_only_redraws_dynamic_layer(failures)
	_test_minimap_static_cache_stays_quiet_when_signatures_do_not_change(failures)
	_test_minimap_cached_view_rect_stays_stable_until_recentering(failures)
	_test_minimap_resource_markers_follow_graphics_setting(failures)
	_test_minimap_resource_marker_specs_are_icon_like_and_subtle(failures)
	_test_minimap_resource_marker_specs_share_common_icon_family(failures)
	_test_minimap_and_map_screen_share_resource_marker_contract(failures)
	return failures


func _test_minimap_view_rect_follows_player_and_stays_larger_than_camera(failures: Array[String]) -> void:
	var minimap := _make_minimap()
	var player := Node2D.new()
	player.global_position = Vector2(420.0, -180.0)
	minimap.player = player
	minimap.world_rect = Rect2(Vector2(-2000.0, -1200.0), Vector2(4000.0, 2400.0))
	minimap.camera_world_size_override = Vector2(960.0, 540.0)
	var content_rect := Rect2(Vector2.ZERO, Vector2(220.0, 140.0))
	var view_world_rect: Rect2 = minimap.call("_get_minimap_view_world_rect", content_rect)
	var camera_world_size: Vector2 = minimap.call("_get_player_camera_world_size")
	TEST_UTILS.expect_close(view_world_rect.get_center().x, player.global_position.x, failures, "Minimap view rect should follow the player's X position")
	TEST_UTILS.expect_close(view_world_rect.get_center().y, player.global_position.y, failures, "Minimap view rect should follow the player's Y position")
	TEST_UTILS.expect(view_world_rect.size.x > camera_world_size.x, failures, "Minimap should show a wider world slice than the current camera view")
	TEST_UTILS.expect(view_world_rect.size.y > camera_world_size.y, failures, "Minimap should show a taller world slice than the current camera view")
	minimap.free()
	player.free()


func _test_world_to_map_keeps_player_in_minimap_center(failures: Array[String]) -> void:
	var minimap := _make_minimap()
	var player := Node2D.new()
	player.global_position = Vector2(-640.0, 320.0)
	minimap.player = player
	minimap.world_rect = Rect2(Vector2(-2000.0, -1200.0), Vector2(4000.0, 2400.0))
	minimap.camera_world_size_override = Vector2(1280.0, 720.0)
	var content_rect := Rect2(Vector2(16.0, 12.0), Vector2(232.0, 152.0))
	var view_world_rect: Rect2 = minimap.call("_get_minimap_view_world_rect", content_rect)
	var player_map_position: Vector2 = minimap.call("_world_to_map", player.global_position, content_rect, view_world_rect)
	TEST_UTILS.expect_close(player_map_position.x, content_rect.get_center().x, failures, "Player marker should stay centered on the minimap horizontally")
	TEST_UTILS.expect_close(player_map_position.y, content_rect.get_center().y, failures, "Player marker should stay centered on the minimap vertically")
	minimap.free()
	player.free()


func _test_world_slice_maps_to_partial_texture_region(failures: Array[String]) -> void:
	var minimap := _make_minimap()
	minimap.world_rect = Rect2(Vector2(-2000.0, -1200.0), Vector2(4000.0, 2400.0))
	var partial_world_rect := Rect2(Vector2(-500.0, -300.0), Vector2(1000.0, 600.0))
	var texture_region: Rect2 = minimap.call("_world_rect_to_texture_region", partial_world_rect)
	TEST_UTILS.expect(texture_region.position.x > 0.0, failures, "A centered world slice should start inside the biome texture instead of always from the left edge")
	TEST_UTILS.expect(texture_region.position.y > 0.0, failures, "A centered world slice should start inside the biome texture instead of always from the top edge")
	TEST_UTILS.expect(texture_region.size.x < 192.0, failures, "A minimap slice should sample only part of the biome texture width")
	TEST_UTILS.expect(texture_region.size.y < 116.0, failures, "A minimap slice should sample only part of the biome texture height")
	minimap.free()


func _test_landmark_markers_stay_inside_minimap_content(failures: Array[String]) -> void:
	var minimap := _make_minimap()
	minimap.world_rect = Rect2(Vector2(-2000.0, -1200.0), Vector2(4000.0, 2400.0))
	minimap.camera_world_size_override = Vector2(1280.0, 720.0)
	var content_rect := Rect2(Vector2(14.0, 14.0), Vector2(232.0, 152.0))
	var view_world_rect := Rect2(Vector2(-400.0, -250.0), Vector2(900.0, 520.0))
	var pond_landmark := {
		"id": "test_pond",
		"type": "pond",
		"radius": 220.0
	}
	var hill_landmark := {
		"id": "test_hill",
		"type": "hill",
		"radius": 240.0
	}
	var pond_center: Vector2 = minimap.call("_get_landmark_marker_center", Vector2(view_world_rect.position.x - 120.0, 10.0), content_rect, view_world_rect)
	var pond_radius: float = minimap.call("_get_landmark_marker_radius", pond_center, 28.0, content_rect, pond_landmark)
	TEST_UTILS.expect_close(pond_center.x, content_rect.position.x, failures, "A pond marker center should clamp to the left edge of the minimap content when the landmark center is off-screen")
	TEST_UTILS.expect(pond_radius <= content_rect.get_center().distance_to(Vector2(content_rect.position.x, content_rect.get_center().y)), failures, "A pond marker radius should shrink instead of drawing outside the minimap content")
	var hill_center: Vector2 = minimap.call("_get_landmark_marker_center", Vector2(view_world_rect.end.x + 140.0, view_world_rect.end.y + 90.0), content_rect, view_world_rect)
	var hill_radius: float = minimap.call("_get_landmark_marker_radius", hill_center, 30.0, content_rect, hill_landmark)
	TEST_UTILS.expect_close(hill_center.x, content_rect.end.x, failures, "A hill marker center should clamp to the right edge of the minimap content when the landmark center is off-screen")
	TEST_UTILS.expect_close(hill_center.y, content_rect.end.y, failures, "A hill marker center should clamp to the bottom edge of the minimap content when the landmark center is off-screen")
	TEST_UTILS.expect(hill_radius <= 0.01, failures, "A hill marker with no room at the edge should collapse instead of spilling outside the minimap")
	minimap.free()


func _test_minimap_reads_registry_resources_and_varnaks(failures: Array[String]) -> void:
	var minimap := _make_minimap()
	var snapshot_service := MockSnapshotService.new()
	snapshot_service.snapshot = {
		"markers": {
			"resources": [{"position": Vector2(-180.0, 60.0), "item_name": "berries", "resource_kind": "berry_bush"}],
			"varnaks": [{"position": Vector2(220.0, -90.0), "type": "varnak"}]
		},
		"world": {
			"landmarks": []
		}
	}
	minimap.snapshot_service = snapshot_service
	minimap.call("_update_marker_cache")
	var cached_resources: Array = minimap.get("cached_resources")
	var registered_varnaks: Array = minimap.get("cached_varnaks")
	TEST_UTILS.expect_equal(cached_resources.size(), 1, failures, "Minimap should cache resource markers from WorldRegistry")
	TEST_UTILS.expect_equal(registered_varnaks.size(), 1, failures, "Minimap should read varnak markers from WorldRegistry")
	minimap.free()


func _test_minimap_builds_texture_outside_draw_path(failures: Array[String]) -> void:
	var minimap := _make_minimap()
	var player := Node2D.new()
	var biome_zones: Array[Dictionary] = [{
		"name": "Test Biome",
		"points": PackedVector2Array([
			Vector2(-200.0, -120.0),
			Vector2(200.0, -120.0),
			Vector2(200.0, 120.0),
			Vector2(-200.0, 120.0)
		]),
		"color": Color(0.2, 0.4, 0.2)
	}]
	var landmarks: Array[Dictionary] = []
	minimap.bind(player, Rect2(Vector2(-200.0, -120.0), Vector2(400.0, 240.0)), biome_zones, landmarks, MockSnapshotService.new())
	TEST_UTILS.expect_equal(minimap.get("minimap_texture_build_count"), 1, failures, "Minimap should build its biome texture outside _draw()")
	TEST_UTILS.expect(float(minimap.get("minimap_texture_last_build_ms")) >= 0.0, failures, "Minimap should track the last biome texture build time")
	minimap.free()
	player.free()

	var draw_spy := CountingMinimap.new()
	draw_spy.world_rect = Rect2(Vector2(-200.0, -120.0), Vector2(400.0, 240.0))
	draw_spy.set("biome_zones", biome_zones)
	draw_spy.set("biome_blend_texture", ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8)))
	draw_spy.set("biome_blend_colors_key", "test")
	var ensure_calls_before := draw_spy.ensure_calls
	draw_spy.call("_draw_biomes", draw_spy, Rect2(Vector2.ZERO, Vector2(160.0, 100.0)), Rect2(Vector2(-200.0, -120.0), Vector2(400.0, 240.0)))
	TEST_UTILS.expect_equal(draw_spy.ensure_calls, ensure_calls_before, failures, "Minimap draw path should reuse the cached biome texture instead of rebuilding it")
	draw_spy.free()


func _test_minimap_shape_map_skips_sample_grid_underlay_when_polygons_exist(failures: Array[String]) -> void:
	var minimap := _make_minimap()
	var shape_map := ShapeMapNoUnderlayStub.new()
	minimap.set("biome_shape_map", shape_map)
	minimap.set("terrain_cell_map", null)
	minimap.set("biome_zones", [])
	minimap.call("_draw_shape_map", minimap, Rect2(Vector2.ZERO, Vector2(160.0, 100.0)), Rect2(Vector2.ZERO, Vector2(160.0, 100.0)))
	TEST_UTILS.expect_equal(shape_map.sample_grid_size_calls, 0, failures, "Minimap should not draw the sample grid underlay when renderable polygons already exist")
	TEST_UTILS.expect_equal(shape_map.sample_grid_cell_world_rect_calls, 0, failures, "Minimap should not probe sample grid cells when renderable polygons already exist")
	minimap.free()


func _test_minimap_reuses_world_surface_texture_when_available(failures: Array[String]) -> void:
	var minimap := _make_minimap()
	var player := Node2D.new()
	var fake_world := MockWorld.new()
	minimap.set("player", player)
	minimap.set("world", fake_world)
	minimap.set("biome_zones", [{"name": "Test Biome", "points": PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE]), "color": Color(0.2, 0.4, 0.2)}])
	minimap.call("_sync_biome_texture")
	TEST_UTILS.expect_equal(minimap.get("biome_blend_texture"), fake_world.surface_texture, failures, "Minimap should reuse the shared world surface texture when it exists")
	TEST_UTILS.expect_equal(str(minimap.get("biome_blend_colors_key")), fake_world.surface_texture_key, failures, "Minimap should mirror the shared world surface texture key")
	minimap.free()
	player.free()
	fake_world.free()


func _test_minimap_camera_world_size_scales_inversely_with_zoom(failures: Array[String]) -> void:
	var minimap := _make_minimap()
	var player := Node2D.new()
	var camera := Camera2D.new()
	player.add_child(camera)
	minimap.player = player
	minimap.camera_world_size_override = Vector2.ZERO
	camera.zoom = Vector2(1.0, 1.0)
	var normal_size: Vector2 = minimap.call("_get_player_camera_world_size")
	camera.zoom = Vector2(2.0, 2.0)
	var closer_size: Vector2 = minimap.call("_get_player_camera_world_size")
	camera.zoom = Vector2(0.5, 0.5)
	var farther_size: Vector2 = minimap.call("_get_player_camera_world_size")
	TEST_UTILS.expect(closer_size.x < normal_size.x and closer_size.y < normal_size.y, failures, "Minimap camera world size should shrink when camera zoom increases")
	TEST_UTILS.expect(farther_size.x > normal_size.x and farther_size.y > normal_size.y, failures, "Minimap camera world size should grow when camera zoom decreases")
	minimap.free()
	player.free()


func _test_minimap_content_rect_reserves_footer_space(failures: Array[String]) -> void:
	var minimap := _make_minimap()
	var map_rect := Rect2(Vector2.ZERO, Vector2(260.0, 180.0))
	var content_rect: Rect2 = minimap.call("_get_content_rect", map_rect)
	TEST_UTILS.expect(content_rect.size.y < map_rect.size.y - 20.0, failures, "Minimap content rect should reserve room for the footer label")
	TEST_UTILS.expect(content_rect.end.y <= map_rect.end.y - 20.0, failures, "Minimap content rect should stop above the footer label")
	minimap.free()


func _test_minimap_performance_debug_reports_layer_redraws(failures: Array[String]) -> void:
	var minimap := _make_minimap()
	minimap.set("static_layer_redraw_count", 2)
	minimap.set("dynamic_layer_redraw_count", 5)
	minimap.set("player_marker_redraw_count", 5)
	minimap.set("static_cache_rebuild_count", 1)
	var debug: Dictionary = minimap.call("get_minimap_performance_debug")
	TEST_UTILS.expect_equal(int(debug.get("redraw_count", 0)), 7, failures, "Minimap debug should report combined layer redraws")
	TEST_UTILS.expect_equal(int(debug.get("static_redraw_count", 0)), 2, failures, "Minimap debug should expose static layer redraws")
	TEST_UTILS.expect_equal(int(debug.get("dynamic_redraw_count", 0)), 5, failures, "Minimap debug should expose dynamic layer redraws")
	TEST_UTILS.expect_equal(int(debug.get("player_marker_redraw_count", 0)), 5, failures, "Minimap debug should expose player marker redraws")
	TEST_UTILS.expect_equal(int(debug.get("static_cache_rebuild_count", 0)), 1, failures, "Minimap debug should expose static cache rebuilds")
	minimap.free()


func _test_minimap_marker_cache_only_redraws_dynamic_layer(failures: Array[String]) -> void:
	var minimap := MarkerChangedMinimap.new()
	minimap.set("shoreline_segments_cache_valid", true)
	minimap.set("shoreline_segments_key", str(minimap.call("_get_biome_texture_key")))
	minimap.call("_refresh_static_caches")
	TEST_UTILS.expect_equal(minimap.static_dirty_calls, 0, failures, "Marker cache changes should not dirty the static minimap layer")
	TEST_UTILS.expect_equal(minimap.dynamic_redraw_calls, 1, failures, "Marker cache changes should request a dynamic minimap redraw")
	TEST_UTILS.expect_equal(int(minimap.get("minimap_marker_cache_rebuild_count")), 1, failures, "Marker cache changes should still increment marker rebuild diagnostics")
	minimap.free()


func _test_minimap_static_cache_stays_quiet_when_signatures_do_not_change(failures: Array[String]) -> void:
	var minimap := StableCacheMinimap.new()
	minimap.set("shoreline_segments_cache_valid", true)
	minimap.set("shoreline_segments_key", str(minimap.call("_get_shoreline_cache_key")))
	minimap.set("landmarks_signature", minimap.call("_build_landmarks_signature"))
	minimap.call("_refresh_static_caches")
	TEST_UTILS.expect_equal(minimap.static_dirty_calls, 0, failures, "Unchanged minimap cache signatures should not dirty the static layer")
	TEST_UTILS.expect_equal(minimap.dynamic_redraw_calls, 0, failures, "Unchanged minimap cache signatures should not request a dynamic redraw")
	TEST_UTILS.expect_equal(int(minimap.get("minimap_marker_cache_skipped_unchanged_count")), 1, failures, "Unchanged marker signatures should increment the skipped counter")
	TEST_UTILS.expect_equal(int(minimap.get("minimap_shoreline_skipped_unchanged_count")), 1, failures, "Unchanged shoreline signatures should increment the skipped counter")
	minimap.free()


func _test_minimap_cached_view_rect_stays_stable_until_recentering(failures: Array[String]) -> void:
	var minimap := _make_minimap()
	var player := Node2D.new()
	player.global_position = Vector2(100.0, 80.0)
	minimap.player = player
	var content_rect := Rect2(Vector2(14.0, 14.0), Vector2(232.0, 152.0))
	var first_rect: Rect2 = minimap.call("_get_cached_minimap_view_world_rect", content_rect)
	player.global_position = Vector2(260.0, 210.0)
	var second_rect: Rect2 = minimap.call("_get_cached_minimap_view_world_rect", content_rect)
	TEST_UTILS.expect_equal(second_rect, first_rect, failures, "Minimap cached view rect should stay stable until recentering")
	minimap.call("_force_minimap_view_recenter", content_rect)
	var recentered_rect: Rect2 = minimap.call("_get_cached_minimap_view_world_rect", content_rect)
	TEST_UTILS.expect(recentered_rect.position.distance_to(player.global_position - recentered_rect.size * 0.5) < 0.01, failures, "Minimap cached view rect should recenter on the current player position")
	minimap.free()
	player.free()


func _test_minimap_resource_markers_follow_graphics_setting(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var previous_settings := tree.root.get_node_or_null("GraphicsSettings")
	if previous_settings != null:
		previous_settings.name = "LiveGraphicsSettings"
	var settings := GraphicsSettingsStub.new()
	settings.name = "GraphicsSettings"
	tree.root.add_child(settings)
	var minimap := _make_minimap()
	TEST_UTILS.expect_equal(minimap.call("_should_show_resource_markers"), false, failures, "Minimap should hide resource markers by default")
	settings.enabled = true
	TEST_UTILS.expect_equal(minimap.call("_should_show_resource_markers"), true, failures, "Minimap should respect the graphics toggle for resource markers")
	minimap.free()
	settings.queue_free()
	if previous_settings != null:
		previous_settings.name = "GraphicsSettings"


func _test_minimap_resource_marker_specs_are_icon_like_and_subtle(failures: Array[String]) -> void:
	var minimap := _make_minimap()
	var wood_spec: Dictionary = minimap.call("_get_resource_marker_render_spec", {"item_name": "wood"})
	var stone_spec: Dictionary = minimap.call("_get_resource_marker_render_spec", {"item_name": "stone"})
	var berry_spec: Dictionary = minimap.call("_get_resource_marker_render_spec", {"item_name": "berries"})
	TEST_UTILS.expect(float(wood_spec.get("radius", 0.0)) <= 2.5, failures, "Wood markers should stay icon-sized")
	TEST_UTILS.expect(float(stone_spec.get("radius", 0.0)) <= 2.5, failures, "Stone markers should stay icon-sized")
	TEST_UTILS.expect(float(berry_spec.get("radius", 0.0)) <= 2.5, failures, "Berry markers should stay icon-sized")
	TEST_UTILS.expect(float(wood_spec.get("fill_color", Color()).a) < 0.9, failures, "Resource markers should remain visually subdued")
	TEST_UTILS.expect(float(stone_spec.get("fill_color", Color()).a) < 0.9, failures, "Resource markers should remain visually subdued")
	TEST_UTILS.expect(float(berry_spec.get("fill_color", Color()).a) < 0.9, failures, "Resource markers should remain visually subdued")
	TEST_UTILS.expect(float(wood_spec.get("inner_radius", 0.0)) > 0.0, failures, "Wood markers should use a filled icon detail")
	TEST_UTILS.expect(float(stone_spec.get("cross_size", 0.0)) > 0.0, failures, "Stone markers should use a cross-like icon detail")
	TEST_UTILS.expect(float(berry_spec.get("inner_radius", 0.0)) > 0.0, failures, "Berry markers should use a compact inner dot")
	minimap.free()


func _test_minimap_resource_marker_specs_share_common_icon_family(failures: Array[String]) -> void:
	var minimap := _make_minimap()
	var specs: Array[Dictionary] = [
		minimap.call("_get_resource_marker_render_spec", {"item_name": "wood"}),
		minimap.call("_get_resource_marker_render_spec", {"item_name": "stone"}),
		minimap.call("_get_resource_marker_render_spec", {"item_name": "berries"}),
		minimap.call("_get_resource_marker_render_spec", {"item_name": "meat"}),
		minimap.call("_get_resource_marker_render_spec", {"item_name": "fiber"})
	]
	for spec in specs:
		TEST_UTILS.expect(float(spec.get("radius", 0.0)) >= 2.0 and float(spec.get("radius", 0.0)) <= 2.3, failures, "Resource markers should stay within the same compact icon family")
		TEST_UTILS.expect(float(Color(spec.get("fill_color")).a) <= 0.82, failures, "Resource markers should remain subdued across the family")
		TEST_UTILS.expect(float(Color(spec.get("outline_color")).a) >= 0.48, failures, "Resource markers should keep a consistent outline treatment")
	minimap.free()


func _test_minimap_and_map_screen_share_resource_marker_contract(failures: Array[String]) -> void:
	var minimap := _make_minimap()
	var map_screen := MAP_SCREEN_SCRIPT.new()
	var minimap_spec: Dictionary = minimap.call("_get_resource_marker_render_spec", {"item_name": "wood"})
	var map_spec: Dictionary = map_screen.call("_get_resource_marker_render_spec", {"item_name": "wood"})
	var helper_spec: Dictionary = RESOURCE_MARKER_ICONS.get_render_spec("wood")
	TEST_UTILS.expect_equal(float(minimap_spec.get("radius", 0.0)), float(map_spec.get("radius", 0.0)), failures, "Map panels should share the same resource marker radius")
	TEST_UTILS.expect_equal(float(minimap_spec.get("inner_radius", 0.0)), float(map_spec.get("inner_radius", 0.0)), failures, "Map panels should share the same resource marker inner detail")
	TEST_UTILS.expect_equal(float(Color(minimap_spec.get("fill_color")).a), float(Color(map_spec.get("fill_color")).a), failures, "Map panels should share the same resource marker alpha")
	TEST_UTILS.expect_equal(float(helper_spec.get("radius", 0.0)), float(minimap_spec.get("radius", 0.0)), failures, "Shared helper should match minimap icon radius")
	TEST_UTILS.expect_equal(float(helper_spec.get("radius", 0.0)), float(map_spec.get("radius", 0.0)), failures, "Shared helper should match map screen icon radius")
	minimap.free()
	map_screen.free()


func _make_minimap() -> Control:
	var minimap := MINIMAP_SCRIPT.new()
	minimap.size = Vector2(260.0, 180.0)
	return minimap
