extends Node2D
class_name TerrainSurfaceChunkRenderer

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const RUNTIME_PROFILER := preload("res://scripts/debug/runtime_profiler.gd")

## Explicit state for every terrain chunk.
## Replaces implicit "figure out state from dict lookups" logic.
## Use chunk_states[key] to read/write. Debug with _get_chunk_state_counts().
enum ChunkState {
	EMPTY = 0,           ## No texture, not in any queue.
	PREVIEW_QUEUED = 1,  ## In pending_chunks, build not yet started.
	PREVIEW_BUILDING = 2,## In active_builds, stage="preview".
	PREVIEW_READY = 3,   ## Has preview texture; in active_builds stage="refine_pending".
	REFINE_BUILDING = 4, ## In active_builds, stage="refine".
	REFINED_READY = 5,   ## Has refined texture; not in active_builds.
	FAILED = 6,          ## Build encountered an unrecoverable error.
	STALE = 7,           ## Removed because chunk left the visible area.
}

var world: Node
var player: Node2D
var camera: Camera2D
var biome_shape_map: Object

var world_rect := Rect2()
var chunk_world_size := 1024.0
var chunk_texture_size := 256
var visible_margin_chunks := 1
var max_chunks_built_per_frame := 1
var preview_enabled := true
var preview_chunk_texture_size := 48
var preview_max_chunks_built_per_frame := 4
var preview_active_build_limit := 6
var refined_chunk_texture_size := 96
var refined_max_rows_built_per_frame := 8
var refined_max_build_ms_per_frame := 4.0
var refine_delay_seconds := 0.15
var refine_pause_when_fps_below := 45
var refine_pause_when_camera_moving := true
var max_refined_chunks_per_second := 3
var preview_only_during_fast_movement := true

var visible_chunks: Dictionary = {}
var chunk_textures: Dictionary = {}
var chunk_states: Dictionary = {}  # Vector2i -> ChunkState
var pending_chunks: Array = []
var pending_chunk_set: Dictionary = {}
var active_builds := {}
var sample_cache := {}
var biome_blend_cache := {}

var last_visible_signature := ""
var dirty := true

var visible_chunk_count := 0
var cached_chunk_count := 0
var preview_chunk_count := 0
var refined_chunk_count := 0
var terrain_surface_drawn_chunk_count := 0
var terrain_surface_skipped_chunk_count := 0
var terrain_surface_refine_skipped_due_to_camera_movement_count := 0
var terrain_surface_refine_skipped_due_to_fps_count := 0
var chunks_built_last_frame := 0
var preview_chunks_built_last_frame := 0
var refined_chunks_built_last_frame := 0
var last_build_ms := 0.0
var max_build_ms := 0.0
var total_build_count := 0
var preview_build_count := 0
var refined_build_count := 0
var chunk_build_started_count := 0
var chunk_build_completed_count := 0
var last_clear_reason := ""
var max_rows_built_per_frame := 8
var max_build_ms_per_frame := 4.0
var hard_budget_enabled := true
var hard_budget_ms := 1.0
var build_cell_batch_size := 16
var preview_build_cell_batch_size := 64
var refined_build_cell_batch_size := 16
var refined_build_cell_batch_size_current := 16
var last_motion_sample_position := Vector2.INF
var refined_chunk_window_start_ms := 0
var refined_chunks_started_in_window := 0
var pending_focus_chunk := Vector2i.ZERO
var surface_sample_source_counts := {}
var exact_surface_sample_count := 0
var grid_surface_sample_count := 0
var world_fallback_surface_sample_count := 0
var terrain_surface_build_budget_exceeded_count := 0
var terrain_surface_build_budget_max_overrun_ms := 0.0
var terrain_surface_build_soft_budget_exceeded_count := 0
var terrain_surface_build_hard_budget_exceeded_count := 0
var terrain_surface_build_steps_last_frame := 0
var terrain_surface_build_pixels_last_frame := 0
var terrain_surface_build_rows_last_frame := 0
var terrain_surface_build_chunks_started_last_frame := 0
var terrain_surface_build_chunks_completed_last_frame := 0
var terrain_surface_missing_visible_texture_count := 0
var terrain_surface_visible_chunks_without_texture := 0
var terrain_surface_old_texture_fallback_drawn_count := 0
var terrain_surface_preview_time_to_first_chunk_ms := 0.0
var terrain_surface_preview_time_to_visible_coverage_ms := 0.0
var terrain_surface_first_preview_started_ms := 0
var use_shape_map_sampling_override := false
var has_use_shape_map_sampling_override := false
# Debug counters for refine pipeline tracking
var refine_jobs_started := 0
var refine_jobs_completed := 0
var refine_jobs_cancelled := 0
var refine_jobs_stale := 0
var active_refine_build_count_debug := 0
var refine_pending_count_debug := 0
var last_camera_idle_time_ms := 0
var smoke_test_refine_build_count_at_idle := 0
var smoke_test_idle_duration_ms := 0
var smoke_test_warning_emitted := false
var smoke_test_warning_count := 0
var smoke_test_warning_cooldown_ms := 30000
var last_smoke_test_warning_ms := 0
var refine_idle_grace_period_ms := 5000
var refine_idle_min_interval_ms := 2500
var last_refine_idle_allow_ms := 0
var smoke_test_refine_work_pending := false
var smoke_test_last_refined_count := 0
var smoke_test_last_refine_progress_ms := 0
var terrain_surface_refine_blocked_reason := ""
var terrain_surface_last_refine_allowed_ms := 0
var terrain_surface_last_refine_started_ms := 0
var terrain_surface_refine_enabled := true
var terrain_surface_refine_disabled_reason := ""
var preview_build_watchdog_start_ms: Dictionary = {}

