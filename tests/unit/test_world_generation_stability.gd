extends RefCounted
## World generation stability tests.
## Verifies that:
##   1. The same seed always produces the same world_generation_hash.
##   2. Different seeds produce different hashes (no trivial collisions).
##   3. No creature spawn zone lands in water or outside world_rect.
##   4. Every biome region has meaningful coverage.
##   5. Terrain coverage is within sane bounds.
##
## These tests run pure data generation — no scene tree required.

const WORLD_GENERATION_RESULT := preload("res://scripts/world/world_generation_result.gd")
const WORLD_GENERATION_VALIDATOR := preload("res://scripts/world/world_generation_validator.gd")

# Seeds that appear in benchmark logs or have special significance.
const TEST_SEEDS: Array[int] = [
	1, 2, 3, 42, 100, 999,
	12345, 54321, 99999,
	2069809369, 1780589108, 1364451488,
	7, 1337,
]


func _make_generator() -> Object:
	return load("res://scripts/world/world_generator.gd").new()


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_deterministic_hash())
	failures.append_array(_test_hash_sensitivity())
	failures.append_array(_test_no_water_spawns())
	failures.append_array(_test_points_in_bounds())
	failures.append_array(_test_biome_coverage())
	failures.append_array(_test_terrain_coverage())
	# New comprehensive island generation tests
	failures.append_array(_test_world_contains_land())
	failures.append_array(_test_world_contains_water())
	failures.append_array(_test_player_spawn_on_land())
	failures.append_array(_test_creatures_spawn_on_valid_terrain())
	failures.append_array(_test_biomes_exist_on_land())
	failures.append_array(_test_different_seeds_create_different_worlds())
	failures.append_array(_test_world_generation_hash_stability())
	return failures


# ---------------------------------------------------------------------------
# 1. Same seed → same hash (determinism)
# ---------------------------------------------------------------------------
func _test_deterministic_hash() -> Array[String]:
	var failures: Array[String] = []
	for test_seed in TEST_SEEDS:
		var gen_a := WorldGenerator.new()
		var layout_a := gen_a.generate_world(test_seed)
		var hash_a := WORLD_GENERATION_RESULT.compute_hash_from_layout(layout_a)

		var gen_b := WorldGenerator.new()
		var layout_b := gen_b.generate_world(test_seed)
		var hash_b := WORLD_GENERATION_RESULT.compute_hash_from_layout(layout_b)

		if hash_a != hash_b:
			failures.append(
				"DETERMINISM seed=%d: hash mismatch — first=%s second=%s" % [test_seed, hash_a, hash_b]
			)
	return failures


# ---------------------------------------------------------------------------
# 2. Different seeds → different hashes (no trivial collision)
# ---------------------------------------------------------------------------
func _test_hash_sensitivity() -> Array[String]:
	var failures: Array[String] = []
	var seen_hashes: Dictionary = {}
	for test_seed in TEST_SEEDS:
		var gen := WorldGenerator.new()
		var layout := gen.generate_world(test_seed)
		var h := WORLD_GENERATION_RESULT.compute_hash_from_layout(layout)
		if seen_hashes.has(h):
			failures.append(
				"HASH_COLLISION seed=%d collides with seed=%d (hash=%s)" % [
					test_seed, int(seen_hashes[h]), h
				]
			)
		else:
			seen_hashes[h] = test_seed
	return failures


# ---------------------------------------------------------------------------
# 3. No spawn zone lands in water
# ---------------------------------------------------------------------------
func _test_no_water_spawns() -> Array[String]:
	var failures: Array[String] = []
	var validator := WORLD_GENERATION_VALIDATOR.new()
	for test_seed in TEST_SEEDS:
		var gen := WorldGenerator.new()
		var layout := gen.generate_world(test_seed)
		var result := WORLD_GENERATION_RESULT.from_layout(layout)
		var report := validator.validate(result, gen)
		for error in Array(report.get("errors", [])):
			failures.append("VALIDATE seed=%d: %s" % [test_seed, str(error)])
	return failures


