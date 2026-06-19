extends Node2D
class_name VegetationVisualLayer

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const RUNTIME_PROFILER := preload("res://scripts/debug/runtime_profiler.gd")

const DEFAULT_GRASS_RADIUS := 5.0
const DEFAULT_DENSE_GRASS_RADIUS := 8.0
const DEFAULT_CHUNK_SIZE := 768.0
const DEFAULT_VISIBILITY_MARGIN := 128.0
const MAX_DRAWN_DECORATIVE_GRASS_INSTANCES := 280
const LOW_END_MAX_DRAWN_DECORATIVE_GRASS_INSTANCES := 160
const VISIBILITY_CENTER_MOVE_THRESHOLD := 96.0
const GRASS_LOD_NEAR_DISTANCE := 360.0
const GRASS_LOD_MID_DISTANCE := 760.0
const GRASS_NEAR_BLADE_COUNT := 6
const GRASS_MID_BLADE_COUNT := 3
const GRASS_FAR_DRAW_EVERY_NTH := 2
const LOD_NEAR := 0
const LOD_MID := 1
const LOD_FAR := 2

var instances: Array[Dictionary] = []
var count_by_kind: Dictionary = {}
var instances_by_chunk: Dictionary = {}
var chunk_size := DEFAULT_CHUNK_SIZE
var visible_world_rect := Rect2()
var has_visible_world_rect := false
var drawn_instance_count := 0
var total_visible_instance_count := 0
var visible_chunk_count := 0
var last_visible_chunk_signature := ""
var last_visible_rect_center := Vector2.INF
var last_visible_rect_size := Vector2.INF
var total_chunk_count := 0
var camera_focus_position := Vector2.ZERO
var has_camera_focus_position := false
var skipped_by_cap_count := 0
var skipped_by_far_lod_count := 0
var near_lod_count := 0
var mid_lod_count := 0
var far_lod_count := 0
var max_drawn_instances := MAX_DRAWN_DECORATIVE_GRASS_INSTANCES
var far_lod_every_nth := GRASS_FAR_DRAW_EVERY_NTH
var dirty := false
var _batch_depth := 0
var _batch_dirty := false
var _visible_candidate_cache: Array = []
var _visible_candidate_cache_key := ""
var _sorted_candidate_cache_key := ""
var _cached_draw_candidates: Array = []
var _cached_visible_chunk_signature := ""
var _cached_camera_focus_cell := Vector2i(2147483647, 2147483647)
var _cached_instances_version := -1
var _cached_quality_cap_version := -1
var _instances_version := 0
var _quality_cap_version := 0
var _draw_cache_dirty := true
var _redraw_reason := "initial"
var _bulk_add_depth := 0
var _bulk_add_request_redraw := false
var _queue_redraw_count := 0
var _bulk_redraw_count := 0
var _debug_stats: Dictionary = {
	"candidate_count_before_cap": 0,
	"drawn_instance_count": 0,
	"candidate_sort_ms": 0.0,
	"candidate_collect_ms": 0.0,
	"draw_loop_ms": 0.0,
	"draw_ms": 0.0,
	"redraw_reason": "initial",
	"draw_cache_rebuilt": false,
	"visible_chunk_signature": ""
}


func clear_instances() -> void:
	instances.clear()
	count_by_kind.clear()
	instances_by_chunk.clear()
	drawn_instance_count = 0
	total_visible_instance_count = 0
	visible_chunk_count = 0
	total_chunk_count = 0
	last_visible_chunk_signature = ""
	last_visible_rect_center = Vector2.INF
	last_visible_rect_size = Vector2.INF
	skipped_by_cap_count = 0
	skipped_by_far_lod_count = 0
	near_lod_count = 0
	mid_lod_count = 0
	far_lod_count = 0
	dirty = true
	_invalidate_visible_candidate_cache("clear_instances")
	_request_redraw_once()


