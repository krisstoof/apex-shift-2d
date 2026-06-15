extends RefCounted
class_name WorldTopography

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")

var seed: int = 1
var pond_noise := FastNoiseLite.new()
var ridge_noise := FastNoiseLite.new()
var wetland_noise := FastNoiseLite.new()
var rocky_noise := FastNoiseLite.new()

const POND_THRESHOLD := 0.48
const WETLAND_THRESHOLD := 0.66
const RIDGE_THRESHOLD := 0.86
const ROCKY_PATCH_THRESHOLD := 0.62
const TOPOGRAPHY_RULES_VERSION := "v3"

func setup(p_seed: int) -> void:
	seed = p_seed if p_seed != 0 else 1
	pond_noise.seed = seed + 1101
	pond_noise.frequency = 0.0018
	ridge_noise.seed = seed + 2202
	ridge_noise.frequency = 0.0018
	wetland_noise.seed = seed + 3303
	wetland_noise.frequency = 0.0032
	rocky_noise.seed = seed + 4404
	rocky_noise.frequency = 0.0038


func get_base_terrain_zone(position: Vector2) -> String:
	return WORLD_CONFIG.get_terrain_zone(position)


func get_topography_zone(position: Vector2) -> String:
	var base_zone := get_base_terrain_zone(position)
	if base_zone in ["deep_ocean", "shallow_water", "shore"]:
		return base_zone
	if is_pond_at(position):
		return "pond"
	if is_wetland_at(position):
		return "wetland"
	if is_ridge_at(position):
		return "ridge"
	if is_rocky_patch_at(position):
		return "rocky_patch"
	if base_zone == "highland":
		return "highland"
	return "land"


func get_pond_value(position: Vector2) -> float:
	var base_zone := get_base_terrain_zone(position)
	if base_zone not in ["land", "highland"]:
		return -999.0
	var height := WORLD_CONFIG.get_terrain_height(position)
	var moisture := wetland_noise.get_noise_2d(position.x, position.y)
	var pond_shape := pond_noise.get_noise_2d(position.x, position.y)
	var basin_bias: float = 1.0 - abs(height - 0.34)
	return pond_shape * 0.55 + moisture * 0.30 + basin_bias * 0.15


func is_pond_at(position: Vector2) -> bool:
	return get_base_terrain_zone(position) == "land" and get_pond_value(position) > POND_THRESHOLD


func is_near_pond(position: Vector2, radius: float = 90.0) -> bool:
	var samples := [
		Vector2.ZERO,
		Vector2(radius, 0.0),
		Vector2(-radius, 0.0),
		Vector2(0.0, radius),
		Vector2(0.0, -radius)
	]
	for offset in samples:
		if is_pond_at(position + offset):
			return true
	return false


func get_ridge_value(position: Vector2) -> float:
	var base_zone := get_base_terrain_zone(position)
	if base_zone not in ["land", "highland"]:
		return -999.0
	var height := WORLD_CONFIG.get_terrain_height(position)
	var ridge := ridge_noise.get_noise_2d(position.x, position.y)
	return height * 0.65 + ridge * 0.35


func is_ridge_at(position: Vector2) -> bool:
	return get_ridge_value(position) > RIDGE_THRESHOLD


func is_rocky_patch_at(position: Vector2) -> bool:
	var base_zone := get_base_terrain_zone(position)
	if base_zone not in ["land", "highland"]:
		return false
	var value := rocky_noise.get_noise_2d(position.x, position.y)
	return value > ROCKY_PATCH_THRESHOLD


func is_wetland_at(position: Vector2) -> bool:
	var base_zone := get_base_terrain_zone(position)
	if base_zone not in ["land", "highland"]:
		return false
	var moisture := wetland_noise.get_noise_2d(position.x, position.y)
	return moisture > WETLAND_THRESHOLD and not is_pond_at(position)
