extends RefCounted
class_name WorldTopography

var seed: int = 1
var rng := RandomNumberGenerator.new()
var biome_id_getter: Callable
var base_terrain_getter: Callable
var pond_noise := FastNoiseLite.new()
var ridge_noise := FastNoiseLite.new()
var wetland_noise := FastNoiseLite.new()
var rocky_noise := FastNoiseLite.new()
var topography_features: Array[Dictionary] = []
var topography_features_by_type: Dictionary = {}
var feature_counts_debug: Dictionary = {"pond": 0, "highland": 0, "rocky_patch": 0}

const POND_THRESHOLD := 0.46
const WETLAND_THRESHOLD := 0.63
const RIDGE_THRESHOLD := 0.84
const ROCKY_PATCH_THRESHOLD := 0.60
const TOPOGRAPHY_RULES_VERSION := "v6"
const TOPOGRAPHY_BOUNDS := Rect2(Vector2(-1000.0, -1000.0), Vector2(2000.0, 2000.0))
const TOPOGRAPHY_HALF_EXTENTS := Vector2(1000.0, 1000.0)
const FEATURE_POSITION_ATTEMPTS := 800

func setup(p_seed: int, p_biome_id_getter: Callable = Callable(), p_base_terrain_getter: Callable = Callable()) -> void:
	seed = p_seed if p_seed != 0 else 1
	rng.seed = seed + 9127
	biome_id_getter = p_biome_id_getter
	base_terrain_getter = p_base_terrain_getter
	pond_noise.seed = seed + 1101
	pond_noise.frequency = 0.0018
	ridge_noise.seed = seed + 2202
	ridge_noise.frequency = 0.0018
	wetland_noise.seed = seed + 3303
	wetland_noise.frequency = 0.0032
	rocky_noise.seed = seed + 4404
	rocky_noise.frequency = 0.0038
	_reset_feature_index()
	_build_topography_features()
	_rebuild_feature_index()
	_update_feature_counts()


func _reset_feature_index() -> void:
	topography_features_by_type = {
		"pond": [],
		"highland": [],
		"rocky_patch": []
	}


func _rebuild_feature_index() -> void:
	_reset_feature_index()
	for feature_value in topography_features:
		var feature := Dictionary(feature_value)
		var feature_type := str(feature.get("type", ""))
		if not topography_features_by_type.has(feature_type):
			topography_features_by_type[feature_type] = []
		var feature_list: Array = Array(topography_features_by_type[feature_type])
		feature_list.append(feature)
		topography_features_by_type[feature_type] = feature_list


func _get_base_terrain_zone(position: Vector2) -> String:
	if base_terrain_getter.is_valid():
		return str(base_terrain_getter.call(position))
	return "land"


func get_base_terrain_zone(position: Vector2) -> String:
	return _get_base_terrain_zone(position)


func _get_biome_id(position: Vector2) -> String:
	if biome_id_getter.is_valid():
		return str(biome_id_getter.call(position))
	return ""


func get_topography_zone(position: Vector2) -> String:
	return str(sample_topography_at(position).get("terrain_zone", "land"))


func sample_topography_at(position: Vector2) -> Dictionary:
	var base_zone := _get_base_terrain_zone(position)
	var biome_id := _get_biome_id(position)
	return _sample_topography_uncached(position, base_zone, biome_id)


