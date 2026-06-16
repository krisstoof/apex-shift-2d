extends RefCounted
class_name BiomeShapeMap

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")

var world_rect := Rect2()
var sample_size := 96.0
var grid_size := Vector2i.ZERO
var seed := 0
var biome_grid: Array[Array] = []
var terrain_grid: Array[Array] = []
var polygons_by_layer: Dictionary = {}
var details: Array[Dictionary] = []
var build_count := 0
var last_build_ms := 0.0
var last_polygon_count := 0
var last_detail_count := 0
var last_key := ""
var biome_shape_map_uses_convex_hull := false
var biome_shape_map_contour_mode := "marching_squares"
var biome_shape_map_rejected_polygon_count := 0
var biome_shape_map_self_crossing_guard_enabled := true

func build(assigned_world_rect: Rect2, world_generator: RefCounted, world_topography: RefCounted, assigned_seed: int) -> void:
	var start_ms := Time.get_ticks_msec()
	world_rect = assigned_world_rect
	seed = assigned_seed
	sample_size = maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("biome_shape_sample_size", 96.0)), 32.0)
	grid_size = Vector2i(maxi(2, int(ceil(world_rect.size.x / sample_size))), maxi(2, int(ceil(world_rect.size.y / sample_size))))
	biome_grid.clear()
	terrain_grid.clear()
	polygons_by_layer.clear()
	details.clear()
	_build_sample_grids(world_generator, world_topography)
	_build_connected_region_polygons()
	_build_details(world_generator)
	build_count += 1
	last_build_ms = float(Time.get_ticks_msec() - start_ms)
	last_polygon_count = _count_polygons()
	last_detail_count = details.size()
	last_key = "shape_map_v2|seed=%d|grid=%s|polys=%d|details=%d" % [seed, str(grid_size), last_polygon_count, last_detail_count]

func get_polygons_by_layer() -> Dictionary:
	return polygons_by_layer

func get_details() -> Array[Dictionary]:
	return details

func get_debug_data() -> Dictionary:
	return {
		"biome_shape_map_enabled": true,
		"biome_shape_map_build_count": build_count,
		"biome_shape_map_last_build_ms": last_build_ms,
		"biome_shape_map_grid_size": grid_size,
		"biome_shape_map_sample_size": sample_size,
		"biome_shape_map_polygon_count": last_polygon_count,
		"biome_shape_map_detail_count": last_detail_count,
		"biome_shape_map_key": last_key,
		"biome_shape_map_uses_convex_hull": biome_shape_map_uses_convex_hull,
		"biome_shape_map_layer_count": polygons_by_layer.size(),
		"biome_shape_map_polygon_count_by_layer": _get_polygon_count_by_layer(),
		"biome_shape_map_largest_polygon_cell_count_by_layer": _get_largest_polygon_cell_count_by_layer(),
		"biome_shape_map_contour_mode": biome_shape_map_contour_mode,
		"biome_shape_map_rejected_polygon_count": biome_shape_map_rejected_polygon_count,
		"biome_shape_map_self_crossing_guard_enabled": biome_shape_map_self_crossing_guard_enabled,
		"biome_shape_map_largest_polygon_bounds_by_layer": _get_largest_polygon_bounds_by_layer(),
		"biome_shape_map_largest_polygon_area_ratio_by_layer": _get_largest_polygon_area_ratio_by_layer()
	}

func _build_sample_grids(world_generator: RefCounted, world_topography: RefCounted) -> void:
	for y in range(grid_size.y):
		var biome_row: Array = []
		var terrain_row: Array = []
		for x in range(grid_size.x):
			var pos := _grid_to_world_center(x, y)
			var biome_id := "hearth_meadow"
			var terrain_id := "land"
			if world_generator != null:
				if world_generator.has_method("get_visual_biome_id_at"):
					biome_id = str(world_generator.get_visual_biome_id_at(pos))
				elif world_generator.has_method("get_biome_id_at"):
					biome_id = str(world_generator.get_biome_id_at(pos))
				if world_generator.has_method("get_base_terrain_zone"):
					terrain_id = str(world_generator.get_base_terrain_zone(pos))
			if world_topography != null and world_topography.has_method("sample_topography_at"):
				var topo := Dictionary(world_topography.sample_topography_at(pos))
				terrain_id = str(topo.get("terrain_zone", terrain_id))
			biome_row.append(biome_id)
			terrain_row.append(terrain_id)
		biome_grid.append(biome_row)
		terrain_grid.append(terrain_row)