func add_instance(kind: String, world_position: Vector2, radius: float = -1.0, biome_id: String = "", visual_scale: float = 1.0) -> void:
	var resolved_radius := radius
	if resolved_radius <= 0.0:
		resolved_radius = get_default_radius(kind)
	resolved_radius *= maxf(visual_scale, 0.1)
	var item := {
		"kind": kind,
		"position": world_position,
		"radius": resolved_radius,
		"biome_id": biome_id,
		"visual_scale": visual_scale,
		"seed": _make_seed(kind, world_position)
	}
	instances.append(item)
	count_by_kind[kind] = int(count_by_kind.get(kind, 0)) + 1
	var chunk_key := _get_chunk_key(world_position)
	if not instances_by_chunk.has(chunk_key):
		instances_by_chunk[chunk_key] = []
	var chunk_items: Array = Array(instances_by_chunk[chunk_key])
	chunk_items.append(item)
	instances_by_chunk[chunk_key] = chunk_items
	total_chunk_count = instances_by_chunk.size()
	_instances_version += 1
	dirty = true
	_invalidate_visible_candidate_cache("instance_added")
	_request_redraw_once()


func add_instance_no_redraw(kind: String, world_position: Vector2, radius: float = -1.0, biome_id: String = "", visual_scale: float = 1.0) -> void:
	var resolved_radius := radius
	if resolved_radius <= 0.0:
		resolved_radius = get_default_radius(kind)
	resolved_radius *= maxf(visual_scale, 0.1)
	var item := {
		"kind": kind,
		"position": world_position,
		"radius": resolved_radius,
		"biome_id": biome_id,
		"visual_scale": visual_scale,
		"seed": _make_seed(kind, world_position)
	}
	instances.append(item)
	count_by_kind[kind] = int(count_by_kind.get(kind, 0)) + 1
	var chunk_key := _get_chunk_key(world_position)
	if not instances_by_chunk.has(chunk_key):
		instances_by_chunk[chunk_key] = []
	var chunk_items: Array = Array(instances_by_chunk[chunk_key])
	chunk_items.append(item)
	instances_by_chunk[chunk_key] = chunk_items
	total_chunk_count = instances_by_chunk.size()
	_instances_version += 1
	dirty = true
	_draw_cache_dirty = true
	_redraw_reason = "instance_added"
	_request_redraw_once()


func add_instances(items: Array) -> void:
	begin_bulk_add()
	for item_value in items:
		var item := Dictionary(item_value)
		add_instance_no_redraw(
			str(item.get("kind", "grass_patch")),
			Vector2(item.get("position", Vector2.ZERO)),
			float(item.get("radius", -1.0)),
			str(item.get("biome_id", "")),
			float(item.get("visual_scale", 1.0))
		)
	end_bulk_add_queue_redraw_once()


func begin_bulk_add() -> void:
	_bulk_add_depth += 1


func end_bulk_add_queue_redraw_once() -> void:
	_bulk_add_depth = maxi(_bulk_add_depth - 1, 0)
	if _bulk_add_depth > 0:
		return
	if _bulk_add_request_redraw:
		_bulk_add_request_redraw = false
		_bulk_redraw_count += 1
		_invalidate_visible_candidate_cache("bulk_add_finished")
		queue_redraw()
	else:
		_invalidate_visible_candidate_cache("bulk_add_finished")


func begin_batch() -> void:
	begin_bulk_add()


func end_batch() -> void:
	end_bulk_add_queue_redraw_once()


func get_instance_count() -> int:
	return instances.size()


func get_count_by_kind() -> Dictionary:
	return count_by_kind.duplicate()


func set_visible_world_rect(world_rect: Rect2) -> void:
	var expanded_rect := world_rect.grow(DEFAULT_VISIBILITY_MARGIN)
	has_visible_world_rect = true
	var rect_changed := not visible_world_rect.has_area() or visible_world_rect.position != expanded_rect.position or visible_world_rect.size != expanded_rect.size
	visible_world_rect = expanded_rect
	var signature := _get_visible_chunk_signature(expanded_rect)
	var center := expanded_rect.get_center()
	var size := expanded_rect.size
	var center_moved := last_visible_rect_center == Vector2.INF or center.distance_to(last_visible_rect_center) >= VISIBILITY_CENTER_MOVE_THRESHOLD
	var size_changed := last_visible_rect_size == Vector2.INF or size != last_visible_rect_size
	if signature == last_visible_chunk_signature and not rect_changed and not center_moved and not size_changed:
		return
	last_visible_chunk_signature = signature
	last_visible_rect_center = center
	last_visible_rect_size = size
	_invalidate_visible_candidate_cache("visible_chunks_changed")
	_request_redraw_once()


