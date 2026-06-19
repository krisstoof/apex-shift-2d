extends RefCounted
class_name WorldGenerator

const GEN_CONFIG := preload("res://scripts/world/world_generation_config.gd")
const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const WORLD_GENERATION_VALIDATOR := preload("res://scripts/core/world/world_generation_validator.gd")
const BIOME_GENERATOR := preload("res://scripts/world/biome_generator.gd")
const GENERATOR_RULES_VERSION := "v5"

var seed: int = 0
var rng := RandomNumberGenerator.new()
var height_noise := FastNoiseLite.new()
var moisture_noise := FastNoiseLite.new()
var biome_noise := FastNoiseLite.new()
var danger_noise := FastNoiseLite.new()
var pond_noise := FastNoiseLite.new()
var ridge_noise := FastNoiseLite.new()
var biome_warp_x := FastNoiseLite.new()
var biome_warp_y := FastNoiseLite.new()
var biome_macro_noise := FastNoiseLite.new()
var biome_detail_noise := FastNoiseLite.new()
var vegetation_noise := FastNoiseLite.new()
var danger_detail_noise := FastNoiseLite.new()

const BIOME_IDS := ["westwood", "stoneback_ridge", "hearth_meadow", "south_thicket", "redfang_wilds"]
const BIOME_OWNERSHIP_MAP_WIDTH := 256
const BIOME_OWNERSHIP_MAP_HEIGHT := 192
const USE_RANDOMIZED_BIOME_LAYOUT := true

var biome_region_anchors: Array[Dictionary] = []
var visual_biome_features: Array[Dictionary] = []
var biome_ownership_map: Array[Array] = []
var topography_features: Array[Dictionary] = []
var island_shape_profile: Dictionary = {}
var biome_cleanup_debug: Dictionary = {
	"component_count": 0,
	"small_components_removed": 0,
	"largest_component_per_biome": {},
	"cells_changed": 0
}
var biome_map = null


func generate_world(p_seed: int = 0) -> Dictionary:
	seed = p_seed if p_seed != 0 else GEN_CONFIG.DEFAULT_SEED
	_configure_rng_and_noise(seed)
	_build_island_shape_profile()
	_build_biome_region_anchors()
	_build_visual_biome_features()
	_build_biome_ownership_map()
	_build_biome_map()
	var layout := {
		"version": 1,
		"generator_rules_version": GENERATOR_RULES_VERSION,
		"seed": seed,
		"world_rect": GEN_CONFIG.WORLD_RECT,
		"maps": _generate_sample_maps(),
		"biomes": [],
		"landmarks": [],
		"resource_zones": [],
		"creature_spawn_zones": [],
		"debug": {}
	}
	layout["biomes"] = _generate_biome_regions(Dictionary(layout["maps"]))
	if biome_map != null and biome_map.has_method("get_regions"):
		layout["biomes"] = Array(biome_map.get_regions())
	layout["landmarks"] = _generate_landmarks(layout)
	layout["resource_zones"] = _generate_resource_zones(layout)
	layout["creature_spawn_zones"] = _generate_creature_spawn_zones(layout)
	layout["debug"] = _build_generation_debug(layout)
	layout["generation_hash"] = get_world_generation_hash(layout)
	return layout


## Compute a stable hash of the key generation outputs for this layout.
## Identical to WorldGenerationResult.compute_hash_from_layout() but callable
## without creating a result object.
func get_world_generation_hash(layout: Dictionary) -> String:
	var result_script := load("res://scripts/core/world/world_generation_result.gd")
	return result_script.compute_hash_from_layout(layout)


## Generate a world and wrap the result in a typed WorldGenerationResult object.
func generate_world_with_result(p_seed: int = 0):
	var layout := generate_world(p_seed)
	var result_script := load("res://scripts/core/world/world_generation_result.gd")
	return result_script.from_layout(layout)


## Validate a layout against hard world rules.
## Returns the validator report dictionary: { valid, errors, warnings }.
func validate_layout(layout: Dictionary) -> Dictionary:
	var result_script := load("res://scripts/core/world/world_generation_result.gd")
	var result = result_script.from_layout(layout)
	var validator := WORLD_GENERATION_VALIDATOR.new()
	return validator.validate(result, self)


func get_height_at(position: Vector2) -> float:
	if island_shape_profile.is_empty():
		_build_island_shape_profile()
	var rect := GEN_CONFIG.WORLD_RECT
	var center := rect.get_center() + Vector2(island_shape_profile.get("center_offset", Vector2.ZERO))
	var rotation := float(island_shape_profile.get("rotation", 0.0))
	var radius_x := rect.size.x * 0.5 * float(island_shape_profile.get("radius_x_ratio", GEN_CONFIG.ISLAND_RADIUS_X_RATIO))
	var radius_y := rect.size.y * 0.5 * float(island_shape_profile.get("radius_y_ratio", GEN_CONFIG.ISLAND_RADIUS_Y_RATIO))
	var local := (position - center).rotated(-rotation)
	var normalized := Vector2(local.x / maxf(radius_x, 1.0), local.y / maxf(radius_y, 1.0))
	var distance := normalized.length()
	var angle := normalized.angle()
	var profile_delta := _get_island_profile_delta(angle, distance)
	var edge_noise_strength := float(island_shape_profile.get("edge_noise_strength", 0.24))
	var falloff := pow(clampf(distance, 0.0, 1.8), GEN_CONFIG.ISLAND_EDGE_FALLOFF_POWER)
	var base_noise := height_noise.get_noise_2d(position.x, position.y)
	var detail_noise := height_noise.get_noise_2d(position.x * 2.7, position.y * 2.7)
	return 1.04 - falloff + profile_delta + base_noise * edge_noise_strength + detail_noise * 0.08


func get_base_terrain_zone(position: Vector2) -> String:
	var h := get_height_at(position)
	if h < GEN_CONFIG.DEEP_OCEAN_THRESHOLD:
		return "deep_ocean"
	if h < GEN_CONFIG.SHALLOW_WATER_THRESHOLD:
		return "shallow_water"
	if h < GEN_CONFIG.SHORE_THRESHOLD:
		return "shore"
	return "land"


func get_inland_water_value(position: Vector2) -> float:
	if get_base_terrain_zone(position) != "land":
		return -1.0
	var moisture := get_moisture_at(position)
	var height := get_height_at(position)
	var pond_value := pond_noise.get_noise_2d(position.x, position.y)
	return moisture * 0.55 + pond_value * 0.45 - abs(height - 0.18) * 0.35


func is_pond_at(position: Vector2) -> bool:
	return get_base_terrain_zone(position) == "land" and get_inland_water_value(position) > 0.48


func get_hill_value(position: Vector2) -> float:
	var height := get_height_at(position)
	var ridge := ridge_noise.get_noise_2d(position.x, position.y)
	return height * 0.7 + ridge * 0.3


