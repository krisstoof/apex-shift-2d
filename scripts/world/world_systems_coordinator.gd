extends RefCounted
class_name WorldSystemsCoordinator

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const RUNTIME_PROFILER := preload("res://scripts/debug/runtime_profiler.gd")

const TERRAIN_SURFACE_RENDERER_UPDATE_INTERVAL := 0.10
const BIOME_SHAPE_RENDERER_UPDATE_INTERVAL := 0.15
const SMALL_PREY_SPAWN_TICK_SECONDS := 4.0
const ROCK_SPAWN_TICK_SECONDS := 18.0
const DECORATIVE_VEGETATION_VISIBILITY_UPDATE_INTERVAL_SECONDS := 0.35

var world: Node


func bind(p_world: Node) -> void:
	world = p_world


func process_render_sync(delta: float, current_fps: float) -> void:
	if not _has_world():
		return
	_process_render_governor(delta, current_fps)
	_process_terrain_surface(delta)
	_process_biome_shape_renderer(delta)
	_call_world("_update_terrain_renderer", [delta])
	_call_world("_update_spatial_index_debug_cache", [delta])


func process_creature_spawn_sync(delta: float, integration_test_mode: bool) -> void:
	if not _has_world():
		return
	_process_failed_spawn_retry_timers(delta, integration_test_mode)
	_process_small_prey_and_grazer_sync(delta)
	_process_varnak_sync(delta)
	_process_periodic_rock_spawn(delta)


func process_render_controller(delta: float, current_night_amount: float) -> void:
	if not _has_world():
		return
	if bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING):
		RUNTIME_PROFILER.begin_scope("world_render_controller_process_ms")
	var render_controller: Variant = _call_world("_ensure_render_controller")
	if render_controller == null:
		render_controller = _get_ref("render_controller")
	var should_redraw_background := false
	if render_controller != null and render_controller.has_method("process"):
		should_redraw_background = bool(render_controller.process(delta, current_night_amount))
	if bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING):
		RUNTIME_PROFILER.end_scope("world_render_controller_process_ms")
	if should_redraw_background:
		world.queue_redraw()


func process_visibility_controller(delta: float, boot_ready: bool) -> void:
	if not _has_world() or not boot_ready:
		return
	var visibility_controller: Variant = _get_ref("visibility_controller")
	if visibility_controller == null:
		return
	if bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING):
		RUNTIME_PROFILER.begin_scope("visibility_cull_ms")
	if visibility_controller.has_method("process"):
		visibility_controller.process(delta)
	if bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING):
		RUNTIME_PROFILER.end_scope("visibility_cull_ms")


func process_decorative_and_activation(delta: float) -> void:
	if not _has_world():
		return
	var decorative_timer: float = _get_float("decorative_vegetation_visibility_timer") - delta
	if decorative_timer <= 0.0:
		decorative_timer = DECORATIVE_VEGETATION_VISIBILITY_UPDATE_INTERVAL_SECONDS
		if bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING):
			RUNTIME_PROFILER.begin_scope("world_decorative_visible_rect_ms")
		_call_world("_update_decorative_vegetation_visible_rect")
		if bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING):
			RUNTIME_PROFILER.end_scope("world_decorative_visible_rect_ms")
	_set_value("decorative_vegetation_visibility_timer", decorative_timer)

	var activation_timer: float = _get_float("resource_activation_timer") - delta
	if activation_timer <= 0.0:
		activation_timer = _get_float("runtime_activation_update_interval", 0.60)
		_call_world("_update_resource_interactions")
	_set_value("resource_activation_timer", activation_timer)


