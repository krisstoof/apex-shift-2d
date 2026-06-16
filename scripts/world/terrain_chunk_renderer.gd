extends Node2D
class_name TerrainChunkRenderer

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const CHUNK_CELLS := 16

var cell_map: TerrainCellMap
var player: Node2D
var camera: Camera2D
var visible_rect := Rect2()
var chunk_cache: Dictionary = {}
var visible_chunks: Dictionary = {}
var chunks_built_last_frame := 0
var last_build_ms := 0.0
var max_build_ms := 0.0
var terrain_chunk_count_visible := 0
var terrain_chunk_count_cached := 0
var terrain_chunk_drawn_cell_count := 0
var terrain_render_mode := "cell_chunk"
var last_visible_chunk_bounds := Rect2i()
var last_visible_chunk_signature := ""


func bind(assigned_cell_map: TerrainCellMap, assigned_player: Node2D, assigned_camera: Camera2D) -> void:
	cell_map = assigned_cell_map
	player = assigned_player
	camera = assigned_camera


func process_visibility(_delta: float) -> void:
	if cell_map == null:
		return
	var rect := _get_visible_world_rect()
	var chunk_bounds := _get_visible_chunk_bounds(rect)
	if rect == visible_rect and chunk_bounds == last_visible_chunk_bounds:
		return
	visible_rect = rect
	last_visible_chunk_bounds = chunk_bounds
	queue_redraw()


func rebuild_visible_chunks(force := false) -> void:
	if cell_map == null:
		return
	var visible_keys: Array[String] = []
	var visible_keys_set: Dictionary = {}
	var grid := cell_map.get_grid_size()
	var start_x := clampi(int(floor((visible_rect.position.x - cell_map.world_rect.position.x) / cell_map.cell_size)) - 1, 0, grid.x - 1)
	var end_x := clampi(int(ceil((visible_rect.end.x - cell_map.world_rect.position.x) / cell_map.cell_size)) + 1, 0, grid.x - 1)
	var start_y := clampi(int(floor((visible_rect.position.y - cell_map.world_rect.position.y) / cell_map.cell_size)) - 1, 0, grid.y - 1)
	var end_y := clampi(int(ceil((visible_rect.end.y - cell_map.world_rect.position.y) / cell_map.cell_size)) + 1, 0, grid.y - 1)
	for y in range(start_y, end_y + 1):
		for x in range(start_x, end_x + 1):
			var chunk_x := int(floor(float(x) / CHUNK_CELLS))
			var chunk_y := int(floor(float(y) / CHUNK_CELLS))
			var key := "%d,%d" % [chunk_x, chunk_y]
			if visible_keys_set.has(key):
				continue
			visible_keys_set[key] = true
			visible_keys.append(key)
	visible_keys.sort()
	var signature := "|".join(visible_keys)
	if not force and signature == last_visible_chunk_signature:
		return
	last_visible_chunk_signature = signature
	visible_chunks.clear()
	for key_string in visible_keys:
		var parts := key_string.split(",")
		var chunk_key := Vector2i(int(parts[0]), int(parts[1]))
		visible_chunks[chunk_key] = true
	if force:
		clear_cache()
	var start_ms := Time.get_ticks_msec()
	chunks_built_last_frame = 0
	var built_this_call := 0
	for key_string in visible_keys:
		var parts := key_string.split(",")
		var chunk_x := int(parts[0])
		var chunk_y := int(parts[1])
		var chunk_key := Vector2i(chunk_x, chunk_y)
		if not force and chunk_cache.has(chunk_key):
			continue
		if built_this_call >= 2:
			continue
		chunk_cache[chunk_key] = _build_chunk_data(chunk_x, chunk_y)
		built_this_call += 1
	chunks_built_last_frame = built_this_call
	terrain_chunk_count_visible = visible_chunks.size()
	terrain_chunk_count_cached = chunk_cache.size()
	terrain_chunk_drawn_cell_count = _count_visible_drawn_cells()
	last_build_ms = float(Time.get_ticks_msec() - start_ms)
	max_build_ms = maxf(max_build_ms, last_build_ms)
	queue_redraw()


func clear_cache() -> void:
	chunk_cache.clear()
	visible_chunks.clear()
	chunks_built_last_frame = 0
	terrain_chunk_count_visible = 0
	terrain_chunk_count_cached = 0
	terrain_chunk_drawn_cell_count = 0
	last_visible_chunk_signature = ""
	last_visible_chunk_bounds = Rect2i()
	queue_redraw()


func get_debug_data() -> Dictionary:
	return {
		"terrain_chunk_count_total": chunk_cache.size(),
		"terrain_chunk_count_visible": terrain_chunk_count_visible,
		"terrain_chunk_count_cached": terrain_chunk_count_cached,
		"terrain_chunks_built_last_frame": chunks_built_last_frame,
		"terrain_chunk_drawn_cell_count": terrain_chunk_drawn_cell_count,
		"terrain_chunk_last_build_ms": last_build_ms,
		"terrain_chunk_max_build_ms": max_build_ms,
		"terrain_render_mode": terrain_render_mode,
		"terrain_visible_chunk_signature": last_visible_chunk_signature
	}


func _draw() -> void:
	if cell_map == null:
		return
	if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return
	for chunk_key in visible_chunks.keys():
		var chunk := Dictionary(chunk_cache.get(chunk_key, {}))
		if chunk.is_empty():
			continue
		_draw_chunk(chunk)


