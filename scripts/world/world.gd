extends Node2D
class_name World

const RESOURCE_SCENE := preload("res://scenes/world/resource_node.tscn")
const VARNAK_SCENE := preload("res://scenes/creatures/varnak.tscn")
const SMALL_PREY_SCENE := preload("res://scenes/creatures/small_prey.tscn")
const GRAZER_SCENE := preload("res://scenes/creatures/grazer.tscn")
const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const WORLD_REGISTRY_SCRIPT := preload("res://scripts/world/world_registry.gd")
const WORLD_QUERY_SERVICE_SCRIPT := preload("res://scripts/world/world_query_service.gd")
const LANDMARK_SERVICE_SCRIPT := preload("res://scripts/world/landmark_service.gd")
const RESOURCE_SERVICE_SCRIPT := preload("res://scripts/world/resource_service.gd")
const ISLAND_WORLD_VALIDATOR_SCRIPT := preload("res://scripts/world/island_world_validator.gd")
const POOL_MANAGER_SCRIPT := preload("res://scripts/systems/pool_manager.gd")
const GRAPHICS_SETTINGS_SCRIPT := preload("res://scripts/systems/graphics_settings.gd")
const WORLD_RENDER_CONTROLLER_SCRIPT := preload("res://scripts/world/world_render_controller.gd")

const SMALL_PREY_SPAWN_TICK_SECONDS := 4.0
const SMALL_PREY_FAILED_SPAWN_RETRY_SECONDS := 5.0
const VARNAK_FAILED_SPAWN_RETRY_SECONDS := 5.0
const ROCK_SPAWN_TICK_SECONDS := 18.0
const SMALL_PREY_MAX_VISIBLE_COUNT := 12
const SMALL_PREY_MAX_VISIBLE_PER_BIOME := 5
const SMALL_PREY_VISIBLE_SPAWN_RADIUS := 850.0
const SMALL_PREY_PLAYER_SAFE_DISTANCE := 240.0
const SMALL_PREY_MIN_DISTANCE := 190.0
const INITIAL_GRAZER_VISIBLE_COUNT := 3
const GRAZER_MAX_VISIBLE_COUNT := 6
const GRAZER_MAX_VISIBLE_PER_BIOME := 3
const GRAZER_INITIAL_PLAYER_SAFE_DISTANCE := 720.0
const VARNAK_MIN_DISTANCE := 360.0
const GRAZER_VISIBLE_SPAWN_RADIUS := 1000.0
const GRAZER_PLAYER_SAFE_DISTANCE := 340.0
const GRAZER_MIN_DISTANCE := 300.0
const DEBUG_SMALL_PREY_VISIBLE_COUNT := 3
const DEBUG_GRAZER_VISIBLE_COUNT := 2
const DEBUG_SMALL_PREY_SPAWN_RADIUS := 180.0
const DEBUG_GRAZER_SPAWN_RADIUS := 240.0
const VISIBILITY_CULL_INTERVAL_SECONDS := 0.35
const VISIBILITY_CULL_MARGIN := 384.0
const VISIBILITY_CULL_GROUPS := ["resources", "small_prey", "grazer", "varnak"]
const BIOME_BLEND_TEXTURE_SIZE := Vector2i(384, 236)
const BIOME_DETAIL_CHUNK_WORLD_SIZE := 768.0
const BIOME_DETAIL_CHUNK_TEXTURE_SIZE := Vector2i(256, 256)
const BIOME_DETAIL_VISIBLE_CHUNK_RADIUS := 1
const BIOME_DETAIL_WORLD_TILE_SIZE := 128.0
const BIOME_DETAIL_ALPHA := 0.22
const BIOME_TERRAIN_ACCENT_COUNTS := {
	"westwood": 26,
	"stoneback_ridge": 22,
	"hearth_meadow": 30,
	"south_thicket": 28,
	"redfang_wilds": 22
}
const BIOME_TERRAIN_TEXTURES := {
	"westwood": {
		"texture_path": "res://assets/textures/biomes/westwood_sample.png",
		"mix": 0.86,
		"seed": 0.38
	},
	"stoneback_ridge": {
		"texture_path": "res://assets/textures/biomes/stoneback_ridge_sample.png",
		"mix": 0.90,
		"seed": 0.63
	},
	"hearth_meadow": {
		"texture_path": "res://assets/textures/biomes/hearth_meadow_sample.png",
		"mix": 0.88,
		"seed": 0.19
	},
	"south_thicket": {
		"texture_path": "res://assets/textures/biomes/south_thicket_sample.png",
		"mix": 0.88,
		"seed": 0.91
	},
	"redfang_wilds": {
		"texture_path": "res://assets/textures/biomes/redfang_wilds_sample.png",
		"mix": 0.92,
		"seed": 0.77
	}
}
const WORLD_BACKGROUND_REDRAW_INTERVAL := 0.20
const NIGHT_REDRAW_MIN_DELTA := 0.03
const PLANT_RESOURCE_KINDS := [
	"conifer_tree",
	"leafy_tree",
	"dry_tree",
	"bush",
	"dry_bush",
	"small_bush",
	"berry_bush",
	"grass_patch",
	"dense_grass"
]
const CREATURE_BOUND_GROUPS := ["varnak", "small_prey", "grazer"]
const CREATURE_BOUND_TELEPORT_PADDING := 36.0
const HILL_RESOURCE_BLOCK_RADIUS_FACTOR := 0.72
const HILL_VISUAL_Y_SCALE := 0.58
const POND_VISUAL_Y_SCALE := 0.62
const POND_VEGETATION_MIN_COUNT := 18
const POND_VEGETATION_RING_MIN_FACTOR := 0.82
const POND_VEGETATION_RING_MAX_FACTOR := 1.35
const POND_VEGETATION_RING_JITTER := 0.16
const POND_VEGETATION_ANGLE_JITTER_FACTOR := 0.38
const INITIAL_SPAWN_BATCH_SIZE := 4
const INITIAL_BOOT_STEP_FRAME_BREAKS := 1
const BIOME_TERRAIN_ACCENT_BUILD_BATCH_SIZE := 1
const WATER_ZONE_LAND := "land"
const WATER_ZONE_HIGHLAND := "highland"
const WATER_ZONE_SHORE := "shore"
const WATER_ZONE_SHALLOW := "shallow_water"
const WATER_ZONE_DEEP := "deep_ocean"
const RESOURCE_DROP_POOL_KEY := "resource_drop"
const RESOURCE_DROP_POOL_MAX_SIZE := 48
const POOLED_RESOURCE_KINDS := ["meat_drop", "bone_drop"]

var evolution_director: Node
var day_night_system: Node
var ecosystem_director: Node
var resource_rng := RandomNumberGenerator.new()
var varnak_rng := RandomNumberGenerator.new()
var small_prey_rng := RandomNumberGenerator.new()
var grazer_rng := RandomNumberGenerator.new()
var small_prey_spawn_timer := 0.0
var small_prey_failed_spawn_retry_timer := 0.0
var small_prey_failed_spawn_warning_printed := false
var small_prey_spawn_sync_attempt_count := 0
var small_prey_spawn_sync_failed_count := 0
var small_prey_spawn_sync_skipped_by_cooldown_count := 0
var small_prey_spawn_sync_last_requested := 0
var small_prey_spawn_sync_last_failed := 0
var small_prey_spawn_sync_last_success := 0
var varnak_spawn_timer := 0.0
var rock_spawn_timer := 0.0
var varnak_failed_spawn_retry_timer := 0.0
var varnak_failed_spawn_warning_printed := false
var varnak_spawn_sync_attempt_count := 0
var varnak_spawn_sync_failed_count := 0
var varnak_spawn_sync_skipped_by_cooldown_count := 0
var varnak_spawn_sync_last_requested := 0
var varnak_spawn_sync_last_failed := 0
var varnak_spawn_sync_last_success := 0
var world_seed := 0
var landmarks: Array[Dictionary] = []
var hill_landmarks: Array[Dictionary] = []
var pond_landmarks: Array[Dictionary] = []
var pond_water_search_radius := 0.0
var biome_sample_images: Dictionary = {}
var biome_terrain_accent_cache: Dictionary = {}
var pending_biome_terrain_accent_biomes: Array[Dictionary] = []
var biome_terrain_accent_cache_build_running := false
var debug_landmark_overlay_enabled: bool = false
var biome_textures_enabled: bool = true
var biome_terrain_accents_enabled: bool = false
var visibility_culling_enabled: bool = true
var pool_manager: PoolManager
var graphics_settings: Node = GRAPHICS_SETTINGS_SCRIPT.new()
var group_nodes_cache: Dictionary = {}
var group_nodes_cache_timestamps: Dictionary = {}
var pending_biome_vegetation_syncs: Dictionary = {}
var biome_vegetation_sync_scheduled := false
var boot_ready := false
var boot_status_message := "Preparing world..."
var boot_status_progress := 0.0
var integration_test_mode := false
var biome_blend_background: Sprite2D
var biome_detail_overlay_cache: Dictionary = {}
var biome_detail_overlay_pending_keys: Array[String] = []
var biome_detail_overlay_visible_keys: Array[String] = []
var biome_detail_overlay_last_signature := ""
var biome_detail_overlay_build_budget_per_frame := 1
var hitch_log_cooldowns: Dictionary = {}
var hitch_log_sequence: Dictionary = {}
var world_biome_texture_build_count: int = 0
var world_biome_texture_last_build_ms: float = 0.0
var visibility_cull_timer := 0.0
var visibility_cull_last_visible_resources: int = 0
var visibility_cull_last_hidden_resources: int = 0
var visibility_cull_last_visible_creatures: int = 0
var visibility_cull_last_hidden_creatures: int = 0
var visibility_cull_last_visible_nodes: Dictionary = {}
var is_restoring_save: bool = false
var island_world_validation_last_report: Dictionary = {}
var night_overlay_polygon: Polygon2D
var registry = WORLD_REGISTRY_SCRIPT.new()
var query_service = WORLD_QUERY_SERVICE_SCRIPT.new()
var landmark_service = LANDMARK_SERVICE_SCRIPT.new()
var resource_service = RESOURCE_SERVICE_SCRIPT.new()
var render_controller = WORLD_RENDER_CONTROLLER_SCRIPT.new()
const GROUP_CACHE_TTL_SECONDS := 0.12

signal world_initialized
signal world_boot_stage_changed(stage_message: String, progress: float)

func _ready() -> void:
	var graphics_settings_node := get_node_or_null("/root/GraphicsSettings")
	if graphics_settings_node != null:
		graphics_settings = graphics_settings_node
	_apply_graphics_settings_defaults()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_biome_blend_background()
	_ensure_night_overlay_polygon()
	_set_boot_progress("Preparing world...", 0.02)
	await get_tree().process_frame
	_set_boot_progress("Preparing world systems...", 0.08)
	_ensure_query_service()
	_ensure_registry()
	_ensure_pool_manager()
	resource_rng.randomize()
	varnak_rng.randomize()
	small_prey_rng.randomize()
	grazer_rng.randomize()
	evolution_director = _get_sibling_node("EvolutionDirector")
	day_night_system = _get_sibling_node("DayNightSystem")
	ecosystem_director = _get_sibling_node("EcosystemDirector")
	if day_night_system and day_night_system.has_signal("day_changed"):
		day_night_system.day_changed.connect(_on_day_changed)
	if evolution_director and evolution_director.has_method("connect") and evolution_director.has_signal("profile_changed"):
		evolution_director.profile_changed.connect(_on_profile_changed)
	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_signal("game_event"):
		event_bus.game_event.connect(_on_game_event)
	_ensure_render_controller()
	_set_boot_progress("Generating landmarks...", 0.18)
	_create_landmarks()
	_place_player_on_safe_start()
	_queue_biome_terrain_accent_cache_rebuild()
	_set_boot_progress("Growing vegetation...", 0.40)
	await _spawn_resources()
	await _yield_initial_boot_step()
	_set_boot_progress("Spawning small prey...", 0.58)
	if integration_test_mode:
		force_spawn_small_prey_for_tests(SMALL_PREY_MAX_VISIBLE_PER_BIOME)
	else:
		_sync_visible_small_prey()
	await _yield_initial_boot_step()
	_set_boot_progress("Spawning grazers...", 0.72)
	if integration_test_mode:
		force_spawn_grazers_for_tests(INITIAL_GRAZER_VISIBLE_COUNT)
	else:
		_spawn_initial_grazers()
	await _yield_initial_boot_step()
	_set_boot_progress("Spawning predators...", 0.84)
	if integration_test_mode:
		force_spawn_varnaks_for_tests(int(GAME_BALANCE.VARNAK_DAY_SCALING.get("spawn_batch_limit", 2)))
	else:
		_sync_visible_varnaks(true)
	await _yield_initial_boot_step()
	_set_boot_progress("Rendering world...", 0.94)
	_prepare_boot_render_cache()
	await _yield_initial_boot_step()
	_set_boot_progress("Finalizing world...", 0.98)
	boot_ready = true
	_set_boot_progress("World ready", 1.0)
	_update_world_object_visibility()
	visibility_cull_timer = VISIBILITY_CULL_INTERVAL_SECONDS
	_sync_biome_blend_background()
	_update_biome_detail_overlay(true)
	world_initialized.emit()
	queue_redraw()


func _process(delta: float) -> void:
	_log_hitch(delta, "World", {
		"biome_textures_enabled": biome_textures_enabled,
		"background_visible": is_instance_valid(biome_blend_background) and biome_blend_background.visible,
		"visibility_culling_enabled": visibility_culling_enabled,
		"visible_resources": visibility_cull_last_visible_resources,
		"hidden_resources": visibility_cull_last_hidden_resources,
		"visible_creatures": visibility_cull_last_visible_creatures,
		"hidden_creatures": visibility_cull_last_hidden_creatures
	})
	if is_restoring_save:
		return
	if small_prey_failed_spawn_retry_timer > 0.0 and not integration_test_mode:
		small_prey_failed_spawn_retry_timer = maxf(0.0, small_prey_failed_spawn_retry_timer - delta)
	if varnak_failed_spawn_retry_timer > 0.0 and not integration_test_mode:
		varnak_failed_spawn_retry_timer = maxf(0.0, varnak_failed_spawn_retry_timer - delta)
	small_prey_spawn_timer += delta
	if small_prey_spawn_timer >= SMALL_PREY_SPAWN_TICK_SECONDS:
		small_prey_spawn_timer = 0.0
		_sync_visible_small_prey()
		_sync_visible_grazers()
	varnak_spawn_timer += delta
	if varnak_spawn_timer >= _get_varnak_spawn_check_interval():
		varnak_spawn_timer = 0.0
		_sync_visible_varnaks()
	rock_spawn_timer += delta
	if rock_spawn_timer >= ROCK_SPAWN_TICK_SECONDS:
		rock_spawn_timer = 0.0
		_sync_periodic_rock_spawn()
	var current_night_amount := _get_night_amount()
	var should_redraw_background: bool = _ensure_render_controller().process(delta, current_night_amount)
	if should_redraw_background:
		_sync_biome_blend_background()
		queue_redraw()
	if boot_ready and visibility_culling_enabled:
		visibility_cull_timer -= delta
		if visibility_cull_timer <= 0.0:
			visibility_cull_timer = VISIBILITY_CULL_INTERVAL_SECONDS
			_update_world_object_visibility()
	_update_biome_detail_overlay()
	_build_pending_biome_detail_overlay_chunks()
	_update_night_overlay(current_night_amount)


func _apply_graphics_settings_defaults() -> void:
	biome_textures_enabled = graphics_settings.get_default_biome_textures_enabled() if graphics_settings.has_method("get_default_biome_textures_enabled") else true
	debug_landmark_overlay_enabled = graphics_settings.get_default_landmark_debug_overlay_enabled() if graphics_settings.has_method("get_default_landmark_debug_overlay_enabled") else false
	biome_terrain_accents_enabled = graphics_settings.get_default_biome_terrain_accents_enabled() if graphics_settings.has_method("get_default_biome_terrain_accents_enabled") else false


func get_world_rect() -> Rect2:
	return WORLD_CONFIG.WORLD_RECT


func get_camera_visible_world_rect(margin := VISIBILITY_CULL_MARGIN) -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return WORLD_CONFIG.WORLD_RECT.grow(margin)
	var camera := viewport.get_camera_2d()
	if camera == null:
		return WORLD_CONFIG.WORLD_RECT.grow(margin)
	var viewport_size := get_viewport_rect().size
	return _get_world_object_visibility_rect(viewport_size, camera.global_position, camera.zoom, margin)


func _update_world_object_visibility() -> void:
	if not boot_ready or not visibility_culling_enabled:
		return
	_set_world_object_visibility_by_rect(get_camera_visible_world_rect(VISIBILITY_CULL_MARGIN))


func _get_world_object_visibility_rect(viewport_size: Vector2, camera_position: Vector2, camera_zoom: Vector2, margin := VISIBILITY_CULL_MARGIN) -> Rect2:
	var safe_zoom := Vector2(maxf(absf(camera_zoom.x), 0.01), maxf(absf(camera_zoom.y), 0.01))
	var visible_world_size := Vector2(viewport_size.x / safe_zoom.x, viewport_size.y / safe_zoom.y)
	var margin_vector := Vector2.ONE * margin
	return Rect2(
		camera_position - visible_world_size * 0.5 - margin_vector,
		visible_world_size + margin_vector * 2.0
	)


func _set_world_object_visibility_by_rect(visible_rect: Rect2) -> void:
	visibility_cull_last_visible_resources = 0
	visibility_cull_last_hidden_resources = 0
	visibility_cull_last_visible_creatures = 0
	visibility_cull_last_hidden_creatures = 0
	var query_rect := visible_rect.grow(128.0)
	var current_visible_nodes: Dictionary = {}
	var visible_resources := get_resources_in_rect(query_rect)
	for node in visible_resources:
		_mark_visibility_candidate(node, true, current_visible_nodes)
	var visible_meat := get_meat_in_rect(query_rect)
	for node in visible_meat:
		_mark_visibility_candidate(node, true, current_visible_nodes)
	for creature_type in ["small_prey", "grazer", "varnak"]:
		var visible_creatures := get_creatures_in_rect(query_rect, creature_type)
		for node in visible_creatures:
			_mark_visibility_candidate(node, false, current_visible_nodes)
	_hide_nodes_that_left_visibility_rect(current_visible_nodes)
	visibility_cull_last_visible_nodes = current_visible_nodes


func _set_visibility_culled_node(node: Node, should_be_visible: bool) -> void:
	if not is_instance_valid(node):
		return
	var node_2d := node as Node2D
	if node_2d == null:
		return
	if node.has_method("set_visibility_culled"):
		node.call("set_visibility_culled", should_be_visible)
	else:
		node_2d.visible = should_be_visible


func _mark_visibility_candidate(node: Node, is_resource: bool, current_visible_nodes: Dictionary) -> void:
	if not is_instance_valid(node):
		return
	var node_2d := node as Node2D
	if node_2d == null:
		return
	var instance_id := node.get_instance_id()
	current_visible_nodes[instance_id] = node
	_set_visibility_culled_node(node, true)
	if is_resource:
		visibility_cull_last_visible_resources += 1
	else:
		visibility_cull_last_visible_creatures += 1


func _hide_nodes_that_left_visibility_rect(current_visible_nodes: Dictionary) -> void:
	for previous_id in visibility_cull_last_visible_nodes.keys():
		if current_visible_nodes.has(previous_id):
			continue
		var previous_value: Variant = visibility_cull_last_visible_nodes.get(previous_id, null)
		if previous_value == null or not is_instance_valid(previous_value):
			continue
		var previous_node := previous_value as Node
		if previous_node == null:
			continue
		var node_2d := previous_node as Node2D
		if node_2d == null:
			continue
		var is_resource := previous_node.is_in_group("resources")
		_set_visibility_culled_node(previous_node, false)
		if is_resource:
			visibility_cull_last_hidden_resources += 1
		else:
			visibility_cull_last_hidden_creatures += 1


func get_biome_zones() -> Array[Dictionary]:
	return WORLD_CONFIG.get_biome_zones()


func get_landmarks() -> Array[Dictionary]:
	if landmarks.is_empty():
		return WORLD_CONFIG.get_landmarks()
	return _ensure_landmark_service().get_landmarks()


func get_safe_player_start_position() -> Vector2:
	return WORLD_CONFIG.get_safe_player_start_position(landmarks)


func get_world_seed() -> int:
	return world_seed


func get_varnak_population_status() -> Dictionary:
	var current_day := _get_current_day()
	return {
		"day": current_day,
		"target": _get_varnak_target_count(current_day),
		"live": get_registered_creatures_by_type("varnak").size(),
		"max": int(GAME_BALANCE.VARNAK_DAY_SCALING["max_varnaks"]),
		"spawn_chance": _get_varnak_spawn_chance(current_day),
		"spawn_batch_limit": int(GAME_BALANCE.VARNAK_DAY_SCALING["spawn_batch_limit"])
	}


func get_boot_progress_state() -> Dictionary:
	return {
		"message": boot_status_message,
		"progress": boot_status_progress,
		"boot_ready": boot_ready
	}


func run_island_world_validation() -> Dictionary:
	var validator := ISLAND_WORLD_VALIDATOR_SCRIPT.new()
	var report: Dictionary = validator.run(self)
	island_world_validation_last_report = report.duplicate(true)
	return report


func get_island_world_validation_report() -> Dictionary:
	if island_world_validation_last_report.is_empty():
		return run_island_world_validation()
	return island_world_validation_last_report.duplicate(true)


func get_island_world_validation_summary() -> String:
	var report := get_island_world_validation_report()
	var status := "PASS" if bool(report.get("passed", false)) else "FAIL"
	var errors := Array(report.get("errors", []))
	var warnings := Array(report.get("warnings", []))
	return "%s | errors %d | warnings %d" % [status, errors.size(), warnings.size()]


func get_island_world_validation_text() -> String:
	var validator := ISLAND_WORLD_VALIDATOR_SCRIPT.new()
	return validator.report_to_text(get_island_world_validation_report())


func enable_integration_test_mode() -> void:
	integration_test_mode = true
	small_prey_failed_spawn_retry_timer = 0.0
	small_prey_failed_spawn_warning_printed = false
	small_prey_spawn_sync_attempt_count = 0
	small_prey_spawn_sync_failed_count = 0
	small_prey_spawn_sync_skipped_by_cooldown_count = 0
	small_prey_spawn_sync_last_requested = 0
	small_prey_spawn_sync_last_failed = 0
	small_prey_spawn_sync_last_success = 0
	varnak_failed_spawn_retry_timer = 0.0
	varnak_failed_spawn_warning_printed = false
	varnak_spawn_sync_attempt_count = 0
	varnak_spawn_sync_failed_count = 0
	varnak_spawn_sync_skipped_by_cooldown_count = 0
	varnak_spawn_sync_last_requested = 0
	varnak_spawn_sync_last_failed = 0
	varnak_spawn_sync_last_success = 0


func spawn_resource_for_tests(resource_kind: String, world_position: Vector2) -> Node:
	return _spawn_resource_at(resource_kind, world_position)


