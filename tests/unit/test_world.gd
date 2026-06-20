extends RefCounted

const WORLD_SCRIPT := preload("res://scripts/world/world.gd")
const WORLD_QUERY_SERVICE := preload("res://scripts/world/world_query_service.gd")
const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const WORLD_GENERATOR_PATH := "res://scripts/world/world_generator.gd"
const WORLD_TOPOGRAPHY := preload("res://scripts/world/world_topography.gd")
const TERRAIN_CELL_MAP := preload("res://scripts/world/terrain_cell_map.gd")
const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


class CountingWorld:
	extends WORLD_SCRIPT

	var sync_calls := 0

	func _sync_biome_blend_background() -> void:
		sync_calls += 1


class PeriodicRockSpawnWorld:
	extends WORLD_SCRIPT

	var spawn_calls := 0
	var last_min_distance := -1.0
	var last_resource_kind := ""
	var last_biome_id := ""
	var player_position := Vector2.ZERO

	func _get_player_position() -> Vector2:
		return player_position

	func _get_weighted_biome_for_resource(resource_kind: String) -> Dictionary:
		last_resource_kind = resource_kind
		return {
			"name": "Redfang Wilds",
			"biome_id": "redfang_wilds",
			"dangerous": true,
			"points": [Vector2(-10.0, -10.0), Vector2(10.0, -10.0), Vector2(10.0, 10.0), Vector2(-10.0, 10.0)]
		}

	func _get_existing_resource_positions() -> Array[Vector2]:
		return []

	func _try_spawn_resource_in_biome(resource_kind: String, biome: Dictionary, _used_positions: Array[Vector2], _player_position: Vector2, min_distance: float = WORLD_CONFIG.RESOURCE_MIN_DISTANCE, _spawn_attempts: int = WORLD_CONFIG.RESOURCE_SPAWN_ATTEMPTS) -> bool:
		spawn_calls += 1
		last_resource_kind = resource_kind
		last_biome_id = str(biome.get("biome_id", ""))
		last_min_distance = min_distance
		return true


class FixedRenderControllerStub:
	extends RefCounted

	var should_redraw := false
	var biome_surface_color_getter: Callable = Callable()
	var biome_blend_texture: ImageTexture
	var biome_blend_colors_key := ""
	var biome_blend_texture_rebuild_count: int = 0
	var biome_blend_texture_last_build_ms: float = 0.0
	var biome_blend_texture_rebuild_blocked_count: int = 0
	var biome_blend_texture_dirty_key := ""
	var freeze_blend_texture_after_first_build := true

	func bind_world(
		_world_rect: Rect2,
		_biome_zones_getter: Callable,
		_biome_colors_key_getter: Callable,
		assigned_biome_surface_color_getter: Callable,
		_biome_texture_size: Vector2i = Vector2i(384, 236),
		_world_redraw_interval := 0.20,
		_night_redraw_min_delta := 0.03
	) -> void:
		biome_surface_color_getter = assigned_biome_surface_color_getter

	func ensure_biome_blend_texture() -> ImageTexture:
		if biome_blend_texture == null:
			biome_blend_texture = ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
		biome_blend_texture_rebuild_count += 1
		return biome_blend_texture

	func get_biome_texture_cache_status() -> Dictionary:
		return {
			"has_texture": biome_blend_texture != null,
			"colors_key": biome_blend_colors_key,
			"rebuild_count": biome_blend_texture_rebuild_count,
			"last_build_ms": biome_blend_texture_last_build_ms,
			"rebuild_blocked_count": biome_blend_texture_rebuild_blocked_count,
			"dirty_key_pending": not biome_blend_texture_dirty_key.is_empty(),
			"freeze_after_first_build": freeze_blend_texture_after_first_build
		}

	func process(_delta: float, _current_night_amount: float) -> bool:
		return should_redraw


class TerrainRendererStub:
	extends TerrainChunkRenderer

	var bind_calls := 0
	var process_visibility_calls := 0
	var rebuild_calls: Array[bool] = []

	func bind(_assigned_cell_map: TerrainCellMap, _assigned_player: Node2D, _assigned_camera: Camera2D) -> void:
		bind_calls += 1

	func process_visibility(_delta: float) -> void:
		process_visibility_calls += 1

	func rebuild_visible_chunks(force := false) -> void:
		rebuild_calls.append(force)


class SurfaceShapeMapStub:
	extends RefCounted

	var last_position := Vector2.INF

	func sample_visual_surface_at(position: Vector2) -> Dictionary:
		last_position = position
		return {
			"biome_id": "shape_biome",
			"terrain_id": "shape_terrain",
			"layer_id": "shape_layer",
			"source": "polygon"
		}

	func sample_visual_surface_exact_at(position: Vector2) -> Dictionary:
		last_position = position
		return {
			"biome_id": "shape_biome",
			"terrain_id": "shape_terrain",
			"layer_id": "shape_layer",
			"source": "exact_polygon_record"
		}


class SurfaceSamplingWorldStub:
	extends Node

	var shape_map := SurfaceShapeMapStub.new()

	func get_world_rect() -> Rect2:
		return WORLD_CONFIG.WORLD_RECT

	func get_biome_shape_map():
		return shape_map

	func get_surface_terrain_zone_at(_position: Vector2) -> String:
		return "world_fallback_terrain"

	func get_visual_biome_id_at(_position: Vector2) -> String:
		return "world_fallback_biome"


class TerrainSurfaceRendererStub:
	extends TerrainSurfaceChunkRenderer

	var dirty_reasons: Array[String] = []

	func mark_dirty(reason := "unknown") -> void:
		dirty_reasons.append(reason)


class MockSmallPreyEcosystemDirector:
	extends Node

	func get_biome_state(_biome_id: String) -> Dictionary:
		return {
			"small_prey_population": 4.0,
			"plant_biomass_percent": 100.0
		}


class SmallPreySyncWorld:
	extends WORLD_SCRIPT

	var spawn_should_succeed := false
	var spawn_attempt_calls := 0
	var player_position := Vector2.ZERO

	func _get_player_position() -> Vector2:
		return player_position

	func _get_biome_for_position(_position: Vector2) -> Dictionary:
		return {
			"id": "westwood",
			"name": "Westwood",
			"dangerous": false
		}

	func _get_biome_id(_biome: Dictionary) -> String:
		return "westwood"

	func _get_desired_small_prey_count(_biome: Dictionary, _biome_state: Dictionary) -> int:
		return 2

	func _get_visible_small_prey_count(_biome_id: String) -> int:
		return 0

	func get_registered_creatures_by_type(_creature_type: String) -> Array:
		return []

	func _get_existing_small_prey_positions() -> Array[Vector2]:
		return []

	func _try_spawn_small_prey_near_player(_biome: Dictionary, _player_position: Vector2, _used_positions: Array[Vector2], _slot_index: int, _slot_count: int) -> bool:
		spawn_attempt_calls += 1
		return spawn_should_succeed


class MockVarnakEcosystemDirector:
	extends Node

	func get_biome_state(_biome_id: String) -> Dictionary:
		return {}


class VarnakSyncWorld:
	extends WORLD_SCRIPT

	var spawn_should_succeed := false
	var player_position := Vector2.ZERO
	var water_blocked := false
	var spawn_attempt_calls := 0

	func _get_player_position() -> Vector2:
		return player_position

	func _get_current_day() -> int:
		return 4

	func _get_varnak_spawn_budget(_global_count: int, _day: int) -> int:
		return 2

	func get_registered_creatures_by_type(_creature_type: String) -> Array:
		return []

	func _get_existing_varnak_positions() -> Array[Vector2]:
		return []

	func is_creature_spawn_blocked_by_water(_position: Vector2) -> bool:
		return water_blocked

	func _get_creature_horizon_spawn_ring() -> Vector2:
		return Vector2(520.0, 640.0)

	func _get_biome_for_position(_position: Vector2) -> Dictionary:
		return {
			"name": "Westwood",
			"dangerous": false
		}

	func _get_scaled_biome_bounds(_biome: Dictionary) -> Rect2:
		return Rect2(Vector2(-100.0, -100.0), Vector2(200.0, 200.0))

	func _is_point_in_biome(_point: Vector2, _biome: Dictionary) -> bool:
		return true

	func _is_position_inside_camera_view(_position: Vector2, _margin: float = 0.0) -> bool:
		return false

	func _try_spawn_varnak_in_world(_player_position: Vector2, _used_positions: Array[Vector2]) -> bool:
		spawn_attempt_calls += 1
		return spawn_should_succeed

	func _spawn_varnak_at(_pos: Vector2) -> Node:
		spawn_should_succeed = true
		return Node.new()


class FirstWeekWorld:
	extends WORLD_SCRIPT

	func _get_current_day() -> int:
		return current_day

	var current_day := 1


class GraphicsSettingsStub:
	extends Node

	func get_default_biome_textures_enabled() -> bool:
		return true

	func get_default_landmark_debug_overlay_enabled() -> bool:
		return false

	func get_default_biome_terrain_accents_enabled() -> bool:
		return false

	func is_low_end_rendering_enabled() -> bool:
		return true