func clear_visible_world_rect() -> void:
	has_visible_world_rect = false
	last_visible_chunk_signature = ""
	_invalidate_visible_candidate_cache("visible_chunks_cleared")
	_request_redraw_once()


func set_camera_focus_position(world_position: Vector2) -> void:
	var previous_cell := _get_camera_focus_cell()
	camera_focus_position = world_position
	has_camera_focus_position = true
	if _get_camera_focus_cell() != previous_cell:
		_invalidate_visible_candidate_cache("camera_cell_changed")


func set_max_drawn_instances(value: int) -> void:
	max_drawn_instances = maxi(value, 0)
	_quality_cap_version += 1
	_invalidate_visible_candidate_cache("quality_cap_changed")
	_request_redraw_once()


func apply_render_budget(budget: Dictionary) -> void:
	var next_max := int(budget.get("decorative_vegetation_max_drawn", max_drawn_instances))
	var next_far_nth := int(budget.get("decorative_far_lod_every_nth", GRASS_FAR_DRAW_EVERY_NTH))
	if next_max == max_drawn_instances and next_far_nth == far_lod_every_nth:
		return
	max_drawn_instances = next_max
	far_lod_every_nth = max(1, next_far_nth)
	_quality_cap_version += 1
	_invalidate_visible_candidate_cache("quality_cap_changed")
	_request_redraw_once()


func get_debug_stats() -> Dictionary:
	return {
		"visual_instance_count": instances.size(),
		"total_instance_count": instances.size(),
		"total_visual_instance_count": instances.size(),
		"drawn_instance_count": drawn_instance_count,
		"skipped_by_cap_count": skipped_by_cap_count,
		"skipped_by_far_lod_count": skipped_by_far_lod_count,
		"near_lod_count": near_lod_count,
		"mid_lod_count": mid_lod_count,
		"far_lod_count": far_lod_count,
		"visible_chunk_count": visible_chunk_count,
		"total_chunk_count": instances_by_chunk.size(),
		"count_by_kind": get_count_by_kind(),
		"has_visible_world_rect": has_visible_world_rect,
		"visible_world_rect": str(visible_world_rect),
		"max_drawn_instances": max_drawn_instances,
		"candidate_count_before_cap": int(_debug_stats.get("candidate_count_before_cap", 0)),
		"vegetation_candidate_count_before_cap": int(_debug_stats.get("candidate_count_before_cap", 0)),
		"candidate_sort_ms": float(_debug_stats.get("candidate_sort_ms", 0.0)),
		"candidate_collect_ms": float(_debug_stats.get("candidate_collect_ms", 0.0)),
		"draw_loop_ms": float(_debug_stats.get("draw_loop_ms", 0.0)),
		"draw_ms": float(_debug_stats.get("draw_ms", 0.0)),
		"redraw_reason": str(_debug_stats.get("redraw_reason", "cached")),
		"draw_cache_rebuilt": bool(_debug_stats.get("draw_cache_rebuilt", false)),
		"visible_chunk_signature": str(_debug_stats.get("visible_chunk_signature", "")),
		"vegetation_queue_redraw_count": _queue_redraw_count,
		"vegetation_bulk_redraw_count": _bulk_redraw_count,
		"vegetation_visible_chunk_count": visible_chunk_count,
		"vegetation_total_chunk_count": total_chunk_count
	}


func get_default_radius(kind: String) -> float:
	match kind:
		"dense_grass":
			return DEFAULT_DENSE_GRASS_RADIUS
		"grass_patch":
			return DEFAULT_GRASS_RADIUS
	return DEFAULT_GRASS_RADIUS


