extends RefCounted

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const ECOSYSTEM_DIRECTOR := preload("res://scripts/systems/ecosystem_director.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_grazer_traits_use_state_and_balance_defaults(failures)
	_test_small_prey_traits_use_state_and_balance_defaults(failures)
	_test_save_and_load_round_trip_restores_biome_state(failures)
	return failures


func _test_grazer_traits_use_state_and_balance_defaults(failures: Array[String]) -> void:
	var director := ECOSYSTEM_DIRECTOR.new()
	director.biome_states = {
		"hearth_meadow": {
			"biome_id": "hearth_meadow",
			"grazer_generation": 4,
			"average_plant_diet": 0.72,
			"average_meat_diet": 0.18,
			"average_scavenger_diet": 0.10,
			"average_aggression": 0.28,
			"average_grazer_reproduction": 0.41,
			"current_niche": "OMNIVORE"
		}
	}
	var traits: Dictionary = director.get_grazer_traits("hearth_meadow")
	TEST_UTILS.expect_equal(traits.get("biome_id", ""), "hearth_meadow", failures, "Grazer traits should preserve the biome id")
	TEST_UTILS.expect_equal(int(traits.get("generation", 0)), 4, failures, "Grazer traits should use the biome generation")
	TEST_UTILS.expect_close(float(traits.get("plant_diet", 0.0)), 0.72, failures, "Grazer traits should use the stored plant diet")
	TEST_UTILS.expect_close(float(traits.get("meat_diet", 0.0)), 0.18, failures, "Grazer traits should use the stored meat diet")
	TEST_UTILS.expect_close(float(traits.get("scavenger_diet", 0.0)), 0.10, failures, "Grazer traits should use the stored scavenger diet")
	TEST_UTILS.expect_close(float(traits.get("aggression", 0.0)), 0.28, failures, "Grazer traits should use the stored aggression")
	TEST_UTILS.expect_close(float(traits.get("reproduction_rate", 0.0)), 0.41, failures, "Grazer traits should use the stored reproduction rate")
	TEST_UTILS.expect_equal(traits.get("current_niche", ""), "OMNIVORE", failures, "Grazer traits should preserve the stored niche")
	TEST_UTILS.expect_equal(
		director.get_biome_status("missing_biome"),
		"unknown",
		failures,
		"Missing biome status should fall back to unknown"
	)
	director.free()


func _test_small_prey_traits_use_state_and_balance_defaults(failures: Array[String]) -> void:
	var director := ECOSYSTEM_DIRECTOR.new()
	director.biome_states = {
		"hearth_meadow": {
			"biome_id": "hearth_meadow",
			"small_prey_generation": 5,
			"average_small_prey_speed": 102.0
		}
	}
	var traits: Dictionary = director.get_small_prey_traits("hearth_meadow")
	TEST_UTILS.expect_equal(traits.get("biome_id", ""), "hearth_meadow", failures, "Small prey traits should preserve the biome id")
	TEST_UTILS.expect_equal(int(traits.get("generation", 0)), 5, failures, "Small prey traits should use the biome generation")
	TEST_UTILS.expect_close(
		float(traits.get("fear", 0.0)),
		float(GAME_BALANCE.ECOSYSTEM.get("initial_small_prey_fear", 0.90)),
		failures,
		"Small prey traits should fall back to the configured fear default"
	)
	TEST_UTILS.expect_close(float(traits.get("speed", 0.0)), 102.0, failures, "Small prey traits should use the stored speed")
	TEST_UTILS.expect_close(
		float(traits.get("reproduction_value", 0.0)),
		float(GAME_BALANCE.ECOSYSTEM.get("initial_small_prey_reproduction", 0.60)),
		failures,
		"Small prey traits should fall back to the configured reproduction default"
	)
	TEST_UTILS.expect_equal(float(traits.get("plant_diet", 0.0)), 1.0, failures, "Small prey should always keep a plant-only diet")
	director.free()


func _test_save_and_load_round_trip_restores_biome_state(failures: Array[String]) -> void:
	var director := ECOSYSTEM_DIRECTOR.new()
	director.biome_states = {
		"hearth_meadow": {
			"biome_id": "hearth_meadow",
			"name": "Hearth Meadow",
			"plant_biomass": 72.0,
			"plant_biomass_percent": 72.0,
			"max_plant_biomass": 100.0,
			"small_prey_population": 12.0,
			"grazer_population": 4.0,
			"status": "stable"
		}
	}
	director.tick_timer = 2.5
	var save_data: Dictionary = director.get_save_data()
	director.biome_states["hearth_meadow"]["plant_biomass"] = 10.0
	director.tick_timer = 0.0
	director.load_save_data(save_data)
	var restored: Dictionary = director.get_biome_state("hearth_meadow")
	TEST_UTILS.expect_close(float(restored.get("plant_biomass", 0.0)), 72.0, failures, "Biome biomass should round-trip through save data")
	TEST_UTILS.expect_close(director.tick_timer, 2.5, failures, "The ecosystem tick timer should round-trip through save data")
	director.free()