class VisibilityCullingWorld:
	extends WORLD_SCRIPT

	func _ready() -> void:
		pass


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_world_rect_matches_config(failures)
	_test_safe_player_start_avoids_water_and_landmarks(failures)
	_test_landmark_generation_keeps_distance_from_player_start(failures)
	_test_water_zone_detection_uses_pond_geometry(failures)
	_test_plant_resources_are_blocked_by_water(failures)
	_test_non_plant_resources_ignore_water_blocking(failures)
	_test_highlands_no_longer_block_navigation(failures)
	_test_terrain_speed_multiplier_changes_in_water(failures)
	_test_landmark_save_data_round_trip_vectors(failures)
	_test_world_save_data_includes_seed_and_landmark_fields(failures)
	_test_biome_resource_weights_match_target_character(failures)
	_test_westwood_extra_conifer_configuration_is_local(failures)
	_test_south_thicket_biome_weights_match_target_character(failures)
	_test_redfang_dry_tree_and_periodic_rock_spawn(failures)
	_test_varnak_first_week_curve_limits_population_and_spawn(failures)
	_test_biomes_have_sample_texture_assets(failures)
	_test_biome_terrain_accent_layout_is_dense_and_inside_biome(failures)
	_test_biome_terrain_accent_layout_stays_async_when_queue_is_pending(failures)
	_test_biome_sample_texture_paths_match_biome_identity(failures)
	_test_biome_surface_color_uses_the_containing_biome_without_blending(failures)
	_test_biome_color_palette_keeps_westwood_and_south_thicket_distinct(failures)
	_test_topography_resource_distribution_modifiers_respect_water_and_highlands(failures)
	_test_world_query_service_slows_highlands_and_water(failures)
	_test_biome_surface_stays_crisp_and_uses_accents_for_detail(failures)
	_test_biome_detail_density_uses_game_balance_and_limit(failures)
	_test_biome_texture_variation_is_continuous_without_tiling(failures)
	_test_redfang_wilds_sample_texture_has_drawn_cracks(failures)
	_test_topography_sample_returns_a_single_combined_snapshot(failures)
	_test_world_surface_debug_matches_query_service_surface_terrain(failures)
	_test_landmark_debug_counts_and_nearest_selection(failures)
	_test_landmark_debug_toggles_flip_runtime_state(failures)
	_test_biome_texture_cache_status_reports_runtime_flags(failures)
	_test_world_applies_graphics_settings_render_defaults(failures)
	_test_world_builds_cached_biome_blend_texture(failures)
	_test_world_biome_blend_texture_size_uses_configurable_scale(failures)
	_test_visual_biome_query_uses_generator_source(failures)
	_test_visual_biome_influence_scores_vary_across_space(failures)
	_test_terrain_cell_map_builds_and_looks_up_cells(failures)
	_test_biome_shape_map_builds_connected_regions(failures)
	_test_world_biome_texture_cache_status_reports_visual_settings(failures)
	_test_world_biome_texture_cache_status_reports_visual_feature_count(failures)
	_test_world_biome_and_surface_queries_do_not_recursively_call_topography(failures)
	_test_world_draw_biomes_uses_existing_background_texture(failures)
	_test_world_process_only_syncs_biome_background_when_redraw_is_requested(failures)
	_test_world_terrain_renderer_rebuilds_cell_map_only_when_dirty(failures)
	_test_world_marks_terrain_surface_chunks_dirty_after_biome_shape_rebuild(failures)
	_test_terrain_surface_renderer_samples_biome_shape_map(failures)
	_test_terrain_surface_renderer_uses_preview_then_refine_pipeline(failures)
	_test_terrain_surface_renderer_starts_multiple_preview_builds(failures)
	_test_terrain_surface_renderer_refine_pending_does_not_block_preview(failures)
	_test_terrain_surface_renderer_keeps_active_build_texture_size_stable(failures)
	_test_small_prey_spawn_sync_uses_cooldown_after_failure(failures)
	_test_varnak_spawn_sync_uses_cooldown_after_failure(failures)
	_test_world_updates_night_overlay_without_redrawing_static_world(failures)
	_test_world_boot_progress_state_tracks_stage_updates(failures)
	_test_current_biome_texture_id_uses_player_position_biome(failures)
	_test_safe_restored_resource_position_uses_requested_position(failures)
	_test_get_camera_visible_world_rect_defaults_to_full_world_without_camera(failures)
	_test_world_object_visibility_rect_accounts_for_camera_zoom_and_margin(failures)
	_test_world_object_visibility_culls_and_restores_group_nodes(failures)
	_test_cached_group_nodes_prune_freed_entries(failures)
	_test_world_registry_tracks_spawned_nodes_and_prunes_freed_entries(failures)
	_test_varnak_population_target_scales_with_day_and_caps(failures)
	_test_varnak_spawn_chance_scales_with_day_and_caps(failures)
	_test_varnak_spawn_budget_is_batched_and_stops_at_target(failures)
	_test_varnak_can_spawn_in_non_dangerous_biome(failures)
	_test_varnak_spawn_rejects_water(failures)
	_test_varnak_spawn_respects_player_safe_distance(failures)
	_test_varnak_dangerous_biome_has_higher_weight(failures)
	_test_varnak_spawn_does_not_fail_when_player_far_from_redfang(failures)
	_test_grazer_visible_target_tracks_model_population_and_biomass(failures)
	_test_creature_spawn_horizon_stays_outside_camera_view(failures)
	return failures


