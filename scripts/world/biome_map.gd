extends RefCounted
class_name BiomeMap

const BIOME_RULES := preload("res://scripts/world/biome_rules.gd")

var seed: int = 0
var world_rect: Rect2 = Rect2()
var terrain_condition_map = null
var biome_id_by_cell: Array[Array] = []
var biome_regions: Array[Dictionary] = []
var cell_size: float = 128.0


func build(p_seed: int, p_world_rect: Rect2, generator: Object, p_cell_size: float = 128.0) -> void:
	seed = p_seed
	world_rect = p_world_rect
	cell_size = p_cell_size
	terrain_condition_map = TerrainConditionMap.new()
	terrain_condition_map.build(seed, world_rect, generator, 64.0)
	var grid_size: Vector2i = terrain_condition_map.grid_size
	biome_id_by_cell = []
	var region_counts: Dictionary = {}
	var region_bounds: Dictionary = {}
	for y in range(grid_size.y):
		var row: Array = []
		for x in range(grid_size.x):
			var conditions = terrain_condition_map.get_cell(x, y)
			var biome_id := str(BIOME_RULES.pick_biome_id(BIOME_RULES.score_biomes(conditions)))
			row.append(biome_id)
			region_counts[biome_id] = int(region_counts.get(biome_id, 0)) + 1
			var world_pos: Vector2 = terrain_condition_map.get_cell_world_position(x, y)
			if not region_bounds.has(biome_id):
				region_bounds[biome_id] = Rect2(world_pos, Vector2.ZERO)
			else:
				region_bounds[biome_id] = Rect2(region_bounds[biome_id]).expand(world_pos)
		biome_id_by_cell.append(row)
	_smooth_regions()
	_remove_tiny_regions(18)
	_rebuild_regions()


func get_biome_id_at_world_position(position: Vector2) -> String:
	if biome_id_by_cell.is_empty() or world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		return "hearth_meadow"
	var tx := clampf((position.x - world_rect.position.x) / world_rect.size.x, 0.0, 0.999999)
	var ty := clampf((position.y - world_rect.position.y) / world_rect.size.y, 0.0, 0.999999)
	var x := clampi(int(tx * float(terrain_condition_map.grid_size.x)), 0, terrain_condition_map.grid_size.x - 1)
	var y := clampi(int(ty * float(terrain_condition_map.grid_size.y)), 0, terrain_condition_map.grid_size.y - 1)
	return str(Array(biome_id_by_cell[y])[x])


func get_visual_biome_id_at_world_position(position: Vector2) -> String:
	return get_biome_id_at_world_position(position)


func get_regions() -> Array[Dictionary]:
	return biome_regions.duplicate(true)


func get_debug_data() -> Dictionary:
	var counts: Dictionary = {}
	for row in biome_id_by_cell:
		for biome_id in row:
			counts[str(biome_id)] = int(counts.get(str(biome_id), 0)) + 1
	return {
		"seed": seed,
		"biome_count_by_type": counts,
		"biome_region_count": biome_regions.size(),
		"small_biome_region_count": _count_small_regions(),
		"shoreline_cell_count": _count_shoreline_cells(),
		"transition_zone_count": _count_transition_cells(),
		"dominant_biome": _get_dominant_biome(counts),
	}


func _smooth_regions() -> void:
	if biome_id_by_cell.is_empty():
		return
	var smoothed: Array[Array] = []
	for y in range(biome_id_by_cell.size()):
		var row: Array = []
		for x in range(Array(biome_id_by_cell[y]).size()):
			var counts: Dictionary = {}
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var sy := clampi(y + oy, 0, biome_id_by_cell.size() - 1)
					var sx := clampi(x + ox, 0, Array(biome_id_by_cell[sy]).size() - 1)
					var biome_id := str(Array(biome_id_by_cell[sy])[sx])
					counts[biome_id] = int(counts.get(biome_id, 0)) + 1
			row.append(_dominant_key(counts))
		smoothed.append(row)
	biome_id_by_cell = smoothed


