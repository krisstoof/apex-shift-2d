extends RefCounted
class_name WorldConfig

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")

const WORLD_SCALE := 2.2
const BASE_WORLD_RECT := Rect2(-1440, -880, 2880, 1760)
const WORLD_RECT := Rect2(BASE_WORLD_RECT.position * WORLD_SCALE, BASE_WORLD_RECT.size * WORLD_SCALE)
const PLAYER_EDGE_PADDING := 40.0

const TREE_COUNT := 48
const ROCK_COUNT := 24
const BUSH_COUNT := 36
const SMALL_BUSH_COUNT := 28
const BERRY_BUSH_COUNT := 14
const GRASS_PATCH_COUNT := 72
const DENSE_GRASS_COUNT := 34

const RESOURCE_SPAWN_MARGIN := 95.0
const RESOURCE_MIN_DISTANCE := 90.0
const RESOURCE_PLAYER_SAFE_DISTANCE := 260.0
const RESOURCE_SPAWN_ATTEMPTS := 120

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
	}
]

const HILL_LANDMARK_PRIORITY := [
	"westwood_old_hill",
	"stoneback_spine",
	"hearth_watch_hill",
	"south_thicket_mound",
	"redfang_teeth",
	"redfang_lookout"
]

const POND_LANDMARK_PRIORITY := [
	"westwood_shade_pond",
	"hearth_mirror_pond",
	"redfang_darkwater",
	"south_thicket_pool",
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
		"tree_weight": 7.0,
		"rock_weight": 1.0,
		"bush_weight": 3.0,
		"grass_weight": 5.0,
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
		"tree_weight": 1.0,
		"rock_weight": 7.0,
		"bush_weight": 1.0,
		"grass_weight": 1.0,
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
		"tree_weight": 3.0,
		"rock_weight": 2.0,
		"bush_weight": 4.0,
		"grass_weight": 7.0,
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
		"tree_weight": 2.0,
		"rock_weight": 1.0,
		"bush_weight": 7.0,
		"grass_weight": 6.0,
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
		"tree_weight": 3.0,
		"rock_weight": 4.0,
		"bush_weight": 2.0,
		"grass_weight": 2.0,
		"dangerous": true
	}
]


static func get_player_limits() -> Vector2:
	return WORLD_RECT.size * 0.5 - Vector2(PLAYER_EDGE_PADDING, PLAYER_EDGE_PADDING)


static func scale_world_point(point: Vector2) -> Vector2:
	return point * WORLD_SCALE


static func get_biome_points(biome: Dictionary) -> Array[Vector2]:
	var scaled_points: Array[Vector2] = []
	for point_value in biome["points"]:
		scaled_points.append(Vector2(point_value) * WORLD_SCALE)
	return scaled_points


static func get_biome_zones() -> Array[Dictionary]:
	var scaled_biomes: Array[Dictionary] = []
	for biome_value in BIOME_ZONES:
		var biome := Dictionary(biome_value).duplicate(true)
		biome["points"] = get_biome_points(biome)
		scaled_biomes.append(biome)
	return scaled_biomes


static func get_landmarks() -> Array[Dictionary]:
	var filtered_landmarks: Array[Dictionary] = _get_balanced_landmark_selection()
	var scaled_landmarks: Array[Dictionary] = []
	for landmark_value in filtered_landmarks:
		var landmark := Dictionary(landmark_value).duplicate(true)
		landmark["position"] = scale_world_point(Vector2(landmark["position"]))
		landmark["radius"] = float(landmark["radius"]) * WORLD_SCALE
		scaled_landmarks.append(landmark)
	return scaled_landmarks


static func _get_balanced_landmark_selection() -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	selected.append_array(_select_landmarks_by_priority("hill", int(GAME_BALANCE.LANDMARKS.get("hill_count", 5)), HILL_LANDMARK_PRIORITY))
	selected.append_array(_select_landmarks_by_priority("pond", int(GAME_BALANCE.LANDMARKS.get("pond_count", 3)), POND_LANDMARK_PRIORITY))
	return selected


static func _select_landmarks_by_priority(landmark_type: String, target_count: int, priority_ids: Array) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for landmark_value in LANDMARKS:
		var landmark := Dictionary(landmark_value)
		if str(landmark.get("type", "")) == landmark_type:
			candidates.append(landmark)
	var clamped_count := clampi(target_count, 0, candidates.size())
	if clamped_count >= candidates.size():
		return candidates
	var selected_ids: Dictionary = {}
	var selected: Array[Dictionary] = []
	for priority_id_value in priority_ids:
		if selected.size() >= clamped_count:
			break
		var priority_id := str(priority_id_value)
		for candidate in candidates:
			if str(candidate.get("id", "")) != priority_id:
				continue
			selected.append(candidate)
			selected_ids[priority_id] = true
			break
	if selected.size() < clamped_count:
		for candidate in candidates:
			var candidate_id := str(candidate.get("id", ""))
			if selected_ids.has(candidate_id):
				continue
			selected.append(candidate)
			if selected.size() >= clamped_count:
				break
	return selected