# ---------------------------------------------------------------------------
# 4. All spawn-zone positions are inside world_rect
# ---------------------------------------------------------------------------
func _test_points_in_bounds() -> Array[String]:
	var failures: Array[String] = []
	for test_seed in TEST_SEEDS:
		var gen := WorldGenerator.new()
		var layout := gen.generate_world(test_seed)
		var world_rect := Rect2(layout.get("world_rect", Rect2()))
		var padded := world_rect.grow(32.0)
		for zone_value in Array(layout.get("creature_spawn_zones", [])):
			var zone := Dictionary(zone_value)
			var pos := Vector2(zone.get("position", Vector2.ZERO))
			if not padded.has_point(pos):
				failures.append(
					"BOUNDS seed=%d zone='%s' pos=%s outside world_rect=%s" % [
						test_seed, zone.get("id", "?"), pos, world_rect
					]
				)
	return failures


# ---------------------------------------------------------------------------
# 5. Every biome has meaningful coverage
# ---------------------------------------------------------------------------
func _test_biome_coverage() -> Array[String]:
	var failures: Array[String] = []
	for test_seed in TEST_SEEDS:
		var gen := WorldGenerator.new()
		var layout := gen.generate_world(test_seed)
		var biomes := Array(layout.get("biomes", []))
		if biomes.is_empty():
			failures.append("BIOMES seed=%d: no biome regions generated" % test_seed)
			continue
		for biome_value in biomes:
			var biome := Dictionary(biome_value)
			var biome_id := str(biome.get("id", "?"))
			var sample_count := int(biome.get("sample_count", 0))
			if sample_count < WORLD_GENERATION_VALIDATOR.MIN_BIOME_SAMPLE_COUNT:
				failures.append(
					"BIOMES seed=%d biome='%s' low coverage: %d samples (min %d)" % [
						test_seed, biome_id, sample_count,
						WORLD_GENERATION_VALIDATOR.MIN_BIOME_SAMPLE_COUNT
					]
				)
	return failures


# ---------------------------------------------------------------------------
# 6. Terrain coverage within sane bounds
# ---------------------------------------------------------------------------
func _test_terrain_coverage() -> Array[String]:
	var failures: Array[String] = []
	for test_seed in TEST_SEEDS:
		var gen := WorldGenerator.new()
		var layout := gen.generate_world(test_seed)
		var debug := Dictionary(layout.get("debug", {}))
		var terrain_counts := Dictionary(debug.get("terrain_counts", {}))
		if terrain_counts.is_empty():
			failures.append("TERRAIN seed=%d: no terrain_counts in debug" % test_seed)
			continue
		var total := 0
		for v in terrain_counts.values():
			total += int(v)
		if total == 0:
			failures.append("TERRAIN seed=%d: total terrain count is 0" % test_seed)
			continue
		var land_count := int(terrain_counts.get("land", 0)) + int(terrain_counts.get("highland", 0))
		var land_pct := float(land_count) / float(total)
		if land_pct < WORLD_GENERATION_VALIDATOR.MIN_LAND_FRACTION:
			failures.append(
				"TERRAIN seed=%d: land fraction %.1f%% below minimum %.0f%%" % [
					test_seed, land_pct * 100.0,
					WORLD_GENERATION_VALIDATOR.MIN_LAND_FRACTION * 100.0
				]
			)
	return failures


# ---------------------------------------------------------------------------
# 7. World contains land
# ---------------------------------------------------------------------------
func _test_world_contains_land() -> Array[String]:
	var failures: Array[String] = []
	for test_seed in TEST_SEEDS:
		var gen := WorldGenerator.new()
		var layout := gen.generate_world(test_seed)
		var debug := Dictionary(layout.get("debug", {}))
		var terrain_counts := Dictionary(debug.get("terrain_counts", {}))
		var land_count := int(terrain_counts.get("land", 0)) + int(terrain_counts.get("highland", 0))
		if land_count <= 0:
			failures.append("LAND_PRESENCE seed=%d: no land terrain found" % test_seed)
	return failures


