extends RefCounted
class_name WorldConfig

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")

const BASELINE_WORLD_SCALE := 3.0
const WORLD_SCALE := 6.0
const BASE_WORLD_RECT := Rect2(-1680, -1040, 3360, 2080)
const WORLD_RECT := Rect2(BASE_WORLD_RECT.position * WORLD_SCALE, BASE_WORLD_RECT.size * WORLD_SCALE)
const WORLD_LINEAR_SCALE_FACTOR := WORLD_SCALE / BASELINE_WORLD_SCALE
const WORLD_AREA_SCALE_FACTOR := WORLD_LINEAR_SCALE_FACTOR * WORLD_LINEAR_SCALE_FACTOR
const RESOURCE_DENSITY_MULTIPLIER := 1.35
const DECORATIVE_VEGETATION_DENSITY_MULTIPLIER := 2.0
const ROCK_DENSITY_MULTIPLIER := 1.35
const FOOD_BUSH_DENSITY_MULTIPLIER := 1.35
const CREATURE_DENSITY_MULTIPLIER := 1.35
const VARNAK_DENSITY_MULTIPLIER := 1.25
const ISLAND_RADIUS_X_RATIO := 0.82
const ISLAND_RADIUS_Y_RATIO := 0.74
const ISLAND_EDGE_FALLOFF_POWER := 1.45
const ISLAND_NOISE_SCALE := 0.0024
const ISLAND_NOISE_STRENGTH := 0.24
const DEEP_OCEAN_THRESHOLD := 0.04
const SHALLOW_WATER_THRESHOLD := 0.10
const SHORE_THRESHOLD := 0.20
const HIGHLAND_THRESHOLD := 0.72
const INNER_POND_CHANCE_MULTIPLIER := 0.35
const PLAYER_EDGE_PADDING := 40.0
const PLAYER_START_POSITION := Vector2(-260.0, 40.0)
const PLAYER_LANDMARK_SAFE_DISTANCE := 760.0
const PLAYER_POND_SAFE_DISTANCE := 900.0
const PLAYER_HILL_SAFE_DISTANCE := 520.0
const PLAYER_SPAWN_SEARCH_STEP := 160.0
const PLAYER_SPAWN_SEARCH_RINGS := 10

const TREE_COUNT := 48
const WESTWOOD_EXTRA_CONIFER_COUNT := 48
const ROCK_COUNT := 24
const BUSH_COUNT := 36
const SMALL_BUSH_COUNT := 28
const BERRY_BUSH_COUNT := 14
const GRASS_PATCH_COUNT := 72
const DENSE_GRASS_COUNT := 34
const REDFANG_EXTRA_DRY_TREE_COUNT := 18
const REDFANG_EXTRA_DRY_BUSH_COUNT := 24
const REDFANG_EXTRA_DRY_TREE_COUNT_MAX := 42
const REDFANG_EXTRA_DRY_BUSH_COUNT_MAX := 55
const TREE_COUNT_MAX := 170
const WESTWOOD_EXTRA_CONIFER_COUNT_MAX := 130
const ROCK_COUNT_MAX := 85
const BUSH_COUNT_MAX := 120
const SMALL_BUSH_COUNT_MAX := 110
const BERRY_BUSH_COUNT_MAX := 55
const GRASS_PATCH_COUNT_MAX := 260
const DENSE_GRASS_COUNT_MAX := 180
const RESOURCE_SPAWN_ATTEMPTS_MAX := 360

const RESOURCE_SPAWN_MARGIN := 95.0
const RESOURCE_MIN_DISTANCE := 90.0
const RESOURCE_PLAYER_SAFE_DISTANCE := 260.0
const RESOURCE_SPAWN_ATTEMPTS := 160

const VARNAK_TARGET_COUNT := 8
const VARNAK_PLAYER_SAFE_DISTANCE := 560.0
const VARNAK_SPAWN_ATTEMPTS := 36
const VARNAK_SPAWN_POINTS := [
	Vector2(220, 0),
	Vector2(-470, -300),
	Vector2(420, 330),
	Vector2(-980, -560),
	Vector2(1040, 520),
	Vector2(760, -680),
	Vector2(980, -120),
	Vector2(1220, -420),
	Vector2(1160, 760),
	Vector2(-1140, 580),
	Vector2(-1290, -120),
	Vector2(-1040, 790),
	Vector2(-240, -760),
	Vector2(90, 700),
	Vector2(620, 810),
	Vector2(1360, 110)
]

