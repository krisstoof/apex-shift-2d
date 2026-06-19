extends RefCounted

const WORLD_GENERATION_RESULT_SCRIPT := preload("res://scripts/core/world/world_generation_result.gd")
const WORLD_GENERATION_SUMMARY := preload("res://scripts/core/world/world_generation_summary.gd")
const WORLD_GENERATION_HASH := preload("res://scripts/core/world/world_generation_hash.gd")

var seed: int = 0
var generator_version: String = ""
var world_rect: Rect2 = Rect2()

var maps: Dictionary = {}
var terrain_counts: Dictionary = {}
var land_water_layout: Dictionary = {}
var topography: Dictionary = {}

var biome_regions: Array[Dictionary] = []
var biome_coverage: Dictionary = {}

var landmarks: Array[Dictionary] = []
var player_spawn_position: Vector2 = Vector2.ZERO
var resource_spawns: Array[Dictionary] = []
var creature_spawns: Array[Dictionary] = []

var debug_stats: Dictionary = {}
var generation_hash: String = ""

var landmark_points: Array[Dictionary]:
	get:
		return landmarks
	set(value):
		landmarks = _copy_dict_array(value)

var resource_zones: Array[Dictionary]:
	get:
		return resource_spawns
	set(value):
		resource_spawns = _copy_dict_array(value)

var creature_spawn_zones: Array[Dictionary]:
	get:
		return creature_spawns
	set(value):
		creature_spawns = _copy_dict_array(value)


static func from_layout(layout: Dictionary) -> WorldGenerationResult:
	var result := WORLD_GENERATION_RESULT_SCRIPT.new()
	result.seed = int(layout.get("seed", 0))
	result.generator_version = str(layout.get("generator_rules_version", layout.get("version", "")))
	result.world_rect = Rect2(layout.get("world_rect", Rect2()))
	result.maps = Dictionary(layout.get("maps", {})).duplicate(true)
	result.biome_regions = _copy_dict_array(layout.get("biomes", []))
	result.landmarks = _copy_dict_array(layout.get("landmarks", []))
	result.resource_spawns = _copy_dict_array(layout.get("resource_zones", []))
	result.creature_spawns = _copy_dict_array(layout.get("creature_spawn_zones", []))
	result.player_spawn_position = Vector2(layout.get("player_spawn_position", layout.get("player_spawn", Vector2.ZERO)))
	result.debug_stats = Dictionary(layout.get("debug", {})).duplicate(true)
	result.terrain_counts = Dictionary(result.debug_stats.get("terrain_counts", {})).duplicate(true)
	result.biome_coverage = Dictionary(result.debug_stats.get("biome_coverage", {})).duplicate(true)
	result.land_water_layout = _extract_land_water_layout(layout, result.debug_stats)
	result.topography = _extract_topography(layout, result.debug_stats)
	result.generation_hash = str(layout.get("generation_hash", ""))
	if result.generation_hash.is_empty():
		result.generation_hash = WORLD_GENERATION_HASH.compute_from_result(result)
	return result


func to_summary():
	return WORLD_GENERATION_SUMMARY.from_result(self)


func compute_hash() -> String:
	return WORLD_GENERATION_HASH.compute_from_result(self)


static func compute_hash_from_layout(layout: Dictionary) -> String:
	return WORLD_GENERATION_HASH.compute_from_layout(layout)


func to_dict() -> Dictionary:
	return {
		"seed": seed,
		"generator_version": generator_version,
		"world_rect": world_rect,
		"maps": maps.duplicate(true),
		"land_water_layout": land_water_layout.duplicate(true),
		"topography": topography.duplicate(true),
		"biomes": _copy_dict_array(biome_regions),
		"biome_coverage": biome_coverage.duplicate(true),
		"landmarks": _copy_dict_array(landmarks),
		"player_spawn_position": player_spawn_position,
		"resource_spawns": _copy_dict_array(resource_spawns),
		"creature_spawns": _copy_dict_array(creature_spawns),
		"debug": debug_stats.duplicate(true),
		"generation_hash": generation_hash
	}


func to_debug_dict() -> Dictionary:
	var summary: Dictionary = to_summary().to_dict()
	return summary


func to_json_dump() -> String:
	return JSON.stringify(to_debug_dict(), "\t")


static func _copy_dict_array(value: Variant) -> Array[Dictionary]:
	var copied: Array[Dictionary] = []
	for item in Array(value):
		copied.append(Dictionary(item).duplicate(true))
	return copied


static func _extract_land_water_layout(layout: Dictionary, debug: Dictionary) -> Dictionary:
	var terrain_counts := Dictionary(debug.get("terrain_counts", {})).duplicate(true)
	return {
		"terrain_counts": terrain_counts,
		"maps": Dictionary(layout.get("maps", {})).duplicate(true)
	}


static func _extract_topography(layout: Dictionary, debug: Dictionary) -> Dictionary:
	var topography := Dictionary(layout.get("topography", {})).duplicate(true)
	if topography.is_empty():
		topography = Dictionary(debug.get("topography", {})).duplicate(true)
	return topography
