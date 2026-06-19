extends RefCounted

const WORLD_GENERATOR := preload("res://scripts/world/world_generator.gd")
const WORLD_GENERATION_RESULT := preload("res://scripts/core/world/world_generation_result.gd")
const WORLD_GENERATION_VALIDATOR := preload("res://scripts/core/world/world_generation_validator.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")

const TEST_SEEDS: Array[int] = [1, 2, 3, 42, 100, 999, 12345, 54321, 99999, 1337]


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_validator_accepts_generated_worlds_for_multiple_seeds(failures)
	_test_validator_detects_missing_land(failures)
	_test_validator_detects_missing_water(failures)
	_test_validator_detects_player_spawn_in_water(failures)
	_test_validator_detects_creature_spawn_in_disallowed_water(failures)
	_test_validator_detects_vegetation_spawn_in_deep_water(failures)
	_test_validator_detects_landmark_overlap(failures)
	_test_save_load_consistency_uses_generation_hash(failures)
	_test_validator_does_not_require_nodes(failures)
	return failures


func _test_validator_accepts_generated_worlds_for_multiple_seeds(failures: Array[String]) -> void:
	var validator := WORLD_GENERATION_VALIDATOR.new()
	for seed in TEST_SEEDS:
		var generator := WORLD_GENERATOR.new()
		var layout := generator.generate_world(seed)
		var result: WorldGenerationResult = WORLD_GENERATION_RESULT.from_layout(layout)
		var report := validator.validate(result, generator)
		TEST_UTILS.expect_equal(bool(report.get("valid", false)), true, failures, "Generated world should validate for seed %d. Errors: %s" % [seed, str(report.get("errors", []))])


func _test_validator_detects_missing_land(failures: Array[String]) -> void:
	var validator := WORLD_GENERATION_VALIDATOR.new()
	var result: WorldGenerationResult = _make_minimal_valid_result()
	result.terrain_counts = {"deep_ocean": 100, "shallow_water": 10, "pond": 5}
	var report := validator.validate(result)
	TEST_UTILS.expect_equal(bool(report.get("valid", true)), false, failures, "Validator should reject world with no land")


func _test_validator_detects_missing_water(failures: Array[String]) -> void:
	var validator := WORLD_GENERATION_VALIDATOR.new()
	var result: WorldGenerationResult = _make_minimal_valid_result()
	result.terrain_counts = {"land": 100, "highland": 10}
	var report := validator.validate(result)
	TEST_UTILS.expect_equal(bool(report.get("valid", true)), false, failures, "Validator should reject world with no water")


func _test_validator_detects_player_spawn_in_water(failures: Array[String]) -> void:
	var validator := WORLD_GENERATION_VALIDATOR.new()
	var result: WorldGenerationResult = _make_minimal_valid_result()
	result.player_spawn_position = Vector2(100.0, 100.0)
	var terrain_provider := MockTerrainProvider.new()
	terrain_provider.terrain_by_position[str(result.player_spawn_position)] = "deep_ocean"
	var report := validator.validate(result, terrain_provider)
	TEST_UTILS.expect_equal(bool(report.get("valid", true)), false, failures, "Validator should reject player spawn in water")


func _test_validator_detects_creature_spawn_in_disallowed_water(failures: Array[String]) -> void:
	var validator := WORLD_GENERATION_VALIDATOR.new()
	var result: WorldGenerationResult = _make_minimal_valid_result()
	result.creature_spawns = [{
		"id": "bad_varnak_spawn",
		"creature_type": "varnak",
		"position": Vector2(120.0, 100.0),
		"terrain": "pond"
	}]
	var report := validator.validate(result)
	TEST_UTILS.expect_equal(bool(report.get("valid", true)), false, failures, "Validator should reject creature spawn in disallowed water")