# ---------------------------------------------------------------------------
# 8. World contains water
# ---------------------------------------------------------------------------
func _test_world_contains_water() -> Array[String]:
	var failures: Array[String] = []
	for test_seed in TEST_SEEDS:
		var gen := WorldGenerator.new()
		var layout := gen.generate_world(test_seed)
		var debug := Dictionary(layout.get("debug", {}))
		var terrain_counts := Dictionary(debug.get("terrain_counts", {}))
		var water_count := int(terrain_counts.get("ocean", 0)) + int(terrain_counts.get("pond", 0))
		if water_count <= 0:
			failures.append("WATER_PRESENCE seed=%d: no water terrain found" % test_seed)
	return failures


# ---------------------------------------------------------------------------
# 9. Player spawn is on land, not in water
# ---------------------------------------------------------------------------
func _test_player_spawn_on_land() -> Array[String]:
	var failures: Array[String] = []
	for test_seed in TEST_SEEDS:
		var gen := WorldGenerator.new()
		var layout := gen.generate_world(test_seed)
		var result := WORLD_GENERATION_RESULT.from_layout(layout)
		var spawn_pos := result.player_spawn_position
		
		if spawn_pos == Vector2.ZERO:
			failures.append("PLAYER_SPAWN seed=%d: spawn position is zero" % test_seed)
			continue
			
		var terrain_zone := gen.get_terrain_zone(spawn_pos)
		if _is_water_terrain(terrain_zone):
			failures.append(
				"PLAYER_SPAWN seed=%d: spawn at %s is in water zone '%s'" % [
					test_seed, spawn_pos, terrain_zone
				]
			)
	return failures


# ---------------------------------------------------------------------------
# 10. Creatures spawn on valid terrain
# ---------------------------------------------------------------------------
func _test_creatures_spawn_on_valid_terrain() -> Array[String]:
	var failures: Array[String] = []
	for test_seed in TEST_SEEDS:
		var gen := WorldGenerator.new()
		var layout := gen.generate_world(test_seed)
		var result := WORLD_GENERATION_RESULT.from_layout(layout)
		var world_rect := result.world_rect
		
		for zone_value in Array(result.creature_spawn_zones):
			var zone := Dictionary(zone_value)
			var pos := Vector2(zone.get("position", Vector2.ZERO))
			var creature_type := str(zone.get("creature_type", "unknown"))
			
			if not world_rect.has_point(pos):
				failures.append(
					"CREATURE_SPAWN seed=%d: creature '%s' at %s outside world_rect" % [
						test_seed, creature_type, pos
					]
				)
				continue
			
			var terrain_zone := gen.get_terrain_zone(pos)
			# Creatures should spawn on land or shallow water
			if _is_deep_water_terrain(terrain_zone):
				failures.append(
					"CREATURE_SPAWN seed=%d: creature '%s' at %s is in deep water '%s'" % [
						test_seed, creature_type, pos, terrain_zone
					]
				)
	return failures


# ---------------------------------------------------------------------------
# 11. Biomes exist on land
# ---------------------------------------------------------------------------
func _test_biomes_exist_on_land() -> Array[String]:
	var failures: Array[String] = []
	for test_seed in TEST_SEEDS:
		var gen = _make_generator()
		var layout := gen.generate_world(test_seed)
		var result := WORLD_GENERATION_RESULT.from_layout(layout)
		
		if result.biome_regions.is_empty():
			failures.append("BIOME_PLACEMENT seed=%d: no biome regions found" % test_seed)
			continue
		
		for biome_value in Array(result.biome_regions):
			var biome := Dictionary(biome_value)
			var biome_id := str(biome.get("id", "?"))
			var sample_count := int(biome.get("sample_count", 0))
			
			if sample_count < 50:
				failures.append(
					"BIOME_PLACEMENT seed=%d: biome '%s' has low coverage (%d samples)" % [
						test_seed, biome_id, sample_count
					]
				)
	return failures


