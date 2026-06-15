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
var feature_counts_debug: Dictionary = {"pond": 0, "highland": 0, "rocky_patch": 0}

const POND_THRESHOLD := 0.48
const WETLAND_THRESHOLD := 0.66
const RIDGE_THRESHOLD := 0.86
const ROCKY_PATCH_THRESHOLD := 0.62
const TOPOGRAPHY_RULES_VERSION := "v4"

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
	_build_topography_features()
	_update_feature_counts()

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
	var sample := {
		"base_terrain_zone": base_zone,
		"terrain_zone": base_zone,
		"elevation_band": base_zone,
		"ridge_value": -999.0,
		"wetland_value": -999.0,
		"pond_influence": 0.0,
		"highland_influence": 0.0,
		"rocky_influence": 0.0,
		"dominant_feature_type": "",
		"dominant_feature_influence": 0.0,
		"dominant_feature_home_biome_id": _get_biome_id(position)
	}
	if base_zone not in ["land", "highland"]:
		return sample

	var pond_value := _get_pond_value(position)
	var wetland_value := _get_wetland_value(position)
	var ridge_value := _get_ridge_value(position)
	var rocky_value := _get_rocky_value(position)

	sample["pond_influence"] = pond_value
	sample["wetland_value"] = wetland_value
	sample["ridge_value"] = ridge_value
	sample["rocky_influence"] = rocky_value
	sample["highland_influence"] = ridge_value

	var dominant_type := "land"
	var dominant_influence := 0.0
	if pond_value > dominant_influence:
		dominant_influence = pond_value
		dominant_type = "pond"
	if wetland_value > dominant_influence:
		dominant_influence = wetland_value
		dominant_type = "wetland"
	if ridge_value > dominant_influence:
		dominant_influence = ridge_value
		dominant_type = "ridge"
	if rocky_value > dominant_influence:
		dominant_influence = rocky_value
		dominant_type = "rocky_patch"

	sample["dominant_feature_type"] = dominant_type
	sample["dominant_feature_influence"] = dominant_influence

	if pond_value > POND_THRESHOLD:
		sample["terrain_zone"] = "pond"
		sample["elevation_band"] = "pond"
	elif wetland_value > WETLAND_THRESHOLD and pond_value <= POND_THRESHOLD:
		sample["terrain_zone"] = "wetland"
		sample["elevation_band"] = "wetland"
	elif ridge_value > RIDGE_THRESHOLD:
		sample["terrain_zone"] = "highland"
		sample["elevation_band"] = "highland_peak" if ridge_value > 0.94 else "highland_mid"
	elif rocky_value > ROCKY_PATCH_THRESHOLD:
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
	for feature_value in topography_features:
		var feature := Dictionary(feature_value)
		if str(feature.get("type", "")) == feature_type:
			result.append(feature)
	return result

func get_topography_zone_at(position: Vector2) -> String:
	return str(sample_topography_at(position).get("terrain_zone", "land"))

func get_elevation_band_at(position: Vector2) -> String:
	return str(sample_topography_at(position).get("elevation_band", "land"))

func get_pond_value(position: Vector2) -> float:
	return _get_pond_value(position)

func _get_pond_value(position: Vector2) -> float:
	var base_zone := _get_base_terrain_zone(position)
	if base_zone not in ["land", "highland"]:
		return -999.0
	var height_bias := 1.0 - absf(_get_height_hint(position) - 0.34)
	var moisture := wetland_noise.get_noise_2d(position.x, position.y)
	var pond_shape := pond_noise.get_noise_2d(position.x, position.y)
	return pond_shape * 0.55 + moisture * 0.30 + height_bias * 0.15

func _get_wetland_value(position: Vector2) -> float:
	var base_zone := _get_base_terrain_zone(position)
	if base_zone not in ["land", "highland"]:
		return -999.0
	return wetland_noise.get_noise_2d(position.x, position.y)

func _get_ridge_value(position: Vector2) -> float:
	var base_zone := _get_base_terrain_zone(position)
	if base_zone not in ["land", "highland"]:
		return -999.0
	var height_hint := _get_height_hint(position)
	var ridge := ridge_noise.get_noise_2d(position.x, position.y)
	return height_hint * 0.65 + ridge * 0.35

