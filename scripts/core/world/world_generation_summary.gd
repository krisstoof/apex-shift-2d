extends RefCounted

const WORLD_GENERATION_RESULT := preload("res://scripts/core/world/world_generation_result.gd")
const WORLD_GENERATION_SUMMARY_SCRIPT := preload("res://scripts/core/world/world_generation_summary.gd")

var seed: int = 0
var generator_version: String = ""
var world_rect: Rect2 = Rect2()

var biome_count: int = 0
var landmark_count: int = 0
var resource_spawn_count: int = 0
var creature_spawn_count: int = 0

var player_spawn_position: Vector2 = Vector2.ZERO
var terrain_counts: Dictionary = {}
var biome_coverage: Dictionary = {}
var generation_hash: String = ""


static func from_result(result):
	var summary: RefCounted = WORLD_GENERATION_SUMMARY_SCRIPT.new()
	if result == null:
		return summary

	summary.seed = result.seed
	summary.generator_version = result.generator_version
	summary.world_rect = result.world_rect
	summary.biome_count = result.biome_regions.size()
	summary.landmark_count = result.landmarks.size()
	summary.resource_spawn_count = result.resource_spawns.size()
	summary.creature_spawn_count = result.creature_spawns.size()
	summary.player_spawn_position = result.player_spawn_position
	summary.terrain_counts = result.terrain_counts.duplicate(true)
	summary.biome_coverage = result.biome_coverage.duplicate(true)
	summary.generation_hash = result.generation_hash
	if summary.generation_hash.is_empty():
		summary.generation_hash = result.compute_hash()
	return summary


static func from_layout(layout: Dictionary):
	return from_result(WORLD_GENERATION_RESULT.from_layout(layout))


func to_dict() -> Dictionary:
	return {
		"seed": seed,
		"generator_version": generator_version,
		"world_rect": world_rect,
		"world_rect_text": str(world_rect),
		"biome_count": biome_count,
		"landmark_count": landmark_count,
		"resource_spawn_count": resource_spawn_count,
		"creature_spawn_count": creature_spawn_count,
		"player_spawn_position": player_spawn_position,
		"player_spawn_text": str(player_spawn_position),
		"terrain_counts": terrain_counts.duplicate(true),
		"biome_coverage": biome_coverage.duplicate(true),
		"generation_hash": generation_hash
	}


func to_json_dump() -> String:
	return JSON.stringify(to_dict(), "\t")