func is_hill_at(position: Vector2) -> bool:
	return get_base_terrain_zone(position) == "land" and get_hill_value(position) > 0.86


func get_terrain_zone(position: Vector2) -> String:
	var base_zone := get_base_terrain_zone(position)
	if base_zone != "land":
		return base_zone
	if is_pond_at(position):
		return "pond"
	if is_hill_at(position):
		return "highland"
	return base_zone


func get_moisture_at(position: Vector2) -> float:
	return moisture_noise.get_noise_2d(position.x, position.y)


func get_moisture01_at(position: Vector2) -> float:
	return clampf(get_moisture_at(position) * 0.5 + 0.5, 0.0, 1.0)


func get_vegetation_density_at(position: Vector2) -> float:
	var moisture := get_moisture01_at(position)
	var height := get_height_at(position)
	var terrain_noise := vegetation_noise.get_noise_2d(position.x, position.y) * 0.5 + 0.5
	var shelter := clampf(1.0 - absf(height - 0.22) * 1.55, 0.0, 1.0)
	return clampf(moisture * 0.56 + terrain_noise * 0.29 + shelter * 0.15, 0.0, 1.0)


func get_danger_at(position: Vector2) -> float:
	var moisture := get_moisture01_at(position)
	var height := clampf(get_height_at(position), 0.0, 1.5) / 1.5
	var ridge := ridge_noise.get_noise_2d(position.x, position.y) * 0.5 + 0.5
	var detail := danger_detail_noise.get_noise_2d(position.x, position.y) * 0.5 + 0.5
	return clampf(detail * 0.34 + ridge * 0.30 + height * 0.22 + (1.0 - moisture) * 0.14, 0.0, 1.0)


func get_distance_to_shore_at(position: Vector2) -> float:
	if get_base_terrain_zone(position) in ["deep_ocean", "shallow_water", "shore"]:
		return 0.0
	var rect := GEN_CONFIG.WORLD_RECT
	var max_distance := maxf(minf(rect.size.x, rect.size.y) * 0.15, 1.0)
	var step := maxf(max_distance / 10.0, 48.0)
	for radius in range(1, 11):
		var distance := float(radius) * step
		for offset in [
			Vector2(distance, 0.0),
			Vector2(-distance, 0.0),
			Vector2(0.0, distance),
			Vector2(0.0, -distance)
		]:
			if get_base_terrain_zone(position + offset) in ["deep_ocean", "shallow_water", "shore"]:
				return clampf(distance / max_distance, 0.0, 1.0)
	return 1.0


func get_terrain_condition_at(position: Vector2) -> Dictionary:
	return {
		"height": get_height_at(position),
		"moisture": get_moisture01_at(position),
		"vegetation_density": get_vegetation_density_at(position),
		"danger": get_danger_at(position),
		"distance_to_shore": get_distance_to_shore_at(position)
	}


func get_biome_map():
	return biome_map


func get_biome_id_at(position: Vector2) -> String:
	var base_terrain := get_base_terrain_zone(position)
	if base_terrain == "deep_ocean" or base_terrain == "shallow_water":
		return base_terrain
	if base_terrain == "shore":
		return "shore"
	if biome_map != null and biome_map.has_method("get_biome_id_at_world_position"):
		return str(biome_map.get_biome_id_at_world_position(position))
	if biome_ownership_map.is_empty():
		return _get_raw_biome_id_at(position)
	return _sample_biome_ownership_map(position)


func get_visual_biome_id_at(position: Vector2) -> String:
	if get_base_terrain_zone(position) in ["deep_ocean", "shallow_water", "shore"]:
		return get_biome_id_at(position)
	var scores := get_visual_biome_influence_scores(position)
	if scores.is_empty():
		return get_biome_id_at(position)
	var best_id := ""
	var best_score := -INF
	for biome_id in scores.keys():
		var score := float(scores[biome_id])
		if score > best_score:
			best_score = score
			best_id = str(biome_id)
	return best_id if not best_id.is_empty() else get_biome_id_at(position)


func get_visual_biome_scores_at(position: Vector2) -> Dictionary:
	return get_visual_biome_influence_scores(position)


func get_visual_biome_influence_scores(position: Vector2) -> Dictionary:
	if visual_biome_features.is_empty():
		_build_visual_biome_features()
	return _get_visual_biome_influence_scores(position)


func get_visual_biome_feature_count() -> int:
	return visual_biome_features.size()


func get_biome_visual_color_at(position: Vector2) -> Color:
	if not bool(GAME_BALANCE.BIOME_TEXTURES.get("visual_biome_shapes_enabled", true)):
		return _boost_color_saturation(get_biome_color(get_biome_id_at(position)), 0.08)
	var base_terrain := get_base_terrain_zone(position)
	match base_terrain:
		"deep_ocean":
			return Color(0.07, 0.22, 0.42)
		"shallow_water":
			return Color(0.12, 0.34, 0.56)
		"shore":
			return Color(0.64, 0.61, 0.38)

	var scores := get_visual_biome_influence_scores(position)
	var biome_id := _get_dominant_visual_biome_id(scores)
	var color := _boost_color_saturation(get_biome_color(biome_id), 0.12)
	var variation := biome_detail_noise.get_noise_2d(position.x * 1.2 + 71.0, position.y * 1.2 - 29.0)
	if variation > 0.0:
		color = color.lightened(variation * 0.018)
	else:
		color = color.darkened(absf(variation) * 0.024)
	var terrain := get_terrain_zone(position)
	var mix_color := _get_secondary_visual_biome_color(scores, biome_id)
	match terrain:
		"pond":
			return _mix_visual_biome_colors(Color(0.05, 0.28, 0.44), mix_color, position, 0.04)
		"rocky_patch":
			return _mix_visual_biome_colors(color.lerp(Color(0.43, 0.42, 0.38), 0.55), mix_color, position, 0.08)
		"highland":
			return _mix_visual_biome_colors(color.lerp(Color(0.52, 0.46, 0.30), 0.42), mix_color, position, 0.10)
		_:
			return _mix_visual_biome_colors(color, mix_color, position, 0.14)


func _boost_color_saturation(color: Color, amount: float = 0.12) -> Color:
	var avg := (color.r + color.g + color.b) / 3.0
	return Color(
		clampf(lerpf(avg, color.r, 1.0 + amount), 0.0, 1.0),
		clampf(lerpf(avg, color.g, 1.0 + amount), 0.0, 1.0),
		clampf(lerpf(avg, color.b, 1.0 + amount), 0.0, 1.0),
		color.a
	)


func _get_dominant_visual_biome_id(scores: Dictionary) -> String:
	var best_id := ""
	var best_score := -INF
	for biome_id in BIOME_IDS:
		var score := float(scores.get(biome_id, -INF))
		if score > best_score:
			best_score = score
			best_id = biome_id
	return best_id if not best_id.is_empty() else "hearth_meadow"


