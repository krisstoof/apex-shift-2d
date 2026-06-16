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
		"biome_shape_map_largest_polygon_cell_count_by_layer": _get_largest_polygon_cell_count_by_layer()
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
			var polygon := _build_boundary_polygon(component)
			if polygon.size() < 3:
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

func _build_boundary_polygon(cells: Array[Vector2i]) -> PackedVector2Array:
	var edge_counts: Dictionary = {}
	for cell in cells:
		var x := cell.x
		var y := cell.y
		_add_edge(edge_counts, Vector2i(x, y), Vector2i(x + 1, y))
		_add_edge(edge_counts, Vector2i(x + 1, y), Vector2i(x + 1, y + 1))
		_add_edge(edge_counts, Vector2i(x + 1, y + 1), Vector2i(x, y + 1))
		_add_edge(edge_counts, Vector2i(x, y + 1), Vector2i(x, y))
	var boundary_edges: Array[Array] = []
	for edge_key in edge_counts.keys():
		if int(edge_counts[edge_key]) != 1:
			continue
		var parts := str(edge_key).split(";")
		if parts.size() != 2:
			continue
		boundary_edges.append([_parse_grid_point(parts[0]), _parse_grid_point(parts[1])])
	var loop := _stitch_longest_loop(boundary_edges)
	if loop.size() < 3:
		return PackedVector2Array()
	var result := PackedVector2Array()
	for grid_point in loop:
		var world_pos := world_rect.position + Vector2(float(grid_point.x) * sample_size, float(grid_point.y) * sample_size)
		result.append(_jitter(world_pos))
	return result

func _add_edge(edge_counts: Dictionary, a: Vector2i, b: Vector2i) -> void:
	var key := _edge_key(a, b)
	edge_counts[key] = int(edge_counts.get(key, 0)) + 1

func _edge_key(a: Vector2i, b: Vector2i) -> String:
	if a.x < b.x or (a.x == b.x and a.y <= b.y):
		return "%d,%d;%d,%d" % [a.x, a.y, b.x, b.y]
	return "%d,%d;%d,%d" % [b.x, b.y, a.x, a.y]

func _parse_grid_point(text: String) -> Vector2i:
	var parts := text.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

func _stitch_longest_loop(edges: Array[Array]) -> Array[Vector2i]:
	var adjacency: Dictionary = {}
	for edge in edges:
		var a: Vector2i = edge[0]
		var b: Vector2i = edge[1]
		if not adjacency.has(a):
			adjacency[a] = []
		if not adjacency.has(b):
			adjacency[b] = []
		Array(adjacency[a]).append(b)
		Array(adjacency[b]).append(a)
	var best_loop: Array[Vector2i] = []
	for start in adjacency.keys():
		var loop: Array[Vector2i] = []
		var current: Vector2i = start
		var previous := Vector2i(2147483647, 2147483647)
		for _i in range(edges.size() + 8):
			loop.append(current)
			var neighbors := Array(adjacency.get(current, []))
			if neighbors.is_empty():
				break
			var next: Vector2i = neighbors[0]
			if neighbors.size() > 1 and next == previous:
				next = neighbors[1]
			previous = current
			current = next
			if current == start:
				break
		if loop.size() > best_loop.size():
			best_loop = loop
	return best_loop

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
