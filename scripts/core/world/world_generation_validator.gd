class_name WorldGenerationValidator
extends RefCounted

const WORLD_GENERATION_RESULT := preload("res://scripts/core/world/world_generation_result.gd")

const MIN_BIOME_SAMPLE_COUNT := 50
const MIN_LAND_FRACTION := 0.20
const MAX_OCEAN_FRACTION := 0.75

const LAND_TERRAINS := {
	"land": true,
	"highland": true,
	"shore": true
}

const WATER_TERRAINS := {
	"water": true,
	"ocean": true,
	"deep_ocean": true,
	"shallow_water": true,
	"pond": true
}

const DEEP_WATER_TERRAINS := {
	"ocean": true,
	"deep_ocean": true
}

const CREATURE_DISALLOWED_WATER_TERRAINS := {
	"ocean": true,
	"deep_ocean": true,
	"shallow_water": true,
	"pond": true
}

const VEGETATION_DISALLOWED_TERRAINS := {
	"ocean": true,
	"deep_ocean": true
}


func validate(result_or_layout, terrain_provider: Variant = null) -> Dictionary:
	var result: WorldGenerationResult = _coerce_result(result_or_layout)
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var checks: Dictionary = {}

	if result == null:
		return _build_report(false, ["WorldGenerationValidator received null/invalid generation data"], warnings, checks)

	_check_world_rect(result, errors, checks)
	_check_world_has_land(result, errors, warnings, checks)
	_check_world_has_water(result, errors, warnings, checks)
	_check_player_spawn_on_land(result, terrain_provider, errors, warnings, checks)
	_check_vegetation_spawns(result, terrain_provider, errors, warnings, checks)
	_check_creature_spawns(result, terrain_provider, errors, warnings, checks)
	_check_landmarks(result, errors, warnings, checks)
	_check_biomes_exist_on_land(result, warnings, checks)
	_check_generation_hash(result, warnings, checks)

	return _build_report(errors.is_empty(), errors, warnings, checks)


func validate_save_load_consistency(before_data, after_data) -> Dictionary:
	var before_result: WorldGenerationResult = _coerce_result(before_data)
	var after_result: WorldGenerationResult = _coerce_result(after_data)
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var checks: Dictionary = {}

	if before_result == null:
		errors.append("Before generation data is invalid")
	if after_result == null:
		errors.append("After generation data is invalid")

	if not errors.is_empty():
		return _build_report(false, errors, warnings, checks)

	var before_summary: WorldGenerationSummary = before_result.to_summary()
	var after_summary: WorldGenerationSummary = after_result.to_summary()

	checks["before_hash"] = before_summary.generation_hash
	checks["after_hash"] = after_summary.generation_hash
	checks["before_seed"] = before_summary.seed
	checks["after_seed"] = after_summary.seed

	if before_summary.seed != after_summary.seed:
		errors.append("Save/load seed mismatch: before=%d after=%d" % [before_summary.seed, after_summary.seed])
	if before_summary.generation_hash != after_summary.generation_hash:
		errors.append("Save/load generation hash mismatch: before=%s after=%s" % [
			before_summary.generation_hash,
			after_summary.generation_hash
		])
	if before_summary.biome_count != after_summary.biome_count:
		errors.append("Save/load biome count mismatch: before=%d after=%d" % [
			before_summary.biome_count,
			after_summary.biome_count
		])
	if before_summary.landmark_count != after_summary.landmark_count:
		errors.append("Save/load landmark count mismatch: before=%d after=%d" % [
			before_summary.landmark_count,
			after_summary.landmark_count
		])
	if before_summary.resource_spawn_count != after_summary.resource_spawn_count:
		errors.append("Save/load resource spawn count mismatch: before=%d after=%d" % [
			before_summary.resource_spawn_count,
			after_summary.resource_spawn_count
		])
	if before_summary.creature_spawn_count != after_summary.creature_spawn_count:
		errors.append("Save/load creature spawn count mismatch: before=%d after=%d" % [
			before_summary.creature_spawn_count,
			after_summary.creature_spawn_count
		])

	return _build_report(errors.is_empty(), errors, warnings, checks)


func _coerce_result(result_or_layout):
	if result_or_layout == null:
		return null
	if result_or_layout is Dictionary:
		return WORLD_GENERATION_RESULT.from_layout(Dictionary(result_or_layout))
	return result_or_layout


func _check_world_rect(result, errors: Array[String], checks: Dictionary) -> void:
	var world_rect: Rect2 = result.world_rect
	checks["world_rect"] = str(world_rect)
	if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		errors.append("world_rect has zero or negative size: %s" % world_rect)