func spawn_small_prey_for_tests(spawn_position: Vector2, biome_id: String) -> Node:
	return _spawn_small_prey_at(spawn_position, biome_id)


func spawn_grazer_for_tests(spawn_position: Vector2, biome_id: String) -> Node:
	return _spawn_grazer_at(spawn_position, biome_id)


func spawn_varnak_for_tests(spawn_position: Vector2) -> Node:
	return _spawn_varnak_at(spawn_position)


func force_spawn_small_prey_for_tests(count: int, center: Vector2 = Vector2.INF) -> Array[Node]:
	var spawned: Array[Node] = []
	if count <= 0:
		return spawned
	var player_position := center if center != Vector2.INF else _get_player_position()
	var biome := _get_biome_for_position(player_position)
	if biome.is_empty():
		biome = _get_first_biome_for_tests(false)
	if biome.is_empty():
		return spawned
	var biome_id := _get_biome_id(biome)
	for i in count:
		var spawn_position := _get_debug_creature_spawn_position(biome, 220.0, i, count)
		if spawn_position == Vector2.ZERO:
			spawn_position = player_position
		spawned.append(_spawn_small_prey_at(spawn_position, biome_id))
	return spawned


func force_spawn_grazers_for_tests(count: int, center: Vector2 = Vector2.INF) -> Array[Node]:
	var spawned: Array[Node] = []
	if count <= 0:
		return spawned
	var player_position := center if center != Vector2.INF else _get_player_position()
	var biome := _get_first_biome_for_tests(false)
	if biome.is_empty():
		biome = _get_biome_for_position(player_position)
	if biome.is_empty():
		return spawned
	var biome_id := _get_biome_id(biome)
	for i in count:
		var spawn_position := _get_debug_creature_spawn_position(biome, 280.0, i, count)
		if spawn_position == Vector2.ZERO:
			spawn_position = player_position
		spawned.append(_spawn_grazer_at(spawn_position, biome_id))
	return spawned


func force_spawn_varnaks_for_tests(count: int, center: Vector2 = Vector2.INF) -> Array[Node]:
	var spawned: Array[Node] = []
	if count <= 0:
		return spawned
	var player_position := center if center != Vector2.INF else _get_player_position()
	var biome := _get_first_biome_for_tests(true)
	if biome.is_empty():
		biome = _get_biome_for_position(player_position)
	if biome.is_empty():
		return spawned
	var used_positions: Array[Vector2] = _get_existing_varnak_positions()
	for i in count:
		var spawn_position := _get_debug_creature_spawn_position(biome, 320.0, i, count)
		if spawn_position == Vector2.ZERO:
			spawn_position = player_position
		if not _is_valid_varnak_spawn_position(spawn_position, player_position, used_positions):
			spawn_position = _clamp_position_to_world(spawn_position)
		used_positions.append(spawn_position)
		spawned.append(_spawn_varnak_at(spawn_position))
	return spawned


func _get_first_biome_for_tests(dangerous: bool) -> Dictionary:
	for biome_value in WORLD_CONFIG.get_biome_zones():
		var biome := Dictionary(biome_value)
		if biome.get("dangerous", false) == dangerous:
			return biome
	return {}


func get_query_service():
	return _ensure_query_service()


func get_landmark_counts() -> Dictionary:
	return _ensure_landmark_service().get_landmark_counts()


func get_nearest_landmark_data(world_position: Vector2) -> Dictionary:
	return _ensure_landmark_service().get_nearest_landmark_data(world_position)


func get_current_biome_texture_id(world_position: Vector2) -> String:
	var biome := _get_biome_for_position(world_position)
	if biome.is_empty():
		return "none"
	return _get_biome_terrain_texture_key(biome)


func get_biome_texture_cache_status() -> Dictionary:
	var render_state: Dictionary = _ensure_render_controller().get_biome_texture_cache_status()
	world_biome_texture_build_count = int(render_state.get("rebuild_count", world_biome_texture_build_count))
	world_biome_texture_last_build_ms = float(render_state.get("last_build_ms", world_biome_texture_last_build_ms))
	return {
		"sample_image_cache_count": biome_sample_images.size(),
		"accent_cache_count": biome_terrain_accent_cache.size(),
		"pending_biomes": pending_biome_terrain_accent_biomes.size(),
		"build_running": biome_terrain_accent_cache_build_running,
		"textures_enabled": biome_textures_enabled,
		"has_blend_texture": bool(render_state.get("has_texture", false)),
		"blend_colors_key": str(render_state.get("colors_key", "")),
		"blend_texture_size": render_state.get("size", Vector2i.ZERO),
		"rebuild_blocked_count": int(render_state.get("rebuild_blocked_count", 0)),
		"dirty_key_pending": bool(render_state.get("dirty_key_pending", false)),
		"freeze_after_first_build": bool(render_state.get("freeze_after_first_build", false)),
		"world_biome_texture_build_count": world_biome_texture_build_count,
		"world_biome_texture_last_build_ms": world_biome_texture_last_build_ms
	}


func get_biome_texture_cache_debug() -> Dictionary:
	return get_biome_texture_cache_status()


func is_landmark_debug_overlay_enabled() -> bool:
	return debug_landmark_overlay_enabled


func are_biome_textures_enabled() -> bool:
	return biome_textures_enabled


func are_biome_terrain_accents_enabled() -> bool:
	return biome_terrain_accents_enabled


func is_low_end_rendering_enabled() -> bool:
	return graphics_settings.has_method("is_low_end_rendering_enabled") and graphics_settings.is_low_end_rendering_enabled()


func get_visibility_culling_debug() -> Dictionary:
	return {
		"enabled": visibility_culling_enabled,
		"interval_seconds": VISIBILITY_CULL_INTERVAL_SECONDS,
		"margin": VISIBILITY_CULL_MARGIN,
		"visible_resources": visibility_cull_last_visible_resources,
		"hidden_resources": visibility_cull_last_hidden_resources,
		"visible_creatures": visibility_cull_last_visible_creatures,
		"hidden_creatures": visibility_cull_last_hidden_creatures
	}


func get_pool_debug_snapshot() -> Dictionary:
	if not is_instance_valid(pool_manager):
		return {}
	return pool_manager.get_debug_snapshot()


func get_pool_debug_text() -> String:
	if not is_instance_valid(pool_manager):
		return "pool unavailable"
	return pool_manager.get_debug_text()


func get_landmark_save_data() -> Array[Dictionary]:
	return _ensure_landmark_service().get_landmark_save_data()


func get_save_data() -> Dictionary:
	return {
		"world_seed": world_seed,
		"landmarks": get_landmark_save_data()
	}


func begin_save_restore() -> void:
	is_restoring_save = true


func end_save_restore() -> void:
	is_restoring_save = false
	clear_cached_group_nodes()
	if visibility_culling_enabled:
		_update_world_object_visibility()
	queue_redraw()


func is_boot_ready() -> bool:
	return boot_ready


func get_cached_group_nodes(group_name: String) -> Array:
	var world_registry = _ensure_registry()
	if world_registry.supports_group(group_name):
		return world_registry.get_group_nodes(group_name)
	var scene_tree := get_tree()
	if scene_tree == null:
		return []
	var now_seconds := Time.get_ticks_msec() / 1000.0
	var last_refresh := float(group_nodes_cache_timestamps.get(group_name, -INF))
	if not group_nodes_cache.has(group_name) or now_seconds - last_refresh >= GROUP_CACHE_TTL_SECONDS:
		group_nodes_cache[group_name] = _filter_valid_cached_group_nodes(scene_tree.get_nodes_in_group(group_name))
		group_nodes_cache_timestamps[group_name] = now_seconds
		return group_nodes_cache[group_name]
	var cached_nodes: Array = Array(group_nodes_cache.get(group_name, []))
	var filtered_nodes := _filter_valid_cached_group_nodes(cached_nodes)
	if filtered_nodes.size() != cached_nodes.size():
		group_nodes_cache[group_name] = filtered_nodes
	return filtered_nodes


func clear_cached_group_nodes() -> void:
	group_nodes_cache.clear()
	group_nodes_cache_timestamps.clear()


func get_world_registry():
	return _ensure_registry()


func get_registered_resources() -> Array:
	return _ensure_registry().get_resources()


func get_registered_resources_by_kind(resource_kind: String) -> Array:
	return _ensure_registry().get_resources_by_kind(resource_kind)


func get_registered_resources_by_biome(biome_id: String) -> Array:
	return _ensure_registry().get_resources_by_biome(biome_id)


func get_registered_creatures_by_type(creature_type: String) -> Array:
	return _ensure_registry().get_creatures_by_type(creature_type)


func get_registered_creatures_by_biome(biome_id: String, creature_type: String = "") -> Array:
	return _ensure_registry().get_creatures_by_biome(biome_id, creature_type)


func get_registered_buildings() -> Array:
	return _ensure_registry().get_buildings()


func get_registered_buildings_by_type(building_type: String) -> Array:
	return _ensure_registry().get_buildings_by_type(building_type)


func register_resource_node(node: Node) -> void:
	_ensure_registry().register_resource(node)
	if visibility_culling_enabled:
		_set_visibility_culled_node(node, false)


func register_creature_node(node: Node, creature_type: String) -> void:
	_ensure_registry().register_creature(node, creature_type)
	if visibility_culling_enabled:
		_set_visibility_culled_node(node, false)


func register_building_node(node: Node, building_type: String) -> void:
	_ensure_registry().register_building(node, building_type)


func _filter_valid_cached_group_nodes(nodes: Array) -> Array:
	var filtered_nodes: Array = []
	for node in nodes:
		if is_instance_valid(node):
			filtered_nodes.append(node)
	return filtered_nodes


func _ensure_registry():
	if registry == null:
		registry = WORLD_REGISTRY_SCRIPT.new()
	registry.set_biome_id_resolver(Callable(self, "_get_biome_id_for_position"))
	return registry


func _ensure_pool_manager() -> PoolManager:
	if is_instance_valid(pool_manager):
		return pool_manager
	pool_manager = POOL_MANAGER_SCRIPT.new()
	pool_manager.name = "PoolManager"
	add_child(pool_manager)
	pool_manager.configure_pool(RESOURCE_DROP_POOL_KEY, RESOURCE_DROP_POOL_MAX_SIZE)
	return pool_manager


func _is_poolable_resource_kind(resource_kind: String) -> bool:
	return resource_kind in POOLED_RESOURCE_KINDS


func update_spatial_entity_cell(node: Node) -> void:
	_ensure_registry().update_entity_cell(node)


func get_resources_near(world_position: Vector2, radius: float, kind_filter: Variant = null) -> Array:
	return _ensure_registry().get_resources_near(world_position, radius, kind_filter)


func get_creatures_near(world_position: Vector2, radius: float, creature_type_filter: Variant = null) -> Array:
	return _ensure_registry().get_creatures_near(world_position, radius, creature_type_filter)


func get_meat_near(world_position: Vector2, radius: float) -> Array:
	return _ensure_registry().get_meat_near(world_position, radius)


func get_resources_in_rect(rect: Rect2, kind_filter: Variant = null) -> Array:
	return _ensure_registry().get_resources_in_rect(rect, kind_filter)


func get_creatures_in_rect(rect: Rect2, creature_type_filter: Variant = null) -> Array:
	return _ensure_registry().get_creatures_in_rect(rect, creature_type_filter)


func get_meat_in_rect(rect: Rect2) -> Array:
	return _ensure_registry().get_meat_in_rect(rect)


func _ensure_landmark_service():
	if landmark_service == null:
		landmark_service = LANDMARK_SERVICE_SCRIPT.new()
	landmark_service.set_landmarks(landmarks)
	return landmark_service


func _ensure_resource_service():
	if resource_service == null:
		resource_service = RESOURCE_SERVICE_SCRIPT.new()
	return resource_service


func _ensure_render_controller():
	if render_controller == null:
		render_controller = WORLD_RENDER_CONTROLLER_SCRIPT.new()
	if not render_controller.biome_surface_color_getter.is_valid():
		render_controller.bind_world(
			WORLD_CONFIG.WORLD_RECT,
			Callable(self, "get_biome_zones"),
			Callable(self, "_get_biome_colors_key"),
			Callable(self, "_get_biome_surface_color_at"),
			_get_world_biome_blend_texture_size()
		)
	return render_controller


func _ensure_biome_blend_background() -> Sprite2D:
	if is_instance_valid(biome_blend_background):
		return biome_blend_background
	biome_blend_background = Sprite2D.new()
	biome_blend_background.name = "BiomeBlendBackground"
	biome_blend_background.centered = false
	biome_blend_background.show_behind_parent = true
	biome_blend_background.z_index = -100
	biome_blend_background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	biome_blend_background.visible = false
	add_child(biome_blend_background)
	return biome_blend_background


func _ensure_night_overlay_polygon() -> Polygon2D:
	if is_instance_valid(night_overlay_polygon):
		return night_overlay_polygon
	night_overlay_polygon = Polygon2D.new()
	night_overlay_polygon.name = "NightOverlay"
	night_overlay_polygon.z_index = 200
	night_overlay_polygon.show_behind_parent = false
	night_overlay_polygon.visible = false
	night_overlay_polygon.polygon = PackedVector2Array([
		WORLD_CONFIG.WORLD_RECT.position,
		Vector2(WORLD_CONFIG.WORLD_RECT.end.x, WORLD_CONFIG.WORLD_RECT.position.y),
		WORLD_CONFIG.WORLD_RECT.end,
		Vector2(WORLD_CONFIG.WORLD_RECT.position.x, WORLD_CONFIG.WORLD_RECT.end.y)
	])
	add_child(night_overlay_polygon)
	return night_overlay_polygon


func _update_night_overlay(night_amount: float) -> void:
	var overlay := _ensure_night_overlay_polygon()
	var overlay_alpha := clampf(night_amount * 0.62, 0.0, 0.62)
	overlay.visible = overlay_alpha > 0.001
	if not overlay.visible:
		return
	overlay.color = Color(0.02, 0.03, 0.09, overlay_alpha)


func _ensure_query_service():
	if query_service == null:
		query_service = WORLD_QUERY_SERVICE_SCRIPT.new()
	query_service.bind_world(
		self,
		PLANT_RESOURCE_KINDS,
		HILL_RESOURCE_BLOCK_RADIUS_FACTOR,
		HILL_VISUAL_Y_SCALE,
		POND_VISUAL_Y_SCALE,
		WATER_ZONE_LAND,
		WATER_ZONE_HIGHLAND,
		WATER_ZONE_SHORE,
		WATER_ZONE_SHALLOW,
		WATER_ZONE_DEEP
	)
	return query_service


func _set_boot_progress(stage_message: String, progress: float) -> void:
	boot_status_message = stage_message
	boot_status_progress = clampf(progress, 0.0, 1.0)
	world_boot_stage_changed.emit(boot_status_message, boot_status_progress)


func _prepare_boot_render_cache() -> void:
	if is_instance_valid(biome_blend_background):
		biome_blend_background.visible = false
	queue_redraw()


func _get_world_biome_blend_texture_size() -> Vector2i:
	var cache_scale := clampf(float(GAME_BALANCE.BIOME_TEXTURES.get("blend_cache_scale", 2.0)), 1.0, 3.0)
	return Vector2i(
		maxi(int(round(float(BIOME_BLEND_TEXTURE_SIZE.x) * cache_scale)), BIOME_BLEND_TEXTURE_SIZE.x),
		maxi(int(round(float(BIOME_BLEND_TEXTURE_SIZE.y) * cache_scale)), BIOME_BLEND_TEXTURE_SIZE.y)
	)


func _sync_biome_blend_background() -> void:
	var background := _ensure_biome_blend_background()
	if not biome_textures_enabled:
		background.visible = false
		background.texture = null
		return
	var controller: Object = _ensure_render_controller()
	var blend_texture: ImageTexture = controller.ensure_biome_blend_texture()
	var render_state: Dictionary = controller.get_biome_texture_cache_status()
	world_biome_texture_build_count = int(render_state.get("rebuild_count", world_biome_texture_build_count))
	world_biome_texture_last_build_ms = float(render_state.get("last_build_ms", world_biome_texture_last_build_ms))
	if blend_texture == null:
		background.visible = false
		background.texture = null
		return
	background.texture = blend_texture
	background.position = WORLD_CONFIG.WORLD_RECT.position
	var texture_size: Vector2i = blend_texture.get_size()
	if texture_size.x > 0 and texture_size.y > 0:
		background.scale = Vector2(
			WORLD_CONFIG.WORLD_RECT.size.x / float(texture_size.x),
			WORLD_CONFIG.WORLD_RECT.size.y / float(texture_size.y)
		)
	background.visible = true


func _yield_initial_boot_step() -> void:
	for _i in INITIAL_BOOT_STEP_FRAME_BREAKS:
		await get_tree().process_frame


func get_terrain_speed_multiplier(world_position: Vector2) -> float:
	return float(_ensure_query_service().get_terrain_speed_multiplier(world_position))


func get_water_zone(world_position: Vector2) -> String:
	return str(_ensure_query_service().get_water_zone(world_position))


func is_position_in_water(world_position: Vector2) -> bool:
	return _ensure_query_service().is_position_in_water(world_position)


func is_position_in_deep_water(world_position: Vector2) -> bool:
	return _ensure_query_service().is_position_in_deep_water(world_position)


func is_resource_position_blocked_by_water(resource_kind: String, world_position: Vector2) -> bool:
	return _ensure_query_service().is_resource_position_blocked_by_water(resource_kind, world_position)


func is_creature_navigation_blocked(world_position: Vector2) -> bool:
	return _ensure_query_service().is_creature_navigation_blocked(world_position)


func is_creature_spawn_blocked_by_water(world_position: Vector2) -> bool:
	return _ensure_query_service().is_creature_spawn_blocked_by_water(world_position)


func get_creatures_out_of_bounds_count() -> int:
	return _get_out_of_bounds_creatures().size()


func debug_teleport_out_of_bounds_creatures() -> void:
	var creatures := _get_out_of_bounds_creatures()
	for creature in creatures:
		if not is_instance_valid(creature):
			continue
		if creature.has_method("debug_return_to_world"):
			creature.debug_return_to_world()
		else:
			creature.global_position = _clamp_position_to_world(creature.global_position)
	if creatures.size() > 0:
		var event_bus := _get_event_bus()
		if event_bus:
			event_bus.post_message("Teleported %d out-of-bounds creature%s" % [
			creatures.size(),
			"" if creatures.size() == 1 else "s"
			])
	else:
		var event_bus := _get_event_bus()
		if event_bus:
			event_bus.post_message("No out-of-bounds creatures")


func _create_landmarks() -> void:
	var game_session := _get_game_session()
	var bootstrap_landmarks: Array[Dictionary] = []
	if game_session and game_session.has_method("get_bootstrap_landmarks"):
		bootstrap_landmarks = game_session.get_bootstrap_landmarks()
	var bootstrap_world_seed := int(game_session.get_bootstrap_world_seed()) if game_session and game_session.has_method("get_bootstrap_world_seed") else 0
	var initial_layout: Dictionary = _ensure_landmark_service().resolve_initial_layout(
		world_seed,
		bootstrap_landmarks,
		bootstrap_world_seed,
		Callable(WORLD_CONFIG, "generate_landmarks")
	)
	world_seed = int(initial_layout.get("world_seed", world_seed))
	landmarks = Array(initial_layout.get("landmarks", []))
	_rebuild_landmark_runtime_state()


func _place_player_on_safe_start() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not (player is Node2D):
		return
	var safe_start := WORLD_CONFIG.get_safe_player_start_position(landmarks)
	if safe_start == Vector2.INF:
		return
	(player as Node2D).global_position = safe_start


func _rebuild_landmark_runtime_state() -> void:
	_ensure_landmark_service()
	hill_landmarks.clear()
	pond_landmarks.clear()
	pond_water_search_radius = 0.0
	landmark_service.sync_runtime_landmarks(landmarks, Callable(self, "_create_landmark_area"))
	hill_landmarks = landmark_service.get_hill_landmarks()
	pond_landmarks = landmark_service.get_pond_landmarks()
	pond_water_search_radius = landmark_service.get_pond_water_search_radius()
	_ensure_query_service()


func restore_landmarks(landmark_data: Array, restored_world_seed: int = 0) -> void:
	await _clear_landmark_areas()
	var restored_layout: Dictionary = _ensure_landmark_service().resolve_restored_layout(
		world_seed,
		landmark_data,
		restored_world_seed,
		Callable(WORLD_CONFIG, "generate_landmarks")
	)
	world_seed = int(restored_layout.get("world_seed", world_seed))
	landmarks = Array(restored_layout.get("landmarks", []))
	_rebuild_landmark_runtime_state()
	clear_cached_group_nodes()
	queue_redraw()


func debug_toggle_landmark_overlay() -> bool:
	debug_landmark_overlay_enabled = not debug_landmark_overlay_enabled
	queue_redraw()
	return debug_landmark_overlay_enabled


func debug_toggle_biome_textures() -> bool:
	biome_textures_enabled = not biome_textures_enabled
	if is_instance_valid(biome_blend_background):
		biome_blend_background.visible = false
		biome_blend_background.texture = null
	if biome_textures_enabled:
		_sync_biome_blend_background()
	queue_redraw()
	return biome_textures_enabled


func debug_toggle_biome_terrain_accents() -> bool:
	biome_terrain_accents_enabled = not biome_terrain_accents_enabled
	if biome_terrain_accents_enabled:
		_queue_biome_terrain_accent_cache_rebuild()
	else:
		biome_terrain_accent_cache.clear()
		pending_biome_terrain_accent_biomes.clear()
		biome_terrain_accent_cache_build_running = false
	queue_redraw()
	return biome_terrain_accents_enabled


func debug_rebuild_biome_texture_cache() -> void:
	biome_sample_images.clear()
	_ensure_render_controller().force_rebuild_biome_blend_texture()
	_sync_biome_blend_background()
	_queue_biome_terrain_accent_cache_rebuild()
	queue_redraw()


func debug_regenerate_landmarks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var new_seed: int = max(rng.randi(), 1)
	await _clear_landmark_areas()
	_clear_pond_vegetation_resources()
	world_seed = new_seed
	landmarks = WORLD_CONFIG.generate_landmarks(world_seed)
	_rebuild_landmark_runtime_state()
	await _respawn_pond_vegetation_for_current_landmarks()
	_sync_all_biome_vegetation()
	var game_session: Node = _get_game_session()
	if game_session and game_session.has_method("set_bootstrap_world_state"):
		game_session.set_bootstrap_world_state(world_seed, get_landmark_save_data())
	clear_cached_group_nodes()
	queue_redraw()
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_method("post_message"):
		event_bus.post_message("Regenerated landmarks with seed %d" % world_seed)


func _deserialize_landmark_save_data(landmark_data: Array) -> Array[Dictionary]:
	return _ensure_landmark_service().deserialize_landmark_save_data(landmark_data)


func _clear_landmark_areas() -> void:
	for landmark_area in get_tree().get_nodes_in_group("landmarks"):
		if is_instance_valid(landmark_area):
			landmark_area.queue_free()
	await get_tree().process_frame


