extends RefCounted

const WORLD_SCRIPT := preload("res://scripts/world/world.gd")
const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_world_rect_matches_config(failures)
	_test_water_zone_detection_uses_pond_geometry(failures)
	_test_plant_resources_are_blocked_by_water(failures)
	_test_non_plant_resources_ignore_water_blocking(failures)
	_test_hills_block_navigation(failures)
	_test_terrain_speed_multiplier_changes_in_water(failures)
	_test_landmark_save_data_round_trip_vectors(failures)
	_test_world_save_data_includes_seed_and_landmark_fields(failures)
	_test_biomes_have_sample_texture_assets(failures)
	_test_biome_terrain_accent_layout_is_dense_and_inside_biome(failures)
	_test_biome_terrain_accent_layout_stays_async_when_queue_is_pending(failures)
	_test_biome_sample_texture_paths_match_biome_identity(failures)
	_test_biome_surface_color_uses_the_containing_biome_without_blending(failures)
	_test_biome_sample_texture_varies_with_position(failures)
	_test_redfang_wilds_sample_texture_has_drawn_cracks(failures)
	_test_landmark_debug_counts_and_nearest_selection(failures)
	_test_landmark_debug_toggles_flip_runtime_state(failures)
	_test_biome_texture_cache_status_reports_runtime_flags(failures)
	_test_current_biome_texture_id_uses_player_position_biome(failures)
	return failures