func _build_connected_region_polygons() -> void:
	var visited: Dictionary = {}
	var max_polygons := int(GAME_BALANCE.BIOME_TEXTURES.get("biome_shape_max_polygons_per_layer", 128))
	var created := 0
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell := Vector2i(x, y)
			if visited.has(cell):
				continue
			var layer_id := _get_layer_id_at_cell(x, y)
			var component := _flood_fill_layer(x, y, layer_id, visited)
			if component.size() < int(GAME_BALANCE.BIOME_TEXTURES.get("biome_shape_min_region_cells", 4)):
				continue
			for polygon in _build_boundary_polygons(component, layer_id):
				if polygon.size() < 3:
					continue
				var area := _polygon_area(polygon)
				if area < sample_size * sample_size:
					biome_shape_map_rejected_polygon_count += 1
					continue
				var bounds: Rect2 = _get_polygon_bounds(polygon)
				var world_area := maxf(world_rect.size.x * world_rect.size.y, 1.0)
				var bounds_ratio := (bounds.size.x * bounds.size.y) / world_area
				if str(_get_terrain_id_from_layer(layer_id)) not in ["deep_ocean", "shallow_water"] and bounds_ratio > 0.85:
					biome_shape_map_rejected_polygon_count += 1
					continue
				polygon = _smooth_polygon(polygon)
				polygon = _simplify_polygon(polygon, sample_size * 0.35)
				if polygon.size() > int(GAME_BALANCE.BIOME_TEXTURES.get("biome_shape_max_points_per_polygon", 192)):
					polygon = _downsample_polygon(polygon, int(GAME_BALANCE.BIOME_TEXTURES.get("biome_shape_max_points_per_polygon", 192)))
				if not polygons_by_layer.has(layer_id):
					polygons_by_layer[layer_id] = []
				Array(polygons_by_layer[layer_id]).append({
					"layer_id": layer_id,
					"biome_id": _get_biome_id_from_layer(layer_id),
					"terrain_id": _get_terrain_id_from_layer(layer_id),
					"points": polygon,
					"cell_count": component.size()
				})
			created += 1
			if created >= max_polygons:
				return

func _build_details(world_generator: RefCounted) -> void:
	if not bool(GAME_BALANCE.BIOME_TEXTURES.get("biome_shape_detail_enabled", true)):
		return
	var spacing := maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("biome_shape_detail_spacing", 220.0)), sample_size)
	var max_visible := int(GAME_BALANCE.BIOME_TEXTURES.get("biome_shape_detail_max_visible", 260))
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if details.size() >= max_visible:
				return
			if ((x + y) % 4) != 0:
				continue
			var terrain_id := str(Array(terrain_grid[y])[x])
			if terrain_id in ["deep_ocean", "shallow_water", "shore", "pond"]:
				continue
			var biome_id := str(Array(biome_grid[y])[x])
			var pos := _grid_to_world_center(x, y)
			var jitter := Vector2(
				_hash_float(x, y, seed + 31) - 0.5,
				_hash_float(y, x, seed + 47) - 0.5
			) * spacing * 0.65
			details.append({
				"position": pos + jitter,
				"biome_id": biome_id,
				"terrain_id": terrain_id,
				"variant": int(floor(_hash_float(x, y, seed + 71) * 6.0))
			})

func _get_layer_id_at_cell(x: int, y: int) -> String:
	var terrain_id := str(Array(terrain_grid[y])[x])
	var biome_id := str(Array(biome_grid[y])[x])
	return _get_layer_id(biome_id, terrain_id)

func _get_layer_id(biome_id: String, terrain_id: String) -> String:
	if terrain_id in ["deep_ocean", "shallow_water", "shore", "pond"]:
		return "terrain:%s" % terrain_id
	if terrain_id in ["highland", "rocky_patch", "wetland"]:
		return "biome:%s|terrain:%s" % [biome_id, terrain_id]
	return "biome:%s|terrain:land" % biome_id

