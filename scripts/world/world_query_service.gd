extends RefCounted
class_name WorldQueryService

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")

var world
var plant_resource_kinds: Array[String] = []
var hill_resource_block_radius_factor := 0.72
var hill_visual_y_scale := 0.58
var pond_visual_y_scale := 0.62
var water_zone_land := "land"
var water_zone_highland := "highland"
var water_zone_shore := "shore"
var water_zone_shallow := "shallow_water"
var water_zone_deep := "deep_ocean"


func bind_world(
	p_world,
	p_plant_resource_kinds: Array = [],
	p_hill_resource_block_radius_factor := 0.72,
	p_hill_visual_y_scale := 0.58,
	p_pond_visual_y_scale := 0.62,
	p_water_zone_land := "land",
	p_water_zone_highland := "highland",
	p_water_zone_shore := "shore",
	p_water_zone_shallow := "shallow_water",
	p_water_zone_deep := "deep_ocean"
) -> WorldQueryService:
	world = p_world
	plant_resource_kinds.clear()
	for resource_kind in p_plant_resource_kinds:
		plant_resource_kinds.append(str(resource_kind))
	hill_resource_block_radius_factor = p_hill_resource_block_radius_factor
	hill_visual_y_scale = p_hill_visual_y_scale
	pond_visual_y_scale = p_pond_visual_y_scale
	water_zone_land = p_water_zone_land
	water_zone_highland = p_water_zone_highland
	water_zone_shore = p_water_zone_shore
	water_zone_shallow = p_water_zone_shallow
	water_zone_deep = p_water_zone_deep
	return self


func get_terrain_speed_multiplier(position: Vector2) -> float:
	match get_water_zone(position):
		water_zone_deep:
			return _get_pond_deep_speed_multiplier()
		water_zone_shallow:
			return _get_pond_shallow_speed_multiplier()
	return 1.0


func get_water_zone(position: Vector2) -> String:
	var terrain_zone := WORLD_CONFIG.get_terrain_zone(position)
	if terrain_zone == "deep_ocean":
		return water_zone_deep
	if terrain_zone == "shallow_water":
		return water_zone_shallow
	if terrain_zone == "shore":
		return water_zone_shore
	var best_zone := water_zone_highland if terrain_zone == "highland" else water_zone_land
	var search_radius := _get_pond_water_search_radius()
	if search_radius <= 0.0:
		return best_zone
	for pond_value in _get_pond_landmarks():
		var pond := Dictionary(pond_value)
		var pond_pos := Vector2(pond.get("position", Vector2.ZERO))
		var distance_to_pond := position.distance_to(pond_pos)
		if distance_to_pond > search_radius:
			continue
		var zone := _get_pond_water_zone(position, pond)
		if zone == water_zone_deep:
			return water_zone_deep
		if zone == water_zone_shallow:
			best_zone = water_zone_shallow
		elif zone == water_zone_shore and best_zone == water_zone_land:
			best_zone = water_zone_shore
	return best_zone


func is_position_in_water(position: Vector2) -> bool:
	var zone := get_water_zone(position)
	return zone == water_zone_deep or zone == water_zone_shallow


func is_position_in_deep_water(position: Vector2) -> bool:
	return get_water_zone(position) == water_zone_deep


func is_position_inside_world_boundary(position: Vector2) -> bool:
	return not _is_outside_world_boundary(position)


func is_resource_position_blocked_by_water(resource_kind: String, position: Vector2) -> bool:
	if not _is_plant_resource_kind(resource_kind):
		return false
	var terrain_zone := WORLD_CONFIG.get_terrain_zone(position)
	if terrain_zone in ["deep_ocean", "shallow_water"]:
		return true
	if terrain_zone == "shore":
		return true
	var margin_multiplier := _get_resource_water_margin_multiplier(resource_kind)
	for pond_value in _get_pond_landmarks():
		var pond := Dictionary(pond_value)
		if _is_position_in_pond_water(position, pond, margin_multiplier):
			return true
	return false


func is_creature_navigation_blocked(position: Vector2) -> bool:
	if is_position_in_deep_water(position):
		return true
	for hill_value in _get_hill_landmarks():
		var hill := Dictionary(hill_value)
		if _is_position_in_hill_obstacle(position, hill):
			return true
	return false


func is_creature_spawn_blocked_by_water(position: Vector2) -> bool:
	var terrain_zone := WORLD_CONFIG.get_terrain_zone(position)
	return terrain_zone in ["deep_ocean", "shallow_water", "shore"]


func _get_pond_landmarks() -> Array:
	if world == null:
		return []
	return Array(world.get("pond_landmarks"))


func _get_hill_landmarks() -> Array:
	if world == null:
		return []
	return Array(world.get("hill_landmarks"))


func _get_pond_water_search_radius() -> float:
	if world == null:
		return 0.0
	return float(world.get("pond_water_search_radius"))


func _is_position_in_pond_water(position: Vector2, pond: Dictionary, margin_multiplier: float = 1.0) -> bool:
	return _get_pond_water_ratio(position, pond) <= margin_multiplier


func _get_pond_water_ratio(position: Vector2, pond: Dictionary) -> float:
	var center := Vector2(pond.get("position", Vector2.ZERO))
	var radius := float(pond.get("radius", 0.0))
	if radius <= 0.0:
		return INF
	var offset := position - center
	var normalized := Vector2(offset.x / radius, offset.y / (radius * pond_visual_y_scale))
	var shape_scale := _get_pond_shape_scale(pond, normalized.angle())
	return normalized.length() / max(shape_scale, 0.1)