func _test_validator_detects_vegetation_spawn_in_deep_water(failures: Array[String]) -> void:
	var validator := WORLD_GENERATION_VALIDATOR.new()
	var result: WorldGenerationResult = _make_minimal_valid_result()
	result.resource_spawns = [{
		"id": "bad_tree_spawn",
		"kind": "conifer_tree",
		"position": Vector2(130.0, 100.0),
		"terrain": "deep_ocean"
	}]
	var report := validator.validate(result)
	TEST_UTILS.expect_equal(bool(report.get("valid", true)), false, failures, "Validator should reject vegetation spawn in deep water")


func _test_validator_detects_landmark_overlap(failures: Array[String]) -> void:
	var validator := WORLD_GENERATION_VALIDATOR.new()
	var result: WorldGenerationResult = _make_minimal_valid_result()
	result.landmarks = [
		{"id": "old_tree", "position": Vector2(100.0, 100.0), "radius": 80.0},
		{"id": "ruins", "position": Vector2(110.0, 100.0), "radius": 80.0}
	]
	var report := validator.validate(result)
	TEST_UTILS.expect_equal(bool(report.get("valid", true)), false, failures, "Validator should reject badly overlapping landmarks")


func _test_save_load_consistency_uses_generation_hash(failures: Array[String]) -> void:
	var validator := WORLD_GENERATION_VALIDATOR.new()
	var before: WorldGenerationResult = _make_minimal_valid_result()
	var after: WorldGenerationResult = _make_minimal_valid_result()
	before.seed = 42
	after.seed = 42
	before.generation_hash = "same_hash"
	after.generation_hash = "same_hash"
	var same_report := validator.validate_save_load_consistency(before, after)
	TEST_UTILS.expect_equal(bool(same_report.get("valid", false)), true, failures, "Validator should accept matching save/load generation hash")
	after.generation_hash = "different_hash"
	var different_report := validator.validate_save_load_consistency(before, after)
	TEST_UTILS.expect_equal(bool(different_report.get("valid", true)), false, failures, "Validator should reject mismatched save/load generation hash")


func _test_validator_does_not_require_nodes(failures: Array[String]) -> void:
	var validator := WORLD_GENERATION_VALIDATOR.new()
	var result: WorldGenerationResult = _make_minimal_valid_result()
	var report := validator.validate(result)
	TEST_UTILS.expect(validator is RefCounted, failures, "WorldGenerationValidator should be RefCounted")
	TEST_UTILS.expect(report.has("valid"), failures, "Validator should return a report without requiring scene tree")


func _make_minimal_valid_result():
	var result: WorldGenerationResult = WORLD_GENERATION_RESULT.new()
	result.seed = 42
	result.generator_version = "test"
	result.world_rect = Rect2(Vector2.ZERO, Vector2(1000.0, 1000.0))
	result.terrain_counts = {
		"land": 100,
		"highland": 10,
		"deep_ocean": 20,
		"shallow_water": 10,
		"pond": 5
	}
	result.biome_regions = [{"id": "hearth_meadow", "sample_count": 100}]
	result.landmarks = [{"id": "safe_landmark", "position": Vector2(500.0, 500.0), "radius": 20.0}]
	result.player_spawn_position = Vector2(100.0, 100.0)
	result.resource_spawns = [{"id": "tree_spawn", "kind": "conifer_tree", "position": Vector2(140.0, 100.0), "terrain": "land"}]
	result.creature_spawns = [{"id": "prey_spawn", "creature_type": "small_prey", "position": Vector2(160.0, 100.0), "terrain": "land"}]
	result.debug_stats = {
		"terrain_counts": result.terrain_counts.duplicate(true),
		"biome_coverage": {"hearth_meadow": 100}
	}
	result.generation_hash = "test_hash"
	return result


class MockTerrainProvider:
	extends RefCounted

	var terrain_by_position: Dictionary = {}

	func get_terrain_zone(position: Vector2) -> String:
		return str(terrain_by_position.get(str(position), "land"))