func _get_rocky_value(position: Vector2) -> float:
	var base_zone := _get_base_terrain_zone(position)
	if base_zone not in ["land", "highland"]:
		return -999.0
	return rocky_noise.get_noise_2d(position.x, position.y)

func _get_height_hint(position: Vector2) -> float:
	var rect := Rect2(Vector2(-1000.0, -1000.0), Vector2(2000.0, 2000.0))
	var normalized := Vector2(
		(position.x - rect.get_center().x) / maxf(rect.size.x * 0.5, 1.0),
		(position.y - rect.get_center().y) / maxf(rect.size.y * 0.5, 1.0)
	)
	return clampf(1.0 - normalized.length(), 0.0, 1.0)

func _build_topography_features() -> void:
	topography_features.clear()
	feature_counts_debug = {"pond": 0, "highland": 0, "rocky_patch": 0}
	var rect := Rect2(Vector2(-1000.0, -1000.0), Vector2(2000.0, 2000.0))
	var target_ponds := randi_range(4, 8)
	var target_highlands := randi_range(5, 9)
	var target_rocks := randi_range(5, 10)
	_spawn_features_for_type("pond", target_ponds, rect)
	_spawn_features_for_type("highland", target_highlands, rect)
	_spawn_features_for_type("rocky_patch", target_rocks, rect)

func _spawn_features_for_type(feature_type: String, count: int, rect: Rect2) -> void:
	for _i in range(count):
		var position := _find_feature_position(feature_type, rect)
		if position == Vector2.INF:
			continue
		var radius := _get_feature_radius(feature_type)
		var biome_id := _get_biome_id(position)
		topography_features.append({
			"type": feature_type,
			"position": position,
			"radius": radius,
			"biome_id": biome_id
		})

func _find_feature_position(feature_type: String, rect: Rect2) -> Vector2:
	for _attempt in range(800):
		var candidate := Vector2(
			rng.randf_range(rect.position.x, rect.end.x),
			rng.randf_range(rect.position.y, rect.end.y)
		)
		if _is_valid_feature_position(feature_type, candidate):
			return candidate
	return Vector2.INF

func _is_valid_feature_position(feature_type: String, position: Vector2) -> bool:
	if _get_base_terrain_zone(position) not in ["land", "highland"]:
		return false
	var biome_id := _get_biome_id(position)
	if biome_id.is_empty():
		return false
	var sample := sample_topography_at(position)
	if feature_type == "pond":
		return float(sample.get("pond_influence", 0.0)) >= 0.65 or get_base_terrain_zone(position) == "land"
	if feature_type == "highland":
		return float(sample.get("dominant_feature_influence", 0.0)) >= 0.55 or get_base_terrain_zone(position) == "land"
	return float(sample.get("dominant_feature_influence", 0.0)) >= 0.55 or get_base_terrain_zone(position) == "land"

func _get_feature_radius(feature_type: String) -> float:
	match feature_type:
		"pond":
			return randf_range(110.0, 220.0)
		"highland":
			return randf_range(140.0, 260.0)
		"rocky_patch":
			return randf_range(80.0, 180.0)
	return randf_range(90.0, 200.0)

func _update_feature_counts() -> void:
	feature_counts_debug["pond"] = get_topography_features_by_type("pond").size()
	feature_counts_debug["highland"] = get_topography_features_by_type("highland").size()
	feature_counts_debug["rocky_patch"] = get_topography_features_by_type("rocky_patch").size()

func is_pond_at(position: Vector2) -> bool:
	return sample_topography_at(position).get("terrain_zone", "") == "pond"

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

func is_ridge_at(position: Vector2) -> bool:
	return sample_topography_at(position).get("terrain_zone", "") == "highland"

func is_rocky_patch_at(position: Vector2) -> bool:
	return sample_topography_at(position).get("terrain_zone", "") == "rocky_patch"

func is_wetland_at(position: Vector2) -> bool:
	return sample_topography_at(position).get("terrain_zone", "") == "wetland"