func _sample_topography_uncached(position: Vector2, base_zone: String, biome_id: String) -> Dictionary:
	var sample := {
		"base_terrain_zone": base_zone,
		"terrain_zone": base_zone,
		"elevation_band": base_zone,
		"ridge_value": -999.0,
		"wetland_value": -999.0,
		"pond_influence": 0.0,
		"best_pond_influence": 0.0,
		"best_highland_influence": 0.0,
		"best_rocky_influence": 0.0,
		"highland_influence": 0.0,
		"rocky_influence": 0.0,
		"dominant_feature_type": "",
		"dominant_feature_influence": 0.0,
		"dominant_feature_home_biome_id": biome_id
	}
	if base_zone not in ["land", "highland"]:
		return sample

	var height_hint := _get_height_hint(position)
	var pond_value := _get_pond_value_for_base(position, base_zone, height_hint)
	var wetland_value := _get_wetland_value_for_base(position, base_zone)
	var ridge_value := _get_ridge_value_for_base(position, base_zone, height_hint)
	var rocky_value := _get_rocky_value_for_base(position, base_zone)
	var pond_feature := _get_feature_influence(position, "pond")
	var highland_feature := _get_feature_influence(position, "highland")
	var rocky_feature := _get_feature_influence(position, "rocky_patch")
	var pond_influence := maxf(pond_value, pond_feature)
	var highland_influence := maxf(ridge_value, highland_feature)
	var rocky_influence := maxf(rocky_value, rocky_feature)

	sample["pond_influence"] = pond_influence
	sample["best_pond_influence"] = pond_influence
	sample["wetland_value"] = wetland_value
	sample["ridge_value"] = highland_influence
	sample["best_highland_influence"] = highland_influence
	sample["rocky_influence"] = rocky_influence
	sample["best_rocky_influence"] = rocky_influence
	sample["highland_influence"] = highland_influence

	var dominant_type := "land"
	var dominant_influence := 0.0
	if pond_influence > dominant_influence:
		dominant_influence = pond_influence
		dominant_type = "pond"
	if wetland_value > dominant_influence:
		dominant_influence = wetland_value
		dominant_type = "wetland"
	if highland_influence > dominant_influence:
		dominant_influence = highland_influence
		dominant_type = "ridge"
	if rocky_influence > dominant_influence:
		dominant_influence = rocky_influence
		dominant_type = "rocky_patch"

	sample["dominant_feature_type"] = dominant_type
	sample["dominant_feature_influence"] = dominant_influence

	if pond_influence > POND_THRESHOLD:
		sample["terrain_zone"] = "pond"
		sample["elevation_band"] = "pond"
	elif wetland_value > WETLAND_THRESHOLD and pond_influence <= POND_THRESHOLD:
		sample["terrain_zone"] = "wetland"
		sample["elevation_band"] = "wetland"
	elif highland_influence > RIDGE_THRESHOLD:
		sample["terrain_zone"] = "highland"
		sample["elevation_band"] = "highland_peak" if highland_influence > 0.94 else "highland_mid"
	elif rocky_influence > ROCKY_PATCH_THRESHOLD:
		sample["terrain_zone"] = "rocky_patch"
		sample["elevation_band"] = "rocky_patch"
	elif base_zone == "highland":
		sample["terrain_zone"] = "highland"
		sample["elevation_band"] = "highland_low"

	return sample


func get_topography_debug_at(position: Vector2) -> Dictionary:
	return sample_topography_at(position)


func get_topography_feature_counts_debug() -> Dictionary:
	return feature_counts_debug.duplicate(true)


