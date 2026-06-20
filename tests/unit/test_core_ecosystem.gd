extends RefCounted

const ECOSYSTEM_STATE := preload("res://scripts/core/ecosystem/ecosystem_state.gd")
const BIOME_STATE := preload("res://scripts/core/ecosystem/biome_ecosystem_state.gd")
const ECOSYSTEM_SIMULATION := preload("res://scripts/core/ecosystem/ecosystem_simulation.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_biomass_recovers_without_scene(failures)
	_test_prey_and_grazer_populations_grow_with_food(failures)
	_test_varnak_pressure_reduces_prey_and_grazers(failures)
	_test_tick_is_deterministic_for_same_input(failures)
	_test_daily_changes_recover_low_populations(failures)
	return failures

func _make_biome_state(overrides: Dictionary = {}) -> BiomeEcosystemState:
	var data := {
		"biome_id": "test_biome",
		"name": "Test Biome",
		"plant_biomass": 100.0,
		"max_plant_biomass": 100.0,
		"plant_regrowth_rate": 1.5,
		"small_prey_population": 12.0,
		"grazer_population": 6.0,
		"varnak_population": 0.0,
		"varnak_ecosystem_pressure": 0.0,
		"predator_pressure": 0.0,
		"average_meat_diet": 0.05,
		"average_scavenger_diet": 0.10
	}
	for key in overrides.keys():
		data[key] = overrides[key]
	return BIOME_STATE.from_dictionary(data)

func _make_ecosystem_state(biome_state: BiomeEcosystemState) -> EcosystemState:
	var state := ECOSYSTEM_STATE.new()
	state.source = "unit_test"
	state.day = 1
	state.set_biome_state(biome_state)
	return state

func _test_biomass_recovers_without_scene(failures: Array[String]) -> void:
	var sim := ECOSYSTEM_SIMULATION.new()
	var input := _make_ecosystem_state(_make_biome_state({"plant_biomass": 50.0, "small_prey_population": 0.0, "grazer_population": 0.0}))
	var output := sim.tick(input)
	var biome := output.get_biome_state("test_biome")
	_expect(biome != null, failures, "Core ecosystem tick should return biome state")
	if biome == null:
		return
	_expect(biome.plant_biomass > 50.0, failures, "Biomass should recover when there is no grazing pressure")
	_expect(biome.status == "stressed", failures, "Recovered 50% biomass should remain stressed, not disappear")

func _test_prey_and_grazer_populations_grow_with_food(failures: Array[String]) -> void:
	var sim := ECOSYSTEM_SIMULATION.new()
	var input := _make_ecosystem_state(_make_biome_state())
	var output := sim.tick(input)
	var biome := output.get_biome_state("test_biome")
	_expect(biome != null, failures, "Population test should return biome state")
	if biome == null:
		return
	_expect(biome.small_prey_population > 12.0, failures, "Small prey should grow when biomass is healthy and predator pressure is zero")
	_expect(biome.grazer_population > 6.0, failures, "Grazers should grow when biomass is healthy and predator pressure is zero")

func _test_varnak_pressure_reduces_prey_and_grazers(failures: Array[String]) -> void:
	var sim := ECOSYSTEM_SIMULATION.new()
	var input := _make_ecosystem_state(_make_biome_state({
		"small_prey_population": 20.0,
		"grazer_population": 10.0,
		"varnak_population": 3.0,
		"varnak_ecosystem_pressure": 1.0,
		"predator_pressure": 1.0
	}))
	var output := sim.tick(input)
	var biome := output.get_biome_state("test_biome")
	_expect(biome != null, failures, "Varnak pressure test should return biome state")
	if biome == null:
		return
	_expect(biome.small_prey_population < 20.0, failures, "Varnak pressure should reduce small prey population")
	_expect(biome.grazer_population < 10.0, failures, "Varnak pressure should reduce grazer population")
	_expect(biome.small_prey_predation_pressure > 0.0, failures, "Varnak pressure should produce small prey predation pressure")
	_expect(biome.grazer_predation_pressure > 0.0, failures, "Varnak pressure should produce grazer predation pressure")

func _test_tick_is_deterministic_for_same_input(failures: Array[String]) -> void:
	var sim := ECOSYSTEM_SIMULATION.new()
	var input_a := _make_ecosystem_state(_make_biome_state({"plant_biomass": 73.0, "small_prey_population": 16.0, "grazer_population": 8.0, "varnak_ecosystem_pressure": 0.4, "predator_pressure": 0.4}))
	var input_b := _make_ecosystem_state(_make_biome_state({"plant_biomass": 73.0, "small_prey_population": 16.0, "grazer_population": 8.0, "varnak_ecosystem_pressure": 0.4, "predator_pressure": 0.4}))
	var output_a := sim.tick(input_a).to_dictionary()
	var output_b := sim.tick(input_b).to_dictionary()
	_expect(str(output_a) == str(output_b), failures, "Core ecosystem tick should be deterministic for identical input")

func _test_daily_changes_recover_low_populations(failures: Array[String]) -> void:
	var sim := ECOSYSTEM_SIMULATION.new()
	var input := _make_ecosystem_state(_make_biome_state({"plant_biomass": 100.0, "small_prey_population": 3.0, "grazer_population": 2.0}))
	var output := sim.apply_daily_changes(input)
	var biome := output.get_biome_state("test_biome")
	_expect(biome != null, failures, "Daily changes should return biome state")
	if biome == null:
		return
	_expect(biome.small_prey_population > 3.0, failures, "Daily changes should recover small prey population")
	_expect(biome.grazer_population > 2.0, failures, "Daily changes should recover grazer population")
	_expect(output.day == 2, failures, "Daily changes should advance ecosystem day")

func _expect(condition: bool, failures: Array[String], message: String) -> void:
	if not condition:
		failures.append(message)