func _get_secondary_visual_biome_color(scores: Dictionary, dominant_biome_id: String) -> Color:
	var best_score := float(scores.get(dominant_biome_id, -INF))
	var candidate_id := ""
	var candidate_score := -INF
	for biome_id in BIOME_IDS:
		if biome_id == dominant_biome_id:
			continue
		var score := float(scores.get(biome_id, -INF))
		if score > candidate_score:
			candidate_score = score
			candidate_id = biome_id
	if candidate_id.is_empty():
		return Color(0.0, 0.0, 0.0, 0.0)
	var closeness := clampf(1.0 - (best_score - candidate_score) * 1.8, 0.0, 1.0)
	if closeness <= 0.0:
		return Color(0.0, 0.0, 0.0, 0.0)
	var candidate_color := _boost_color_saturation(get_biome_color(candidate_id), 0.10)
	return Color(candidate_color.r, candidate_color.g, candidate_color.b, closeness)


func _mix_visual_biome_colors(base_color: Color, mix_color: Color, position: Vector2, max_amount: float) -> Color:
	if mix_color.a <= 0.0:
		return base_color
	var noise := biome_detail_noise.get_noise_2d(position.x * 0.021 + 13.0, position.y * 0.021 - 17.0) * 0.5 + 0.5
	var amount := clampf(max_amount * mix_color.a * (0.18 + noise * 0.82), 0.0, max_amount)
	return base_color.lerp(mix_color, amount)


func get_biome_color(biome_id: String) -> Color:
	match biome_id:
		"westwood":
			return Color(0.12, 0.34, 0.15)
		"stoneback_ridge":
			return Color(0.50, 0.46, 0.38)
		"hearth_meadow":
			return Color(0.36, 0.62, 0.27)
		"south_thicket":
			return Color(0.28, 0.48, 0.16)
		"redfang_wilds":
			return Color(0.50, 0.26, 0.19)
		"shore":
			return Color(0.78, 0.72, 0.44)
		_:
			return Color(0.32, 0.52, 0.28)
func debug_validate_same_seed(test_seed: int) -> Dictionary:
	var generator_a: WorldGenerator = get_script().new()
	var layout_a: Dictionary = generator_a.generate_world(test_seed)
	var generator_b: WorldGenerator = get_script().new()
	var layout_b: Dictionary = generator_b.generate_world(test_seed)
	var hash_a := get_world_generation_hash(layout_a)
	var hash_b := get_world_generation_hash(layout_b)
	return {
		"seed": test_seed,
		"same_generation_hash": hash_a == hash_b,
		"hash_a": hash_a,
		"hash_b": hash_b,
		"same_landmark_count": Array(layout_a.get("landmarks", [])).size() == Array(layout_b.get("landmarks", [])).size(),
		"same_spawn_zone_count": Array(layout_a.get("creature_spawn_zones", [])).size() == Array(layout_b.get("creature_spawn_zones", [])).size()
	}


func _configure_rng_and_noise(p_seed: int) -> void:
	rng.seed = p_seed
	height_noise.seed = p_seed + 101
	height_noise.frequency = GEN_CONFIG.HEIGHT_NOISE_FREQUENCY
	moisture_noise.seed = p_seed + 202
	moisture_noise.frequency = GEN_CONFIG.MOISTURE_NOISE_FREQUENCY
	biome_noise.seed = p_seed + 303
	biome_noise.frequency = GEN_CONFIG.BIOME_NOISE_FREQUENCY * 0.55
	danger_noise.seed = p_seed + 404
	danger_noise.frequency = GEN_CONFIG.DANGER_NOISE_FREQUENCY
	pond_noise.seed = p_seed + 505
	pond_noise.frequency = 0.0018
	ridge_noise.seed = p_seed + 606
	ridge_noise.frequency = 0.0018
	biome_warp_x.seed = p_seed + 707
	biome_warp_x.frequency = 0.00045
	biome_warp_y.seed = p_seed + 808
	biome_warp_y.frequency = 0.00045
	biome_macro_noise.seed = p_seed + 909
	biome_macro_noise.frequency = 0.00065
	biome_detail_noise.seed = p_seed + 1001
	biome_detail_noise.frequency = 0.0014
	vegetation_noise.seed = p_seed + 1102
	vegetation_noise.frequency = 0.0022
	danger_detail_noise.seed = p_seed + 1203
	danger_detail_noise.frequency = 0.0019


func _build_biome_map() -> void:
	var generator := BIOME_GENERATOR.new()
	biome_map = generator.build_biome_map(seed, GEN_CONFIG.WORLD_RECT, self)


func _generate_sample_maps() -> Dictionary:
	var height_samples: Array = []
	var moisture_samples: Array = []
	var biome_samples: Array = []
	var topography_samples: Array = []
	var danger_samples: Array = []
	for y in range(GEN_CONFIG.MAP_SAMPLE_HEIGHT):
		var height_row: Array = []
		var moisture_row: Array = []
		var biome_row: Array = []
		var topography_row: Array = []
		var danger_row: Array = []
		for x in range(GEN_CONFIG.MAP_SAMPLE_WIDTH):
			var world_pos := _sample_to_world_position(x, y)
			height_row.append(get_height_at(world_pos))
			moisture_row.append(get_moisture_at(world_pos))
			biome_row.append(get_biome_id_at(world_pos))
			topography_row.append(get_terrain_zone(world_pos))
			danger_row.append(get_danger_at(world_pos))
		height_samples.append(height_row)
		moisture_samples.append(moisture_row)
		biome_samples.append(biome_row)
		topography_samples.append(topography_row)
		danger_samples.append(danger_row)
	return {
		"width": GEN_CONFIG.MAP_SAMPLE_WIDTH,
		"height": GEN_CONFIG.MAP_SAMPLE_HEIGHT,
		"height_map": height_samples,
		"moisture_map": moisture_samples,
		"biome_map": biome_samples,
		"topography_map": topography_samples,
		"danger_map": danger_samples
	}


func _build_island_shape_profile() -> void:
	var rect := GEN_CONFIG.WORLD_RECT
	var min_size := minf(rect.size.x, rect.size.y)
	island_shape_profile = {
		"center_offset": Vector2(
			rng.randf_range(-rect.size.x * 0.055, rect.size.x * 0.055),
			rng.randf_range(-rect.size.y * 0.055, rect.size.y * 0.055)
		),
		"rotation": rng.randf_range(-0.38, 0.38),
		"radius_x_ratio": rng.randf_range(0.68, 0.88),
		"radius_y_ratio": rng.randf_range(0.58, 0.82),
		"edge_noise_strength": rng.randf_range(0.18, 0.34),
		"lobes": _generate_island_lobes(rng.randi_range(3, 6), min_size),
		"bays": _generate_island_bays(rng.randi_range(1, 3), min_size)
	}