func _draw() -> void:
	var draw_start := Time.get_ticks_usec()
	_reset_draw_debug_counters()
	var profile_enabled := bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING)
	if profile_enabled:
		RUNTIME_PROFILER.begin_scope("vegetation_draw_total_ms")
	var visible_chunk_signature := last_visible_chunk_signature if has_visible_world_rect else _get_visible_chunk_signature(visible_world_rect)
	var camera_focus_cell := _get_camera_focus_cell()
	var should_rebuild := _should_rebuild_draw_cache(visible_chunk_signature, camera_focus_cell)
	if should_rebuild:
		_rebuild_draw_candidates(visible_chunk_signature, camera_focus_cell)
	else:
		_debug_stats["draw_cache_rebuilt"] = false
		_debug_stats["redraw_reason"] = "cached"
	var candidates := _cached_draw_candidates
	if candidates.is_empty():
		_debug_stats["draw_ms"] = float(Time.get_ticks_usec() - draw_start) / 1000.0
		if profile_enabled:
			RUNTIME_PROFILER.end_scope("vegetation_draw_total_ms")
		return
	total_visible_instance_count = candidates.size()
	if profile_enabled:
		RUNTIME_PROFILER.begin_scope("vegetation_draw_loop_ms")
	var draw_loop_start := Time.get_ticks_usec()
	for item in candidates:
		if drawn_instance_count >= max_drawn_instances:
			skipped_by_cap_count += 1
			continue
		var position := Vector2(item.get("position", Vector2.ZERO))
		var kind := str(item.get("kind", "grass_patch"))
		var radius := float(item.get("radius", get_default_radius(kind)))
		var seed := int(item.get("seed", 0))
		var lod := _resolve_grass_lod(position, seed)
		if lod == LOD_FAR and _should_skip_far_grass(seed):
			skipped_by_far_lod_count += 1
			continue
		_draw_vegetation_instance_lod(kind, position, radius, seed, lod)
		drawn_instance_count += 1
		match lod:
			LOD_NEAR:
				near_lod_count += 1
			LOD_MID:
				mid_lod_count += 1
			LOD_FAR:
				far_lod_count += 1
	_debug_stats["drawn_instance_count"] = drawn_instance_count
	_debug_stats["draw_loop_ms"] = float(Time.get_ticks_usec() - draw_loop_start) / 1000.0
	if profile_enabled:
		RUNTIME_PROFILER.end_scope("vegetation_draw_loop_ms")
	_debug_stats["draw_ms"] = float(Time.get_ticks_usec() - draw_start) / 1000.0
	if profile_enabled:
		RUNTIME_PROFILER.end_scope("vegetation_draw_total_ms")


func _reset_draw_debug_counters() -> void:
	drawn_instance_count = 0
	total_visible_instance_count = 0
	visible_chunk_count = 0
	skipped_by_cap_count = 0
	skipped_by_far_lod_count = 0
	near_lod_count = 0
	mid_lod_count = 0
	far_lod_count = 0


func _collect_visible_draw_candidates() -> Array[Dictionary]:
	return _cached_draw_candidates


func _should_rebuild_draw_cache(visible_chunk_signature: String, camera_focus_cell: Vector2i) -> bool:
	if _draw_cache_dirty:
		return true
	if visible_chunk_signature != _cached_visible_chunk_signature:
		return true
	if camera_focus_cell != _cached_camera_focus_cell:
		return true
	if _instances_version != _cached_instances_version:
		return true
	return _quality_cap_version != _cached_quality_cap_version


func _rebuild_draw_candidates(visible_chunk_signature: String, camera_focus_cell: Vector2i) -> void:
	var sort_start := Time.get_ticks_usec()
	var profile_enabled := bool(GAME_BALANCE.DEBUG_HITCH_BREAKDOWN_PROFILING)
	var collect_start := Time.get_ticks_usec()
	if profile_enabled:
		RUNTIME_PROFILER.begin_scope("vegetation_collect_candidates_ms")
	var result: Array[Dictionary] = []
	if not has_visible_world_rect:
		for item_value in instances:
			result.append(Dictionary(item_value))
	else:
		var visible_keys := _get_visible_chunk_keys(visible_world_rect)
		visible_chunk_count = visible_keys.size()
		for chunk_key in visible_keys:
			var chunk_items := Array(instances_by_chunk.get(chunk_key, []))
			for item_value in chunk_items:
				var item := Dictionary(item_value)
				var position := Vector2(item.get("position", Vector2.ZERO))
				if not visible_world_rect.has_point(position):
					continue
				result.append(item)
	_debug_stats["candidate_collect_ms"] = float(Time.get_ticks_usec() - collect_start) / 1000.0
	if profile_enabled:
		RUNTIME_PROFILER.end_scope("vegetation_collect_candidates_ms")
	if has_camera_focus_position:
		if profile_enabled:
			RUNTIME_PROFILER.begin_scope("vegetation_sort_candidates_ms")
		result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var a_pos := Vector2(a.get("position", Vector2.ZERO))
			var b_pos := Vector2(b.get("position", Vector2.ZERO))
			return a_pos.distance_squared_to(camera_focus_position) < b_pos.distance_squared_to(camera_focus_position)
		)
		if profile_enabled:
			RUNTIME_PROFILER.end_scope("vegetation_sort_candidates_ms")
	_sorted_candidate_cache_key = "%s|%s|%d|%d" % [visible_chunk_signature, str(camera_focus_cell), _instances_version, _quality_cap_version]
	_cached_draw_candidates = result
	_cached_visible_chunk_signature = visible_chunk_signature
	_cached_camera_focus_cell = camera_focus_cell
	_cached_instances_version = _instances_version
	_draw_cache_dirty = false
	_debug_stats["candidate_count_before_cap"] = result.size()
	_debug_stats["candidate_sort_ms"] = float(Time.get_ticks_usec() - sort_start) / 1000.0
	_debug_stats["redraw_reason"] = _redraw_reason
	_debug_stats["draw_cache_rebuilt"] = true
	_debug_stats["visible_chunk_signature"] = visible_chunk_signature
	_redraw_reason = "cached"