func _remove_tiny_regions(min_cells: int) -> void:
	if biome_id_by_cell.is_empty():
		return
	var visited: Dictionary = {}
	for y in range(biome_id_by_cell.size()):
		for x in range(Array(biome_id_by_cell[y]).size()):
			var start := Vector2i(x, y)
			if visited.has(start):
				continue
			var target := str(Array(biome_id_by_cell[y])[x])
			var stack: Array[Vector2i] = [start]
			var component: Array[Vector2i] = []
			while not stack.is_empty():
				var cell: Vector2i = stack.pop_back()
				if visited.has(cell):
					continue
				visited[cell] = true
				if str(Array(biome_id_by_cell[cell.y])[cell.x]) != target:
					continue
				component.append(cell)
				for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					var nx: int = cell.x + offset.x
					var ny: int = cell.y + offset.y
					if ny < 0 or ny >= biome_id_by_cell.size():
						continue
					var row: Array = Array(biome_id_by_cell[ny])
					if nx < 0 or nx >= row.size():
						continue
					var neighbor := Vector2i(nx, ny)
					if not visited.has(neighbor):
						stack.append(neighbor)
			if component.size() >= min_cells:
				continue
			var replacement: String = _get_dominant_neighbor_biome(component)
			for cell in component:
				if replacement.is_empty():
					break
				Array(biome_id_by_cell[cell.y])[cell.x] = replacement


func _rebuild_regions() -> void:
	var counts: Dictionary = {}
	var bounds: Dictionary = {}
	for y in range(biome_id_by_cell.size()):
		for x in range(Array(biome_id_by_cell[y]).size()):
			var biome_id := str(Array(biome_id_by_cell[y])[x])
			counts[biome_id] = int(counts.get(biome_id, 0)) + 1
			var world_pos: Vector2 = terrain_condition_map.get_cell_world_position(x, y)
			if not bounds.has(biome_id):
				bounds[biome_id] = Rect2(world_pos, Vector2.ZERO)
			else:
				bounds[biome_id] = Rect2(bounds[biome_id]).expand(world_pos)
	biome_regions = []
	for biome_id in counts.keys():
		biome_regions.append({"id": biome_id, "name": biome_id.capitalize().replace("_", " "), "bounds": bounds[biome_id], "sample_count": counts[biome_id]})


func _dominant_key(counts: Dictionary) -> String:
	var best := ""
	var best_count := -1
	for key in counts.keys():
		var count := int(counts[key])
		if count > best_count:
			best_count = count
			best = str(key)
	return best


func _get_dominant_neighbor_biome(component: Array[Vector2i]) -> String:
	var neighbor_counts: Dictionary = {}
	for cell in component:
		for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var nx: int = cell.x + offset.x
			var ny: int = cell.y + offset.y
			if ny < 0 or ny >= biome_id_by_cell.size():
				continue
			var row: Array = Array(biome_id_by_cell[ny])
			if nx < 0 or nx >= row.size():
				continue
			var biome_id := str(row[nx])
			neighbor_counts[biome_id] = int(neighbor_counts.get(biome_id, 0)) + 1
	return _dominant_key(neighbor_counts)


func _count_small_regions() -> int:
	var count := 0
	for region in biome_regions:
		if int(Dictionary(region).get("sample_count", 0)) < 18:
			count += 1
	return count


func _count_shoreline_cells() -> int:
	if terrain_condition_map == null:
		return 0
	var count := 0
	for y in range(terrain_condition_map.grid_size.y):
		for x in range(terrain_condition_map.grid_size.x):
			if float(Dictionary(terrain_condition_map.get_cell(x, y)).get("distance_to_shore", 1.0)) <= 0.18:
				count += 1
	return count


func _count_transition_cells() -> int:
	if biome_id_by_cell.is_empty():
		return 0
	var count := 0
	for y in range(biome_id_by_cell.size()):
		for x in range(Array(biome_id_by_cell[y]).size()):
			var biome_id := str(Array(biome_id_by_cell[y])[x])
			var neighbor_match := 0
			for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var nx: int = x + offset.x
				var ny: int = y + offset.y
				if ny < 0 or ny >= biome_id_by_cell.size():
					continue
				var row: Array = Array(biome_id_by_cell[ny])
				if nx < 0 or nx >= row.size():
					continue
				if str(row[nx]) == biome_id:
					neighbor_match += 1
			if neighbor_match < 4:
				count += 1
	return count


func _get_dominant_biome(counts: Dictionary) -> String:
	return _dominant_key(counts)