func _generate_island_lobes(count: int, _min_size: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for _i in range(count):
		result.append({
			"angle": rng.randf_range(0.0, TAU),
			"width": rng.randf_range(0.32, 0.62),
			"strength": rng.randf_range(0.05, 0.16),
			"distance": rng.randf_range(0.70, 1.05)
		})
	return result


func _generate_island_bays(count: int, _min_size: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for _i in range(count):
		result.append({
			"angle": rng.randf_range(0.0, TAU),
			"width": rng.randf_range(0.22, 0.48),
			"strength": rng.randf_range(0.05, 0.14),
			"distance": rng.randf_range(0.68, 0.98)
		})
	return result


func _get_island_profile_delta(angle: float, distance: float) -> float:
	var delta := 0.0
	for lobe_value in Array(island_shape_profile.get("lobes", [])):
		var lobe := Dictionary(lobe_value)
		var d := absf(angle_difference(angle, float(lobe.get("angle", 0.0))))
		var width := maxf(float(lobe.get("width", 0.4)), 0.01)
		var influence := exp(-pow(d / width, 2.0))
		influence *= smoothstep(0.30, 1.15, distance)
		delta += influence * float(lobe.get("strength", 0.08))
	for bay_value in Array(island_shape_profile.get("bays", [])):
		var bay := Dictionary(bay_value)
		var d := absf(angle_difference(angle, float(bay.get("angle", 0.0))))
		var width := maxf(float(bay.get("width", 0.35)), 0.01)
		var influence := exp(-pow(d / width, 2.0))
		influence *= smoothstep(0.42, 1.18, distance)
		delta -= influence * float(bay.get("strength", 0.08))
	return delta


func angle_difference(a: float, b: float) -> float:
	return wrapf(a - b, -PI, PI)


func _sample_to_world_position(x: int, y: int) -> Vector2:
	var rect := GEN_CONFIG.WORLD_RECT
	var tx := float(x) / float(GEN_CONFIG.MAP_SAMPLE_WIDTH - 1)
	var ty := float(y) / float(GEN_CONFIG.MAP_SAMPLE_HEIGHT - 1)
	return Vector2(lerpf(rect.position.x, rect.end.x, tx), lerpf(rect.position.y, rect.end.y, ty))


func _generate_biome_regions(maps: Dictionary) -> Array[Dictionary]:
	var counts: Dictionary = {}
	var bounds: Dictionary = {}
	for y in range(GEN_CONFIG.MAP_SAMPLE_HEIGHT):
		for x in range(GEN_CONFIG.MAP_SAMPLE_WIDTH):
			var biome_id := str(maps["biome_map"][y][x])
			if biome_id in ["deep_ocean", "shallow_water", "shore"]:
				continue
			var world_pos := _sample_to_world_position(x, y)
			counts[biome_id] = int(counts.get(biome_id, 0)) + 1
			if not bounds.has(biome_id):
				bounds[biome_id] = Rect2(world_pos, Vector2.ZERO)
			else:
				bounds[biome_id] = Rect2(bounds[biome_id]).expand(world_pos)
	var result: Array[Dictionary] = []
	for biome_id in counts.keys():
		result.append({
			"id": biome_id,
			"name": _get_biome_display_name(biome_id),
			"bounds": bounds[biome_id],
			"sample_count": counts[biome_id],
			"resource_rules": _get_biome_resource_rules(biome_id)
		})
	return result


func get_topography_feature_counts_debug() -> Dictionary:
	var counts: Dictionary = {}
	for feature in topography_features:
		var t := str(Dictionary(feature).get("type", "unknown"))
		counts[t] = int(counts.get(t, 0)) + 1
	return counts


func _generate_landmarks(_layout: Dictionary) -> Array[Dictionary]:
	return []


func _generate_resource_zones(layout: Dictionary) -> Array[Dictionary]:
	var zones: Array[Dictionary] = []
	for biome in Array(layout.get("biomes", [])):
		var biome_dict := Dictionary(biome)
		var biome_id := str(biome_dict.get("id", ""))
		zones.append({
			"id": "resources_%s" % biome_id,
			"biome_id": biome_id,
			"rules": _get_biome_resource_rules(biome_id),
			"density": _get_resource_density_for_biome(biome_id)
		})
	return zones


func _generate_creature_spawn_zones(_layout: Dictionary) -> Array[Dictionary]:
	var zones: Array[Dictionary] = []
	for i in range(GEN_CONFIG.CREATURE_SPAWN_ZONE_COUNT):
		var position := _random_land_position()
		var biome_id := get_biome_id_at(position)
		var danger := get_danger_at(position)
		var allowed_creatures: Array[String] = []
		if danger < 0.45:
			allowed_creatures = ["small_prey", "grazer"]
		elif danger < 0.68:
			allowed_creatures = ["small_prey", "grazer", "varnak"]
		else:
			allowed_creatures = ["varnak", "grazer"]
		zones.append({
			"id": "spawn_zone_%02d" % i,
			"position": position,
			"radius": rng.randf_range(350.0, 700.0),
			"biome_id": biome_id,
			"danger": danger,
			"allowed_creatures": allowed_creatures
		})
	return zones


func _build_generation_debug(layout: Dictionary) -> Dictionary:
	var maps: Dictionary = Dictionary(layout.get("maps", {}))
	var width: int = int(maps.get("width", 1))
	var height: int = int(maps.get("height", 1))
	var total: int = maxi(width * height, 1)
	var biome_map: Array = Array(maps.get("biome_map", []))
	var topography_map: Array = Array(maps.get("topography_map", []))
	var height_map: Array = Array(maps.get("height_map", []))
	var moisture_map: Array = Array(maps.get("moisture_map", []))
	var danger_map: Array = Array(maps.get("danger_map", []))
	var terrain_counts: Dictionary = {
		"deep_ocean": 0,
		"shallow_water": 0,
		"shore": 0,
		"pond": 0,
		"highland": 0,
		"land": 0
	}
	var biome_counts: Dictionary = {}
	var moisture_total := 0.0
	var danger_total := 0.0
	var height_min := INF
	var height_max := -INF
	var moisture_min := INF
	var moisture_max := -INF
	var danger_min := INF
	var danger_max := -INF
	for y in range(min(height, biome_map.size())):
		var biome_row: Array = Array(biome_map[y])
		var height_row: Array = Array(height_map[y]) if y < height_map.size() else []
		var moisture_row: Array = Array(moisture_map[y]) if y < moisture_map.size() else []
		var danger_row: Array = Array(danger_map[y]) if y < danger_map.size() else []
		for x in range(min(width, biome_row.size())):
			var biome_id := str(biome_row[x])
			var world_pos := _sample_to_world_position(x, y)
			var terrain_zone := get_terrain_zone(world_pos)
			terrain_counts[terrain_zone] = int(terrain_counts.get(terrain_zone, 0)) + 1
			biome_counts[biome_id] = int(biome_counts.get(biome_id, 0)) + 1
			var sample_height := float(height_row[x]) if x < height_row.size() else get_height_at(world_pos)
			var sample_moisture := float(moisture_row[x]) if x < moisture_row.size() else get_moisture_at(world_pos)
			var sample_danger := float(danger_row[x]) if x < danger_row.size() else get_danger_at(world_pos)
			height_min = minf(height_min, sample_height)
			height_max = maxf(height_max, sample_height)
			moisture_min = minf(moisture_min, sample_moisture)
			moisture_max = maxf(moisture_max, sample_moisture)
			danger_min = minf(danger_min, sample_danger)
			danger_max = maxf(danger_max, sample_danger)
			moisture_total += sample_moisture
			danger_total += sample_danger
	var topography_counts := get_topography_feature_counts_debug()
	var biome_region_count := Array(layout.get("biomes", [])).size()
	var small_biome_region_count := 0
	for biome_value in Array(layout.get("biomes", [])):
		if int(Dictionary(biome_value).get("sample_count", 0)) < 320:
			small_biome_region_count += 1
	var dominant_biome := ""
	var dominant_count := -1
	for biome_id in biome_counts.keys():
		var count := int(biome_counts[biome_id])
		if count > dominant_count:
			dominant_count = count
			dominant_biome = str(biome_id)
	return {
		"seed": seed,
		"world_seed": seed,
		"version": int(layout.get("version", 0)),
		"biomes": Array(layout.get("biomes", [])).size(),
		"biome_region_count": biome_region_count,
		"small_biome_region_count": small_biome_region_count,
		"dominant_biome": dominant_biome,
		"landmarks": Array(layout.get("landmarks", [])).size(),
		"resource_zones": Array(layout.get("resource_zones", [])).size(),
		"creature_spawn_zones": Array(layout.get("creature_spawn_zones", [])).size(),
		"terrain_counts": terrain_counts,
		"biome_counts": biome_counts,
		"biome_count_by_type": biome_counts.duplicate(true),
		"biome_coverage": get_biome_coverage_debug(),
		"height_range": Vector2(height_min, height_max),
		"moisture_range": Vector2(moisture_min, moisture_max),
		"danger_range": Vector2(danger_min, danger_max),
		"topography_feature_counts": topography_counts,
		"topography_features": topography_features.size(),
		"biome_cleanup": biome_cleanup_debug.duplicate(true),
		"terrain_coverage": {
			"ocean": float(int(terrain_counts["deep_ocean"]) + int(terrain_counts["shallow_water"])) / float(total),
			"land": float(int(terrain_counts["land"])) / float(total),
			"pond": float(int(terrain_counts["pond"])) / float(total),
			"highland": float(int(terrain_counts["highland"])) / float(total)
		},
		"moisture_average": moisture_total / float(total),
		"danger_average": danger_total / float(total)
	}


func get_biome_lookup_debug(position: Vector2) -> Dictionary:
	var conditions := get_terrain_condition_at(position)
	var biome_id := get_biome_id_at(position)
	var terrain_zone := get_terrain_zone(position)
	return {
		"seed": seed,
		"position": position,
		"biome_id": biome_id,
		"terrain_zone": terrain_zone,
		"conditions": conditions.duplicate(true),
		"world_rect_has_point": GEN_CONFIG.WORLD_RECT.has_point(position)
	}


func _get_biome_display_name(biome_id: String) -> String:
	return biome_id.capitalize().replace("_", " ")


func _get_biome_resource_rules(biome_id: String) -> Dictionary:
	match biome_id:
		"westwood":
			return {"trees": 1.6, "bushes": 0.9, "rocks": 0.35, "grass": 1.2, "berries": 0.8}
		"stoneback_ridge":
			return {"trees": 0.35, "bushes": 0.5, "rocks": 1.7, "grass": 0.65, "berries": 0.2}
		"redfang_wilds":
			return {"trees": 0.3, "bushes": 0.45, "rocks": 1.2, "grass": 0.25, "berries": 0.05}
		"south_thicket":
			return {"trees": 0.5, "bushes": 1.25, "rocks": 0.7, "grass": 0.75, "berries": 0.25}
		_:
			return {"trees": 0.9, "bushes": 0.9, "rocks": 0.65, "grass": 1.0, "berries": 0.45}


func _get_resource_density_for_biome(_biome_id: String) -> float:
	return 1.0


func _random_land_position() -> Vector2:
	for _attempt in range(400):
		var candidate := Vector2(
			rng.randf_range(GEN_CONFIG.WORLD_RECT.position.x, GEN_CONFIG.WORLD_RECT.end.x),
			rng.randf_range(GEN_CONFIG.WORLD_RECT.position.y, GEN_CONFIG.WORLD_RECT.end.y)
		)
		if get_base_terrain_zone(candidate) == "land":
			return candidate
	return GEN_CONFIG.WORLD_RECT.get_center()


func _build_biome_region_anchors() -> void:
	biome_region_anchors.clear()
	var remaining_biomes: Array[String] = []
	for biome_id in BIOME_IDS:
		remaining_biomes.append(biome_id)
	var hearth_id := "hearth_meadow"
	if USE_RANDOMIZED_BIOME_LAYOUT:
		var hearth_pos := _find_biome_anchor_position_near_safe_area()
		_add_biome_anchor(hearth_id, hearth_pos, _get_random_biome_radius(hearth_id), rng.randf_range(1.12, 1.36))
	else:
		var rect := GEN_CONFIG.WORLD_RECT
		var center := rect.get_center()
		_add_biome_anchor(
			hearth_id,
			center + Vector2(
				rng.randf_range(-rect.size.x * 0.10, rect.size.x * 0.10),
				rng.randf_range(-rect.size.y * 0.10, rect.size.y * 0.10)
			),
			_get_random_biome_radius(hearth_id),
			rng.randf_range(1.12, 1.36)
		)
	remaining_biomes.erase(hearth_id)
	remaining_biomes.shuffle()
	for biome_id in remaining_biomes:
		var pos := _find_random_macro_biome_anchor_position(biome_id)
		_add_biome_anchor(biome_id, pos, _get_random_biome_radius(biome_id), rng.randf_range(1.05, 1.35))


func _build_visual_biome_features() -> void:
	visual_biome_features.clear()
	for anchor_value in biome_region_anchors:
		var anchor := Dictionary(anchor_value)
		var biome_id := str(anchor.get("biome_id", ""))
		if biome_id.is_empty():
			continue
		var anchor_pos := Vector2(anchor.get("position", Vector2.ZERO))
		var anchor_radius := float(anchor.get("radius", 3000.0))
		var anchor_strength := float(anchor.get("strength", 1.0))
		_add_visual_biome_feature(biome_id, anchor_pos, anchor_radius * rng.randf_range(0.88, 1.05), anchor_strength * rng.randf_range(1.06, 1.28), "core", Vector2.ZERO, rng.randf_range(0.05, 0.11))
		if rng.randf() < 0.8:
			_add_visual_biome_feature(biome_id, anchor_pos + _random_feature_offset(anchor_radius * 0.20), anchor_radius * rng.randf_range(0.32, 0.58), anchor_strength * rng.randf_range(0.62, 0.92), "core", _random_feature_warp_offset(), rng.randf_range(0.05, 0.12))
		var lobe_count := rng.randi_range(2, 5)
		for _i in range(lobe_count):
			_add_visual_biome_feature(
				biome_id,
				anchor_pos + _random_feature_offset(anchor_radius * rng.randf_range(0.18, 0.55)),
				anchor_radius * rng.randf_range(0.14, 0.30),
				anchor_strength * rng.randf_range(0.28, 0.58),
				"lobe",
				_random_feature_warp_offset(),
				rng.randf_range(0.08, 0.18)
			)
		if rng.randf() < 0.7:
			_add_visual_biome_feature(
				biome_id,
				anchor_pos + _random_feature_offset(anchor_radius * rng.randf_range(0.12, 0.36)),
				anchor_radius * rng.randf_range(0.10, 0.20),
				anchor_strength * rng.randf_range(0.20, 0.40),
				"bridge",
				_random_feature_warp_offset(),
				rng.randf_range(0.14, 0.24)
			)
		if rng.randf() < 0.9:
			_add_visual_biome_feature(
				biome_id,
				anchor_pos + _random_feature_offset(anchor_radius * rng.randf_range(0.16, 0.42)),
				anchor_radius * rng.randf_range(0.12, 0.24),
				anchor_strength * rng.randf_range(0.12, 0.26),
				"erosion",
				_random_feature_warp_offset(),
				rng.randf_range(0.16, 0.30)
			)


func _add_visual_biome_feature(biome_id: String, position: Vector2, radius: float, strength: float, shape_type: String, warp_offset: Vector2, warp_strength: float) -> void:
	visual_biome_features.append({
		"biome_id": biome_id,
		"position": position,
		"radius": maxf(radius, 1.0),
		"strength": maxf(strength, 0.0),
		"shape_type": shape_type,
		"warp_offset": warp_offset,
		"warp_strength": maxf(warp_strength, 0.0)
	})


func _random_feature_offset(distance: float) -> Vector2:
	var angle := rng.randf_range(0.0, TAU)
	return Vector2(cos(angle), sin(angle)) * distance


func _random_feature_warp_offset() -> Vector2:
	return Vector2(
		rng.randf_range(-1.0, 1.0),
		rng.randf_range(-1.0, 1.0)
	)


func _add_biome_anchor(biome_id: String, position: Vector2, radius: float, strength: float) -> void:
	biome_region_anchors.append({
		"biome_id": biome_id,
		"position": position,
		"radius": radius,
		"strength": strength
	})


func _find_biome_anchor_position_near_safe_area() -> Vector2:
	var center := GEN_CONFIG.WORLD_RECT.get_center()
	for _attempt in range(800):
		var offset := Vector2(
			rng.randf_range(-GEN_CONFIG.WORLD_RECT.size.x * 0.14, GEN_CONFIG.WORLD_RECT.size.x * 0.14),
			rng.randf_range(-GEN_CONFIG.WORLD_RECT.size.y * 0.14, GEN_CONFIG.WORLD_RECT.size.y * 0.14)
		)
		var candidate := center + offset
		if _is_good_biome_anchor_position(candidate, "hearth_meadow", minf(GEN_CONFIG.WORLD_RECT.size.x, GEN_CONFIG.WORLD_RECT.size.y) * 0.20):
			return candidate
	return center


func _find_random_macro_biome_anchor_position(biome_id: String) -> Vector2:
	var min_distance := minf(GEN_CONFIG.WORLD_RECT.size.x, GEN_CONFIG.WORLD_RECT.size.y) * 0.20
	for _attempt in range(800):
		var candidate := _random_land_position()
		if _is_good_biome_anchor_position(candidate, biome_id, min_distance):
			return candidate
	return _random_land_position()


func _is_good_biome_anchor_position(candidate: Vector2, _biome_id: String, min_distance: float) -> bool:
	if get_base_terrain_zone(candidate) != "land":
		return false
	if _is_near_ocean_or_shore(candidate, 420.0):
		return false
	for anchor_value in biome_region_anchors:
		var anchor := Dictionary(anchor_value)
		var other_pos := Vector2(anchor.get("position", Vector2.ZERO))
		if candidate.distance_to(other_pos) < min_distance:
			return false
	return true


func _is_near_ocean_or_shore(position: Vector2, radius: float) -> bool:
	var samples := [
		Vector2.ZERO,
		Vector2(radius, 0.0),
		Vector2(-radius, 0.0),
		Vector2(0.0, radius),
		Vector2(0.0, -radius),
		Vector2(radius * 0.7, radius * 0.7),
		Vector2(-radius * 0.7, radius * 0.7),
		Vector2(radius * 0.7, -radius * 0.7),
		Vector2(-radius * 0.7, -radius * 0.7)
	]
	for offset in samples:
		if get_base_terrain_zone(position + offset) != "land":
			return true
	return false


func _get_random_biome_radius(biome_id: String) -> float:
	var min_size := minf(GEN_CONFIG.WORLD_RECT.size.x, GEN_CONFIG.WORLD_RECT.size.y)
	match biome_id:
		"hearth_meadow":
			return rng.randf_range(min_size * 0.22, min_size * 0.34)
		"stoneback_ridge":
			return rng.randf_range(min_size * 0.20, min_size * 0.32)
		"redfang_wilds":
			return rng.randf_range(min_size * 0.22, min_size * 0.36)
		"westwood":
			return rng.randf_range(min_size * 0.24, min_size * 0.38)
		"south_thicket":
			return rng.randf_range(min_size * 0.22, min_size * 0.36)
	return rng.randf_range(min_size * 0.22, min_size * 0.34)


func _get_warped_biome_position(position: Vector2) -> Vector2:
	var warp_strength := 240.0
	return position + Vector2(
		biome_warp_x.get_noise_2d(position.x, position.y) * warp_strength,
		biome_warp_y.get_noise_2d(position.x + 431.0, position.y - 217.0) * warp_strength
	)


func _get_macro_biome_score(position: Vector2, biome_id: String) -> float:
	var best := 0.0
	for anchor_value in biome_region_anchors:
		var anchor := Dictionary(anchor_value)
		if str(anchor.get("biome_id", "")) != biome_id:
			continue

		var anchor_pos := Vector2(anchor.get("position", Vector2.ZERO))
		var radius := float(anchor.get("radius", 3000.0))
		var strength := float(anchor.get("strength", 1.0))

		var distance := position.distance_to(anchor_pos)
		var normalized := clampf(1.0 - distance / maxf(radius, 1.0), 0.0, 1.0)

		best = maxf(best, pow(normalized, 1.25) * strength)
	return best


func _get_biome_scores(position: Vector2) -> Dictionary:
	var warped := _get_warped_biome_position(position)
	var conditions := get_terrain_condition_at(position)
	var height := float(conditions.get("height", 0.0))
	var moisture := float(conditions.get("moisture", 0.0))
	var vegetation := float(conditions.get("vegetation_density", 0.0))
	var danger := float(conditions.get("danger", 0.0))
	var distance_to_shore := float(conditions.get("distance_to_shore", 1.0))
	var rect := GEN_CONFIG.WORLD_RECT
	var center := rect.get_center()
	var local := warped - center

	var nx := clampf(local.x / maxf(rect.size.x * 0.5, 1.0), -1.0, 1.0)
	var ny := clampf(local.y / maxf(rect.size.y * 0.5, 1.0), -1.0, 1.0)

	return {
		"westwood": _get_macro_biome_score(warped, "westwood") * 4.4 + moisture * 1.6 + vegetation * 1.0 - danger * 0.35 - absf(height - 0.32) * 0.4 - nx * 0.02,
		"stoneback_ridge": _get_macro_biome_score(warped, "stoneback_ridge") * 4.8 + height * 2.1 - vegetation * 1.15 - moisture * 0.35 + ny * 0.02,
		"hearth_meadow": _get_macro_biome_score(warped, "hearth_meadow") * 5.0 + (1.0 - absf(moisture - 0.5) * 2.0) + (1.0 - vegetation) * 0.8 + (1.0 - danger) * 0.55 - absf(height - 0.22) * 0.4,
		"south_thicket": _get_macro_biome_score(warped, "south_thicket") * 4.9 + moisture * 1.8 + vegetation * 1.7 + (1.0 - distance_to_shore) * 1.1 + ny * 0.02,
		"redfang_wilds": _get_macro_biome_score(warped, "redfang_wilds") * 4.7 + danger * 2.0 + (1.0 - moisture) * 1.1 + distance_to_shore * 0.9 + nx * 0.02
	}


func _get_visual_biome_influence_scores(position: Vector2) -> Dictionary:
	var scores := _get_biome_scores(position)
	if visual_biome_features.is_empty():
		return scores
	var warped := _get_warped_biome_position(position)
	var edge_noise_strength := float(GAME_BALANCE.BIOME_TEXTURES.get("visual_biome_shape_edge_noise_strength", 0.08))
	var edge_noise_scale := maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("visual_biome_shape_edge_noise_scale", 220.0)), 1.0)
	for feature_value in visual_biome_features:
		var feature := Dictionary(feature_value)
		var biome_id := str(feature.get("biome_id", ""))
		if biome_id.is_empty():
			continue
		var feature_pos := Vector2(feature.get("position", Vector2.ZERO))
		var radius := maxf(float(feature.get("radius", 1.0)), 1.0)
		var strength := maxf(float(feature.get("strength", 0.0)), 0.0)
		var shape_type := str(feature.get("shape_type", "core"))
		var warp_offset := Vector2(feature.get("warp_offset", Vector2.ZERO))
		var warp_strength := maxf(float(feature.get("warp_strength", 0.0)), 0.0)
		var sample_pos := warped
		if warp_strength > 0.0:
			var warp_noise := Vector2(
				biome_detail_noise.get_noise_2d((warped.x + warp_offset.x * 113.0) / edge_noise_scale, (warped.y + warp_offset.y * 113.0) / edge_noise_scale),
				biome_detail_noise.get_noise_2d((warped.x - warp_offset.y * 91.0) / edge_noise_scale, (warped.y + warp_offset.x * 91.0) / edge_noise_scale)
			)
			sample_pos += warp_noise * warp_strength * radius * 0.28
		var distance := sample_pos.distance_to(feature_pos)
		var normalized := clampf(1.0 - distance / radius, 0.0, 1.0)
		if normalized <= 0.0:
			continue
		var exponent := 1.35
		match shape_type:
			"core":
				exponent = 1.05
			"lobe":
				exponent = 1.55
			"bridge":
				exponent = 2.10
			"erosion":
				exponent = 2.65
		var influence := pow(normalized, exponent) * strength
		if shape_type == "erosion":
			influence = -influence
		influence += (biome_detail_noise.get_noise_2d(position.x / edge_noise_scale, position.y / edge_noise_scale) * 0.5 + 0.5) * edge_noise_strength * 0.02
		scores[biome_id] = float(scores.get(biome_id, 0.0)) + influence
	return scores


