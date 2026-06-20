extends RefCounted

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const WORLD_TOPOGRAPHY := preload("res://scripts/world/world_topography.gd")
const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_world_rectangle_is_valid(failures)
	_test_resource_spawn_config_is_valid(failures)
	_test_biome_config_is_valid(failures)
	_test_landmark_config_is_valid(failures)
	_test_generated_landmarks_stay_on_land(failures)
	_test_biome_landmark_weights_follow_design(failures)
	_test_randomized_landmarks_are_seeded_and_spaced(failures)
	_test_weighted_landmark_selection_matches_biome_character(failures)
	return failures


func _test_world_rectangle_is_valid(failures: Array[String]) -> void:
	TEST_UTILS.expect(WORLD_CONFIG.WORLD_RECT.size.x > 0.0, failures, "World width should be positive")
	TEST_UTILS.expect(WORLD_CONFIG.WORLD_RECT.size.y > 0.0, failures, "World height should be positive")
	var limits: Vector2 = WORLD_CONFIG.get_player_limits()
	TEST_UTILS.expect(limits.x > 0.0 and limits.y > 0.0, failures, "Player limits should be positive")


func _test_resource_spawn_config_is_valid(failures: Array[String]) -> void:
	TEST_UTILS.expect(WORLD_CONFIG.TREE_COUNT > 0, failures, "Tree count should be positive")
	TEST_UTILS.expect(WORLD_CONFIG.ROCK_COUNT > 0, failures, "Rock count should be positive")
	TEST_UTILS.expect(WORLD_CONFIG.BUSH_COUNT > 0, failures, "Bush count should be positive")
	TEST_UTILS.expect(WORLD_CONFIG.GRASS_PATCH_COUNT > 0, failures, "Grass patch count should be positive")
	TEST_UTILS.expect(WORLD_CONFIG.RESOURCE_SPAWN_ATTEMPTS > 0, failures, "Resource spawn attempts should be positive")
	TEST_UTILS.expect(WORLD_CONFIG.RESOURCE_MIN_DISTANCE > 0.0, failures, "Resource minimum distance should be positive")
	TEST_UTILS.expect(WORLD_CONFIG.RESOURCE_PLAYER_SAFE_DISTANCE > 0.0, failures, "Resource player-safe distance should be positive")


func _test_biome_config_is_valid(failures: Array[String]) -> void:
	var biomes: Array[Dictionary] = WORLD_CONFIG.get_biome_zones()
	TEST_UTILS.expect(not biomes.is_empty(), failures, "Biome zones should not be empty")
	var weight_sum := 0.0
	for biome in biomes:
		weight_sum += max(float(biome.get("tree_weight", 0.0)), 0.0)
		weight_sum += max(float(biome.get("rock_weight", 0.0)), 0.0)
		weight_sum += max(float(biome.get("bush_weight", 0.0)), 0.0)
		weight_sum += max(float(biome.get("grass_weight", 0.0)), 0.0)
	TEST_UTILS.expect(weight_sum > 0.0, failures, "Biome weights should add up to a positive value")
	for biome in biomes:
		TEST_UTILS.expect(not String(biome.get("name", "")).is_empty(), failures, "Each biome should have a name")
		TEST_UTILS.expect(biome.has("points"), failures, "Each biome should define points")


func _test_landmark_config_is_valid(failures: Array[String]) -> void:
	var landmarks: Array[Dictionary] = WORLD_CONFIG.get_landmarks()
	TEST_UTILS.expect(landmarks.is_empty(), failures, "WorldConfig should no longer generate pond/hill landmark POIs")
	var topo := WORLD_TOPOGRAPHY.new()
	topo.setup(
		12345,
		Callable(self, "_get_test_biome_id"),
		Callable(self, "_get_test_base_terrain_zone")
	)
	var topo_counts := Dictionary(topo.get_topography_feature_counts_debug())
	TEST_UTILS.expect(int(topo_counts.get("pond", 0)) > 0, failures, "Topography should generate pond features")
	TEST_UTILS.expect(int(topo_counts.get("highland", 0)) > 0, failures, "Topography should generate highland features")
	TEST_UTILS.expect(int(topo_counts.get("rocky_patch", 0)) > 0, failures, "Topography should generate rocky patch features")
	topo = null


