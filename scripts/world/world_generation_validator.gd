extends RefCounted
class_name WorldGenerationValidator

const WORLD_GENERATION_RESULT := preload("res://scripts/core/world/world_generation_result.gd")

## Validates a WorldGenerationResult against hard rules that must hold
## for a world to be correct and playable.
## Call validate() after generation; check the returned report for errors/warnings.

## Minimum number of biome ownership-map cells a biome must occupy.
const MIN_BIOME_SAMPLE_COUNT := 50
## Minimum fraction of the map that must be land (not ocean/shore).
const MIN_LAND_FRACTION := 0.20
## Maximum fraction of the map that may be ocean.
const MAX_OCEAN_FRACTION := 0.75


## Run all checks on the given result using the generator for spatial queries.
## generator must expose get_terrain_zone(position: Vector2) -> String.
## Returns: { valid, errors: Array[String], warnings: Array[String] }
func validate(result, generator: Object) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	_check_world_rect(result, errors)
	_check_creature_spawn_zones(result, generator, errors)
	_check_biome_coverage(result, warnings)
	_check_terrain_coverage(result, warnings)

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"error_count": errors.size(),
		"warning_count": warnings.size(),
	}


func _check_world_rect(result, errors: Array[String]) -> void:
	if result.world_rect.size.x <= 0.0 or result.world_rect.size.y <= 0.0:
		errors.append("world_rect has zero or negative size: %s" % result.world_rect)


func _check_creature_spawn_zones(result, generator: Object, errors: Array[String]) -> void:
	if not generator.has_method("get_terrain_zone"):
		return
	var world_rect: Rect2 = result.world_rect
	for zone_value in result.creature_spawn_zones:
		var zone := Dictionary(zone_value)
		var zone_id := str(zone.get("id", "?"))
		var pos := Vector2(zone.get("position", Vector2.ZERO))
		# Bounds check — allow a small margin for float imprecision.
		if not world_rect.grow(16.0).has_point(pos):
			errors.append("Spawn zone '%s' outside world_rect at %s" % [zone_id, pos])
			continue
		# Water check — spawning in ocean or pond is always invalid.
		var terrain := str(generator.call("get_terrain_zone", pos))
		if terrain in ["deep_ocean", "shallow_water", "pond"]:
			errors.append("Spawn zone '%s' in water (terrain=%s) at %s" % [zone_id, terrain, pos])


func _check_biome_coverage(result, warnings: Array[String]) -> void:
	if result.biome_regions.is_empty():
		warnings.append("No biome regions in generation result")
		return
	for biome_value in result.biome_regions:
		var biome := Dictionary(biome_value)
		var biome_id := str(biome.get("id", "?"))
		var sample_count := int(biome.get("sample_count", 0))
		if sample_count < MIN_BIOME_SAMPLE_COUNT:
			warnings.append("Biome '%s' very low coverage: %d samples (min %d)" % [
				biome_id, sample_count, MIN_BIOME_SAMPLE_COUNT
			])


func _check_terrain_coverage(result, warnings: Array[String]) -> void:
	var counts: Dictionary = result.terrain_counts
	if counts.is_empty():
		return
	var total := 0
	for v in counts.values():
		total += int(v)
	if total == 0:
		return
	var land_count := int(counts.get("land", 0)) + int(counts.get("highland", 0))
	var ocean_count := int(counts.get("deep_ocean", 0)) + int(counts.get("shallow_water", 0))
	var land_pct := float(land_count) / float(total)
	var ocean_pct := float(ocean_count) / float(total)
	if land_pct < MIN_LAND_FRACTION:
		warnings.append(
			"Low land fraction: %.1f%% (min %.0f%%)" % [land_pct * 100.0, MIN_LAND_FRACTION * 100.0]
		)
	if ocean_pct > MAX_OCEAN_FRACTION:
		warnings.append(
			"High ocean fraction: %.1f%% (max %.0f%%)" % [ocean_pct * 100.0, MAX_OCEAN_FRACTION * 100.0]
		)
