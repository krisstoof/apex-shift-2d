extends RefCounted

const BiomeVegetationProfiles := preload("res://scripts/core/worldgen/biome_vegetation_profiles.gd")


func run() -> Dictionary:
	var failures: Array[String] = []

	_test_westwood_profile_exists(failures)
	_test_westwood_dominant_kind_is_conifer_tree(failures)
	_test_south_thicket_dominant_kind_is_leafy_tree(failures)
	_test_unknown_biome_falls_back_to_hearth_meadow(failures)
	_test_empty_biome_falls_back_to_hearth_meadow(failures)
	_test_pick_kind_for_known_biomes_never_empty(failures)

	return {
		"passed": failures.is_empty(),
		"failures": failures
	}


func _test_westwood_profile_exists(failures: Array[String]) -> void:
	if BiomeVegetationProfiles.get_profile("westwood").is_empty():
		failures.append("Expected westwood profile to exist")


func _test_westwood_dominant_kind_is_conifer_tree(failures: Array[String]) -> void:
	var dominant := BiomeVegetationProfiles.get_expected_dominant_kind("westwood")
	if dominant != "conifer_tree":
		failures.append("Expected westwood dominant kind to be conifer_tree, got %s" % dominant)


func _test_south_thicket_dominant_kind_is_leafy_tree(failures: Array[String]) -> void:
	var dominant := BiomeVegetationProfiles.get_expected_dominant_kind("south_thicket")
	if dominant != "leafy_tree":
		failures.append("Expected south_thicket dominant kind to be leafy_tree, got %s" % dominant)


func _test_unknown_biome_falls_back_to_hearth_meadow(failures: Array[String]) -> void:
	BiomeVegetationProfiles.clear_unknown_profile_request_counts()

	var unknown_profile := BiomeVegetationProfiles.get_profile("unknown_biome")
	var default_profile := BiomeVegetationProfiles.get_profile(BiomeVegetationProfiles.get_default_profile_id())

	if unknown_profile.is_empty():
		failures.append("Expected unknown biome to return fallback profile")
	if unknown_profile != default_profile:
		failures.append("Expected unknown biome to fallback to hearth_meadow profile")

	var counts := BiomeVegetationProfiles.get_unknown_profile_request_counts()
	if int(counts.get("unknown_biome", 0)) != 1:
		failures.append("Expected unknown_biome request count to be 1")


func _test_empty_biome_falls_back_to_hearth_meadow(failures: Array[String]) -> void:
	BiomeVegetationProfiles.clear_unknown_profile_request_counts()

	var empty_profile := BiomeVegetationProfiles.get_profile("")
	var default_profile := BiomeVegetationProfiles.get_profile(BiomeVegetationProfiles.get_default_profile_id())

	if empty_profile.is_empty():
		failures.append("Expected empty biome id to return fallback profile")
	if empty_profile != default_profile:
		failures.append("Expected empty biome id to fallback to hearth_meadow profile")

	var counts := BiomeVegetationProfiles.get_unknown_profile_request_counts()
	if int(counts.get("<empty>", 0)) != 1:
		failures.append("Expected <empty> request count to be 1")


func _test_pick_kind_for_known_biomes_never_empty(failures: Array[String]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var known_biomes := [
		"westwood",
		"south_thicket",
		"hearth_meadow",
		"stoneback_ridge",
		"redfang_wilds",
		"shore"
	]

	for biome_id in known_biomes:
		for _i in range(20):
			var kind := BiomeVegetationProfiles.pick_kind_for_biome(biome_id, rng)
			if kind.is_empty():
				failures.append("Expected non-empty vegetation kind for biome %s" % biome_id)
				return