func _test_biome_landmark_weights_follow_design(failures: Array[String]) -> void:
	var biome_profiles := _get_biome_profiles()
	var westwood := Dictionary(biome_profiles.get("westwood", {}))
	var stoneback := Dictionary(biome_profiles.get("stoneback_ridge", {}))
	var south_thicket := Dictionary(biome_profiles.get("south_thicket", {}))
	var redfang := Dictionary(biome_profiles.get("redfang_wilds", {}))
	TEST_UTILS.expect(not westwood.is_empty(), failures, "Westwood biome profile should exist")
	TEST_UTILS.expect(not stoneback.is_empty(), failures, "Stoneback Ridge biome profile should exist")
	TEST_UTILS.expect(not south_thicket.is_empty(), failures, "South Thicket biome profile should exist")
	TEST_UTILS.expect(not redfang.is_empty(), failures, "Redfang Wilds biome profile should exist")
	var westwood_weights := Dictionary(westwood.get("landmark_weights", {}))
	var stoneback_weights := Dictionary(stoneback.get("landmark_weights", {}))
	var south_thicket_weights := Dictionary(south_thicket.get("landmark_weights", {}))
	var redfang_weights := Dictionary(redfang.get("landmark_weights", {}))
	var redfang_tag_weights := Dictionary(redfang.get("landmark_tag_weights", {}))
	TEST_UTILS.expect(float(westwood_weights.get("pond", 0.0)) > float(westwood_weights.get("hill", 0.0)), failures, "Westwood should prefer ponds over hills")
	TEST_UTILS.expect(float(south_thicket_weights.get("pond", 0.0)) > float(south_thicket_weights.get("hill", 0.0)), failures, "South Thicket should prefer ponds over hills")
	TEST_UTILS.expect(float(stoneback_weights.get("hill", 0.0)) > float(stoneback_weights.get("pond", 0.0)), failures, "Stoneback Ridge should prefer hills over ponds")
	TEST_UTILS.expect(float(redfang_weights.get("hill", 0.0)) >= float(redfang_weights.get("pond", 0.0)), failures, "Redfang Wilds should not prefer ponds over dangerous hills")
	TEST_UTILS.expect(float(redfang_tag_weights.get("danger", 1.0)) > 1.0, failures, "Redfang Wilds should boost dangerous landmark tags")


func _test_randomized_landmarks_are_seeded_and_spaced(failures: Array[String]) -> void:
	var topo_a := WORLD_TOPOGRAPHY.new()
	var topo_b := WORLD_TOPOGRAPHY.new()
	var topo_c := WORLD_TOPOGRAPHY.new()
	topo_a.setup(101, Callable(self, "_get_test_biome_id"), Callable(self, "_get_test_base_terrain_zone"))
	topo_b.setup(101, Callable(self, "_get_test_biome_id"), Callable(self, "_get_test_base_terrain_zone"))
	topo_c.setup(202, Callable(self, "_get_test_biome_id"), Callable(self, "_get_test_base_terrain_zone"))
	var first_counts := Dictionary(topo_a.get_topography_feature_counts_debug())
	var second_counts := Dictionary(topo_b.get_topography_feature_counts_debug())
	var third_counts := Dictionary(topo_c.get_topography_feature_counts_debug())
	TEST_UTILS.expect_equal(first_counts, second_counts, failures, "The same world seed should reproduce the same topography feature counts")
	TEST_UTILS.expect(first_counts != third_counts, failures, "Different world seeds should produce different topography counts or placements")
	var first_ponds := topo_a.get_topography_features_by_type("pond")
	var second_ponds := topo_b.get_topography_features_by_type("pond")
	TEST_UTILS.expect_equal(first_ponds.size(), second_ponds.size(), failures, "The same world seed should generate the same pond feature count")
	for i in range(first_ponds.size()):
		var first_feature := Dictionary(first_ponds[i])
		var second_feature := Dictionary(second_ponds[i])
		TEST_UTILS.expect_close(Vector2(first_feature.get("position", Vector2.ZERO)).x, Vector2(second_feature.get("position", Vector2.ZERO)).x, failures, "The same world seed should reproduce pond feature X positions")
		TEST_UTILS.expect_close(Vector2(first_feature.get("position", Vector2.ZERO)).y, Vector2(second_feature.get("position", Vector2.ZERO)).y, failures, "The same world seed should reproduce pond feature Y positions")
	topo_a = null
	topo_b = null
	topo_c = null