func _get_raw_biome_id_at(position: Vector2) -> String:
	var scores := _get_biome_scores(position)
	var sorted_ids: Array[String] = []
	for biome_id in BIOME_IDS:
		sorted_ids.append(biome_id)
	sorted_ids.sort_custom(func(a: String, b: String) -> bool:
		return float(scores.get(a, -INF)) > float(scores.get(b, -INF))
	)
	if sorted_ids.is_empty():
		return "south_thicket"
	var best_biome_id := str(sorted_ids[0])
	if sorted_ids.size() < 2:
		return best_biome_id
	var best_score := float(scores.get(best_biome_id, -INF))
	var second_score := float(scores.get(str(sorted_ids[1]), -INF))
	if best_score - second_score < 0.08:
		return _get_nearest_anchor_biome(position)
	for biome_id in BIOME_IDS:
		var score := float(scores.get(biome_id, -INF))
		if score > best_score:
			best_score = score
			best_biome_id = biome_id
	return best_biome_id


func _get_nearest_anchor_biome(position: Vector2) -> String:
	var best_id := ""
	var best_distance := INF
	for anchor in biome_region_anchors:
		var anchor_pos := Vector2(anchor.get("position", Vector2.ZERO))
		var distance := position.distance_to(anchor_pos)
		if distance < best_distance:
			best_distance = distance
			best_id = str(anchor.get("biome_id", ""))
	return best_id if not best_id.is_empty() else "south_thicket"


