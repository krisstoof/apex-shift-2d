extends RefCounted
class_name WorldConfig

const WORLD_SCALE := 1.5
const BASE_WORLD_RECT := Rect2(-1440, -880, 2880, 1760)
const WORLD_RECT := Rect2(BASE_WORLD_RECT.position * WORLD_SCALE, BASE_WORLD_RECT.size * WORLD_SCALE)
const PLAYER_EDGE_PADDING := 30.0

const TREE_COUNT := 29
const ROCK_COUNT := 14
const BUSH_COUNT := 19

const RESOURCE_SPAWN_MARGIN := 70.0
const RESOURCE_MIN_DISTANCE := 70.0
const RESOURCE_PLAYER_SAFE_DISTANCE := 180.0
const RESOURCE_SPAWN_ATTEMPTS := 80

const VARNAK_TARGET_COUNT := 6
const VARNAK_PLAYER_SAFE_DISTANCE := 360.0
const VARNAK_SPAWN_ATTEMPTS := 20
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
	Vector2(-1140, 580)
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