func _resolve_grass_lod(position: Vector2, seed: int) -> int:
	if not has_camera_focus_position:
		return LOD_NEAR
	var distance := position.distance_to(camera_focus_position)
	if distance <= GRASS_LOD_NEAR_DISTANCE:
		return LOD_NEAR
	if distance <= GRASS_LOD_MID_DISTANCE:
		return LOD_MID
	return LOD_FAR


func _should_skip_far_grass(seed: int) -> bool:
	return abs(seed) % far_lod_every_nth != 0


func _draw_vegetation_instance_lod(kind: String, position: Vector2, radius: float, seed: int, lod: int) -> void:
	match kind:
		"grass_patch", "dense_grass":
			_draw_grass_lod(kind, position, radius, seed, lod)
		"reed":
			_draw_reed_lod(position, radius, seed, lod)
		"cattail":
			_draw_cattail_lod(position, radius, seed, lod)
		"water_lily":
			_draw_water_lily_lod(position, radius, seed, lod)
		"pond_grass", "wetland_grass":
			_draw_wetland_grass_lod(kind, position, radius, seed, lod)
		_:
			_draw_vegetation_instance(kind, position, radius, seed)


func _draw_grass_lod(kind: String, position: Vector2, radius: float, seed: int, lod: int) -> void:
	match lod:
		LOD_NEAR:
			_draw_grass_blades(kind, position, radius, seed, GRASS_NEAR_BLADE_COUNT)
		LOD_MID:
			_draw_grass_blades(kind, position, radius * 0.82, seed, GRASS_MID_BLADE_COUNT)
		LOD_FAR:
			_draw_far_grass_mark(kind, position, radius, seed)


func _draw_grass_blades(kind: String, position: Vector2, radius: float, seed: int, blade_count: int) -> void:
	var base_color := _get_color_for_kind(kind, seed)
	for i in range(blade_count):
		var blade_seed := seed + i * 92821
		var angle_noise := float(abs(blade_seed) % 1000) / 1000.0
		var offset_noise := float(abs(blade_seed / 17) % 1000) / 1000.0
		var height_noise := float(abs(blade_seed / 31) % 1000) / 1000.0
		var x_offset := lerpf(-radius * 0.45, radius * 0.45, offset_noise)
		var blade_height := lerpf(radius * 0.55, radius * 1.15, height_noise)
		var lean := lerpf(-radius * 0.28, radius * 0.28, angle_noise)
		var base := position + Vector2(x_offset, radius * 0.35)
		var tip := base + Vector2(lean, -blade_height)
		draw_line(base, tip, base_color, 1.0)


func _draw_far_grass_mark(kind: String, position: Vector2, radius: float, seed: int) -> void:
	var color := _get_color_for_kind(kind, seed)
	var width := maxf(2.0, radius * 0.30)
	draw_line(position + Vector2(-width, 0.0), position + Vector2(width, 0.0), color, 1.0)