const LANDMARKS := [
	{
		"id": "westwood_old_hill",
		"type": "hill",
		"position": Vector2(-1120, -430),
		"radius": 170.0,
		"biome_id": "westwood",
		"gameplay_tags": ["high_ground", "navigation"]
	},
	{
		"id": "westwood_shade_pond",
		"type": "pond",
		"position": Vector2(-980, 360),
		"radius": 145.0,
		"biome_id": "westwood",
		"gameplay_tags": ["water_source", "vegetation_bonus"]
	},
	{
		"id": "stoneback_spine",
		"type": "hill",
		"position": Vector2(-180, -640),
		"radius": 210.0,
		"biome_id": "stoneback_ridge",
		"gameplay_tags": ["high_ground", "rocky"]
	},
	{
		"id": "stoneback_basin",
		"type": "pond",
		"position": Vector2(300, -540),
		"radius": 115.0,
		"biome_id": "stoneback_ridge",
		"gameplay_tags": ["water_source", "rare"]
	},
	{
		"id": "hearth_watch_hill",
		"type": "hill",
		"position": Vector2(-260, 40),
		"radius": 150.0,
		"biome_id": "hearth_meadow",
		"gameplay_tags": ["high_ground", "safe_landmark"]
	},
	{
		"id": "hearth_mirror_pond",
		"type": "pond",
		"position": Vector2(230, 120),
		"radius": 130.0,
		"biome_id": "hearth_meadow",
		"gameplay_tags": ["water_source", "vegetation_bonus", "safe_landmark"]
	},
	{
		"id": "south_thicket_mound",
		"type": "hill",
		"position": Vector2(-180, 600),
		"radius": 165.0,
		"biome_id": "south_thicket",
		"gameplay_tags": ["high_ground", "dense_cover"]
	},
	{
		"id": "south_thicket_pool",
		"type": "pond",
		"position": Vector2(310, 620),
		"radius": 150.0,
		"biome_id": "south_thicket",
		"gameplay_tags": ["water_source", "vegetation_bonus", "dense_cover"]
	},
	{
		"id": "redfang_lookout",
		"type": "hill",
		"position": Vector2(940, -520),
		"radius": 190.0,
		"biome_id": "redfang_wilds",
		"gameplay_tags": ["high_ground", "danger"]
	},
	{
		"id": "redfang_teeth",
		"type": "hill",
		"position": Vector2(1050, 460),
		"radius": 230.0,
		"biome_id": "redfang_wilds",
		"gameplay_tags": ["high_ground", "danger", "navigation"]
	},
	{
		"id": "redfang_darkwater",
		"type": "pond",
		"position": Vector2(910, 60),
		"radius": 135.0,
		"biome_id": "redfang_wilds",
		"gameplay_tags": ["water_source", "danger"]
	},
	{
		"id": "north_coast_pool",
		"type": "pond",
		"position": Vector2(-260, -760),
		"radius": 120.0,
		"biome_id": "stoneback_ridge",
		"gameplay_tags": ["water_source", "coast"]
	},
	{
		"id": "south_marsh_pool",
		"type": "pond",
		"position": Vector2(-120, 820),
		"radius": 150.0,
		"biome_id": "south_thicket",
		"gameplay_tags": ["water_source", "vegetation_bonus"]
	},
	{
		"id": "far_west_hill",
		"type": "hill",
		"position": Vector2(-1320, 120),
		"radius": 180.0,
		"biome_id": "westwood",
		"gameplay_tags": ["high_ground", "navigation"]
	},
	{
		"id": "east_ridge_hill",
		"type": "hill",
		"position": Vector2(1260, -140),
		"radius": 210.0,
		"biome_id": "redfang_wilds",
		"gameplay_tags": ["high_ground", "danger"]
	}
]

const HILL_LANDMARK_PRIORITY := [
	"westwood_old_hill",
	"far_west_hill",
	"stoneback_spine",
	"hearth_watch_hill",
	"south_thicket_mound",
	"redfang_teeth",
	"redfang_lookout",
	"east_ridge_hill"
]

const POND_LANDMARK_PRIORITY := [
	"westwood_shade_pond",
	"north_coast_pool",
	"hearth_mirror_pond",
	"redfang_darkwater",
	"south_thicket_pool",
	"south_marsh_pool",
	"stoneback_basin"
]