func process_biome_detail_and_night(delta: float, current_night_amount: float) -> void:
	if not _has_world():
		return
	var use_surface_renderer := _is_surface_renderer_enabled()
	var allow_legacy_overlay := bool(GAME_BALANCE.BIOME_TEXTURES.get("legacy_biome_detail_overlay_enabled_with_surface_renderer", false))
	if not use_surface_renderer or allow_legacy_overlay:
		if bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING):
			RUNTIME_PROFILER.begin_scope("world_biome_detail_overlay_ms")
		_call_world("_update_biome_detail_overlay", [delta])
		if bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING):
			RUNTIME_PROFILER.end_scope("world_biome_detail_overlay_ms")
		if bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING):
			RUNTIME_PROFILER.begin_scope("world_biome_detail_overlay_build_pending_chunks_ms")
		_call_world("_build_pending_biome_detail_overlay_chunks")
		if bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING):
			RUNTIME_PROFILER.end_scope("world_biome_detail_overlay_build_pending_chunks_ms")

	if bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING):
		RUNTIME_PROFILER.begin_scope("world_night_overlay_ms")
	_call_world("_update_night_overlay", [current_night_amount])
	if bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING):
		RUNTIME_PROFILER.end_scope("world_night_overlay_ms")


func _process_render_governor(delta: float, current_fps: float) -> void:
	var governor: Variant = _get_ref("render_performance_governor")
	if governor == null or not governor.has_method("update"):
		return
	governor.update(delta, current_fps)
	if not governor.has_method("get_budget"):
		return
	var governor_budget: Dictionary = Dictionary(governor.get_budget())
	var terrain_surface_chunk_renderer: Variant = _get_ref("terrain_surface_chunk_renderer")
	if is_instance_valid(terrain_surface_chunk_renderer) and terrain_surface_chunk_renderer.has_method("apply_render_budget"):
		terrain_surface_chunk_renderer.apply_render_budget(governor_budget)


func _process_terrain_surface(delta: float) -> void:
	if not _is_surface_renderer_enabled():
		return
	var terrain_surface_chunk_renderer: Variant = _get_ref("terrain_surface_chunk_renderer")
	var timer: float = _get_float("terrain_surface_renderer_update_timer") - delta
	if timer <= 0.0:
		timer = TERRAIN_SURFACE_RENDERER_UPDATE_INTERVAL
		if is_instance_valid(terrain_surface_chunk_renderer):
			if bool(GAME_BALANCE.BIOME_TEXTURES.get("benchmark_collect_render_attribution", true)):
				RUNTIME_PROFILER.begin_scope("terrain_surface_chunk_visibility_ms")
			if terrain_surface_chunk_renderer.has_method("process_visibility"):
				terrain_surface_chunk_renderer.process_visibility(delta)
			if bool(GAME_BALANCE.BIOME_TEXTURES.get("benchmark_collect_render_attribution", true)):
				RUNTIME_PROFILER.end_scope("terrain_surface_chunk_visibility_ms")
	_set_value("terrain_surface_renderer_update_timer", timer)

	if is_instance_valid(terrain_surface_chunk_renderer):
		if bool(GAME_BALANCE.BIOME_TEXTURES.get("benchmark_collect_render_attribution", true)):
			RUNTIME_PROFILER.begin_scope("terrain_surface_chunk_build_ms")
		if terrain_surface_chunk_renderer.has_method("process_build_queue"):
			terrain_surface_chunk_renderer.process_build_queue()
		if bool(GAME_BALANCE.BIOME_TEXTURES.get("benchmark_collect_render_attribution", true)):
			RUNTIME_PROFILER.end_scope("terrain_surface_chunk_build_ms")


func _process_biome_shape_renderer(delta: float) -> void:
	var biome_shape_renderer: Variant = _get_ref("biome_shape_renderer")
	var timer: float = _get_float("biome_shape_renderer_update_timer") - delta
	if timer <= 0.0:
		timer = BIOME_SHAPE_RENDERER_UPDATE_INTERVAL
		if is_instance_valid(biome_shape_renderer):
			if bool(GAME_BALANCE.BIOME_TEXTURES.get("benchmark_collect_render_attribution", true)):
				RUNTIME_PROFILER.begin_scope("biome_shape_renderer_visibility_ms")
			if biome_shape_renderer.has_method("process_visibility"):
				biome_shape_renderer.process_visibility(delta)
			if bool(GAME_BALANCE.BIOME_TEXTURES.get("benchmark_collect_render_attribution", true)):
				RUNTIME_PROFILER.end_scope("biome_shape_renderer_visibility_ms")
	_set_value("biome_shape_renderer_update_timer", timer)


