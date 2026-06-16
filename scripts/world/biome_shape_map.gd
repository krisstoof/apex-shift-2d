extends RefCounted
class_name BiomeShapeMap

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")

var world_rect := Rect2()
var sample_size := 96.0
var grid_size := Vector2i.ZERO
var seed := 0
var polygons_by_layer: Dictionary = {}
var details: Array[Dictionary] = []
var build_count := 0
var last_build_ms := 0.0
var last_polygon_count := 0
var last_detail_count := 0
var last_key := ""

func build(assigned_world_rect: Rect2, world_generator: RefCounted, world_topography: RefCounted, assigned_seed: int) -> void:
	var start_ms := Time.get_ticks_msec()
	world_rect = assigned_world_rect
	seed = assigned_seed
	sample_size = maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("biome_shape_sample_size", 96.0)), 32.0)
	grid_size = Vector2i(maxi(2, int(ceil(world_rect.size.x / sample_size))), maxi(2, int(ceil(world_rect.size.y / sample_size))))
	polygons_by_layer.clear()
	details.clear()
	var layer_points: Dictionary = {}
	for y in range(grid_size.y):
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
			var layer := _get_layer_id(biome_id, terrain_id)
			if not layer_points.has(layer):
				layer_points[layer] = []
			Array(layer_points[layer]).append(pos + _jitter(pos))
			if bool(GAME_BALANCE.BIOME_TEXTURES.get("biome_shape_detail_enabled", true)) and details.size() < int(GAME_BALANCE.BIOME_TEXTURES.get("biome_shape_detail_max_visible", 260)):
				if ((x + y) % 4) == 0 and terrain_id not in ["deep_ocean", "shallow_water", "shore", "pond"]:
					details.append({"position": pos, "biome_id": biome_id, "terrain_id": terrain_id, "variant": int(abs(_hash_int(x, y))) % 6})
	for layer_id in layer_points.keys():
		var hull := _convex_hull(Array(layer_points[layer_id]))
		if hull.size() < 3:
			continue
		if not polygons_by_layer.has(layer_id):
			polygons_by_layer[layer_id] = []
		Array(polygons_by_layer[layer_id]).append({
			"layer_id": layer_id,
			"biome_id": _get_biome_id_from_layer(layer_id),
			"terrain_id": _get_terrain_id_from_layer(layer_id),
			"points": hull
		})
	build_count += 1
	last_build_ms = float(Time.get_ticks_msec() - start_ms)
	last_polygon_count = _count_polygons()
	last_detail_count = details.size()
	last_key = "shape_map|seed=%d|grid=%s|polys=%d|details=%d" % [seed, str(grid_size), last_polygon_count, last_detail_count]

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
		"biome_shape_map_key": last_key
	}

func _get_layer_id(biome_id: String, terrain_id: String) -> String:
	if terrain_id in ["deep_ocean", "shallow_water", "shore", "pond"]:
		return "terrain:%s" % terrain_id
	if terrain_id in ["highland", "rocky_patch", "wetland"]:
		return "biome:%s|terrain:%s" % [biome_id, terrain_id]
	return "biome:%s|terrain:land" % biome_id

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

func _convex_hull(points: Array) -> PackedVector2Array:
	var pts: Array[Vector2] = []
	for p in points:
		if typeof(p) == TYPE_VECTOR2:
			pts.append(p)
	pts.sort_custom(func(a, b): return a.x < b.x or (is_equal_approx(a.x, b.x) and a.y < b.y))
	if pts.size() <= 2:
		return PackedVector2Array(pts)
	var lower: Array[Vector2] = []
	for p in pts:
		while lower.size() >= 2 and _cross(lower[lower.size() - 2], lower[lower.size() - 1], p) <= 0.0:
			lower.pop_back()
		lower.append(p)
	var upper: Array[Vector2] = []
	for i in range(pts.size() - 1, -1, -1):
		var p := pts[i]
		while upper.size() >= 2 and _cross(upper[upper.size() - 2], upper[upper.size() - 1], p) <= 0.0:
			upper.pop_back()
		upper.append(p)
	lower.pop_back()
	upper.pop_back()
	return PackedVector2Array(lower + upper)

func _cross(o: Vector2, a: Vector2, b: Vector2) -> float:
	return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)

func _count_polygons() -> int:
	var count := 0
	for layer_id in polygons_by_layer.keys():
		count += Array(polygons_by_layer[layer_id]).size()
	return count
