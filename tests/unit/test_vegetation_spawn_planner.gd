extends RefCounted

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const WORLD_SCRIPT := preload("res://scripts/world/world.gd")
const VEGETATION_SPAWN_PLANNER := preload("res://scripts/core/worldgen/vegetation_spawn_planner.gd")
const VEGETATION_SPAWN_ADAPTER := preload("res://scripts/godot_adapters/world/godot_vegetation_spawn_adapter.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_profiles_generate_expected_kinds(failures)
	_test_no_water_spawns(failures)
	_test_non_zero_spawn_requests_for_configured_biomes(failures)
	_test_world_vegetation_debug_summary_keeps_core_metrics(failures)
	_test_bounds_only_biome_still_spawns(failures)
	_test_adapter_only_allows_decorative_kinds(failures)
	_test_world_exposes_spawn_refresh_helper(failures)
	return failures


func _build_plan(seed: int) -> Array:
	var planner := VEGETATION_SPAWN_PLANNER.new()
	planner.set_seed(seed)
	var biomes: Array = WORLD_CONFIG.get_biome_zones()
	return planner.build_spawn_plan(
		biomes,
		WORLD_CONFIG.WORLD_RECT,
		Callable(self, "_get_terrain_zone"),
		Callable(self, "_is_blocked_by_water"),
		Callable(self, "_is_blocked_by_hill"),
		180,
		Vector2.ZERO
	)


func _test_profiles_generate_expected_kinds(failures: Array[String]) -> void:
	var aggregated := {
		"westwood": {},
		"south_thicket": {},
		"redfang_wilds": {}
	}
	for seed in [1, 7, 42, 97]:
		for item_value in _build_plan(seed):
			var item := Dictionary(item_value.to_dictionary() if item_value.has_method("to_dictionary") else item_value)
			var biome_id := str(item.get("biome_id", ""))
			var kind := str(item.get("kind", ""))
			if not aggregated.has(biome_id):
				continue
			var biome_counts := Dictionary(aggregated.get(biome_id, {}))
			biome_counts[kind] = int(biome_counts.get(kind, 0)) + 1
			aggregated[biome_id] = biome_counts
	TEST_UTILS.expect(int(Dictionary(aggregated.get("westwood", {})).get("conifer_tree", 0)) > 0, failures, "Westwood should spawn conifer_tree")
	TEST_UTILS.expect(int(Dictionary(aggregated.get("south_thicket", {})).get("leafy_tree", 0)) > 0, failures, "South Thicket should spawn leafy_tree")
	TEST_UTILS.expect(int(Dictionary(aggregated.get("redfang_wilds", {})).get("dry_tree", 0)) > 0 or int(Dictionary(aggregated.get("redfang_wilds", {})).get("dry_bush", 0)) > 0, failures, "Redfang Wilds should spawn dry vegetation")


func _test_no_water_spawns(failures: Array[String]) -> void:
	for item_value in _build_plan(42):
		var item := Dictionary(item_value.to_dictionary() if item_value.has_method("to_dictionary") else item_value)
		var position := Vector2(item.get("position", Vector2.ZERO))
		var terrain_zone := _get_terrain_zone(position)
		if terrain_zone in ["deep_ocean", "shallow_water", "pond"]:
			failures.append("Vegetation plan spawned %s in forbidden terrain zone %s at %s" % [str(item.get("kind", "")), terrain_zone, position])
			return


func _test_non_zero_spawn_requests_for_configured_biomes(failures: Array[String]) -> void:
	var plan := _build_plan(97)
	var counts_by_biome: Dictionary = {}
	for item_value in plan:
		var item := Dictionary(item_value.to_dictionary() if item_value.has_method("to_dictionary") else item_value)
		var biome_id := str(item.get("biome_id", ""))
		var kind := str(item.get("kind", ""))
		if biome_id.is_empty() or kind.is_empty():
			continue
		var biome_counts := Dictionary(counts_by_biome.get(biome_id, {}))
		biome_counts[kind] = int(biome_counts.get(kind, 0)) + 1
		counts_by_biome[biome_id] = biome_counts
	for biome_id in ["westwood", "south_thicket", "hearth_meadow", "stoneback_ridge", "redfang_wilds"]:
		var biome_counts := Dictionary(counts_by_biome.get(biome_id, {}))
		TEST_UTILS.expect(int(biome_counts.get("conifer_tree", 0)) + int(biome_counts.get("leafy_tree", 0)) + int(biome_counts.get("dry_tree", 0)) + int(biome_counts.get("dry_bush", 0)) + int(biome_counts.get("small_bush", 0)) + int(biome_counts.get("berry_bush", 0)) + int(biome_counts.get("grass_patch", 0)) + int(biome_counts.get("dense_grass", 0)) > 0, failures, "Biome %s should receive vegetation spawn items" % biome_id)


func _test_world_vegetation_debug_summary_keeps_core_metrics(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	world.vegetation_spawn_debug_summary = {
		"core_spawn_plan_size": 123,
		"core_spawn_apply_spawned": 117,
		"core_spawn_apply_failed": 6,
		"core_spawn_applied_by_biome_and_kind": {
			"westwood": {"conifer_tree": 16}
		},
		"core_spawn_failed_by_biome_and_kind": {
			"westwood": {"conifer_tree": 2}
		},
		"core_spawn_plan_by_biome_and_kind": {
			"westwood": {"conifer_tree": 18}
		}
	}
	var debug := Dictionary(world.call("get_vegetation_spawn_debug_summary"))
	TEST_UTILS.expect_equal(int(debug.get("core_spawn_plan_size", 0)), 123, failures, "Vegetation debug summary should expose core_spawn_plan_size")
	TEST_UTILS.expect_equal(int(debug.get("core_spawn_apply_spawned", 0)), 117, failures, "Vegetation debug summary should expose core_spawn_apply_spawned")
	TEST_UTILS.expect_equal(int(debug.get("core_spawn_apply_failed", 0)), 6, failures, "Vegetation debug summary should expose core_spawn_apply_failed")
	var plan_by_biome := Dictionary(debug.get("core_spawn_plan_by_biome_and_kind", {}))
	TEST_UTILS.expect(int(Dictionary(plan_by_biome.get("westwood", {})).get("conifer_tree", 0)) > 0, failures, "Vegetation debug summary should preserve core spawn plan breakdown")
	var applied_by_biome := Dictionary(debug.get("core_spawn_applied_by_biome_and_kind", {}))
	TEST_UTILS.expect(int(Dictionary(applied_by_biome.get("westwood", {})).get("conifer_tree", 0)) > 0, failures, "Vegetation debug summary should expose applied core spawn breakdown")
	var failed_by_biome := Dictionary(debug.get("core_spawn_failed_by_biome_and_kind", {}))
	TEST_UTILS.expect(int(Dictionary(failed_by_biome.get("westwood", {})).get("conifer_tree", 0)) > 0, failures, "Vegetation debug summary should expose failed core spawn breakdown")


func _test_bounds_only_biome_still_spawns(failures: Array[String]) -> void:
	var planner := VEGETATION_SPAWN_PLANNER.new()
	planner.set_seed(123)
	var plan := planner.build_spawn_plan(
		[{"id": "bounds_only", "bounds": Rect2(Vector2(-100, -100), Vector2(200, 200))}],
		Rect2(Vector2(-500, -500), Vector2(1000, 1000)),
		Callable(self, "_get_terrain_zone"),
		Callable(self, "_is_blocked_by_water"),
		Callable(self, "_is_blocked_by_hill"),
		12,
		Vector2.ZERO
	)
	TEST_UTILS.expect(not plan.is_empty(), failures, "Bounds-only biome should still produce vegetation spawn items")


func _test_adapter_only_allows_decorative_kinds(failures: Array[String]) -> void:
	var adapter := VEGETATION_SPAWN_ADAPTER.new()
	var decorative_kinds := ["grass_patch", "dense_grass", "reed", "cattail", "water_lily", "pond_grass", "wetland_grass"]
	for kind in decorative_kinds:
		TEST_UTILS.expect(bool(adapter.call("_is_decorative_kind", kind)), failures, "Expected %s to be treated as decorative" % kind)
	for kind in ["conifer_tree", "leafy_tree", "dry_tree", "bush", "dry_bush", "small_bush", "berry_bush"]:
		TEST_UTILS.expect(not bool(adapter.call("_is_decorative_kind", kind)), failures, "Expected %s to be treated as interactive" % kind)


func _test_world_exposes_spawn_refresh_helper(failures: Array[String]) -> void:
	var world := WORLD_SCRIPT.new()
	TEST_UTILS.expect(world.has_method("_refresh_resource_visibility_and_interactions_after_spawn"), failures, "World should expose a post-spawn resource visibility refresh helper")


func _get_terrain_zone(position: Vector2) -> String:
	return WORLD_CONFIG.get_terrain_zone(position)


func _is_blocked_by_water(_kind: String, position: Vector2) -> bool:
	return WORLD_CONFIG.get_terrain_zone(position) in ["deep_ocean", "shallow_water", "pond"]


func _is_blocked_by_hill(_kind: String, position: Vector2) -> bool:
	return WORLD_CONFIG.get_terrain_zone(position) == "highland"