func _draw_chunk(chunk: Dictionary) -> void:
	for cell in Array(chunk.get("cells", [])):
		var cell_data := Dictionary(cell)
		var rect := Rect2(Vector2(cell_data.get("position", Vector2.ZERO)), Vector2(cell_data.get("size", Vector2.ONE)))
		var biome_id := str(cell_data.get("biome_id", "hearth_meadow"))
		var terrain_id := str(cell_data.get("terrain_id", "land"))
		var variant := int(cell_data.get("variant", 0))
		draw_rect(rect, _get_cell_color(biome_id, terrain_id, variant), true)
		terrain_chunk_drawn_cell_count += 1
		if bool(GAME_BALANCE.BIOME_TEXTURES.get("terrain_detail_enabled", false)):
			_draw_cell_detail(rect, biome_id, terrain_id, variant)


func _draw_cell_detail(rect: Rect2, biome_id: String, terrain_id: String, variant: int) -> void:
	var inset := rect.grow(-rect.size.x * 0.18)
	if inset.size.x <= 1.0 or inset.size.y <= 1.0:
		return
	var accent := _get_detail_color(biome_id, terrain_id)
	if variant % 2 == 0:
		draw_line(inset.position, inset.end, accent, 1.0)
	else:
		draw_line(Vector2(inset.position.x, inset.end.y), Vector2(inset.end.x, inset.position.y), accent, 1.0)


func _build_chunk_data(chunk_x: int, chunk_y: int) -> Dictionary:
	var cells: Array = []
	for y in range(chunk_y * CHUNK_CELLS, min((chunk_y + 1) * CHUNK_CELLS, cell_map.grid_size.y)):
		for x in range(chunk_x * CHUNK_CELLS, min((chunk_x + 1) * CHUNK_CELLS, cell_map.grid_size.x)):
			var cell := cell_map.get_cell(x, y)
			if cell.is_empty():
				continue
			var rect := cell_map.get_cell_world_rect(x, y)
			cells.append({
				"position": rect.position,
				"size": rect.size,
				"biome_id": cell.get("biome_id", ""),
				"terrain_id": cell.get("terrain_id", ""),
				"variant": cell.get("variant", 0)
			})
	return {"cells": cells}


func _get_visible_world_rect() -> Rect2:
	if camera != null and is_instance_valid(camera):
		var viewport_size := get_viewport_rect().size
		var zoom := camera.zoom if camera.zoom != Vector2.ZERO else Vector2.ONE
		var half_size := Vector2(viewport_size.x / zoom.x, viewport_size.y / zoom.y) * 0.5
		return Rect2(camera.global_position - half_size, half_size * 2.0).grow(192.0)
	if player != null and is_instance_valid(player):
		return Rect2(player.global_position - Vector2(640.0, 360.0), Vector2(1280.0, 720.0)).grow(192.0)
	return cell_map.world_rect


func _get_visible_chunk_bounds(rect: Rect2) -> Rect2i:
	if cell_map == null or cell_map.cell_size <= 0.0:
		return Rect2i()
	var grid := cell_map.get_grid_size()
	if grid == Vector2i.ZERO:
		return Rect2i()
	var start_x := clampi(int(floor((rect.position.x - cell_map.world_rect.position.x) / cell_map.cell_size / CHUNK_CELLS)), 0, maxi(0, int(ceil(float(grid.x) / CHUNK_CELLS)) - 1))
	var end_x := clampi(int(floor((rect.end.x - cell_map.world_rect.position.x) / cell_map.cell_size / CHUNK_CELLS)), 0, maxi(0, int(ceil(float(grid.x) / CHUNK_CELLS)) - 1))
	var start_y := clampi(int(floor((rect.position.y - cell_map.world_rect.position.y) / cell_map.cell_size / CHUNK_CELLS)), 0, maxi(0, int(ceil(float(grid.y) / CHUNK_CELLS)) - 1))
	var end_y := clampi(int(floor((rect.end.y - cell_map.world_rect.position.y) / cell_map.cell_size / CHUNK_CELLS)), 0, maxi(0, int(ceil(float(grid.y) / CHUNK_CELLS)) - 1))
	return Rect2i(Vector2i(start_x, start_y), Vector2i(end_x - start_x + 1, end_y - start_y + 1))


func _count_visible_drawn_cells() -> int:
	var count := 0
	for chunk_key in visible_chunks.keys():
		var chunk := Dictionary(chunk_cache.get(chunk_key, {}))
		count += Array(chunk.get("cells", [])).size()
	return count


func _get_cell_color(biome_id: String, terrain_id: String, variant: int) -> Color:
	var base := _get_biome_base_color(biome_id)
	var noise := 0.02 * float(variant)
	match terrain_id:
		"highland":
			base = base.lerp(Color(0.55, 0.50, 0.34), 0.22)
		"pond":
			base = Color(0.10, 0.38, 0.50)
		"rocky_patch":
			base = base.lerp(Color(0.46, 0.43, 0.36), 0.34)
		"wetland":
			base = base.lerp(Color(0.18, 0.34, 0.20), 0.20)
	base = base.lightened(noise)
	return base


func _get_detail_color(biome_id: String, terrain_id: String) -> Color:
	match terrain_id:
		"pond":
			return Color(0.20, 0.55, 0.62, 0.5)
		"rocky_patch":
			return Color(0.72, 0.68, 0.58, 0.42)
		"highland":
			return Color(0.68, 0.62, 0.42, 0.35)
		_:
			return _get_biome_base_color(biome_id).lightened(0.16)


func _get_biome_base_color(biome_id: String) -> Color:
	match biome_id:
		"westwood":
			return Color(0.15, 0.34, 0.17)
		"stoneback_ridge":
			return Color(0.48, 0.44, 0.36)
		"hearth_meadow":
			return Color(0.28, 0.52, 0.22)
		"south_thicket":
			return Color(0.20, 0.38, 0.18)
		"redfang_wilds":
			return Color(0.46, 0.24, 0.18)
		_:
			return Color(0.28, 0.45, 0.24)
