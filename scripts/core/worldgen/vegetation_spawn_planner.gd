extends RefCounted
class_name VegetationSpawnPlanner

const BiomeProfiles := preload("res://scripts/core/worldgen/biome_vegetation_profiles.gd")
const SpawnPlanItem := preload("res://scripts/core/worldgen/vegetation_spawn_plan_item.gd")
const DistributionValidator := preload("res://scripts/core/worldgen/vegetation_distribution_validator.gd")

const TREE_KINDS := {"conifer_tree": true, "leafy_tree": true, "dry_tree": true}
const BUSH_KINDS := {"bush": true, "dry_bush": true, "small_bush": true, "berry_bush": true}
const DECORATIVE_KINDS := {"grass_patch": true, "dense_grass": true, "reed": true}

var rng := RandomNumberGenerator.new()
var min_distance_default := 90.0
var player_safe_distance := 260.0
var max_attempts_per_biome := 800
var debug_distribution_by_biome: Dictionary = {}
var debug_distribution_by_kind: Dictionary = {}
var debug_rejections_by_reason: Dictionary = {}
var _last_plan: Array = []


func set_seed(seed_value: int) -> void:
	rng.seed = seed_value


func build_spawn_plan(
	biome_zones: Array,
	world_rect: Rect2,
	terrain_zone_resolver: Callable,
	water_blocker: Callable,
	hill_blocker: Callable,
	total_budget: int,
	player_position: Vector2
) -> Array:
	debug_distribution_by_biome.clear()
	debug_distribution_by_kind.clear()
	debug_rejections_by_reason.clear()
	var plan: Array = []
	var used_positions: Array[Vector2] = []
	for biome_value in biome_zones:
		var biome := Dictionary(biome_value)
		var biome_id := _resolve_biome_id(biome)
		if biome_id.is_empty():
			continue
		var biome_budget := _calculate_biome_budget(biome_id, total_budget, biome_zones.size())
		plan.append_array(_build_plan_for_biome(biome, biome_id, biome_budget, world_rect, terrain_zone_resolver, water_blocker, hill_blocker, player_position, used_positions))
	_last_plan = plan.duplicate(true)
	var validation := DistributionValidator.validate_distribution(_last_plan)
	debug_rejections_by_reason["validation_warning_count"] = Array(validation.get("warnings", [])).size()
	debug_distribution_by_biome = Dictionary(validation.get("by_biome", debug_distribution_by_biome))
	debug_distribution_by_kind = Dictionary(validation.get("by_kind", debug_distribution_by_kind))
	return plan


func _build_plan_for_biome(
	biome: Dictionary,
	biome_id: String,
	budget: int,
	_world_rect: Rect2,
	terrain_zone_resolver: Callable,
	water_blocker: Callable,
	hill_blocker: Callable,
	player_position: Vector2,
	used_positions: Array[Vector2]
) -> Array:
	var result: Array = []
	var bounds := _get_biome_bounds(biome).grow(-24.0)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return result
	var attempts := 0
	while result.size() < budget and attempts < max_attempts_per_biome:
		attempts += 1
		var kind := BiomeProfiles.pick_kind_for_biome(biome_id, rng)
		if kind.is_empty():
			_add_rejection("empty_kind")
			continue
		var candidate := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		if not _is_point_in_biome(candidate, biome):
			_add_rejection("outside_biome")
			continue
		var terrain_zone := "land"
		if terrain_zone_resolver.is_valid():
			terrain_zone = str(terrain_zone_resolver.call(candidate))
		if not _is_terrain_valid_for_kind(kind, terrain_zone):
			_add_rejection("invalid_terrain:%s:%s" % [kind, terrain_zone])
			continue
		if water_blocker.is_valid() and bool(water_blocker.call(kind, candidate)):
			_add_rejection("water_blocked:%s" % kind)
			continue
		if hill_blocker.is_valid() and bool(hill_blocker.call(kind, candidate)):
			_add_rejection("hill_blocked:%s" % kind)
			continue
		if candidate.distance_to(player_position) < player_safe_distance:
			_add_rejection("player_safe_distance")
			continue
		var min_distance := _get_min_distance_for_kind(kind)
		if not _passes_spacing(candidate, used_positions, min_distance):
			_add_rejection("spacing:%s" % kind)
			continue
		used_positions.append(candidate)
		var visual_only := DECORATIVE_KINDS.has(kind)
		var resource_class := "decorative" if visual_only else "interactive"
		var item := SpawnPlanItem.new(kind, candidate, biome_id, terrain_zone, visual_only, resource_class)
		result.append(item)
		_add_distribution(biome_id, kind)
	return result


