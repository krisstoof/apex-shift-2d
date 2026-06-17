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
var polygon_records: Array[Dictionary] = []
var visual_surface_grid: Array[Array] = []
var visual_surface_grid_size := Vector2i.ZERO
var visual_surface_sample_size := 48.0
var visual_surface_build_count := 0
var visual_surface_last_build_ms := 0.0
var visual_surface_source := "none"

func build(assigned_world_rect: Rect2, world_generator: RefCounted, world_topography: RefCounted, assigned_seed: int) -> void:
	var start_ms := Time.get_ticks_msec()
	world_rect = assigned_world_rect
	seed = assigned_seed
	sample_size = maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("biome_shape_sample_size", 96.0)), 32.0)
	grid_size = Vector2i(maxi(2, int(ceil(world_rect.size.x / sample_size))), maxi(2, int(ceil(world_rect.size.y / sample_size))))
	biome_grid.clear()
	terrain_grid.clear()
	polygons_by_layer.clear()
	polygon_records.clear()
	details.clear()
	visual_surface_grid.clear()
	visual_surface_grid_size = Vector2i.ZERO
	visual_surface_source = "none"
	_build_sample_grids(world_generator, world_topography)
	_build_connected_region_polygons()
	_build_polygon_records()
	_build_visual_surface_grid_from_polygons()
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

func get_sample_grid_size() -> Vector2i:
	return grid_size

func get_sample_grid_cell(x: int, y: int) -> Dictionary:
	if y < 0 or y >= biome_grid.size() or y >= terrain_grid.size():
		return {}
	var biome_row := Array(biome_grid[y])
	var terrain_row := Array(terrain_grid[y])
	if x < 0 or x >= biome_row.size() or x >= terrain_row.size():
		return {}
	var biome_id := str(biome_row[x])
	var terrain_id := str(terrain_row[x])
	return {
		"biome_id": biome_id,
		"terrain_id": terrain_id,
		"layer_id": _get_layer_id(biome_id, terrain_id)
	}

func get_sample_grid_cell_world_rect(x: int, y: int) -> Rect2:
	return Rect2(_grid_to_world_point(x, y), Vector2(sample_size, sample_size))

func has_renderable_polygons() -> bool:
	for layer_id in polygons_by_layer.keys():
		if Array(polygons_by_layer[layer_id]).size() > 0:
			return true
	return false

func sample_visual_surface_at(position: Vector2) -> Dictionary:
	if not world_rect.has_point(position):
		return {
			"biome_id": "",
			"terrain_id": "deep_ocean",
			"layer_id": "terrain:deep_ocean",
			"source": "outside_world_rect"
		}
	if visual_surface_grid_size != Vector2i.ZERO and not visual_surface_grid.is_empty():
		var cell := _visual_world_to_grid(position)
		if cell.y >= 0 and cell.y < visual_surface_grid.size():
			var row := Array(visual_surface_grid[cell.y])
			if cell.x >= 0 and cell.x < row.size():
				return Dictionary(row[cell.x])
	var fallback := _sample_grid_surface_at(position)
	return {
		"biome_id": str(fallback.get("biome_id", "")),
		"terrain_id": str(fallback.get("terrain_id", "deep_ocean")),
		"layer_id": str(fallback.get("layer_id", "terrain:deep_ocean")),
		"source": "grid_fallback_no_visual_surface"
	}

func sample_visual_surface_exact_at(position: Vector2) -> Dictionary:
	if not world_rect.has_point(position):
		return {
			"biome_id": "",
			"terrain_id": "deep_ocean",
			"layer_id": "terrain:deep_ocean",
			"source": "exact_outside_world_rect"
		}
	for i in range(polygon_records.size() - 1, -1, -1):
		var record := Dictionary(polygon_records[i])
		var bounds := Rect2(record.get("bounds", Rect2()))
		if not bounds.has_point(position):
			continue
		var points := PackedVector2Array(record.get("points", PackedVector2Array()))
		if points.size() < 3:
			continue
		if Geometry2D.is_point_in_polygon(position, points):
			return {
				"biome_id": str(record.get("biome_id", "")),
				"terrain_id": str(record.get("terrain_id", "land")),
				"layer_id": str(record.get("layer_id", "")),
				"source": "exact_polygon_record"
			}
	var fallback := sample_visual_surface_at(position)
	fallback["source"] = "exact_grid_fallback"
	return fallback

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
		"biome_shape_map_has_renderable_polygons": has_renderable_polygons(),
		"biome_shape_map_largest_polygon_cell_count_by_layer": _get_largest_polygon_cell_count_by_layer(),
		"biome_shape_map_contour_mode": biome_shape_map_contour_mode,
		"biome_shape_map_rejected_polygon_count": biome_shape_map_rejected_polygon_count,
		"biome_shape_map_self_crossing_guard_enabled": biome_shape_map_self_crossing_guard_enabled,
		"biome_shape_polygon_record_count": polygon_records.size(),
		"biome_shape_map_largest_polygon_bounds_by_layer": _get_largest_polygon_bounds_by_layer(),
		"biome_shape_map_largest_polygon_area_ratio_by_layer": _get_largest_polygon_area_ratio_by_layer(),
		"biome_shape_visual_surface_grid_size": visual_surface_grid_size,
		"biome_shape_visual_surface_sample_size": visual_surface_sample_size,
		"biome_shape_visual_surface_build_count": visual_surface_build_count,
		"biome_shape_visual_surface_last_build_ms": visual_surface_last_build_ms,
		"biome_shape_visual_surface_source": visual_surface_source,
		"biome_shape_visual_surface_enabled": not visual_surface_grid.is_empty()
	}

