extends RefCounted
class_name TerrainConditionMap

var seed: int = 0
var world_rect: Rect2 = Rect2()
var grid_size := Vector2i.ZERO
var cell_size: float = 64.0
var height_map: Array[Array] = []
var moisture_map: Array[Array] = []
var vegetation_density_map: Array[Array] = []
var danger_map: Array[Array] = []
var distance_to_shore_map: Array[Array] = []
var moisture_raw_map: Array[Array] = []


func build(p_seed: int, p_world_rect: Rect2, generator: Object, p_cell_size: float = 64.0) -> void:
	seed = p_seed
	world_rect = p_world_rect
	cell_size = maxf(p_cell_size, 1.0)
	grid_size = Vector2i(
		maxi(1, int(ceil(world_rect.size.x / cell_size))),
		maxi(1, int(ceil(world_rect.size.y / cell_size)))
	)
	height_map = []
	moisture_map = []
	vegetation_density_map = []
	danger_map = []
	distance_to_shore_map = []
	moisture_raw_map = []
	for y in range(grid_size.y):
		var height_row: Array = []
		var moisture_row: Array = []
		var moisture_raw_row: Array = []
		var vegetation_row: Array = []
		var danger_row: Array = []
		var shore_row: Array = []
		for x in range(grid_size.x):
			var position := get_cell_world_position(x, y)
			height_row.append(generator.get_height_at(position))
			var moisture_raw := float(generator.get_moisture_at(position))
			var moisture := moisture_raw
			if generator.has_method("get_moisture01_at"):
				moisture = float(generator.get_moisture01_at(position))
			else:
				moisture = clampf(moisture_raw * 0.5 + 0.5, 0.0, 1.0)
			moisture_raw_row.append(moisture_raw)
			moisture_row.append(moisture)
			vegetation_row.append(generator.get_vegetation_density_at(position))
			danger_row.append(generator.get_danger_at(position))
			shore_row.append(generator.get_distance_to_shore_at(position))
		height_map.append(height_row)
		moisture_map.append(moisture_row)
		moisture_raw_map.append(moisture_raw_row)
		vegetation_density_map.append(vegetation_row)
		danger_map.append(danger_row)
		distance_to_shore_map.append(shore_row)


func get_cell_world_position(x: int, y: int) -> Vector2:
	return Vector2(
		lerpf(world_rect.position.x, world_rect.end.x, (float(x) + 0.5) / float(grid_size.x)),
		lerpf(world_rect.position.y, world_rect.end.y, (float(y) + 0.5) / float(grid_size.y))
	)


func sample_at_world_position(position: Vector2) -> Dictionary:
	if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		return {}
	var tx := clampf((position.x - world_rect.position.x) / world_rect.size.x, 0.0, 0.999999)
	var ty := clampf((position.y - world_rect.position.y) / world_rect.size.y, 0.0, 0.999999)
	var x := clampi(int(tx * float(grid_size.x)), 0, grid_size.x - 1)
	var y := clampi(int(ty * float(grid_size.y)), 0, grid_size.y - 1)
	return get_cell(x, y)


func get_cell(x: int, y: int) -> Dictionary:
	if x < 0 or y < 0 or x >= grid_size.x or y >= grid_size.y:
		return {}
	return {
		"height": float(Array(height_map[y])[x]),
		"moisture": float(Array(moisture_map[y])[x]),
		"moisture_raw": float(Array(moisture_raw_map[y])[x]) if moisture_raw_map.size() > y and Array(moisture_raw_map[y]).size() > x else 0.0,
		"vegetation_density": float(Array(vegetation_density_map[y])[x]),
		"danger": float(Array(danger_map[y])[x]),
		"distance_to_shore": float(Array(distance_to_shore_map[y])[x])
	}