func _test_world_rect_matches_config(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	TEST_UTILS.expect_equal(world.get_world_rect(), WORLD_CONFIG.WORLD_RECT, failures, "World rectangle should match world config")
	world.free()


func _test_water_zone_detection_uses_pond_geometry(failures: Array[String]) -> void:
	var world := _make_world_with_single_pond()
	TEST_UTILS.expect_equal(world.get_water_zone(Vector2.ZERO), "deep_water", failures, "Pond center should be deep water")
	var shallow_point := _find_sample_point_for_zone(world, "shallow_water")
	TEST_UTILS.expect(shallow_point != Vector2.INF, failures, "The pond should expose at least one shallow-water sample point")
	if shallow_point != Vector2.INF:
		TEST_UTILS.expect_equal(world.get_water_zone(shallow_point), "shallow_water", failures, "A sampled mid-ring point should be shallow water")
	TEST_UTILS.expect_equal(world.get_water_zone(Vector2(160.0, 0.0)), "land", failures, "Outside the pond should be land")
	world.free()


func _test_plant_resources_are_blocked_by_water(failures: Array[String]) -> void:
	var world := _make_world_with_single_pond()
	TEST_UTILS.expect(world.is_resource_position_blocked_by_water("grass_patch", Vector2.ZERO), failures, "Plant resources should be blocked in pond water")
	TEST_UTILS.expect(world.is_resource_position_blocked_by_water("bush", Vector2(15.0, 0.0)), failures, "Bushes should be blocked in pond water")
	world.free()


func _test_non_plant_resources_ignore_water_blocking(failures: Array[String]) -> void:
	var world := _make_world_with_single_pond()
	TEST_UTILS.expect(not world.is_resource_position_blocked_by_water("rock", Vector2.ZERO), failures, "Rocks should ignore water blocking")
	TEST_UTILS.expect(not world.is_resource_position_blocked_by_water("meat_drop", Vector2.ZERO), failures, "Meat drops should ignore water blocking")
	world.free()


func _test_hills_block_navigation(failures: Array[String]) -> void:
	var world := _make_world_with_single_hill()
	TEST_UTILS.expect(world.is_creature_navigation_blocked(Vector2.ZERO), failures, "Hill centers should block navigation")
	TEST_UTILS.expect(not world.is_creature_navigation_blocked(Vector2(220.0, 0.0)), failures, "Positions far from the hill should remain navigable")
	world.free()


func _test_terrain_speed_multiplier_changes_in_water(failures: Array[String]) -> void:
	var world := _make_world_with_single_pond()
	var deep_speed: float = float(world.get_terrain_speed_multiplier(Vector2.ZERO))
	var shallow_point := _find_sample_point_for_zone(world, "shallow_water")
	var shallow_speed: float = float(world.get_terrain_speed_multiplier(shallow_point if shallow_point != Vector2.INF else Vector2(80.0, 0.0)))
	var land_speed: float = float(world.get_terrain_speed_multiplier(Vector2(160.0, 0.0)))
	TEST_UTILS.expect(deep_speed < shallow_speed, failures, "Deep water should slow movement more than shallow water")
	TEST_UTILS.expect(shallow_speed < land_speed, failures, "Shallow water should still slow movement more than land")
	world.free()


func _test_landmark_save_data_round_trip_vectors(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	world.landmarks = [{
		"id": "test_pond",
		"type": "pond",
		"position": Vector2(120.0, -90.0),
		"radius": 140.0,
		"biome_id": "westwood",
		"gameplay_tags": ["water_source"]
	}]
	var save_data: Array = world.get_landmark_save_data()
	TEST_UTILS.expect_equal(save_data.size(), 1, failures, "World should export landmark save data")
	if save_data.size() == 1:
		var exported := Dictionary(save_data[0])
		var position_data := Dictionary(exported.get("position", {}))
		TEST_UTILS.expect_close(float(position_data.get("x", 0.0)), 120.0, failures, "Landmark save data should preserve position X")
		TEST_UTILS.expect_close(float(position_data.get("y", 0.0)), -90.0, failures, "Landmark save data should preserve position Y")
	var restored: Array = world.call("_deserialize_landmark_save_data", save_data)
	TEST_UTILS.expect_equal(restored.size(), 1, failures, "World should deserialize landmark save data")
	if restored.size() == 1:
		var restored_landmark := Dictionary(restored[0])
		var restored_position := Vector2(restored_landmark.get("position", Vector2.ZERO))
		TEST_UTILS.expect_close(restored_position.x, 120.0, failures, "Deserialized landmark save data should restore position X")
		TEST_UTILS.expect_close(restored_position.y, -90.0, failures, "Deserialized landmark save data should restore position Y")
	world.free()


func _test_world_save_data_includes_seed_and_landmark_fields(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	world.world_seed = 2468
	world.landmarks = [{
		"id": "test_hill",
		"type": "hill",
		"position": Vector2(200.0, 150.0),
		"radius": 180.0,
		"biome_id": "stoneback_ridge",
		"gameplay_tags": ["high_ground", "rocky"]
	}]
	var save_data: Dictionary = world.get_save_data()
	TEST_UTILS.expect_equal(int(save_data.get("world_seed", 0)), 2468, failures, "World save data should include the generated world seed")
	var landmarks_data: Array = Array(save_data.get("landmarks", []))
	TEST_UTILS.expect_equal(landmarks_data.size(), 1, failures, "World save data should include the final landmark layout")
	if landmarks_data.size() == 1:
		var exported := Dictionary(landmarks_data[0])
		TEST_UTILS.expect_equal(str(exported.get("id", "")), "test_hill", failures, "World save data should preserve landmark ids")
		TEST_UTILS.expect_equal(str(exported.get("type", "")), "hill", failures, "World save data should preserve landmark types")
		TEST_UTILS.expect_equal(str(exported.get("biome_id", "")), "stoneback_ridge", failures, "World save data should preserve landmark biome ids")
		TEST_UTILS.expect_close(float(exported.get("radius", 0.0)), 180.0, failures, "World save data should preserve landmark radii")
		var gameplay_tags: Array = Array(exported.get("gameplay_tags", []))
		TEST_UTILS.expect_equal(gameplay_tags.size(), 2, failures, "World save data should preserve gameplay tags for restored landmarks")
	world.free()


func _test_biomes_have_sample_texture_assets(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	for biome_value in WORLD_CONFIG.get_biome_zones():
		var biome := Dictionary(biome_value)
		var texture_key := str(world.call("_get_biome_terrain_texture_key", biome))
		TEST_UTILS.expect(texture_key != "none", failures, "%s should have a terrain sample texture" % str(biome.get("name", "biome")))
		var pattern := Dictionary(world.call("_get_biome_terrain_pattern", biome))
		TEST_UTILS.expect(not pattern.is_empty(), failures, "%s should resolve to a terrain sample texture" % str(biome.get("name", "biome")))
		var texture_path := str(pattern.get("texture_path", ""))
		TEST_UTILS.expect(not texture_path.is_empty(), failures, "%s should define a sample texture path" % str(biome.get("name", "biome")))
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(texture_path)
		var image := Image.new()
		var err := image.load_png_from_buffer(bytes)
		TEST_UTILS.expect(err == OK and not image.is_empty(), failures, "%s sample texture should load as a PNG image" % texture_path)
		if err == OK and not image.is_empty():
			TEST_UTILS.expect(image.get_width() > 0 and image.get_height() > 0, failures, "%s sample texture should have dimensions" % texture_path)
			TEST_UTILS.expect(image.get_width() <= 256 and image.get_height() <= 256, failures, "%s sample texture should be downscaled to 256px or less" % texture_path)
	world.free()


func _test_biome_terrain_accent_layout_is_dense_and_inside_biome(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	for biome_value in WORLD_CONFIG.get_biome_zones():
		var biome := Dictionary(biome_value)
		var accents: Array = world.call("_get_biome_terrain_accent_layout", biome)
		var target_count := int(world.call("_get_biome_terrain_accent_target_count", biome))
		var minimum_expected := int(max(target_count - 2, 12))
		var points := PackedVector2Array(biome["points"])
		TEST_UTILS.expect(not accents.is_empty(), failures, "%s should generate at least one terrain accent" % str(biome.get("name", "biome")))
		TEST_UTILS.expect(target_count >= 14, failures, "%s should target a denser accent budget than the previous sparse pass" % str(biome.get("name", "biome")))
		TEST_UTILS.expect(accents.size() >= minimum_expected, failures, "%s should fill most of its terrain accent budget" % str(biome.get("name", "biome")))
		TEST_UTILS.expect(accents.size() <= 36, failures, "%s should keep terrain accents under the performance ceiling" % str(biome.get("name", "biome")))
		for accent_value in accents:
			var accent := Dictionary(accent_value)
			var position := Vector2(accent.get("position", Vector2.ZERO))
			TEST_UTILS.expect(Geometry2D.is_point_in_polygon(position, points), failures, "%s terrain accents should stay inside the biome polygon" % str(biome.get("name", "biome")))
			TEST_UTILS.expect(not str(accent.get("kind", "")).is_empty(), failures, "%s terrain accents should declare a drawable kind" % str(biome.get("name", "biome")))
	var westwood := _get_biome_by_name("Westwood")
	var first_layout: Array = world.call("_get_biome_terrain_accent_layout", westwood)
	var second_layout: Array = world.call("_get_biome_terrain_accent_layout", westwood)
	TEST_UTILS.expect_equal(first_layout.size(), second_layout.size(), failures, "Biome accent layout should stay deterministic between reads")
	if not first_layout.is_empty() and not second_layout.is_empty():
		var first_position := Vector2(Dictionary(first_layout[0]).get("position", Vector2.ZERO))
		var second_position := Vector2(Dictionary(second_layout[0]).get("position", Vector2.ZERO))
		TEST_UTILS.expect_close(first_position.x, second_position.x, failures, "Biome accent layout should keep the first accent X stable")
		TEST_UTILS.expect_close(first_position.y, second_position.y, failures, "Biome accent layout should keep the first accent Y stable")
	world.free()


func _test_biome_terrain_accent_layout_stays_async_when_queue_is_pending(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	world.call("_queue_biome_terrain_accent_cache_rebuild")
	var westwood := _get_biome_by_name("Westwood")
	var pending_layout: Array = world.call("_get_biome_terrain_accent_layout", westwood)
	TEST_UTILS.expect(pending_layout.is_empty(), failures, "Queued terrain accents should wait for the async cache builder instead of rebuilding synchronously during draw-time access")
	world.free()


func _test_biome_sample_texture_paths_match_biome_identity(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	var expected_tokens := {
		"Westwood": "westwood_sample",
		"Stoneback Ridge": "stoneback_ridge_sample",
		"Hearth Meadow": "hearth_meadow_sample",
		"South Thicket": "south_thicket_sample",
		"Redfang Wilds": "redfang_wilds_sample"
	}
	for biome_value in WORLD_CONFIG.get_biome_zones():
		var biome := Dictionary(biome_value)
		var biome_name := str(biome.get("name", "biome"))
		var texture_key := str(world.call("_get_biome_terrain_texture_key", biome))
		var expected_token := str(expected_tokens.get(biome_name, ""))
		TEST_UTILS.expect(not expected_token.is_empty(), failures, "%s should have an expected sample texture token in the test" % biome_name)
		if not expected_token.is_empty():
			TEST_UTILS.expect(texture_key.contains(expected_token), failures, "%s should use the %s sample texture" % [biome_name, expected_token])
	world.free()


func _test_biome_surface_color_uses_the_containing_biome_without_blending(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	var westwood := _get_biome_by_name("Westwood")
	var biome_zones := WORLD_CONFIG.get_biome_zones()
	var sample_point := _find_boundary_sample_point(westwood, biome_zones)
	TEST_UTILS.expect(sample_point != Vector2.INF, failures, "Westwood should expose a sample point near a biome edge")
	if sample_point == Vector2.INF:
		world.free()
		return
	var base_color := Color(westwood["color"])
	var expected_color: Color = world.call("_get_biome_terrain_color", westwood, sample_point, world.call("_get_biome_visual_color", westwood))
	var surface_color: Color = world.call("_get_biome_surface_color_at", sample_point, biome_zones)
	TEST_UTILS.expect_close(surface_color.r, expected_color.r, failures, "Biome surface color should use the containing biome red channel without blending")
	TEST_UTILS.expect_close(surface_color.g, expected_color.g, failures, "Biome surface color should use the containing biome green channel without blending")
	TEST_UTILS.expect_close(surface_color.b, expected_color.b, failures, "Biome surface color should use the containing biome blue channel without blending")
	TEST_UTILS.expect(surface_color != base_color, failures, "Biome texture should still apply the biome's own surface pattern")
	world.free()


func _test_biome_sample_texture_varies_with_position(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	var biome := _get_biome_by_name("Hearth Meadow")
	var base_color := Color(biome["color"])
	var sample_positions: Array[Vector2] = []
	for y in [-520.0, -240.0, 0.0, 260.0, 520.0]:
		for x in [-900.0, -420.0, 0.0, 420.0, 900.0]:
			sample_positions.append(Vector2(float(x), float(y)))
	var sample_a: Vector2 = sample_positions[0]
	var color_low: Color = Color.WHITE
	var color_high: Color = Color.BLACK
	var unique_colors: Dictionary = {}
	for sample_position in sample_positions:
		var sample_color: Color = world.call("_get_biome_terrain_color", biome, sample_position, base_color)
		var color_key := "%d:%d:%d" % [int(round(sample_color.r * 31.0)), int(round(sample_color.g * 31.0)), int(round(sample_color.b * 31.0))]
		unique_colors[color_key] = true
		if sample_color.get_luminance() < color_low.get_luminance():
			color_low = sample_color
		if sample_color.get_luminance() > color_high.get_luminance():
			color_high = sample_color
	var color_a: Color = world.call("_get_biome_terrain_color", biome, sample_a, base_color)
	var color_difference: float = abs(color_low.r - color_high.r) + abs(color_low.g - color_high.g) + abs(color_low.b - color_high.b)
	TEST_UTILS.expect(unique_colors.size() >= 4, failures, "Terrain sample texture should resolve into multiple visible colors instead of one blotch")
	TEST_UTILS.expect(color_difference > 0.08, failures, "Terrain texture should produce visible color changes across different positions")
	TEST_UTILS.expect(color_a != base_color, failures, "Terrain texture should modify the base biome color")
	world.free()


func _test_redfang_wilds_sample_texture_has_drawn_cracks(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	var biome := _get_biome_by_name("Redfang Wilds")
	var pattern: Dictionary = Dictionary(world.call("_get_biome_terrain_pattern", biome))
	var texture_path := str(pattern.get("texture_path", ""))
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(texture_path)
	var image := Image.new()
	var load_err := image.load_png_from_buffer(bytes)
	TEST_UTILS.expect(load_err == OK and not image.is_empty(), failures, "Redfang Wilds sample texture should load successfully")
	if load_err != OK or image.is_empty():
		world.free()
		return
	var width := image.get_width()
	var height := image.get_height()
	var sample_positions: Array[Vector2i] = [
		Vector2i(clampi(int(round(width * 0.10)), 0, width - 1), clampi(int(round(height * 0.10)), 0, height - 1)),
		Vector2i(clampi(int(round(width * 0.30)), 0, width - 1), clampi(int(round(height * 0.16)), 0, height - 1)),
		Vector2i(clampi(int(round(width * 0.52)), 0, width - 1), clampi(int(round(height * 0.22)), 0, height - 1)),
		Vector2i(clampi(int(round(width * 0.68)), 0, width - 1), clampi(int(round(height * 0.55)), 0, height - 1)),
		Vector2i(clampi(int(round(width * 0.80)), 0, width - 1), clampi(int(round(height * 0.78)), 0, height - 1)),
		Vector2i(clampi(int(round(width * 0.90)), 0, width - 1), clampi(int(round(height * 0.88)), 0, height - 1))
	]
	var darkest := 1.0
	var lightest := 0.0
	var unique_colors: Dictionary = {}
	for sample_position in sample_positions:
		var sample_color := image.get_pixel(sample_position.x, sample_position.y)
		unique_colors["%d:%d:%d" % [int(round(sample_color.r * 31.0)), int(round(sample_color.g * 31.0)), int(round(sample_color.b * 31.0))]] = true
		darkest = min(darkest, sample_color.get_luminance())
		lightest = max(lightest, sample_color.get_luminance())
	TEST_UTILS.expect(darkest < 0.28, failures, "Redfang Wilds sample texture should keep dark crack seams")
	TEST_UTILS.expect(lightest > 0.34, failures, "Redfang Wilds sample texture should keep lighter plates")
	TEST_UTILS.expect(lightest - darkest > 0.16, failures, "Redfang Wilds sample texture should show a visible cracked-earth contrast")
	TEST_UTILS.expect(unique_colors.size() >= 4, failures, "Redfang Wilds sample texture should include several drawn colors, not a flat blotch")
	world.free()


func _test_landmark_debug_counts_and_nearest_selection(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	world.landmarks = [
		{
			"id": "near_pond",
			"type": "pond",
			"position": Vector2(90.0, 30.0),
			"radius": 120.0,
			"biome_id": "westwood"
		},
		{
			"id": "far_hill",
			"type": "hill",
			"position": Vector2(620.0, -180.0),
			"radius": 180.0,
			"biome_id": "stoneback_ridge"
		}
	]
	world.pond_landmarks = [world.landmarks[0]]
	world.hill_landmarks = [world.landmarks[1]]
	var counts: Dictionary = world.get_landmark_counts()
	TEST_UTILS.expect_equal(int(counts.get("generated", 0)), 2, failures, "Landmark debug counts should include the generated landmark total")
	TEST_UTILS.expect_equal(int(counts.get("pond", 0)), 1, failures, "Landmark debug counts should report pond totals")
	TEST_UTILS.expect_equal(int(counts.get("hill", 0)), 1, failures, "Landmark debug counts should report hill totals")
	var nearest: Dictionary = world.get_nearest_landmark_data(Vector2(100.0, 35.0))
	TEST_UTILS.expect_equal(str(nearest.get("id", "")), "near_pond", failures, "Nearest landmark lookup should prefer the closest landmark")
	TEST_UTILS.expect_equal(str(nearest.get("type", "")), "pond", failures, "Nearest landmark lookup should preserve landmark type")
	TEST_UTILS.expect(float(nearest.get("distance_to_position", INF)) < 20.0, failures, "Nearest landmark lookup should report a small distance for nearby targets")
	world.free()


func _test_landmark_debug_toggles_flip_runtime_state(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	TEST_UTILS.expect(not world.is_landmark_debug_overlay_enabled(), failures, "Landmark overlay debug should start disabled")
	TEST_UTILS.expect(world.are_biome_textures_enabled(), failures, "Biome textures should start enabled")
	var overlay_enabled: bool = world.debug_toggle_landmark_overlay()
	var textures_enabled: bool = world.debug_toggle_biome_textures()
	TEST_UTILS.expect(overlay_enabled, failures, "Landmark overlay debug toggle should enable the overlay on first press")
	TEST_UTILS.expect(not textures_enabled, failures, "Biome texture debug toggle should disable textures on first press")
	TEST_UTILS.expect(world.is_landmark_debug_overlay_enabled(), failures, "Landmark overlay debug state should persist after toggling")
	TEST_UTILS.expect(not world.are_biome_textures_enabled(), failures, "Biome texture debug state should persist after toggling")
	world.free()


func _test_biome_texture_cache_status_reports_runtime_flags(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	world.biome_sample_images["westwood"] = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	world.biome_terrain_accent_cache["westwood"] = [{"position": Vector2.ZERO, "kind": "grass"}]
	world.pending_biome_terrain_accent_biomes = [_get_biome_by_name("Westwood")]
	world.biome_terrain_accent_cache_build_running = true
	world.biome_textures_enabled = false
	var status: Dictionary = world.get_biome_texture_cache_status()
	TEST_UTILS.expect_equal(int(status.get("sample_image_cache_count", 0)), 1, failures, "Biome texture cache status should report loaded sample images")
	TEST_UTILS.expect_equal(int(status.get("accent_cache_count", 0)), 1, failures, "Biome texture cache status should report cached accent layouts")
	TEST_UTILS.expect_equal(int(status.get("pending_biomes", 0)), 1, failures, "Biome texture cache status should report queued biome rebuilds")
	TEST_UTILS.expect(status.get("build_running", false) == true, failures, "Biome texture cache status should expose whether the cache builder is running")
	TEST_UTILS.expect(status.get("textures_enabled", true) == false, failures, "Biome texture cache status should expose whether biome textures are enabled")
	world.free()


func _test_current_biome_texture_id_uses_player_position_biome(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	var westwood := _get_biome_by_name("Westwood")
	var sample_point := _find_boundary_sample_point(westwood, WORLD_CONFIG.get_biome_zones())
	TEST_UTILS.expect(sample_point != Vector2.INF, failures, "Westwood should expose a sample point for biome texture id checks")
	if sample_point == Vector2.INF:
		world.free()
		return
	var texture_id := world.get_current_biome_texture_id(sample_point)
	TEST_UTILS.expect(texture_id.contains("westwood_sample"), failures, "Current biome texture id should resolve from the biome containing the sampled world position")
	world.free()


func _make_world_with_single_pond() -> Node2D:
	var world := WORLD_SCRIPT.new()
	world.pond_landmarks = [{
		"id": "test_pond",
		"position": Vector2.ZERO,
		"radius": 100.0
	}]
	world.pond_water_search_radius = 120.0
	world.hill_landmarks = []
	return world


func _make_world_with_single_hill() -> Node2D:
	var world := WORLD_SCRIPT.new()
	world.pond_landmarks = []
	world.pond_water_search_radius = 0.0
	world.hill_landmarks = [{
		"id": "test_hill",
		"position": Vector2.ZERO,
		"radius": 100.0
	}]
	return world


func _find_sample_point_for_zone(world: Node2D, target_zone: String) -> Vector2:
	for x in range(1, 201):
		var candidate := Vector2(float(x), 0.0)
		if world.get_water_zone(candidate) == target_zone:
			return candidate
	return Vector2.INF


func _get_biome_by_name(target_name: String) -> Dictionary:
	for biome_value in WORLD_CONFIG.get_biome_zones():
		var biome := Dictionary(biome_value)
		if str(biome.get("name", "")) == target_name:
			return biome
	return {}


func _find_boundary_sample_point(biome: Dictionary, biome_zones: Array[Dictionary]) -> Vector2:
	var best_point := Vector2.INF
	var best_distance := INF
	for y in range(-860, 861, 60):
		for x in range(-1420, 1421, 60):
			var candidate := Vector2(float(x), float(y))
			if not Geometry2D.is_point_in_polygon(candidate, PackedVector2Array(biome["points"])):
				continue
			var edge_distance := _get_point_polygon_edge_distance(candidate, biome_zones)
			if edge_distance < best_distance:
				best_distance = edge_distance
				best_point = candidate
	return best_point


func _get_point_polygon_edge_distance(point: Vector2, biome_zones: Array[Dictionary]) -> float:
	var nearest_distance := INF
	for biome_value in biome_zones:
		var biome := Dictionary(biome_value)
		var points := PackedVector2Array(biome["points"])
		for i in points.size():
			var start := points[i]
			var end := points[(i + 1) % points.size()]
			nearest_distance = min(nearest_distance, _get_distance_to_segment(point, start, end))
	return nearest_distance


func _get_distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var t: float = clamp((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)