func _process_failed_spawn_retry_timers(delta: float, integration_test_mode: bool) -> void:
	if integration_test_mode:
		return
	var small_retry: float = _get_float("small_prey_failed_spawn_retry_timer")
	if small_retry > 0.0:
		_set_value("small_prey_failed_spawn_retry_timer", maxf(0.0, small_retry - delta))
	var varnak_retry: float = _get_float("varnak_failed_spawn_retry_timer")
	if varnak_retry > 0.0:
		_set_value("varnak_failed_spawn_retry_timer", maxf(0.0, varnak_retry - delta))


func _process_small_prey_and_grazer_sync(delta: float) -> void:
	var timer: float = _get_float("small_prey_spawn_timer") + delta
	if timer >= SMALL_PREY_SPAWN_TICK_SECONDS:
		timer = 0.0
		if bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING):
			RUNTIME_PROFILER.begin_scope("world_sync_visible_small_prey_ms")
		_call_world("_sync_visible_small_prey")
		if bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING):
			RUNTIME_PROFILER.end_scope("world_sync_visible_small_prey_ms")
		if bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING):
			RUNTIME_PROFILER.begin_scope("world_sync_visible_grazers_ms")
		_call_world("_sync_visible_grazers")
		if bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING):
			RUNTIME_PROFILER.end_scope("world_sync_visible_grazers_ms")
	_set_value("small_prey_spawn_timer", timer)


func _process_varnak_sync(delta: float) -> void:
	var timer: float = _get_float("varnak_spawn_timer") + delta
	var interval: float = 10.0
	var interval_value: Variant = _call_world("_get_varnak_spawn_check_interval")
	if interval_value != null:
		interval = float(interval_value)
	if timer >= interval:
		timer = 0.0
		if bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING):
			RUNTIME_PROFILER.begin_scope("world_sync_visible_varnaks_ms")
		_call_world("_sync_visible_varnaks")
		if bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING):
			RUNTIME_PROFILER.end_scope("world_sync_visible_varnaks_ms")
	_set_value("varnak_spawn_timer", timer)


func _process_periodic_rock_spawn(delta: float) -> void:
	var timer: float = _get_float("rock_spawn_timer") + delta
	if timer >= ROCK_SPAWN_TICK_SECONDS:
		timer = 0.0
		if bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING):
			RUNTIME_PROFILER.begin_scope("world_sync_periodic_rock_spawn_ms")
		_call_world("_sync_periodic_rock_spawn")
		if bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING):
			RUNTIME_PROFILER.end_scope("world_sync_periodic_rock_spawn_ms")
	_set_value("rock_spawn_timer", timer)


func _is_surface_renderer_enabled() -> bool:
	if not _has_world():
		return false
	var runtime_value: Variant = world.get("runtime_use_terrain_surface_chunk_renderer")
	if runtime_value != null:
		return bool(runtime_value)
	return bool(GAME_BALANCE.BIOME_TEXTURES.get("use_terrain_surface_chunk_renderer", true))


func _has_world() -> bool:
	return world != null and is_instance_valid(world)


func _get_ref(property_name: String) -> Variant:
	if not _has_world():
		return null
	return world.get(property_name)


func _get_float(property_name: String, fallback: float = 0.0) -> float:
	if not _has_world():
		return fallback
	var value: Variant = world.get(property_name)
	if value == null:
		return fallback
	return float(value)


func _set_value(property_name: String, value: Variant) -> void:
	if not _has_world():
		return
	world.set(property_name, value)


func _call_world(method_name: String, args: Array = []) -> Variant:
	if not _has_world() or not world.has_method(method_name):
		return null
	return world.callv(method_name, args)