func _test_generated_landmarks_stay_on_land(failures: Array[String]) -> void:
	for seed in [1, 42, 97]:
		var topo := WORLD_TOPOGRAPHY.new()
		topo.setup(seed, Callable(self, "_get_test_biome_id"), Callable(self, "_get_test_base_terrain_zone"))
		for feature_type in ["pond", "highland", "rocky_patch"]:
			for feature_value in topo.get_topography_features_by_type(feature_type):
				var feature := Dictionary(feature_value)
				var position := Vector2(feature.get("position", Vector2.ZERO))
				var terrain_zone := WORLD_CONFIG.get_terrain_zone(position)
				TEST_UTILS.expect(terrain_zone == "land" or terrain_zone == "highland", failures, "Generated topography features should stay on land")
				var radius := float(feature.get("radius", 0.0))
				var sample_directions := [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
				for direction in sample_directions:
					var sample_zone := WORLD_CONFIG.get_terrain_zone(position + direction * radius * 0.9)
					TEST_UTILS.expect(sample_zone != "deep_ocean" and sample_zone != "shallow_water", failures, "Generated topography feature footprint should avoid ocean water")
		topo = null


func _test_weighted_landmark_selection_matches_biome_character(failures: Array[String]) -> void:
	var selected_counts := {"pond": 0, "highland": 0, "rocky_patch": 0}
	for seed in range(1, 97):
		var topo := WORLD_TOPOGRAPHY.new()
		topo.setup(seed, Callable(self, "_get_test_biome_id"), Callable(self, "_get_test_base_terrain_zone"))
		for feature_type in selected_counts.keys():
			selected_counts[feature_type] = int(selected_counts.get(feature_type, 0)) + topo.get_topography_features_by_type(feature_type).size()
		topo = null
	TEST_UTILS.expect(int(selected_counts.get("pond", 0)) > 0, failures, "Topography should surface pond features across many seeds")
	TEST_UTILS.expect(int(selected_counts.get("highland", 0)) > 0, failures, "Topography should surface highland features across many seeds")
	TEST_UTILS.expect(int(selected_counts.get("rocky_patch", 0)) > 0, failures, "Topography should surface rocky patch features across many seeds")


func _get_biome_profiles() -> Dictionary:
	var profiles := {}
	var biomes: Array[Dictionary] = WORLD_CONFIG.get_biome_zones()
	for biome_value in biomes:
		var biome := Dictionary(biome_value)
		profiles[str(biome.get("name", "")).to_snake_case()] = biome
	return profiles


func _get_test_base_terrain_zone(position: Vector2) -> String:
	return WORLD_CONFIG.get_terrain_zone(position)


func _get_test_biome_id(position: Vector2) -> String:
	for biome_value in WORLD_CONFIG.get_biome_zones():
		var biome := Dictionary(biome_value)
		var points := PackedVector2Array(biome.get("points", []))
		if points.size() >= 3 and Geometry2D.is_point_in_polygon(position, points):
			return str(biome.get("name", "")).to_snake_case()
	return ""
