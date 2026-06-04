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