func _draw_reed_lod(position: Vector2, radius: float, seed: int, lod: int) -> void:
	var blade_count := 4 if lod == LOD_NEAR else 2
	for i in blade_count:
		var x_offset := -radius * 0.14 + float(i) * radius * 0.10
		draw_line(position + Vector2(x_offset, radius * 0.45), position + Vector2(x_offset + sin(float(seed + i)) * 1.4, -radius * 0.95), Color(0.34, 0.60, 0.22), 1.8 if lod == LOD_NEAR else 1.3)


func _draw_cattail_lod(position: Vector2, radius: float, seed: int, lod: int) -> void:
	draw_line(position + Vector2(-1.4, radius * 0.48), position + Vector2(-1.4, -radius * 0.92), Color(0.32, 0.48, 0.20), 2.0)
	draw_line(position + Vector2(2.2, radius * 0.46), position + Vector2(2.2, -radius * 0.80), Color(0.28, 0.44, 0.18), 2.0)
	draw_circle(position + Vector2(-1.4, -radius * 0.92), maxf(radius * 0.18, 2.0), Color(0.40, 0.30, 0.12))
	draw_circle(position + Vector2(2.2, -radius * 0.80), maxf(radius * 0.18, 2.0), Color(0.42, 0.31, 0.13))


func _draw_water_lily_lod(position: Vector2, radius: float, seed: int, lod: int) -> void:
	draw_circle(position, maxf(radius * 0.55, 5.5), Color(0.12, 0.44, 0.18))
	draw_circle(position + Vector2(-2.0, 1.5), maxf(radius * 0.26, 2.5), Color(0.18, 0.56, 0.22))
	draw_arc(position, maxf(radius * 0.60, 6.0), -PI * 0.1, PI * 1.5, 12, Color(0.08, 0.30, 0.11), 2.0)


func _draw_wetland_grass_lod(kind: String, position: Vector2, radius: float, seed: int, lod: int) -> void:
	var base_color := Color(0.22, 0.55, 0.18) if kind == "wetland_grass" else Color(0.28, 0.64, 0.20)
	var blade_count := 7 if lod == LOD_NEAR else 4
	for i in blade_count:
		var offset := -radius * 0.55 + float(i) * radius * 0.16
		draw_line(position + Vector2(offset, radius * 0.45), position + Vector2(offset + sin(float(seed + i)) * 1.6, -radius * 0.55 - float(i % 2) * 2.5), base_color, 1.6)


func _draw_vegetation_instance(kind: String, position: Vector2, radius: float, seed: int) -> void:
	var color := _get_color_for_kind(kind, seed)
	var blade_count := 0
	var blade_length_factor := 1.0
	var blade_spread := 1.0
	var blade_thickness := 1.0
	match kind:
		"dense_grass":
			blade_count = 9
			blade_length_factor = 1.25
			blade_spread = 0.95
			blade_thickness = 1.8
		"grass_patch":
			blade_count = 6
			blade_length_factor = 1.0
			blade_spread = 0.82
			blade_thickness = 1.35
		_:
			blade_count = 5
			blade_length_factor = 0.88
			blade_spread = 0.75
			blade_thickness = 1.2
	_draw_grass_tuft(position, radius, color, seed, blade_count, blade_length_factor, blade_spread, blade_thickness)


func _get_color_for_kind(kind: String, seed: int) -> Color:
	var variation := float(abs(seed % 17)) / 17.0
	match kind:
		"dense_grass":
			return Color(0.13 + variation * 0.05, 0.42 + variation * 0.08, 0.12 + variation * 0.03, 0.64)
		"grass_patch":
			return Color(0.18 + variation * 0.05, 0.50 + variation * 0.08, 0.16 + variation * 0.02, 0.56)
	return Color(0.18, 0.48, 0.16, 0.50)