func _get_polygon_biome_id_at(position: Vector2) -> String:
	for biome_value in WORLD_CONFIG.get_biome_zones():
		var biome := Dictionary(biome_value)
		var points := PackedVector2Array(biome.get("points", []))
		if points.size() >= 3 and Geometry2D.is_point_in_polygon(position, points):
			return _normalize_biome_id(str(biome.get("id", biome.get("name", ""))))
	return ""


func _normalize_biome_id(value: String) -> String:
	return value.strip_edges().to_lower().replace(" ", "_")


func _get_nearest_biome_zone_id(position: Vector2) -> String:
	var best_id := ""
	var best_distance := INF
	for biome_value in WORLD_CONFIG.get_biome_zones():
		var biome := Dictionary(biome_value)
		var points := PackedVector2Array(biome.get("points", []))
		if points.is_empty():
			continue
		var centroid := _get_polygon_centroid(points)
		var distance := position.distance_to(centroid)
		if distance < best_distance:
			best_distance = distance
			best_id = _normalize_biome_id(str(biome.get("id", biome.get("name", ""))))
	return best_id


func _get_polygon_centroid(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for point in points:
		sum += point
	return sum / float(points.size())


func _build_biome_ownership_map() -> void:
	biome_ownership_map.clear()
	for y in range(BIOME_OWNERSHIP_MAP_HEIGHT):
		var row: Array = []
		for x in range(BIOME_OWNERSHIP_MAP_WIDTH):
			var world_pos := _ownership_sample_to_world_position(x, y)
			row.append(_get_raw_biome_id_at(world_pos))
		biome_ownership_map.append(row)
	for _i in range(3):
		_smooth_biome_ownership_map()
	_remove_small_biome_islands(220)


func _ownership_sample_to_world_position(x: int, y: int) -> Vector2:
	var rect := GEN_CONFIG.WORLD_RECT
	var tx := float(x) / float(maxi(BIOME_OWNERSHIP_MAP_WIDTH - 1, 1))
	var ty := float(y) / float(maxi(BIOME_OWNERSHIP_MAP_HEIGHT - 1, 1))
	return Vector2(lerpf(rect.position.x, rect.end.x, tx), lerpf(rect.position.y, rect.end.y, ty))


func _smooth_biome_ownership_map() -> void:
	if biome_ownership_map.is_empty():
		return
	var smoothed: Array[Array] = []
	for y in range(biome_ownership_map.size()):
		var row: Array = []
		for x in range(Array(biome_ownership_map[y]).size()):
			var counts: Dictionary = {}
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var sy := clampi(y + oy, 0, biome_ownership_map.size() - 1)
					var sx := clampi(x + ox, 0, Array(biome_ownership_map[sy]).size() - 1)
					var neighbor_id := str(Array(biome_ownership_map[sy])[sx])
					counts[neighbor_id] = int(counts.get(neighbor_id, 0)) + 1
			var best_id := str(Array(biome_ownership_map[y])[x])
			var best_count := -1
			for biome_id in counts.keys():
				var count := int(counts[biome_id])
				if count > best_count:
					best_count = count
					best_id = str(biome_id)
			row.append(best_id)
		smoothed.append(row)
	biome_ownership_map = smoothed


func _remove_small_biome_islands(min_region_cells: int) -> void:
	if biome_ownership_map.is_empty():
		return
	var visited: Dictionary = {}
	var component_count := 0
	var small_components_removed := 0
	var cells_changed := 0
	var largest_component_per_biome: Dictionary = {}
	for y in range(biome_ownership_map.size()):
		for x in range(Array(biome_ownership_map[y]).size()):
			var cell := Vector2i(x, y)
			if visited.has(cell):
				continue
			var component := _collect_biome_component(cell, visited)
			component_count += 1
			if component.is_empty():
				continue
			var biome_id := str(Array(biome_ownership_map[cell.y])[cell.x])
			largest_component_per_biome[biome_id] = maxi(int(largest_component_per_biome.get(biome_id, 0)), component.size())
			if component.size() >= min_region_cells:
				continue
			var replacement_id := _get_dominant_neighbor_biome(component)
			if replacement_id.is_empty():
				continue
			small_components_removed += 1
			for component_cell in component:
				var row: Array = Array(biome_ownership_map[component_cell.y])
				if str(row[component_cell.x]) == replacement_id:
					continue
				row[component_cell.x] = replacement_id
				cells_changed += 1
	biome_cleanup_debug = {
		"component_count": component_count,
		"small_components_removed": small_components_removed,
		"largest_component_per_biome": largest_component_per_biome,
		"cells_changed": cells_changed
	}


func _collect_biome_component(start_cell: Vector2i, visited: Dictionary) -> Array[Vector2i]:
	var component: Array[Vector2i] = []
	var target_biome := str(Array(biome_ownership_map[start_cell.y])[start_cell.x])
	var stack: Array[Vector2i] = [start_cell]
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		if visited.has(cell):
			continue
		visited[cell] = true
		if str(Array(biome_ownership_map[cell.y])[cell.x]) != target_biome:
			continue
		component.append(cell)
		for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var nx: int = cell.x + offset.x
			var ny: int = cell.y + offset.y
			if ny < 0 or ny >= biome_ownership_map.size():
				continue
			var row: Array = Array(biome_ownership_map[ny])
			if nx < 0 or nx >= row.size():
				continue
			var neighbor_cell := Vector2i(nx, ny)
			if not visited.has(neighbor_cell):
				stack.append(neighbor_cell)
	return component


func _get_dominant_neighbor_biome(component: Array[Vector2i]) -> String:
	var neighbor_counts: Dictionary = {}
	for cell in component:
		for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var nx: int = cell.x + offset.x
			var ny: int = cell.y + offset.y
			if ny < 0 or ny >= biome_ownership_map.size():
				continue
			var row: Array = Array(biome_ownership_map[ny])
			if nx < 0 or nx >= row.size():
				continue
			var neighbor_id := str(row[nx])
			if neighbor_id.is_empty():
				continue
			neighbor_counts[neighbor_id] = int(neighbor_counts.get(neighbor_id, 0)) + 1
	var best_id := ""
	var best_count := -1
	for neighbor_id in neighbor_counts.keys():
		var count := int(neighbor_counts[neighbor_id])
		if count > best_count:
			best_count = count
			best_id = str(neighbor_id)
	return best_id


func _sample_biome_ownership_map(position: Vector2) -> String:
	if biome_ownership_map.is_empty():
		return _get_raw_biome_id_at(position)
	var rect := GEN_CONFIG.WORLD_RECT
	var tx := clampf((position.x - rect.position.x) / maxf(rect.size.x, 1.0), 0.0, 0.999999)
	var ty := clampf((position.y - rect.position.y) / maxf(rect.size.y, 1.0), 0.0, 0.999999)
	var x := clampi(int(tx * float(BIOME_OWNERSHIP_MAP_WIDTH)), 0, BIOME_OWNERSHIP_MAP_WIDTH - 1)
	var y := clampi(int(ty * float(BIOME_OWNERSHIP_MAP_HEIGHT)), 0, BIOME_OWNERSHIP_MAP_HEIGHT - 1)
	return str(Array(biome_ownership_map[y])[x])


func get_biome_coverage_debug() -> Dictionary:
	var counts: Dictionary = {}
	if biome_ownership_map.is_empty():
		return counts
	for row in biome_ownership_map:
		for biome_id in Array(row):
			var biome_key := str(biome_id)
			counts[biome_key] = int(counts.get(biome_key, 0)) + 1
	return counts


func get_debug_generation_key() -> String:
	return "biome_ownership_v8|seed=%d|anchors=%d|visual_features=%d|ownership=%dx%d" % [
		seed,
		biome_region_anchors.size(),
		visual_biome_features.size(),
		BIOME_OWNERSHIP_MAP_WIDTH,
		BIOME_OWNERSHIP_MAP_HEIGHT
	]