func _sample_grid_surface_at(position: Vector2) -> Dictionary:
	if grid_size == Vector2i.ZERO or biome_grid.is_empty() or terrain_grid.is_empty():
		return {
			"biome_id": "",
			"terrain_id": "deep_ocean",
			"layer_id": "terrain:deep_ocean"
		}
	var local := position - world_rect.position
	var x := clampi(int(floor(local.x / sample_size)), 0, grid_size.x - 1)
	var y := clampi(int(floor(local.y / sample_size)), 0, grid_size.y - 1)
	var biome_id := str(Array(biome_grid[y])[x])
	var terrain_id := str(Array(terrain_grid[y])[x])
	var layer_id := _get_layer_id(biome_id, terrain_id)
	return {
		"biome_id": biome_id,
		"terrain_id": terrain_id,
		"layer_id": layer_id
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
			if layer_id == "terrain:deep_ocean":
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

func _build_polygon_records() -> void:
	polygon_records.clear()
	var draw_order := _get_layer_draw_order(polygons_by_layer)
	for layer_id in draw_order:
		for polygon_value in Array(polygons_by_layer.get(layer_id, [])):
			var polygon := Dictionary(polygon_value)
			var points := PackedVector2Array(polygon.get("points", PackedVector2Array()))
			if points.size() < 3:
				continue
			polygon_records.append({
				"layer_id": layer_id,
				"biome_id": str(polygon.get("biome_id", "")),
				"terrain_id": str(polygon.get("terrain_id", "land")),
				"points": points,
				"bounds": _get_polygon_bounds(points)
			})

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

func _build_visual_surface_grid_from_polygons() -> void:
	var start_ms := Time.get_ticks_msec()
	visual_surface_sample_size = maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("biome_shape_runtime_sample_size", 48.0)), 24.0)
	visual_surface_grid_size = Vector2i(
		maxi(2, int(ceil(world_rect.size.x / visual_surface_sample_size))),
		maxi(2, int(ceil(world_rect.size.y / visual_surface_sample_size)))
	)
	visual_surface_grid.clear()
	for y in range(visual_surface_grid_size.y):
		var row: Array = []
		for x in range(visual_surface_grid_size.x):
			var world_pos := _visual_grid_to_world_center(x, y)
			var fallback := _sample_grid_surface_at(world_pos)
			row.append({
				"biome_id": str(fallback.get("biome_id", "")),
				"terrain_id": str(fallback.get("terrain_id", "deep_ocean")),
				"layer_id": str(fallback.get("layer_id", "terrain:deep_ocean")),
				"source": "visual_surface_grid_fallback"
			})
		visual_surface_grid.append(row)
	var draw_order := _get_layer_draw_order(polygons_by_layer)
	for layer_id in draw_order:
		if layer_id == "terrain:deep_ocean":
			continue
		var polygons := Array(polygons_by_layer.get(layer_id, []))
		for polygon_value in polygons:
			var polygon := Dictionary(polygon_value)
			var points := PackedVector2Array(polygon.get("points", PackedVector2Array()))
			if points.size() < 3:
				continue
			var bounds := _get_polygon_bounds(points)
			var min_cell := _visual_world_to_grid(bounds.position)
			var max_cell := _visual_world_to_grid(bounds.end)
			for gy in range(min_cell.y, max_cell.y + 1):
				for gx in range(min_cell.x, max_cell.x + 1):
					if gx < 0 or gy < 0 or gx >= visual_surface_grid_size.x or gy >= visual_surface_grid_size.y:
						continue
					var world_pos := _visual_grid_to_world_center(gx, gy)
					if not Geometry2D.is_point_in_polygon(world_pos, points):
						continue
					Array(visual_surface_grid[gy])[gx] = {
						"biome_id": str(polygon.get("biome_id", "")),
						"terrain_id": str(polygon.get("terrain_id", "land")),
						"layer_id": str(polygon.get("layer_id", layer_id)),
						"source": "visual_surface_grid_polygon"
					}
	_seal_visual_surface_grid_seams()
	visual_surface_build_count += 1
	visual_surface_last_build_ms = float(Time.get_ticks_msec() - start_ms)
	visual_surface_source = "polygons_by_layer"