func _draw_grass_tuft(position: Vector2, radius: float, color: Color, seed: int, blade_count: int, blade_length_factor: float, blade_spread: float, blade_thickness: float) -> void:
	var tuft_radius := maxf(radius, 2.0)
	var base_angle := float(abs(seed % 360)) / 360.0 * TAU
	for i in range(blade_count):
		var blade_index := float(i)
		var count := float(max(blade_count, 1))
		var fan_strength := 0.45 + blade_spread * 0.7
		var angle_variation := sin(float(seed) * 0.013 + blade_index * 1.91) * 0.28
		var angle := base_angle + TAU * blade_index / count + angle_variation
		var center_offset := float(blade_index) - (count - 1.0) * 0.5
		var width_offset := center_offset * tuft_radius * 0.16 * fan_strength
		var height_noise := 0.72 + float(abs((seed + i * 13) % 11)) / 11.0 * 0.42
		var blade_length := tuft_radius * blade_length_factor * height_noise
		var bend := Vector2(cos(angle + 0.75), sin(angle + 0.75)) * tuft_radius * (0.25 + fan_strength * 0.1)
		var blade_base := position + Vector2(cos(angle), sin(angle)) * tuft_radius * 0.18 * blade_spread + Vector2(cos(base_angle + PI * 0.5), sin(base_angle + PI * 0.5)) * width_offset
		var blade_tip := blade_base + Vector2(0.0, -blade_length) + bend
		var edge_color := color.darkened(0.10 + float(i % 3) * 0.03)
		draw_line(blade_base, blade_tip, edge_color, blade_thickness)
		draw_line(blade_base + Vector2(blade_thickness * 0.18, 0.0), blade_tip + Vector2(blade_thickness * 0.05, 0.0), color.lightened(0.05), maxf(1.0, blade_thickness * 0.52))
		if i % 3 == 0:
			var side_tip := blade_base + Vector2(cos(angle - 0.7), sin(angle - 0.7)) * tuft_radius * (0.46 + blade_spread * 0.16)
			draw_line(blade_base, side_tip, color.darkened(0.14), maxf(1.0, blade_thickness * 0.44))
	draw_circle(position + Vector2(0.0, tuft_radius * 0.08), tuft_radius * 0.18, color.darkened(0.08))


func _get_chunk_key(world_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_position.x / chunk_size),
		floori(world_position.y / chunk_size)
	)


func _get_chunk_range_for_rect(rect: Rect2) -> Dictionary:
	var start_key := _get_chunk_key(rect.position)
	var end_key := _get_chunk_key(rect.position + rect.size)
	return {
		"start": start_key,
		"end": end_key
	}


func _get_visible_chunk_keys(rect: Rect2) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var chunk_range := _get_chunk_range_for_rect(rect)
	var start_key := Vector2i(chunk_range.get("start", Vector2i.ZERO))
	var end_key := Vector2i(chunk_range.get("end", Vector2i.ZERO))
	for chunk_x in range(start_key.x, end_key.x + 1):
		for chunk_y in range(start_key.y, end_key.y + 1):
			var key := Vector2i(chunk_x, chunk_y)
			if instances_by_chunk.has(key):
				result.append(key)
	return result


func _get_visible_chunk_signature(rect: Rect2) -> String:
	var keys := _get_visible_chunk_keys(rect)
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.x == b.x:
			return a.y < b.y
		return a.x < b.x
	)
	var parts: Array[String] = []
	for key in keys:
		parts.append("%d:%d" % [key.x, key.y])
	return "|".join(parts)


func _make_seed(kind: String, world_position: Vector2) -> int:
	var hash_value := kind.hash()
	hash_value = int(hash_value + int(world_position.x * 17.0) + int(world_position.y * 31.0))
	return hash_value


func _invalidate_visible_candidate_cache(reason: String = "manual_redraw") -> void:
	_draw_cache_dirty = true
	_redraw_reason = reason
	_cached_draw_candidates.clear()
	_cached_visible_chunk_signature = ""
	_cached_camera_focus_cell = Vector2i(2147483647, 2147483647)
	_cached_instances_version = -1
	_cached_quality_cap_version = -1
	_sorted_candidate_cache_key = ""
	_debug_stats["redraw_reason"] = reason
	_debug_stats["draw_cache_rebuilt"] = false


func _request_redraw_once() -> void:
	_queue_redraw_count += 1
	if _bulk_add_depth > 0:
		_bulk_add_request_redraw = true
		return
	queue_redraw()


func _get_camera_focus_cell() -> Vector2i:
	if not has_camera_focus_position:
		return Vector2i(2147483647, 2147483647)
	return Vector2i(floori(camera_focus_position.x / chunk_size), floori(camera_focus_position.y / chunk_size))