const BIOME_ZONES := [
	{
		"name": "Westwood",
		"points": [
			Vector2(-1440, -880),
			Vector2(-690, -880),
			Vector2(-560, -620),
			Vector2(-720, -260),
			Vector2(-560, 130),
			Vector2(-700, 520),
			Vector2(-610, 880),
			Vector2(-1440, 880)
		],
		"color": Color(0.10, 0.24, 0.13),
		"tree_weight": 18.0,
		"conifer_tree_weight": 22.0,
		"leafy_tree_weight": 2.0,
		"dry_tree_weight": 0.4,
		"rock_weight": 1.2,
		"bush_weight": 5.0,
		"berry_bush_weight": 7.5,
		"dry_bush_weight": 0.8,
		"grass_weight": 8.0,
		"landmark_weights": {
			"hill": 0.08,
			"pond": 2.25
		},
		"landmark_tag_weights": {
			"vegetation_bonus": 1.25
		},
		"dangerous": false
	},
	{
		"name": "Stoneback Ridge",
		"points": [
			Vector2(-690, -880),
			Vector2(540, -880),
			Vector2(680, -710),
			Vector2(470, -470),
			Vector2(560, -250),
			Vector2(120, -300),
			Vector2(-120, -230),
			Vector2(-560, -360),
			Vector2(-720, -620)
		],
		"color": Color(0.22, 0.25, 0.23),
		"tree_weight": 2.4,
		"conifer_tree_weight": 2.8,
		"leafy_tree_weight": 0.6,
		"dry_tree_weight": 0.4,
		"rock_weight": 11.0,
		"bush_weight": 1.0,
		"dry_bush_weight": 6.0,
		"berry_bush_weight": 0.3,
		"grass_weight": 1.7,
		"landmark_weights": {
			"hill": 1.85,
			"pond": 0.20
		},
		"landmark_tag_weights": {
			"rocky": 1.20
		},
		"dangerous": false
	},
	{
		"name": "Hearth Meadow",
		"points": [
			Vector2(-560, -360),
			Vector2(-120, -230),
			Vector2(120, -300),
			Vector2(560, -250),
			Vector2(650, 60),
			Vector2(470, 290),
			Vector2(130, 330),
			Vector2(-80, 250),
			Vector2(-430, 340),
			Vector2(-560, 130),
			Vector2(-720, -260)
		],
		"color": Color(0.16, 0.30, 0.14),
		"tree_weight": 7.0,
		"conifer_tree_weight": 2.0,
		"leafy_tree_weight": 12.0,
		"dry_tree_weight": 0.8,
		"rock_weight": 2.3,
		"bush_weight": 5.0,
		"dry_bush_weight": 1.4,
		"berry_bush_weight": 3.1,
		"grass_weight": 9.5,
		"landmark_weights": {
			"hill": 0.95,
			"pond": 1.05
		},
		"dangerous": false
	},
	{
		"name": "South Thicket",
		"points": [
			Vector2(-560, 130),
			Vector2(-430, 340),
			Vector2(-80, 250),
			Vector2(130, 330),
			Vector2(470, 290),
			Vector2(610, 540),
			Vector2(540, 880),
			Vector2(-610, 880),
			Vector2(-700, 520)
		],
		"color": Color(0.20, 0.34, 0.12),
		"tree_weight": 3.2,
		"conifer_tree_weight": 0.6,
		"leafy_tree_weight": 5.3,
		"dry_tree_weight": 0.4,
		"rock_weight": 1.1,
		"bush_weight": 7.5,
		"small_bush_weight": 6.2,
		"dry_bush_weight": 0.8,
		"berry_bush_weight": 1.15,
		"grass_weight": 10.0,
		"landmark_weights": {
			"hill": 0.10,
			"pond": 2.35
		},
		"landmark_tag_weights": {
			"vegetation_bonus": 1.25,
			"dense_cover": 1.15
		},
		"dangerous": false
	},
	{
		"name": "Redfang Wilds",
		"points": [
			Vector2(540, -880),
			Vector2(1440, -880),
			Vector2(1440, 880),
			Vector2(540, 880),
			Vector2(610, 540),
			Vector2(470, 290),
			Vector2(650, 60),
			Vector2(560, -250),
			Vector2(470, -470),
			Vector2(680, -710)
		],
		"color": Color(0.26, 0.18, 0.13),
		"tree_weight": 7.0,
		"conifer_tree_weight": 0.8,
		"leafy_tree_weight": 0.4,
		"dry_tree_weight": 24.0,
		"rock_weight": 6.0,
		"bush_weight": 2.5,
		"dry_bush_weight": 13.0,
		"berry_bush_weight": 0.2,
		"grass_weight": 0.9,
		"landmark_weights": {
			"hill": 1.60,
			"pond": 0.70
		},
		"landmark_tag_weights": {
			"danger": 1.40
		},
		"dangerous": true
	}
]

const BIOME_EDGE_SUBDIVISIONS := 10
const BIOME_EDGE_JITTER := 90.0
const BIOME_EDGE_NOISE_SCALE := 0.028
const OCEAN_COLOR := Color(0.08, 0.22, 0.40)

static var cached_organic_biome_zones: Array[Dictionary] = []
static var cached_organic_biome_zones_built := false
static var cached_world_boundary_points: PackedVector2Array = PackedVector2Array()
static var cached_world_boundary_points_built := false
static var cached_island_noise: FastNoiseLite = FastNoiseLite.new()


static func get_player_limits() -> Vector2:
	return WORLD_RECT.size * 0.5 - Vector2(PLAYER_EDGE_PADDING, PLAYER_EDGE_PADDING)


static func scale_count(base_count: int, multiplier: float, max_count: int) -> int:
	return mini(int(round(float(base_count) * multiplier)), max_count)


static func get_scaled_spawn_attempts(base_attempts: int, multiplier: float = 1.5, max_attempts: int = 400) -> int:
	return mini(int(round(float(base_attempts) * multiplier)), max_attempts)


static func get_tree_count() -> int:
	return scale_count(TREE_COUNT, RESOURCE_DENSITY_MULTIPLIER, TREE_COUNT_MAX)


