extends RefCounted
class_name EcosystemSimulation

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const ECOSYSTEM_STATE := preload("res://scripts/core/ecosystem/ecosystem_state.gd")
const BIOME_STATE := preload("res://scripts/core/ecosystem/biome_ecosystem_state.gd")
const BIOMASS_MODEL := preload("res://scripts/core/ecosystem/biomass_model.gd")
const POPULATION_MODEL := preload("res://scripts/core/ecosystem/population_model.gd")

func tick(state: EcosystemState, options: Dictionary = {}) -> EcosystemState:
	if state == null:
		return ECOSYSTEM_STATE.new()
	var result: EcosystemState = state.duplicate_state()
	var ecosystem_balance: Dictionary = _get_ecosystem_balance(options)
	var population_recovery: Dictionary = _get_population_recovery(options)
	for biome_id in result.get_biome_ids():
		var biome_state: BiomeEcosystemState = result.get_biome_state(biome_id)
		if biome_state == null:
			continue
		tick_biome(biome_state, ecosystem_balance, population_recovery)
		result.set_biome_state(biome_state)
	return result

func tick_biome(state: BiomeEcosystemState, ecosystem_balance: Dictionary = {}, population_recovery: Dictionary = {}) -> BiomeEcosystemState:
	var result: BiomeEcosystemState = state.duplicate_state()
	var effective_ecosystem: Dictionary = GAME_BALANCE.ECOSYSTEM if ecosystem_balance.is_empty() else ecosystem_balance
	var effective_recovery: Dictionary = GAME_BALANCE.POPULATION_RECOVERY if population_recovery.is_empty() else population_recovery
	BIOMASS_MODEL.tick_biome(result, effective_ecosystem)
	POPULATION_MODEL.tick_biome(result, effective_ecosystem, effective_recovery)
	result.refresh_derived_state()
	return result

func tick_biome_from_dictionary(state: Dictionary, options: Dictionary = {}) -> Dictionary:
	var biome_state: BiomeEcosystemState = BIOME_STATE.from_dictionary(state)
	var ticked: BiomeEcosystemState = tick_biome(biome_state, _get_ecosystem_balance(options), _get_population_recovery(options))
	return ticked.to_dictionary()

func apply_daily_changes(state: EcosystemState, options: Dictionary = {}) -> EcosystemState:
	if state == null:
		return ECOSYSTEM_STATE.new()
	var result: EcosystemState = state.duplicate_state()
	var ecosystem_balance: Dictionary = _get_ecosystem_balance(options)
	var population_recovery: Dictionary = _get_population_recovery(options)
	var biomass_multiplier: float = float(options.get("biomass_recovery_multiplier", 1.0))
	for biome_id in result.get_biome_ids():
		var biome_state: BiomeEcosystemState = result.get_biome_state(biome_id)
		if biome_state == null:
			continue
		BIOMASS_MODEL.apply_recovery_day(biome_state, ecosystem_balance, biomass_multiplier)
		POPULATION_MODEL.apply_daily_recovery(biome_state, population_recovery)
		result.set_biome_state(biome_state)
	result.day += 1
	return result

func get_debug_summary(state: EcosystemState) -> Dictionary:
	if state == null:
		return {}
	var summary: Dictionary = {
		"biome_count": state.get_biome_ids().size(),
		"small_prey_population": 0.0,
		"grazer_population": 0.0,
		"varnak_population": 0.0,
		"plant_biomass": 0.0,
		"average_biomass_percent": 0.0
	}
	for biome_id in state.get_biome_ids():
		var biome_state: BiomeEcosystemState = state.get_biome_state(biome_id)
		if biome_state == null:
			continue
		summary["small_prey_population"] = float(summary["small_prey_population"]) + biome_state.small_prey_population
		summary["grazer_population"] = float(summary["grazer_population"]) + biome_state.grazer_population
		summary["varnak_population"] = float(summary["varnak_population"]) + biome_state.varnak_population
		summary["plant_biomass"] = float(summary["plant_biomass"]) + biome_state.plant_biomass
		summary["average_biomass_percent"] = float(summary["average_biomass_percent"]) + biome_state.plant_biomass_percent
	if int(summary["biome_count"]) > 0:
		summary["average_biomass_percent"] = float(summary["average_biomass_percent"]) / float(summary["biome_count"])
	return summary

func _get_ecosystem_balance(options: Dictionary) -> Dictionary:
	return Dictionary(options.get("ecosystem_balance", GAME_BALANCE.ECOSYSTEM)).duplicate(true)

func _get_population_recovery(options: Dictionary) -> Dictionary:
	return Dictionary(options.get("population_recovery", GAME_BALANCE.POPULATION_RECOVERY)).duplicate(true)