# ---------------------------------------------------------------------------
# 12. Different seeds create different worlds
# ---------------------------------------------------------------------------
func _test_different_seeds_create_different_worlds() -> Array[String]:
	var failures: Array[String] = []
	var hashes: Dictionary = {}
	var seed_count := 0
	
	for test_seed in TEST_SEEDS:
		var gen = _make_generator()
		var layout := gen.generate_world(test_seed)
		var h := WORLD_GENERATION_RESULT.compute_hash_from_layout(layout)
		hashes[test_seed] = h
		seed_count += 1
	
	# Check that at least most seeds produce different hashes
	var unique_hashes := {}
	for h in hashes.values():
		unique_hashes[h] = true
	
	var hash_count := unique_hashes.size()
	var uniqueness_ratio := float(hash_count) / float(seed_count)
	
	if uniqueness_ratio < 0.8:  # At least 80% unique
		failures.append(
			"SEED_SENSITIVITY: only %.0f%% of seeds produce unique hashes (%d/%d)" % [
				uniqueness_ratio * 100.0, hash_count, seed_count
			]
		)
	return failures


# ---------------------------------------------------------------------------
# 13. World generation hash is stable (same seed = same hash, reproducible)
# ---------------------------------------------------------------------------
func _test_world_generation_hash_stability() -> Array[String]:
	var failures: Array[String] = []
	
	for test_seed in TEST_SEEDS:
		# Generate same seed three times
		var hashes: Array[String] = []
		for i in range(3):
			var gen = _make_generator()
			var layout := gen.generate_world(test_seed)
			var h := WORLD_GENERATION_RESULT.compute_hash_from_layout(layout)
			hashes.append(h)
		
		# All three should be identical
		if hashes[0] != hashes[1] or hashes[1] != hashes[2]:
			failures.append(
				"HASH_STABILITY seed=%d: hashes differ between runs [%s, %s, %s]" % [
					test_seed, hashes[0], hashes[1], hashes[2]
				]
			)
	return failures


# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

func _is_water_terrain(terrain_zone: String) -> bool:
	return terrain_zone in ["pond", "ocean"]


func _is_deep_water_terrain(terrain_zone: String) -> bool:
	return terrain_zone == "ocean"


func _is_land_terrain(terrain_zone: String) -> bool:
	return terrain_zone in ["land", "highland"]


## Helper: Build world generation summary for comparison
func build_world_generation_summary(gen: Object, layout: Dictionary) -> Dictionary:
	var debug := Dictionary(layout.get("debug", {}))
	var terrain_counts := Dictionary(debug.get("terrain_counts", {}))
	var land_count := int(terrain_counts.get("land", 0)) + int(terrain_counts.get("highland", 0))
	var water_count := int(terrain_counts.get("ocean", 0)) + int(terrain_counts.get("pond", 0))
	
	return {
		"seed": int(layout.get("seed", 0)),
		"world_rect": str(layout.get("world_rect", Rect2())),
		"land_count": land_count,
		"water_count": water_count,
		"player_spawn": str(layout.get("player_spawn_position", Vector2.ZERO)),
		"biome_count": (layout.get("biomes", []) as Array).size(),
		"creature_spawn_count": (layout.get("creature_spawn_zones", []) as Array).size(),
		"resource_spawn_count": (layout.get("resource_zones", []) as Array).size(),
	}


## Helper: Hash summary dict for comparison
func build_world_generation_hash(summary: Dictionary) -> String:
	return str(hash(JSON.stringify(summary)))
