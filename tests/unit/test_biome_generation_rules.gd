extends RefCounted

const WORLD_GENERATION_RESULT := preload("res://scripts/world/world_generation_result.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")

const SEEDS: Array[int] = [12345, 54321, 99999]


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_determinism())
	failures.append_array(_test_seed_variation())
	failures.append_array(_test_debug_metrics_present())
	failures.append_array(_test_shore_rules())
	failures.append_array(_test_stoneback_ridge_rules())
	failures.append_array(_test_south_thicket_rules())
	failures.append_array(_test_hearth_meadow_rules())
	failures.append_array(_test_redfang_rules())
	failures.append_array(_test_world_minimap_map_source_alignment())
	return failures


func _make_layout(seed: int) -> Dictionary:
	var generator := _make_generator()
	return generator.generate_world(seed)


func _make_generator() -> Object:
	return load("res://scripts/world/world_generator.gd").new()


func _sample_points(layout: Dictionary, predicate: Callable, limit: int = 48) -> Array[Vector2]:
	var generator := _make_generator()
	generator.generate_world(int(layout.get("seed", 0)))
	var world_rect: Rect2 = Rect2(layout.get("world_rect", Rect2()))
	var points: Array[Vector2] = []
	var steps_x := 24
	var steps_y := 16
	for y in range(steps_y):
		for x in range(steps_x):
			var tx := float(x) / float(maxi(steps_x - 1, 1))
			var ty := float(y) / float(maxi(steps_y - 1, 1))
			var position := Vector2(
				lerpf(world_rect.position.x, world_rect.end.x, tx),
				lerpf(world_rect.position.y, world_rect.end.y, ty)
			)
			if bool(predicate.call(generator, position)):
				points.append(position)
				if points.size() >= limit:
					return points
	return points


func _test_determinism() -> Array[String]:
	var failures: Array[String] = []
	for seed in SEEDS:
		var a: Dictionary = _make_generator().generate_world(seed)
		var b: Dictionary = _make_generator().generate_world(seed)
		var hash_a := WORLD_GENERATION_RESULT.compute_hash_from_layout(a)
		var hash_b := WORLD_GENERATION_RESULT.compute_hash_from_layout(b)
		TEST_UTILS.expect_equal(hash_a, hash_b, failures, "Same seed should produce identical generation hash for seed %d" % seed)
	return failures


func _test_seed_variation() -> Array[String]:
	var failures: Array[String] = []
	var hashes: Dictionary = {}
	for seed in SEEDS:
		var layout: Dictionary = _make_generator().generate_world(seed)
		var hash := WORLD_GENERATION_RESULT.compute_hash_from_layout(layout)
		if hashes.has(hash):
			failures.append("Different seeds produced the same hash: %d and %d" % [seed, int(hashes[hash])])
		else:
			hashes[hash] = seed
	return failures


func _test_debug_metrics_present() -> Array[String]:
	var failures: Array[String] = []
	var layout: Dictionary = _make_generator().generate_world(SEEDS[0])
	var debug := Dictionary(layout.get("debug", {}))
	for key in ["world_seed", "biome_count_by_type", "dominant_biome", "height_range", "moisture_range", "danger_range", "biome_region_count", "small_biome_region_count"]:
		TEST_UTILS.expect(debug.has(key), failures, "Debug data should include %s" % key)
	TEST_UTILS.expect_equal(int(debug.get("world_seed", 0)), SEEDS[0], failures, "Debug world_seed should match the requested seed")
	return failures


func _test_shore_rules() -> Array[String]:
	var failures: Array[String] = []
	for seed in SEEDS:
		var generator := _make_generator()
		var layout: Dictionary = generator.generate_world(seed)
		var shore_points := _sample_points(layout, func(gen: Object, pos: Vector2) -> bool:
			return float(gen.get_distance_to_shore_at(pos)) <= 0.12
		)
		if shore_points.is_empty():
			failures.append("No shore-adjacent samples found for seed %d" % seed)
			continue
		var best := 0
		for position in shore_points:
			if str(generator.get_biome_id_at(position)) == "shore":
				best += 1
		TEST_UTILS.expect(best >= int(ceil(float(shore_points.size()) * 0.6)), failures, "Shore samples should usually map to Shore for seed %d" % seed)
	return failures


func _test_stoneback_ridge_rules() -> Array[String]:
	var failures: Array[String] = []
	for seed in SEEDS:
		var generator := _make_generator()
		var layout: Dictionary = generator.generate_world(seed)
		var high_points := _sample_points(layout, func(gen: Object, pos: Vector2) -> bool:
			var c := Dictionary(gen.get_terrain_condition_at(pos))
			return float(c.get("height", 0.0)) >= 0.72 and float(c.get("vegetation_density", 1.0)) <= 0.45
		)
		if high_points.is_empty():
			failures.append("No ridge candidate samples found for seed %d" % seed)
			continue
		var ridge_hits := 0
		for position in high_points:
			if str(generator.get_biome_id_at(position)) == "stoneback_ridge":
				ridge_hits += 1
		TEST_UTILS.expect(ridge_hits >= max(1, int(high_points.size() * 0.35)), failures, "High, sparse terrain should often become Stoneback Ridge for seed %d" % seed)
	return failures