func _clear_pond_vegetation_resources() -> void:
	for resource in get_tree().get_nodes_in_group("pond_vegetation"):
		if is_instance_valid(resource):
			resource.queue_free()


func _respawn_pond_vegetation_for_current_landmarks() -> void:
	await get_tree().process_frame
	var used_positions := _get_existing_resource_positions()
	await _spawn_pond_vegetation(used_positions, _get_player_position())


func _create_landmark_area(landmark: Dictionary, group_name: String) -> void:
	var area := Area2D.new()
	area.name = str(landmark.get("id", "landmark"))
	area.global_position = Vector2(landmark.get("position", Vector2.ZERO))
	area.collision_layer = 0
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = false
	area.set_meta("landmark_id", str(landmark.get("id", "")))
	area.set_meta("landmark_type", str(landmark.get("type", "")))
	area.set_meta("biome_id", str(landmark.get("biome_id", "")))
	area.set_meta("gameplay_tags", landmark.get("gameplay_tags", []))
	if str(landmark.get("type", "")) == "pond":
		area.set_meta("deep_water_speed_multiplier", _get_pond_deep_speed_multiplier())
		area.set_meta("shallow_water_speed_multiplier", _get_pond_shallow_speed_multiplier())
	area.add_to_group("landmarks")
	area.add_to_group(group_name)
	if str(landmark.get("type", "")) == "pond":
		area.add_to_group("water_sources")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = float(landmark.get("radius", 120.0))
	shape.shape = circle
	area.add_child(shape)
	add_child(area)


func _spawn_resources() -> void:
	var used_positions: Array[Vector2] = []
	var player_position := _get_player_position()
	var conifer_count := int(ceil(float(WORLD_CONFIG.TREE_COUNT) * 0.6))
	var leafy_count := WORLD_CONFIG.TREE_COUNT - conifer_count
	var dry_bush_count := int(ceil(float(WORLD_CONFIG.BUSH_COUNT) * 0.35))
	var green_bush_count := WORLD_CONFIG.BUSH_COUNT - dry_bush_count

	await _spawn_resource_kind("conifer_tree", conifer_count, used_positions, player_position)
	await _spawn_resource_kind_in_biome(
		"conifer_tree",
		WORLD_CONFIG.WESTWOOD_EXTRA_CONIFER_COUNT,
		"westwood",
		used_positions,
		player_position,
		WORLD_CONFIG.RESOURCE_MIN_DISTANCE * 0.72
	)
	await _spawn_resource_kind("leafy_tree", leafy_count, used_positions, player_position)
	await _spawn_resource_kind("dry_tree", int(ceil(float(WORLD_CONFIG.TREE_COUNT) * 0.10)), used_positions, player_position)
	await _spawn_resource_kind("rock", WORLD_CONFIG.ROCK_COUNT, used_positions, player_position)
	await _spawn_resource_kind("bush", green_bush_count, used_positions, player_position)
	await _spawn_resource_kind("dry_bush", dry_bush_count, used_positions, player_position)
	await _spawn_resource_kind("small_bush", WORLD_CONFIG.SMALL_BUSH_COUNT, used_positions, player_position)
	await _spawn_resource_kind("berry_bush", WORLD_CONFIG.BERRY_BUSH_COUNT, used_positions, player_position)
	await _spawn_resource_kind("grass_patch", WORLD_CONFIG.GRASS_PATCH_COUNT, used_positions, player_position)
	await _spawn_resource_kind("dense_grass", WORLD_CONFIG.DENSE_GRASS_COUNT, used_positions, player_position)
	await _spawn_pond_vegetation(used_positions, player_position)
	call_deferred("_sync_all_biome_vegetation")


func _spawn_resource_kind(resource_kind: String, count: int, used_positions: Array[Vector2], player_position: Vector2) -> void:
	var spawned_since_yield := 0
	for _i in count:
		if not _try_spawn_resource(resource_kind, used_positions, player_position):
			push_warning("Could not find a valid spawn position for %s" % resource_kind)
		spawned_since_yield += 1
		if spawned_since_yield >= INITIAL_SPAWN_BATCH_SIZE:
			spawned_since_yield = 0
			await get_tree().process_frame


func _spawn_resource_kind_in_biome(
	resource_kind: String,
	count: int,
	biome_id: String,
	used_positions: Array[Vector2],
	player_position: Vector2,
	min_distance: float = WORLD_CONFIG.RESOURCE_MIN_DISTANCE
) -> void:
	var biome := _get_biome_for_id(biome_id)
	if biome.is_empty():
		return
	var spawned_since_yield := 0
	for _i in count:
		if not _try_spawn_resource_in_biome(resource_kind, biome, used_positions, player_position, min_distance):
			push_warning("Could not find a valid spawn position for %s in biome %s" % [resource_kind, biome_id])
		spawned_since_yield += 1
		if spawned_since_yield >= INITIAL_SPAWN_BATCH_SIZE:
			spawned_since_yield = 0
			await get_tree().process_frame


func _spawn_pond_vegetation(used_positions: Array[Vector2], player_position: Vector2) -> void:
	for pond in pond_landmarks:
		var biome := _get_biome_for_id(str(pond.get("biome_id", "")))
		if biome.is_empty():
			continue
		var pond_kinds := [
			"dense_grass",
			"grass_patch",
			"dense_grass",
			"grass_patch",
			"small_bush",
			"dense_grass",
			"grass_patch",
			"berry_bush",
			"dense_grass",
			"grass_patch",
			"small_bush",
			"grass_patch"
		]
		var vegetation_count := _get_pond_vegetation_count()
		var angle_phase := resource_rng.randf_range(0.0, TAU)
		var spawned_since_yield := 0
		for i in vegetation_count:
			var kind := str(pond_kinds[i % pond_kinds.size()])
			_try_spawn_resource_near_pond(kind, pond, biome, used_positions, player_position, i, vegetation_count, angle_phase)
			spawned_since_yield += 1
			if spawned_since_yield >= INITIAL_SPAWN_BATCH_SIZE:
				spawned_since_yield = 0
				await get_tree().process_frame


func _try_spawn_resource_near_pond(resource_kind: String, pond: Dictionary, biome: Dictionary, used_positions: Array[Vector2], player_position: Vector2, slot_index: int, slot_count: int, angle_phase: float) -> bool:
	var slot_angle: float = TAU / float(max(slot_count, 1))
	var base_angle: float = angle_phase + slot_angle * float(slot_index)
	var ring_factor := _get_pond_vegetation_ring_factor(slot_index, slot_count)
	var min_ring_factor: float = max(ring_factor - POND_VEGETATION_RING_JITTER, 1.12)
	var max_ring_factor: float = ring_factor + POND_VEGETATION_RING_JITTER
	for _attempt in WORLD_CONFIG.RESOURCE_SPAWN_ATTEMPTS:
		var angle: float = base_angle + resource_rng.randf_range(-slot_angle, slot_angle) * POND_VEGETATION_ANGLE_JITTER_FACTOR
		var distance_factor := resource_rng.randf_range(min_ring_factor, max_ring_factor)
		var candidate := _get_pond_shape_position(pond, angle, distance_factor)
		if is_resource_position_blocked_by_water(resource_kind, candidate):
			continue
		if not _is_point_in_biome(candidate, biome):
			continue
		if _is_resource_blocked_by_hill(resource_kind, candidate):
			continue
		if not _is_valid_resource_position_with_min_distance(candidate, used_positions, player_position, _get_pond_vegetation_min_distance(), _get_pond_vegetation_player_safe_distance()):
			continue
		used_positions.append(candidate)
		var node := _spawn_resource_at(resource_kind, candidate)
		if node.has_method("set_pond_vegetation"):
			node.set_pond_vegetation(
				str(pond.get("id", "pond")),
				float(GAME_BALANCE.LANDMARKS.get("pond_grass_food_bonus", 1.0)),
				float(GAME_BALANCE.LANDMARKS.get("pond_vegetation_visual_scale", 1.0))
			)
		return true
	return false


func _get_pond_vegetation_count() -> int:
	var base_count := int(GAME_BALANCE.LANDMARKS.get("pond_vegetation_base_count", 6))
	var bonus := float(GAME_BALANCE.LANDMARKS.get("pond_vegetation_bonus", 1.0))
	return max(POND_VEGETATION_MIN_COUNT, int(round(float(base_count) * bonus)))


func _get_pond_vegetation_ring_factor(index: int, _count: int) -> float:
	var inner_factor := float(GAME_BALANCE.LANDMARKS.get("pond_vegetation_inner_ring_factor", POND_VEGETATION_RING_MIN_FACTOR))
	var outer_factor := float(GAME_BALANCE.LANDMARKS.get("pond_vegetation_outer_ring_factor", POND_VEGETATION_RING_MAX_FACTOR))
	var band_index := (index * 5) % 4
	match band_index:
		0:
			return inner_factor
		1:
			return lerp(inner_factor, outer_factor, 0.34)
		2:
			return lerp(inner_factor, outer_factor, 0.68)
		_:
			return outer_factor


func _get_pond_vegetation_min_distance() -> float:
	return float(GAME_BALANCE.LANDMARKS.get("pond_vegetation_min_distance", 46.0))


func _get_pond_vegetation_player_safe_distance() -> float:
	return float(GAME_BALANCE.LANDMARKS.get("pond_vegetation_player_safe_distance", 36.0))


func _is_position_in_pond_water(world_position: Vector2, pond: Dictionary, margin_multiplier: float = 1.0) -> bool:
	return _get_pond_water_ratio(world_position, pond) <= margin_multiplier


func _get_pond_shape_position(pond: Dictionary, angle: float, radius_factor: float) -> Vector2:
	var center := Vector2(pond.get("position", Vector2.ZERO))
	var radius := float(pond.get("radius", 0.0))
	var shape_scale := _get_pond_shape_scale(pond, angle)
	return center + Vector2(
		cos(angle) * radius * radius_factor * shape_scale,
		sin(angle) * radius * POND_VISUAL_Y_SCALE * radius_factor * shape_scale
	)


func _get_pond_water_ratio(world_position: Vector2, pond: Dictionary) -> float:
	var center := Vector2(pond.get("position", Vector2.ZERO))
	var radius := float(pond.get("radius", 0.0))
	if radius <= 0.0:
		return INF
	var offset := world_position - center
	var normalized := Vector2(offset.x / radius, offset.y / (radius * POND_VISUAL_Y_SCALE))
	var shape_scale := _get_pond_shape_scale(pond, normalized.angle())
	return normalized.length() / max(shape_scale, 0.1)


func _get_pond_shape_scale(pond: Dictionary, angle: float) -> float:
	var irregularity: float = _get_pond_shape_irregularity()
	if irregularity <= 0.0:
		return 1.0
	var seed_value: float = _get_pond_shape_seed(pond)
	var wave: float = (
		sin(angle * 2.0 + seed_value) * 0.55
		+ sin(angle * 3.0 - seed_value * 1.7) * 0.32
		+ sin(angle * 5.0 + seed_value * 0.6) * 0.18
	) / 1.05
	return clamp(1.0 + wave * irregularity, 1.0 - irregularity * 1.25, 1.0 + irregularity * 1.25)


func _get_pond_shape_seed(pond: Dictionary) -> float:
	var pond_id := str(pond.get("id", "pond"))
	var seed_value := 0
	for i in pond_id.length():
		seed_value = (seed_value + pond_id.unicode_at(i) * (i + 3)) % 997
	return float(seed_value) / 997.0 * TAU


func _get_pond_shape_irregularity() -> float:
	return float(clamp(float(GAME_BALANCE.LANDMARKS.get("pond_shape_irregularity", 0.16)), 0.0, 0.45))


func _get_pond_shape_sample_count() -> int:
	return max(16, int(GAME_BALANCE.LANDMARKS.get("pond_shape_sample_count", 48)))


func _get_pond_water_zone(world_position: Vector2, pond: Dictionary) -> String:
	var ratio := _get_pond_water_ratio(world_position, pond)
	if ratio <= _get_pond_deep_water_radius_factor():
		return WATER_ZONE_DEEP
	if ratio <= _get_pond_shallow_water_radius_factor():
		return WATER_ZONE_SHALLOW
	if ratio <= _get_pond_shore_radius_factor():
		return WATER_ZONE_SHORE
	return WATER_ZONE_LAND


func _get_pond_deep_water_radius_factor() -> float:
	return float(GAME_BALANCE.LANDMARKS.get("pond_deep_water_radius_factor", 0.68))


func _get_pond_shallow_water_radius_factor() -> float:
	return float(GAME_BALANCE.LANDMARKS.get("pond_shallow_water_radius_factor", 1.0))


func _get_pond_shore_radius_factor() -> float:
	return float(GAME_BALANCE.LANDMARKS.get("pond_shore_radius_factor", 1.12))


func _get_pond_deep_speed_multiplier() -> float:
	return float(GAME_BALANCE.LANDMARKS.get("pond_deep_speed_multiplier", 0.42))


func _get_pond_shallow_speed_multiplier() -> float:
	return float(GAME_BALANCE.LANDMARKS.get("pond_shallow_speed_multiplier", 0.68))


func _get_resource_water_margin_multiplier(resource_kind: String) -> float:
	match resource_kind:
		"conifer_tree", "leafy_tree", "tree":
			return float(GAME_BALANCE.LANDMARKS.get("pond_tree_water_margin", 1.22))
		"bush", "dry_bush", "small_bush", "berry_bush":
			return float(GAME_BALANCE.LANDMARKS.get("pond_bush_water_margin", 1.12))
		"grass_patch", "dense_grass":
			return float(GAME_BALANCE.LANDMARKS.get("pond_grass_water_margin", 1.04))
	return 1.0


func _is_position_in_hill_obstacle(world_position: Vector2, hill: Dictionary) -> bool:
	return _get_hill_shape_ratio(world_position, hill) <= HILL_RESOURCE_BLOCK_RADIUS_FACTOR


func _get_hill_shape_position(hill: Dictionary, angle: float, radius_factor: float, offset: Vector2 = Vector2.ZERO) -> Vector2:
	var center := Vector2(hill.get("position", Vector2.ZERO))
	var radius := float(hill.get("radius", 0.0))
	var shape_scale := _get_hill_shape_scale(hill, angle)
	return center + offset + Vector2(
		cos(angle) * radius * radius_factor * shape_scale,
		sin(angle) * radius * HILL_VISUAL_Y_SCALE * radius_factor * shape_scale
	)


func _get_hill_shape_ratio(world_position: Vector2, hill: Dictionary) -> float:
	var center := Vector2(hill.get("position", Vector2.ZERO))
	var radius := float(hill.get("radius", 0.0))
	if radius <= 0.0:
		return INF
	var offset := world_position - center
	var normalized := Vector2(offset.x / radius, offset.y / (radius * HILL_VISUAL_Y_SCALE))
	var shape_scale := _get_hill_shape_scale(hill, normalized.angle())
	return normalized.length() / max(shape_scale, 0.1)


func _get_hill_shape_scale(hill: Dictionary, angle: float) -> float:
	var irregularity: float = _get_hill_shape_irregularity()
	if irregularity <= 0.0:
		return 1.0
	var hill_seed: float = _get_hill_shape_seed(hill)
	var wave: float = (
		sin(angle * 2.0 + hill_seed) * 0.50
		+ sin(angle * 4.0 - hill_seed * 1.35) * 0.28
		+ sin(angle * 6.0 + hill_seed * 0.4) * 0.16
	) / 0.94
	return clamp(1.0 + wave * irregularity, 1.0 - irregularity * 1.15, 1.0 + irregularity * 1.15)


func _get_hill_shape_seed(hill: Dictionary) -> float:
	var hill_id := str(hill.get("id", "hill"))
	var hash_seed := 0
	for i in hill_id.length():
		hash_seed = (hash_seed + hill_id.unicode_at(i) * (i + 5)) % 997
	return float(hash_seed) / 997.0 * TAU


func _get_hill_shape_irregularity() -> float:
	return float(clamp(float(GAME_BALANCE.LANDMARKS.get("hill_shape_irregularity", 0.10)), 0.0, 0.35))


func _get_hill_shape_sample_count() -> int:
	return max(16, int(GAME_BALANCE.LANDMARKS.get("hill_shape_sample_count", 40)))


func _get_hill_mid_elevation_factor() -> float:
	return float(GAME_BALANCE.LANDMARKS.get("hill_mid_elevation_factor", 0.70))


func _get_hill_peak_elevation_factor() -> float:
	return float(GAME_BALANCE.LANDMARKS.get("hill_peak_elevation_factor", 0.38))


func _spawn_resource_at(resource_kind: String, pos: Vector2) -> Node:
	if _is_poolable_resource_kind(resource_kind):
		return _spawn_pooled_resource_at(resource_kind, pos)
	var node := RESOURCE_SCENE.instantiate()
	node.position = pos
	node.setup(resource_kind)
	add_child(node)
	call_deferred("_finalize_spawned_resource_node", node)
	return node


func _spawn_pooled_resource_at(resource_kind: String, pos: Vector2, loot_amount: int = 1) -> Node:
	var data := {
		"resource_kind": resource_kind,
		"position": pos,
		"loot_amount": loot_amount,
		"release_callback": Callable(self, "_release_pooled_resource_node")
	}
	var node := _ensure_pool_manager().acquire(RESOURCE_DROP_POOL_KEY, RESOURCE_SCENE, self, data)
	if node == null:
		return null
	_finalize_spawned_resource_node(node)
	return node


func _finalize_spawned_resource_node(node: Node) -> void:
	if not is_instance_valid(node):
		return
	register_resource_node(node)
	if node is Node2D:
		(node as Node2D).visible = true


func _release_pooled_resource_node(node: Node) -> void:
	if not is_instance_valid(node):
		return
	_ensure_registry().unregister_resource(node)
	if node is Node2D:
		(node as Node2D).visible = false
	clear_cached_group_nodes()
	var released := _ensure_pool_manager().release(RESOURCE_DROP_POOL_KEY, node)
	if not released:
		return
	if visibility_culling_enabled:
		_update_world_object_visibility()


func spawn_meat_drop_for_animal(animal_kind: String, drop_position: Vector2) -> Node:
	var amount: int = _get_meat_drop_amount(animal_kind)
	if amount <= 0:
		return null
	var initial_position: Vector2 = _clamp_position_to_world(drop_position)
	# Ensure meat drop does not spawn in water or hills.
	var safe_position: Vector2 = _find_safe_drop_position(
		"meat_drop",
		_get_safe_restored_resource_position("meat_drop", initial_position)
	)
	if is_resource_position_blocked_by_water("meat_drop", safe_position):
		push_warning("Meat drop for %s spawning in water at %s after fallback" % [animal_kind, safe_position])
	var node: Node = _spawn_pooled_resource_at("meat_drop", safe_position, amount)
	if node == null:
		return null
	if node is Node2D:
		(node as Node2D).visible = true
	if visibility_culling_enabled:
		_update_world_object_visibility()
	var event_bus := _get_event_bus()
	if event_bus:
		event_bus.emit_game_event("animal_dropped_meat", {
			"animal_kind": animal_kind,
			"amount": amount,
			"position": node.global_position
		})
	return node


func spawn_bone_drop_for_animal(animal_kind: String, drop_position: Vector2) -> Node:
	var amount: int = _get_bone_drop_amount(animal_kind)
	if amount <= 0:
		return null
	var initial_position: Vector2 = _clamp_position_to_world(drop_position)
	var safe_position: Vector2 = _find_safe_drop_position(
		"bone_drop",
		_get_safe_restored_resource_position("bone_drop", initial_position)
	)
	if is_resource_position_blocked_by_water("bone_drop", safe_position):
		push_warning("Bone drop for %s spawning in water at %s after fallback" % [animal_kind, safe_position])
	var node: Node = _spawn_pooled_resource_at("bone_drop", safe_position, amount)
	if node == null:
		return null
	if node is Node2D:
		(node as Node2D).visible = true
	if visibility_culling_enabled:
		_update_world_object_visibility()
	var event_bus := _get_event_bus()
	if event_bus:
		event_bus.emit_game_event("animal_dropped_bone", {
			"animal_kind": animal_kind,
			"amount": amount,
			"position": node.global_position
		})
	return node


func _get_meat_drop_amount(animal_kind: String) -> int:
	var loot: Dictionary = GAME_BALANCE.ANIMAL_LOOT.get(animal_kind, {})
	if loot.is_empty():
		return 0
	var min_amount := int(loot.get("meat_min", 0))
	var max_amount := int(loot.get("meat_max", min_amount))
	if max_amount < min_amount:
		max_amount = min_amount
	return resource_rng.randi_range(min_amount, max_amount)


func _get_bone_drop_amount(animal_kind: String) -> int:
	var loot: Dictionary = GAME_BALANCE.ANIMAL_LOOT.get(animal_kind, {})
	if loot.is_empty():
		return 0
	var min_amount := int(loot.get("bone_min", 0))
	var max_amount := int(loot.get("bone_max", min_amount))
	if max_amount < min_amount:
		max_amount = min_amount
	return resource_rng.randi_range(min_amount, max_amount)


func _find_safe_drop_position(resource_kind: String, origin: Vector2, radius: float = 18.0) -> Vector2:
	var candidates: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(24.0, 0.0),
		Vector2(-24.0, 0.0),
		Vector2(0.0, 24.0),
		Vector2(0.0, -24.0),
		Vector2(32.0, 16.0),
		Vector2(-32.0, 16.0),
		Vector2(32.0, -16.0),
		Vector2(-32.0, -16.0),
		Vector2(48.0, 0.0),
		Vector2(-48.0, 0.0),
		Vector2(0.0, 48.0),
		Vector2(0.0, -48.0)
	]
	for offset in candidates:
		var candidate := origin + offset
		if _is_valid_drop_position(candidate, radius, resource_kind):
			return candidate
	return origin


func _is_valid_drop_position(drop_position: Vector2, radius: float = 18.0, resource_kind: String = "") -> bool:
	if not WORLD_CONFIG.WORLD_RECT.has_point(drop_position):
		return false
	if resource_kind != "" and is_resource_position_blocked_by_water(resource_kind, drop_position):
		return false
	for landmark in get_tree().get_nodes_in_group("landmarks"):
		if not is_instance_valid(landmark):
			continue
		var landmark_node := landmark as Node2D
		if landmark_node == null:
			continue
		var safe_distance := 48.0
		var custom_radius: Variant = landmark.get("radius") if landmark.has_method("get") else null
		if custom_radius != null:
			safe_distance = maxf(float(custom_radius), safe_distance)
		if landmark_node.global_position.distance_to(drop_position) < safe_distance + radius:
			return false
	return true