static func get_westwood_extra_conifer_count() -> int:
	return scale_count(WESTWOOD_EXTRA_CONIFER_COUNT, RESOURCE_DENSITY_MULTIPLIER, WESTWOOD_EXTRA_CONIFER_COUNT_MAX)


static func get_rock_count() -> int:
	return scale_count(ROCK_COUNT, ROCK_DENSITY_MULTIPLIER, ROCK_COUNT_MAX)


static func get_bush_count() -> int:
	return scale_count(BUSH_COUNT, RESOURCE_DENSITY_MULTIPLIER, BUSH_COUNT_MAX)


static func get_small_bush_count() -> int:
	return scale_count(SMALL_BUSH_COUNT, RESOURCE_DENSITY_MULTIPLIER, SMALL_BUSH_COUNT_MAX)


static func get_berry_bush_count() -> int:
	return scale_count(BERRY_BUSH_COUNT, FOOD_BUSH_DENSITY_MULTIPLIER, BERRY_BUSH_COUNT_MAX)


static func get_grass_patch_count() -> int:
	return scale_count(GRASS_PATCH_COUNT, DECORATIVE_VEGETATION_DENSITY_MULTIPLIER, GRASS_PATCH_COUNT_MAX)


static func get_dense_grass_count() -> int:
	return scale_count(DENSE_GRASS_COUNT, DECORATIVE_VEGETATION_DENSITY_MULTIPLIER, DENSE_GRASS_COUNT_MAX)


static func get_redfang_extra_dry_tree_count() -> int:
	return scale_count(REDFANG_EXTRA_DRY_TREE_COUNT, RESOURCE_DENSITY_MULTIPLIER, REDFANG_EXTRA_DRY_TREE_COUNT_MAX)


static func get_redfang_extra_dry_bush_count() -> int:
	return scale_count(REDFANG_EXTRA_DRY_BUSH_COUNT, RESOURCE_DENSITY_MULTIPLIER, REDFANG_EXTRA_DRY_BUSH_COUNT_MAX)


static func get_varnak_target_count() -> int:
	return scale_count(VARNAK_TARGET_COUNT, VARNAK_DENSITY_MULTIPLIER, 14)


static func get_resource_spawn_attempts() -> int:
	return mini(int(round(float(RESOURCE_SPAWN_ATTEMPTS) * 2.0)), RESOURCE_SPAWN_ATTEMPTS_MAX)


static func get_small_prey_population_multiplier() -> float:
	return CREATURE_DENSITY_MULTIPLIER


static func get_grazer_population_multiplier() -> float:
	return CREATURE_DENSITY_MULTIPLIER


static func get_terrain_height(position: Vector2) -> float:
	var center := WORLD_RECT.get_center()
	var radius_x := WORLD_RECT.size.x * 0.5 * ISLAND_RADIUS_X_RATIO
	var radius_y := WORLD_RECT.size.y * 0.5 * ISLAND_RADIUS_Y_RATIO
	if radius_x <= 0.0 or radius_y <= 0.0:
		return 0.0
	var local_position := position - center
	var normalized := Vector2(local_position.x / radius_x, local_position.y / radius_y)
	var normalized_distance := normalized.length()
	var falloff := pow(clampf(normalized_distance, 0.0, 1.8), ISLAND_EDGE_FALLOFF_POWER)
	var island_noise := _get_island_noise()
	var base_noise := island_noise.get_noise_2d(position.x * ISLAND_NOISE_SCALE, position.y * ISLAND_NOISE_SCALE)
	var detail_noise := island_noise.get_noise_2d(position.x * ISLAND_NOISE_SCALE * 2.8, position.y * ISLAND_NOISE_SCALE * 2.8)
	var combined_noise := base_noise * 0.75 + detail_noise * 0.25
	return 1.04 - falloff + combined_noise * ISLAND_NOISE_STRENGTH


static func get_terrain_zone(position: Vector2) -> String:
	var height := get_terrain_height(position)
	if height < DEEP_OCEAN_THRESHOLD:
		return "deep_ocean"
	if height < SHALLOW_WATER_THRESHOLD:
		return "shallow_water"
	if height < SHORE_THRESHOLD:
		return "shore"
	if height < HIGHLAND_THRESHOLD:
		return "land"
	return "highland"


static func scale_world_point(point: Vector2) -> Vector2:
	return point * WORLD_SCALE


static func get_biome_points(biome: Dictionary) -> Array[Vector2]:
	var scaled_points: Array[Vector2] = []
	for point_value in biome["points"]:
		scaled_points.append(Vector2(point_value) * WORLD_SCALE)
	return scaled_points


