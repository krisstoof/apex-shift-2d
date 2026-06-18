extends RefCounted

const WORLD_SCRIPT := preload("res://scripts/world/world.gd")
const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_resource_spawn_summary_aggregates_counts(failures)
	_test_resource_spawn_debug_exposes_cache_count(failures)
	_test_decorative_spawn_attempt_budget_is_configured(failures)
	return failures


func _make_world() -> Node:
	return WORLD_SCRIPT.new()


func _test_resource_spawn_summary_aggregates_counts(failures: Array[String]) -> void:
	var world := _make_world()
	world.call("_record_resource_spawn_request", "grass_patch", "hearth_meadow", 10)
	world.call("_record_resource_spawn_failure", "grass_patch", "hearth_meadow", 10)
	world.call("_record_resource_spawn_rejection", "grass_patch", "hearth_meadow", "water")
	world.call("_record_resource_spawn_rejection", "grass_patch", "hearth_meadow", "water")
	world.call("_record_resource_spawn_rejection", "grass_patch", "hearth_meadow", "hill")
	var summary := Dictionary(world.call("_build_resource_spawn_debug_summary"))
	TEST_UTILS.expect_equal(summary.get("summary_count", 0), 1, failures, "Spawn summary should aggregate to one entry")
	TEST_UTILS.expect_equal(summary.get("total_failed", 0), 1, failures, "Spawn summary should count failed attempts")
	TEST_UTILS.expect_equal(summary.get("top_failure_key", ""), "grass_patch|hearth_meadow", failures, "Top failure key should point at the aggregated biome")
	TEST_UTILS.expect(str(summary.get("top_rejection_reason", "")).begins_with("grass_patch|hearth_meadow"), failures, "Top rejection reason should point at the aggregated biome")


func _test_resource_spawn_debug_exposes_cache_count(failures: Array[String]) -> void:
	var world := _make_world()
	var debug := Dictionary(world.call("get_resource_spawn_debug"))
	TEST_UTILS.expect(debug.has("biome_spawn_point_cache_count"), failures, "Resource spawn debug should expose cache count")
	TEST_UTILS.expect_equal(int(debug.get("biome_spawn_point_cache_count", -1)), 0, failures, "Fresh world should start with empty spawn cache")


func _test_decorative_spawn_attempt_budget_is_configured(failures: Array[String]) -> void:
	var world := _make_world()
	var budget := int(world.call("_get_decorative_visual_spawn_attempts", "grass_patch"))
	TEST_UTILS.expect_equal(budget, int(GAME_BALANCE.RESOURCE_SPAWN_OPTIMIZATION.get("decorative_visual_spawn_attempts", 18)), failures, "Decorative attempt budget should come from GameBalance")