func _try_spawn_resource(resource_kind: String, used_positions: Array[Vector2], player_position: Vector2) -> bool:
	for _attempt in WORLD_CONFIG.RESOURCE_SPAWN_ATTEMPTS:
		var biome := _pick_resource_biome(resource_kind)
		var spawn_area := _get_biome_bounds(biome).grow(-WORLD_CONFIG.RESOURCE_SPAWN_MARGIN)
		var candidate := Vector2(
			resource_rng.randf_range(spawn_area.position.x, spawn_area.end.x),
			resource_rng.randf_range(spawn_area.position.y, spawn_area.end.y)
		)
		if is_resource_position_blocked_by_water(resource_kind, candidate):
			continue
		if _is_resource_blocked_by_hill(resource_kind, candidate):
			continue
		if _is_point_in_biome(candidate, biome) and _is_valid_resource_position(candidate, used_positions, player_position):
			used_positions.append(candidate)
			_spawn_resource_at(resource_kind, candidate)
			return true
	return false


func _pick_resource_biome(resource_kind: String) -> Dictionary:
	var total_weight := 0.0
	for biome_value in WORLD_CONFIG.BIOME_ZONES:
		var biome := Dictionary(biome_value)
		total_weight += _get_biome_resource_weight(biome, resource_kind)
	if total_weight <= 0.0:
		return Dictionary(WORLD_CONFIG.BIOME_ZONES[0])

	var roll := resource_rng.randf_range(0.0, total_weight)
	var cursor := 0.0
	for biome_value in WORLD_CONFIG.BIOME_ZONES:
		var biome := Dictionary(biome_value)
		cursor += _get_biome_resource_weight(biome, resource_kind)
		if roll <= cursor:
			return biome
	return Dictionary(WORLD_CONFIG.BIOME_ZONES[0])


func _get_biome_resource_weight(biome: Dictionary, resource_kind: String) -> float:
	match resource_kind:
		"tree", "conifer_tree":
			return float(biome.get("conifer_tree_weight", biome.get("tree_weight", 0.0)))
		"leafy_tree":
			return float(biome.get("leafy_tree_weight", biome.get("tree_weight", 0.0)))
		"dry_tree":
			return float(biome.get("dry_tree_weight", biome.get("tree_weight", 0.0)))
		"rock":
			return float(biome.get("rock_weight", 0.0))
		"bush", "small_bush":
			return float(biome.get("bush_weight", 0.0))
		"dry_bush":
			return float(biome.get("dry_bush_weight", biome.get("bush_weight", 0.0)))
		"berry_bush":
			return float(biome.get("berry_bush_weight", biome.get("bush_weight", 0.0)))
		"grass_patch", "dense_grass":
			return float(biome.get("grass_weight", 0.0))
		_:
			return 0.0


func _get_biome_bounds(biome: Dictionary) -> Rect2:
	var points := _get_runtime_biome_points(biome)
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


func _is_point_in_biome(point: Vector2, biome: Dictionary) -> bool:
	return Geometry2D.is_point_in_polygon(point, _get_runtime_biome_points(biome))


func _get_runtime_biome_points(biome: Dictionary) -> PackedVector2Array:
	if biome.has("bounds"):
		return PackedVector2Array(biome.get("points", []))
	return PackedVector2Array(WORLD_CONFIG.get_biome_points(biome))


func _is_valid_resource_position(candidate: Vector2, used_positions: Array[Vector2], player_position: Vector2) -> bool:
	return _is_valid_resource_position_with_min_distance(candidate, used_positions, player_position, WORLD_CONFIG.RESOURCE_MIN_DISTANCE)


func _is_valid_resource_position_with_min_distance(candidate: Vector2, used_positions: Array[Vector2], player_position: Vector2, min_distance: float, player_safe_distance: float = WORLD_CONFIG.RESOURCE_PLAYER_SAFE_DISTANCE) -> bool:
	if candidate.distance_to(player_position) < player_safe_distance:
		return false
	for used_position in used_positions:
		if candidate.distance_to(used_position) < min_distance:
			return false
	return true


func _is_resource_blocked_by_hill(resource_kind: String, candidate: Vector2) -> bool:
	if not _is_plant_resource_kind(resource_kind):
		return false
	for hill in hill_landmarks:
		var center := Vector2(hill.get("position", Vector2.ZERO))
		var blocked_radius := float(hill.get("radius", 0.0)) * HILL_RESOURCE_BLOCK_RADIUS_FACTOR
		if candidate.distance_to(center) < blocked_radius:
			return true
	return false


func _is_plant_resource_kind(resource_kind: String) -> bool:
	return resource_kind in PLANT_RESOURCE_KINDS


func _get_player_position() -> Vector2:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		return player.global_position
	return Vector2.ZERO


func advance_resource_growth_days(days: float) -> void:
	var changed_count := _ensure_resource_service().advance_growth_days(get_registered_resources(), days)
	if changed_count > 0:
		var event_bus := _get_event_bus()
		if event_bus:
			event_bus.post_message("%d resources advanced growth" % changed_count)


func debug_advance_resource_growth_day() -> void:
	advance_resource_growth_days(1.0)


func debug_force_full_vegetation_regrowth() -> void:
	var changed_count := 0
	for resource in get_registered_resources():
		if not is_instance_valid(resource) or not resource.has_method("force_full_regrowth"):
			continue
		resource.force_full_regrowth()
		changed_count += 1
	var event_bus := _get_event_bus()
	if event_bus:
		event_bus.post_message("Forced full regrowth on %d resources" % changed_count)


func debug_reset_resource_growth() -> void:
	var changed_count := 0
	for resource in get_registered_resources():
		if not is_instance_valid(resource) or not resource.has_method("reset_growth_state"):
			continue
		resource.reset_growth_state()
		changed_count += 1
	var event_bus := _get_event_bus()
	if event_bus:
		event_bus.post_message("Reset growth state on %d resources" % changed_count)


func debug_test_resource_drop_pool() -> Dictionary:
	var before := get_pool_debug_snapshot()
	var spawned: Array[Node] = []
	var base_position := _get_player_position()
	for i in range(12):
		var offset := Vector2(float(i % 4) * 18.0, (float(i) / 4.0) * 18.0)
		var node := _spawn_pooled_resource_at("meat_drop", base_position + offset, 1)
		if node != null:
			spawned.append(node)
	for node in spawned:
		if is_instance_valid(node):
			_release_pooled_resource_node(node)
	var reused: Array[Node] = []
	for i in range(6):
		var offset := Vector2(float(i) * 18.0, 72.0)
		var node := _spawn_pooled_resource_at("meat_drop", base_position + offset, 1)
		if node != null:
			reused.append(node)
	var after := get_pool_debug_snapshot()
	for node in reused:
		if is_instance_valid(node):
			_release_pooled_resource_node(node)
	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_method("post_message"):
		event_bus.post_message("Pool test finished: %s" % get_pool_debug_text())
	return {
		"before": before,
		"after": after,
		"summary": get_pool_debug_text()
	}


func get_resource_growth_debug_summary() -> Dictionary:
	var summary := {
		"depleted": 0,
		"sprout": 0,
		"young": 0,
		"mature": 0
	}
	for resource in get_registered_resources():
		if not is_instance_valid(resource) or not resource.has_method("get_growth_debug_text"):
			continue
		var stage := int(resource.get("growth_stage"))
		match stage:
			0:
				summary["depleted"] += 1
			1:
				summary["sprout"] += 1
			2:
				summary["young"] += 1
			_:
				summary["mature"] += 1
	return summary


func get_resource_save_data() -> Array[Dictionary]:
	return _ensure_resource_service().build_save_data(get_registered_resources())


func restore_resources(resources: Array) -> void:
	for resource in get_registered_resources():
		if is_instance_valid(resource):
			resource.queue_free()
	await get_tree().process_frame
	_ensure_resource_service().restore_resources_from_data(
		resources,
		Callable(self, "_get_safe_restored_resource_position"),
		Callable(self, "_spawn_restored_resource_at"),
		Callable(self, "_apply_restored_resource_data")
	)


func _get_safe_restored_resource_position(resource_kind: String, requested_position: Variant) -> Vector2:
	var requested_vector := Vector2.ZERO
	if typeof(requested_position) == TYPE_VECTOR2:
		requested_vector = requested_position
	elif typeof(requested_position) == TYPE_DICTIONARY:
		var requested_data := Dictionary(requested_position)
		requested_vector = Vector2(
			float(requested_data.get("x", 0.0)),
			float(requested_data.get("y", 0.0))
		)
	else:
		requested_vector = Vector2.ZERO
	var safe_position := _clamp_position_to_world(requested_vector)
	if not is_resource_position_blocked_by_water(resource_kind, safe_position) and not _is_resource_blocked_by_hill(resource_kind, safe_position):
		return safe_position
	var pond := _get_nearest_pond_landmark(safe_position)
	if pond.is_empty():
		return safe_position
	var center := Vector2(pond.get("position", Vector2.ZERO))
	var radius := float(pond.get("radius", 0.0))
	if radius <= 0.0:
		return safe_position
	var direction := safe_position - center
	var base_angle := direction.angle() if direction.length_squared() > 0.001 else 0.0
	var base_radius_factor: float = max(_get_resource_water_margin_multiplier(resource_kind) + 0.08, 1.16)
	var used_positions := _get_existing_resource_positions()
	var player_position := _get_player_position()
	for attempt in 48:
		var angle := base_angle + float(attempt) * 0.83
		var radius_factor: float = base_radius_factor + floor(float(attempt) / 8.0) * WORLD_CONFIG.RESOURCE_MIN_DISTANCE / radius
		var candidate := _clamp_position_to_world(_get_pond_shape_position(pond, angle, radius_factor))
		if is_resource_position_blocked_by_water(resource_kind, candidate):
			continue
		if _is_resource_blocked_by_hill(resource_kind, candidate):
			continue
		if _get_biome_for_position(candidate).is_empty():
			continue
		if _is_valid_resource_position(candidate, used_positions, player_position):
			return candidate
	for attempt in 48:
		var angle := base_angle - float(attempt) * 0.83
		var radius_factor: float = base_radius_factor + floor(float(attempt) / 8.0) * WORLD_CONFIG.RESOURCE_MIN_DISTANCE / radius
		var candidate := _clamp_position_to_world(_get_pond_shape_position(pond, angle, radius_factor))
		if not is_resource_position_blocked_by_water(resource_kind, candidate) and not _is_resource_blocked_by_hill(resource_kind, candidate) and not _get_biome_for_position(candidate).is_empty():
			return candidate
	return safe_position


func _apply_restored_resource_data(resource_node: Variant, resource_data: Dictionary) -> bool:
	var data := Dictionary(resource_data).duplicate(true)
	var restored_position := _data_to_vector(data.get("position", {}))
	data["position"] = _vector_to_data(restored_position)
	data["biome_id"] = _get_biome_id_for_position(restored_position)
	return _ensure_resource_service().apply_restore_data(resource_node, data)


func _spawn_restored_resource_at(resource_kind: String, position_data: Variant) -> Node:
	if typeof(position_data) == TYPE_VECTOR2:
		return _spawn_resource_at(resource_kind, position_data)
	if typeof(position_data) == TYPE_DICTIONARY:
		return _spawn_resource_at(resource_kind, _data_to_vector(Dictionary(position_data)))
	return _spawn_resource_at(resource_kind, Vector2.ZERO)


func _get_nearest_pond_landmark(search_position: Vector2) -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_distance := INF
	for pond in pond_landmarks:
		var center := Vector2(pond.get("position", Vector2.ZERO))
		var distance := search_position.distance_squared_to(center)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = pond
	return nearest


func _sync_visible_small_prey() -> void:
	if not ecosystem_director or not ecosystem_director.has_method("get_biome_state"):
		return
	if small_prey_failed_spawn_retry_timer > 0.0 and not integration_test_mode:
		small_prey_spawn_sync_skipped_by_cooldown_count += 1
		return
	small_prey_spawn_sync_attempt_count += 1
	var player_position := _get_player_position()
	var player_biome := _get_biome_for_position(player_position)
	if player_biome.is_empty():
		return
	var biome_id := _get_biome_id(player_biome)
	var biome_state: Dictionary = ecosystem_director.get_biome_state(biome_id)
	if biome_state.is_empty():
		return
	var desired_count := _get_desired_small_prey_count(player_biome, biome_state)
	var current_biome_count := _get_visible_small_prey_count(biome_id)
	var global_count := get_registered_creatures_by_type("small_prey").size()
	var requested_count: int = min(desired_count - current_biome_count, SMALL_PREY_MAX_VISIBLE_COUNT - global_count)
	small_prey_spawn_sync_last_requested = requested_count
	if requested_count <= 0:
		return
	var spawned := 0
	var used_positions := _get_existing_small_prey_positions()
	for slot_index in requested_count:
		if _try_spawn_small_prey_near_player(player_biome, player_position, used_positions, slot_index, requested_count):
			spawned += 1
	if spawned > 0:
		var event_bus := _get_event_bus()
		if event_bus:
			event_bus.post_message("%d SmallPrey entered the ecosystem" % spawned)
	var failed_count: int = requested_count - spawned
	if failed_count <= 0:
		small_prey_failed_spawn_retry_timer = 0.0
		small_prey_failed_spawn_warning_printed = false
		small_prey_spawn_sync_last_failed = 0
		small_prey_spawn_sync_last_success = requested_count
		return
	small_prey_failed_spawn_retry_timer = SMALL_PREY_FAILED_SPAWN_RETRY_SECONDS
	small_prey_spawn_sync_failed_count += 1
	small_prey_spawn_sync_last_failed = failed_count
	small_prey_spawn_sync_last_success = spawned
	if not small_prey_failed_spawn_warning_printed:
		push_warning("Failed to spawn %d out of %d SmallPrey. Retrying in %.1f seconds." % [
			failed_count,
			requested_count,
			SMALL_PREY_FAILED_SPAWN_RETRY_SECONDS
		])
		small_prey_failed_spawn_warning_printed = true


func _get_desired_small_prey_count(biome: Dictionary, biome_state: Dictionary) -> int:
	var population := float(biome_state.get("small_prey_population", 0.0))
	var biomass_percent := float(biome_state.get("plant_biomass_percent", 0.0))
	var population_factor: float = clamp(population / 12.0, 0.0, 1.0)
	var biomass_factor: float = clamp(biomass_percent / 100.0, 0.0, 1.0)
	var danger_factor := 0.45 if biome.get("dangerous", false) == true else 1.0
	var desired := int(round(float(SMALL_PREY_MAX_VISIBLE_PER_BIOME) * population_factor * biomass_factor * danger_factor))
	if population > 0.0 and biomass_percent >= 30.0:
		desired = max(desired, 1)
	return clamp(desired, 0, SMALL_PREY_MAX_VISIBLE_PER_BIOME)


func _get_visible_small_prey_count(biome_id: String) -> int:
	var count := 0
	for small_prey in get_registered_creatures_by_type("small_prey"):
		if not is_instance_valid(small_prey):
			continue
		if _get_biome_id_for_position(small_prey.global_position) == biome_id:
			count += 1
	return count


func _get_existing_small_prey_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for small_prey in get_registered_creatures_by_type("small_prey"):
		if is_instance_valid(small_prey):
			positions.append(small_prey.global_position)
	return positions


func _try_spawn_small_prey_near_player(biome: Dictionary, player_position: Vector2, used_positions: Array[Vector2], slot_index: int, _slot_count: int) -> bool:
	var spawn_ring := _get_creature_horizon_spawn_ring()
	for _attempt in WORLD_CONFIG.RESOURCE_SPAWN_ATTEMPTS:
		var offset := Vector2.RIGHT.rotated(small_prey_rng.randf_range(0.0, TAU)) * small_prey_rng.randf_range(spawn_ring.x, spawn_ring.y)
		var candidate := player_position + offset
		if not _is_point_in_biome(candidate, biome):
			continue
		if not _is_valid_small_prey_position(candidate, used_positions, player_position, spawn_ring.x):
			continue
		used_positions.append(candidate)
		_spawn_small_prey_at(candidate, _get_biome_id(biome))
		return true
	var fallback_position := _find_valid_creature_position_in_biome(
		biome,
		player_position,
		used_positions,
		SMALL_PREY_MIN_DISTANCE,
		SMALL_PREY_PLAYER_SAFE_DISTANCE,
		small_prey_rng,
		WORLD_CONFIG.RESOURCE_SPAWN_ATTEMPTS * 2
	)
	if fallback_position != Vector2.INF:
		used_positions.append(fallback_position)
		_spawn_small_prey_at(fallback_position, _get_biome_id(biome))
		return true
	var player_limits: Vector2 = WORLD_CONFIG.get_player_limits()
	for distance_step in 8:
		var distance_factor: float = float(distance_step) / 7.0
		var distance: float = lerp(spawn_ring.y, spawn_ring.x, distance_factor)
		for angle_step in 48:
			var angle: float = TAU * float(angle_step) / 48.0 + float(slot_index) * 0.21
			var candidate: Vector2 = player_position + Vector2.RIGHT.rotated(angle) * distance
			candidate.x = clamp(candidate.x, -player_limits.x, player_limits.x)
			candidate.y = clamp(candidate.y, -player_limits.y, player_limits.y)
			if not _is_point_in_biome(candidate, biome):
				continue
			if not _is_valid_small_prey_position(candidate, used_positions, player_position, spawn_ring.x):
				continue
			used_positions.append(candidate)
			_spawn_small_prey_at(candidate, _get_biome_id(biome))
			return true
	return false


func _is_valid_small_prey_position(candidate: Vector2, used_positions: Array[Vector2], player_position: Vector2, player_safe_distance: float = SMALL_PREY_PLAYER_SAFE_DISTANCE) -> bool:
	return _is_valid_creature_spawn_position(
		candidate,
		used_positions,
		SMALL_PREY_MIN_DISTANCE,
		player_position,
		player_safe_distance
	)


func _get_biome_for_position(target_position: Vector2) -> Dictionary:
	for biome in WORLD_CONFIG.get_biome_zones():
		if _is_point_in_biome(target_position, biome):
			return biome
	return {}


func _get_weighted_biome_for_resource(resource_kind: String) -> Dictionary:
	var total_weight := 0.0
	for biome_value in WORLD_CONFIG.get_biome_zones():
		total_weight += _get_biome_resource_weight(Dictionary(biome_value), resource_kind)
	if total_weight <= 0.0:
		return Dictionary(WORLD_CONFIG.BIOME_ZONES[0])
	var roll := resource_rng.randf_range(0.0, total_weight)
	var cursor := 0.0
	for biome_value in WORLD_CONFIG.get_biome_zones():
		var biome: Dictionary = Dictionary(biome_value)
		cursor += _get_biome_resource_weight(biome, resource_kind)
		if roll <= cursor:
			return biome
	return Dictionary(WORLD_CONFIG.BIOME_ZONES[0])


func _get_biome_id(biome: Dictionary) -> String:
	return str(biome.get("name", "biome")).to_snake_case()


func _get_biome_id_for_position(target_position: Vector2) -> String:
	var biome := _get_biome_for_position(target_position)
	if biome.is_empty():
		return ""
	return _get_biome_id(biome)


func _find_valid_creature_position_in_biome(
	biome: Dictionary,
	player_position: Vector2,
	used_positions: Array[Vector2],
	min_distance: float,
	player_safe_distance: float,
	rng: RandomNumberGenerator,
	max_attempts: int = 96
) -> Vector2:
	if biome.is_empty():
		return Vector2.INF
	var bounds := _get_scaled_biome_bounds(biome).grow(-WORLD_CONFIG.RESOURCE_SPAWN_MARGIN)
	for _attempt in max_attempts:
		var candidate := Vector2(
			rng.randf_range(bounds.position.x, bounds.end.x),
			rng.randf_range(bounds.position.y, bounds.end.y)
		)
		if not _is_point_in_biome(candidate, biome):
			continue
		if not _is_valid_creature_spawn_position(
			candidate,
			used_positions,
			min_distance,
			player_position,
			player_safe_distance
		):
			continue
		return candidate
	return Vector2.INF


func _sync_all_biome_vegetation() -> void:
	var changed := false
	for biome in WORLD_CONFIG.get_biome_zones():
		changed = _sync_biome_vegetation(_get_biome_id(biome)) or changed
	if changed:
		queue_redraw()


func _sync_periodic_rock_spawn() -> bool:
	var biome := _get_weighted_biome_for_resource("rock")
	if biome.is_empty():
		return false
	var used_positions := _get_existing_resource_positions()
	var spawned := false
	if _try_spawn_resource_in_biome("rock", biome, used_positions, _get_player_position(), WORLD_CONFIG.RESOURCE_MIN_DISTANCE * 0.9):
		spawned = true
	if spawned:
		queue_redraw()
	return spawned


func _sync_biome_vegetation(biome_id: String) -> bool:
	var biome := _get_biome_for_id(biome_id)
	if biome.is_empty():
		return false
	var used_positions := _get_existing_resource_positions()
	var changed := false
	for resource_kind in PLANT_RESOURCE_KINDS:
		var kind := str(resource_kind)
		var target_count := _get_biome_resource_target_count(biome, kind)
		var current_resources := _get_plant_resources_in_biome(biome_id, kind)
		var current_count := current_resources.size()
		if current_count < target_count:
			for _i in target_count - current_count:
				if _try_spawn_resource_in_biome(kind, biome, used_positions, _get_player_position(), WORLD_CONFIG.RESOURCE_MIN_DISTANCE):
					changed = true
	if changed:
		return true
	return false


func _get_biome_for_id(biome_id: String) -> Dictionary:
	for biome in WORLD_CONFIG.get_biome_zones():
		if _get_biome_id(biome) == biome_id:
			return biome
	return {}


func _get_biome_resource_target_count(biome: Dictionary, resource_kind: String) -> int:
	var base_count := _get_base_resource_count(resource_kind)
	if base_count <= 0:
		return 0
	var total_weight := 0.0
	for biome_value in WORLD_CONFIG.get_biome_zones():
		total_weight += _get_biome_resource_weight(Dictionary(biome_value), resource_kind)
	if total_weight <= 0.0:
		return 0
	var biome_id := _get_biome_id(biome)
	var weight := _get_biome_resource_weight(biome, resource_kind)
	var full_biomass_count := int(round(float(base_count) * weight / total_weight))
	var biomass_factor := _get_biome_biomass_factor(biome_id)
	return int(round(float(full_biomass_count) * biomass_factor))


func _get_base_resource_count(resource_kind: String) -> int:
	match resource_kind:
		"conifer_tree":
			return int(ceil(float(WORLD_CONFIG.TREE_COUNT) * 0.50))
		"leafy_tree":
			return WORLD_CONFIG.TREE_COUNT - int(ceil(float(WORLD_CONFIG.TREE_COUNT) * 0.50)) - int(ceil(float(WORLD_CONFIG.TREE_COUNT) * 0.10))
		"dry_tree":
			return int(ceil(float(WORLD_CONFIG.TREE_COUNT) * 0.10))
		"bush":
			return WORLD_CONFIG.BUSH_COUNT - int(ceil(float(WORLD_CONFIG.BUSH_COUNT) * 0.35))
		"dry_bush":
			return int(ceil(float(WORLD_CONFIG.BUSH_COUNT) * 0.35))
		"small_bush":
			return WORLD_CONFIG.SMALL_BUSH_COUNT
		"berry_bush":
			return WORLD_CONFIG.BERRY_BUSH_COUNT
		"grass_patch":
			return WORLD_CONFIG.GRASS_PATCH_COUNT
		"dense_grass":
			return WORLD_CONFIG.DENSE_GRASS_COUNT
	return 0