static func get_biome_zones() -> Array[Dictionary]:
	if cached_organic_biome_zones_built:
		return _duplicate_biome_zones(cached_organic_biome_zones)
	cached_organic_biome_zones = []
	for biome_value in BIOME_ZONES:
		var biome := Dictionary(biome_value).duplicate(true)
		biome["points"] = _build_organic_biome_points(biome)
		biome["bounds"] = _get_polygon_bounds(PackedVector2Array(biome["points"]))
		biome["center"] = _get_polygon_center(PackedVector2Array(biome["points"]))
		cached_organic_biome_zones.append(biome)
	cached_organic_biome_zones_built = true
	return _duplicate_biome_zones(cached_organic_biome_zones)


static func _duplicate_biome_zones(zones: Array[Dictionary]) -> Array[Dictionary]:
	var duplicated: Array[Dictionary] = []
	for biome_value in zones:
		duplicated.append(Dictionary(biome_value).duplicate(true))
	return duplicated


static func _build_organic_biome_points(biome: Dictionary) -> Array[Vector2]:
	var base_points := get_biome_points(biome)
	if base_points.size() < 3:
		return base_points
	var biome_seed := _get_biome_seed(biome)
	var organic_points: Array[Vector2] = []
	for i in base_points.size():
		var a := base_points[i]
		var b := base_points[(i + 1) % base_points.size()]
		organic_points.append(a)
		for step in range(1, BIOME_EDGE_SUBDIVISIONS):
			var t := float(step) / float(BIOME_EDGE_SUBDIVISIONS)
			var midpoint := a.lerp(b, t)
			var edge := b - a
			var normal := Vector2(-edge.y, edge.x)
			if normal.length_squared() > 0.0001:
				normal = normal.normalized()
				var jitter := _get_biome_edge_jitter(midpoint, biome_seed)
				midpoint += normal * jitter
			organic_points.append(midpoint)
	return organic_points


static func _get_biome_seed(biome: Dictionary) -> float:
	var biome_name := str(biome.get("name", "biome"))
	var hash_value := 0
	for i in biome_name.length():
		hash_value = (hash_value * 31 + biome_name.unicode_at(i) * (i + 7)) % 10007
	return float(hash_value)


static func _get_biome_edge_jitter(point: Vector2, biome_seed: float) -> float:
	var wave := (
		sin(point.x * BIOME_EDGE_NOISE_SCALE + biome_seed * 0.013) * 0.42
		+ sin(point.y * BIOME_EDGE_NOISE_SCALE * 1.27 - biome_seed * 0.017) * 0.26
		+ sin((point.x + point.y) * BIOME_EDGE_NOISE_SCALE * 0.73 + biome_seed * 0.021) * 0.18
		+ sin((point.x - point.y) * BIOME_EDGE_NOISE_SCALE * 1.61 + biome_seed * 0.009) * 0.14
	) / 1.00
	return wave * BIOME_EDGE_JITTER


static func get_landmarks() -> Array[Dictionary]:
	return generate_landmarks(1)


static func get_world_boundary_points() -> PackedVector2Array:
	if cached_world_boundary_points_built:
		return cached_world_boundary_points.duplicate()
	cached_world_boundary_points = _build_world_boundary_points()
	cached_world_boundary_points_built = true
	return cached_world_boundary_points.duplicate()


static func get_world_distribution_debug(landmarks: Array[Dictionary]) -> Dictionary:
	var quadrants := {
		"north_west": 0,
		"north_east": 0,
		"south_west": 0,
		"south_east": 0
	}
	var center := WORLD_RECT.get_center()
	for landmark_value in landmarks:
		var landmark := Dictionary(landmark_value)
		var pos := Vector2(landmark.get("position", Vector2.ZERO))
		var key := "north_" if pos.y < center.y else "south_"
		key += "west" if pos.x < center.x else "east"
		quadrants[key] = int(quadrants.get(key, 0)) + 1
	return {
		"landmarks": landmarks.size(),
		"quadrants": quadrants
	}


static func clear_runtime_caches() -> void:
	cached_organic_biome_zones.clear()
	cached_organic_biome_zones_built = false
	cached_world_boundary_points.clear()
	cached_world_boundary_points_built = false


static func generate_landmarks(world_seed: int) -> Array[Dictionary]:
	var selected := _get_balanced_landmark_selection(world_seed)
	var scaled_landmarks: Array[Dictionary] = []
	for landmark_value in selected:
		scaled_landmarks.append(_scale_landmark(Dictionary(landmark_value)))
	return scaled_landmarks


static func get_safe_player_start_position(landmarks: Array[Dictionary]) -> Vector2:
	if is_safe_player_start_position(PLAYER_START_POSITION, landmarks):
		return PLAYER_START_POSITION
	for ring in range(1, PLAYER_SPAWN_SEARCH_RINGS + 1):
		var ring_distance := float(ring) * PLAYER_SPAWN_SEARCH_STEP
		var candidate_count: int = max(12, int(TAU * ring_distance / maxf(PLAYER_SPAWN_SEARCH_STEP * 0.75, 1.0)))
		for index in range(candidate_count):
			var angle := TAU * float(index) / float(candidate_count)
			var candidate := PLAYER_START_POSITION + Vector2.RIGHT.rotated(angle) * ring_distance
			if is_safe_player_start_position(candidate, landmarks):
				return candidate
	var world_center := WORLD_RECT.get_center()
	if is_safe_player_start_position(world_center, landmarks):
		return world_center
	return PLAYER_START_POSITION


