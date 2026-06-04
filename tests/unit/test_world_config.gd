extends RefCounted

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_world_rectangle_is_valid(failures)
	_test_resource_spawn_config_is_valid(failures)
	_test_biome_config_is_valid(failures)
	_test_landmark_config_is_valid(failures)
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
	TEST_UTILS.expect(not landmarks.is_empty(), failures, "Landmark list should not be empty")
	var pond_count := 0
	var hill_count := 0
	var pond_biomes: Dictionary = {}
	var hill_biomes: Dictionary = {}
	for landmark in landmarks:
		match str(landmark.get("type", "")):
			"pond":
				pond_count += 1
				pond_biomes[str(landmark.get("biome_id", ""))] = true
			"hill":
				hill_count += 1
				hill_biomes[str(landmark.get("biome_id", ""))] = true
	TEST_UTILS.expect(pond_count > 0, failures, "There should be at least one pond landmark")
	TEST_UTILS.expect(hill_count > 0, failures, "There should be at least one hill landmark")
	TEST_UTILS.expect_equal(pond_count, int(GAME_BALANCE.LANDMARKS.get("pond_count", 0)), failures, "Pond landmark count should match the tuned balance target")
	TEST_UTILS.expect_equal(hill_count, int(GAME_BALANCE.LANDMARKS.get("hill_count", 0)), failures, "Hill landmark count should match the tuned balance target")
	TEST_UTILS.expect(pond_biomes.size() >= min(pond_count, 3), failures, "Reduced pond landmarks should still cover multiple biomes for navigation readability")
	TEST_UTILS.expect(hill_biomes.size() >= min(hill_count, 4), failures, "Reduced hill landmarks should still cover multiple biomes for navigation readability")


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
	var seed_a := 101
	var seed_b := 202
	var first_layout: Array[Dictionary] = WORLD_CONFIG.generate_landmarks(seed_a)
	var second_layout: Array[Dictionary] = WORLD_CONFIG.generate_landmarks(seed_a)
	var third_layout: Array[Dictionary] = WORLD_CONFIG.generate_landmarks(seed_b)
	TEST_UTILS.expect_equal(first_layout.size(), second_layout.size(), failures, "The same world seed should generate the same number of landmarks")
	TEST_UTILS.expect_equal(first_layout.size(), third_layout.size(), failures, "Different world seeds should still respect the same landmark target counts")
	var changed_position := false
	for i in range(first_layout.size()):
		var first_landmark := Dictionary(first_layout[i])
		var second_landmark := Dictionary(second_layout[i])
		var third_landmark := Dictionary(third_layout[i])
		var first_position := Vector2(first_landmark.get("position", Vector2.ZERO))
		var second_position := Vector2(second_landmark.get("position", Vector2.ZERO))
		var third_position := Vector2(third_landmark.get("position", Vector2.ZERO))
		TEST_UTILS.expect_close(first_position.x, second_position.x, failures, "The same world seed should reproduce landmark X positions")
		TEST_UTILS.expect_close(first_position.y, second_position.y, failures, "The same world seed should reproduce landmark Y positions")
		if first_position.distance_to(third_position) > 1.0:
			changed_position = true
		TEST_UTILS.expect(WORLD_CONFIG.WORLD_RECT.has_point(first_position), failures, "Generated landmarks should stay inside world bounds")
		TEST_UTILS.expect(first_position.distance_to(WORLD_CONFIG.PLAYER_START_POSITION) >= float(GAME_BALANCE.LANDMARKS.get("landmark_player_safe_distance", 760.0)), failures, "Generated landmarks should stay away from the player start area")
		for j in range(i + 1, first_layout.size()):
			var other_landmark := Dictionary(first_layout[j])
			var other_position := Vector2(other_landmark.get("position", Vector2.ZERO))
			var minimum_distance: float = maxf(float(GAME_BALANCE.LANDMARKS.get("landmark_min_distance", 420.0)), float(first_landmark.get("radius", 0.0)) + float(other_landmark.get("radius", 0.0)) + 40.0)
			TEST_UTILS.expect(first_position.distance_to(other_position) >= minimum_distance, failures, "Generated landmarks should not overlap or crowd each other")
	TEST_UTILS.expect(changed_position, failures, "Different world seeds should produce a different landmark layout")


func _test_weighted_landmark_selection_matches_biome_character(failures: Array[String]) -> void:
	var selected_counts := {
		"westwood_old_hill": 0,
		"westwood_shade_pond": 0,
		"stoneback_spine": 0,
		"stoneback_basin": 0,
		"south_thicket_mound": 0,
		"south_thicket_pool": 0,
		"redfang_lookout": 0,
		"redfang_teeth": 0,
		"redfang_darkwater": 0
	}
	for seed in range(1, 97):
		var layout: Array[Dictionary] = WORLD_CONFIG.generate_landmarks(seed)
		for landmark_value in layout:
			var landmark := Dictionary(landmark_value)
			var landmark_id := str(landmark.get("id", ""))
			if selected_counts.has(landmark_id):
				selected_counts[landmark_id] = int(selected_counts.get(landmark_id, 0)) + 1
	TEST_UTILS.expect(int(selected_counts.get("stoneback_spine", 0)) > int(selected_counts.get("stoneback_basin", 0)), failures, "Stoneback Ridge should receive hill landmarks more often than pond landmarks across many seeds")
	TEST_UTILS.expect(int(selected_counts.get("westwood_shade_pond", 0)) > int(selected_counts.get("westwood_old_hill", 0)), failures, "Westwood should select its pond landmark more often than its hill landmark across many seeds")
	TEST_UTILS.expect(int(selected_counts.get("south_thicket_pool", 0)) > int(selected_counts.get("south_thicket_mound", 0)), failures, "South Thicket should select its pond landmark more often than its hill landmark across many seeds")
	var redfang_hill_total := int(selected_counts.get("redfang_lookout", 0)) + int(selected_counts.get("redfang_teeth", 0))
	var redfang_pond_total := int(selected_counts.get("redfang_darkwater", 0))
	TEST_UTILS.expect(redfang_hill_total > redfang_pond_total, failures, "Redfang Wilds should surface dangerous hill landmarks more often than its pond landmark across many seeds")


func _get_biome_profiles() -> Dictionary:
	var profiles := {}
	var biomes: Array[Dictionary] = WORLD_CONFIG.get_biome_zones()
	for biome_value in biomes:
		var biome := Dictionary(biome_value)
		profiles[str(biome.get("name", "")).to_snake_case()] = biome
	return profiles