func _get_biome_biomass_factor(biome_id: String) -> float:
	if not ecosystem_director or not ecosystem_director.has_method("get_biome_state"):
		return 1.0
	var biome_state: Dictionary = ecosystem_director.get_biome_state(biome_id)
	if biome_state.is_empty():
		return 1.0
	return clamp(float(biome_state.get("plant_biomass_percent", 100.0)) / 100.0, 0.0, 1.0)


func _get_plant_resources_in_biome(biome_id: String, resource_kind: String) -> Array[Node2D]:
	var resources: Array[Node2D] = []
	for resource in get_registered_resources_by_kind(resource_kind):
		if not is_instance_valid(resource) or resource.is_queued_for_deletion():
			continue
		if _get_biome_id_for_position(resource.global_position) == biome_id:
			resources.append(resource)
	return resources


func _get_existing_resource_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for resource in get_registered_resources():
		if is_instance_valid(resource) and not resource.is_queued_for_deletion():
			positions.append(resource.global_position)
	return positions


func _remove_plant_resources(resources: Array[Node2D], count: int) -> void:
	var player_position := _get_player_position()
	resources.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(player_position) < b.global_position.distance_squared_to(player_position)
	)
	var removed := 0
	for resource in resources:
		if removed >= count:
			break
		if not is_instance_valid(resource):
			continue
		resource.queue_free()
		removed += 1


func _try_spawn_resource_in_biome(
	resource_kind: String,
	biome: Dictionary,
	used_positions: Array[Vector2],
	player_position: Vector2,
	min_distance: float
) -> bool:
	for _attempt in WORLD_CONFIG.RESOURCE_SPAWN_ATTEMPTS:
		var spawn_area := _get_biome_bounds(biome).grow(-WORLD_CONFIG.RESOURCE_SPAWN_MARGIN)
		var candidate := Vector2(
			resource_rng.randf_range(spawn_area.position.x, spawn_area.end.x),
			resource_rng.randf_range(spawn_area.position.y, spawn_area.end.y)
		)

		if is_resource_position_blocked_by_water(resource_kind, candidate):
			continue
		if _is_resource_blocked_by_hill(resource_kind, candidate):
			continue
		if not _is_point_in_biome(candidate, biome):
			continue
		if not _is_valid_resource_position_with_min_distance(candidate, used_positions, player_position, min_distance):
			continue

		used_positions.append(candidate)
		_spawn_resource_at(resource_kind, candidate)
		return true

	return false


func _get_scaled_biome_bounds(biome: Dictionary) -> Rect2:
	var points := PackedVector2Array(biome["points"])
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


func _is_point_in_scaled_biome(point: Vector2, biome: Dictionary) -> bool:
	return Geometry2D.is_point_in_polygon(point, PackedVector2Array(biome["points"]))


func _spawn_small_prey_at(pos: Vector2, biome_id: String) -> Node:
	var small_prey := SMALL_PREY_SCENE.instantiate()
	small_prey.global_position = pos
	if small_prey.has_method("setup"):
		small_prey.setup(biome_id)
	add_child(small_prey)
	register_creature_node(small_prey, "small_prey")
	return small_prey


func _spawn_initial_grazers() -> void:
	var player_position := _get_player_position()
	var grazer_biomes := _get_initial_grazer_biomes()
	if grazer_biomes.is_empty():
		return
	var spawned := 0
	var used_positions := _get_existing_grazer_positions()
	for i in INITIAL_GRAZER_VISIBLE_COUNT:
		var biome := Dictionary(grazer_biomes[i % grazer_biomes.size()])
		if _try_spawn_grazer_in_biome(biome, player_position, used_positions):
			spawned += 1
	if spawned > 0:
		var event_bus := _get_event_bus()
		if event_bus:
			event_bus.post_message("%d Grazer%s dispersed into the ecosystem" % [spawned, "" if spawned == 1 else "s"])


func _sync_visible_grazers() -> void:
	if not ecosystem_director or not ecosystem_director.has_method("get_biome_state"):
		return
	var player_position := _get_player_position()
	var player_biome := _get_biome_for_position(player_position)
	if player_biome.is_empty():
		return
	var biome_id := _get_biome_id(player_biome)
	var biome_state: Dictionary = ecosystem_director.get_biome_state(biome_id)
	if biome_state.is_empty():
		return
	var desired_count := _get_desired_grazer_count(biome_state)
	var current_biome_count := _get_visible_grazer_count(biome_id)
	var global_count := get_registered_creatures_by_type("grazer").size()
	var spawn_budget: int = min(desired_count - current_biome_count, GRAZER_MAX_VISIBLE_COUNT - global_count)
	if spawn_budget <= 0:
		return
	var spawned := 0
	var used_positions := _get_existing_grazer_positions()
	for _i in spawn_budget:
		if _try_spawn_grazer_near_player(player_biome, player_position, used_positions):
			spawned += 1
	if spawned > 0:
		var event_bus := _get_event_bus()
		if event_bus:
			event_bus.post_message("%d Grazer%s entered the ecosystem" % [spawned, "" if spawned == 1 else "s"])
	elif spawned < spawn_budget:
		push_warning("Failed to spawn %d out of %d Grazers" % [spawn_budget - spawned, spawn_budget])


func _get_desired_grazer_count(biome_state: Dictionary) -> int:
	var population := float(biome_state.get("grazer_population", 0.0))
	var biomass_percent := float(biome_state.get("plant_biomass_percent", 0.0))
	var target_population := float(GAME_BALANCE.POPULATION_RECOVERY["grazer_target_population"])
	var population_factor: float = clamp(population / maxf(target_population, 1.0), 0.0, 1.0)
	var biomass_factor: float = clamp(biomass_percent / 100.0, 0.0, 1.0)
	var desired := int(round(float(GRAZER_MAX_VISIBLE_PER_BIOME) * population_factor * biomass_factor))
	if population > 0.0 and biomass_percent >= 30.0:
		desired = max(desired, 1)
	return clampi(desired, 0, GRAZER_MAX_VISIBLE_PER_BIOME)


func _get_visible_grazer_count(biome_id: String) -> int:
	var count := 0
	for grazer in get_registered_creatures_by_type("grazer"):
		if not is_instance_valid(grazer):
			continue
		if _get_biome_id_for_position(grazer.global_position) == biome_id:
			count += 1
	return count


func _get_initial_grazer_biomes() -> Array[Dictionary]:
	var biomes: Array[Dictionary] = []
	for biome_value in WORLD_CONFIG.get_biome_zones():
		var biome := Dictionary(biome_value)
		if biome.get("dangerous", false) == true:
			continue
		biomes.append(biome)
	biomes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_score := float(a.get("grass_weight", 1.0)) + float(a.get("bush_weight", 1.0)) * 0.35
		var b_score := float(b.get("grass_weight", 1.0)) + float(b.get("bush_weight", 1.0)) * 0.35
		return a_score > b_score
	)
	return biomes


func _try_spawn_grazer_in_biome(biome: Dictionary, player_position: Vector2, used_positions: Array[Vector2]) -> bool:
	var spawn_area := _get_scaled_biome_bounds(biome).grow(-WORLD_CONFIG.RESOURCE_SPAWN_MARGIN)
	for _attempt in WORLD_CONFIG.RESOURCE_SPAWN_ATTEMPTS:
		var candidate := Vector2(
			grazer_rng.randf_range(spawn_area.position.x, spawn_area.end.x),
			grazer_rng.randf_range(spawn_area.position.y, spawn_area.end.y)
		)
		if not _is_point_in_biome(candidate, biome):
			continue
		if not _is_valid_initial_grazer_position(candidate, used_positions, player_position):
			continue
		used_positions.append(candidate)
		var grazer := _spawn_grazer_at(candidate, _get_biome_id(biome))
		grazer.set("hunger", grazer_rng.randf_range(0.04, 0.22))
		grazer.set("energy", grazer_rng.randf_range(0.78, 1.0))
		grazer.set("decision_reason", "initial_map_distribution")
		return true
	return false


func _try_spawn_grazer_near_player(biome: Dictionary, player_position: Vector2, used_positions: Array[Vector2]) -> bool:
	var spawn_ring := _get_creature_horizon_spawn_ring()
	for _attempt in WORLD_CONFIG.RESOURCE_SPAWN_ATTEMPTS:
		var offset := Vector2.RIGHT.rotated(grazer_rng.randf_range(0.0, TAU)) * grazer_rng.randf_range(spawn_ring.x, spawn_ring.y)
		var candidate := player_position + offset
		if not _is_point_in_biome(candidate, biome):
			continue
		if not _is_valid_grazer_position(candidate, used_positions, player_position, spawn_ring.x):
			continue
		used_positions.append(candidate)
		_spawn_grazer_at(candidate, _get_biome_id(biome))
		return true
	return false


func _is_valid_creature_spawn_position(candidate: Vector2, used_positions: Array[Vector2], min_distance: float, player_position: Vector2, player_safe_distance: float) -> bool:
	if not WORLD_CONFIG.WORLD_RECT.has_point(candidate):
		return false
	if is_creature_spawn_blocked_by_water(candidate):
		return false
	if candidate.distance_to(player_position) < player_safe_distance:
		return false
	for used_position in used_positions:
		if candidate.distance_to(used_position) < min_distance:
			return false
	return true


func _get_existing_grazer_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for grazer in get_registered_creatures_by_type("grazer"):
		if is_instance_valid(grazer):
			positions.append(grazer.global_position)
	return positions


func _get_existing_varnak_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for varnak in get_registered_creatures_by_type("varnak"):
		if is_instance_valid(varnak):
			positions.append(varnak.global_position)
	return positions


func _get_visible_varnak_count(biome_id: String) -> int:
	var count := 0
	for varnak in get_registered_creatures_by_type("varnak"):
		if not is_instance_valid(varnak):
			continue
		if _get_biome_id_for_position(varnak.global_position) == biome_id:
			count += 1
	return count


func _is_valid_grazer_position(candidate: Vector2, used_positions: Array[Vector2], player_position: Vector2, player_safe_distance: float = GRAZER_PLAYER_SAFE_DISTANCE) -> bool:
	return _is_valid_creature_spawn_position(
		candidate,
		used_positions,
		GRAZER_MIN_DISTANCE,
		player_position,
		player_safe_distance
	)


func _get_creature_horizon_spawn_ring() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x < 320.0 or viewport_size.y < 180.0:
		viewport_size = Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
		)
	if viewport_size.x < 320.0 or viewport_size.y < 180.0:
		viewport_size = Vector2(1280.0, 720.0)
	var camera_zoom := Vector2.ONE
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera:
			camera_zoom = camera.zoom
	var minimum_distance := _calculate_creature_horizon_distance(viewport_size, camera_zoom)
	var ring_width := float(GAME_BALANCE.CREATURE_SPAWN["horizon_ring_width"])
	var min_ring := float(GAME_BALANCE.CREATURE_SPAWN.get("min_spawn_ring_distance", 360.0))
	var max_ring := float(GAME_BALANCE.CREATURE_SPAWN.get("max_spawn_ring_distance", 1200.0))
	minimum_distance = clampf(minimum_distance, min_ring, max_ring)
	return Vector2(minimum_distance, minimum_distance + ring_width)


func _calculate_creature_horizon_distance(viewport_size: Vector2, camera_zoom: Vector2) -> float:
	var safe_zoom := Vector2(maxf(absf(camera_zoom.x), 0.01), maxf(absf(camera_zoom.y), 0.01))
	var visible_world_size := Vector2(viewport_size.x / safe_zoom.x, viewport_size.y / safe_zoom.y)
	var visible_half_diagonal := visible_world_size.length() * 0.5
	var horizon_margin := float(GAME_BALANCE.CREATURE_SPAWN["horizon_margin"])
	var fallback_distance := float(GAME_BALANCE.CREATURE_SPAWN["horizon_fallback_distance"])
	return maxf(visible_half_diagonal + horizon_margin, fallback_distance)


func _is_valid_initial_grazer_position(candidate: Vector2, used_positions: Array[Vector2], player_position: Vector2) -> bool:
	if not _is_valid_creature_spawn_position(
		candidate,
		used_positions,
		GRAZER_MIN_DISTANCE,
		player_position,
		GRAZER_INITIAL_PLAYER_SAFE_DISTANCE
	):
		return false
	var world := _get_world_node()
	if world and world.has_method("is_creature_navigation_blocked") and world.is_creature_navigation_blocked(candidate) == true:
		return false
	return true


func _get_world_node() -> Node:
	var scene_tree := get_tree()
	if scene_tree == null or scene_tree.current_scene == null:
		return null
	return scene_tree.current_scene.get_node_or_null("World")


func _get_sibling_node(node_name: String) -> Node:
	var parent := get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null(node_name)


func _get_event_bus() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("EventBus")


func _get_game_session() -> Node:
	return get_node_or_null("/root/GameSession")


func _try_spawn_varnak_in_world(player_position: Vector2, used_positions: Array[Vector2]) -> bool:
	var spawn_ring := _get_creature_horizon_spawn_ring()
	for _attempt in WORLD_CONFIG.VARNAK_SPAWN_ATTEMPTS:
		var angle := varnak_rng.randf_range(0.0, TAU)
		var distance := varnak_rng.randf_range(spawn_ring.x, spawn_ring.y)
		var candidate := player_position + Vector2.RIGHT.rotated(angle) * distance
		if _get_biome_for_position(candidate).is_empty():
			continue
		if not _is_valid_varnak_spawn_position(candidate, player_position, used_positions, spawn_ring.x):
			continue
		if _is_position_inside_camera_view(candidate, float(GAME_BALANCE.VARNAK_SPAWN.get("avoid_camera_margin", 160.0))):
			continue
		used_positions.append(candidate)
		var varnak := _spawn_varnak_at(candidate)
		varnak.set("hunger", varnak_rng.randf_range(0.12, 0.42))
		varnak.set("energy", varnak_rng.randf_range(0.72, 0.96))
		varnak.set("decision_reason", "entered_visible_area")
		return true
	return _try_spawn_varnak_in_weighted_biome(player_position, used_positions, spawn_ring)


func _get_varnak_spawn_biomes() -> Array[Dictionary]:
	var spawn_biomes: Array[Dictionary] = []
	for biome_value in WORLD_CONFIG.get_biome_zones():
		var biome := Dictionary(biome_value)
		spawn_biomes.append(biome)
	return spawn_biomes


func _get_varnak_biome_spawn_weight(biome: Dictionary) -> float:
	var base_weight := float(GAME_BALANCE.VARNAK_SPAWN.get("default_biome_weight", 1.0))
	if biome.get("dangerous", false) == true:
		base_weight *= float(GAME_BALANCE.VARNAK_SPAWN.get("dangerous_biome_weight_multiplier", 3.0))
	var biome_id := _get_biome_id(biome)
	match biome_id:
		"redfang_wilds":
			base_weight *= 1.25
		"hearth_meadow":
			base_weight *= 0.75
		"westwood":
			base_weight *= 0.90
		"stoneback_ridge":
			base_weight *= 1.00
		"south_thicket":
			base_weight *= 1.10
	return maxf(base_weight, 0.0)


func _pick_varnak_spawn_biome() -> Dictionary:
	var biomes := _get_varnak_spawn_biomes()
	if biomes.is_empty():
		return {}
	var total_weight := 0.0
	for biome_value in biomes:
		total_weight += _get_varnak_biome_spawn_weight(Dictionary(biome_value))
	if total_weight <= 0.0:
		return Dictionary(biomes[varnak_rng.randi_range(0, biomes.size() - 1)])
	var roll := varnak_rng.randf() * total_weight
	var cumulative := 0.0
	for biome_value in biomes:
		var biome := Dictionary(biome_value)
		cumulative += _get_varnak_biome_spawn_weight(biome)
		if roll <= cumulative:
			return biome
	return Dictionary(biomes.back())


func _try_spawn_varnak_in_weighted_biome(player_position: Vector2, used_positions: Array[Vector2], spawn_ring: Vector2) -> bool:
	var attempt_multiplier := int(GAME_BALANCE.VARNAK_SPAWN.get("fallback_attempt_multiplier", 3))
	for _attempt in WORLD_CONFIG.VARNAK_SPAWN_ATTEMPTS * max(attempt_multiplier, 1):
		var biome := _pick_varnak_spawn_biome()
		if biome.is_empty():
			return false
		var bounds := _get_scaled_biome_bounds(biome)
		var candidate := Vector2(
			varnak_rng.randf_range(bounds.position.x, bounds.end.x),
			varnak_rng.randf_range(bounds.position.y, bounds.end.y)
		)
		if not _is_point_in_biome(candidate, biome):
			continue
		if not _is_valid_varnak_spawn_position(candidate, player_position, used_positions, maxf(spawn_ring.x, WORLD_CONFIG.VARNAK_PLAYER_SAFE_DISTANCE)):
			continue
		if _is_position_inside_camera_view(candidate, float(GAME_BALANCE.VARNAK_SPAWN.get("avoid_camera_margin", 160.0))):
			continue
		used_positions.append(candidate)
		var varnak := _spawn_varnak_at(candidate)
		varnak.set("hunger", varnak_rng.randf_range(0.12, 0.42))
		varnak.set("energy", varnak_rng.randf_range(0.72, 0.96))
		varnak.set("decision_reason", "weighted_biome_spawn")
		return true
	for biome_value in _get_varnak_spawn_biomes():
		var biome := Dictionary(biome_value)
		var fallback_position := _find_valid_creature_position_in_biome(
			biome,
			player_position,
			used_positions,
			VARNAK_MIN_DISTANCE,
			maxf(spawn_ring.x, WORLD_CONFIG.VARNAK_PLAYER_SAFE_DISTANCE),
			varnak_rng,
			WORLD_CONFIG.VARNAK_SPAWN_ATTEMPTS
		)
		if fallback_position == Vector2.INF:
			continue
		if _is_position_inside_camera_view(fallback_position, float(GAME_BALANCE.VARNAK_SPAWN.get("avoid_camera_margin", 160.0))):
			continue
		used_positions.append(fallback_position)
		var varnak := _spawn_varnak_at(fallback_position)
		varnak.set("hunger", varnak_rng.randf_range(0.12, 0.42))
		varnak.set("energy", varnak_rng.randf_range(0.72, 0.96))
		varnak.set("decision_reason", "fallback_land_biome_spawn")
		return true
	return false


func _spawn_grazer_at(pos: Vector2, biome_id: String) -> Node:
	var grazer := GRAZER_SCENE.instantiate()
	grazer.global_position = pos
	if grazer.has_method("setup"):
		grazer.setup(biome_id)
	add_child(grazer)
	register_creature_node(grazer, "grazer")
	return grazer


func _sync_visible_varnaks(force_spawn_check := false) -> void:
	if varnak_failed_spawn_retry_timer > 0.0 and not force_spawn_check and not integration_test_mode:
		varnak_spawn_sync_skipped_by_cooldown_count += 1
		return
	varnak_spawn_sync_attempt_count += 1
	var player_position := _get_player_position()
	var global_count := get_registered_creatures_by_type("varnak").size()
	var spawn_budget := _get_varnak_spawn_budget(global_count, _get_current_day())
	varnak_spawn_sync_last_requested = spawn_budget
	if spawn_budget <= 0:
		return
	if not force_spawn_check and varnak_rng.randf() > _get_varnak_spawn_chance(_get_current_day()):
		return
	var spawned := 0
	var used_positions := _get_existing_varnak_positions()
	for _i in spawn_budget:
		if _try_spawn_varnak_in_world(player_position, used_positions):
			spawned += 1
	if spawned > 0:
		var event_bus := _get_event_bus()
		if event_bus:
			event_bus.post_message("Varnak population increased by %d" % spawned)
	var failed_count: int = spawn_budget - spawned
	if failed_count <= 0:
		varnak_failed_spawn_retry_timer = 0.0
		varnak_failed_spawn_warning_printed = false
		varnak_spawn_sync_last_failed = 0
		varnak_spawn_sync_last_success = spawn_budget
		return
	varnak_failed_spawn_retry_timer = VARNAK_FAILED_SPAWN_RETRY_SECONDS
	varnak_spawn_sync_failed_count += 1
	varnak_spawn_sync_last_failed = failed_count
	varnak_spawn_sync_last_success = spawned
	if not varnak_failed_spawn_warning_printed:
		push_warning("Failed to spawn %d out of %d Varnaks. Retrying in %.1f seconds." % [
			failed_count,
			spawn_budget,
			VARNAK_FAILED_SPAWN_RETRY_SECONDS
		])
		varnak_failed_spawn_warning_printed = true


func respawn_missing_varnaks() -> void:
	_sync_visible_varnaks(true)


func respawn_varnaks() -> void:
	for varnak in get_registered_creatures_by_type("varnak"):
		if is_instance_valid(varnak):
			varnak.queue_free()
	await get_tree().process_frame
	_sync_visible_varnaks(true)
	var event_bus := _get_event_bus()
	if event_bus:
		event_bus.post_message("Varnaks respawned with current profile")


func debug_spawn_animal(aggressive: bool) -> void:
	var spawn_position := _get_debug_animal_spawn_position()
	var varnak := _spawn_varnak_at(spawn_position)
	if aggressive:
		varnak.apply_profile(_get_debug_aggressive_profile())
		var event_bus := _get_event_bus()
		if event_bus:
			event_bus.post_message("Debug spawned aggressive animal")
	else:
		varnak.apply_profile(_get_debug_neutral_profile())
		var event_bus := _get_event_bus()
		if event_bus:
			event_bus.post_message("Debug spawned neutral animal")


func debug_spawn_small_prey_near_player() -> void:
	var biome := _get_biome_for_position(_get_player_position())
	if biome.is_empty():
		return
	var biome_id := _get_biome_id(biome)
	var spawned := 0
	for i in DEBUG_SMALL_PREY_VISIBLE_COUNT:
		var spawn_position := _get_debug_creature_spawn_position(biome, DEBUG_SMALL_PREY_SPAWN_RADIUS, i, DEBUG_SMALL_PREY_VISIBLE_COUNT)
		_spawn_small_prey_at(spawn_position, biome_id)
		spawned += 1
	if spawned > 0:
		var event_bus := _get_event_bus()
		if event_bus:
			event_bus.post_message("Debug spawned %d SmallPrey" % spawned)


func debug_remove_small_prey_near_player() -> void:
	var removed := _debug_remove_nearest_creatures("small_prey", DEBUG_SMALL_PREY_VISIBLE_COUNT)
	if removed > 0:
		var event_bus := _get_event_bus()
		if event_bus:
			event_bus.post_message("Debug removed %d SmallPrey" % removed)