func _check_world_has_land(result, errors: Array[String], warnings: Array[String], checks: Dictionary) -> void:
	var counts: Dictionary = result.terrain_counts
	checks["terrain_counts"] = counts.duplicate(true)
	if counts.is_empty():
		warnings.append("Cannot verify land presence: terrain_counts is empty")
		return
	var land_count := _sum_counts(counts, ["land", "highland", "shore"])
	checks["land_count"] = land_count
	if land_count <= 0:
		errors.append("World has no land terrain")


func _check_world_has_water(result, errors: Array[String], warnings: Array[String], checks: Dictionary) -> void:
	var counts: Dictionary = result.terrain_counts
	if counts.is_empty():
		warnings.append("Cannot verify water presence: terrain_counts is empty")
		return
	var water_count := _sum_counts(counts, ["water", "ocean", "deep_ocean", "shallow_water", "pond"])
	checks["water_count"] = water_count
	if water_count <= 0:
		errors.append("World has no water terrain")


func _check_player_spawn_on_land(result, terrain_provider: Variant, errors: Array[String], warnings: Array[String], checks: Dictionary) -> void:
	var pos: Vector2 = result.player_spawn_position
	checks["player_spawn_position"] = pos
	if pos == Vector2.ZERO:
		warnings.append("Player spawn position is Vector2.ZERO or missing")
		return
	if not result.world_rect.grow(16.0).has_point(pos):
		errors.append("Player spawn is outside world_rect at %s" % pos)
		return
	var terrain := _get_terrain_for_position(pos, terrain_provider)
	checks["player_spawn_terrain"] = terrain
	if terrain.is_empty():
		warnings.append("Cannot verify player spawn terrain: no terrain data for %s" % pos)
		return
	if not _is_land_terrain(terrain):
		errors.append("Player spawn must be on land, got terrain='%s' at %s" % [terrain, pos])


func _check_vegetation_spawns(result, terrain_provider: Variant, errors: Array[String], warnings: Array[String], checks: Dictionary) -> void:
	var checked_count := 0
	var missing_terrain_count := 0
	for spawn_value in result.resource_spawns:
		var spawn := Dictionary(spawn_value)
		var kind := str(spawn.get("kind", spawn.get("resource_kind", spawn.get("id", "?"))))
		if not _looks_like_vegetation(kind, spawn):
			continue
		var pos := _get_spawn_position(spawn)
		var terrain := _get_spawn_terrain(spawn, pos, terrain_provider)
		checked_count += 1
		if terrain.is_empty():
			missing_terrain_count += 1
			continue
		if terrain in VEGETATION_DISALLOWED_TERRAINS:
			errors.append("Vegetation spawn '%s' is in disallowed deep water terrain='%s' at %s" % [kind, terrain, pos])
	checks["vegetation_spawn_checked_count"] = checked_count
	checks["vegetation_spawn_missing_terrain_count"] = missing_terrain_count
	if checked_count > 0 and missing_terrain_count == checked_count:
		warnings.append("Vegetation spawn terrain could not be verified from data")


func _check_creature_spawns(result, terrain_provider: Variant, errors: Array[String], warnings: Array[String], checks: Dictionary) -> void:
	var checked_count := 0
	var missing_terrain_count := 0
	for spawn_value in result.creature_spawns:
		var spawn := Dictionary(spawn_value)
		var creature_type := str(spawn.get("creature_type", spawn.get("kind", spawn.get("id", "?"))))
		var pos := _get_spawn_position(spawn)
		var terrain := _get_spawn_terrain(spawn, pos, terrain_provider)
		checked_count += 1
		if not result.world_rect.grow(16.0).has_point(pos):
			errors.append("Creature spawn '%s' is outside world_rect at %s" % [creature_type, pos])
			continue
		if terrain.is_empty():
			missing_terrain_count += 1
			continue
		if terrain in CREATURE_DISALLOWED_WATER_TERRAINS:
			errors.append("Creature spawn '%s' is in disallowed water terrain='%s' at %s" % [creature_type, terrain, pos])
	checks["creature_spawn_checked_count"] = checked_count
	checks["creature_spawn_missing_terrain_count"] = missing_terrain_count
	if checked_count > 0 and missing_terrain_count == checked_count:
		warnings.append("Creature spawn terrain could not be verified from data")