func _test_south_thicket_rules() -> Array[String]:
	var failures: Array[String] = []
	for seed in SEEDS:
		var generator := _make_generator()
		var layout: Dictionary = generator.generate_world(seed)
		var wet_points := _sample_points(layout, func(gen: Object, pos: Vector2) -> bool:
			var c := Dictionary(gen.get_terrain_condition_at(pos))
			return float(c.get("moisture", 0.0)) >= 0.65 and float(c.get("vegetation_density", 0.0)) >= 0.65
		)
		if wet_points.is_empty():
			failures.append("No wet thicket candidate samples found for seed %d" % seed)
			continue
		var hits := 0
		for position in wet_points:
			if str(generator.get_biome_id_at(position)) == "south_thicket":
				hits += 1
		TEST_UTILS.expect(hits >= max(1, int(wet_points.size() * 0.35)), failures, "Wet, dense terrain should often become South Thicket for seed %d" % seed)
	return failures


func _test_hearth_meadow_rules() -> Array[String]:
	var failures: Array[String] = []
	for seed in SEEDS:
		var generator := _make_generator()
		var layout: Dictionary = generator.generate_world(seed)
		var meadow_points := _sample_points(layout, func(gen: Object, pos: Vector2) -> bool:
			var c := Dictionary(gen.get_terrain_condition_at(pos))
			return float(c.get("moisture", 0.0)) >= 0.35 and float(c.get("moisture", 0.0)) <= 0.65 and float(c.get("vegetation_density", 1.0)) <= 0.45 and float(c.get("danger", 1.0)) <= 0.7
		)
		if meadow_points.is_empty():
			failures.append("No meadow candidate samples found for seed %d" % seed)
			continue
		var hits := 0
		for position in meadow_points:
			if str(generator.get_biome_id_at(position)) == "hearth_meadow":
				hits += 1
		TEST_UTILS.expect(hits >= max(1, int(meadow_points.size() * 0.30)), failures, "Open moderate terrain should often become Hearth Meadow for seed %d" % seed)
	return failures


func _test_redfang_rules() -> Array[String]:
	var failures: Array[String] = []
	for seed in SEEDS:
		var generator := _make_generator()
		var layout: Dictionary = generator.generate_world(seed)
		var wild_points := _sample_points(layout, func(gen: Object, pos: Vector2) -> bool:
			var c := Dictionary(gen.get_terrain_condition_at(pos))
			return float(c.get("danger", 0.0)) >= 0.65 and float(c.get("moisture", 1.0)) <= 0.45 and float(c.get("distance_to_shore", 0.0)) >= 0.45
		)
		if wild_points.is_empty():
			failures.append("No Redfang candidate samples found for seed %d" % seed)
			continue
		var hits := 0
		for position in wild_points:
			if str(generator.get_biome_id_at(position)) == "redfang_wilds":
				hits += 1
		TEST_UTILS.expect(hits >= max(1, int(wild_points.size() * 0.30)), failures, "Dangerous inner land should often become Redfang Wilds for seed %d" % seed)
	return failures


func _test_world_minimap_map_source_alignment() -> Array[String]:
	var failures: Array[String] = []
	for seed in SEEDS:
		var generator := _make_generator()
		var layout: Dictionary = generator.generate_world(seed)
		var sample_points := [
			Vector2(0.0, 0.0),
			Vector2(-960.0, -320.0),
			Vector2(640.0, 480.0),
			Vector2(1320.0, -720.0)
		]
		for position in sample_points:
			var world_id := str(generator.get_biome_id_at(position))
			var visual_id := str(generator.get_visual_biome_id_at(position))
			TEST_UTILS.expect(not world_id.is_empty(), failures, "World biome lookup should produce an id at %s for seed %d" % [position, seed])
			TEST_UTILS.expect(not visual_id.is_empty(), failures, "Visual biome lookup should produce an id at %s for seed %d" % [position, seed])
			TEST_UTILS.expect_equal(world_id, generator.get_biome_id_at(position), failures, "World biome lookup should be stable")
			TEST_UTILS.expect_equal(visual_id, generator.get_visual_biome_id_at(position), failures, "Visual biome lookup should be stable")
		var debug := Dictionary(layout.get("debug", {}))
		TEST_UTILS.expect(int(debug.get("biome_region_count", 0)) > 0, failures, "Biome region count should be populated")
		TEST_UTILS.expect(int(debug.get("biome_count_by_type", {}).size()) > 0, failures, "Biome counts should be populated")
	return failures
