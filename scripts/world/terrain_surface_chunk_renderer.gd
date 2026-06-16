extends Node2D
class_name TerrainSurfaceChunkRenderer

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")

var world: Node
var player: Node2D
var camera: Camera2D
var biome_shape_map: Object

var world_rect := Rect2()
var chunk_world_size := 1024.0
var chunk_texture_size := 256
var visible_margin_chunks := 1
var max_chunks_built_per_frame := 1

var visible_chunks: Dictionary = {}
var chunk_textures: Dictionary = {}
var pending_chunks: Array = []
var pending_chunk_set: Dictionary = {}
var active_builds := {}
var sample_cache := {}

var last_visible_signature := ""
var dirty := true

var visible_chunk_count := 0
var cached_chunk_count := 0
var chunks_built_last_frame := 0
var last_build_ms := 0.0
var max_build_ms := 0.0
var total_build_count := 0
var chunk_build_started_count := 0
var chunk_build_completed_count := 0
var last_clear_reason := ""
var max_rows_built_per_frame := 8
var max_build_ms_per_frame := 4.0
var pending_focus_chunk := Vector2i.ZERO

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
	chunk_texture_size = maxi(int(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_chunk_texture_size", 96)), 32)
	visible_margin_chunks = maxi(int(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_visible_margin_chunks", 1)), 0)
	max_chunks_built_per_frame = maxi(int(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_max_chunks_built_per_frame", 1)), 1)
	max_rows_built_per_frame = maxi(int(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_max_rows_built_per_frame", 8)), 1)
	max_build_ms_per_frame = maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_max_build_ms_per_frame", 4.0)), 1.0)
	if bool(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_texture_filter_nearest", false)):
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if world_changed:
		mark_dirty("bind_world_changed")

func mark_dirty(reason := "unknown") -> void:
	dirty = true
	last_clear_reason = reason
	chunk_textures.clear()
	visible_chunks.clear()
	pending_chunks.clear()
	pending_chunk_set.clear()
	active_builds.clear()
	sample_cache.clear()
	last_visible_signature = ""
	visible_chunk_count = 0
	cached_chunk_count = 0
	queue_redraw()

func process_visibility(_delta: float) -> void:
	if world == null:
		return
	var visible_rect := _get_visible_world_rect()
	var chunk_bounds := _get_chunk_bounds_for_rect(visible_rect)
	var signature := _chunk_bounds_signature(chunk_bounds)
	if not dirty and signature == last_visible_signature:
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

func process_build_queue() -> void:
	chunks_built_last_frame = 0
	var start_ms := Time.get_ticks_msec()
	while active_builds.size() < max_chunks_built_per_frame and not pending_chunks.is_empty():
		var chunk_key = pending_chunks.pop_front()
		pending_chunk_set.erase(chunk_key)
		if chunk_textures.has(chunk_key) or active_builds.has(chunk_key):
			continue
		_start_chunk_build(chunk_key)
	for key_value in active_builds.keys():
		var chunk_key = key_value
		_process_active_chunk_build(chunk_key, start_ms)
		if float(Time.get_ticks_msec() - start_ms) >= max_build_ms_per_frame:
			break
	last_build_ms = float(Time.get_ticks_msec() - start_ms)
	max_build_ms = maxf(max_build_ms, last_build_ms)
	cached_chunk_count = chunk_textures.size()
	if chunks_built_last_frame > 0:
		queue_redraw()

func get_debug_data() -> Dictionary:
	return {
		"terrain_surface_chunk_renderer_enabled": visible,
		"terrain_surface_chunk_visible_count": visible_chunk_count,
		"terrain_surface_chunk_cached_count": cached_chunk_count,
		"terrain_surface_chunk_pending_count": pending_chunks.size(),
		"terrain_surface_chunks_built_last_frame": chunks_built_last_frame,
		"terrain_surface_chunk_last_build_ms": last_build_ms,
		"terrain_surface_chunk_max_build_ms": max_build_ms,
		"terrain_surface_chunk_total_build_count": total_build_count,
		"terrain_surface_active_build_count": active_builds.size(),
		"terrain_surface_chunk_build_started_count": chunk_build_started_count,
		"terrain_surface_chunk_build_completed_count": chunk_build_completed_count,
		"terrain_surface_max_rows_built_per_frame": max_rows_built_per_frame,
		"terrain_surface_max_build_ms_per_frame": max_build_ms_per_frame,
		"terrain_surface_transition_enabled": bool(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_transition_enabled", false)),
		"terrain_surface_uses_biome_shape_map": biome_shape_map != null and biome_shape_map.has_method("sample_visual_surface_at"),
		"terrain_surface_chunk_world_size": chunk_world_size,
		"terrain_surface_chunk_texture_size": chunk_texture_size,
		"terrain_surface_visible_signature": last_visible_signature,
		"terrain_surface_last_clear_reason": last_clear_reason,
		"terrain_surface_draw_mode": "chunk_texture_surface"
	}

func _draw() -> void:
	if not visible:
		return
	for key_value in visible_chunks.keys():
		var chunk_key: Vector2i = key_value
		var texture = chunk_textures.get(chunk_key, null)
		if texture == null:
			if bool(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_draw_placeholders", false)):
				_draw_chunk_placeholder(chunk_key)
			continue
		var chunk_rect := _get_chunk_world_rect(chunk_key)
		draw_texture_rect(texture, chunk_rect, false)

func _queue_chunk_build(chunk_key: Vector2i) -> void:
	if pending_chunk_set.has(chunk_key):
		return
	pending_chunk_set[chunk_key] = true
	pending_chunks.append(chunk_key)

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

func _start_chunk_build(chunk_key: Vector2i) -> void:
	if active_builds.has(chunk_key):
		return
	var image := Image.create(chunk_texture_size, chunk_texture_size, false, Image.FORMAT_RGBA8)
	active_builds[chunk_key] = {
		"chunk_key": chunk_key,
		"image": image,
		"chunk_rect": _get_chunk_world_rect(chunk_key),
		"next_y": 0
	}
	chunk_build_started_count += 1

func _process_active_chunk_build(chunk_key: Vector2i, frame_start_ms: int) -> void:
	if not active_builds.has(chunk_key):
		return
	var state := Dictionary(active_builds[chunk_key])
	var image = state.get("image")
	var chunk_rect = Rect2(state.get("chunk_rect", Rect2()))
	var next_y := int(state.get("next_y", 0))
	var rows_done := 0
	while next_y < chunk_texture_size and rows_done < max_rows_built_per_frame:
		_build_chunk_texture_row(image, chunk_rect, next_y)
		next_y += 1
		rows_done += 1
		if float(Time.get_ticks_msec() - frame_start_ms) >= max_build_ms_per_frame:
			break
	if next_y >= chunk_texture_size:
		chunk_textures[chunk_key] = ImageTexture.create_from_image(image)
		active_builds.erase(chunk_key)
		chunks_built_last_frame += 1
		total_build_count += 1
		chunk_build_completed_count += 1
		sample_cache.clear()
		queue_redraw()
	else:
		state["next_y"] = next_y
		active_builds[chunk_key] = state

func _build_chunk_texture_row(image: Image, chunk_rect: Rect2, y: int) -> void:
	for x in range(chunk_texture_size):
		var uv := Vector2(
			(float(x) + 0.5) / float(chunk_texture_size),
			(float(y) + 0.5) / float(chunk_texture_size)
		)
		var world_pos := chunk_rect.position + Vector2(chunk_rect.size.x * uv.x, chunk_rect.size.y * uv.y)
		image.set_pixel(x, y, _sample_surface_color(world_pos))

func _sample_surface_color(world_pos: Vector2) -> Color:
	var cache_step := 48.0
	var cache_key := "%d,%d" % [int(floor(world_pos.x / cache_step)), int(floor(world_pos.y / cache_step))]
	var terrain_id := ""
	var biome_id := ""
	if sample_cache.has(cache_key):
		var cached := Dictionary(sample_cache[cache_key])
		terrain_id = str(cached.get("terrain_id", "land"))
		biome_id = str(cached.get("biome_id", "hearth_meadow"))
	else:
		var surface := _sample_surface_ids(world_pos)
		terrain_id = str(surface.get("terrain_id", "land"))
		biome_id = str(surface.get("biome_id", "hearth_meadow"))
		sample_cache[cache_key] = {
			"terrain_id": terrain_id,
			"biome_id": biome_id
		}
	var base := _get_base_surface_color(biome_id, terrain_id)
	if bool(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_noise_enabled", true)):
		base = _apply_surface_variation(base, biome_id, terrain_id, world_pos)
	if bool(GAME_BALANCE.BIOME_TEXTURES.get("terrain_surface_transition_enabled", false)):
		return _apply_local_transition(base, biome_id, terrain_id, world_pos)
	return base

func _sample_surface_ids(world_pos: Vector2) -> Dictionary:
	if biome_shape_map != null and biome_shape_map.has_method("sample_visual_surface_at"):
		return Dictionary(biome_shape_map.sample_visual_surface_at(world_pos))
	return {
		"terrain_id": _get_surface_terrain(world_pos),
		"biome_id": _get_visual_biome(world_pos),
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