func _seal_visual_surface_grid_seams() -> void:
	if visual_surface_grid_size == Vector2i.ZERO or visual_surface_grid.is_empty():
		return
	var pass_count := maxi(int(GAME_BALANCE.BIOME_TEXTURES.get("biome_shape_visual_surface_gap_fill_passes", 2)), 0)
	var neighbor_offsets := [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)
	]
	for _pass in range(pass_count):
		var changed := false
		var next_grid: Array[Array] = []
		for y in range(visual_surface_grid_size.y):
			var next_row: Array = []
			for x in range(visual_surface_grid_size.x):
				var current := Dictionary(Array(visual_surface_grid[y])[x])
				var replacement := current
				if _is_water_gap_surface(current):
					var land_neighbor_count := 0
					var biome_counts: Dictionary = {}
					for offset in neighbor_offsets:
						var nx: int = x + offset.x
						var ny: int = y + offset.y
						if nx < 0 or ny < 0 or nx >= visual_surface_grid_size.x or ny >= visual_surface_grid_size.y:
							continue
						var neighbor := Dictionary(Array(visual_surface_grid[ny])[nx])
						if not _is_landlike_surface(neighbor):
							continue
						land_neighbor_count += 1
						var neighbor_biome_id := str(neighbor.get("biome_id", ""))
						if neighbor_biome_id.is_empty():
							continue
						biome_counts[neighbor_biome_id] = int(biome_counts.get(neighbor_biome_id, 0)) + 1
					if land_neighbor_count >= 4 and not biome_counts.is_empty():
						var preferred_biome_id := str(current.get("biome_id", ""))
						var dominant_biome_id := preferred_biome_id if biome_counts.has(preferred_biome_id) else ""
						var dominant_count := int(biome_counts.get(dominant_biome_id, 0))
						for biome_id_value in biome_counts.keys():
							var biome_id := str(biome_id_value)
							var count := int(biome_counts.get(biome_id, 0))
							if dominant_biome_id.is_empty() or count > dominant_count:
								dominant_biome_id = biome_id
								dominant_count = count
						if not dominant_biome_id.is_empty():
							replacement = {
								"biome_id": dominant_biome_id,
								"terrain_id": "land",
								"layer_id": _get_layer_id(dominant_biome_id, "land"),
								"source": "visual_surface_grid_gap_fill"
							}
							changed = true
				next_row.append(replacement)
			next_grid.append(next_row)
		visual_surface_grid = next_grid
		if not changed:
			return

func _is_water_gap_surface(surface: Dictionary) -> bool:
	var terrain_id := str(surface.get("terrain_id", ""))
	return terrain_id in ["deep_ocean", "shallow_water", "shore"]

func _is_landlike_surface(surface: Dictionary) -> bool:
	var terrain_id := str(surface.get("terrain_id", ""))
	return terrain_id in ["land", "highland", "rocky_patch", "wetland"]

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

func _get_layer_draw_order(polygons_by_layer: Dictionary) -> Array[String]:
	var ordered: Array[String] = [
		"terrain:deep_ocean",
		"terrain:shallow_water",
		"terrain:shore"
	]
	var biome_layers: Array[String] = []
	var other_layers: Array[String] = []
	for layer_id in polygons_by_layer.keys():
		var layer := str(layer_id)
		if ordered.has(layer):
			continue
		if layer.begins_with("biome:") and layer.ends_with("|terrain:land"):
			biome_layers.append(layer)
		else:
			other_layers.append(layer)
	biome_layers.sort()
	var wetland_layers: Array[String] = []
	var rocky_layers: Array[String] = []
	var highland_layers: Array[String] = []
	var pond_layers: Array[String] = []
	var remaining_other: Array[String] = []
	for layer in other_layers:
		if layer.ends_with("|terrain:wetland"):
			wetland_layers.append(layer)
		elif layer.ends_with("|terrain:rocky_patch"):
			rocky_layers.append(layer)
		elif layer.ends_with("|terrain:highland"):
			highland_layers.append(layer)
		elif layer.ends_with("|terrain:pond") or layer == "terrain:pond":
			pond_layers.append(layer)
		else:
			remaining_other.append(layer)
	ordered.append_array(biome_layers)
	ordered.append_array(wetland_layers)
	ordered.append_array(rocky_layers)
	ordered.append_array(highland_layers)
	ordered.append_array(pond_layers)
	remaining_other.sort()
	ordered.append_array(remaining_other)
	return ordered

func _get_sample_order() -> Array[String]:
	var draw_order := _get_layer_draw_order(polygons_by_layer)
	draw_order.reverse()
	return draw_order

func _get_polygon_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var rect := Rect2(points[0], Vector2.ZERO)
	for p in points:
		rect = rect.expand(p)
	return rect

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

func _visual_world_to_grid(position: Vector2) -> Vector2i:
	var local := position - world_rect.position
	return Vector2i(
		clampi(int(floor(local.x / visual_surface_sample_size)), 0, visual_surface_grid_size.x - 1),
		clampi(int(floor(local.y / visual_surface_sample_size)), 0, visual_surface_grid_size.y - 1)
	)

func _visual_grid_to_world_center(x: int, y: int) -> Vector2:
	return world_rect.position + Vector2(
		(float(x) + 0.5) * visual_surface_sample_size,
		(float(y) + 0.5) * visual_surface_sample_size
	)

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