func _flood_fill_layer(start_x: int, start_y: int, layer_id: String, visited: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var stack: Array[Vector2i] = [Vector2i(start_x, start_y)]
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		if visited.has(cell):
			continue
		if cell.x < 0 or cell.y < 0 or cell.x >= grid_size.x or cell.y >= grid_size.y:
			continue
		if _get_layer_id_at_cell(cell.x, cell.y) != layer_id:
			continue
		visited[cell] = true
		result.append(cell)
		stack.append(Vector2i(cell.x + 1, cell.y))
		stack.append(Vector2i(cell.x - 1, cell.y))
		stack.append(Vector2i(cell.x, cell.y + 1))
		stack.append(Vector2i(cell.x, cell.y - 1))
	return result

func _build_boundary_polygons(cells: Array[Vector2i], layer_id: String) -> Array[PackedVector2Array]:
	var min_x := grid_size.x
	var min_y := grid_size.y
	var max_x := 0
	var max_y := 0
	for cell in cells:
		min_x = min(min_x, cell.x)
		min_y = min(min_y, cell.y)
		max_x = max(max_x, cell.x)
		max_y = max(max_y, cell.y)
	min_x = maxi(min_x - 1, 0)
	min_y = maxi(min_y - 1, 0)
	max_x = mini(max_x + 1, grid_size.x - 1)
	max_y = mini(max_y + 1, grid_size.y - 1)
	var mask := {}
	for cell in cells:
		mask[cell] = true
	var segments: Array[Array] = []
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var tl := _is_mask_cell(mask, x, y, layer_id)
			var tr := _is_mask_cell(mask, x + 1, y, layer_id)
			var br := _is_mask_cell(mask, x + 1, y + 1, layer_id)
			var bl := _is_mask_cell(mask, x, y + 1, layer_id)
			var case_index := 0
			if tl: case_index |= 8
			if tr: case_index |= 4
			if br: case_index |= 2
			if bl: case_index |= 1
			segments.append_array(_marching_squares_segments(x, y, case_index))
	return _stitch_segments_to_loops(segments)

func _is_mask_cell(mask: Dictionary, x: int, y: int, _layer_id: String) -> bool:
	if x < 0 or y < 0 or x >= grid_size.x or y >= grid_size.y:
		return false
	return mask.has(Vector2i(x, y))

func _marching_squares_segments(x: int, y: int, case_index: int) -> Array[Array]:
	var p_tl := _grid_to_world_point(x, y)
	var p_tr := _grid_to_world_point(x + 1, y)
	var p_br := _grid_to_world_point(x + 1, y + 1)
	var p_bl := _grid_to_world_point(x, y + 1)
	var top := (p_tl + p_tr) * 0.5
	var right := (p_tr + p_br) * 0.5
	var bottom := (p_bl + p_br) * 0.5
	var left := (p_tl + p_bl) * 0.5
	match case_index:
		0, 15:
			return []
		1:
			return [[left, bottom]]
		2:
			return [[bottom, right]]
		3:
			return [[left, right]]
		4:
			return [[top, right]]
		5:
			return [[top, left], [bottom, right]]
		6:
			return [[top, bottom]]
		7:
			return [[top, left]]
		8:
			return [[top, left]]
		9:
			return [[top, bottom]]
		10:
			return [[top, right], [left, bottom]]
		11:
			return [[top, right]]
		12:
			return [[left, right]]
		13:
			return [[bottom, right]]
		14:
			return [[left, bottom]]
	return []

func _stitch_segments_to_loops(segments: Array[Array]) -> Array[PackedVector2Array]:
	var remaining: Array[Array] = segments.duplicate(true)
	var loops: Array[PackedVector2Array] = []
	while not remaining.is_empty():
		var start_segment: Array = remaining.pop_back()
		var loop_points: Array[Vector2] = [start_segment[0], start_segment[1]]
		var current: Vector2 = start_segment[1]
		var guard := 0
		while guard < 2048:
			guard += 1
			var found_index := -1
			for i in range(remaining.size()):
				var seg: Array = remaining[i]
				if seg[0].is_equal_approx(current):
					found_index = i
					current = seg[1]
					break
				if seg[1].is_equal_approx(current):
					found_index = i
					current = seg[0]
					break
			if found_index == -1:
				break
			var seg2: Array = remaining[found_index]
			remaining.remove_at(found_index)
			if not loop_points.back().is_equal_approx(seg2[0]):
				if loop_points.back().is_equal_approx(seg2[1]):
					loop_points.append(seg2[0])
				else:
					loop_points.append(seg2[0])
			loop_points.append(current)
			if current.is_equal_approx(loop_points[0]):
				break
		var poly := PackedVector2Array()
		for p in loop_points:
			poly.append(p)
		if poly.size() >= 3:
			loops.append(poly)
	return loops

func _smooth_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var passes := int(GAME_BALANCE.BIOME_TEXTURES.get("biome_shape_smoothing_passes", 2))
	var result := points
	for _pass in range(passes):
		if result.size() < 4:
			return result
		var smoothed := PackedVector2Array()
		for i in range(result.size()):
			var prev := result[(i - 1 + result.size()) % result.size()]
			var cur := result[i]
			var next := result[(i + 1) % result.size()]
			smoothed.append(prev * 0.18 + cur * 0.64 + next * 0.18)
		result = smoothed
	return result

func _simplify_polygon(points: PackedVector2Array, min_distance: float) -> PackedVector2Array:
	if points.size() <= 3:
		return points
	var result := PackedVector2Array()
	var last := points[0]
	result.append(last)
	for i in range(1, points.size()):
		if points[i].distance_to(last) >= min_distance:
			result.append(points[i])
			last = points[i]
	if result.size() < 3:
		return points
	return result

func _downsample_polygon(points: PackedVector2Array, max_points: int) -> PackedVector2Array:
	if points.size() <= max_points:
		return points
	var result := PackedVector2Array()
	var step := float(points.size()) / float(max_points)
	for i in range(max_points):
		result.append(points[int(floor(float(i) * step))])
	return result

func _get_polygon_count_by_layer() -> Dictionary:
	var result: Dictionary = {}
	for layer_id in polygons_by_layer.keys():
		result[layer_id] = Array(polygons_by_layer[layer_id]).size()
	return result

func _get_largest_polygon_cell_count_by_layer() -> Dictionary:
	var result: Dictionary = {}
	for layer_id in polygons_by_layer.keys():
		var largest := 0
		for polygon_value in Array(polygons_by_layer[layer_id]):
			var polygon := Dictionary(polygon_value)
			largest = max(largest, int(polygon.get("cell_count", 0)))
		result[layer_id] = largest
	return result

func _grid_to_world_center(x: int, y: int) -> Vector2:
	return world_rect.position + Vector2((float(x) + 0.5) * sample_size, (float(y) + 0.5) * sample_size)

func _grid_to_world_point(x: int, y: int) -> Vector2:
	return world_rect.position + Vector2(float(x) * sample_size, float(y) * sample_size)

func _jitter(world_pos: Vector2) -> Vector2:
	var amount := float(GAME_BALANCE.BIOME_TEXTURES.get("biome_shape_edge_jitter_world", 26.0))
	var h := float(abs(_hash_int(int(world_pos.x), int(world_pos.y)))) / 2147483647.0
	var angle := h * TAU
	var strength := amount * (0.35 + h * 0.65)
	return Vector2(cos(angle), sin(angle)) * strength

func _hash_int(x: int, y: int) -> int:
	var n := int(x * 374761393 + y * 668265263 + seed * 982451653)
	n = int((n ^ (n >> 13)) * 1274126177)
	return n ^ (n >> 16)

func _hash_float(x: int, y: int, p_seed: int) -> float:
	var n := int(x * 374761393 + y * 668265263 + p_seed * 982451653)
	n = int((n ^ (n >> 13)) * 1274126177)
	n = n ^ (n >> 16)
	return float(abs(n % 10000)) / 10000.0

func _get_biome_id_from_layer(layer_id: String) -> String:
	for part in layer_id.split("|"):
		if part.begins_with("biome:"):
			return part.replace("biome:", "")
	return ""

func _get_terrain_id_from_layer(layer_id: String) -> String:
	for part in layer_id.split("|"):
		if part.begins_with("terrain:"):
			return part.replace("terrain:", "")
	return "land"

func _count_polygons() -> int:
	var count := 0
	for layer_id in polygons_by_layer.keys():
		count += Array(polygons_by_layer[layer_id]).size()
	return count

func _polygon_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		area += a.x * b.y - b.x * a.y
	return absf(area) * 0.5

func _get_polygon_bounds_by_layer() -> Dictionary:
	var result: Dictionary = {}
	for layer_id in polygons_by_layer.keys():
		var largest := Rect2()
		var found := false
		for polygon_value in Array(polygons_by_layer[layer_id]):
			var polygon := Dictionary(polygon_value)
			var points := PackedVector2Array(polygon.get("points", PackedVector2Array()))
			if points.is_empty():
				continue
			var bounds: Rect2 = _get_polygon_bounds(points)
			if not found or bounds.size.x * bounds.size.y > largest.size.x * largest.size.y:
				largest = bounds
				found = true
		result[layer_id] = largest
	return result

func _get_largest_polygon_bounds_by_layer() -> Dictionary:
	return _get_polygon_bounds_by_layer()

func _get_largest_polygon_area_ratio_by_layer() -> Dictionary:
	var result: Dictionary = {}
	var world_area := maxf(world_rect.size.x * world_rect.size.y, 1.0)
	for layer_id in polygons_by_layer.keys():
		var largest_ratio := 0.0
		for polygon_value in Array(polygons_by_layer[layer_id]):
			var polygon := Dictionary(polygon_value)
			var points := PackedVector2Array(polygon.get("points", PackedVector2Array()))
			if points.is_empty():
				continue
			var bounds: Rect2 = _get_polygon_bounds(points)
			largest_ratio = maxf(largest_ratio, (bounds.size.x * bounds.size.y) / world_area)
		result[layer_id] = largest_ratio
	return result

func _get_polygon_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var rect := Rect2(points[0], Vector2.ZERO)
	for point in points:
		rect = rect.expand(point)
	return rect