func _calculate_biome_budget(biome_id: String, total_budget: int, biome_count: int) -> int:
	var base := float(total_budget) / float(maxi(biome_count, 1))
	return maxi(1, int(round(base * BiomeProfiles.get_density_multiplier(biome_id))))


func _resolve_biome_id(biome: Dictionary) -> String:
	if biome.has("id"):
		return str(biome.get("id", ""))
	if biome.has("biome_id"):
		return str(biome.get("biome_id", ""))
	if biome.has("name"):
		return str(biome.get("name", "")).to_lower().replace(" ", "_")
	return ""


func _get_biome_bounds(biome: Dictionary) -> Rect2:
	if biome.has("bounds"):
		return Rect2(biome.get("bounds"))
	var points := PackedVector2Array(biome.get("points", []))
	if points.is_empty():
		return Rect2()
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


func _is_point_in_biome(point: Vector2, biome: Dictionary) -> bool:
	var points := PackedVector2Array(biome.get("points", []))
	return points.size() >= 3 and Geometry2D.is_point_in_polygon(point, points)


func _is_terrain_valid_for_kind(kind: String, terrain_zone: String) -> bool:
	if terrain_zone in ["deep_ocean", "shallow_water"]:
		return false
	if terrain_zone == "shore":
		return kind in ["grass_patch", "dense_grass", "small_bush", "berry_bush", "reed"]
	if terrain_zone == "highland":
		return kind in ["conifer_tree", "dry_tree", "dry_bush", "small_bush", "grass_patch", "dense_grass"]
	return true


func _get_min_distance_for_kind(kind: String) -> float:
	if TREE_KINDS.has(kind):
		return min_distance_default
	if BUSH_KINDS.has(kind):
		return min_distance_default * 0.65
	if DECORATIVE_KINDS.has(kind):
		return min_distance_default * 0.35
	return min_distance_default


func _passes_spacing(candidate: Vector2, used_positions: Array[Vector2], min_distance: float) -> bool:
	for used_position in used_positions:
		if candidate.distance_to(used_position) < min_distance:
			return false
	return true


func _add_distribution(biome_id: String, kind: String) -> void:
	if not debug_distribution_by_biome.has(biome_id):
		debug_distribution_by_biome[biome_id] = {}
	var biome_data := Dictionary(debug_distribution_by_biome[biome_id])
	biome_data[kind] = int(biome_data.get(kind, 0)) + 1
	debug_distribution_by_biome[biome_id] = biome_data
	if not debug_distribution_by_kind.has(kind):
		debug_distribution_by_kind[kind] = {}
	var kind_data := Dictionary(debug_distribution_by_kind[kind])
	kind_data[biome_id] = int(kind_data.get(biome_id, 0)) + 1
	debug_distribution_by_kind[kind] = kind_data


func _add_rejection(reason: String) -> void:
	debug_rejections_by_reason[reason] = int(debug_rejections_by_reason.get(reason, 0)) + 1


func get_debug_summary() -> Dictionary:
	return {
		"distribution_by_biome": debug_distribution_by_biome.duplicate(true),
		"distribution_by_kind": debug_distribution_by_kind.duplicate(true),
		"rejections_by_reason": debug_rejections_by_reason.duplicate(true),
		"validation": DistributionValidator.validate_distribution(_last_plan)
	}
