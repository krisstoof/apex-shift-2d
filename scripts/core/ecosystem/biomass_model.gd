extends RefCounted
class_name BiomassModel

static func tick_biome(state: BiomeEcosystemState, ecosystem_balance: Dictionary) -> Dictionary:
	if state == null:
		return {}
	var max_biomass: float = maxf(state.max_plant_biomass, 0.001)
	var plant_biomass: float = clamp(state.plant_biomass, 0.0, max_biomass)
	var regrowth_rate: float = state.plant_regrowth_rate
	var small_prey_consumption: float = state.small_prey_population * _value(ecosystem_balance, "small_prey_plant_consumption", 0.08)
	var grazer_consumption: float = state.grazer_population * _value(ecosystem_balance, "grazer_plant_consumption", 0.35)
	var consumption_pressure: float = small_prey_consumption + grazer_consumption
	var regrowth: float = regrowth_rate if plant_biomass < max_biomass else 0.0
	plant_biomass = clamp(plant_biomass + regrowth - consumption_pressure, 0.0, max_biomass)
	state.plant_biomass = plant_biomass
	state.plant_consumption_pressure = consumption_pressure
	state.overgrazing_pressure = consumption_pressure
	state.overgrazing_level = clamp(consumption_pressure / maxf(_value(ecosystem_balance, "overgrazing_pressure_scale", 10.0), 0.001), 0.0, 1.0)
	state.refresh_derived_state()
	state.starvation_pressure = state.food_stress
	return {
		"plant_biomass": state.plant_biomass,
		"plant_biomass_percent": state.plant_biomass_percent,
		"plant_consumption_pressure": state.plant_consumption_pressure,
		"overgrazing_level": state.overgrazing_level,
		"food_stress": state.food_stress
	}

static func apply_recovery_day(state: BiomeEcosystemState, ecosystem_balance: Dictionary, multiplier: float = 1.0) -> Dictionary:
	if state == null:
		return {}
	var max_biomass: float = maxf(state.max_plant_biomass, 0.001)
	var regrowth: float = state.plant_regrowth_rate * maxf(multiplier, 0.0)
	state.plant_biomass = clamp(state.plant_biomass + regrowth, 0.0, max_biomass)
	state.refresh_derived_state()
	return {"plant_biomass": state.plant_biomass, "plant_biomass_percent": state.plant_biomass_percent}

static func _value(source: Dictionary, key: String, fallback: float) -> float:
	return float(source.get(key, fallback))