func bind(p_world: Node, p_player: Node2D, p_camera: Camera2D) -> void:
	var previous_world := world
	world = p_world
	player = p_player
	camera = p_camera
	if world != null and world.has_method("get_world_rect"):
		world_rect = Rect2(world.get_world_rect())
	else:
		world_rect = Rect2(Vector2(-10080.0, -6240.0), Vector2(20160.0, 12480.0))
	biome_shape_map = null
	if world != null and world.has_method("get_biome_shape_map"):
		biome_shape_map = world.get_biome_shape_map()
	var world_changed := previous_world != p_world
	chunk_world_size = maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_chunk_world_size", 1024.0)), 256.0)
	preview_enabled = bool(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_preview_enabled", true))
	preview_chunk_texture_size = maxi(int(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_preview_texture_size", 32)), 16)
	preview_max_chunks_built_per_frame = maxi(int(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_preview_max_chunks_built_per_frame", 8)), 1)
	preview_active_build_limit = maxi(int(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_preview_active_build_limit", 12)), 1)
	refined_chunk_texture_size = maxi(int(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_refined_texture_size", GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_chunk_texture_size", 96))), 32)
	chunk_texture_size = refined_chunk_texture_size
	refined_max_rows_built_per_frame = maxi(int(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_refine_max_rows_built_per_frame", 8)), 1)
	refined_max_build_ms_per_frame = maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_refine_max_build_ms_per_frame", 4.0)), 1.0)
	refine_delay_seconds = maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_refine_delay_seconds", 0.05)), 0.0)
	refine_pause_when_fps_below = maxi(int(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_refine_pause_when_fps_below", 25)), 0)
	refine_pause_when_camera_moving = bool(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_refine_pause_when_camera_moving", true))
	max_refined_chunks_per_second = maxi(int(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_max_refined_chunks_per_second", 8)), 1)
	hard_budget_enabled = bool(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_hard_budget_enabled", true))
	hard_budget_ms = maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_hard_budget_ms", 1.0)), 0.1)
	build_cell_batch_size = maxi(int(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_build_cell_batch_size", 16)), 1)
	preview_build_cell_batch_size = maxi(int(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_preview_build_cell_batch_size", 64)), 1)
	refined_build_cell_batch_size = maxi(int(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_refined_build_cell_batch_size", build_cell_batch_size)), 1)
	refined_build_cell_batch_size_current = refined_build_cell_batch_size
	preview_only_during_fast_movement = bool(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_preview_only_during_fast_movement", true))
	visible_margin_chunks = maxi(int(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_visible_margin_chunks", 1)), 0)
	max_chunks_built_per_frame = maxi(int(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_max_chunks_built_per_frame", preview_max_chunks_built_per_frame)), 1)
	max_rows_built_per_frame = refined_max_rows_built_per_frame
	max_build_ms_per_frame = refined_max_build_ms_per_frame
	last_motion_sample_position = _get_motion_sample_position()
	refined_chunk_window_start_ms = Time.get_ticks_msec()
	refined_chunks_started_in_window = 0
	terrain_surface_first_preview_started_ms = Time.get_ticks_msec()
	if bool(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_texture_filter_nearest", false)):
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if world_changed:
		mark_dirty("bind_world_changed")


func set_terrain_surface_refine_enabled(enabled: bool) -> void:
	terrain_surface_refine_enabled = enabled
	terrain_surface_refine_disabled_reason = "" if enabled else "benchmark_disabled"
	if not enabled:
		_clear_or_pause_refine_queue_for_benchmark()


func is_terrain_surface_refine_enabled() -> bool:
	return terrain_surface_refine_enabled


func _clear_or_pause_refine_queue_for_benchmark() -> void:
	terrain_surface_refine_blocked_reason = terrain_surface_refine_disabled_reason
func apply_render_budget(budget: Dictionary) -> void:
	max_chunks_built_per_frame = maxi(int(budget.get("terrain_refined_chunks_per_frame", max_chunks_built_per_frame)), 1)
	max_build_ms_per_frame = maxf(float(budget.get("terrain_build_budget_ms", max_build_ms_per_frame)), 0.5)
	visible_margin_chunks = maxi(int(budget.get("terrain_visible_margin_chunks", visible_margin_chunks)), 0)
	refined_chunk_texture_size = maxi(int(budget.get("terrain_refined_texture_size", refined_chunk_texture_size)), 32)
	chunk_texture_size = refined_chunk_texture_size
	refine_pause_when_fps_below = maxi(int(budget.get("terrain_refine_pause_when_fps_below", refine_pause_when_fps_below)), 0)
	max_refined_chunks_per_second = maxi(int(budget.get("terrain_max_refined_chunks_per_second", max_refined_chunks_per_second)), 1)

func mark_dirty(reason := "unknown") -> void:
	dirty = true
	last_clear_reason = reason
	chunk_textures.clear()
	visible_chunks.clear()
	pending_chunks.clear()
	pending_chunk_set.clear()
	active_builds.clear()
	sample_cache.clear()
	biome_blend_cache.clear()
	surface_sample_source_counts.clear()
	exact_surface_sample_count = 0
	grid_surface_sample_count = 0
	world_fallback_surface_sample_count = 0
	last_visible_signature = ""
	visible_chunk_count = 0
	cached_chunk_count = 0
	preview_chunk_count = 0
	refined_chunk_count = 0
	preview_chunks_built_last_frame = 0
	refined_chunks_built_last_frame = 0
	refined_chunk_window_start_ms = Time.get_ticks_msec()
	refined_chunks_started_in_window = 0
	last_motion_sample_position = _get_motion_sample_position()
	refine_jobs_started = 0
	refine_jobs_completed = 0
	refine_jobs_cancelled = 0
	refine_jobs_stale = 0
	smoke_test_refine_build_count_at_idle = 0
	smoke_test_idle_duration_ms = 0
	smoke_test_warning_emitted = false
	smoke_test_warning_count = 0
	last_refine_idle_allow_ms = 0
	smoke_test_refine_work_pending = false
	smoke_test_last_refined_count = 0
	smoke_test_last_refine_progress_ms = 0
	terrain_surface_refine_blocked_reason = ""
	terrain_surface_last_refine_allowed_ms = 0
	terrain_surface_last_refine_started_ms = 0
	preview_build_watchdog_start_ms.clear()
	chunk_states.clear()
	queue_redraw()


func clear_runtime_state(reason := "cleanup") -> void:
	last_clear_reason = reason
	chunk_textures.clear()
	visible_chunks.clear()
	pending_chunks.clear()
	pending_chunk_set.clear()
	active_builds.clear()
	chunk_states.clear()
	sample_cache.clear()
	biome_blend_cache.clear()
	surface_sample_source_counts.clear()
	world = null
	player = null
	camera = null
	biome_shape_map = null
	last_visible_signature = ""
	visible_chunk_count = 0
	cached_chunk_count = 0
	preview_chunk_count = 0
	refined_chunk_count = 0
	chunks_built_last_frame = 0
	preview_chunks_built_last_frame = 0
	refined_chunks_built_last_frame = 0
	refine_jobs_started = 0
	refine_jobs_completed = 0
	refine_jobs_cancelled = 0
	refine_jobs_stale = 0
	smoke_test_warning_emitted = false
	smoke_test_warning_count = 0
	last_refine_idle_allow_ms = 0
	smoke_test_refine_work_pending = false
	smoke_test_last_refined_count = 0
	smoke_test_last_refine_progress_ms = 0
	terrain_surface_refine_blocked_reason = ""
	terrain_surface_last_refine_allowed_ms = 0
	terrain_surface_last_refine_started_ms = 0
	preview_build_watchdog_start_ms.clear()
	queue_redraw()


func _exit_tree() -> void:
	clear_runtime_state("exit_tree")

func process_visibility(_delta: float) -> void:
	var profile_enabled := bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING)
	if profile_enabled:
		RUNTIME_PROFILER.begin_scope("terrain_surface_process_visibility_ms")
	if world == null:
		if profile_enabled:
			RUNTIME_PROFILER.end_scope("terrain_surface_process_visibility_ms")
		return
	if profile_enabled:
		RUNTIME_PROFILER.begin_scope("terrain_surface_rebuild_visible_chunks_ms")
	var visible_rect := _get_visible_world_rect()
	var chunk_bounds := _get_chunk_bounds_for_rect(visible_rect)
	var signature := _chunk_bounds_signature(chunk_bounds)
	if not dirty and signature == last_visible_signature:
		if profile_enabled:
			RUNTIME_PROFILER.end_scope("terrain_surface_rebuild_visible_chunks_ms")
			RUNTIME_PROFILER.end_scope("terrain_surface_process_visibility_ms")
		return
	last_visible_signature = signature
	dirty = false
	visible_chunks.clear()
	for cy in range(chunk_bounds.position.y, chunk_bounds.position.y + chunk_bounds.size.y):
		for cx in range(chunk_bounds.position.x, chunk_bounds.position.x + chunk_bounds.size.x):
			var key := Vector2i(cx, cy)
			visible_chunks[key] = true
			if not chunk_textures.has(key):
				_queue_chunk_build(key)
	_sort_pending_chunks_by_focus()
	visible_chunk_count = visible_chunks.size()
	cached_chunk_count = chunk_textures.size()
	queue_redraw()
	if profile_enabled:
		RUNTIME_PROFILER.end_scope("terrain_surface_rebuild_visible_chunks_ms")
		RUNTIME_PROFILER.end_scope("terrain_surface_process_visibility_ms")

func process_build_queue(delta: float = 0.0) -> void:
	var profile_enabled := bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING)
	if profile_enabled:
		RUNTIME_PROFILER.begin_scope("terrain_surface_build_chunks_ms")
	if bool(GAME_BALANCE.BIOME_TEXTURES.get("benchmark_collect_render_attribution", true)):
		RUNTIME_PROFILER.begin_scope("terrain_surface_chunk_build_queue_ms")
	chunks_built_last_frame = 0
	preview_chunks_built_last_frame = 0
	refined_chunks_built_last_frame = 0
	terrain_surface_build_steps_last_frame = 0
	terrain_surface_build_pixels_last_frame = 0
	terrain_surface_build_rows_last_frame = 0
	terrain_surface_build_chunks_started_last_frame = 0
	terrain_surface_build_chunks_completed_last_frame = 0
	var start_usec: int = Time.get_ticks_usec()
	var hard_budget_usec: int = int(hard_budget_ms * 1000.0)
	var hard_budget_deadline_usec: int = start_usec + hard_budget_usec if hard_budget_enabled else 9223372036854775807
	
	# Smoke test: detect camera idle for 30 seconds
	var current_position := _get_motion_sample_position()
	var is_camera_idle := not _is_camera_moving_fast()
	if is_camera_idle:
		if last_camera_idle_time_ms == 0:
			last_camera_idle_time_ms = Time.get_ticks_msec()
		smoke_test_idle_duration_ms = int(Time.get_ticks_msec() - last_camera_idle_time_ms)
		if smoke_test_idle_duration_ms >= 30000:  # 30 seconds
			smoke_test_refine_build_count_at_idle = refined_build_count
			smoke_test_refine_work_pending = _count_active_stage("refine") > 0 or _count_active_stage("refine_pending") > 0
			if refined_build_count > smoke_test_last_refined_count:
				smoke_test_last_refined_count = refined_build_count
				smoke_test_last_refine_progress_ms = Time.get_ticks_msec()
			var stalled_refine := Time.get_ticks_msec() - smoke_test_last_refine_progress_ms >= 30000
			if smoke_test_refine_work_pending and stalled_refine and Time.get_ticks_msec() - last_smoke_test_warning_ms >= smoke_test_warning_cooldown_ms:
				smoke_test_warning_emitted = true
				smoke_test_warning_count += 1
				last_smoke_test_warning_ms = Time.get_ticks_msec()
				push_warning("TERRAIN_SURFACE_SMOKE_TEST: Refine work pending after 30s idle (pending=%d active=%d blocked_reason=%s)." % [
					_count_active_stage("refine_pending"),
					_count_active_stage("refine"),
					terrain_surface_refine_blocked_reason if not terrain_surface_refine_blocked_reason.is_empty() else "none"
				])
	else:
		last_camera_idle_time_ms = 0
		smoke_test_idle_duration_ms = 0
		smoke_test_warning_emitted = false
		smoke_test_refine_work_pending = false
	
	# Remove invisible chunks from active builds
	var chunks_to_remove: Array = []
	for chunk_key in active_builds.keys():
		if not visible_chunks.has(chunk_key):
			var state := Dictionary(active_builds[chunk_key])
			var stage := str(state.get("stage", "preview"))
			if stage == "refine":
				refine_jobs_cancelled += 1
			elif stage == "refine_pending":
				pass  # Will be counted as stale
			chunks_to_remove.append(chunk_key)
	
	for chunk_key in chunks_to_remove:
		active_builds.erase(chunk_key)
		refine_jobs_stale += 1
		chunk_states[chunk_key] = ChunkState.STALE
		preview_build_watchdog_start_ms.erase(chunk_key)
	
	var active_work_limit := preview_active_build_limit + max_chunks_built_per_frame
	while _count_active_work_stages() < active_work_limit and not pending_chunks.is_empty():
		if Time.get_ticks_usec() >= hard_budget_deadline_usec:
			break
		var chunk_key = pending_chunks.pop_front()
		pending_chunk_set.erase(chunk_key)
		if chunk_textures.has(chunk_key) or active_builds.has(chunk_key):
			continue
		if chunk_textures.size() < visible_chunks.size() and _count_active_stage("preview") >= preview_active_build_limit:
			_queue_chunk_build(chunk_key)
			break
		_start_chunk_build(chunk_key)
		terrain_surface_build_chunks_started_last_frame += 1
	
	var allow_refine := _can_process_refine()
	for chunk_key in _get_active_build_keys_by_priority():
		if Time.get_ticks_usec() >= hard_budget_deadline_usec:
			break
		_process_active_chunk_build(chunk_key, start_usec, allow_refine, hard_budget_deadline_usec)
		if float(Time.get_ticks_usec() - start_usec) / 1000.0 >= max_build_ms_per_frame:
			break
	
	last_build_ms = float(Time.get_ticks_usec() - start_usec) / 1000.0
	if hard_budget_enabled and last_build_ms > hard_budget_ms:
		terrain_surface_build_budget_exceeded_count += 1
		terrain_surface_build_budget_max_overrun_ms = maxf(terrain_surface_build_budget_max_overrun_ms, last_build_ms - hard_budget_ms)
	max_build_ms = maxf(max_build_ms, last_build_ms)
	cached_chunk_count = chunk_textures.size()
	if chunks_built_last_frame > 0:
		queue_redraw()
	if bool(GAME_BALANCE.BIOME_TEXTURES.get("benchmark_collect_render_attribution", true)):
		RUNTIME_PROFILER.end_scope("terrain_surface_chunk_build_queue_ms")
	if profile_enabled:
		RUNTIME_PROFILER.end_scope("terrain_surface_build_chunks_ms")

func get_debug_data() -> Dictionary:
	return {
		"terrain_surface_chunk_renderer_enabled": visible,
		"terrain_surface_chunk_visible_count": visible_chunk_count,
		"terrain_surface_chunk_cached_count": cached_chunk_count,
		"terrain_surface_chunk_preview_count": preview_chunk_count,
		"terrain_surface_chunk_refined_count": refined_chunk_count,
		"terrain_surface_chunk_pending_count": pending_chunks.size(),
		"terrain_surface_chunks_built_last_frame": chunks_built_last_frame,
		"terrain_surface_preview_chunks_built_last_frame": preview_chunks_built_last_frame,
		"terrain_surface_refined_chunks_built_last_frame": refined_chunks_built_last_frame,
		"terrain_surface_chunk_last_build_ms": last_build_ms,
		"terrain_surface_chunk_max_build_ms": max_build_ms,
		"terrain_surface_chunk_total_build_count": total_build_count,
		"terrain_surface_preview_build_count": preview_build_count,
		"terrain_surface_refined_build_count": refined_build_count,
		"terrain_surface_active_build_count": active_builds.size(),
		"terrain_surface_active_work_build_count": _count_active_work_stages(),
		"terrain_surface_active_preview_build_count": _count_active_stage("preview"),
		"terrain_surface_active_refine_build_count": _count_active_stage("refine"),
		"terrain_surface_active_refine_pending_count": _count_active_stage("refine_pending"),
		"terrain_surface_chunk_state_counts": _get_chunk_state_counts(),
		"terrain_surface_drawn_chunk_count": terrain_surface_drawn_chunk_count,
		"terrain_surface_skipped_chunk_count": terrain_surface_skipped_chunk_count,
		"terrain_surface_refine_skipped_due_to_camera_movement_count": terrain_surface_refine_skipped_due_to_camera_movement_count,
		"terrain_surface_refine_skipped_due_to_fps_count": terrain_surface_refine_skipped_due_to_fps_count,
		"terrain_surface_chunk_build_started_count": chunk_build_started_count,
		"terrain_surface_chunk_build_completed_count": chunk_build_completed_count,
		"terrain_surface_build_budget_exceeded_count": terrain_surface_build_budget_exceeded_count,
		"terrain_surface_build_budget_max_overrun_ms": terrain_surface_build_budget_max_overrun_ms,
		"terrain_surface_build_soft_budget_exceeded_count": terrain_surface_build_soft_budget_exceeded_count,
		"terrain_surface_build_hard_budget_exceeded_count": terrain_surface_build_hard_budget_exceeded_count,
		"terrain_surface_build_steps_last_frame": terrain_surface_build_steps_last_frame,
		"terrain_surface_build_pixels_last_frame": terrain_surface_build_pixels_last_frame,
		"terrain_surface_build_rows_last_frame": terrain_surface_build_rows_last_frame,
		"terrain_surface_build_chunks_started_last_frame": terrain_surface_build_chunks_started_last_frame,
		"terrain_surface_build_chunks_completed_last_frame": terrain_surface_build_chunks_completed_last_frame,
		"terrain_surface_missing_visible_texture_count": terrain_surface_missing_visible_texture_count,
		"terrain_surface_visible_chunks_without_texture": terrain_surface_visible_chunks_without_texture,
		"terrain_surface_old_texture_fallback_drawn_count": terrain_surface_old_texture_fallback_drawn_count,
		"terrain_surface_preview_time_to_first_chunk_ms": terrain_surface_preview_time_to_first_chunk_ms,
		"terrain_surface_preview_time_to_visible_coverage_ms": terrain_surface_preview_time_to_visible_coverage_ms,
		"terrain_surface_preview_enabled": preview_enabled,
		"terrain_surface_preview_texture_size": preview_chunk_texture_size,
		"terrain_surface_refined_texture_size": refined_chunk_texture_size,
		"terrain_surface_refine_delay_seconds": refine_delay_seconds,
		"terrain_surface_refine_pause_when_fps_below": refine_pause_when_fps_below,
		"terrain_surface_refine_pause_when_camera_moving": refine_pause_when_camera_moving,
		"terrain_surface_max_refined_chunks_per_second": max_refined_chunks_per_second,
		"terrain_surface_preview_only_during_fast_movement": preview_only_during_fast_movement,
		"terrain_surface_max_rows_built_per_frame": max_rows_built_per_frame,
		"terrain_surface_max_build_ms_per_frame": max_build_ms_per_frame,
		"terrain_surface_transition_enabled": bool(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_transition_enabled", false)),
		"terrain_surface_uses_biome_shape_map": biome_shape_map != null and biome_shape_map.has_method("sample_visual_surface_at"),
		"terrain_surface_sample_source_counts": surface_sample_source_counts,
		"terrain_surface_exact_surface_sample_count": exact_surface_sample_count,
		"terrain_surface_grid_surface_sample_count": grid_surface_sample_count,
		"terrain_surface_world_fallback_surface_sample_count": world_fallback_surface_sample_count,
		"terrain_surface_use_shape_map_sampling": bool(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_use_shape_map_sampling", false)),
		"terrain_surface_use_exact_shape_sampling": bool(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_use_exact_shape_sampling", true)),
		"terrain_surface_chunk_world_size": chunk_world_size,
		"terrain_surface_chunk_texture_size": chunk_texture_size,
		"terrain_surface_visible_signature": last_visible_signature,
		"terrain_surface_last_clear_reason": last_clear_reason,
		"terrain_surface_draw_mode": "chunk_texture_surface",
		# Debug counters for refine pipeline
		"terrain_surface_refine_jobs_started": refine_jobs_started,
		"terrain_surface_refine_jobs_completed": refine_jobs_completed,
		"terrain_surface_refine_jobs_cancelled": refine_jobs_cancelled,
		"terrain_surface_refine_jobs_stale": refine_jobs_stale,
		"terrain_surface_refine_blocked_reason": terrain_surface_refine_blocked_reason,
		"terrain_surface_last_refine_allowed_ms": terrain_surface_last_refine_allowed_ms,
		"terrain_surface_last_refine_started_ms": terrain_surface_last_refine_started_ms,
		"terrain_surface_active_refine_count": _count_active_stage("refine"),
		"terrain_surface_refine_pending_count": _count_active_stage("refine_pending"),
		"terrain_surface_smoke_test_idle_duration_ms": smoke_test_idle_duration_ms,
		"terrain_surface_smoke_test_refine_count_at_idle": smoke_test_refine_build_count_at_idle,
		"terrain_surface_smoke_test_refine_work_pending": smoke_test_refine_work_pending,
		"terrain_surface_smoke_test_stuck": smoke_test_refine_work_pending and smoke_test_idle_duration_ms >= 30000 and smoke_test_refine_build_count_at_idle <= 1,
		"terrain_surface_smoke_test_warning_count": smoke_test_warning_count,
		"terrain_surface_smoke_test_last_warning_ms": last_smoke_test_warning_ms
	}

func _draw() -> void:
	if not visible:
		return
	if bool(GAME_BALANCE.BIOME_TEXTURES.get("benchmark_collect_render_attribution", true)):
		RUNTIME_PROFILER.begin_scope("terrain_surface_chunk_draw_ms")
	terrain_surface_drawn_chunk_count = 0
	terrain_surface_skipped_chunk_count = 0
	terrain_surface_missing_visible_texture_count = 0
	terrain_surface_visible_chunks_without_texture = 0
	terrain_surface_old_texture_fallback_drawn_count = 0
	var actual_visible_rect := _get_actual_camera_world_rect()
	for key_value in visible_chunks.keys():
		var chunk_key: Vector2i = key_value
		var chunk_rect := _get_chunk_world_rect(chunk_key)
		if not chunk_rect.intersects(actual_visible_rect.grow(chunk_world_size * 0.15)):
			terrain_surface_skipped_chunk_count += 1
			continue
		var texture = chunk_textures.get(chunk_key, null)
		if texture == null:
			terrain_surface_missing_visible_texture_count += 1
			terrain_surface_visible_chunks_without_texture += 1
			if bool(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_draw_placeholders", false)):
				_draw_chunk_placeholder(chunk_key)
				terrain_surface_old_texture_fallback_drawn_count += 1
				terrain_surface_drawn_chunk_count += 1
			continue
		draw_texture_rect(texture, chunk_rect, false)
		terrain_surface_drawn_chunk_count += 1
	if bool(GAME_BALANCE.BIOME_TEXTURES.get("benchmark_collect_render_attribution", true)):
		RUNTIME_PROFILER.end_scope("terrain_surface_chunk_draw_ms")

func _queue_chunk_build(chunk_key: Vector2i) -> void:
	if pending_chunk_set.has(chunk_key):
		return
	pending_chunk_set[chunk_key] = true
	pending_chunks.append(chunk_key)
	chunk_states[chunk_key] = ChunkState.PREVIEW_QUEUED

func _sort_pending_chunks_by_focus() -> void:
	var focus := world_rect.get_center()
	if player != null and is_instance_valid(player):
		focus = player.global_position
	elif camera != null and is_instance_valid(camera):
		focus = camera.global_position
	var focus_chunk := _world_to_chunk(focus)
	pending_focus_chunk = focus_chunk
	pending_chunks.sort_custom(Callable(self, "_compare_chunk_focus"))

func _compare_chunk_focus(a, b) -> bool:
	var chunk_a := Vector2i(a)
	var chunk_b := Vector2i(b)
	var da := _chunk_distance_sq(chunk_a, pending_focus_chunk)
	var db := _chunk_distance_sq(chunk_b, pending_focus_chunk)
	return da < db

func _count_active_stage(stage_name: String) -> int:
	var count := 0
	for state_value in active_builds.values():
		var state := Dictionary(state_value)
		if str(state.get("stage", "preview")) == stage_name:
			count += 1
	return count


func _get_chunk_state_counts() -> Dictionary:
	var counts := {
		"EMPTY": 0,
		"PREVIEW_QUEUED": 0,
		"PREVIEW_BUILDING": 0,
		"PREVIEW_READY": 0,
		"REFINE_BUILDING": 0,
		"REFINED_READY": 0,
		"FAILED": 0,
		"STALE": 0,
	}
	for state_value in chunk_states.values():
		match int(state_value):
			ChunkState.EMPTY:          counts["EMPTY"] += 1
			ChunkState.PREVIEW_QUEUED: counts["PREVIEW_QUEUED"] += 1
			ChunkState.PREVIEW_BUILDING: counts["PREVIEW_BUILDING"] += 1
			ChunkState.PREVIEW_READY:  counts["PREVIEW_READY"] += 1
			ChunkState.REFINE_BUILDING: counts["REFINE_BUILDING"] += 1
			ChunkState.REFINED_READY:  counts["REFINED_READY"] += 1
			ChunkState.FAILED:         counts["FAILED"] += 1
			ChunkState.STALE:          counts["STALE"] += 1
	return counts

func _count_active_work_stages() -> int:
	var count := 0
	for state_value in active_builds.values():
		var state := Dictionary(state_value)
		var stage_name := str(state.get("stage", "preview"))
		if stage_name == "preview" or stage_name == "refine":
			count += 1
	return count

func _get_active_build_keys_by_priority() -> Array:
	var preview_keys: Array = []
	var refine_keys: Array = []
	var pending_keys: Array = []
	for key_value in active_builds.keys():
		var chunk_key := Vector2i(key_value)
		var state := Dictionary(active_builds.get(chunk_key, {}))
		match str(state.get("stage", "preview")):
			"preview":
				preview_keys.append(chunk_key)
			"refine":
				refine_keys.append(chunk_key)
			_:
				pending_keys.append(chunk_key)
	preview_keys.sort_custom(Callable(self, "_compare_chunk_focus"))
	refine_keys.sort_custom(Callable(self, "_compare_chunk_focus"))
	pending_keys.sort_custom(Callable(self, "_compare_chunk_focus"))
	var result: Array = []
	result.append_array(preview_keys)
	result.append_array(refine_keys)
	result.append_array(pending_keys)
	return result

func _get_stage_batch_size(stage: String) -> int:
	if stage == "preview":
		return preview_build_cell_batch_size
	return refined_build_cell_batch_size_current

func _get_missing_visible_texture_count() -> int:
	var missing := 0
	for key_value in visible_chunks.keys():
		if not chunk_textures.has(Vector2i(key_value)):
			missing += 1
	return missing

func _start_chunk_build(chunk_key: Vector2i) -> void:
	if active_builds.has(chunk_key):
		return
	var initial_texture_size := preview_chunk_texture_size if preview_enabled else refined_chunk_texture_size
	var image := Image.create(initial_texture_size, initial_texture_size, false, Image.FORMAT_RGBA8)
	active_builds[chunk_key] = {
		"chunk_key": chunk_key,
		"image": image,
		"chunk_rect": _get_chunk_world_rect(chunk_key),
		"next_y": 0,
		"stage": "preview" if preview_enabled else "refine",
		"texture_size": initial_texture_size,
		"stage_ready_at": 0.0
	}
	chunk_build_started_count += 1
	chunk_states[chunk_key] = ChunkState.PREVIEW_BUILDING if preview_enabled else ChunkState.REFINE_BUILDING

func _process_active_chunk_build(chunk_key: Vector2i, frame_start_usec: int, allow_refine := true, hard_budget_deadline_usec := 9223372036854775807) -> void:
	if not active_builds.has(chunk_key):
		return
	
	var state := Dictionary(active_builds[chunk_key])
	var chunk_rect = Rect2(state.get("chunk_rect", Rect2()))
	var next_y := int(state.get("next_y", 0))
	var next_x := int(state.get("next_x", 0))
	var stage := str(state.get("stage", "preview"))
	if stage == "preview":
		if not preview_build_watchdog_start_ms.has(chunk_key):
			preview_build_watchdog_start_ms[chunk_key] = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - int(preview_build_watchdog_start_ms[chunk_key]) >= 10000:
			state["stage"] = "refine_pending"
			state["stage_ready_at"] = float(Time.get_ticks_msec()) / 1000.0
			state["image"] = null
			state["next_y"] = 0
			state["next_x"] = 0
			active_builds[chunk_key] = state
			chunk_states[chunk_key] = ChunkState.PREVIEW_READY
			refine_jobs_stale += 1
			preview_build_watchdog_start_ms.erase(chunk_key)
			return

	# Handle refine_pending stage transition to refine FIRST (before null check)
	if stage == "refine_pending":
		if allow_refine:
			var ready_at := float(state.get("stage_ready_at", 0.0))
			var now_s := float(Time.get_ticks_msec()) / 1000.0
			if now_s >= ready_at and _can_start_refine_chunk(allow_refine):
				var refine_texture_size := refined_chunk_texture_size
				var refine_image := Image.create(refine_texture_size, refine_texture_size, false, Image.FORMAT_RGBA8)
				state["image"] = refine_image
				state["next_y"] = 0
				state["next_x"] = 0
				state["stage"] = "refine"
				state["texture_size"] = refine_texture_size
				state["refine_started_at"] = Time.get_ticks_msec()
				stage = "refine"
				next_y = 0
				next_x = 0
				refine_jobs_started += 1
				terrain_surface_last_refine_started_ms = Time.get_ticks_msec()
				terrain_surface_refine_blocked_reason = ""
				active_builds[chunk_key] = state
				chunk_states[chunk_key] = ChunkState.REFINE_BUILDING
		# If not ready to transition, just update and return early
		return
	
	var image: Image = state.get("image")
	if image == null:
		# Incomplete state, remove it
		if stage == "refine":
			refine_jobs_cancelled += 1
		active_builds.erase(chunk_key)
		return
	
	var texture_size := int(state.get("texture_size", image.get_width()))
	if texture_size <= 0:
		texture_size = image.get_width()
	texture_size = min(min(texture_size, image.get_width()), image.get_height())
	
	var rows_per_frame := preview_max_chunks_built_per_frame if stage == "preview" else refined_max_rows_built_per_frame
	var build_budget_usec := int(max_build_ms_per_frame * 1000.0)
	var rows_done := 0
	
	# Main build loop with incremental budget checking
	while next_y < texture_size and rows_done < rows_per_frame:
		var now_usec := Time.get_ticks_usec()
		if now_usec >= hard_budget_deadline_usec or now_usec - frame_start_usec >= build_budget_usec:
			break
		
		# Check if next batch would exceed budget BEFORE executing it
		var batch_size := _get_stage_batch_size(stage)
		var batch_end_x := mini(next_x + batch_size, texture_size)
		var pixels_to_process := batch_end_x - next_x
		
		# Estimate if this batch will fit in budget (rough estimate)
		var avg_us_per_pixel := 2.0  # Empirical average from profiling
		var estimated_batch_us := int(float(pixels_to_process) * avg_us_per_pixel)
		var time_remaining_usec := build_budget_usec - (now_usec - frame_start_usec)
		
		if estimated_batch_us > time_remaining_usec:
			# This batch will likely exceed budget, stop early
			break
		
		var step_start_usec: int = now_usec
		
		# Execute the batch
		if stage == "preview":
			_build_preview_chunk_texture_span(image, chunk_rect, next_y, next_x, batch_end_x, texture_size)
		else:
			_build_chunk_texture_span(image, chunk_rect, next_y, next_x, batch_end_x, texture_size)
		
		var step_ms := float(Time.get_ticks_usec() - step_start_usec) / 1000.0
		terrain_surface_build_steps_last_frame += 1
		terrain_surface_build_pixels_last_frame += pixels_to_process
		
		if step_ms > max_build_ms_per_frame:
			terrain_surface_build_soft_budget_exceeded_count += 1
			terrain_surface_build_budget_exceeded_count += 1
			terrain_surface_build_budget_max_overrun_ms = maxf(terrain_surface_build_budget_max_overrun_ms, step_ms - max_build_ms_per_frame)
			if stage != "preview":
				refined_build_cell_batch_size_current = maxi(int(floor(float(refined_build_cell_batch_size_current) * 0.5)), 4)
		elif step_ms > hard_budget_ms:
			terrain_surface_build_hard_budget_exceeded_count += 1
		
		next_x = batch_end_x
		if next_x >= texture_size:
			next_x = 0
			next_y += 1
			rows_done += 1
			terrain_surface_build_rows_last_frame += 1
		
		now_usec = Time.get_ticks_usec()
		if now_usec >= hard_budget_deadline_usec or now_usec - frame_start_usec >= build_budget_usec:
			break
	
	# Check if this stage is complete
	if next_y >= texture_size:
		if stage == "preview":
			if terrain_surface_preview_time_to_first_chunk_ms <= 0.0:
				terrain_surface_preview_time_to_first_chunk_ms = float(Time.get_ticks_msec() - terrain_surface_first_preview_started_ms)
			var preview_texture := ImageTexture.create_from_image(image)
			chunk_textures[chunk_key] = preview_texture
			state["stage"] = "refine_pending"
			state["stage_ready_at"] = float(Time.get_ticks_msec()) / 1000.0 + refine_delay_seconds
			state["image"] = null
			state["next_y"] = 0
			state["next_x"] = 0
			active_builds[chunk_key] = state
			chunk_states[chunk_key] = ChunkState.PREVIEW_READY
			preview_build_watchdog_start_ms.erase(chunk_key)
			preview_chunks_built_last_frame += 1
			preview_build_count += 1
			preview_chunk_count = chunk_textures.size()
			if terrain_surface_preview_time_to_visible_coverage_ms <= 0.0 and _get_missing_visible_texture_count() == 0:
				terrain_surface_preview_time_to_visible_coverage_ms = float(Time.get_ticks_msec() - terrain_surface_first_preview_started_ms)
			queue_redraw()
		else:  # stage == "refine"
			var refined_texture := ImageTexture.create_from_image(image)
			chunk_textures[chunk_key] = refined_texture
			active_builds.erase(chunk_key)
			chunk_states[chunk_key] = ChunkState.REFINED_READY
			chunks_built_last_frame += 1
			refined_chunks_built_last_frame += 1
			terrain_surface_build_chunks_completed_last_frame += 1
			total_build_count += 1
			refined_build_count += 1
			smoke_test_last_refined_count = refined_build_count
			smoke_test_last_refine_progress_ms = Time.get_ticks_msec()
			chunk_build_completed_count += 1
			refine_jobs_completed += 1
			sample_cache.clear()
			refined_chunk_count = chunk_textures.size()
			refined_build_cell_batch_size_current = mini(refined_build_cell_batch_size, refined_build_cell_batch_size_current + 1)
			queue_redraw()
	else:
		# Partial progress, save state
		state["next_y"] = next_y
		state["next_x"] = next_x
		active_builds[chunk_key] = state


func _can_process_refine() -> bool:
	if not terrain_surface_refine_enabled:
		terrain_surface_refine_blocked_reason = terrain_surface_refine_disabled_reason
		return false
	var camera_moving_fast := _is_camera_moving_fast()
	if preview_only_during_fast_movement and refine_pause_when_camera_moving and camera_moving_fast:
		terrain_surface_refine_blocked_reason = "camera_moving"
		terrain_surface_refine_skipped_due_to_camera_movement_count += 1
		return false
	var fps := Engine.get_frames_per_second()
	if refine_pause_when_fps_below > 0 and fps > 0 and fps < refine_pause_when_fps_below:
		terrain_surface_refine_blocked_reason = "fps_below_threshold"
		if smoke_test_idle_duration_ms >= refine_idle_grace_period_ms:
			var now_ms := Time.get_ticks_msec()
			if last_refine_idle_allow_ms == 0 or now_ms - last_refine_idle_allow_ms >= refine_idle_min_interval_ms:
				last_refine_idle_allow_ms = now_ms
				terrain_surface_last_refine_allowed_ms = now_ms
				terrain_surface_refine_blocked_reason = ""
				return true
		terrain_surface_refine_skipped_due_to_fps_count += 1
		return false
	if max_refined_chunks_per_second <= 0:
		terrain_surface_refine_blocked_reason = ""
		terrain_surface_last_refine_allowed_ms = Time.get_ticks_msec()
		return true
	var now_ms := Time.get_ticks_msec()
	if now_ms - refined_chunk_window_start_ms >= 1000:
		refined_chunk_window_start_ms = now_ms
		refined_chunks_started_in_window = 0
	if refined_chunks_started_in_window >= max_refined_chunks_per_second:
		terrain_surface_refine_blocked_reason = "rate_limited"
		return false
	terrain_surface_refine_blocked_reason = ""
	terrain_surface_last_refine_allowed_ms = now_ms
	return true


func _can_start_refine_chunk(allow_refine: bool) -> bool:
	if not allow_refine:
		return false
	refined_chunks_started_in_window += 1
	return true


func _is_camera_moving_fast() -> bool:
	var current_position := _get_motion_sample_position()
	if last_motion_sample_position == Vector2.INF:
		last_motion_sample_position = current_position
		return false
	var move_distance := current_position.distance_to(last_motion_sample_position)
	last_motion_sample_position = current_position
	var threshold := maxf(chunk_world_size * 0.25, 96.0)
	return move_distance >= threshold


func _get_motion_sample_position() -> Vector2:
	if camera != null and is_instance_valid(camera):
		return camera.global_position
	if player != null and is_instance_valid(player):
		return player.global_position
	return world_rect.get_center()


func _get_actual_camera_world_rect() -> Rect2:
	if camera != null and is_instance_valid(camera):
		var viewport := get_viewport()
		var viewport_size := viewport.get_visible_rect().size if viewport != null else Vector2(1920.0, 1080.0)
		var zoom := camera.zoom if camera.zoom != Vector2.ZERO else Vector2.ONE
		var safe_zoom := Vector2(maxf(absf(zoom.x), 0.01), maxf(absf(zoom.y), 0.01))
		var half_size := Vector2(viewport_size.x / safe_zoom.x, viewport_size.y / safe_zoom.y) * 0.5
		return Rect2(camera.global_position - half_size, half_size * 2.0)
	if player != null and is_instance_valid(player):
		return Rect2(player.global_position - Vector2(960.0, 540.0), Vector2(1920.0, 1080.0))
	return world_rect

func _build_chunk_texture_span(image: Image, chunk_rect: Rect2, y: int, start_x: int, end_x: int, texture_size: int) -> void:
	if image == null:
		return
	var safe_texture_size: int = texture_size
	safe_texture_size = mini(safe_texture_size, image.get_width())
	safe_texture_size = mini(safe_texture_size, image.get_height())
	if y < 0 or y >= safe_texture_size:
		return
	var safe_start_x := maxi(start_x, 0)
	var safe_end_x := mini(end_x, safe_texture_size)
	for x in range(safe_start_x, safe_end_x):
		var uv := Vector2(
			(float(x) + 0.5) / float(safe_texture_size),
			(float(y) + 0.5) / float(safe_texture_size)
		)
		var world_pos := chunk_rect.position + Vector2(chunk_rect.size.x * uv.x, chunk_rect.size.y * uv.y)
		image.set_pixel(x, y, _sample_surface_color(world_pos))

func _build_preview_chunk_texture_span(image: Image, chunk_rect: Rect2, y: int, start_x: int, end_x: int, texture_size: int) -> void:
	if image == null:
		return
	var safe_texture_size: int = texture_size
	safe_texture_size = mini(safe_texture_size, image.get_width())
	safe_texture_size = mini(safe_texture_size, image.get_height())
	if y < 0 or y >= safe_texture_size:
		return
	var safe_start_x := maxi(start_x, 0)
	var safe_end_x := mini(end_x, safe_texture_size)
	for x in range(safe_start_x, safe_end_x):
		var uv := Vector2(
			(float(x) + 0.5) / float(safe_texture_size),
			(float(y) + 0.5) / float(safe_texture_size)
		)
		var world_pos := chunk_rect.position + Vector2(chunk_rect.size.x * uv.x, chunk_rect.size.y * uv.y)
		image.set_pixel(x, y, _sample_preview_surface_color(world_pos))

func _sample_preview_surface_color(world_pos: Vector2) -> Color:
	var surface := _sample_surface_ids(world_pos)
	var base := _get_base_surface_color(str(surface.get("biome_id", "hearth_meadow")), str(surface.get("terrain_id", "land")))
	base = _apply_topography_soft_blend(base, str(surface.get("biome_id", "hearth_meadow")), str(surface.get("terrain_id", "land")), world_pos)
	base = _apply_biome_influence_soft_blend(base, str(surface.get("biome_id", "hearth_meadow")), str(surface.get("terrain_id", "land")), world_pos)
	var noise := _value_noise(world_pos * 0.004, 71) * 0.035
	return base.lightened(noise) if noise >= 0.0 else base.darkened(absf(noise))

func _sample_surface_color(world_pos: Vector2) -> Color:
	var base := _sample_surface_color_single(world_pos)
	if bool(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_edge_supersampling_enabled", true)):
		var radius := maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_edge_supersample_radius", 6.0)), 0.0)
		var sample_count := maxi(int(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_edge_supersample_count", 5)), 1)
		var sample_points: Array[Vector2] = [world_pos]
		for i in range(sample_count - 1):
			var angle := TAU * float(i) / float(maxi(sample_count - 1, 1))
			sample_points.append(world_pos + Vector2(cos(angle), sin(angle)) * radius)
		var mixed := Color(0.0, 0.0, 0.0, 0.0)
		for sample_point in sample_points:
			mixed += _sample_surface_color_single(sample_point)
		base = mixed / float(sample_points.size())
	if bool(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_noise_enabled", true)):
		var surface := _sample_surface_ids(world_pos)
		base = _apply_topography_soft_blend(base, str(surface.get("biome_id", "hearth_meadow")), str(surface.get("terrain_id", "land")), world_pos)
		base = _apply_biome_influence_soft_blend(base, str(surface.get("biome_id", "hearth_meadow")), str(surface.get("terrain_id", "land")), world_pos)
		base = _apply_surface_variation(base, str(surface.get("biome_id", "hearth_meadow")), str(surface.get("terrain_id", "land")), world_pos)
	if bool(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_transition_enabled", false)):
		var transition_surface := _sample_surface_ids(world_pos)
		return _apply_local_transition(base, str(transition_surface.get("biome_id", "hearth_meadow")), str(transition_surface.get("terrain_id", "land")), world_pos)
	return base

func _sample_surface_color_single(world_pos: Vector2) -> Color:
	var cache_enabled := bool(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_sample_cache_enabled", false))
	var cache_step := maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_sample_cache_step", 8.0)), 4.0)
	var terrain_id := ""
	var biome_id := ""
	if cache_enabled:
		var cache_key := "%d,%d" % [int(floor(world_pos.x / cache_step)), int(floor(world_pos.y / cache_step))]
		if sample_cache.has(cache_key):
			var cached := Dictionary(sample_cache[cache_key])
			terrain_id = str(cached.get("terrain_id", "land"))
			biome_id = str(cached.get("biome_id", "hearth_meadow"))
		else:
			var surface := _sample_surface_ids(world_pos)
			var source := str(surface.get("source", "unknown"))
			surface_sample_source_counts[source] = int(surface_sample_source_counts.get(source, 0)) + 1
			terrain_id = str(surface.get("terrain_id", "land"))
			biome_id = str(surface.get("biome_id", "hearth_meadow"))
			sample_cache[cache_key] = {
				"terrain_id": terrain_id,
				"biome_id": biome_id
			}
	else:
		var surface := _sample_surface_ids(world_pos)
		var source := str(surface.get("source", "unknown"))
		surface_sample_source_counts[source] = int(surface_sample_source_counts.get(source, 0)) + 1
		terrain_id = str(surface.get("terrain_id", "land"))
		biome_id = str(surface.get("biome_id", "hearth_meadow"))
	var base := _get_base_surface_color(biome_id, terrain_id)
	return base

func _sample_surface_ids(world_pos: Vector2) -> Dictionary:
	var use_shape_map_sampling := bool(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_use_shape_map_sampling", false))
	if has_use_shape_map_sampling_override:
		use_shape_map_sampling = use_shape_map_sampling_override
	if use_shape_map_sampling and biome_shape_map != null and biome_shape_map.has_method("sample_visual_surface_at"):
		if bool(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_use_exact_shape_sampling", true)) and biome_shape_map.has_method("sample_visual_surface_exact_at"):
			var exact_surface := Dictionary(biome_shape_map.sample_visual_surface_exact_at(world_pos))
			if not exact_surface.is_empty():
				var exact_source := str(exact_surface.get("source", "unknown"))
				if exact_source.begins_with("exact_polygon"):
					exact_surface_sample_count += 1
				elif exact_source.find("grid") != -1:
					grid_surface_sample_count += 1
				elif exact_source == "world_fallback":
					world_fallback_surface_sample_count += 1
				return exact_surface
		var surface := Dictionary(biome_shape_map.sample_visual_surface_at(world_pos))
		if not surface.is_empty():
			var source := str(surface.get("source", "unknown"))
			if source.begins_with("exact_polygon"):
				exact_surface_sample_count += 1
			elif source.find("grid") != -1:
				grid_surface_sample_count += 1
			elif source == "world_fallback":
				world_fallback_surface_sample_count += 1
			return surface
	world_fallback_surface_sample_count += 1
	return {
		"terrain_id": _get_surface_terrain(world_pos),
		"biome_id": _get_visual_biome(world_pos),
		"layer_id": "",
		"source": "world_fallback"
	}

func _get_visual_biome(world_pos: Vector2) -> String:
	if world != null and world.has_method("get_visual_biome_id_at"):
		return str(world.get_visual_biome_id_at(world_pos))
	if world != null and world.has_method("get_biome_id_at"):
		return str(world.get_biome_id_at(world_pos))
	return "hearth_meadow"

func _get_surface_terrain(world_pos: Vector2) -> String:
	if world != null and world.has_method("get_surface_terrain_zone_at"):
		return str(world.get_surface_terrain_zone_at(world_pos))
	if world != null and world.has_method("get_generator_base_terrain_zone_at"):
		return str(world.get_generator_base_terrain_zone_at(world_pos))
	return "land"

func _get_base_surface_color(biome_id: String, terrain_id: String) -> Color:
	match terrain_id:
		"deep_ocean":
			return Color(0.045, 0.145, 0.31)
		"shallow_water":
			return Color(0.07, 0.27, 0.43)
		"shore":
			return Color(0.70, 0.65, 0.42)
		"pond":
			return Color(0.06, 0.29, 0.38)
		"highland":
			return _get_biome_color(biome_id).lerp(Color(0.52, 0.48, 0.34), 0.34)
		"rocky_patch":
			return _get_biome_color(biome_id).lerp(Color(0.44, 0.42, 0.35), 0.42)
		"wetland":
			return _get_biome_color(biome_id).lerp(Color(0.13, 0.27, 0.18), 0.35)
		_:
			return _get_biome_color(biome_id)

func _get_biome_color(biome_id: String) -> Color:
	match biome_id:
		"westwood":
			return Color(0.16, 0.35, 0.17)
		"stoneback_ridge":
			return Color(0.50, 0.46, 0.36)
		"hearth_meadow":
			return Color(0.39, 0.58, 0.27)
		"south_thicket":
			return Color(0.23, 0.43, 0.18)
		"redfang_wilds":
			return Color(0.48, 0.27, 0.19)
		_:
			return Color(0.34, 0.51, 0.25)

func _apply_surface_variation(color: Color, biome_id: String, terrain_id: String, world_pos: Vector2) -> Color:
	if terrain_id in ["deep_ocean", "shallow_water", "pond"]:
		var water_wave := _value_noise(world_pos * 0.012, 41) * 0.035
		return color.lightened(water_wave)
	var low := _value_noise(world_pos * 0.0028, 11)
	var detail := _value_noise(world_pos * 0.018, 23)
	var strength := float(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_noise_strength", 0.08))
	var detail_strength := float(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_detail_noise_strength", 0.055))
	var amount := (low - 0.5) * strength + (detail - 0.5) * detail_strength
	match biome_id:
		"westwood":
			amount -= 0.025 * _value_noise(world_pos * 0.010, 31)
			if _detail_mask(world_pos, 0.035, 103, 0.68) > 0.0:
				amount -= 0.05
		"hearth_meadow":
			amount += 0.025 * _value_noise(world_pos * 0.014, 37)
			if _detail_mask(world_pos, 0.045, 101, 0.72) > 0.0:
				amount += 0.04
		"south_thicket":
			amount -= 0.035 * _value_noise(world_pos * 0.020, 43)
			if _detail_mask(world_pos, 0.050, 107, 0.64) > 0.0:
				amount -= 0.06
		"redfang_wilds":
			amount += 0.030 * _value_noise(world_pos * 0.011, 47)
			if _detail_mask(world_pos, 0.040, 109, 0.70) > 0.0:
				amount += 0.045
		"stoneback_ridge":
			amount += 0.020 * _value_noise(world_pos * 0.030, 53)
			if _detail_mask(world_pos, 0.060, 113, 0.66) > 0.0:
				amount += 0.05
	if amount >= 0.0:
		return color.lightened(amount)
	return color.darkened(absf(amount))

func _apply_topography_soft_blend(color: Color, biome_id: String, terrain_id: String, world_pos: Vector2) -> Color:
	if world == null or not world.has_method("get_topography_sample_at"):
		return color
	var topo_sample := Dictionary(world.get_topography_sample_at(world_pos))
	if topo_sample.is_empty():
		return color
	var pond_influence := float(topo_sample.get("best_pond_influence", topo_sample.get("pond_influence", 0.0)))
	var shore_threshold := float(GAME_BALANCE.LANDMARKS.get("topography_pond_shore_threshold", 0.46))
	var shallow_threshold := float(GAME_BALANCE.LANDMARKS.get("topography_pond_shallow_threshold", 0.56))
	var deep_threshold := float(GAME_BALANCE.LANDMARKS.get("topography_pond_deep_threshold", 0.70))
	var edge_start := maxf(shore_threshold - 0.10, 0.0)
	var edge_end := minf(shallow_threshold + 0.06, 1.0)
	if pond_influence <= edge_start:
		return color
	var edge_mix := clampf(inverse_lerp(edge_start, edge_end, pond_influence), 0.0, 1.0)
	var pond_color := _get_base_surface_color(biome_id, "pond")
	if pond_influence >= deep_threshold:
		pond_color = _get_base_surface_color(biome_id, "deep_ocean")
	elif pond_influence >= shallow_threshold:
		pond_color = _get_base_surface_color(biome_id, "shallow_water")
	return color.lerp(pond_color, edge_mix * 0.78 if terrain_id != "pond" else edge_mix * 0.42)


func _apply_biome_influence_soft_blend(color: Color, biome_id: String, terrain_id: String, world_pos: Vector2) -> Color:
	if terrain_id in ["deep_ocean", "shallow_water", "shore", "pond"]:
		return color
	if world == null or not world.has_method("get_visual_biome_influence_scores_at"):
		return color
	var cache_step := maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_sample_cache_step", 8.0)) * 2.0, 24.0)
	var cache_key := "%d,%d" % [int(floor(world_pos.x / cache_step)), int(floor(world_pos.y / cache_step))]
	var cached_blend := Dictionary(biome_blend_cache.get(cache_key, {}))
	if cached_blend.is_empty():
		var scores := Dictionary(world.get_visual_biome_influence_scores_at(world_pos))
		if scores.is_empty():
			biome_blend_cache[cache_key] = {"blend": 0.0, "secondary_biome_id": biome_id}
			return color
		var primary_score := float(scores.get(biome_id, -INF))
		if primary_score <= -INF:
			biome_blend_cache[cache_key] = {"blend": 0.0, "secondary_biome_id": biome_id}
			return color
		var secondary_score := -INF
		var secondary_biome_id := biome_id
		for key_value in scores.keys():
			var candidate_id := str(key_value)
			if candidate_id == biome_id:
				continue
			var candidate_score := float(scores.get(candidate_id, -INF))
			if candidate_score > secondary_score:
				secondary_score = candidate_score
				secondary_biome_id = candidate_id
		if secondary_biome_id == biome_id or secondary_score <= -INF:
			biome_blend_cache[cache_key] = {"blend": 0.0, "secondary_biome_id": biome_id}
			return color
		var margin := primary_score - secondary_score
		var blend_width := maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_biome_blend_width", 0.32)), 0.04)
		var blend_strength := clampf(1.0 - margin / blend_width, 0.0, 1.0)
		blend_strength = smoothstep(0.0, 1.0, blend_strength)
		cached_blend = {
			"blend": blend_strength,
			"secondary_biome_id": secondary_biome_id
		}
		biome_blend_cache[cache_key] = cached_blend
	var blend := float(cached_blend.get("blend", 0.0))
	var secondary_biome_id := str(cached_blend.get("secondary_biome_id", biome_id))
	if blend <= 0.001 or secondary_biome_id.is_empty() or secondary_biome_id == biome_id:
		return color
	var secondary_color := _get_base_surface_color(secondary_biome_id, terrain_id)
	var max_blend := clampf(float(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_biome_blend_strength", 0.34)), 0.0, 0.6)
	return color.lerp(secondary_color, blend * max_blend)

func _detail_mask(world_pos: Vector2, scale: float, salt: int, threshold: float) -> float:
	var n := _value_noise(world_pos * scale, salt)
	return 1.0 if n > threshold else 0.0

func _apply_local_transition(color: Color, biome_id: String, terrain_id: String, world_pos: Vector2) -> Color:
	var sample_distance := float(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_transition_sample_distance", 96.0))
	var transition_strength := float(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_transition_strength", 0.18))
	if transition_strength <= 0.0:
		return color
	var neighbor_positions := [
		world_pos + Vector2(sample_distance, 0.0),
		world_pos + Vector2(-sample_distance, 0.0),
		world_pos + Vector2(0.0, sample_distance),
		world_pos + Vector2(0.0, -sample_distance)
	]
	var mixed := color
	var diff_count := 0
	for pos in neighbor_positions:
		var neighbor_surface := _sample_surface_ids(pos)
		var neighbor_terrain := str(neighbor_surface.get("terrain_id", "land"))
		var neighbor_biome := str(neighbor_surface.get("biome_id", "hearth_meadow"))
		if neighbor_terrain != terrain_id or neighbor_biome != biome_id:
			mixed = mixed.lerp(_get_base_surface_color(neighbor_biome, neighbor_terrain), transition_strength)
			diff_count += 1
	if diff_count == 0:
		return color
	return color.lerp(mixed, clampf(float(diff_count) / 4.0, 0.0, 1.0))

func _value_noise(v: Vector2, salt: int) -> float:
	var x0 := int(floor(v.x))
	var y0 := int(floor(v.y))
	var fx := v.x - float(x0)
	var fy := v.y - float(y0)
	var a := _hash_float(x0, y0, salt)
	var b := _hash_float(x0 + 1, y0, salt)
	var c := _hash_float(x0, y0 + 1, salt)
	var d := _hash_float(x0 + 1, y0 + 1, salt)
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uy := fy * fy * (3.0 - 2.0 * fy)
	return lerpf(lerpf(a, b, ux), lerpf(c, d, ux), uy)

func _hash_float(x: int, y: int, salt: int) -> float:
	var n := int(x * 374761393 + y * 668265263 + salt * 1442695041)
	if world != null and world.has_method("get_world_seed"):
		n += int(world.get_world_seed()) * 982451653
	n = int((n ^ (n >> 13)) * 1274126177)
	n = n ^ (n >> 16)
	return float(abs(n % 10000)) / 10000.0

func _get_visible_world_rect() -> Rect2:
	if camera != null and is_instance_valid(camera):
		var viewport_size := get_viewport_rect().size
		var zoom := camera.zoom if camera.zoom != Vector2.ZERO else Vector2.ONE
		var safe_zoom := Vector2(maxf(absf(zoom.x), 0.01), maxf(absf(zoom.y), 0.01))
		var half_size := Vector2(viewport_size.x / safe_zoom.x, viewport_size.y / safe_zoom.y) * 0.5
		return Rect2(camera.global_position - half_size, half_size * 2.0).grow(chunk_world_size * float(visible_margin_chunks))
	if player != null and is_instance_valid(player):
		return Rect2(player.global_position - Vector2(960.0, 540.0), Vector2(1920.0, 1080.0)).grow(chunk_world_size * float(visible_margin_chunks))
	return world_rect

func _get_chunk_bounds_for_rect(rect: Rect2) -> Rect2i:
	var start_x := int(floor((rect.position.x - world_rect.position.x) / chunk_world_size))
	var end_x := int(floor((rect.end.x - world_rect.position.x) / chunk_world_size))
	var start_y := int(floor((rect.position.y - world_rect.position.y) / chunk_world_size))
	var end_y := int(floor((rect.end.y - world_rect.position.y) / chunk_world_size))
	var min_chunk := _world_to_chunk(world_rect.position)
	var max_chunk := _world_to_chunk(world_rect.end - Vector2.ONE)
	start_x = clampi(start_x, min_chunk.x, max_chunk.x)
	end_x = clampi(end_x, min_chunk.x, max_chunk.x)
	start_y = clampi(start_y, min_chunk.y, max_chunk.y)
	end_y = clampi(end_y, min_chunk.y, max_chunk.y)
	return Rect2i(Vector2i(start_x, start_y), Vector2i(end_x - start_x + 1, end_y - start_y + 1))

func _world_to_chunk(pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor((pos.x - world_rect.position.x) / chunk_world_size)),
		int(floor((pos.y - world_rect.position.y) / chunk_world_size))
	)

func _get_chunk_world_rect(chunk_key: Vector2i) -> Rect2:
	return Rect2(world_rect.position + Vector2(float(chunk_key.x) * chunk_world_size, float(chunk_key.y) * chunk_world_size), Vector2(chunk_world_size, chunk_world_size))

func _chunk_bounds_signature(bounds: Rect2i) -> String:
	return "%d,%d,%d,%d" % [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]

func _draw_chunk_placeholder(chunk_key: Vector2i) -> void:
	var alpha := float(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_placeholder_alpha", 0.0))
	if alpha <= 0.0:
		return
	draw_rect(_get_chunk_world_rect(chunk_key), Color(0.08, 0.18, 0.11, alpha), true)

func _chunk_distance_sq(a: Vector2i, b: Vector2i) -> int:
	var dx := a.x - b.x
	var dy := a.y - b.y
	return dx * dx + dy * dy