func debug_spawn_grazers_near_player() -> void:
	var biome := _get_biome_for_position(_get_player_position())
	if biome.is_empty():
		return
	var biome_id := _get_biome_id(biome)
	var spawned := 0
	for i in DEBUG_GRAZER_VISIBLE_COUNT:
		var spawn_position := _get_debug_creature_spawn_position(biome, DEBUG_GRAZER_SPAWN_RADIUS, i, DEBUG_GRAZER_VISIBLE_COUNT)
		_spawn_grazer_at(spawn_position, biome_id)
		spawned += 1
	if spawned > 0:
		var event_bus := _get_event_bus()
		if event_bus:
			event_bus.post_message("Debug spawned %d Grazers" % spawned)


func debug_remove_grazers_near_player() -> void:
	var removed := _debug_remove_nearest_creatures("grazer", DEBUG_GRAZER_VISIBLE_COUNT)
	if removed > 0:
		var event_bus := _get_event_bus()
		if event_bus:
			event_bus.post_message("Debug removed %d Grazers" % removed)


func _get_out_of_bounds_creatures() -> Array[Node2D]:
	var creatures: Array[Node2D] = []
	for group_name in CREATURE_BOUND_GROUPS:
		for node in get_registered_creatures_by_type(group_name):
			var creature := node as Node2D
			if not is_instance_valid(creature):
				continue
			if not WORLD_CONFIG.WORLD_RECT.has_point(creature.global_position):
				creatures.append(creature)
	return creatures


func _clamp_position_to_world(target_position: Vector2) -> Vector2:
	var rect := WORLD_CONFIG.WORLD_RECT.grow(-CREATURE_BOUND_TELEPORT_PADDING)
	return Vector2(
		clamp(target_position.x, rect.position.x, rect.end.x),
		clamp(target_position.y, rect.position.y, rect.end.y)
	)


func get_varnak_save_data() -> Array[Dictionary]:
	var varnaks: Array[Dictionary] = []
	for varnak in get_registered_creatures_by_type("varnak"):
		if not is_instance_valid(varnak):
			continue
		if varnak.has_method("get_save_data"):
			varnaks.append(varnak.get_save_data())
	return varnaks


func get_small_prey_save_data() -> Array[Dictionary]:
	return _get_creature_save_data("small_prey")


func get_small_prey_spawn_sync_debug() -> Dictionary:
	return {
		"retry_timer": small_prey_failed_spawn_retry_timer,
		"warning_printed": small_prey_failed_spawn_warning_printed,
		"attempt_count": small_prey_spawn_sync_attempt_count,
		"failed_count": small_prey_spawn_sync_failed_count,
		"skipped_by_cooldown_count": small_prey_spawn_sync_skipped_by_cooldown_count,
		"last_requested": small_prey_spawn_sync_last_requested,
		"last_failed": small_prey_spawn_sync_last_failed,
		"last_success": small_prey_spawn_sync_last_success
	}


func get_varnak_spawn_sync_debug() -> Dictionary:
	return {
		"retry_timer": varnak_failed_spawn_retry_timer,
		"warning_printed": varnak_failed_spawn_warning_printed,
		"attempt_count": varnak_spawn_sync_attempt_count,
		"failed_count": varnak_spawn_sync_failed_count,
		"skipped_by_cooldown_count": varnak_spawn_sync_skipped_by_cooldown_count,
		"last_requested": varnak_spawn_sync_last_requested,
		"last_failed": varnak_spawn_sync_last_failed,
		"last_success": varnak_spawn_sync_last_success
	}


func get_grazer_save_data() -> Array[Dictionary]:
	return _get_creature_save_data("grazer")


func _get_creature_save_data(group_name: String) -> Array[Dictionary]:
	var creatures: Array[Dictionary] = []
	for creature in get_registered_creatures_by_type(group_name):
		if not is_instance_valid(creature):
			continue
		if creature.has_method("get_save_data"):
			creatures.append(creature.get_save_data())
	return creatures


func restore_varnaks(varnaks: Array) -> void:
	for varnak in get_registered_creatures_by_type("varnak"):
		if is_instance_valid(varnak):
			varnak.queue_free()
	await get_tree().process_frame
	for varnak_data in varnaks:
		if typeof(varnak_data) != TYPE_DICTIONARY:
			continue
		_restore_varnak_from_data(Dictionary(varnak_data))


func restore_small_prey(small_prey_data: Array) -> void:
	await _restore_creature_group("small_prey", small_prey_data, SMALL_PREY_SCENE)


func restore_grazers(grazer_data: Array) -> void:
	await _restore_creature_group("grazer", grazer_data, GRAZER_SCENE)


func _restore_creature_group(group_name: String, creature_data: Array, scene: PackedScene) -> void:
	for creature in get_registered_creatures_by_type(group_name):
		if is_instance_valid(creature):
			creature.queue_free()
	await get_tree().process_frame
	for data_value in creature_data:
		if typeof(data_value) != TYPE_DICTIONARY:
			continue
		var creature := scene.instantiate()
		if creature.has_method("restore_from_data"):
			creature.restore_from_data(Dictionary(data_value))
		add_child(creature)
		register_creature_node(creature, group_name)


func _spawn_varnak_at(pos: Vector2) -> Node:
	var varnak := VARNAK_SCENE.instantiate()
	varnak.global_position = pos
	varnak.apply_profile(evolution_director.get_profile())
	varnak.day_night_system = day_night_system
	add_child(varnak)
	register_creature_node(varnak, "varnak")
	return varnak


func _restore_varnak_from_data(data: Dictionary) -> void:
	var varnak := VARNAK_SCENE.instantiate()
	varnak.apply_profile(evolution_director.get_profile())
	varnak.day_night_system = day_night_system
	if varnak.has_method("restore_from_data"):
		varnak.restore_from_data(data)
	add_child(varnak)
	register_creature_node(varnak, "varnak")


func _get_debug_animal_spawn_position() -> Vector2:
	var player_position := _get_player_position()
	var player_limits := WORLD_CONFIG.get_player_limits()
	for attempt in 24:
		var angle := float(attempt) * TAU / 24.0
		var distance: float = 180.0 + floor(float(attempt) / 8.0) * 48.0
		var candidate := player_position + Vector2.RIGHT.rotated(angle) * distance
		candidate.x = clamp(candidate.x, -player_limits.x, player_limits.x)
		candidate.y = clamp(candidate.y, -player_limits.y, player_limits.y)
		if WORLD_CONFIG.WORLD_RECT.has_point(candidate) and not is_creature_spawn_blocked_by_water(candidate):
			return candidate
	return _get_fallback_dry_creature_spawn_position(player_position)


func _get_debug_creature_spawn_position(biome: Dictionary, radius: float, index: int, total: int) -> Vector2:
	var player_position := _get_player_position()
	var player_limits := WORLD_CONFIG.get_player_limits()
	for attempt in 24:
		var angle := TAU * float(index + attempt) / float(max(total, 1)) + float(attempt) * 0.35
		var candidate := player_position + Vector2.RIGHT.rotated(angle) * (radius + float(attempt) * 18.0)
		candidate.x = clamp(candidate.x, -player_limits.x, player_limits.x)
		candidate.y = clamp(candidate.y, -player_limits.y, player_limits.y)
		if _is_point_in_biome(candidate, biome) and WORLD_CONFIG.WORLD_RECT.has_point(candidate) and not is_creature_spawn_blocked_by_water(candidate):
			return candidate
	return _get_fallback_dry_creature_spawn_position(player_position)


func _get_fallback_dry_creature_spawn_position(origin: Vector2) -> Vector2:
	var player_limits := WORLD_CONFIG.get_player_limits()
	for attempt in 48:
		var angle := float(attempt) * TAU / 48.0
		var distance: float = 160.0 + floor(float(attempt) / 12.0) * 60.0
		var candidate := origin + Vector2.RIGHT.rotated(angle) * distance
		candidate.x = clamp(candidate.x, -player_limits.x, player_limits.x)
		candidate.y = clamp(candidate.y, -player_limits.y, player_limits.y)
		if WORLD_CONFIG.WORLD_RECT.has_point(candidate) and not is_creature_spawn_blocked_by_water(candidate):
			return candidate
	return _clamp_position_to_world(origin)


func _debug_remove_nearest_creatures(group_name: String, count: int) -> int:
	var player_position := _get_player_position()
	var nodes := get_registered_creatures_by_type(group_name)
	nodes.sort_custom(func(a: Node, b: Node) -> bool:
		if not is_instance_valid(a):
			return false
		if not is_instance_valid(b):
			return true
		return a.global_position.distance_squared_to(player_position) < b.global_position.distance_squared_to(player_position)
	)
	var removed := 0
	for creature in nodes:
		if removed >= count:
			break
		if not is_instance_valid(creature):
			continue
		creature.queue_free()
		removed += 1
	return removed


func _get_debug_aggressive_profile() -> Dictionary:
	var profile: Dictionary = evolution_director.get_profile()
	profile["aggression"] = 1.0
	profile["base_curiosity"] = 0.8
	profile["night_activity"] = 0.8
	return profile


func _get_debug_neutral_profile() -> Dictionary:
	var profile: Dictionary = evolution_director.get_profile()
	profile["aggression"] = 0.0
	profile["base_curiosity"] = 0.0
	profile["night_activity"] = 0.0
	profile["pack_coordination"] = 0.0
	profile["stalk_tendency"] = 0.0
	return profile


func _scale_world_point(point: Vector2) -> Vector2:
	return WORLD_CONFIG.scale_world_point(point)


func _get_varnak_spawn_weight(point: Vector2) -> float:
	return 4.0 if _is_point_in_dangerous_biome(point) else 1.0


func _is_point_in_dangerous_biome(point: Vector2) -> bool:
	for biome_value in WORLD_CONFIG.BIOME_ZONES:
		var biome := Dictionary(biome_value)
		if biome.get("dangerous", false) == true and _is_point_in_biome(point, biome):
			return true
	return false


func _is_valid_varnak_spawn_position(point: Vector2, player_position: Vector2, used_positions: Array[Vector2] = [], player_safe_distance: float = WORLD_CONFIG.VARNAK_PLAYER_SAFE_DISTANCE) -> bool:
	if not WORLD_CONFIG.WORLD_RECT.has_point(point):
		return false
	if is_creature_spawn_blocked_by_water(point):
		return false
	if point.distance_to(player_position) < player_safe_distance:
		return false
	for used_position in used_positions:
		if point.distance_to(used_position) < VARNAK_MIN_DISTANCE:
			return false
	for varnak in get_registered_creatures_by_type("varnak"):
		if is_instance_valid(varnak) and varnak.global_position.distance_to(point) < VARNAK_MIN_DISTANCE:
			return false
	var other_creature_min_distance := float(GAME_BALANCE.VARNAK_DAY_SCALING["other_creature_min_distance"])
	for creature_type in ["small_prey", "grazer"]:
		for creature_value in get_registered_creatures_by_type(creature_type):
			var creature := creature_value as Node2D
			if creature and is_instance_valid(creature) and creature.global_position.distance_to(point) < other_creature_min_distance:
				return false
	return true


func _is_position_inside_camera_view(target_position: Vector2, margin: float = 0.0) -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return false
	var viewport_size := get_viewport_rect().size
	var zoom := camera.zoom
	var safe_zoom := Vector2(maxf(absf(zoom.x), 0.01), maxf(absf(zoom.y), 0.01))
	var visible_world_size := Vector2(viewport_size.x / safe_zoom.x, viewport_size.y / safe_zoom.y)
	var rect := Rect2(camera.global_position - visible_world_size * 0.5, visible_world_size).grow(margin)
	return rect.has_point(target_position)


func _get_current_day() -> int:
	if day_night_system and day_night_system.has_method("get_day"):
		return maxi(int(day_night_system.get_day()), 1)
	return 1


func _get_varnak_target_count(day: int) -> int:
	if day <= 7:
		var difficulty := GameBalance.get_first_week_difficulty(day)
		var difficulty_max := int(difficulty.get("varnak_max_population", -1))
		if difficulty_max > 0:
			return difficulty_max
	var scaling := GameBalance.VARNAK_DAY_SCALING
	var normalized_day := maxi(day, 1)
	if normalized_day <= 1:
		return clampi(int(scaling.get("day_1_min", 0)), 0, int(scaling.get("day_1_max", 0)))
	if normalized_day == 2:
		return clampi(int(scaling.get("day_2_min", 1)), int(scaling.get("day_2_min", 1)), int(scaling.get("day_2_max", 2)))
	if normalized_day == 3:
		return clampi(int(scaling.get("day_3_min", 2)), int(scaling.get("day_3_min", 2)), int(scaling.get("day_3_max", 4)))
	var daily_growth := int(scaling.get("daily_growth", 1))
	var max_varnaks := int(scaling.get("max_varnaks", 12))
	var day_three_cap := int(scaling.get("day_3_max", 4))
	return clampi(day_three_cap + ((normalized_day - 3) * daily_growth), day_three_cap, max_varnaks)


func _get_varnak_spawn_chance(day: int) -> float:
	if day <= 7:
		var difficulty := GameBalance.get_first_week_difficulty(day)
		if difficulty.has("varnak_spawn_chance"):
			return clampf(float(difficulty.get("varnak_spawn_chance", 0.0)), 0.0, 1.0)
	if day < 2:
		return 0.0
		
	var scaling := GAME_BALANCE.VARNAK_DAY_SCALING
	var daily_growth_steps := maxi(day - 1, 0)
	return minf(
		float(scaling["day_1_spawn_chance"]) + float(daily_growth_steps) * float(scaling["spawn_chance_daily_growth"]),
		float(scaling["max_spawn_chance"])
	)


func _get_varnak_spawn_budget(global_count: int, day: int) -> int:
	var missing_count := _get_varnak_target_count(day) - maxi(global_count, 0)
	return maxi(mini(missing_count, int(GAME_BALANCE.VARNAK_DAY_SCALING["spawn_batch_limit"])), 0)


func _get_varnak_spawn_check_interval() -> float:
	return maxf(float(GAME_BALANCE.VARNAK_DAY_SCALING["spawn_check_interval_seconds"]), 0.1)


func _on_day_changed(_day: int) -> void:
	if is_restoring_save:
		return
	varnak_spawn_timer = 0.0
	call_deferred("_sync_visible_varnaks", true)
	call_deferred("_sync_visible_small_prey")
	call_deferred("_sync_visible_grazers")


func _on_profile_changed(profile: Dictionary) -> void:
	for varnak in get_registered_creatures_by_type("varnak"):
		varnak.apply_profile(profile)


func _on_game_event(event_name: String, _payload: Dictionary) -> void:
	if event_name == "generation_changed":
		call_deferred("respawn_varnaks")
	elif event_name == "day_ended":
		call_deferred("advance_resource_growth_days", 1.0)
	elif event_name == "ecosystem_vegetation_changed":
		var biome_id := str(_payload.get("biome_id", ""))
		_queue_biome_vegetation_sync(biome_id)


func _queue_biome_vegetation_sync(biome_id: String) -> void:
	if biome_id.is_empty():
		return
	pending_biome_vegetation_syncs[biome_id] = true
	if biome_vegetation_sync_scheduled:
		return
	biome_vegetation_sync_scheduled = true
	call_deferred("_flush_pending_biome_vegetation_syncs")


func _flush_pending_biome_vegetation_syncs() -> void:
	biome_vegetation_sync_scheduled = false
	if pending_biome_vegetation_syncs.is_empty():
		return
	var changed := false
	var biome_ids := pending_biome_vegetation_syncs.keys()
	pending_biome_vegetation_syncs.clear()
	for biome_id_value in biome_ids:
		changed = _sync_biome_vegetation(str(biome_id_value)) or changed
	if changed:
		queue_redraw()


func _vector_to_data(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


func _data_to_vector(data: Variant) -> Vector2:
	if typeof(data) != TYPE_DICTIONARY:
		return Vector2.ZERO
	return Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))


func _draw() -> void:
	var has_biome_blend_background := (
		biome_textures_enabled
		and is_instance_valid(biome_blend_background)
		and biome_blend_background.visible
		and biome_blend_background.texture != null
	)
	if not has_biome_blend_background:
		draw_rect(WORLD_CONFIG.WORLD_RECT, WORLD_CONFIG.OCEAN_COLOR, true)
	_draw_biomes()
	_draw_biome_detail_overlay()
	_draw_landmarks()
	if debug_landmark_overlay_enabled:
		_draw_landmark_debug_overlay()
		_draw_world_boundary()


func _get_night_amount() -> float:
	if not day_night_system:
		return 0.0
	return clamp(float(day_night_system.night_amount), 0.0, 1.0)


func _draw_biomes() -> void:
	if biome_textures_enabled:
		if is_instance_valid(biome_blend_background) and biome_blend_background.visible and biome_blend_background.texture != null:
			return
	elif is_instance_valid(biome_blend_background):
		biome_blend_background.visible = false
		biome_blend_background.texture = null
	for biome_value in WORLD_CONFIG.get_biome_zones():
		var biome := Dictionary(biome_value)
		var points := PackedVector2Array(biome["points"])
		var base_color := _get_biome_visual_color(biome)
		draw_colored_polygon(points, base_color)
		if biome_terrain_accents_enabled:
			_draw_biome_terrain_accents(biome, base_color)


func _update_biome_detail_overlay(force_redraw: bool = false) -> void:
	if not biome_textures_enabled:
		biome_detail_overlay_pending_keys.clear()
		if not biome_detail_overlay_visible_keys.is_empty():
			biome_detail_overlay_visible_keys.clear()
		biome_detail_overlay_last_signature = ""
		return
	if not bool(GAME_BALANCE.BIOME_TEXTURES.get("detail_overlay_enabled", true)):
		biome_detail_overlay_pending_keys.clear()
		biome_detail_overlay_visible_keys.clear()
		biome_detail_overlay_last_signature = ""
		return
	var visible_keys := _get_visible_biome_detail_overlay_keys()
	var signature := "|".join(visible_keys)
	biome_detail_overlay_visible_keys = visible_keys
	if force_redraw or signature != biome_detail_overlay_last_signature:
		biome_detail_overlay_last_signature = signature
		_queue_missing_biome_detail_overlay_chunks(visible_keys)
		queue_redraw()


func _get_visible_biome_detail_overlay_keys() -> Array[String]:
	var chunk_world_size: float = maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("detail_chunk_world_size", BIOME_DETAIL_CHUNK_WORLD_SIZE)), 1.0)
	var visible_rect := get_camera_visible_world_rect(chunk_world_size)
	var chunk_radius := int(GAME_BALANCE.BIOME_TEXTURES.get("detail_visible_chunk_radius", BIOME_DETAIL_VISIBLE_CHUNK_RADIUS))
	var chunk_min_x := int(floor(visible_rect.position.x / chunk_world_size)) - chunk_radius
	var chunk_min_y := int(floor(visible_rect.position.y / chunk_world_size)) - chunk_radius
	var chunk_max_x := int(floor(visible_rect.end.x / chunk_world_size)) + chunk_radius
	var chunk_max_y := int(floor(visible_rect.end.y / chunk_world_size)) + chunk_radius
	var visible_keys: Array[String] = []
	for chunk_y in range(chunk_min_y, chunk_max_y + 1):
		for chunk_x in range(chunk_min_x, chunk_max_x + 1):
			visible_keys.append("%d:%d" % [chunk_x, chunk_y])
	return visible_keys


func _draw_biome_detail_overlay() -> void:
	if not biome_textures_enabled:
		return
	if not bool(GAME_BALANCE.BIOME_TEXTURES.get("detail_overlay_enabled", true)):
		return
	if not is_instance_valid(biome_blend_background) or not biome_blend_background.visible:
		return
	var chunk_world_size: float = maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("detail_chunk_world_size", BIOME_DETAIL_CHUNK_WORLD_SIZE)), 1.0)
	for chunk_key in biome_detail_overlay_visible_keys:
		var chunk_texture: ImageTexture = _get_biome_detail_overlay_texture(chunk_key)
		if chunk_texture == null:
			continue
		var key_parts := chunk_key.split(":")
		if key_parts.size() != 2:
			continue
		var chunk_x := int(key_parts[0])
		var chunk_y := int(key_parts[1])
		var chunk_position := Vector2(
			float(chunk_x) * chunk_world_size,
			float(chunk_y) * chunk_world_size
		)
		draw_texture_rect(
			chunk_texture,
			Rect2(chunk_position, Vector2(chunk_world_size, chunk_world_size)),
			false,
			Color(1.0, 1.0, 1.0, clampf(float(GAME_BALANCE.BIOME_TEXTURES.get("detail_overlay_alpha", BIOME_DETAIL_ALPHA)), 0.0, 1.0))
		)


func _queue_missing_biome_detail_overlay_chunks(visible_keys: Array[String]) -> void:
	var queued: Dictionary = {}
	for key in biome_detail_overlay_pending_keys:
		queued[key] = true
	for key in visible_keys:
		if biome_detail_overlay_cache.has(key) or queued.has(key):
			continue
		biome_detail_overlay_pending_keys.append(key)
		queued[key] = true


func _build_pending_biome_detail_overlay_chunks() -> void:
	if not biome_textures_enabled:
		return
	if not bool(GAME_BALANCE.BIOME_TEXTURES.get("detail_overlay_enabled", true)):
		return
	var budget := maxi(int(GAME_BALANCE.BIOME_TEXTURES.get("detail_chunk_build_budget_per_frame", biome_detail_overlay_build_budget_per_frame)), 0)
	var built_any := false
	for _i in range(budget):
		if biome_detail_overlay_pending_keys.is_empty():
			break
		var chunk_key := str(biome_detail_overlay_pending_keys.pop_front())
		if biome_detail_overlay_cache.has(chunk_key):
			continue
		var key_parts := chunk_key.split(":")
		if key_parts.size() != 2:
			continue
		var chunk_x := int(key_parts[0])
		var chunk_y := int(key_parts[1])
		biome_detail_overlay_cache[chunk_key] = _build_biome_detail_overlay_chunk_texture(chunk_x, chunk_y)
		built_any = true
	if built_any:
		queue_redraw()


func _get_biome_detail_overlay_texture(chunk_key: String) -> ImageTexture:
	if biome_detail_overlay_cache.has(chunk_key):
		return biome_detail_overlay_cache[chunk_key]
	return null