func _get_pond_shape_scale(pond: Dictionary, angle: float) -> float:
	var irregularity := _get_pond_shape_irregularity()
	if irregularity <= 0.0:
		return 1.0
	var seed := _get_pond_shape_seed(pond)
	var wave := (
		sin(angle * 2.0 + seed) * 0.55
		+ sin(angle * 3.0 - seed * 1.7) * 0.32
		+ sin(angle * 5.0 + seed * 0.6) * 0.18
	) / 1.05
	return clamp(1.0 + wave * irregularity, 1.0 - irregularity * 1.25, 1.0 + irregularity * 1.25)


func _get_pond_shape_seed(pond: Dictionary) -> float:
	var pond_id := str(pond.get("id", "pond"))
	var seed := 0
	for i in pond_id.length():
		seed = (seed + pond_id.unicode_at(i) * (i + 3)) % 997
	return float(seed) / 997.0 * TAU


func _get_pond_shape_irregularity() -> float:
	return float(clamp(float(GAME_BALANCE.LANDMARKS.get("pond_shape_irregularity", 0.16)), 0.0, 0.45))


func _get_pond_water_zone(position: Vector2, pond: Dictionary) -> String:
	var ratio := _get_pond_water_ratio(position, pond)
	if ratio <= _get_pond_deep_water_radius_factor():
		return water_zone_deep
	if ratio <= _get_pond_shallow_water_radius_factor():
		return water_zone_shallow
	if ratio <= _get_pond_shore_radius_factor():
		return water_zone_shore
	return water_zone_land


func _get_pond_deep_water_radius_factor() -> float:
	return float(GAME_BALANCE.LANDMARKS.get("pond_deep_water_radius_factor", 0.68))


func _get_pond_shallow_water_radius_factor() -> float:
	return float(GAME_BALANCE.LANDMARKS.get("pond_shallow_water_radius_factor", 1.0))


func _get_pond_shore_radius_factor() -> float:
	return float(GAME_BALANCE.LANDMARKS.get("pond_shore_radius_factor", 1.12))


func _get_pond_deep_speed_multiplier() -> float:
	return float(GAME_BALANCE.LANDMARKS.get("pond_deep_speed_multiplier", 0.42))


func _get_pond_shallow_speed_multiplier() -> float:
	return float(GAME_BALANCE.LANDMARKS.get("pond_shallow_speed_multiplier", 0.68))


func _get_resource_water_margin_multiplier(resource_kind: String) -> float:
	match resource_kind:
		"conifer_tree", "leafy_tree", "tree":
			return float(GAME_BALANCE.LANDMARKS.get("pond_tree_water_margin", 1.22))
		"bush", "dry_bush", "small_bush", "berry_bush":
			return float(GAME_BALANCE.LANDMARKS.get("pond_bush_water_margin", 1.12))
		"grass_patch", "dense_grass":
			return float(GAME_BALANCE.LANDMARKS.get("pond_grass_water_margin", 1.04))
	return 1.0


func _is_position_in_hill_obstacle(position: Vector2, hill: Dictionary) -> bool:
	return _get_hill_shape_ratio(position, hill) <= hill_resource_block_radius_factor


func _is_outside_world_boundary(position: Vector2) -> bool:
	var boundary_points := WORLD_CONFIG.get_world_boundary_points()
	if boundary_points.size() < 3:
		return false
	return not Geometry2D.is_point_in_polygon(position, boundary_points)


func _get_hill_shape_ratio(position: Vector2, hill: Dictionary) -> float:
	var center := Vector2(hill.get("position", Vector2.ZERO))
	var radius := float(hill.get("radius", 0.0))
	if radius <= 0.0:
		return INF
	var offset := position - center
	var normalized := Vector2(offset.x / radius, offset.y / (radius * hill_visual_y_scale))
	var shape_scale := _get_hill_shape_scale(hill, normalized.angle())
	return normalized.length() / max(shape_scale, 0.1)


func _get_hill_shape_scale(hill: Dictionary, angle: float) -> float:
	var irregularity := _get_hill_shape_irregularity()
	if irregularity <= 0.0:
		return 1.0
	var seed := _get_hill_shape_seed(hill)
	var wave := (
		sin(angle * 2.0 + seed) * 0.50
		+ sin(angle * 4.0 - seed * 1.35) * 0.28
		+ sin(angle * 6.0 + seed * 0.4) * 0.16
	) / 0.94
	return clamp(1.0 + wave * irregularity, 1.0 - irregularity * 1.15, 1.0 + irregularity * 1.15)


func _get_hill_shape_seed(hill: Dictionary) -> float:
	var hill_id := str(hill.get("id", "hill"))
	var seed := 0
	for i in hill_id.length():
		seed = (seed + hill_id.unicode_at(i) * (i + 5)) % 997
	return float(seed) / 997.0 * TAU


func _get_hill_shape_irregularity() -> float:
	return float(clamp(float(GAME_BALANCE.LANDMARKS.get("hill_shape_irregularity", 0.10)), 0.0, 0.35))


func _is_plant_resource_kind(resource_kind: String) -> bool:
	return resource_kind in plant_resource_kinds