static func is_safe_player_start_position(position: Vector2, landmarks: Array[Dictionary]) -> bool:
	var zone := get_terrain_zone(position)
	if zone != "land" and zone != "highland":
		return false
	if not WORLD_RECT.grow(-PLAYER_EDGE_PADDING * 4.0).has_point(position):
		return false
	for landmark_value in landmarks:
		var landmark := Dictionary(landmark_value)
		var landmark_position := Vector2(landmark.get("position", Vector2.ZERO))
		var radius := float(landmark.get("radius", 0.0))
		var landmark_type := str(landmark.get("type", ""))
		var safe_distance := PLAYER_LANDMARK_SAFE_DISTANCE
		if landmark_type == "pond":
			safe_distance = PLAYER_POND_SAFE_DISTANCE
		elif landmark_type == "hill":
			safe_distance = PLAYER_HILL_SAFE_DISTANCE
		if position.distance_to(landmark_position) < radius + safe_distance:
			return false
	return true


static func _get_balanced_landmark_selection(world_seed: int) -> Array[Dictionary]:
	# Ponds and hills are now generated by WorldTopography, not as landmark POIs.
	# Keep this hook for future non-topography POIs, but do not emit terrain features here.
	return []


static func _select_landmarks_for_type(landmark_type: String, target_count: int, world_seed: int) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for landmark_value in LANDMARKS:
		var landmark := Dictionary(landmark_value)
		if str(landmark.get("type", "")) == landmark_type:
			candidates.append(landmark)
	var clamped_count := clampi(target_count, 0, candidates.size())
	if clamped_count >= candidates.size():
		return candidates
	var selected: Array[Dictionary] = []
	var available: Array[Dictionary] = candidates.duplicate(true)
	var biomes: Array[Dictionary] = get_biome_zones()
	var rng := RandomNumberGenerator.new()
	rng.seed = _get_landmark_selection_seed(world_seed, landmark_type)
	while selected.size() < clamped_count and not available.is_empty():
		var total_weight := 0.0
		for candidate_value in available:
			total_weight += _get_landmark_candidate_weight(Dictionary(candidate_value), biomes)
		if total_weight <= 0.0:
			selected.append(available.pop_front())
			continue
		var roll := rng.randf() * total_weight
		var cumulative := 0.0
		for index in range(available.size()):
			var candidate := Dictionary(available[index])
			cumulative += _get_landmark_candidate_weight(candidate, biomes)
			if cumulative < roll and index < available.size() - 1:
				continue
			selected.append(candidate)
			available.remove_at(index)
			break
	return selected


static func _get_landmark_selection_seed(world_seed: int, landmark_type: String) -> int:
	var normalized_seed: int = abs(world_seed) if world_seed != 0 else 1
	match landmark_type:
		"hill":
			return normalized_seed * 131 + 17
		"pond":
			return normalized_seed * 131 + 29
		_:
			return normalized_seed * 131 + 53


static func _get_landmark_candidate_weight(landmark: Dictionary, biomes: Array[Dictionary]) -> float:
	var biome_id := str(landmark.get("biome_id", ""))
	var biome := _get_biome_by_id(biome_id, biomes)
	if biome.is_empty():
		return 1.0
	var landmark_type := str(landmark.get("type", ""))
	var weight := 1.0
	var biome_landmark_weights := Dictionary(biome.get("landmark_weights", {}))
	weight *= float(biome_landmark_weights.get(landmark_type, 1.0))
	var biome_tag_weights := Dictionary(biome.get("landmark_tag_weights", {}))
	var gameplay_tags: Array = Array(landmark.get("gameplay_tags", []))
	for tag_value in gameplay_tags:
		weight *= float(biome_tag_weights.get(str(tag_value), 1.0))
	return max(weight, 0.0)


static func _scale_landmark(landmark: Dictionary) -> Dictionary:
	var scaled := landmark.duplicate(true)
	scaled["position"] = scale_world_point(Vector2(landmark.get("position", Vector2.ZERO)))
	scaled["radius"] = float(landmark.get("radius", 120.0)) * WORLD_SCALE
	return scaled


static func _get_biome_by_id(target_biome_id: String, biomes: Array[Dictionary]) -> Dictionary:
	for biome_value in biomes:
		var biome := Dictionary(biome_value)
		if _get_biome_id(biome) == target_biome_id:
			return biome
	return {}