func _check_landmarks(result, errors: Array[String], warnings: Array[String], checks: Dictionary) -> void:
	var landmark_count: int = result.landmarks.size()
	var overlap_count := 0
	checks["landmark_count"] = landmark_count
	for i in range(result.landmarks.size()):
		var a := Dictionary(result.landmarks[i])
		var a_pos := _get_spawn_position(a)
		var a_radius := _get_landmark_radius(a)
		if not result.world_rect.grow(16.0).has_point(a_pos):
			errors.append("Landmark '%s' is outside world_rect at %s" % [str(a.get("id", a.get("type", "?"))), a_pos])
		for j in range(i + 1, result.landmarks.size()):
			var b := Dictionary(result.landmarks[j])
			var b_pos := _get_spawn_position(b)
			var b_radius := _get_landmark_radius(b)
			var min_distance := maxf(8.0, (a_radius + b_radius) * 0.65)
			if a_pos.distance_to(b_pos) < min_distance:
				overlap_count += 1
				errors.append("Landmarks overlap: '%s' at %s and '%s' at %s distance=%.2f min=%.2f" % [
					str(a.get("id", a.get("type", "?"))),
					a_pos,
					str(b.get("id", b.get("type", "?"))),
					b_pos,
					a_pos.distance_to(b_pos),
					min_distance
				])
	checks["landmark_overlap_count"] = overlap_count
	if landmark_count == 0:
		warnings.append("No landmarks in generation result")


func _check_biomes_exist_on_land(result, warnings: Array[String], checks: Dictionary) -> void:
	var biome_count: int = result.biome_regions.size()
	checks["biome_count"] = biome_count
	if biome_count == 0:
		warnings.append("No biome regions in generation result")
		return
	var low_coverage: Array[String] = []
	for biome_value in result.biome_regions:
		var biome := Dictionary(biome_value)
		var biome_id := str(biome.get("id", "?"))
		var sample_count := int(biome.get("sample_count", biome.get("land_sample_count", 0)))
		if sample_count < MIN_BIOME_SAMPLE_COUNT:
			low_coverage.append("%s:%d" % [biome_id, sample_count])
	if not low_coverage.is_empty():
		warnings.append("Some biomes have low or unknown land coverage: %s" % ", ".join(low_coverage))
	checks["biome_low_coverage_count"] = low_coverage.size()


func _check_generation_hash(result, warnings: Array[String], checks: Dictionary) -> void:
	checks["generation_hash"] = result.generation_hash
	if result.generation_hash.is_empty():
		warnings.append("Generation hash is empty")


func _get_spawn_position(spawn: Dictionary) -> Vector2:
	if spawn.has("position"):
		return Vector2(spawn.get("position", Vector2.ZERO))
	if spawn.has("pos"):
		return Vector2(spawn.get("pos", Vector2.ZERO))
	if spawn.has("center"):
		return Vector2(spawn.get("center", Vector2.ZERO))
	if spawn.has("world_position"):
		return Vector2(spawn.get("world_position", Vector2.ZERO))
	return Vector2.ZERO


func _get_landmark_radius(landmark: Dictionary) -> float:
	if landmark.has("radius"):
		return float(landmark.get("radius", 0.0))
	if landmark.has("radius_x") or landmark.has("radius_y"):
		return maxf(float(landmark.get("radius_x", 0.0)), float(landmark.get("radius_y", 0.0)))
	if landmark.has("size"):
		var size_value: Variant = landmark.get("size")
		if size_value is Vector2:
			var size := Vector2(size_value)
			return maxf(size.x, size.y) * 0.5
	return 24.0


func _get_spawn_terrain(spawn: Dictionary, position: Vector2, terrain_provider: Variant) -> String:
	for key in ["terrain", "terrain_zone", "base_terrain", "water_zone", "resolved_terrain"]:
		if spawn.has(key):
			return str(spawn.get(key, ""))
	return _get_terrain_for_position(position, terrain_provider)


func _get_terrain_for_position(position: Vector2, terrain_provider: Variant) -> String:
	if terrain_provider != null and terrain_provider.has_method("get_terrain_zone"):
		return str(terrain_provider.call("get_terrain_zone", position))
	return ""


func _looks_like_vegetation(kind: String, spawn: Dictionary) -> bool:
	if bool(spawn.get("is_vegetation", false)):
		return true
	var lowered := kind.to_lower()
	return lowered.contains("tree") or lowered.contains("bush") or lowered.contains("grass") or lowered.contains("berry") or lowered.contains("plant") or lowered.contains("vegetation")


func _is_land_terrain(terrain: String) -> bool:
	return terrain in LAND_TERRAINS


func _sum_counts(counts: Dictionary, keys: Array[String]) -> int:
	var total := 0
	for key in keys:
		total += int(counts.get(key, 0))
	return total


func _build_report(valid: bool, errors: Array[String], warnings: Array[String], checks: Dictionary) -> Dictionary:
	return {
		"valid": valid,
		"errors": errors,
		"warnings": warnings,
		"checks": checks,
		"error_count": errors.size(),
		"warning_count": warnings.size()
	}