func get_topography_features_by_type(feature_type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for feature_value in Array(topography_features_by_type.get(feature_type, [])):
		result.append(Dictionary(feature_value).duplicate(true))
	return result


func get_topography_zone_at(position: Vector2) -> String:
	return str(sample_topography_at(position).get("terrain_zone", "land"))


func get_elevation_band_at(position: Vector2) -> String:
	return str(sample_topography_at(position).get("elevation_band", "land"))


func get_pond_value(position: Vector2) -> float:
	return _get_pond_value(position)


func _get_pond_value(position: Vector2) -> float:
	return _get_pond_value_for_base(position, _get_base_terrain_zone(position), _get_height_hint(position))


func _get_pond_value_for_base(position: Vector2, base_zone: String, height_hint: float) -> float:
	if base_zone not in ["land", "highland"]:
		return -999.0
	var height_bias := 1.0 - absf(height_hint - 0.34)
	var moisture := wetland_noise.get_noise_2d(position.x, position.y)
	var pond_shape := pond_noise.get_noise_2d(position.x, position.y)
	return pond_shape * 0.55 + moisture * 0.30 + height_bias * 0.15


func _get_wetland_value(position: Vector2) -> float:
	return _get_wetland_value_for_base(position, _get_base_terrain_zone(position))


func _get_wetland_value_for_base(position: Vector2, base_zone: String) -> float:
	if base_zone not in ["land", "highland"]:
		return -999.0
	return wetland_noise.get_noise_2d(position.x, position.y)


func _get_ridge_value(position: Vector2) -> float:
	return _get_ridge_value_for_base(position, _get_base_terrain_zone(position), _get_height_hint(position))


func _get_ridge_value_for_base(position: Vector2, base_zone: String, height_hint: float) -> float:
	if base_zone not in ["land", "highland"]:
		return -999.0
	var ridge := ridge_noise.get_noise_2d(position.x, position.y)
	return height_hint * 0.65 + ridge * 0.35


func _get_rocky_value(position: Vector2) -> float:
	return _get_rocky_value_for_base(position, _get_base_terrain_zone(position))


func _get_rocky_value_for_base(position: Vector2, base_zone: String) -> float:
	if base_zone not in ["land", "highland"]:
		return -999.0
	return rocky_noise.get_noise_2d(position.x, position.y)


func _get_height_hint(position: Vector2) -> float:
	var normalized := Vector2(
		position.x / maxf(TOPOGRAPHY_HALF_EXTENTS.x, 1.0),
		position.y / maxf(TOPOGRAPHY_HALF_EXTENTS.y, 1.0)
	)
	return clampf(1.0 - normalized.length(), 0.0, 1.0)


func _build_topography_features() -> void:
	topography_features.clear()
	feature_counts_debug = {"pond": 0, "highland": 0, "rocky_patch": 0}
	var target_ponds := rng.randi_range(1, 3)
	var target_highlands := rng.randi_range(3, 5)
	var target_rocks := rng.randi_range(4, 7)
	_spawn_features_for_type("pond", target_ponds, TOPOGRAPHY_BOUNDS)
	_spawn_features_for_type("highland", target_highlands, TOPOGRAPHY_BOUNDS)
	_spawn_features_for_type("rocky_patch", target_rocks, TOPOGRAPHY_BOUNDS)


func _spawn_features_for_type(feature_type: String, count: int, rect: Rect2) -> void:
	for _i in range(count):
		var radius := _get_feature_radius(feature_type)
		var position := _find_feature_position(feature_type, rect, radius)
		if position == Vector2.INF:
			continue
		var biome_id := _get_biome_id(position)
		topography_features.append({
			"type": feature_type,
			"position": position,
			"radius": radius,
			"biome_id": biome_id
		})


func _find_feature_position(feature_type: String, rect: Rect2, candidate_radius: float) -> Vector2:
	for _attempt in range(FEATURE_POSITION_ATTEMPTS):
		var candidate := Vector2(
			rng.randf_range(rect.position.x, rect.end.x),
			rng.randf_range(rect.position.y, rect.end.y)
		)
		if _is_valid_feature_position(feature_type, candidate, candidate_radius):
			return candidate
	return Vector2.INF


func _is_valid_feature_position(feature_type: String, position: Vector2, candidate_radius: float) -> bool:
	var base_zone := _get_base_terrain_zone(position)
	if base_zone not in ["land", "highland"]:
		return false
	var biome_id := _get_biome_id(position)
	if biome_id.is_empty():
		return false
	var sample := _sample_topography_uncached(position, base_zone, biome_id)
	var min_spacing := candidate_radius * 1.45
	for feature_value in topography_features:
		var existing_position := Vector2(feature_value.get("position", Vector2.ZERO))
		var existing_radius := maxf(float(feature_value.get("radius", 1.0)), 1.0)
		var required_spacing := maxf(min_spacing, existing_radius * 1.2)
		if position.distance_squared_to(existing_position) < required_spacing * required_spacing:
			return false
	if feature_type == "pond":
		return float(sample.get("pond_influence", 0.0)) >= 0.40 or base_zone == "land"
	if feature_type == "highland":
		return float(sample.get("dominant_feature_influence", 0.0)) >= 0.55 or base_zone == "land"
	return float(sample.get("dominant_feature_influence", 0.0)) >= 0.55 or base_zone == "land"


func _get_feature_radius(feature_type: String) -> float:
	match feature_type:
		"pond":
			return rng.randf_range(900.0, 1800.0)
		"highland":
			return rng.randf_range(260.0, 420.0)
		"rocky_patch":
			return rng.randf_range(120.0, 220.0)
	return rng.randf_range(120.0, 240.0)


func _update_feature_counts() -> void:
	feature_counts_debug["pond"] = Array(topography_features_by_type.get("pond", [])).size()
	feature_counts_debug["highland"] = Array(topography_features_by_type.get("highland", [])).size()
	feature_counts_debug["rocky_patch"] = Array(topography_features_by_type.get("rocky_patch", [])).size()


func _get_feature_influence(position: Vector2, feature_type: String) -> float:
	var features := Array(topography_features_by_type.get(feature_type, []))
	if features.is_empty():
		return 0.0
	var best := 0.0
	var strength := _get_feature_strength(feature_type)
	for feature_value in features:
		var center := Vector2(feature_value.get("position", Vector2.ZERO))
		var radius := maxf(float(feature_value.get("radius", 1.0)), 1.0)
		var radius_squared := radius * radius
		var distance_squared := position.distance_squared_to(center)
		if distance_squared >= radius_squared:
			continue
		var normalized := clampf(1.0 - sqrt(distance_squared) / radius, 0.0, 1.0)
		best = maxf(best, pow(normalized, 1.35) * strength)
	return best


func _get_feature_strength(feature_type: String) -> float:
	match feature_type:
		"pond":
			return 0.72
		"highland":
			return 0.98
		"rocky_patch":
			return 0.78
	return 0.5


func is_pond_at(position: Vector2) -> bool:
	return sample_topography_at(position).get("terrain_zone", "") == "pond"


func is_near_pond(position: Vector2, radius: float = 90.0) -> bool:
	return (
		is_pond_at(position)
		or is_pond_at(position + Vector2(radius, 0.0))
		or is_pond_at(position + Vector2(-radius, 0.0))
		or is_pond_at(position + Vector2(0.0, radius))
		or is_pond_at(position + Vector2(0.0, -radius))
	)


func is_ridge_at(position: Vector2) -> bool:
	return sample_topography_at(position).get("terrain_zone", "") == "highland"


func is_rocky_patch_at(position: Vector2) -> bool:
	return sample_topography_at(position).get("terrain_zone", "") == "rocky_patch"


func is_wetland_at(position: Vector2) -> bool:
	return sample_topography_at(position).get("terrain_zone", "") == "wetland"