static func _generate_landmark_position(landmark: Dictionary, biome: Dictionary, placed_landmarks: Array[Dictionary], rng: RandomNumberGenerator) -> Vector2:
	var fallback_position := Vector2(landmark.get("position", Vector2.ZERO))
	if biome.is_empty():
		return fallback_position
	var points := PackedVector2Array(biome.get("points", []))
	if points.is_empty():
		return fallback_position
	var bounds := _get_polygon_bounds(points)
	var radius := float(landmark.get("radius", 120.0))
	var spawn_margin := _get_landmark_spawn_margin(str(landmark.get("type", "")))
	var world_margin := spawn_margin + radius
	var player_position := PLAYER_START_POSITION
	var min_landmark_distance := float(GAME_BALANCE.LANDMARKS.get("landmark_min_distance", 420.0))
	for _attempt in 96:
		var candidate := Vector2(
			rng.randf_range(bounds.position.x, bounds.end.x),
			rng.randf_range(bounds.position.y, bounds.end.y)
		)
		if not Geometry2D.is_point_in_polygon(candidate, points):
			continue
		if not _is_landmark_inside_world_bounds(candidate, world_margin):
			continue
		if not _is_landmark_position_on_valid_terrain(candidate, radius):
			continue
		if _is_landmark_too_close_to_player(candidate, radius, player_position):
			continue
		if _is_landmark_too_close_to_others(candidate, radius, placed_landmarks, min_landmark_distance):
			continue
		return candidate
	return _find_landmark_fallback_position(fallback_position, points, radius, world_margin, placed_landmarks, min_landmark_distance, player_position)


static func _is_landmark_inside_world_bounds(position: Vector2, margin: float) -> bool:
	return (
		position.x >= WORLD_RECT.position.x + margin
		and position.x <= WORLD_RECT.end.x - margin
		and position.y >= WORLD_RECT.position.y + margin
		and position.y <= WORLD_RECT.end.y - margin
	)


static func _is_landmark_too_close_to_others(position: Vector2, radius: float, placed_landmarks: Array[Dictionary], min_landmark_distance: float) -> bool:
	for placed_value in placed_landmarks:
		var placed := Dictionary(placed_value)
		var placed_position := Vector2(placed.get("position", Vector2.ZERO))
		var placed_radius := float(placed.get("radius", 120.0))
		var required_distance: float = maxf(min_landmark_distance, radius + placed_radius + 40.0)
		if position.distance_to(placed_position) < required_distance:
			return true
	return false


static func _is_landmark_too_close_to_player(position: Vector2, radius: float, player_position: Vector2) -> bool:
	var zone := get_terrain_zone(position)
	var safe_distance := PLAYER_LANDMARK_SAFE_DISTANCE
	if zone == "pond":
		safe_distance = PLAYER_POND_SAFE_DISTANCE
	elif zone == "hill":
		safe_distance = PLAYER_HILL_SAFE_DISTANCE
	return position.distance_to(player_position) < radius + safe_distance


static func _find_landmark_fallback_position(fallback_position: Vector2, points: PackedVector2Array, radius: float, world_margin: float, placed_landmarks: Array[Dictionary], min_landmark_distance: float, player_position: Vector2) -> Vector2:
	if Geometry2D.is_point_in_polygon(fallback_position, points) and _is_landmark_inside_world_bounds(fallback_position, world_margin) and _is_landmark_position_on_valid_terrain(fallback_position, radius) and not _is_landmark_too_close_to_others(fallback_position, radius, placed_landmarks, min_landmark_distance) and not _is_landmark_too_close_to_player(fallback_position, radius, player_position):
		return fallback_position
	var bounds := _get_polygon_bounds(points)
	var center: Vector2 = bounds.get_center()
	for ring in range(1, 7):
		var ring_distance: float = float(ring) * maxf(radius * 0.9, 120.0)
		for angle_step in range(24):
			var angle := TAU * float(angle_step) / 24.0
			var candidate: Vector2 = center + Vector2.RIGHT.rotated(angle) * ring_distance
			if not Geometry2D.is_point_in_polygon(candidate, points):
				continue
			if not _is_landmark_inside_world_bounds(candidate, world_margin):
				continue
			if not _is_landmark_position_on_valid_terrain(candidate, radius):
				continue
			if _is_landmark_too_close_to_others(candidate, radius, placed_landmarks, min_landmark_distance):
				continue
			if _is_landmark_too_close_to_player(candidate, radius, player_position):
				continue
			return candidate
	if Geometry2D.is_point_in_polygon(center, points) and _is_landmark_inside_world_bounds(center, world_margin) and _is_landmark_position_on_valid_terrain(center, radius) and not _is_landmark_too_close_to_others(center, radius, placed_landmarks, min_landmark_distance) and not _is_landmark_too_close_to_player(center, radius, player_position):
		return center
	return Vector2.INF


static func _is_landmark_position_on_valid_terrain(position: Vector2, radius: float) -> bool:
	var zone := get_terrain_zone(position)
	if zone != "land" and zone != "highland":
		return false
	var sample_directions := [
		Vector2.RIGHT,
		Vector2.LEFT,
		Vector2.UP,
		Vector2.DOWN,
		Vector2(1, 1).normalized(),
		Vector2(-1, 1).normalized(),
		Vector2(1, -1).normalized(),
		Vector2(-1, -1).normalized()
	]
	for direction in sample_directions:
		var sample_position: Vector2 = position + direction * radius * 0.9
		var sample_zone := get_terrain_zone(sample_position)
		if sample_zone == "deep_ocean" or sample_zone == "shallow_water":
			return false
	return true


