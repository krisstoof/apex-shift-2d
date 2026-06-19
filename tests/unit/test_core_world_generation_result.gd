extends RefCounted

const WORLD_GENERATOR := preload("res://scripts/world/world_generator.gd")
const WORLD_GENERATION_RESULT := preload("res://scripts/core/world/world_generation_result.gd")
const WORLD_GENERATION_SUMMARY := preload("res://scripts/core/world/world_generation_summary.gd")
const WORLD_GENERATION_HASH := preload("res://scripts/core/world/world_generation_hash.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_result_from_layout_contains_generation_data(failures)
	_test_summary_from_result_contains_stable_counts(failures)
	_test_hash_is_stable_for_same_seed(failures)
	_test_hash_changes_for_different_seed(failures)
	_test_result_does_not_require_nodes(failures)
	return failures


func _test_result_from_layout_contains_generation_data(failures: Array[String]) -> void:
	var generator := WORLD_GENERATOR.new()
	var layout := generator.generate_world(42)
	var result := WORLD_GENERATION_RESULT.from_layout(layout)

	TEST_UTILS.expect_equal(result.seed, 42, failures, "WorldGenerationResult should preserve seed")
	TEST_UTILS.expect(result.world_rect.size.x > 0.0, failures, "WorldGenerationResult should preserve world rect width")
	TEST_UTILS.expect(result.world_rect.size.y > 0.0, failures, "WorldGenerationResult should preserve world rect height")
	TEST_UTILS.expect(not result.biome_regions.is_empty(), failures, "WorldGenerationResult should contain biomes")
	TEST_UTILS.expect(not result.landmarks.is_empty(), failures, "WorldGenerationResult should contain landmarks")
	TEST_UTILS.expect(not result.resource_spawns.is_empty(), failures, "WorldGenerationResult should contain resource spawn data")
	TEST_UTILS.expect(not result.creature_spawns.is_empty(), failures, "WorldGenerationResult should contain creature spawn data")
	TEST_UTILS.expect(not result.debug_stats.is_empty(), failures, "WorldGenerationResult should contain debug stats")
	TEST_UTILS.expect(not result.generation_hash.is_empty(), failures, "WorldGenerationResult should contain generation hash")


func _test_summary_from_result_contains_stable_counts(failures: Array[String]) -> void:
	var generator := WORLD_GENERATOR.new()
	var layout := generator.generate_world(42)
	var result := WORLD_GENERATION_RESULT.from_layout(layout)
	var summary: Object = result.to_summary()

	TEST_UTILS.expect_equal(summary.seed, result.seed, failures, "WorldGenerationSummary should preserve seed")
	TEST_UTILS.expect_equal(summary.biome_count, result.biome_regions.size(), failures, "WorldGenerationSummary should count biomes")
	TEST_UTILS.expect_equal(summary.landmark_count, result.landmarks.size(), failures, "WorldGenerationSummary should count landmarks")
	TEST_UTILS.expect_equal(summary.resource_spawn_count, result.resource_spawns.size(), failures, "WorldGenerationSummary should count resource spawns")
	TEST_UTILS.expect_equal(summary.creature_spawn_count, result.creature_spawns.size(), failures, "WorldGenerationSummary should count creature spawns")
	TEST_UTILS.expect_equal(summary.generation_hash, result.generation_hash, failures, "WorldGenerationSummary should preserve hash")


func _test_hash_is_stable_for_same_seed(failures: Array[String]) -> void:
	var generator_a := WORLD_GENERATOR.new()
	var generator_b := WORLD_GENERATOR.new()

	var layout_a := generator_a.generate_world(12345)
	var layout_b := generator_b.generate_world(12345)

	var hash_a := WORLD_GENERATION_RESULT.compute_hash_from_layout(layout_a)
	var hash_b := WORLD_GENERATION_RESULT.compute_hash_from_layout(layout_b)

	TEST_UTILS.expect_equal(hash_a, hash_b, failures, "WorldGenerationHash should be stable for same seed")


func _test_hash_changes_for_different_seed(failures: Array[String]) -> void:
	var generator_a := WORLD_GENERATOR.new()
	var generator_b := WORLD_GENERATOR.new()

	var layout_a := generator_a.generate_world(42)
	var layout_b := generator_b.generate_world(1337)

	var hash_a := WORLD_GENERATION_RESULT.compute_hash_from_layout(layout_a)
	var hash_b := WORLD_GENERATION_RESULT.compute_hash_from_layout(layout_b)

	TEST_UTILS.expect(hash_a != hash_b, failures, "WorldGenerationHash should usually change for different seeds")


func _test_result_does_not_require_nodes(failures: Array[String]) -> void:
	var result := WORLD_GENERATION_RESULT.new()
	var summary: Object = result.to_summary()

	TEST_UTILS.expect(result is RefCounted, failures, "WorldGenerationResult should be RefCounted")
	TEST_UTILS.expect(summary is RefCounted, failures, "WorldGenerationSummary should be RefCounted")