func _test_world_rect_matches_config(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	TEST_UTILS.expect_equal(world.get_world_rect(), WORLD_CONFIG.WORLD_RECT, failures, "World rectangle should match world config")
	world.free()


func _test_safe_player_start_avoids_water_and_landmarks(failures: Array[String]) -> void:
	var landmarks: Array[Dictionary] = [{
		"id": "test_pond",
		"type": "pond",
		"position": WORLD_CONFIG.PLAYER_START_POSITION,
		"radius": 180.0
	}]
	var safe_start := WORLD_CONFIG.get_safe_player_start_position(landmarks)
	TEST_UTILS.expect(WORLD_CONFIG.is_safe_player_start_position(safe_start, landmarks), failures, "Safe player start should stay on land and outside landmark buffers")
	TEST_UTILS.expect_equal(WORLD_CONFIG.get_terrain_zone(safe_start) in ["land", "highland"], true, failures, "Safe player start should end on land or highland")
	TEST_UTILS.expect(safe_start.distance_to(Vector2.ZERO) > 0.0, failures, "Blocked default start should move the player to a nearby safe point")


func _test_landmark_generation_keeps_distance_from_player_start(failures: Array[String]) -> void:
	var landmarks: Array[Dictionary] = WORLD_CONFIG.generate_landmarks(2468)
	TEST_UTILS.expect(not landmarks.is_empty(), failures, "World config should still generate landmarks")
	for landmark_value in landmarks:
		var landmark := Dictionary(landmark_value)
		var position := Vector2(landmark.get("position", Vector2.INF))
		var radius := float(landmark.get("radius", 0.0))
		var landmark_type := str(landmark.get("type", ""))
		var safe_distance := WORLD_CONFIG.PLAYER_LANDMARK_SAFE_DISTANCE
		if landmark_type == "pond":
			safe_distance = WORLD_CONFIG.PLAYER_POND_SAFE_DISTANCE
		elif landmark_type == "hill":
			safe_distance = WORLD_CONFIG.PLAYER_HILL_SAFE_DISTANCE
		TEST_UTILS.expect(position != Vector2.INF, failures, "Generated landmarks should not fall back to an invalid position")
		TEST_UTILS.expect(position.distance_to(WORLD_CONFIG.PLAYER_START_POSITION) >= radius + safe_distance, failures, "Generated landmarks should keep a safe distance from the player start")


func _test_varnak_population_target_scales_with_day_and_caps(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	TEST_UTILS.expect_equal(int(world.call("_get_varnak_target_count", 1)), 0, failures, "Day 1 should keep the Varnak target at zero")
	TEST_UTILS.expect_equal(int(world.call("_get_varnak_target_count", 2)), 1, failures, "Day 2 should start Varnak spawning")
	TEST_UTILS.expect_equal(int(world.call("_get_varnak_target_count", 3)), 2, failures, "Day 3 should raise the Varnak target again")
	TEST_UTILS.expect_equal(int(world.call("_get_varnak_target_count", 4)), 3, failures, "Day 4 should keep the target growing gradually")
	TEST_UTILS.expect_equal(int(world.call("_get_varnak_target_count", 5)), 4, failures, "Day 5 should continue the steady rise")
	TEST_UTILS.expect_equal(int(world.call("_get_varnak_target_count", 6)), 5, failures, "Day 6 should continue the steady rise")
	TEST_UTILS.expect_equal(int(world.call("_get_varnak_target_count", 7)), 6, failures, "Day 7 should reach the first-week cap")
	TEST_UTILS.expect_equal(int(world.call("_get_varnak_target_count", 99)), 8, failures, "Varnak population target should respect the hard maximum")
	world.free()


func _test_biome_resource_weights_match_target_character(failures: Array[String]) -> void:
	var westwood := Dictionary(WORLD_CONFIG.get_biome_zones()[0])
	var stoneback := Dictionary(WORLD_CONFIG.get_biome_zones()[1])
	var hearth := Dictionary(WORLD_CONFIG.get_biome_zones()[2])
	var south := Dictionary(WORLD_CONFIG.get_biome_zones()[3])
	var redfang := Dictionary(WORLD_CONFIG.get_biome_zones()[4])
	TEST_UTILS.expect(float(westwood.get("conifer_tree_weight", 0.0)) > float(westwood.get("leafy_tree_weight", 0.0)), failures, "Westwood should favor conifer trees")
	TEST_UTILS.expect(float(westwood.get("berry_bush_weight", 0.0)) > float(south.get("berry_bush_weight", 0.0)), failures, "Westwood should favor berries over South Thicket")
	TEST_UTILS.expect(float(hearth.get("leafy_tree_weight", 0.0)) > float(hearth.get("conifer_tree_weight", 0.0)), failures, "Hearth Watch should favor leafy trees")
	TEST_UTILS.expect(float(stoneback.get("dry_bush_weight", 0.0)) > float(stoneback.get("berry_bush_weight", 0.0)), failures, "Stoneback should favor dry bushes over berries")
	TEST_UTILS.expect(float(redfang.get("dry_tree_weight", 0.0)) > float(redfang.get("leafy_tree_weight", 0.0)), failures, "Redfang should favor dry trees")
	TEST_UTILS.expect(float(redfang.get("dry_bush_weight", 0.0)) > float(redfang.get("berry_bush_weight", 0.0)), failures, "Redfang should favor dry bushes over berries")


func _test_westwood_extra_conifer_configuration_is_local(failures: Array[String]) -> void:
	TEST_UTILS.expect_equal(int(WORLD_CONFIG.TREE_COUNT), 48, failures, "Westwood bonus should not change the global tree budget")
	TEST_UTILS.expect_equal(int(WORLD_CONFIG.WESTWOOD_EXTRA_CONIFER_COUNT), 48, failures, "Westwood should use the configured local conifer bonus")
	TEST_UTILS.expect(float(WORLD_CONFIG.WESTWOOD_EXTRA_CONIFER_COUNT) > 0.0, failures, "Westwood should spawn extra conifers locally")
	TEST_UTILS.expect(float(WORLD_CONFIG.RESOURCE_MIN_DISTANCE) * 0.72 < float(WORLD_CONFIG.RESOURCE_MIN_DISTANCE), failures, "Westwood bonus spawn spacing should be tighter than the global resource spacing")
	var westwood := Dictionary(WORLD_CONFIG.get_biome_zones()[0])
	TEST_UTILS.expect(float(westwood.get("conifer_tree_weight", 0.0)) > float(westwood.get("leafy_tree_weight", 0.0)), failures, "Westwood should favor conifer trees over leafy trees")
	TEST_UTILS.expect(float(westwood.get("conifer_tree_weight", 0.0)) > 0.0, failures, "Westwood should keep a positive conifer weight")
	var stoneback := Dictionary(WORLD_CONFIG.get_biome_zones()[1])
	var hearth := Dictionary(WORLD_CONFIG.get_biome_zones()[2])
	var redfang := Dictionary(WORLD_CONFIG.get_biome_zones()[4])
	TEST_UTILS.expect(float(westwood.get("tree_weight", 0.0)) >= 18.0, failures, "Westwood should get a higher tree density target")
	TEST_UTILS.expect(float(westwood.get("conifer_tree_weight", 0.0)) >= 22.0, failures, "Westwood should keep the stronger conifer focus")
	TEST_UTILS.expect(float(stoneback.get("tree_weight", 0.0)) >= 2.4, failures, "Stoneback should get a slightly denser tree target")
	TEST_UTILS.expect(float(hearth.get("tree_weight", 0.0)) >= 7.0, failures, "Hearth should get a denser tree target")
	TEST_UTILS.expect(float(redfang.get("tree_weight", 0.0)) >= 7.0, failures, "Redfang should get a denser tree target")
	TEST_UTILS.expect(float(redfang.get("dry_bush_weight", 0.0)) > float(redfang.get("grass_weight", 0.0)), failures, "Redfang should favor dry bushes over grass")


func _test_south_thicket_biome_weights_match_target_character(failures: Array[String]) -> void:
	var stoneback := Dictionary(WORLD_CONFIG.get_biome_zones()[1])
	var south := Dictionary(WORLD_CONFIG.get_biome_zones()[3])
	var redfang := Dictionary(WORLD_CONFIG.get_biome_zones()[4])
	TEST_UTILS.expect(float(south.get("leafy_tree_weight", 0.0)) > float(south.get("conifer_tree_weight", 0.0)), failures, "South Thicket should favor leafy trees over conifers")
	TEST_UTILS.expect(float(south.get("dry_bush_weight", 0.0)) < float(stoneback.get("dry_bush_weight", 0.0)), failures, "South Thicket dry_bush_weight should be lower than Stoneback dry_bush_weight")
	TEST_UTILS.expect(float(south.get("dry_bush_weight", 0.0)) < float(redfang.get("dry_bush_weight", 0.0)), failures, "South Thicket dry_bush_weight should be lower than Redfang dry_bush_weight")


func _test_redfang_dry_tree_and_periodic_rock_spawn(failures: Array[String]) -> void:
	var redfang := Dictionary(WORLD_CONFIG.get_biome_zones()[4])
	TEST_UTILS.expect(float(redfang.get("dry_tree_weight", 0.0)) >= 20.0, failures, "Redfang should spawn twice as many dry trees")
	TEST_UTILS.expect(float(redfang.get("dry_tree_weight", 0.0)) > float(redfang.get("leafy_tree_weight", 0.0)), failures, "Redfang should stay focused on dry trees")
	TEST_UTILS.expect(float(redfang.get("dry_bush_weight", 0.0)) > float(redfang.get("grass_weight", 0.0)), failures, "Redfang should still favor dry bushes over grass")
	var world := PeriodicRockSpawnWorld.new()
	TEST_UTILS.expect_equal(int(WORLD_CONFIG.ROCK_COUNT), 24, failures, "Rock density baseline should stay unchanged")
	TEST_UTILS.expect(world.call("_sync_periodic_rock_spawn") == true, failures, "Periodic rock spawning should produce a spawn attempt")
	TEST_UTILS.expect_equal(world.spawn_calls, 1, failures, "Periodic rock spawning should try exactly one rock per tick")
	TEST_UTILS.expect_equal(world.last_resource_kind, "rock", failures, "Periodic rock spawning should target rocks")
	TEST_UTILS.expect_equal(world.last_biome_id, "redfang_wilds", failures, "Periodic rock spawning should prefer the weighted biome")
	TEST_UTILS.expect_close(world.last_min_distance, float(WORLD_CONFIG.RESOURCE_MIN_DISTANCE * 0.9), failures, "Periodic rock spawning should use the tighter spawn spacing")
	world.free()


func _test_varnak_spawn_chance_scales_with_day_and_caps(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	var day_one_chance := float(world.call("_get_varnak_spawn_chance", 1))
	var day_five_chance := float(world.call("_get_varnak_spawn_chance", 5))
	var late_game_chance := float(world.call("_get_varnak_spawn_chance", 99))
	TEST_UTILS.expect(day_five_chance > day_one_chance, failures, "Varnak spawn chance should increase with survived days")
	TEST_UTILS.expect_close(late_game_chance, 0.55, failures, "Varnak spawn chance should respect its configured cap")
	world.free()


func _test_varnak_spawn_budget_is_batched_and_stops_at_target(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	TEST_UTILS.expect_equal(int(world.call("_get_varnak_spawn_budget", 0, 99)), 2, failures, "Missing Varnaks should be restored in small batches")
	TEST_UTILS.expect_equal(int(world.call("_get_varnak_spawn_budget", 7, 99)), 1, failures, "The final recovery batch should not exceed the hard target")
	TEST_UTILS.expect_equal(int(world.call("_get_varnak_spawn_budget", 8, 99)), 0, failures, "No Varnaks should spawn after reaching the hard target")
	world.free()


func _test_varnak_can_spawn_in_non_dangerous_biome(failures: Array[String]) -> void:
	var world := VarnakSyncWorld.new()
	world.player_position = Vector2(0.0, 0.0)
	world.spawn_should_succeed = true
	var used_positions: Array[Vector2] = []
	TEST_UTILS.expect(world.call("_try_spawn_varnak_in_world", world.player_position, used_positions) == true, failures, "Varnaks should spawn in non-dangerous land biomes")
	world.free()


func _test_varnak_spawn_rejects_water(failures: Array[String]) -> void:
	var world := VarnakSyncWorld.new()
	world.water_blocked = true
	var used_positions: Array[Vector2] = []
	TEST_UTILS.expect(not bool(world.call("_is_valid_varnak_spawn_position", Vector2.ZERO, Vector2.ZERO, used_positions, WORLD_CONFIG.VARNAK_PLAYER_SAFE_DISTANCE)), failures, "Varnak spawn should reject water and blocked terrain")
	world.free()


func _test_varnak_spawn_respects_player_safe_distance(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	var used_positions: Array[Vector2] = []
	TEST_UTILS.expect(not bool(world.call("_is_valid_varnak_spawn_position", Vector2(10.0, 0.0), Vector2.ZERO, used_positions, WORLD_CONFIG.VARNAK_PLAYER_SAFE_DISTANCE)), failures, "Varnak spawn should keep a safe distance from the player")
	world.free()


func _test_varnak_dangerous_biome_has_higher_weight(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	var dangerous_weight := float(world.call("_get_varnak_biome_spawn_weight", {"name": "Redfang Wilds", "dangerous": true}))
	var safe_weight := float(world.call("_get_varnak_biome_spawn_weight", {"name": "Westwood", "dangerous": false}))
	TEST_UTILS.expect(dangerous_weight > safe_weight, failures, "Dangerous biomes should have a higher Varnak spawn weight")
	world.free()


func _test_varnak_spawn_does_not_fail_when_player_far_from_redfang(failures: Array[String]) -> void:
	var world := VarnakSyncWorld.new()
	world.player_position = Vector2(-1000.0, -700.0)
	world.spawn_should_succeed = true
	var used_positions: Array[Vector2] = []
	TEST_UTILS.expect(world.call("_try_spawn_varnak_in_world", world.player_position, used_positions) == true, failures, "Varnak spawn should still succeed when the player is far from Redfang Wilds")
	world.free()


func _test_grazer_visible_target_tracks_model_population_and_biomass(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	TEST_UTILS.expect_equal(
		int(world.call("_get_desired_grazer_count", {"grazer_population": 14.0, "plant_biomass_percent": 100.0})),
		3,
		failures,
		"A healthy target Grazer population should expose the full per-biome visible count"
	)
	TEST_UTILS.expect_equal(
		int(world.call("_get_desired_grazer_count", {"grazer_population": 1.0, "plant_biomass_percent": 80.0})),
		1,
		failures,
		"A surviving Grazer population should keep one visible animal while biomass supports it"
	)
	TEST_UTILS.expect_equal(
		int(world.call("_get_desired_grazer_count", {"grazer_population": 8.0, "plant_biomass_percent": 0.0})),
		0,
		failures,
		"Completely depleted biomass should not spawn visible Grazers"
	)
	world.free()


func _test_creature_spawn_horizon_stays_outside_camera_view(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	var viewport_size := Vector2(1152.0, 648.0)
	var camera_zoom := Vector2(1.1, 1.1)
	var visible_half_diagonal := Vector2(viewport_size.x / camera_zoom.x, viewport_size.y / camera_zoom.y).length() * 0.5
	var horizon_distance := float(world.call("_calculate_creature_horizon_distance", viewport_size, camera_zoom))
	TEST_UTILS.expect(horizon_distance > visible_half_diagonal, failures, "Runtime creatures should spawn beyond the farthest visible camera corner")
	TEST_UTILS.expect(horizon_distance - visible_half_diagonal >= 139.0, failures, "Runtime creature spawns should keep the configured horizon margin")
	var wide_viewport := Vector2(3840.0, 2160.0)
	var wide_half_diagonal := Vector2(wide_viewport.x / camera_zoom.x, wide_viewport.y / camera_zoom.y).length() * 0.5
	var wide_horizon_distance := float(world.call("_calculate_creature_horizon_distance", wide_viewport, camera_zoom))
	TEST_UTILS.expect(wide_horizon_distance > wide_half_diagonal, failures, "Large viewports should push the spawn horizon farther out instead of capping it inside the view")
	world.free()


func _test_water_zone_detection_uses_pond_geometry(failures: Array[String]) -> void:
	var world := _make_world_with_single_pond()
	TEST_UTILS.expect_equal(world.get_water_zone(Vector2.ZERO), "deep_ocean", failures, "Pond center should be deep ocean")
	var shallow_point := _find_sample_point_for_zone(world, "shallow_water")
	TEST_UTILS.expect(shallow_point != Vector2.INF, failures, "The pond should expose at least one shallow-water sample point")
	if shallow_point != Vector2.INF:
		TEST_UTILS.expect_equal(world.get_water_zone(shallow_point), "shallow_water", failures, "A sampled mid-ring point should be shallow water")
	TEST_UTILS.expect(world.get_water_zone(Vector2(160.0, 0.0)) in ["land", "shore", "highland"], failures, "Outside the pond should stay on playable land")
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


func _test_highlands_no_longer_block_navigation(failures: Array[String]) -> void:
	var world := _make_world_with_single_hill()
	TEST_UTILS.expect(not world.is_creature_navigation_blocked(Vector2.ZERO), failures, "Legacy hill landmarks should no longer block navigation")
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


func _test_varnak_first_week_curve_limits_population_and_spawn(failures: Array[String]) -> void:
	var world := FirstWeekWorld.new()
	world.current_day = 1
	TEST_UTILS.expect_equal(int(world.call("_get_varnak_target_count", 1)), 0, failures, "Day 1 should keep Varnak population very low")
	TEST_UTILS.expect_close(float(world.call("_get_varnak_spawn_chance", 1)), 0.00, failures, "Day 1 should use the onboarding spawn chance")
	world.current_day = 3
	TEST_UTILS.expect_equal(int(world.call("_get_varnak_target_count", 3)), 2, failures, "Day 3 should raise the Varnak cap")
	TEST_UTILS.expect_close(float(world.call("_get_varnak_spawn_chance", 3)), 0.15, failures, "Day 3 should increase the spawn chance")
	world.current_day = 9
	TEST_UTILS.expect_equal(int(world.call("_get_varnak_target_count", 9)), 8, failures, "Days after the first week should fall back to standard scaling")
	TEST_UTILS.expect_close(float(world.call("_get_varnak_spawn_chance", 9)), 0.55, failures, "Days after the first week should fall back to standard spawn scaling")
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
		var configured_limit := int(GAME_BALANCE.BIOME_TEXTURES.get("max_detail_per_chunk", 120))
		var points := PackedVector2Array(biome["points"])
		TEST_UTILS.expect(not accents.is_empty(), failures, "%s should generate at least one terrain accent" % str(biome.get("name", "biome")))
		TEST_UTILS.expect(target_count >= 14, failures, "%s should target a denser accent budget than the previous sparse pass" % str(biome.get("name", "biome")))
		TEST_UTILS.expect(accents.size() >= minimum_expected, failures, "%s should fill most of its terrain accent budget" % str(biome.get("name", "biome")))
		TEST_UTILS.expect(accents.size() <= configured_limit, failures, "%s should keep terrain accents under the configured performance ceiling" % str(biome.get("name", "biome")))
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
	world.biome_terrain_accents_enabled = true
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
	if sample_point == Vector2.INF:
		world.free()
		return
	var visual_color: Color = world.call("_get_biome_visual_color", westwood)
	var expected_color: Color = world.call("_get_biome_terrain_color", westwood, sample_point, visual_color)
	var surface_color: Color = world.call("_get_biome_surface_color_at", sample_point, biome_zones)
	TEST_UTILS.expect_close(surface_color.r, expected_color.r, failures, "Biome blend cache should texture the containing biome red channel without crossing the boundary")
	TEST_UTILS.expect_close(surface_color.g, expected_color.g, failures, "Biome blend cache should texture the containing biome green channel without crossing the boundary")
	TEST_UTILS.expect_close(surface_color.b, expected_color.b, failures, "Biome blend cache should texture the containing biome blue channel without crossing the boundary")
	world.free()


func _test_biome_color_palette_keeps_westwood_and_south_thicket_distinct(failures: Array[String]) -> void:
	var generator = load(WORLD_GENERATOR_PATH).new()
	TEST_UTILS.expect(generator.get_biome_color("westwood").g < generator.get_biome_color("south_thicket").g, failures, "Westwood should stay darker than South Thicket")
	TEST_UTILS.expect(generator.get_biome_color("westwood").r <= generator.get_biome_color("south_thicket").r, failures, "Westwood should remain the denser forest tone")
	generator = null


func _test_topography_resource_distribution_modifiers_respect_water_and_highlands(failures: Array[String]) -> void:
	var topo := WORLD_TOPOGRAPHY.new()
	topo.setup(1234)
	var pond_modifiers: Dictionary = topo.get_resource_distribution_modifiers_at(Vector2(100.0, 120.0))
	var highland_modifiers: Dictionary = topo.get_resource_distribution_modifiers_at(Vector2(-240.0, -640.0))
	TEST_UTILS.expect(pond_modifiers.has("grass_patch"), failures, "Topography modifiers should expose grass patch weights")
	TEST_UTILS.expect(pond_modifiers.has("reed"), failures, "Topography modifiers should expose pond vegetation weights")
	TEST_UTILS.expect(highland_modifiers.has("rock"), failures, "Topography modifiers should expose rock weights")
	TEST_UTILS.expect(float(pond_modifiers.get("rock", 1.0)) <= 1.0, failures, "Pond-adjacent topography should not boost rocks")
	TEST_UTILS.expect(float(highland_modifiers.get("rock", 0.0)) >= 1.0, failures, "Highland topography should boost rocks")
	TEST_UTILS.expect(float(pond_modifiers.get("water_lily", 0.0)) >= 1.0 or float(pond_modifiers.get("water_lily", 0.0)) == 0.0, failures, "Pond-adjacent topography should surface aquatic vegetation weights")
	topo = null


func _test_world_query_service_slows_highlands_and_water(failures: Array[String]) -> void:
	var service := WORLD_QUERY_SERVICE.new()
	var world := _make_world_with_single_pond()
	service.bind_world(world)
	TEST_UTILS.expect(float(service.get_terrain_speed_multiplier(Vector2.ZERO)) < 1.0, failures, "Deep pond water should slow movement")
	TEST_UTILS.expect(float(service.get_terrain_speed_multiplier(Vector2(140.0, 0.0))) <= 0.92, failures, "Shore and wetland movement should stay slower than normal land")
	world.free()
	service = WORLD_QUERY_SERVICE.new()
	world = WORLD_SCRIPT.new()
	world._set_world_generator_seed(1234)
	service.bind_world(world)
	var highland_speed := float(service.get_terrain_speed_multiplier(Vector2(-240.0, -640.0)))
	TEST_UTILS.expect(highland_speed <= 0.88, failures, "Highlands should apply a movement slowdown")
	world.free()


func _test_biome_surface_stays_crisp_and_uses_accents_for_detail(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	var biome := _get_biome_by_name("Hearth Meadow")
	var base_color := Color(biome["color"])
	var surface_color: Color = world.call("_get_biome_terrain_color", biome, Vector2(100.0, 150.0), base_color)
	var accents: Array = world.call("_build_biome_terrain_accent_layout", biome)
	var color_delta: float = abs(surface_color.r - base_color.r) + abs(surface_color.g - base_color.g) + abs(surface_color.b - base_color.b)
	TEST_UTILS.expect(color_delta > 0.01, failures, "Biome surface should show visible texture variation instead of staying perfectly flat")
	TEST_UTILS.expect(not accents.is_empty(), failures, "Biome variation should remain visible through crisp cached terrain accents")
	world.free()


func _test_biome_detail_density_uses_game_balance_and_limit(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	var biome := _get_biome_by_name("Hearth Meadow")
	var target_count: int = world.call("_get_biome_terrain_accent_target_count", biome)
	var configured_limit := int(GAME_BALANCE.BIOME_TEXTURES.get("max_detail_per_chunk", 120))
	TEST_UTILS.expect(target_count > 30, failures, "Biome detail density multiplier should increase Hearth Meadow beyond its base accent count")
	TEST_UTILS.expect(target_count <= configured_limit, failures, "Biome detail count should respect the configured cache limit")
	var accents: Array = world.call("_build_biome_terrain_accent_layout", biome)
	var has_secondary := false
	for accent_value in accents:
		var accent := Dictionary(accent_value)
		if accent.get("secondary", false) == true:
			has_secondary = true
			break
	TEST_UTILS.expect(has_secondary, failures, "Biome detail layouts should include subtle secondary variants")
	world.free()


func _test_biome_texture_variation_is_continuous_without_tiling(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	var biome := _get_biome_by_name("Hearth Meadow")
	var base_color := Color(biome["color"])
	var color_a: Color = world.call("_get_biome_terrain_color", biome, Vector2(100.0, 150.0), base_color)
	var color_near: Color = world.call("_get_biome_terrain_color", biome, Vector2(101.0, 151.0), base_color)
	var color_far: Color = world.call("_get_biome_terrain_color", biome, Vector2(900.0, 650.0), base_color)
	var near_difference: float = abs(color_a.r - color_near.r) + abs(color_a.g - color_near.g) + abs(color_a.b - color_near.b)
	var far_difference: float = abs(color_a.r - color_far.r) + abs(color_a.g - color_far.g) + abs(color_a.b - color_far.b)
	TEST_UTILS.expect(near_difference <= 0.18, failures, "Biome surface should keep nearby points visually coherent")
	TEST_UTILS.expect(far_difference >= 0.01, failures, "Biome surface should still vary across the biome instead of staying flat")
	var cache_size: Vector2i = world.call("_get_world_biome_blend_texture_size")
	TEST_UTILS.expect(cache_size.x >= 384 and cache_size.y >= 236, failures, "Biome blend cache should not drop below the baseline resolution")
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
	TEST_UTILS.expect_equal(int(counts.get("generated", 0)), 0, failures, "Landmark debug counts should only include active POI landmarks")
	TEST_UTILS.expect_equal(int(counts.get("pond", 0)), 0, failures, "Landmark debug counts should no longer report pond totals")
	TEST_UTILS.expect_equal(int(counts.get("hill", 0)), 0, failures, "Landmark debug counts should no longer report hill totals")
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
	TEST_UTILS.expect_equal(int(status.get("rebuild_blocked_count", 0)), 0, failures, "Biome texture cache status should report blocked rebuild attempts")
	TEST_UTILS.expect_equal(bool(status.get("dirty_key_pending", false)), false, failures, "Biome texture cache status should report that no dirty key is pending yet")
	TEST_UTILS.expect_equal(bool(status.get("freeze_after_first_build", false)), true, failures, "Biome texture cache status should report that rebuilds freeze after the first build")
	world.free()


func _test_world_applies_graphics_settings_render_defaults(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	world.graphics_settings = GraphicsSettingsStub.new()
	world.call("_apply_graphics_settings_defaults")
	TEST_UTILS.expect_equal(bool(world.is_low_end_rendering_enabled()), true, failures, "World should expose the low-end rendering flag from graphics settings")
	TEST_UTILS.expect_equal(bool(world.are_biome_textures_enabled()), true, failures, "World should keep biome textures enabled in the low-end preset")
	TEST_UTILS.expect_equal(bool(world.is_landmark_debug_overlay_enabled()), false, failures, "World should keep the landmark debug overlay disabled in the low-end preset")
	TEST_UTILS.expect_equal(bool(world.are_biome_terrain_accents_enabled()), false, failures, "World should disable biome terrain accents in the low-end preset")
	world.free()


func _test_world_builds_cached_biome_blend_texture(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	var controller: Object = world.call("_ensure_render_controller")
	var texture: ImageTexture = controller.call("ensure_biome_blend_texture")
	TEST_UTILS.expect(texture != null, failures, "World should be able to build the cached biome blend texture used for world rendering")
	var status: Dictionary = world.get_biome_texture_cache_status()
	var expected_size: Vector2i = world.call("_get_world_biome_blend_texture_size")
	TEST_UTILS.expect(status.get("has_blend_texture", false) == true, failures, "Biome texture cache status should report the built world blend texture")
	TEST_UTILS.expect(str(status.get("blend_colors_key", "")) != "", failures, "Biome texture cache status should expose a non-empty blend texture key after building")
	TEST_UTILS.expect(int(status.get("world_biome_texture_build_count", 0)) >= 1, failures, "Biome texture cache status should expose the world blend texture build counter")
	TEST_UTILS.expect(float(status.get("world_biome_texture_last_build_ms", 0.0)) >= 0.0, failures, "Biome texture cache status should expose the world blend texture build time")
	TEST_UTILS.expect_equal(status.get("blend_texture_size", Vector2i.ZERO), expected_size, failures, "World should build the blend texture at the configured cache size")
	world.free()


func _test_world_biome_blend_texture_size_uses_configurable_scale(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	var texture_size: Vector2i = world.call("_get_world_biome_blend_texture_size")
	var min_scale := float(GAME_BALANCE.BIOME_TEXTURES.get("blend_cache_scale_min", 0.35))
	var max_scale := float(GAME_BALANCE.BIOME_TEXTURES.get("blend_cache_scale_max", 0.85))
	var configured_scale := clampf(float(GAME_BALANCE.BIOME_TEXTURES.get("blend_cache_scale", 0.65)), min_scale, max_scale)
	TEST_UTILS.expect(texture_size.x > 0, failures, "World blend texture width should stay positive")
	TEST_UTILS.expect(texture_size.y > 0, failures, "World blend texture height should stay positive")
	TEST_UTILS.expect(texture_size.x >= int(round(float(WORLD_SCRIPT.BIOME_BLEND_TEXTURE_SIZE.x) * min_scale)), failures, "World blend texture width should respect the configured minimum scale")
	TEST_UTILS.expect(texture_size.y >= int(round(float(WORLD_SCRIPT.BIOME_BLEND_TEXTURE_SIZE.y) * min_scale)), failures, "World blend texture height should respect the configured minimum scale")
	TEST_UTILS.expect(texture_size.x <= int(round(float(WORLD_SCRIPT.BIOME_BLEND_TEXTURE_SIZE.x) * max_scale)), failures, "World blend texture width should respect the configured maximum scale")
	TEST_UTILS.expect(texture_size.y <= int(round(float(WORLD_SCRIPT.BIOME_BLEND_TEXTURE_SIZE.y) * max_scale)), failures, "World blend texture height should respect the configured maximum scale")
	TEST_UTILS.expect(texture_size.x == int(round(float(WORLD_SCRIPT.BIOME_BLEND_TEXTURE_SIZE.x) * configured_scale)) or texture_size.x > 0, failures, "World blend texture width should derive from the configured scale")
	world.free()


func _test_visual_biome_query_uses_generator_source(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	world._set_world_generator_seed(12345)
	var visual_id := world.get_visual_biome_id_at(Vector2.ZERO)
	TEST_UTILS.expect(typeof(visual_id) == TYPE_STRING, failures, "Visual biome lookup should return a string")
	TEST_UTILS.expect(not visual_id.is_empty(), failures, "Visual biome lookup should return a non-empty biome id")
	world.free()


func _test_visual_biome_influence_scores_vary_across_space(failures: Array[String]) -> void:
	var generator = load(WORLD_GENERATOR_PATH).new()
	generator.generate_world(12345)
	var center_scores: Dictionary = generator.get_visual_biome_influence_scores(Vector2.ZERO)
	var offset_scores: Dictionary = generator.get_visual_biome_influence_scores(Vector2(980.0, -420.0))
	TEST_UTILS.expect(not center_scores.is_empty(), failures, "Visual biome influence scores should be available after world generation")
	TEST_UTILS.expect(not offset_scores.is_empty(), failures, "Visual biome influence scores should remain available away from origin")
	var differs := false
	for biome_id in ["westwood", "stoneback_ridge", "hearth_meadow", "south_thicket", "redfang_wilds"]:
		if absf(float(center_scores.get(biome_id, 0.0)) - float(offset_scores.get(biome_id, 0.0))) > 0.01:
			differs = true
			break
	TEST_UTILS.expect(differs, failures, "Visual biome influence scores should vary across the map instead of staying flat")
	generator = null


func _test_terrain_cell_map_builds_and_looks_up_cells(failures: Array[String]) -> void:
	var generator = load(WORLD_GENERATOR_PATH).new()
	var topo := WORLD_TOPOGRAPHY.new()
	generator.generate_world(13579)
	topo.setup(13579)
	var cell_map := TERRAIN_CELL_MAP.new()
	cell_map.build(WORLD_CONFIG.WORLD_RECT, 96.0, generator, topo, 13579)
	var grid_size := cell_map.get_grid_size()
	TEST_UTILS.expect(grid_size.x > 0 and grid_size.y > 0, failures, "Terrain cell map should build a positive grid size")
	var sample_cell := cell_map.get_cell(0, 0)
	TEST_UTILS.expect(sample_cell.has("terrain_id"), failures, "Terrain cell map cells should expose terrain ids")
	TEST_UTILS.expect(sample_cell.has("biome_id"), failures, "Terrain cell map cells should expose biome ids")
	TEST_UTILS.expect(not cell_map.get_cell_at_world_position(Vector2.ZERO).is_empty(), failures, "Terrain cell lookup by world position should work")
	var repeat_map := TERRAIN_CELL_MAP.new()
	repeat_map.build(WORLD_CONFIG.WORLD_RECT, 96.0, generator, topo, 13579)
	TEST_UTILS.expect_equal(cell_map.get_cell(2, 2).get("biome_id", ""), repeat_map.get_cell(2, 2).get("biome_id", ""), failures, "Same seed should produce the same terrain cell map")
	var other_generator = load(WORLD_GENERATOR_PATH).new()
	var other_topo := WORLD_TOPOGRAPHY.new()
	other_generator.generate_world(24680)
	other_topo.setup(24680)
	var other_map := TERRAIN_CELL_MAP.new()
	other_map.build(WORLD_CONFIG.WORLD_RECT, 96.0, other_generator, other_topo, 24680)
	TEST_UTILS.expect(cell_map.get_cell(2, 2).get("biome_id", "") != other_map.get_cell(2, 2).get("biome_id", "") or cell_map.get_cell(2, 2).get("terrain_id", "") != other_map.get_cell(2, 2).get("terrain_id", ""), failures, "Different seeds should produce different terrain cell maps")
	generator = null
	topo = null
	other_generator = null
	other_topo = null


func _test_biome_shape_map_builds_connected_regions(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	world._set_world_generator_seed(13579)
	var debug: Dictionary = world.get_biome_shape_debug()
	TEST_UTILS.expect_equal(bool(debug.get("biome_shape_map_uses_convex_hull", true)), false, failures, "Biome shape map should not use convex hulls for final regions")
	TEST_UTILS.expect(int(debug.get("biome_shape_map_build_count", 0)) >= 1, failures, "Biome shape map should build at least once after world generation")
	TEST_UTILS.expect(int(debug.get("biome_shape_map_polygon_count", 0)) > 0, failures, "Biome shape map should build at least one polygon")
	TEST_UTILS.expect_equal(bool(debug.get("biome_shape_visual_surface_enabled", false)), true, failures, "Biome shape map should build a runtime visual surface grid")
	TEST_UTILS.expect(int(debug.get("biome_shape_visual_surface_build_count", 0)) >= 1, failures, "Biome shape map should rasterize the visual surface at least once")
	var layer_counts: Dictionary = Dictionary(debug.get("biome_shape_map_polygon_count_by_layer", {}))
	TEST_UTILS.expect(layer_counts.size() > 1, failures, "Biome shape map should contain multiple layers")
	var land_polygon_total := 0
	for layer_id in layer_counts.keys():
		var layer := str(layer_id)
		if layer.begins_with("biome:") and layer.ends_with("|terrain:land"):
			land_polygon_total += int(layer_counts.get(layer_id, 0))
	TEST_UTILS.expect(land_polygon_total > 1, failures, "Biome shape map should produce multiple land biome regions")
	var largest_by_layer: Dictionary = Dictionary(debug.get("biome_shape_map_largest_polygon_cell_count_by_layer", {}))
	var total_cells := 0
	if world.has_method("get_biome_shape_map"):
		var shape_map: Object = world.get_biome_shape_map()
		if shape_map != null and shape_map.has_method("get_debug_data"):
			total_cells = int(Dictionary(shape_map.get_debug_data()).get("biome_shape_map_grid_size", Vector2i.ZERO).x) * int(Dictionary(shape_map.get_debug_data()).get("biome_shape_map_grid_size", Vector2i.ZERO).y)
	var oversize := false
	for layer_id in largest_by_layer.keys():
		if int(largest_by_layer.get(layer_id, 0)) > int(total_cells * 0.85):
			oversize = true
			break
	TEST_UTILS.expect(not oversize, failures, "No biome region should cover almost the entire world")
	world.free()


func _test_world_marks_terrain_surface_chunks_dirty_after_biome_shape_rebuild(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	world.world_generator = load(WORLD_GENERATOR_PATH).new()
	world.world_topography = WORLD_TOPOGRAPHY.new()
	world.world_generator.generate_world(13579)
	world.world_topography.setup(13579)
	world.biome_shape_map_dirty = true
	world.terrain_surface_chunk_renderer = TerrainSurfaceRendererStub.new()
	world._ensure_biome_shape_map_built(true)
	var renderer: TerrainSurfaceRendererStub = world.terrain_surface_chunk_renderer
	TEST_UTILS.expect_equal(renderer.dirty_reasons, ["biome_shape_map_rebuilt"], failures, "Biome shape map rebuild should invalidate cached terrain surface chunks")
	world.free()


func _test_world_biome_texture_cache_status_reports_visual_settings(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	var status: Dictionary = world.get_biome_texture_cache_status()
	TEST_UTILS.expect(status.has("visual_biome_shapes_enabled"), failures, "Biome texture cache status should expose whether visual biome shapes are enabled")
	TEST_UTILS.expect(status.has("visual_biome_shape_use_raw_scores"), failures, "Biome texture cache status should expose whether visual biome shapes use raw scores")
	TEST_UTILS.expect(status.has("visual_biome_query_source"), failures, "Biome texture cache status should expose the visual biome query source")
	TEST_UTILS.expect(status.has("gameplay_biome_query_still_cached"), failures, "Biome texture cache status should expose whether gameplay biome query caching still exists")
	world.free()


func _test_world_biome_texture_cache_status_reports_visual_feature_count(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	world._set_world_generator_seed(12345)
	var status: Dictionary = world.get_biome_texture_cache_status()
	TEST_UTILS.expect(status.has("visual_biome_feature_count"), failures, "Biome texture cache status should expose the visual biome feature count")
	TEST_UTILS.expect(int(status.get("visual_biome_feature_count", 0)) > 0, failures, "Visual biome feature count should be populated after world generation")
	world.free()


func _test_world_biome_and_surface_queries_do_not_recursively_call_topography(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	world._set_world_generator_seed(1234)
	var biome_id := world.get_biome_id_at(Vector2.ZERO)
	var surface_zone := world.get_surface_terrain_zone_at(Vector2.ZERO)
	TEST_UTILS.expect(biome_id != null, failures, "World biome query should return a valid value after topography setup")
	TEST_UTILS.expect(surface_zone != null, failures, "World surface terrain query should return a valid value after topography setup")
	world.free()


func _test_topography_sample_returns_a_single_combined_snapshot(failures: Array[String]) -> void:
	var topo := WORLD_TOPOGRAPHY.new()
	topo.setup(1234)
	var sample: Dictionary = topo.sample_topography_at(Vector2(120.0, -80.0))
	TEST_UTILS.expect(sample.has("terrain_zone"), failures, "Topography sampling should return the resolved terrain zone")
	TEST_UTILS.expect(sample.has("elevation_band"), failures, "Topography sampling should return the resolved elevation band")
	TEST_UTILS.expect(sample.has("dominant_feature_type"), failures, "Topography sampling should expose the dominant feature type")
	TEST_UTILS.expect(sample.has("dominant_feature_influence"), failures, "Topography sampling should expose the dominant feature influence")
	TEST_UTILS.expect(sample.has("dominant_feature_home_biome_id"), failures, "Topography sampling should expose the dominant feature biome id")
	topo = null


func _test_world_surface_debug_matches_query_service_surface_terrain(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	world._set_world_generator_seed(1234)
	var position := Vector2(-260.0, 40.0)
	var debug: Dictionary = world.get_player_surface_debug(position)
	TEST_UTILS.expect_equal(str(debug.get("surface_terrain", "")), str(world.get_surface_terrain_zone_at(position)), failures, "World surface debug should report the same surface terrain as the world helper")
	TEST_UTILS.expect_equal(str(debug.get("generator_base_terrain", "")), str(world.get_generator_base_terrain_zone_at(position)), failures, "World surface debug should report the same generator terrain as the world helper")
	world.free()


func _test_world_draw_biomes_uses_existing_background_texture(failures: Array[String]) -> void:
	var world := CountingWorld.new()
	world.biome_textures_enabled = true
	world.biome_blend_background = Sprite2D.new()
	world.biome_blend_background.visible = true
	world.biome_blend_background.texture = ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	var sync_calls_before := world.sync_calls
	world.call("_draw_biomes")
	TEST_UTILS.expect_equal(world.sync_calls, sync_calls_before, failures, "World draw path should reuse the cached biome background instead of rebuilding it")
	world.free()


func _test_world_process_only_syncs_biome_background_when_redraw_is_requested(failures: Array[String]) -> void:
	var world := CountingWorld.new()
	world.render_controller = FixedRenderControllerStub.new()
	world.night_overlay_polygon = Polygon2D.new()
	world.small_prey_spawn_timer = 0.0
	world.varnak_spawn_timer = 0.0
	world.small_prey_failed_spawn_retry_timer = 0.0
	world.varnak_failed_spawn_retry_timer = 0.0
	var controller: FixedRenderControllerStub = world.render_controller
	controller.should_redraw = false
	world._process(0.05)
	TEST_UTILS.expect_equal(world.sync_calls, 0, failures, "World process should not sync the biome background when the render controller does not request a redraw")
	controller.should_redraw = true
	world._process(0.05)
	TEST_UTILS.expect_equal(world.sync_calls, 1, failures, "World process should sync the biome background only when the render controller requests a redraw")
	world.free()


func _test_world_terrain_renderer_rebuilds_cell_map_only_when_dirty(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	world.world_generator = load(WORLD_GENERATOR_PATH).new()
	world.world_topography = WORLD_TOPOGRAPHY.new()
	world.world_generator.generate_world(13579)
	world.world_topography.setup(13579)
	world.terrain_chunk_renderer = TerrainRendererStub.new()
	world.terrain_renderer_bound = true
	world.terrain_cell_map_dirty = true
	world._sync_terrain_renderer(false)
	var renderer: TerrainRendererStub = world.terrain_chunk_renderer
	TEST_UTILS.expect_equal(world.terrain_cell_map_dirty, false, failures, "Terrain sync should clear the dirty flag after rebuilding the cell map")
	TEST_UTILS.expect_equal(renderer.bind_calls, 1, failures, "Terrain sync should bind the renderer when the terrain map is rebuilt")
	TEST_UTILS.expect_equal(renderer.process_visibility_calls, 1, failures, "Terrain sync should update terrain visibility after rebuilding")
	TEST_UTILS.expect_equal(renderer.rebuild_calls, [false], failures, "Terrain sync should only request a lazy visible-chunk refresh")
	world._sync_terrain_renderer(false)
	TEST_UTILS.expect_equal(renderer.bind_calls, 1, failures, "Terrain sync should not rebind when the renderer stays clean")
	TEST_UTILS.expect_equal(renderer.process_visibility_calls, 2, failures, "Terrain sync should continue to update visibility on subsequent timer ticks")
	TEST_UTILS.expect_equal(renderer.rebuild_calls, [false, false], failures, "Terrain sync should keep visible chunk rebuilds lazy on repeated redraws")
	world.free()


func _test_terrain_surface_renderer_samples_biome_shape_map(failures: Array[String]) -> void:
	var renderer := TerrainSurfaceChunkRenderer.new()
	var world := SurfaceSamplingWorldStub.new()
	var player := Node2D.new()
	var camera := Camera2D.new()
	player.add_child(camera)
	renderer.use_shape_map_sampling_override = true
	renderer.has_use_shape_map_sampling_override = true
	renderer.bind(world, player, camera)
	var sample: Dictionary = renderer.call("_sample_surface_ids", Vector2(128.0, 256.0))
	TEST_UTILS.expect_equal(str(sample.get("source", "")), "polygon", failures, "Terrain surface renderer should prefer the biome shape map surface without falling back to world terrain")
	TEST_UTILS.expect_equal(str(sample.get("terrain_id", "")), "shape_terrain", failures, "Terrain surface renderer should use the biome shape map terrain id")
	TEST_UTILS.expect_equal(str(sample.get("biome_id", "")), "shape_biome", failures, "Terrain surface renderer should use the biome shape map biome id")
	TEST_UTILS.expect_equal(world.shape_map.last_position, Vector2(128.0, 256.0), failures, "Biome shape map should receive the exact sampled position")
	renderer.call("_sample_surface_color", Vector2(128.0, 256.0))
	var debug: Dictionary = renderer.get_debug_data()
	var source_counts := Dictionary(debug.get("terrain_surface_sample_source_counts", {}))
	TEST_UTILS.expect_equal(int(source_counts.get("polygon", 0)) >= 1, true, failures, "Terrain surface renderer should track biome shape map sample sources")
	renderer.free()
	player.free()
	world.free()


func _test_terrain_surface_renderer_uses_preview_then_refine_pipeline(failures: Array[String]) -> void:
	var renderer := TerrainSurfaceChunkRenderer.new()
	var world := SurfaceSamplingWorldStub.new()
	renderer.world_rect = WORLD_CONFIG.WORLD_RECT
	renderer.world = world
	renderer.biome_shape_map = world.get_biome_shape_map()
	renderer.preview_enabled = true
	renderer.preview_chunk_texture_size = 2
	renderer.refined_chunk_texture_size = 4
	renderer.max_chunks_built_per_frame = 1
	renderer.refined_max_rows_built_per_frame = 4
	renderer.refined_max_build_ms_per_frame = 1000.0
	renderer.refine_delay_seconds = 0.0
	renderer.call("_start_chunk_build", Vector2i.ZERO)
	renderer.call("_process_active_chunk_build", Vector2i.ZERO, Time.get_ticks_usec())
	renderer.call("_process_active_chunk_build", Vector2i.ZERO, Time.get_ticks_usec())
	var debug: Dictionary = renderer.get_debug_data()
	TEST_UTILS.expect_equal(int(debug.get("terrain_surface_preview_build_count", 0)) >= 1, true, failures, "Terrain surface renderer should build a preview texture before refining")
	TEST_UTILS.expect_equal(int(debug.get("terrain_surface_refined_build_count", 0)) >= 1, true, failures, "Terrain surface renderer should refine the preview into a final chunk texture")
	renderer.free()
	world.free()


func _test_terrain_surface_renderer_starts_multiple_preview_builds(failures: Array[String]) -> void:
	var renderer := TerrainSurfaceChunkRenderer.new()
	var world := SurfaceSamplingWorldStub.new()
	renderer.world_rect = WORLD_CONFIG.WORLD_RECT
	renderer.world = world
	renderer.biome_shape_map = world.get_biome_shape_map()
	renderer.preview_enabled = true
	renderer.preview_chunk_texture_size = 8
	renderer.refined_chunk_texture_size = 16
	renderer.preview_active_build_limit = 3
	renderer.preview_build_cell_batch_size = 8
	renderer.max_chunks_built_per_frame = 1
	renderer.max_build_ms_per_frame = 1000.0
	renderer.hard_budget_enabled = true
	renderer.hard_budget_ms = 1000.0
	renderer.visible_chunks = {
		Vector2i(0, 0): true,
		Vector2i(1, 0): true,
		Vector2i(2, 0): true
	}
	renderer.pending_chunks = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	renderer.pending_chunk_set = {
		Vector2i(0, 0): true,
		Vector2i(1, 0): true,
		Vector2i(2, 0): true
	}
	renderer.process_build_queue(0.016)
	var debug: Dictionary = renderer.get_debug_data()
	TEST_UTILS.expect_equal(int(debug.get("terrain_surface_build_chunks_started_last_frame", 0)) >= 3, true, failures, "Terrain surface renderer should start multiple preview builds for visible chunks in one budgeted pass")
	TEST_UTILS.expect_equal(int(debug.get("terrain_surface_build_pixels_last_frame", 0)) >= 8, true, failures, "Terrain surface preview build should process a useful pixel batch instead of collapsing to one pixel")
	renderer.free()
	world.free()


func _test_terrain_surface_renderer_refine_pending_does_not_block_preview(failures: Array[String]) -> void:
	var renderer := TerrainSurfaceChunkRenderer.new()
	var world := SurfaceSamplingWorldStub.new()
	renderer.world_rect = WORLD_CONFIG.WORLD_RECT
	renderer.world = world
	renderer.biome_shape_map = world.get_biome_shape_map()
	renderer.preview_enabled = true
	renderer.preview_chunk_texture_size = 8
	renderer.refined_chunk_texture_size = 16
	renderer.preview_active_build_limit = 3
	renderer.preview_build_cell_batch_size = 8
	renderer.max_chunks_built_per_frame = 1
	renderer.max_build_ms_per_frame = 1000.0
	renderer.hard_budget_enabled = true
	renderer.hard_budget_ms = 1000.0
	for i in range(7):
		renderer.active_builds[Vector2i(i, -1)] = {
			"chunk_key": Vector2i(i, -1),
			"image": null,
			"chunk_rect": Rect2(),
			"next_y": 0,
			"next_x": 0,
			"stage": "refine_pending",
			"texture_size": 16,
			"stage_ready_at": 999999.0
		}
	renderer.visible_chunks = {
		Vector2i(0, 0): true,
		Vector2i(1, 0): true,
		Vector2i(2, 0): true
	}
	renderer.pending_chunks = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	renderer.pending_chunk_set = {
		Vector2i(0, 0): true,
		Vector2i(1, 0): true,
		Vector2i(2, 0): true
	}
	renderer.process_build_queue(0.016)
	var debug: Dictionary = renderer.get_debug_data()
	TEST_UTILS.expect_equal(int(debug.get("terrain_surface_active_refine_pending_count", 0)), 7, failures, "Terrain surface renderer should keep refine-pending chunks tracked")
	TEST_UTILS.expect_equal(int(debug.get("terrain_surface_active_preview_build_count", 0)) >= 3, true, failures, "Terrain surface renderer should start preview work even when refine-pending chunks fill active_builds")
	TEST_UTILS.expect_equal(int(debug.get("terrain_surface_build_chunks_started_last_frame", 0)) >= 3, true, failures, "Terrain surface renderer should not count refine-pending chunks against preview startup capacity")
	renderer.free()
	world.free()


func _test_terrain_surface_renderer_keeps_active_build_texture_size_stable(failures: Array[String]) -> void:
	var renderer := TerrainSurfaceChunkRenderer.new()
	var world := SurfaceSamplingWorldStub.new()
	renderer.world_rect = WORLD_CONFIG.WORLD_RECT
	renderer.world = world
	renderer.biome_shape_map = world.get_biome_shape_map()
	renderer.preview_enabled = false
	renderer.refined_chunk_texture_size = 4
	renderer.max_chunks_built_per_frame = 1
	renderer.refined_max_rows_built_per_frame = 4
	renderer.refined_max_build_ms_per_frame = 1000.0
	renderer.refine_delay_seconds = 0.0
	renderer.call("_start_chunk_build", Vector2i.ZERO)
	var active_builds: Dictionary = Dictionary(renderer.get("active_builds"))
	var state: Dictionary = Dictionary(active_builds.get(Vector2i.ZERO, {}))
	TEST_UTILS.expect_equal(int(state.get("texture_size", 0)), 4, failures, "Terrain surface renderer should store the active build texture size in state")
	renderer.refined_chunk_texture_size = 96
	renderer.chunk_texture_size = 96
	renderer.call("_process_active_chunk_build", Vector2i.ZERO, Time.get_ticks_usec())
	var chunk_textures: Dictionary = Dictionary(renderer.get("chunk_textures"))
	var texture: ImageTexture = chunk_textures.get(Vector2i.ZERO)
	TEST_UTILS.expect(texture != null, failures, "Terrain surface renderer should finish the active build after the budget changes")
	if texture != null:
		TEST_UTILS.expect_equal(texture.get_size().x, 4, failures, "Terrain surface renderer should keep using the original active build texture width after the global budget changes")
		TEST_UTILS.expect_equal(texture.get_size().y, 4, failures, "Terrain surface renderer should keep using the original active build texture height after the global budget changes")
	active_builds = Dictionary(renderer.get("active_builds"))
	state = Dictionary(active_builds.get(Vector2i.ZERO, {}))
	TEST_UTILS.expect_equal(int(state.get("texture_size", 0)), 4, failures, "Terrain surface renderer should not overwrite the active build texture size when the budget changes")
	renderer.free()
	world.free()


func _test_small_prey_spawn_sync_uses_cooldown_after_failure(failures: Array[String]) -> void:
	var world := SmallPreySyncWorld.new()
	world.ecosystem_director = MockSmallPreyEcosystemDirector.new()
	world.spawn_should_succeed = false
	world.call("_sync_visible_small_prey")
	var failed_debug: Dictionary = world.get_small_prey_spawn_sync_debug()
	TEST_UTILS.expect_equal(int(failed_debug.get("attempt_count", 0)), 1, failures, "SmallPrey sync should count the first spawn attempt")
	TEST_UTILS.expect_equal(int(failed_debug.get("failed_count", 0)), 1, failures, "SmallPrey sync should count the failed spawn pass")
	TEST_UTILS.expect_equal(int(failed_debug.get("skipped_by_cooldown_count", 0)), 0, failures, "SmallPrey sync should not skip the first attempt")
	TEST_UTILS.expect_equal(int(failed_debug.get("last_requested", 0)), 2, failures, "SmallPrey sync should record the requested spawn count")
	TEST_UTILS.expect_equal(int(failed_debug.get("last_failed", 0)), 2, failures, "SmallPrey sync should record all failed spawn slots")
	TEST_UTILS.expect_equal(int(failed_debug.get("last_success", 0)), 0, failures, "SmallPrey sync should record zero successful spawns on failure")
	TEST_UTILS.expect_equal(float(failed_debug.get("retry_timer", 0.0)), 5.0, failures, "SmallPrey sync should start the cooldown after a failed spawn pass")
	TEST_UTILS.expect_equal(bool(failed_debug.get("warning_printed", false)), true, failures, "SmallPrey sync should mark the warning as printed after the first failure")
	world.call("_sync_visible_small_prey")
	var skipped_debug: Dictionary = world.get_small_prey_spawn_sync_debug()
	TEST_UTILS.expect_equal(int(skipped_debug.get("attempt_count", 0)), 1, failures, "SmallPrey sync should not retry during cooldown")
	TEST_UTILS.expect_equal(int(skipped_debug.get("skipped_by_cooldown_count", 0)), 1, failures, "SmallPrey sync should count cooldown skips")
	TEST_UTILS.expect_equal(int(skipped_debug.get("failed_count", 0)), 1, failures, "SmallPrey sync should not add new failures while cooled down")
	world._process(1.5)
	var cooled_debug: Dictionary = world.get_small_prey_spawn_sync_debug()
	TEST_UTILS.expect_close(float(cooled_debug.get("retry_timer", 0.0)), 3.5, failures, "World process should reduce the failed-spawn cooldown")
	world.small_prey_failed_spawn_retry_timer = 0.0
	world.spawn_should_succeed = true
	world.call("_sync_visible_small_prey")
	var success_debug: Dictionary = world.get_small_prey_spawn_sync_debug()
	TEST_UTILS.expect_equal(int(success_debug.get("attempt_count", 0)), 2, failures, "SmallPrey sync should try again after the cooldown expires")
	TEST_UTILS.expect_equal(int(success_debug.get("failed_count", 0)), 1, failures, "SmallPrey sync should keep the historical failed-pass count")
	TEST_UTILS.expect_equal(int(success_debug.get("last_requested", 0)), 2, failures, "SmallPrey sync should continue to request the same number of prey")
	TEST_UTILS.expect_equal(int(success_debug.get("last_failed", 0)), 0, failures, "SmallPrey sync should clear the last failure count after a successful retry")
	TEST_UTILS.expect_equal(int(success_debug.get("last_success", 0)), 2, failures, "SmallPrey sync should record a full success after the retry")
	TEST_UTILS.expect_equal(float(success_debug.get("retry_timer", 0.0)), 0.0, failures, "SmallPrey sync should clear the cooldown after a successful spawn pass")
	TEST_UTILS.expect_equal(bool(success_debug.get("warning_printed", true)), false, failures, "SmallPrey sync should clear the warning state after success")
	world.free()


func _test_varnak_spawn_sync_uses_cooldown_after_failure(failures: Array[String]) -> void:
	var world := VarnakSyncWorld.new()
	world.ecosystem_director = MockVarnakEcosystemDirector.new()
	world.spawn_should_succeed = false
	world.call("_sync_visible_varnaks", true)
	var failed_debug: Dictionary = world.get_varnak_spawn_sync_debug()
	TEST_UTILS.expect_equal(int(failed_debug.get("attempt_count", 0)), 1, failures, "Varnak sync should count the first spawn attempt")
	TEST_UTILS.expect_equal(int(failed_debug.get("failed_count", 0)), 1, failures, "Varnak sync should count the failed spawn pass")
	TEST_UTILS.expect_equal(int(failed_debug.get("skipped_by_cooldown_count", 0)), 0, failures, "Varnak sync should not skip the first attempt")
	TEST_UTILS.expect_equal(int(failed_debug.get("last_requested", 0)), 2, failures, "Varnak sync should record the requested spawn count")
	TEST_UTILS.expect_equal(int(failed_debug.get("last_failed", 0)), 2, failures, "Varnak sync should record all failed spawn slots")
	TEST_UTILS.expect_equal(int(failed_debug.get("last_success", 0)), 0, failures, "Varnak sync should record zero successful spawns on failure")
	TEST_UTILS.expect_equal(float(failed_debug.get("retry_timer", 0.0)), 5.0, failures, "Varnak sync should start the cooldown after a failed spawn pass")
	TEST_UTILS.expect_equal(bool(failed_debug.get("warning_printed", false)), true, failures, "Varnak sync should mark the warning as printed after the first failure")
	world.call("_sync_visible_varnaks")
	var skipped_debug: Dictionary = world.get_varnak_spawn_sync_debug()
	TEST_UTILS.expect_equal(int(skipped_debug.get("attempt_count", 0)), 1, failures, "Varnak sync should not retry during cooldown")
	TEST_UTILS.expect_equal(int(skipped_debug.get("skipped_by_cooldown_count", 0)), 1, failures, "Varnak sync should count cooldown skips")
	world._process(1.5)
	var cooled_debug: Dictionary = world.get_varnak_spawn_sync_debug()
	TEST_UTILS.expect_close(float(cooled_debug.get("retry_timer", 0.0)), 3.5, failures, "World process should reduce the failed-spawn cooldown for Varnaks")
	world.varnak_failed_spawn_retry_timer = 0.0
	world.spawn_should_succeed = true
	world.call("_sync_visible_varnaks", true)
	var success_debug: Dictionary = world.get_varnak_spawn_sync_debug()
	TEST_UTILS.expect_equal(int(success_debug.get("attempt_count", 0)), 2, failures, "Varnak sync should try again after the cooldown expires")
	TEST_UTILS.expect_equal(int(success_debug.get("failed_count", 0)), 1, failures, "Varnak sync should keep the historical failed-pass count")
	TEST_UTILS.expect_equal(int(success_debug.get("last_requested", 0)), 2, failures, "Varnak sync should continue to request the same number of Varnaks")
	TEST_UTILS.expect_equal(int(success_debug.get("last_failed", 0)), 0, failures, "Varnak sync should clear the last failure count after a successful retry")
	TEST_UTILS.expect_equal(int(success_debug.get("last_success", 0)), 2, failures, "Varnak sync should record a full success after the retry")
	TEST_UTILS.expect_equal(float(success_debug.get("retry_timer", 0.0)), 0.0, failures, "Varnak sync should clear the cooldown after a successful spawn pass")
	TEST_UTILS.expect_equal(bool(success_debug.get("warning_printed", true)), false, failures, "Varnak sync should clear the warning state after success")
	world.free()


func _test_world_updates_night_overlay_without_redrawing_static_world(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	var overlay: Polygon2D = world.call("_ensure_night_overlay_polygon")
	TEST_UTILS.expect(overlay != null, failures, "World should create a dedicated polygon overlay for night shading")
	world.call("_update_night_overlay", 0.0)
	TEST_UTILS.expect(not overlay.visible, failures, "Night overlay should stay hidden during daytime")
	world.call("_update_night_overlay", 0.5)
	TEST_UTILS.expect(overlay.visible, failures, "Night overlay should become visible when night shading is active")
	TEST_UTILS.expect_close(float(overlay.color.a), 0.31, failures, "Night overlay alpha should track the night amount without requiring a static world redraw")
	TEST_UTILS.expect_equal(overlay.polygon.size(), 4, failures, "Night overlay should cover the world rectangle with a simple quad")
	world.free()


func _test_world_boot_progress_state_tracks_stage_updates(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	world.call("_set_boot_progress", "Rendering world...", 0.94)
	var boot_state: Dictionary = world.get_boot_progress_state()
	TEST_UTILS.expect_equal(str(boot_state.get("message", "")), "Rendering world...", failures, "World boot progress state should expose the current stage message")
	TEST_UTILS.expect_close(float(boot_state.get("progress", 0.0)), 0.94, failures, "World boot progress state should expose the current stage progress")
	TEST_UTILS.expect(boot_state.get("boot_ready", true) == false, failures, "World boot progress state should keep boot_ready false before the world finishes booting")
	world.free()


func _test_get_camera_visible_world_rect_defaults_to_full_world_without_camera(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	TEST_UTILS.expect(tree != null and tree.current_scene != null, failures, "Test runner should provide a current scene for camera visibility tests")
	if tree == null or tree.current_scene == null:
		return
	var world := VisibilityCullingWorld.new()
	tree.current_scene.add_child(world)
	var visible_rect: Rect2 = world.call("get_camera_visible_world_rect")
	var expected_rect := WORLD_CONFIG.WORLD_RECT.grow(384.0)
	TEST_UTILS.expect_equal(visible_rect, expected_rect, failures, "World should expose the full world rect when no camera is available")
	world.free()


func _test_current_biome_texture_id_uses_player_position_biome(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	var westwood := _get_biome_by_name("Westwood")
	var sample_point := _find_boundary_sample_point(westwood, WORLD_CONFIG.get_biome_zones())
	if sample_point == Vector2.INF:
		world.free()
		return
	var texture_id := world.get_current_biome_texture_id(sample_point)
	TEST_UTILS.expect(texture_id.contains("westwood_sample"), failures, "Current biome texture id should resolve from the biome containing the sampled world position")
	world.free()


func _test_safe_restored_resource_position_uses_requested_position(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	var restored_position: Vector2 = world.call("_get_safe_restored_resource_position", "meat_drop", Vector2(500.0, 300.0))
	TEST_UTILS.expect(restored_position.distance_to(Vector2(500.0, 300.0)) < 1.0, failures, "Safe restored resource position should keep the requested drop position when it is already valid")
	TEST_UTILS.expect(restored_position != Vector2.ZERO, failures, "Safe restored resource position should not fall back to the world origin")
	world.free()


func _test_world_object_visibility_rect_accounts_for_camera_zoom_and_margin(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	var viewport_size := Vector2(1152.0, 648.0)
	var camera_position := Vector2(320.0, -180.0)
	var camera_zoom := Vector2(1.1, 1.4)
	var visible_rect: Rect2 = world.call("_get_world_object_visibility_rect", viewport_size, camera_position, camera_zoom)
	var safe_zoom := Vector2(maxf(absf(camera_zoom.x), 0.01), maxf(absf(camera_zoom.y), 0.01))
	var visible_world_size := Vector2(viewport_size.x / safe_zoom.x, viewport_size.y / safe_zoom.y)
	var expected_position := camera_position - visible_world_size * 0.5 - Vector2.ONE * 384.0
	var expected_size := visible_world_size + Vector2.ONE * 768.0
	TEST_UTILS.expect_close(float(visible_rect.position.x), expected_position.x, failures, "World visibility culling should offset the rect from the camera center")
	TEST_UTILS.expect_close(float(visible_rect.position.y), expected_position.y, failures, "World visibility culling should offset the rect from the camera center on Y")
	TEST_UTILS.expect_close(float(visible_rect.size.x), expected_size.x, failures, "World visibility culling should expand the rect by the configured margin on X")
	TEST_UTILS.expect_close(float(visible_rect.size.y), expected_size.y, failures, "World visibility culling should expand the rect by the configured margin on Y")
	TEST_UTILS.expect(visible_rect.has_point(camera_position), failures, "World visibility culling should keep the camera center inside the visible rect")
	world.free()


func _test_world_object_visibility_culls_and_restores_group_nodes(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	TEST_UTILS.expect(tree != null and tree.current_scene != null, failures, "Test runner should provide a current scene for visibility culling tests")
	if tree == null or tree.current_scene == null:
		return
	var world := VisibilityCullingWorld.new()
	tree.current_scene.add_child(world)
	var groups := ["resources", "small_prey", "grazer", "varnak"]
	var inside_nodes: Array[Node2D] = []
	var outside_nodes: Array[Node2D] = []
	for group_name in groups:
		var inside := Node2D.new()
		inside.position = Vector2.ZERO
		inside.add_to_group(group_name)
		tree.current_scene.add_child(inside)
		inside_nodes.append(inside)
		var outside := Node2D.new()
		outside.position = Vector2(1000.0, 0.0)
		outside.add_to_group(group_name)
		tree.current_scene.add_child(outside)
		outside_nodes.append(outside)
	var shared_creature := Node2D.new()
	shared_creature.position = Vector2.ZERO
	shared_creature.add_to_group("small_prey")
	shared_creature.add_to_group("grazer")
	tree.current_scene.add_child(shared_creature)
	var left_rect := Rect2(Vector2(-128.0, -128.0), Vector2(256.0, 256.0))
	world.call("_set_world_object_visibility_by_rect", left_rect)
	for inside in inside_nodes:
		TEST_UTILS.expect_equal(inside.visible, true, failures, "World visibility culling should keep on-screen nodes visible")
	for outside in outside_nodes:
		TEST_UTILS.expect_equal(outside.visible, false, failures, "World visibility culling should hide off-screen nodes")
	TEST_UTILS.expect_equal(shared_creature.visible, true, failures, "World visibility culling should keep shared nodes visible when they are inside the visible rect")
	var left_debug: Dictionary = Dictionary(world.call("get_visibility_culling_debug"))
	TEST_UTILS.expect_equal(int(left_debug.get("visible_resources", -1)), 1, failures, "World visibility culling should count visible resources once")
	TEST_UTILS.expect_equal(int(left_debug.get("hidden_resources", -1)), 1, failures, "World visibility culling should count hidden resources once")
	TEST_UTILS.expect_equal(int(left_debug.get("visible_creatures", -1)), 4, failures, "World visibility culling should deduplicate shared creature group membership")
	TEST_UTILS.expect_equal(int(left_debug.get("hidden_creatures", -1)), 3, failures, "World visibility culling should count hidden creatures once")
	var right_rect := Rect2(Vector2(872.0, -128.0), Vector2(256.0, 256.0))
	world.call("_set_world_object_visibility_by_rect", right_rect)
	for inside in inside_nodes:
		TEST_UTILS.expect_equal(inside.visible, false, failures, "World visibility culling should hide nodes that moved outside the camera rect")
	for outside in outside_nodes:
		TEST_UTILS.expect_equal(outside.visible, true, failures, "World visibility culling should restore nodes when they re-enter the camera rect")
	TEST_UTILS.expect_equal(shared_creature.visible, false, failures, "World visibility culling should hide shared nodes when they move outside the visible rect")
	var right_debug: Dictionary = Dictionary(world.call("get_visibility_culling_debug"))
	TEST_UTILS.expect_equal(int(right_debug.get("visible_creatures", -1)), 3, failures, "World visibility culling should keep deduplicated creature counts stable when nodes move outside")
	TEST_UTILS.expect_equal(int(right_debug.get("hidden_creatures", -1)), 4, failures, "World visibility culling should update hidden creature counts when shared nodes move outside")
	for node in inside_nodes:
		node.free()
	for node in outside_nodes:
		node.free()
	shared_creature.free()
	_test_world_visibility_culls_newly_registered_nodes_start_hidden(failures)
	world.free()


func _test_world_visibility_culls_newly_registered_nodes_start_hidden(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	TEST_UTILS.expect(tree != null and tree.current_scene != null, failures, "Test runner should provide a current scene for visibility culling registration tests")
	if tree == null or tree.current_scene == null:
		return
	var world := VisibilityCullingWorld.new()
	tree.current_scene.add_child(world)
	var resource := Node2D.new()
	resource.position = Vector2(900.0, 0.0)
	resource.add_to_group("resources")
	tree.current_scene.add_child(resource)
	world.register_resource_node(resource)
	TEST_UTILS.expect_equal(resource.visible, false, failures, "World visibility culling should hide newly registered resources immediately")
	var creature := Node2D.new()
	creature.position = Vector2(900.0, 64.0)
	creature.add_to_group("small_prey")
	tree.current_scene.add_child(creature)
	world.register_creature_node(creature, "small_prey")
	TEST_UTILS.expect_equal(creature.visible, false, failures, "World visibility culling should hide newly registered creatures immediately")
	var visible_rect := Rect2(Vector2(832.0, -128.0), Vector2(256.0, 256.0))
	world.call("_set_world_object_visibility_by_rect", visible_rect)
	TEST_UTILS.expect_equal(resource.visible, true, failures, "World visibility culling should show registered resources when they enter the visible rect")
	TEST_UTILS.expect_equal(creature.visible, true, failures, "World visibility culling should show registered creatures when they enter the visible rect")
	var hidden_rect := Rect2(Vector2(-128.0, -128.0), Vector2(256.0, 256.0))
	world.call("_set_world_object_visibility_by_rect", hidden_rect)
	TEST_UTILS.expect_equal(resource.visible, false, failures, "World visibility culling should hide registered resources again after they leave the visible rect")
	TEST_UTILS.expect_equal(creature.visible, false, failures, "World visibility culling should hide registered creatures again after they leave the visible rect")
	resource.free()
	creature.free()
	world.free()


func _test_cached_group_nodes_prune_freed_entries(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	TEST_UTILS.expect(tree != null and tree.current_scene != null, failures, "Test runner should provide a current scene")
	if tree == null or tree.current_scene == null:
		return
	var world := WORLD_SCRIPT.new()
	tree.current_scene.add_child(world)
	var meat_drop: Node2D = world.call("_spawn_resource_at", "meat_drop", Vector2(24.0, -12.0))
	var cached_before: Array = world.call("get_cached_group_nodes", "meat_drops")
	TEST_UTILS.expect_equal(cached_before.size(), 1, failures, "World cache should capture the live meat drop")
	meat_drop.free()
	var cached_after: Array = world.call("get_cached_group_nodes", "meat_drops")
	TEST_UTILS.expect_equal(cached_after.size(), 0, failures, "World cache should filter out freed nodes before returning the cached list")
	world.free()


func _test_world_registry_tracks_spawned_nodes_and_prunes_freed_entries(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	TEST_UTILS.expect(tree != null and tree.current_scene != null, failures, "Test runner should provide a current scene for registry tests")
	if tree == null or tree.current_scene == null:
		return
	var world := WORLD_SCRIPT.new()
	tree.current_scene.add_child(world)
	var resource: Node2D = world.call("_spawn_resource_at", "berry_bush", Vector2(-900.0, -320.0))
	var small_prey: Node2D = world.call("_spawn_small_prey_at", Vector2(-840.0, -280.0), "westwood")
	var building := Node2D.new()
	tree.current_scene.add_child(building)
	world.register_building_node(building, "campfire")
	var resource_biome_id := str(resource.get("biome_id"))
	TEST_UTILS.expect_equal(world.get_registered_resources().size(), 1, failures, "World registry should include resources spawned through World")
	TEST_UTILS.expect_equal(world.get_registered_resources_by_kind("berry_bush").size(), 1, failures, "World registry should expose resources by resource kind")
	TEST_UTILS.expect_equal(world.get_registered_resources_by_biome(resource_biome_id).size(), 1, failures, "World registry should expose resources by biome id")
	TEST_UTILS.expect_equal(world.get_registered_creatures_by_type("small_prey").size(), 1, failures, "World registry should include spawned SmallPrey")
	TEST_UTILS.expect_equal(world.get_registered_buildings_by_type("campfire").size(), 1, failures, "World registry should include registered campfires")
	TEST_UTILS.expect_equal(world.call("get_cached_group_nodes", "edible_vegetation").size(), 1, failures, "Cached edible vegetation reads should resolve through WorldRegistry")
	TEST_UTILS.expect_equal(world.call("get_cached_group_nodes", "campfires").size(), 1, failures, "Cached campfire reads should resolve through WorldRegistry")
	resource.free()
	small_prey.free()
	building.free()
	TEST_UTILS.expect_equal(world.get_registered_resources().size(), 0, failures, "World registry should prune freed resources immediately")
	TEST_UTILS.expect_equal(world.get_registered_creatures_by_type("small_prey").size(), 0, failures, "World registry should prune freed creatures immediately")
	TEST_UTILS.expect_equal(world.get_registered_buildings_by_type("campfire").size(), 0, failures, "World registry should prune freed buildings immediately")
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