func _build_biome_detail_overlay_chunk_texture(chunk_x: int, chunk_y: int) -> ImageTexture:
	var chunk_texture_size: int = max(int(GAME_BALANCE.BIOME_TEXTURES.get("detail_chunk_texture_size", BIOME_DETAIL_CHUNK_TEXTURE_SIZE.x)), 1)
	var chunk_world_size: float = maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("detail_chunk_world_size", BIOME_DETAIL_CHUNK_WORLD_SIZE)), 1.0)
	var image := Image.create(chunk_texture_size, chunk_texture_size, false, Image.FORMAT_RGBA8)
	var chunk_origin := Vector2(
		float(chunk_x) * chunk_world_size,
		float(chunk_y) * chunk_world_size
	)
	for y in range(chunk_texture_size):
		for x in range(chunk_texture_size):
			var world_position := chunk_origin + Vector2(
				(float(x) + 0.5) / float(chunk_texture_size) * chunk_world_size,
				(float(y) + 0.5) / float(chunk_texture_size) * chunk_world_size
			)
			var terrain_zone := WORLD_CONFIG.get_terrain_zone(world_position)
			if terrain_zone == "deep_ocean" or terrain_zone == "shallow_water" or terrain_zone == "shore":
				continue
			var biome := _get_biome_for_position(world_position)
			if biome.is_empty():
				continue
			var terrain_pattern := _get_biome_terrain_pattern(biome)
			if terrain_pattern.is_empty():
				continue
			var texture_color: Color = _sample_biome_detail_texture_color(terrain_pattern, world_position)
			if texture_color == Color.BLACK:
				continue
			var luminance: float = clampf(texture_color.get_luminance(), 0.0, 1.0)
			var base_color := _get_biome_visual_color(biome)
			var overlay_color := base_color.darkened(0.10).lerp(base_color.lightened(0.12), luminance)
			var alpha := clampf(float(GAME_BALANCE.BIOME_TEXTURES.get("detail_overlay_alpha", BIOME_DETAIL_ALPHA)), 0.0, 1.0)
			image.set_pixel(x, y, Color(overlay_color.r, overlay_color.g, overlay_color.b, alpha))
	var texture := ImageTexture.create_from_image(image)
	return texture


func _sample_biome_detail_texture_color(terrain_pattern: Dictionary, world_position: Vector2) -> Color:
	var texture_image := _get_biome_texture_image(terrain_pattern)
	if texture_image.is_empty():
		return Color.BLACK
	var pattern_seed: float = float(terrain_pattern.get("seed", 0.0))
	var density_multiplier := maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("detail_density_multiplier", 1.0)), 0.1)
	density_multiplier *= maxf(float(terrain_pattern.get("density_scale", 1.0)), 0.1)
	var tile_world_size := maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("detail_tile_world_size", BIOME_DETAIL_WORLD_TILE_SIZE)), 1.0)
	var world_uv := Vector2(
		world_position.x / tile_world_size,
		world_position.y / tile_world_size
	)
	var tiled_uv := Vector2(
		fposmod(world_uv.x * density_multiplier + pattern_seed * 0.013, 1.0),
		fposmod(world_uv.y * density_multiplier + pattern_seed * 0.007, 1.0)
	)
	var sample_position := Vector2(
		tiled_uv.x * float(texture_image.get_width() - 1),
		tiled_uv.y * float(texture_image.get_height() - 1)
	)
	return texture_image.get_pixel(
		clampi(int(round(sample_position.x)), 0, texture_image.get_width() - 1),
		clampi(int(round(sample_position.y)), 0, texture_image.get_height() - 1)
	)


func _draw_biome_terrain_accents(biome: Dictionary, base_color: Color) -> void:
	var accents: Array = _get_biome_terrain_accent_layout(biome)
	var biome_id := _get_biome_id(biome)
	for accent_value in accents:
		var accent := Dictionary(accent_value)
		var accent_position := Vector2(accent.get("position", Vector2.ZERO))
		var accent_rotation := float(accent.get("rotation", 0.0))
		var accent_scale := float(accent.get("scale", 1.0))
		var tint := float(accent.get("tint", 0.0))
		var is_secondary: bool = accent.get("secondary", false) == true
		var detail_alpha: float = float(GAME_BALANCE.BIOME_TEXTURES.get(
			"secondary_detail_alpha" if is_secondary else "detail_alpha",
			0.18 if is_secondary else 0.30
		))
		var colors := _get_biome_accent_colors(str(accent.get("kind", "")), base_color, tint, detail_alpha)
		var light_color := Color(colors.get("light", base_color))
		var dark_color := Color(colors.get("dark", base_color.darkened(0.18)))
		match str(accent.get("kind", "")):
			"grass":
				_draw_biome_grass_accent(accent_position, accent_rotation, accent_scale, light_color, dark_color)
			"leaf":
				_draw_biome_leaf_accent(accent_position, accent_rotation, accent_scale, light_color, dark_color)
			"plate":
				_draw_biome_plate_accent(accent_position, accent_rotation, accent_scale, light_color, dark_color)
			"thicket":
				_draw_biome_thicket_accent(accent_position, accent_rotation, accent_scale, light_color, dark_color)
			"crack":
				_draw_biome_crack_accent(accent_position, accent_rotation, accent_scale, light_color, dark_color)
			_:
				if biome_id == "hearth_meadow":
					_draw_biome_grass_accent(accent_position, accent_rotation, accent_scale, light_color, dark_color)


func _draw_world_boundary() -> void:
	var points := WORLD_CONFIG.get_world_boundary_points()
	if points.size() < 3:
		draw_rect(WORLD_CONFIG.WORLD_RECT, Color(0.07, 0.09, 0.07), false, 5.0)
		return
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, Color(0.07, 0.09, 0.07), 5.0, true)


func _get_biome_accent_colors(kind: String, base_color: Color, tint: float, alpha: float) -> Dictionary:
	var light := base_color.lightened(0.08)
	var dark := base_color.darkened(0.18)
	match kind:
		"grass":
			light = base_color.lerp(Color(0.28, 0.70, 0.22), 0.78).lightened(tint * 0.08)
			dark = base_color.lerp(Color(0.12, 0.30, 0.09), 0.82)
		"leaf":
			light = base_color.lerp(Color(0.36, 0.76, 0.20), 0.70).lightened(tint * 0.06)
			dark = base_color.lerp(Color(0.11, 0.24, 0.09), 0.80)
		"plate":
			light = base_color.lerp(Color(0.55, 0.56, 0.60), 0.72).lightened(tint * 0.05)
			dark = base_color.lerp(Color(0.22, 0.23, 0.25), 0.82)
		"thicket":
			light = base_color.lerp(Color(0.43, 0.86, 0.25), 0.68).lightened(tint * 0.06)
			dark = base_color.lerp(Color(0.12, 0.26, 0.10), 0.82)
		"crack":
			light = base_color.lerp(Color(0.66, 0.49, 0.22), 0.76).lightened(tint * 0.05)
			dark = base_color.lerp(Color(0.38, 0.27, 0.12), 0.84)
	return {
		"light": _color_with_alpha(light, alpha),
		"dark": _color_with_alpha(dark, minf(alpha * 1.20, 0.42))
	}


func _color_with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))


func _rebuild_biome_terrain_accent_cache() -> void:
	biome_terrain_accent_cache.clear()
	for biome_value in WORLD_CONFIG.get_biome_zones():
		_get_biome_terrain_accent_layout(Dictionary(biome_value))


func _queue_biome_terrain_accent_cache_rebuild() -> void:
	biome_terrain_accent_cache.clear()
	pending_biome_terrain_accent_biomes.clear()
	if not biome_terrain_accents_enabled:
		biome_terrain_accent_cache_build_running = false
		return
	for biome_value in WORLD_CONFIG.get_biome_zones():
		pending_biome_terrain_accent_biomes.append(Dictionary(biome_value))
	if biome_terrain_accent_cache_build_running:
		return
	biome_terrain_accent_cache_build_running = true
	call_deferred("_build_pending_biome_terrain_accent_cache")


func _build_pending_biome_terrain_accent_cache() -> void:
	if not biome_terrain_accents_enabled:
		pending_biome_terrain_accent_biomes.clear()
		biome_terrain_accent_cache_build_running = false
		return
	var built_since_yield := 0
	while not pending_biome_terrain_accent_biomes.is_empty():
		var biome := Dictionary(pending_biome_terrain_accent_biomes.pop_front())
		var biome_id := _get_biome_id(biome)
		biome_terrain_accent_cache[biome_id] = _build_biome_terrain_accent_layout(biome)
		built_since_yield += 1
		queue_redraw()
		if built_since_yield >= BIOME_TERRAIN_ACCENT_BUILD_BATCH_SIZE and not pending_biome_terrain_accent_biomes.is_empty():
			built_since_yield = 0
			await get_tree().process_frame
	biome_terrain_accent_cache_build_running = false


func _get_biome_terrain_accent_layout(biome: Dictionary) -> Array:
	var biome_id := _get_biome_id(biome)
	if biome_terrain_accent_cache.has(biome_id):
		return biome_terrain_accent_cache[biome_id]
	if _is_biome_terrain_accent_pending(biome_id):
		return []
	var accents := _build_biome_terrain_accent_layout(biome)
	biome_terrain_accent_cache[biome_id] = accents
	return accents


func _is_biome_terrain_accent_pending(biome_id: String) -> bool:
	for pending_biome in pending_biome_terrain_accent_biomes:
		if _get_biome_id(pending_biome) == biome_id:
			return true
	return false


func _build_biome_terrain_accent_layout(biome: Dictionary) -> Array:
	var biome_id := _get_biome_id(biome)
	var points := PackedVector2Array(biome["points"])
	var bounds := _get_polygon_bounds(points)
	var target_count := _get_biome_terrain_accent_target_count(biome)
	var accents: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = _get_string_seed(biome_id)
	var attempts := 0
	while accents.size() < target_count and attempts < target_count * 22:
		attempts += 1
		var candidate := Vector2(
			rng.randf_range(bounds.position.x, bounds.end.x),
			rng.randf_range(bounds.position.y, bounds.end.y)
		)
		if not Geometry2D.is_point_in_polygon(candidate, points):
			continue
		accents.append({
			"kind": _pick_biome_accent_kind(biome_id, rng.randf()),
			"position": candidate,
			"rotation": rng.randf_range(-0.55, 0.55),
			"scale": rng.randf_range(0.62, 1.42),
			"tint": rng.randf_range(-0.10, 0.22),
			"secondary": rng.randf() < 0.42
		})
	return accents


func _get_biome_terrain_accent_target_count(biome: Dictionary) -> int:
	var biome_id := _get_biome_id(biome)
	var points := PackedVector2Array(biome["points"])
	var area := _get_polygon_area(points)
	var area_scale := clampf(area / 900000.0, 0.85, 1.45)
	var density_multiplier := maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("detail_density_multiplier", 1.0)), 0.1)
	var max_details := maxi(int(GAME_BALANCE.BIOME_TEXTURES.get("max_detail_per_chunk", 120)), 1)
	var target := int(round(float(BIOME_TERRAIN_ACCENT_COUNTS.get(biome_id, 20)) * area_scale * density_multiplier))
	return clampi(target, mini(int(round(14.0 * density_multiplier)), max_details), max_details)


func _pick_biome_accent_kind(biome_id: String, roll: float) -> String:
	match biome_id:
		"westwood":
			return "leaf" if roll < 0.72 else "crack"
		"stoneback_ridge":
			return "plate" if roll < 0.78 else "crack"
		"hearth_meadow":
			return "grass" if roll < 0.84 else "leaf"
		"south_thicket":
			return "thicket" if roll < 0.78 else "leaf"
		"redfang_wilds":
			return "plate" if roll < 0.58 else "crack"
	return "leaf"


func _draw_biome_grass_accent(accent_position: Vector2, accent_rotation: float, accent_scale: float, light_color: Color, dark_color: Color) -> void:
	for i in 6:
		var offset := -6.0 + float(i) * 2.4
		var height := 8.0 + float(i % 3) * 2.0
		var start := _transform_biome_accent_point(Vector2(offset, 7.0), accent_position, accent_rotation, accent_scale)
		var end := _transform_biome_accent_point(Vector2(offset + sin(float(i)) * 3.0, 7.0 - height), accent_position, accent_rotation, accent_scale)
		draw_line(start, end, light_color, max(1.0, 1.6 * accent_scale))
	draw_circle(accent_position, 8.0 * accent_scale, _color_with_alpha(dark_color, dark_color.a * 0.38))


func _draw_biome_leaf_accent(accent_position: Vector2, accent_rotation: float, accent_scale: float, fill_color: Color, outline_color: Color) -> void:
	draw_circle(_transform_biome_accent_point(Vector2(-6.0, 3.0), accent_position, accent_rotation, accent_scale), 8.0 * accent_scale, fill_color.darkened(0.08))
	draw_circle(_transform_biome_accent_point(Vector2(3.0, -3.0), accent_position, accent_rotation, accent_scale), 9.0 * accent_scale, fill_color)
	draw_circle(_transform_biome_accent_point(Vector2(8.0, 5.0), accent_position, accent_rotation, accent_scale), 7.0 * accent_scale, fill_color.darkened(0.14))
	var stem_start := _transform_biome_accent_point(Vector2(-10.0, 7.0), accent_position, accent_rotation, accent_scale)
	var stem_end := _transform_biome_accent_point(Vector2(10.0, 7.0), accent_position, accent_rotation, accent_scale)
	draw_line(stem_start, stem_end, outline_color, max(1.0, 1.5 * accent_scale))


func _draw_biome_plate_accent(accent_position: Vector2, accent_rotation: float, accent_scale: float, fill_color: Color, outline_color: Color) -> void:
	var plate := PackedVector2Array([
		Vector2(-17.0, 8.0),
		Vector2(-9.0, -13.0),
		Vector2(10.0, -12.0),
		Vector2(18.0, 5.0),
		Vector2(3.0, 16.0)
	])
	var transformed := _transform_biome_accent_points(plate, accent_position, accent_rotation, accent_scale)
	draw_colored_polygon(transformed, fill_color.darkened(0.12))
	var highlight := PackedVector2Array([
		Vector2(-9.0, -13.0),
		Vector2(10.0, -12.0),
		Vector2(3.0, 1.0),
		Vector2(-14.0, 4.0)
	])
	draw_colored_polygon(_transform_biome_accent_points(highlight, accent_position, accent_rotation, accent_scale), fill_color)
	var crack_start := _transform_biome_accent_point(Vector2(-5.0, -8.0), accent_position, accent_rotation, accent_scale)
	var crack_end := _transform_biome_accent_point(Vector2(4.0, 10.0), accent_position, accent_rotation, accent_scale)
	draw_line(crack_start, crack_end, outline_color, max(1.0, 2.0 * accent_scale))


func _draw_biome_thicket_accent(accent_position: Vector2, accent_rotation: float, accent_scale: float, fill_color: Color, outline_color: Color) -> void:
	draw_circle(_transform_biome_accent_point(Vector2(-10.0, 4.0), accent_position, accent_rotation, accent_scale), 12.0 * accent_scale, fill_color.darkened(0.10))
	draw_circle(_transform_biome_accent_point(Vector2(2.0, -4.0), accent_position, accent_rotation, accent_scale), 14.0 * accent_scale, fill_color)
	draw_circle(_transform_biome_accent_point(Vector2(13.0, 5.0), accent_position, accent_rotation, accent_scale), 11.0 * accent_scale, fill_color.darkened(0.16))
	draw_circle(_transform_biome_accent_point(Vector2(2.0, 9.0), accent_position, accent_rotation, accent_scale), 11.0 * accent_scale, fill_color.darkened(0.06))
	var base_start := _transform_biome_accent_point(Vector2(-16.0, 8.0), accent_position, accent_rotation, accent_scale)
	var base_end := _transform_biome_accent_point(Vector2(16.0, 8.0), accent_position, accent_rotation, accent_scale)
	draw_line(base_start, base_end, outline_color, max(1.0, 2.0 * accent_scale))


func _draw_biome_crack_accent(accent_position: Vector2, accent_rotation: float, accent_scale: float, fill_color: Color, outline_color: Color) -> void:
	var branches := [
		[Vector2(0.0, 12.0), Vector2(-18.0, -8.0)],
		[Vector2(0.0, 12.0), Vector2(18.0, -9.0)],
		[Vector2(0.0, 12.0), Vector2(0.0, -16.0)],
		[Vector2(-8.0, 1.0), Vector2(-19.0, 3.0)],
		[Vector2(7.0, 1.0), Vector2(19.0, 5.0)]
	]
	for branch in branches:
		var start := _transform_biome_accent_point(branch[0], accent_position, accent_rotation, accent_scale)
		var end := _transform_biome_accent_point(branch[1], accent_position, accent_rotation, accent_scale)
		draw_line(start, end, fill_color, max(1.0, 2.0 * accent_scale))
	draw_circle(accent_position, 15.0 * accent_scale, _color_with_alpha(outline_color, outline_color.a * 0.24))


func _transform_biome_accent_point(point: Vector2, accent_position: Vector2, accent_rotation: float, accent_scale: float) -> Vector2:
	return accent_position + point.rotated(accent_rotation) * accent_scale


func _transform_biome_accent_points(points: PackedVector2Array, accent_position: Vector2, accent_rotation: float, accent_scale: float) -> PackedVector2Array:
	var transformed := PackedVector2Array()
	for point in points:
		transformed.append(_transform_biome_accent_point(point, accent_position, accent_rotation, accent_scale))
	return transformed


func _close_polyline(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(points)
	if not closed.is_empty():
		closed.append(closed[0])
	return closed


func _get_polygon_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ONE)
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point.x = min(min_point.x, point.x)
		min_point.y = min(min_point.y, point.y)
		max_point.x = max(max_point.x, point.x)
		max_point.y = max(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)


func _get_polygon_area(points: PackedVector2Array) -> float:
	if points.size() < 3:
		return 0.0
	var area := 0.0
	for i in points.size():
		var current := points[i]
		var next := points[(i + 1) % points.size()]
		area += current.x * next.y - next.x * current.y
	return abs(area) * 0.5


func _get_string_seed(text: String) -> int:
	var pattern_seed := 17
	for character in text:
		pattern_seed = int((pattern_seed * 31 + character.unicode_at(0)) % 2147483647)
	return pattern_seed


func _draw_biome_blend_texture() -> void:
	if not is_instance_valid(biome_blend_background) or not biome_blend_background.visible:
		return
	if biome_blend_background.texture:
		draw_texture_rect(biome_blend_background.texture, WORLD_CONFIG.WORLD_RECT, false)


func _log_hitch(delta: float, system_name: String, flags: Dictionary = {}) -> void:
	if delta <= 0.1:
		return
	var now_ms := Time.get_ticks_msec()
	var last_log_ms := int(hitch_log_cooldowns.get(system_name, 0))
	var log_count := int(hitch_log_sequence.get(system_name, 0))
	if log_count < 3:
		hitch_log_sequence[system_name] = log_count + 1
	elif now_ms - last_log_ms < 2000:
		return
	hitch_log_cooldowns[system_name] = now_ms
	var flag_text := ""
	for key in flags.keys():
		if not flag_text.is_empty():
			flag_text += " "
		flag_text += "%s=%s" % [str(key), str(flags.get(key))]
	print("[HITCH] %s delta=%.3f %s" % [system_name, delta, flag_text])


func _get_biome_surface_color_at(surface_position: Vector2, biome_zones: Array) -> Color:
	var terrain_zone := WORLD_CONFIG.get_terrain_zone(surface_position)
	match terrain_zone:
		"deep_ocean":
			return WORLD_CONFIG.OCEAN_COLOR
		"shallow_water":
			return Color(0.11, 0.30, 0.50)
		"shore":
			return Color(0.64, 0.60, 0.38)
	for i in biome_zones.size():
		var biome: Dictionary = biome_zones[i]
		var bounds := Rect2(biome.get("bounds", Rect2()))
		if not bounds.has_point(surface_position):
			continue
		if _is_point_in_biome(surface_position, biome):
			var visual_color := _get_biome_visual_color(biome)
			return _get_biome_terrain_color(biome, surface_position, visual_color)
	return _get_nearest_biome_visual_color(surface_position, biome_zones)


func _get_nearest_biome_visual_color(search_position: Vector2, biome_zones: Array) -> Color:
	var best_color := Color(0.18, 0.28, 0.13)
	var best_distance := INF
	for biome_value in biome_zones:
		var biome: Dictionary = biome_value
		var center := Vector2(biome.get("center", Rect2(biome.get("bounds", Rect2())).get_center()))
		var distance := search_position.distance_squared_to(center)
		if distance < best_distance:
			best_distance = distance
			best_color = _get_biome_visual_color(biome)
	return best_color


func _get_point_polygon_edge_distance(point: Vector2, points: PackedVector2Array) -> float:
	var nearest_distance := INF
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


func _get_biome_colors_key() -> String:
	var parts: Array[String] = []
	for biome in WORLD_CONFIG.get_biome_zones():
		var color := Color(biome["color"])
		parts.append("%.3f:%.3f:%.3f:%s" % [color.r, color.g, color.b, _get_biome_terrain_texture_key(biome)])
	parts.append("texture_balance:%.2f:%.2f:%.2f:%.2f:%d" % [
		float(GAME_BALANCE.BIOME_TEXTURES.get("detail_density_multiplier", 1.0)),
		float(GAME_BALANCE.BIOME_TEXTURES.get("detail_alpha", 0.18)),
		float(GAME_BALANCE.BIOME_TEXTURES.get("secondary_detail_alpha", 0.10)),
		float(GAME_BALANCE.BIOME_TEXTURES.get("variation_noise_strength", 0.22)),
		int(GAME_BALANCE.BIOME_TEXTURES.get("max_detail_per_chunk", 120))
	])
	parts.append("texture_scale:%.2f" % float(GAME_BALANCE.BIOME_TEXTURES.get("blend_cache_scale", 2.0)))
	parts.append("texture_world_scale:%.2f" % float(GAME_BALANCE.BIOME_TEXTURES.get("texture_world_scale", 1.0)))
	return "|".join(parts)


func _get_biome_visual_color(biome: Dictionary) -> Color:
	var base_color := Color(biome["color"])
	if not ecosystem_director or not ecosystem_director.has_method("get_biome_state"):
		return base_color
	var biome_state: Dictionary = ecosystem_director.get_biome_state(_get_biome_id(biome))
	if biome_state.is_empty():
		return base_color
	var biomass_percent: float = clamp(float(biome_state.get("plant_biomass_percent", 100.0)), 0.0, 100.0)
	var visual_bucket: float = max(float(GAME_BALANCE.BIOME_VISUALS.get("biomass_visual_bucket_percent", 5.0)), 1.0)
	var visual_biomass_percent: float = clamp(round(biomass_percent / visual_bucket) * visual_bucket, 0.0, 100.0)
	var stress := 1.0 - visual_biomass_percent / 100.0
	var depleted_tint := Color(GAME_BALANCE.BIOME_VISUALS.get("biomass_depleted_tint", Color(0.34, 0.31, 0.22)))
	var tint_strength := float(GAME_BALANCE.BIOME_VISUALS.get("biomass_tint_max_strength", 0.38))
	var darkening_strength := float(GAME_BALANCE.BIOME_VISUALS.get("biomass_darkening_max_strength", 0.08))
	return base_color.lerp(depleted_tint, stress * tint_strength).darkened(stress * darkening_strength)


func _get_biome_terrain_color(biome: Dictionary, world_position: Vector2, base_color: Color) -> Color:
	var variation_strength: float = minf(float(GAME_BALANCE.BIOME_TEXTURES.get("variation_noise_strength", 0.08)), 0.16)
	if variation_strength <= 0.0:
		return base_color
	var variation_seed := float(_get_string_seed(_get_biome_id(biome)) % 1000) * 0.013
	var noise := sin(world_position.x * 0.004 + variation_seed) * 0.5 + sin(world_position.y * 0.0037 - variation_seed) * 0.5
	var amount := clampf((noise + 1.0) * 0.5, 0.0, 1.0)
	var darker := base_color.darkened(variation_strength)
	var lighter := base_color.lightened(variation_strength * 0.35)
	return base_color.lerp(darker.lerp(lighter, amount), 0.16)


