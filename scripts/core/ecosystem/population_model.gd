extends RefCounted
class_name PopulationModel

static func tick_biome(state: BiomeEcosystemState, ecosystem_balance: Dictionary, population_recovery: Dictionary) -> Dictionary:
	if state == null:
		return {}
	var biomass_factor: float = clamp(state.plant_biomass_percent / 100.0, 0.0, 1.0)
	var predator_pressure: float = clamp(maxf(state.varnak_ecosystem_pressure, state.predator_pressure), 0.0, 1.0)
	var food_stress: float = state.food_stress
	var small_prey_before: float = state.small_prey_population
	var grazer_before: float = state.grazer_population
	var omnivore_resilience: float = state.average_meat_diet + state.average_scavenger_diet
	var small_prey_predation_multiplier: float = _critical_predation_multiplier(state.small_prey_population, _recovery_value(population_recovery, "small_prey_min_population", 12.0), population_recovery)
	var grazer_predation_multiplier: float = _critical_predation_multiplier(state.grazer_population, _recovery_value(population_recovery, "grazer_min_population", 6.0), population_recovery)
	var small_prey_predation_pressure: float = predator_pressure * _value(ecosystem_balance, "small_prey_predation_rate", 1.15) * small_prey_predation_multiplier
	var grazer_predation_pressure: float = predator_pressure * _value(ecosystem_balance, "grazer_predation_rate", 0.65) * grazer_predation_multiplier
	var max_omnivore_resilience: float = _value(ecosystem_balance, "max_omnivore_resilience", 0.85)
	var grazer_starvation_pressure: float = food_stress * _value(ecosystem_balance, "grazer_starvation_rate", 0.70) * (1.0 - clamp(omnivore_resilience, 0.0, max_omnivore_resilience))
	var small_prey_delta: float = biomass_factor * _value(ecosystem_balance, "small_prey_growth_rate", 0.75)
	small_prey_delta -= small_prey_predation_pressure
	if biomass_factor < _value(ecosystem_balance, "small_prey_collapse_biomass_factor", 0.12):
		small_prey_delta -= _value(ecosystem_balance, "small_prey_collapse_loss_rate", 0.65)
	var grazer_delta: float = biomass_factor * _value(ecosystem_balance, "grazer_growth_rate", 0.32)
	grazer_delta -= grazer_starvation_pressure
	grazer_delta -= grazer_predation_pressure
	state.small_prey_population = clamp(state.small_prey_population + small_prey_delta, 0.0, _recovery_value(population_recovery, "small_prey_max_population", 40.0))
	state.grazer_population = clamp(state.grazer_population + grazer_delta, 0.0, _recovery_value(population_recovery, "grazer_max_population", 25.0))
	var actual_small_delta := state.small_prey_population - small_prey_before
	var actual_grazer_delta := state.grazer_population - grazer_before
	state.population_count = state.small_prey_population + state.grazer_population + state.varnak_population
	state.birth_rate = maxf(actual_small_delta + actual_grazer_delta, 0.0)
	state.death_rate = maxf(-(actual_small_delta + actual_grazer_delta), 0.0)
	state.starvation_pressure = food_stress
	state.small_prey_predation_pressure = small_prey_predation_pressure
	state.grazer_predation_pressure = grazer_predation_pressure
	state.grazer_starvation_pressure = grazer_starvation_pressure
	state.small_prey_population_trend = get_population_trend(actual_small_delta)
	state.grazer_population_trend = get_population_trend(actual_grazer_delta)
	return {
		"small_prey_delta": actual_small_delta,
		"grazer_delta": actual_grazer_delta,
		"small_prey_predation_pressure": small_prey_predation_pressure,
		"grazer_predation_pressure": grazer_predation_pressure,
		"grazer_starvation_pressure": grazer_starvation_pressure
	}

static func apply_daily_recovery(state: BiomeEcosystemState, population_recovery: Dictionary, ecosystem_balance: Dictionary = {}) -> Dictionary:
	if state == null:
		return {}
	var biomass_multiplier: float = get_biomass_recovery_multiplier(state.plant_biomass_percent, population_recovery, ecosystem_balance)
	var small_recovery: float = _recover_population(state.small_prey_population, _recovery_value(population_recovery, "small_prey_min_population", 12.0), _recovery_value(population_recovery, "small_prey_target_population", 25.0), _recovery_value(population_recovery, "small_prey_recovery_per_day", 4.0), biomass_multiplier)
	var grazer_recovery: float = _recover_population(state.grazer_population, _recovery_value(population_recovery, "grazer_min_population", 6.0), _recovery_value(population_recovery, "grazer_target_population", 14.0), _recovery_value(population_recovery, "grazer_recovery_per_day", 2.0), biomass_multiplier)
	state.small_prey_population += small_recovery
	state.grazer_population += grazer_recovery
	state.small_prey_daily_recovery = small_recovery
	state.grazer_daily_recovery = grazer_recovery
	state.small_prey_population_trend = get_population_trend(small_recovery)
	state.grazer_population_trend = get_population_trend(grazer_recovery)
	state.refresh_derived_state()
	return {"small_prey_daily_recovery": small_recovery, "grazer_daily_recovery": grazer_recovery}

static func get_biomass_recovery_multiplier(biomass_percent: float, population_recovery: Dictionary, ecosystem_balance: Dictionary = {}) -> float:
	var depleted_threshold: float = float(ecosystem_balance.get("depleted_threshold", 30.0))
	var healthy_threshold: float = float(ecosystem_balance.get("stressed_threshold", 70.0))
	var depleted_multiplier: float = _recovery_value(population_recovery, "depleted_biomass_recovery_multiplier", 0.45)
	var healthy_multiplier: float = _recovery_value(population_recovery, "healthy_biomass_recovery_multiplier", 1.25)
	if biomass_percent <= depleted_threshold:
		return depleted_multiplier
	if biomass_percent >= healthy_threshold:
		return healthy_multiplier
	var blend: float = inverse_lerp(depleted_threshold, healthy_threshold, biomass_percent)
	return lerpf(depleted_multiplier, healthy_multiplier, blend)

static func get_critical_predation_multiplier(population: float, minimum_population: float, population_recovery: Dictionary) -> float:
	return _critical_predation_multiplier(population, minimum_population, population_recovery)

static func get_population_trend(delta: float) -> String:
	if delta > 0.05:
		return "growing"
	if delta < -0.05:
		return "declining"
	return "stable"

static func _recover_population(population: float, minimum: float, target: float, per_day: float, biomass_multiplier: float) -> float:
	if population >= target:
		return 0.0
	var recovery := per_day * biomass_multiplier
	if population < minimum:
		recovery *= 1.35
	return min(recovery, target - population)

static func _critical_predation_multiplier(population: float, minimum_population: float, recovery: Dictionary) -> float:
	if population >= minimum_population:
		return 1.0
	return _recovery_value(recovery, "critical_population_predation_multiplier", 0.35)

static func _value(source: Dictionary, key: String, fallback: float) -> float:
	return float(source.get(key, fallback))

static func _recovery_value(source: Dictionary, key: String, fallback: float) -> float:
	return float(source.get(key, fallback))
