extends RefCounted

const CREATURE_STATE := preload("res://scripts/core/creatures/creature_state.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_creature_state_round_trip_for_small_prey(failures)
	_test_creature_state_round_trip_for_grazer(failures)
	_test_creature_state_round_trip_for_varnak(failures)
	_test_creature_state_duplicate_is_independent(failures)
	_test_creature_state_legacy_and_core_save_data_stay_in_sync(failures)
	return failures


func _test_creature_state_round_trip_for_small_prey(failures: Array[String]) -> void:
	var state := CREATURE_STATE.new()
	state.entity_id = 42
	state.creature_type = "small_prey"
	state.species_id = "small_prey"
	state.species_name = "Small Prey"
	state.generation = 3
	state.position = Vector2(120.0, -40.0)
	state.facing_angle = 0.45
	state.facing_side = -1.0
	state.stats.max_health = 24.0
	state.stats.health = 18.0
	state.stats.speed = 88.0
	state.stats.fear = 0.7
	state.stats.plant_diet = 1.0
	state.needs.hunger = 0.62
	state.needs.max_hunger = 1.0
	state.needs.hunger_growth_rate = 0.2
	state.needs.energy = 0.74
	state.memory.current_behavior = "seek_food"
	state.memory.decision_reason = "hungry_seek_plant"
	state.memory.last_food_source = "plants"
	state.memory.home_biome = "hearth_meadow"
	state.memory.current_biome = "hearth_meadow"
	state.memory.population_biome = "hearth_meadow"
	state.memory.state_time = 1.25
	state.memory.target_lock_time = 0.35
	state.memory.eat_cooldown = 0.18
	state.memory.age_seconds = 42.0
	state.custom_data = {
		"wander_target": {"x": 140.0, "y": -20.0},
		"dropped_meat": false,
		"plant_consumption_rate": 0.4
	}

	var restored := CREATURE_STATE.new()
	restored.load_from_save_data(state.to_save_data())
	TEST_UTILS.expect_equal(restored.to_save_data(), state.to_save_data(), failures, "Small prey creature state should round-trip cleanly")
	TEST_UTILS.expect_equal(restored.creature_type, "small_prey", failures, "Small prey creature type should survive round-trip")
	TEST_UTILS.expect_equal(restored.memory.current_behavior, "seek_food", failures, "Small prey behavior should survive round-trip")
	TEST_UTILS.expect_equal(restored.custom_data.get("plant_consumption_rate", 0.0), 0.4, failures, "Small prey custom data should survive round-trip")


func _test_creature_state_round_trip_for_grazer(failures: Array[String]) -> void:
	var state := CREATURE_STATE.new()
	state.entity_id = 84
	state.creature_type = "grazer"
	state.species_id = "grazer"
	state.species_name = "Grazer"
	state.generation = 5
	state.position = Vector2(-120.0, 55.0)
	state.stats.max_health = 46.0
	state.stats.health = 31.0
	state.stats.speed = 72.0
	state.stats.aggression = 0.18
	state.stats.plant_diet = 0.82
	state.stats.meat_diet = 0.05
	state.stats.scavenger_diet = 0.13
	state.stats.size = 1.4
	state.needs.hunger = 0.45
	state.needs.max_hunger = 1.0
	state.needs.hunger_growth_rate = 0.3
	state.needs.energy = 0.63
	state.memory.current_behavior = "hunt_small_prey"
	state.memory.decision_reason = "hungry_no_plants_predation"
	state.memory.last_food_source = "small_prey_meat"
	state.memory.home_biome = "stoneback_ridge"
	state.memory.current_biome = "stoneback_ridge"
	state.memory.population_biome = "stoneback_ridge"
	state.memory.state_time = 2.0
	state.memory.target_lock_time = 0.9
	state.memory.age_seconds = 88.0
	state.custom_data = {
		"wander_target": {"x": -96.0, "y": 72.0},
		"current_niche": "OMNIVORE",
		"plant_consumption_rate": 1.2,
		"dropped_meat": true
	}

	var restored := CREATURE_STATE.new()
	restored.load_from_save_data(state.to_save_data())
	TEST_UTILS.expect_equal(restored.to_save_data(), state.to_save_data(), failures, "Grazer creature state should round-trip cleanly")
	TEST_UTILS.expect_equal(restored.stats.size, 1.4, failures, "Grazer size should survive round-trip")
	TEST_UTILS.expect_equal(restored.memory.current_behavior, "hunt_small_prey", failures, "Grazer behavior should survive round-trip")
	TEST_UTILS.expect_equal(restored.custom_data.get("current_niche", ""), "OMNIVORE", failures, "Grazer custom data should survive round-trip")


func _test_creature_state_round_trip_for_varnak(failures: Array[String]) -> void:
	var state := CREATURE_STATE.new()
	state.entity_id = 126
	state.creature_type = "varnak"
	state.species_id = "varnak"
	state.species_name = "Varnak"
	state.generation = 7
	state.position = Vector2(200.0, 120.0)
	state.stats.max_health = 92.0
	state.stats.health = 77.0
	state.stats.speed = 108.0
	state.stats.fear = 0.0
	state.stats.aggression = 0.52
	state.stats.meat_diet = 1.0
	state.stats.scavenger_diet = 0.45
	state.stats.fire_fear = 0.85
	state.stats.trap_awareness = 0.2
	state.stats.pack_coordination = 0.3
	state.stats.night_activity = 0.4
	state.needs.hunger = 0.28
	state.needs.max_hunger = 1.0
	state.needs.hunger_growth_rate = 0.18
	state.needs.energy = 0.81
	state.memory.current_behavior = "hunt_ecosystem"
	state.memory.decision_reason = "hunt_drive_ecosystem_prey"
	state.memory.last_food_source = "small_prey_meat"
	state.memory.population_biome = "redfang_wilds"
	state.memory.state_time = 3.4
	state.memory.target_lock_time = 1.1
	state.memory.age_seconds = 144.0
	state.custom_data = {
		"wander_target": {"x": 240.0, "y": 130.0},
		"ecosystem_target_kind": "small_prey",
		"attack_cooldown": 0.7,
		"night_health_bonus_active": true,
		"dropped_meat": true,
		"base_curiosity": 0.12,
		"stalk_tendency": 0.18
	}

	var restored := CREATURE_STATE.new()
	restored.load_from_save_data(state.to_save_data())
	TEST_UTILS.expect_equal(restored.to_save_data(), state.to_save_data(), failures, "Varnak creature state should round-trip cleanly")
	TEST_UTILS.expect_equal(restored.stats.fire_fear, 0.85, failures, "Varnak fire fear should survive round-trip")
	TEST_UTILS.expect_equal(restored.memory.current_behavior, "hunt_ecosystem", failures, "Varnak behavior should survive round-trip")
	TEST_UTILS.expect_equal(bool(restored.custom_data.get("night_health_bonus_active", false)), true, failures, "Varnak custom data should survive round-trip")


func _test_creature_state_duplicate_is_independent(failures: Array[String]) -> void:
	var state := CREATURE_STATE.new()
	state.species_id = "small_prey"
	state.stats.health = 12.0
	state.needs.hunger = 0.4
	state.memory.current_behavior = "wander"
	state.custom_data = {"wander_target": {"x": 10.0, "y": 20.0}}
	var duplicate := state.duplicate_state()
	duplicate.stats.health = 3.0
	duplicate.needs.hunger = 0.9
	duplicate.memory.current_behavior = "flee"
	duplicate.custom_data["wander_target"] = {"x": 99.0, "y": 99.0}
	TEST_UTILS.expect_equal(state.stats.health, 12.0, failures, "CreatureState duplicate should not mutate original stats")
	TEST_UTILS.expect_equal(state.needs.hunger, 0.4, failures, "CreatureState duplicate should not mutate original needs")
	TEST_UTILS.expect_equal(state.memory.current_behavior, "wander", failures, "CreatureState duplicate should not mutate original memory")
	TEST_UTILS.expect_equal(Dictionary(state.custom_data).get("wander_target", {}), {"x": 10.0, "y": 20.0}, failures, "CreatureState duplicate should deep-copy custom data")


func _test_creature_state_legacy_and_core_save_data_stay_in_sync(failures: Array[String]) -> void:
	var state := CREATURE_STATE.new()
	state.entity_id = 7
	state.creature_type = "small_prey"
	state.species_id = "small_prey"
	state.species_name = "Small Prey"
	state.generation = 2
	state.position = Vector2(9.0, 11.0)
	state.stats.max_health = 20.0
	state.stats.health = 13.0
	state.stats.speed = 88.0
	state.needs.hunger = 0.33
	state.needs.max_hunger = 1.0
	state.memory.current_behavior = "seek_food"
	state.memory.decision_reason = "hungry_seek_plant"
	state.custom_data = {"plant_consumption_rate": 0.4}
	var save_data := state.to_save_data()
	TEST_UTILS.expect_equal(Dictionary(save_data.get("custom_data", {})).get("plant_consumption_rate", null), 0.4, failures, "CreatureState save data should expose custom data")
	TEST_UTILS.expect_equal(str(save_data.get("creature_type", "")), "small_prey", failures, "CreatureState save data should expose creature type")
	TEST_UTILS.expect_equal(str(save_data.get("species_id", "")), "small_prey", failures, "CreatureState save data should expose species id")
	TEST_UTILS.expect_equal(Dictionary(save_data.get("stats", {})).get("health", null), 13.0, failures, "CreatureState save data should expose health through stats")
