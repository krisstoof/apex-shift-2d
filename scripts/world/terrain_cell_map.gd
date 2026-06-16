extends RefCounted
class_name TerrainCellMap

const TERRAIN_IDS := ["deep_ocean", "shallow_water", "shore", "land", "highland", "pond", "rocky_patch", "wetland"]

var cell_size: float = 96.0
var world_rect := Rect2()
var grid_size := Vector2i.ZERO
var cells: Array[Array] = []
var seed: int = 0
var terrain_cell_map_rebuild_count := 0
var terrain_cell_map_last_build_ms := 0.0


func build(assigned_world_rect: Rect2, assigned_cell_size: float, world_generator: RefCounted, world_topography: RefCounted, assigned_seed: int) -> void:
	var start_ms := Time.get_ticks_msec()
	world_rect = assigned_world_rect
	cell_size = maxf(assigned_cell_size, 32.0)
	seed = assigned_seed
	grid_size = Vector2i(
		maxi(1, int(ceil(world_rect.size.x / cell_size))),
		maxi(1, int(ceil(world_rect.size.y / cell_size)))
	)
	cells.clear()
	for y in range(grid_size.y):
		var row: Array = []
		for x in range(grid_size.x):
			var world_position := get_cell_world_center(x, y)
			var terrain_id := "land"
			var biome_id := "hearth_meadow"
			var variant := _hash_variant(x, y, terrain_id, biome_id)
			var edge_mask := 0
			if world_generator != null:
				if world_generator.has_method("get_base_terrain_zone"):
					terrain_id = str(world_generator.get_base_terrain_zone(world_position))
				if world_generator.has_method("get_visual_biome_id_at"):
					biome_id = str(world_generator.get_visual_biome_id_at(world_position))
				elif world_generator.has_method("get_biome_id_at"):
					biome_id = str(world_generator.get_biome_id_at(world_position))
			if world_topography != null and world_topography.has_method("sample_topography_at"):
				var sample := Dictionary(world_topography.sample_topography_at(world_position))
				var topo_terrain := str(sample.get("terrain_zone", terrain_id))
				if not topo_terrain.is_empty():
					terrain_id = topo_terrain
				edge_mask = _get_edge_mask(sample)
			var cell := {
				"terrain_id": terrain_id,
				"biome_id": biome_id,
				"variant": variant,
				"edge_mask": edge_mask,
				"detail_seed": _hash_int(seed, x, y, biome_id, terrain_id)
			}
			row.append(cell)
		cells.append(row)
	terrain_cell_map_rebuild_count += 1
	terrain_cell_map_last_build_ms = float(Time.get_ticks_msec() - start_ms)


func get_cell_at_world_position(position: Vector2) -> Dictionary:
	if not world_rect.has_point(position) or cells.is_empty():
		return {}
	var local := position - world_rect.position
	var x := clampi(int(floor(local.x / cell_size)), 0, grid_size.x - 1)
	var y := clampi(int(floor(local.y / cell_size)), 0, grid_size.y - 1)
	return get_cell(x, y)


func get_cell(x: int, y: int) -> Dictionary:
	if y < 0 or y >= cells.size():
		return {}
	var row := Array(cells[y])
	if x < 0 or x >= row.size():
		return {}
	return Dictionary(row[x])


func get_grid_size() -> Vector2i:
	return grid_size


func get_cell_world_rect(x: int, y: int) -> Rect2:
	return Rect2(world_rect.position + Vector2(x * cell_size, y * cell_size), Vector2(cell_size, cell_size))


func get_cell_world_center(x: int, y: int) -> Vector2:
	var rect := get_cell_world_rect(x, y)
	return rect.position + rect.size * 0.5


func get_debug_data() -> Dictionary:
	return {
		"terrain_cell_map_cell_count": grid_size.x * grid_size.y,
		"terrain_cell_size": cell_size,
		"terrain_grid_size": grid_size,
		"terrain_render_mode": "cell_map",
		"terrain_cell_map_rebuild_count": terrain_cell_map_rebuild_count,
		"terrain_cell_map_last_build_ms": terrain_cell_map_last_build_ms
	}


func _get_edge_mask(sample: Dictionary) -> int:
	var mask := 0
	if sample.get("terrain_zone", "") in ["pond", "rocky_patch", "wetland", "highland"]:
		mask |= 1
	return mask


func _hash_variant(x: int, y: int, biome_id: String, terrain_id: String) -> int:
	return abs(_hash_int(seed, x, y, biome_id, terrain_id)) % 6


func _hash_int(p_seed: int, x: int, y: int, biome_id: String, terrain_id: String) -> int:
	var text := "%d|%d|%d|%s|%s" % [p_seed, x, y, biome_id, terrain_id]
	var hash_value := 0
	for character in text:
		hash_value = int((hash_value * 31 + character.unicode_at(0)) & 0x7fffffff)
	return hash_value