func _sample_biome_terrain_pattern(terrain_pattern: Dictionary, world_position: Vector2) -> float:
	return _sample_biome_texture_luminance(terrain_pattern, world_position)


func _sample_biome_texture_color(terrain_pattern: Dictionary, world_position: Vector2) -> Color:
	var texture_image := _get_biome_texture_image(terrain_pattern)
	if texture_image.is_empty():
		return Color.BLACK
	var texture_position := _get_biome_texture_position(terrain_pattern, world_position, texture_image)
	return texture_image.get_pixel(texture_position.x, texture_position.y)


func _sample_biome_texture_luminance(terrain_pattern: Dictionary, world_position: Vector2) -> float:
	var texture_color := _sample_biome_texture_color(terrain_pattern, world_position)
	return clamp(texture_color.get_luminance(), 0.0, 1.0)


func _sample_forest_floor_pattern(local_position: Vector2, seed_value: float) -> float:
	var leaf_a: float = _sample_jagged_shape(local_position, seed_value, 0.86, 0.34, 0.56, 5, 0.22, 0.055, 0.60, 0.20, 0.14)
	var leaf_b: float = _sample_jagged_shape(local_position + Vector2(0.28, 0.18), seed_value + 1.7, 0.78, 0.28, 0.48, 5, 0.20, 0.050, 0.56, 0.18, 0.12)
	var twig: float = _get_line_mask(sin((local_position.x - local_position.y) * 2.15 + seed_value * 4.9), 0.06, 0.05)
	var litter_edges: float = max(_get_cell_edge_mask(local_position.x * 0.84 + seed_value * 1.4, 0.08), _get_cell_edge_mask(local_position.y * 0.73 - seed_value * 1.1, 0.08))
	return clamp(leaf_a * 0.56 + leaf_b * 0.42 + twig * 0.18 + litter_edges * 0.18, 0.0, 1.0)


func _sample_rock_noise_pattern(local_position: Vector2, seed_value: float) -> float:
	var plate_a: float = _sample_jagged_shape(local_position, seed_value, 1.08, 0.72, 0.52, 7, 0.28, 0.045, 0.72, 0.22, 0.20)
	var plate_b: float = _sample_jagged_shape(local_position + Vector2(0.34, -0.18), seed_value + 2.4, 0.84, 0.54, 0.40, 6, 0.24, 0.040, 0.60, 0.18, 0.16)
	var seam: float = _get_line_mask(sin((local_position.x + local_position.y) * 1.75 + seed_value * 7.3), 0.08, 0.06)
	var shard_edges: float = max(_get_cell_edge_mask(local_position.x * 0.66 + seed_value * 0.8, 0.06), _get_cell_edge_mask(local_position.y * 0.70 - seed_value * 0.5, 0.06))
	return clamp(plate_a * 0.54 + plate_b * 0.34 + seam * 0.24 + shard_edges * 0.16, 0.0, 1.0)


func _sample_grass_streak_pattern(local_position: Vector2, seed_value: float) -> float:
	var cluster_cell := Vector2(floor(local_position.x * 0.85), floor(local_position.y * 0.85))
	var cluster_density: float = _get_pattern_hash(cluster_cell, seed_value * 4.9)
	if cluster_density < 0.30:
		return 0.0
	var blade_a: float = _sample_jagged_shape(local_position, seed_value, 0.66, 0.16, 0.86, 4, 0.16, 0.040, 0.78, 0.14, 0.12)
	var blade_b: float = _sample_jagged_shape(local_position + Vector2(0.16, 0.20), seed_value + 1.2, 0.58, 0.14, 0.78, 4, 0.14, 0.036, 0.72, 0.12, 0.10)
	var blade_c: float = _sample_jagged_shape(local_position + Vector2(-0.22, 0.08), seed_value + 2.1, 0.50, 0.12, 0.72, 4, 0.12, 0.032, 0.66, 0.12, 0.10)
	var dark_blades: float = _get_line_mask(sin((local_position.x * 0.65 - local_position.y * 1.45) * 3.7 + seed_value * 2.8), 0.05, 0.05)
	return clamp(cluster_density * 0.22 + blade_a * 0.44 + blade_b * 0.34 + blade_c * 0.26 + dark_blades * 0.18, 0.0, 1.0)


func _sample_dense_thicket_pattern(local_position: Vector2, seed_value: float) -> float:
	var canopy: float = _sample_jagged_shape(local_position, seed_value, 0.74, 0.30, 0.62, 5, 0.20, 0.050, 0.72, 0.18, 0.16)
	var clusters: float = _sample_jagged_shape(local_position + Vector2(0.18, -0.14), seed_value + 2.4, 0.58, 0.22, 0.50, 5, 0.16, 0.040, 0.60, 0.16, 0.12)
	var stalks: float = _get_line_mask(sin((local_position.x - local_position.y) * 4.05 + seed_value * 4.7), 0.06, 0.05)
	var thicket_edges: float = max(_get_cell_edge_mask(local_position.x * 0.66 + seed_value * 0.6, 0.08), _get_cell_edge_mask(local_position.y * 0.69 - seed_value * 0.8, 0.08))
	return clamp(canopy * 0.42 + clusters * 0.26 + stalks * 0.18 + thicket_edges * 0.18, 0.0, 1.0)


func _sample_dry_cracked_earth_pattern(local_position: Vector2, seed_value: float) -> float:
	var crack_plate_a: float = _sample_jagged_shape(local_position, seed_value, 2.28, 0.98, 0.82, 7, 0.34, 0.080, 0.96, 0.28, 0.18)
	var crack_plate_b: float = _sample_jagged_shape(local_position + Vector2(-0.36, 0.24), seed_value + 1.8, 1.72, 0.74, 0.60, 6, 0.28, 0.070, 0.82, 0.20, 0.14)
	var crack_plate_c: float = _sample_jagged_shape(local_position + Vector2(0.22, -0.30), seed_value + 3.1, 1.18, 0.58, 0.48, 5, 0.22, 0.060, 0.66, 0.14, 0.11)
	var crack_lines: float = _get_line_mask(sin((local_position.x * 0.94 + local_position.y * 0.48) * 3.65 + seed_value * 8.0), 0.11, 0.06)
	var cross_cracks: float = _get_line_mask(sin((local_position.x * 0.42 - local_position.y * 1.16) * 2.78 - seed_value * 5.3), 0.10, 0.06)
	var cell_edges: float = max(
		_get_cell_edge_mask(local_position.x * 0.40 + seed_value * 1.7, 0.14),
		_get_cell_edge_mask(local_position.y * 0.33 - seed_value * 0.9, 0.14)
	)
	var plate_map: float = max(crack_plate_a, max(crack_plate_b * 0.92, crack_plate_c * 0.82))
	var crack_map: float = max(crack_lines, max(cross_cracks, cell_edges))
	var chip_scatter: float = _get_cell_edge_mask(local_position.x * 0.61 + local_position.y * 0.19 + seed_value * 1.2, 0.05) * 0.10
	return clamp(plate_map * 2.0 - crack_map * 0.48 + chip_scatter + 0.02, 0.0, 1.0)


func _get_pattern_hash(grid_position: Vector2, seed_value: float) -> float:
	var value: float = sin(grid_position.x * 127.1 + grid_position.y * 311.7 + seed_value * 913.7) * 43758.5453
	return value - floor(value)


func _sample_jagged_shape(
	local_position: Vector2,
	seed_value: float,
	cell_size: float,
	radius_x: float,
	radius_y: float,
	vertex_count: int,
	jitter: float,
	outline_width: float,
	outline_strength: float,
	fill_strength: float,
	offset_strength: float
) -> float:
	var cell_position := Vector2(
		floor(local_position.x / cell_size),
		floor(local_position.y / cell_size)
	)
	var cell_seed: float = seed_value + cell_position.x * 17.31 + cell_position.y * 29.77
	var center := (cell_position + Vector2(0.5, 0.5)) * cell_size
	var offset := Vector2(
		(_get_pattern_hash(cell_position, cell_seed * 1.3) - 0.5) * cell_size * offset_strength,
		(_get_pattern_hash(cell_position + Vector2(3.0, 7.0), cell_seed * 2.1) - 0.5) * cell_size * offset_strength
	)
	center += offset
	var polygon := _build_jagged_polygon(center, cell_seed, cell_size * radius_x, cell_size * radius_y, vertex_count, jitter)
	var inner_polygon := _scale_polygon(polygon, 0.84)
	if Geometry2D.is_point_in_polygon(local_position, inner_polygon):
		return fill_strength
	var edge_distance := _get_point_polygon_edge_distance(local_position, polygon)
	if edge_distance <= outline_width:
		return outline_strength
	if Geometry2D.is_point_in_polygon(local_position, polygon):
		return max(fill_strength * 0.72, outline_strength * 0.72)
	return 0.0


func _build_jagged_polygon(center: Vector2, seed_value: float, radius_x: float, radius_y: float, vertex_count: int, jitter: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var base_rotation: float = _get_pattern_hash(center.floor(), seed_value * 0.87) * TAU
	for i in range(vertex_count):
		var vertex_index := float(i)
		var count := float(max(vertex_count, 1))
		var angle_variation: float = (_get_pattern_hash(Vector2(vertex_index, count), seed_value * 2.3) - 0.5) * 0.38
		var radius_noise: float = 1.0 + (_get_pattern_hash(Vector2(vertex_index * 2.0, count * 3.0), seed_value * 3.7) - 0.5) * jitter
		var angle: float = base_rotation + TAU * vertex_index / count + angle_variation
		points.append(center + Vector2(cos(angle) * radius_x * radius_noise, sin(angle) * radius_y * radius_noise))
	return points


func _scale_polygon(polygon: PackedVector2Array, scale_factor: float) -> PackedVector2Array:
	var scaled := PackedVector2Array()
	if polygon.is_empty():
		return scaled
	var center := Vector2.ZERO
	for point in polygon:
		center += point
	center /= float(polygon.size())
	for point in polygon:
		scaled.append(center + (point - center) * scale_factor)
	return scaled


func _get_line_mask(signal_value: float, width: float, feather: float) -> float:
	var signal_distance: float = abs(signal_value)
	return 1.0 - _smoothstep(width, width + feather, signal_distance)


func _get_cell_edge_mask(value: float, edge_width: float) -> float:
	var cell_fraction: float = value - floor(value)
	var edge_distance: float = min(cell_fraction, 1.0 - cell_fraction)
	return 1.0 - _smoothstep(edge_width, edge_width * 2.4, edge_distance)


func _smoothstep(edge0: float, edge1: float, value: float) -> float:
	if edge0 == edge1:
		return 1.0 if value >= edge1 else 0.0
	var t: float = clamp((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _get_biome_terrain_texture_key(biome: Dictionary) -> String:
	var terrain_pattern: Dictionary = _get_biome_terrain_pattern(biome)
	if terrain_pattern.is_empty():
		return "none"
	return "%s:%.2f:%.2f" % [
		str(terrain_pattern.get("texture_path", "none")),
		float(terrain_pattern.get("mix", 0.0)),
		float(terrain_pattern.get("seed", 0.0))
	]


func _get_biome_terrain_pattern(biome: Dictionary) -> Dictionary:
	var biome_id := _get_biome_id(biome)
	if not BIOME_TERRAIN_TEXTURES.has(biome_id):
		return {}
	return Dictionary(BIOME_TERRAIN_TEXTURES[biome_id])


func _get_biome_texture_image(terrain_pattern: Dictionary) -> Image:
	var texture_path := str(terrain_pattern.get("texture_path", ""))
	if texture_path.is_empty():
		var empty_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		empty_image.fill(Color.BLACK)
		return empty_image
	if biome_sample_images.has(texture_path):
		var cached_image: Image = biome_sample_images[texture_path]
		return cached_image
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(texture_path)
	if bytes.is_empty():
		push_error("Failed to load biome texture bytes: %s" % texture_path)
		var fallback_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		fallback_image.fill(Color.BLACK)
		return fallback_image
	var image := Image.new()
	var err := image.load_png_from_buffer(bytes)
	if err != OK or image.is_empty():
		push_error("Failed to decode biome texture image: %s" % texture_path)
		var fallback_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		fallback_image.fill(Color.BLACK)
		return fallback_image
	biome_sample_images[texture_path] = image
	return image


func _get_biome_texture_position(terrain_pattern: Dictionary, world_position: Vector2, texture_image: Image) -> Vector2i:
	var pattern_seed := float(terrain_pattern.get("seed", 0.0))
	var density_multiplier := maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("detail_density_multiplier", 1.0)), 0.1)
	density_multiplier *= maxf(float(terrain_pattern.get("density_scale", 1.0)), 0.1)
	var texture_world_scale := maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("texture_world_scale", 1.0)), 0.1)
	var world_rect := WORLD_CONFIG.WORLD_RECT
	var world_uv := Vector2(
		inverse_lerp(world_rect.position.x, world_rect.end.x, world_position.x),
		inverse_lerp(world_rect.position.y, world_rect.end.y, world_position.y)
	)
	var tiled_uv := Vector2(
		fposmod(world_uv.x * density_multiplier / texture_world_scale + pattern_seed * 0.013, 1.0),
		fposmod(world_uv.y * density_multiplier / texture_world_scale + pattern_seed * 0.007, 1.0)
	)
	var sample_position := Vector2(
		tiled_uv.x * float(texture_image.get_width() - 1),
		tiled_uv.y * float(texture_image.get_height() - 1)
	)
	return Vector2i(
		clampi(int(round(sample_position.x)), 0, texture_image.get_width() - 1),
		clampi(int(round(sample_position.y)), 0, texture_image.get_height() - 1)
	)


func _draw_landmarks() -> void:
	for landmark in landmarks:
		match str(landmark.get("type", "")):
			"hill":
				_draw_hill_landmark(landmark)
			"pond":
				_draw_pond_landmark(landmark)


func _draw_landmark_debug_overlay() -> void:
	var font := ThemeDB.fallback_font
	for landmark_value in landmarks:
		var landmark := Dictionary(landmark_value)
		var center := Vector2(landmark.get("position", Vector2.ZERO))
		var radius := float(landmark.get("radius", 120.0))
		var label := "%s | %s | r:%d" % [
			str(landmark.get("type", "landmark")),
			str(landmark.get("biome_id", "unknown")),
			int(round(radius))
		]
		match str(landmark.get("type", "")):
			"pond":
				_draw_debug_ellipse_outline(center, radius, radius * POND_VISUAL_Y_SCALE, Color(0.34, 0.86, 0.92, 0.92), 2.0)
			"hill":
				_draw_debug_ellipse_outline(center, radius, radius * HILL_VISUAL_Y_SCALE, Color(0.98, 0.86, 0.44, 0.92), 2.0)
			_:
				draw_circle(center, max(radius, 6.0), Color(0.94, 0.94, 0.94, 0.32))
		draw_circle(center, 4.0, Color(1.0, 0.95, 0.82, 0.90))
		if font:
			draw_string(font, center + Vector2(-radius * 0.35, -radius - 10.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.98, 0.98, 0.88, 0.92))


func _draw_debug_ellipse_outline(center: Vector2, radius_x: float, radius_y: float, outline_color: Color, line_width: float) -> void:
	var points := PackedVector2Array()
	for i in range(48):
		var angle := TAU * float(i) / 48.0
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	for i in range(points.size()):
		var from := points[i]
		var to := points[(i + 1) % points.size()]
		draw_line(from, to, outline_color, line_width)


func _draw_hill_landmark(landmark: Dictionary) -> void:
	var radius := float(landmark.get("radius", 120.0))
	_draw_filled_hill_shape(landmark, 1.04, Color(0.12, 0.14, 0.09, 0.28), Vector2(radius * 0.05, radius * 0.07))
	_draw_filled_hill_shape(landmark, 1.0, Color(0.30, 0.34, 0.20, 0.86))
	_draw_filled_hill_shape(landmark, _get_hill_mid_elevation_factor(), Color(0.40, 0.42, 0.25, 0.62))
	_draw_filled_hill_shape(landmark, _get_hill_peak_elevation_factor(), Color(0.53, 0.52, 0.32, 0.50), Vector2(-radius * 0.05, -radius * 0.05))
	_draw_hill_slope_marks(landmark)


func _draw_filled_hill_shape(hill: Dictionary, radius_factor: float, hill_color: Color, offset: Vector2 = Vector2.ZERO) -> void:
	var points := PackedVector2Array()
	var sample_count := _get_hill_shape_sample_count()
	for i in range(sample_count):
		var angle := TAU * float(i) / float(sample_count)
		points.append(_get_hill_shape_position(hill, angle, radius_factor, offset))
	draw_colored_polygon(points, hill_color)


func _draw_hill_slope_marks(hill: Dictionary) -> void:
	var center := Vector2(hill.get("position", Vector2.ZERO))
	var radius := float(hill.get("radius", 120.0))
	var light_color := Color(0.63, 0.62, 0.40, 0.42)
	var dark_color := Color(0.16, 0.18, 0.10, 0.32)
	var light_start := center + Vector2(-radius * 0.44, -radius * 0.12)
	var light_end := center + Vector2(radius * 0.12, -radius * 0.24)
	var dark_start := center + Vector2(-radius * 0.20, radius * 0.18)
	var dark_end := center + Vector2(radius * 0.46, radius * 0.02)
	draw_line(light_start, light_end, light_color, 4.0)
	draw_line(center + Vector2(-radius * 0.24, -radius * 0.02), center + Vector2(radius * 0.28, -radius * 0.10), light_color.darkened(0.08), 2.6)
	draw_line(dark_start, dark_end, dark_color, 4.0)
	draw_line(center + Vector2(-radius * 0.08, radius * 0.30), center + Vector2(radius * 0.34, radius * 0.14), dark_color, 2.4)


func _draw_pond_landmark(landmark: Dictionary) -> void:
	var deep_factor := _get_pond_deep_water_radius_factor()
	_draw_filled_pond_shape(landmark, _get_pond_shore_radius_factor(), Color(0.16, 0.28, 0.21, 0.34))
	_draw_filled_pond_shape(landmark, _get_pond_shallow_water_radius_factor(), Color(0.12, 0.37, 0.43, 0.48))
	_draw_filled_pond_shape(landmark, deep_factor, Color(0.06, 0.22, 0.32, 0.76))
	_draw_filled_pond_shape(landmark, deep_factor * 0.72, Color(0.10, 0.35, 0.45, 0.44))
	_draw_pond_shoreline_details(landmark)
	_draw_pond_aquatic_vegetation(landmark)


func _draw_filled_pond_shape(pond: Dictionary, radius_factor: float, pond_color: Color) -> void:
	var points := PackedVector2Array()
	var sample_count := _get_pond_shape_sample_count()
	for i in range(sample_count):
		var angle := TAU * float(i) / float(sample_count)
		points.append(_get_pond_shape_position(pond, angle, radius_factor))
	draw_colored_polygon(points, pond_color)


func _draw_pond_shoreline_details(pond: Dictionary) -> void:
	var detail_count := _get_pond_shore_detail_count()
	for i in range(detail_count):
		var angle := TAU * (float(i) / float(detail_count)) + (_get_pond_detail_noise(pond, i, 1) - 0.5) * 0.34
		var radius_factor := 1.01 + _get_pond_detail_noise(pond, i, 2) * 0.12
		var detail_position := _get_pond_shape_position(pond, angle, radius_factor)
		var size := 8.0 + _get_pond_detail_noise(pond, i, 3) * 10.0
		var color := Color(0.22, 0.32, 0.20, 0.34).lerp(Color(0.31, 0.26, 0.15, 0.38), _get_pond_detail_noise(pond, i, 4))
		_draw_filled_ellipse(Rect2(detail_position - Vector2(size, size * 0.34), Vector2(size * 2.0, size * 0.68)), color)


func _draw_pond_aquatic_vegetation(pond: Dictionary) -> void:
	var vegetation_count := _get_pond_aquatic_vegetation_count()
	for i in range(vegetation_count):
		var near_shore := i % 3 != 0
		var angle := TAU * (float(i) / float(vegetation_count)) + (_get_pond_detail_noise(pond, i, 5) - 0.5) * 0.72
		if near_shore:
			var reed_position := _get_pond_shape_position(pond, angle, 0.82 + _get_pond_detail_noise(pond, i, 6) * 0.24)
			_draw_reed_cluster(reed_position, angle, 3 + int(_get_pond_detail_noise(pond, i, 7) * 3.0))
		else:
			var lily_position := _get_pond_shape_position(pond, angle, 0.36 + _get_pond_detail_noise(pond, i, 8) * 0.42)
			_draw_lily_pad(lily_position, angle)


func _draw_reed_cluster(cluster_position: Vector2, angle: float, blade_count: int) -> void:
	for blade_index in range(blade_count):
		var offset := Vector2.RIGHT.rotated(angle + PI * 0.5) * (float(blade_index) - float(blade_count - 1) * 0.5) * 3.0
		var base := cluster_position + offset
		var height := 14.0 + float(blade_index % 3) * 4.0
		var lean := Vector2.RIGHT.rotated(angle - 0.45 + float(blade_index) * 0.20) * 4.0
		draw_line(base, base + Vector2(0.0, -height) + lean, Color(0.47, 0.55, 0.25, 0.82), 2.0)
		draw_line(base + Vector2(1.5, 0.0), base + Vector2(1.5, -height * 0.74) - lean * 0.4, Color(0.25, 0.43, 0.20, 0.78), 1.4)


func _draw_lily_pad(lily_position: Vector2, angle: float) -> void:
	var radius := 7.0
	_draw_filled_ellipse(Rect2(lily_position - Vector2(radius, radius * 0.62), Vector2(radius * 2.0, radius * 1.24)), Color(0.18, 0.45, 0.22, 0.82))
	var notch_start := lily_position + Vector2.RIGHT.rotated(angle) * 1.5
	draw_line(notch_start, notch_start + Vector2.RIGHT.rotated(angle) * radius, Color(0.08, 0.23, 0.15, 0.55), 1.2)


func _get_pond_detail_noise(pond: Dictionary, index: int, salt: int) -> float:
	var seed_value: float = _get_pond_shape_seed(pond)
	var value: float = sin(seed_value * float(salt + 1) + float(index) * 12.9898 + float(salt) * 78.233) * 43758.5453
	return value - floor(value)


func _get_pond_shore_detail_count() -> int:
	return max(0, int(GAME_BALANCE.LANDMARKS.get("pond_shore_detail_count", 18)))


func _get_pond_aquatic_vegetation_count() -> int:
	return max(0, int(GAME_BALANCE.LANDMARKS.get("pond_aquatic_vegetation_count", 12)))


func _draw_filled_ellipse(rect: Rect2, ellipse_color: Color) -> void:
	var points := PackedVector2Array()
	var center := rect.get_center()
	var radii := rect.size * 0.5
	for i in range(32):
		var angle := TAU * float(i) / 32.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, ellipse_color)