static func _get_landmark_spawn_margin(landmark_type: String) -> float:
	match landmark_type:
		"pond":
			return float(GAME_BALANCE.LANDMARKS.get("pond_spawn_margin", 260.0))
		"hill":
			return float(GAME_BALANCE.LANDMARKS.get("hill_spawn_margin", 220.0))
	return float(GAME_BALANCE.LANDMARKS.get("landmark_min_distance", 420.0)) * 0.5


static func _get_polygon_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ONE)
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point.x = min(min_point.x, point.x)
		min_point.y = min(min_point.y, point.y)
		max_point.x = max(max_point.x, point.x)
		max_point.y = max(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)


static func _get_polygon_center(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var total := Vector2.ZERO
	for point in points:
		total += point
	return total / float(points.size())


static func _build_world_boundary_points() -> PackedVector2Array:
	var rect := WORLD_RECT
	var points := PackedVector2Array([
		Vector2(rect.position.x, rect.position.y + rect.size.y * 0.14),
		Vector2(rect.position.x + rect.size.x * 0.06, rect.position.y + rect.size.y * 0.02),
		Vector2(rect.position.x + rect.size.x * 0.12, rect.position.y + rect.size.y * 0.09),
		Vector2(rect.position.x + rect.size.x * 0.20, rect.position.y + rect.size.y * 0.01),
		Vector2(rect.position.x + rect.size.x * 0.29, rect.position.y + rect.size.y * 0.12),
		Vector2(rect.position.x + rect.size.x * 0.37, rect.position.y + rect.size.y * 0.03),
		Vector2(rect.position.x + rect.size.x * 0.48, rect.position.y + rect.size.y * 0.10),
		Vector2(rect.position.x + rect.size.x * 0.58, rect.position.y + rect.size.y * 0.02),
		Vector2(rect.position.x + rect.size.x * 0.68, rect.position.y + rect.size.y * 0.13),
		Vector2(rect.position.x + rect.size.x * 0.78, rect.position.y + rect.size.y * 0.06),
		Vector2(rect.position.x + rect.size.x * 0.88, rect.position.y + rect.size.y * 0.17),
		Vector2(rect.end.x, rect.position.y + rect.size.y * 0.26),
		Vector2(rect.end.x - rect.size.x * 0.01, rect.position.y + rect.size.y * 0.38),
		Vector2(rect.end.x - rect.size.x * 0.07, rect.position.y + rect.size.y * 0.50),
		Vector2(rect.end.x - rect.size.x * 0.02, rect.position.y + rect.size.y * 0.64),
		Vector2(rect.end.x - rect.size.x * 0.08, rect.position.y + rect.size.y * 0.78),
		Vector2(rect.end.x - rect.size.x * 0.02, rect.position.y + rect.size.y * 0.91),
		Vector2(rect.position.x + rect.size.x * 0.84, rect.end.y),
		Vector2(rect.position.x + rect.size.x * 0.70, rect.end.y - rect.size.y * 0.03),
		Vector2(rect.position.x + rect.size.x * 0.58, rect.end.y - rect.size.y * 0.01),
		Vector2(rect.position.x + rect.size.x * 0.45, rect.end.y - rect.size.y * 0.06),
		Vector2(rect.position.x + rect.size.x * 0.32, rect.end.y - rect.size.y * 0.02),
		Vector2(rect.position.x + rect.size.x * 0.18, rect.end.y - rect.size.y * 0.08),
		Vector2(rect.position.x + rect.size.x * 0.06, rect.end.y - rect.size.y * 0.02),
		Vector2(rect.position.x, rect.end.y - rect.size.y * 0.14),
		Vector2(rect.position.x + rect.size.x * 0.02, rect.position.y + rect.size.y * 0.82),
		Vector2(rect.position.x + rect.size.x * 0.00, rect.position.y + rect.size.y * 0.56)
	])
	for i in points.size():
		var point := points[i]
		var x_wave := sin(point.y * 0.0023 + float(i) * 0.82) * 60.0
		var y_wave := cos(point.x * 0.0020 - float(i) * 0.64) * 44.0
		point.x = clampf(point.x + x_wave, rect.position.x, rect.end.x)
		point.y = clampf(point.y + y_wave, rect.position.y, rect.end.y)
		points[i] = point
	return points


static func _get_island_noise() -> FastNoiseLite:
	if cached_island_noise == null:
		cached_island_noise = FastNoiseLite.new()
	cached_island_noise.seed = 224466
	cached_island_noise.frequency = 0.6
	return cached_island_noise


static func _get_biome_id(biome: Dictionary) -> String:
	return str(biome.get("name", "")).to_snake_case()
