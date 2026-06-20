extends RefCounted
class_name BiomeEcosystemState

const STATUS_HEALTHY := "healthy"
const STATUS_STRESSED := "stressed"
const STATUS_DEPLETED := "depleted"
const STATUS_COLLAPSING := "collapsing"

var biome_id := ""
var name := ""
var plant_biomass := 100.0
var plant_biomass_percent := 100.0
var max_plant_biomass := 100.0
var plant_regrowth_rate := 1.5
var plant_consumption_pressure := 0.0
var overgrazing_pressure := 0.0
var overgrazing_level := 0.0
var small_prey_population := 0.0
var grazer_population := 0.0
var varnak_population := 0.0
var population_count := 0.0
var average_hunger := 0.0
var average_energy := 1.0
var small_prey_generation := 1
var small_prey_pressure_ticks := 0
var average_small_prey_fear := 0.90
var average_small_prey_speed := 90.0
var average_small_prey_reproduction := 0.60
var average_small_prey_fitness := 0.0
var grazer_generation := 1
var grazer_pressure_ticks := 0
var average_grazer_reproduction := 0.35
var average_grazer_fitness := 0.0
var average_varnak_hunger := 0.0
var average_varnak_energy := 1.0
var average_varnak_fitness := 0.0
var average_varnak_meat_diet := 1.0
var average_varnak_scavenger_diet := 0.45
var average_varnak_hunt_drive := 0.0
var varnak_generation := 1
var varnak_ecosystem_pressure := 0.0
var predator_pressure := 0.0
var food_stress := 0.0
var starvation_pressure := 0.0
var average_plant_diet := 0.85
var average_meat_diet := 0.05
var average_scavenger_diet := 0.10
var average_aggression := 0.15
var birth_rate := 0.0
var death_rate := 0.0
var small_prey_daily_recovery := 0.0
var grazer_daily_recovery := 0.0
var small_prey_predation_pressure := 0.0
var grazer_predation_pressure := 0.0
var grazer_starvation_pressure := 0.0
var small_prey_population_trend := "stable"
var grazer_population_trend := "stable"
var status := STATUS_HEALTHY
var current_niche := "HERBIVORE"
var generations_under_food_stress := 0
var grazer_non_plant_food_events := 0

func load_from_dictionary(data: Dictionary) -> void:
	biome_id = str(data.get("biome_id", biome_id))
	name = str(data.get("name", name if not name.is_empty() else biome_id))
	plant_biomass = float(data.get("plant_biomass", plant_biomass))
	max_plant_biomass = maxf(float(data.get("max_plant_biomass", max_plant_biomass)), 0.001)
	plant_biomass_percent = float(data.get("plant_biomass_percent", get_biomass_percent()))
	plant_regrowth_rate = float(data.get("plant_regrowth_rate", plant_regrowth_rate))
	plant_consumption_pressure = float(data.get("plant_consumption_pressure", plant_consumption_pressure))
	overgrazing_pressure = float(data.get("overgrazing_pressure", overgrazing_pressure))
	overgrazing_level = float(data.get("overgrazing_level", overgrazing_level))
	small_prey_population = float(data.get("small_prey_population", small_prey_population))
	grazer_population = float(data.get("grazer_population", grazer_population))
	varnak_population = float(data.get("varnak_population", varnak_population))
	population_count = float(data.get("population_count", small_prey_population + grazer_population + varnak_population))
	average_hunger = float(data.get("average_hunger", average_hunger))
	average_energy = float(data.get("average_energy", average_energy))
	small_prey_generation = int(data.get("small_prey_generation", small_prey_generation))
	small_prey_pressure_ticks = int(data.get("small_prey_pressure_ticks", small_prey_pressure_ticks))
	average_small_prey_fear = float(data.get("average_small_prey_fear", average_small_prey_fear))
	average_small_prey_speed = float(data.get("average_small_prey_speed", average_small_prey_speed))
	average_small_prey_reproduction = float(data.get("average_small_prey_reproduction", average_small_prey_reproduction))
	average_small_prey_fitness = float(data.get("average_small_prey_fitness", average_small_prey_fitness))
	grazer_generation = int(data.get("grazer_generation", grazer_generation))
	grazer_pressure_ticks = int(data.get("grazer_pressure_ticks", grazer_pressure_ticks))
	average_grazer_reproduction = float(data.get("average_grazer_reproduction", average_grazer_reproduction))
	average_grazer_fitness = float(data.get("average_grazer_fitness", average_grazer_fitness))
	average_varnak_hunger = float(data.get("average_varnak_hunger", average_varnak_hunger))
	average_varnak_energy = float(data.get("average_varnak_energy", average_varnak_energy))
	average_varnak_fitness = float(data.get("average_varnak_fitness", average_varnak_fitness))
	average_varnak_meat_diet = float(data.get("average_varnak_meat_diet", average_varnak_meat_diet))
	average_varnak_scavenger_diet = float(data.get("average_varnak_scavenger_diet", average_varnak_scavenger_diet))
	average_varnak_hunt_drive = float(data.get("average_varnak_hunt_drive", average_varnak_hunt_drive))
	varnak_generation = int(data.get("varnak_generation", varnak_generation))
	varnak_ecosystem_pressure = float(data.get("varnak_ecosystem_pressure", data.get("predator_pressure", varnak_ecosystem_pressure)))
	predator_pressure = float(data.get("predator_pressure", varnak_ecosystem_pressure))
	food_stress = float(data.get("food_stress", food_stress))
	starvation_pressure = float(data.get("starvation_pressure", starvation_pressure))
	average_plant_diet = float(data.get("average_plant_diet", average_plant_diet))
	average_meat_diet = float(data.get("average_meat_diet", average_meat_diet))
	average_scavenger_diet = float(data.get("average_scavenger_diet", average_scavenger_diet))
	average_aggression = float(data.get("average_aggression", average_aggression))
	birth_rate = float(data.get("birth_rate", birth_rate))
	death_rate = float(data.get("death_rate", death_rate))
	small_prey_daily_recovery = float(data.get("small_prey_daily_recovery", small_prey_daily_recovery))
	grazer_daily_recovery = float(data.get("grazer_daily_recovery", grazer_daily_recovery))
	small_prey_predation_pressure = float(data.get("small_prey_predation_pressure", small_prey_predation_pressure))
	grazer_predation_pressure = float(data.get("grazer_predation_pressure", grazer_predation_pressure))
	grazer_starvation_pressure = float(data.get("grazer_starvation_pressure", grazer_starvation_pressure))
	small_prey_population_trend = str(data.get("small_prey_population_trend", small_prey_population_trend))
	grazer_population_trend = str(data.get("grazer_population_trend", grazer_population_trend))
	current_niche = str(data.get("current_niche", current_niche))
	generations_under_food_stress = int(data.get("generations_under_food_stress", generations_under_food_stress))
	grazer_non_plant_food_events = int(data.get("grazer_non_plant_food_events", grazer_non_plant_food_events))
	status = str(data.get("status", status))
	refresh_derived_state()

func to_dictionary() -> Dictionary:
	return {
		"biome_id": biome_id,
		"name": name,
		"plant_biomass": plant_biomass,
		"plant_biomass_percent": plant_biomass_percent,
		"max_plant_biomass": max_plant_biomass,
		"plant_regrowth_rate": plant_regrowth_rate,
		"plant_consumption_pressure": plant_consumption_pressure,
		"overgrazing_pressure": overgrazing_pressure,
		"overgrazing_level": overgrazing_level,
		"small_prey_population": small_prey_population,
		"grazer_population": grazer_population,
		"varnak_population": varnak_population,
		"population_count": population_count,
		"average_hunger": average_hunger,
		"average_energy": average_energy,
		"small_prey_generation": small_prey_generation,
		"small_prey_pressure_ticks": small_prey_pressure_ticks,
		"average_small_prey_fear": average_small_prey_fear,
		"average_small_prey_speed": average_small_prey_speed,
		"average_small_prey_reproduction": average_small_prey_reproduction,
		"average_small_prey_fitness": average_small_prey_fitness,
		"grazer_generation": grazer_generation,
		"grazer_pressure_ticks": grazer_pressure_ticks,
		"average_grazer_reproduction": average_grazer_reproduction,
		"average_grazer_fitness": average_grazer_fitness,
		"average_varnak_hunger": average_varnak_hunger,
		"average_varnak_energy": average_varnak_energy,
		"average_varnak_fitness": average_varnak_fitness,
		"average_varnak_meat_diet": average_varnak_meat_diet,
		"average_varnak_scavenger_diet": average_varnak_scavenger_diet,
		"average_varnak_hunt_drive": average_varnak_hunt_drive,
		"varnak_generation": varnak_generation,
		"varnak_ecosystem_pressure": varnak_ecosystem_pressure,
		"predator_pressure": predator_pressure,
		"food_stress": food_stress,
		"starvation_pressure": starvation_pressure,
		"average_plant_diet": average_plant_diet,
		"average_meat_diet": average_meat_diet,
		"average_scavenger_diet": average_scavenger_diet,
		"average_aggression": average_aggression,
		"birth_rate": birth_rate,
		"death_rate": death_rate,
		"small_prey_daily_recovery": small_prey_daily_recovery,
		"grazer_daily_recovery": grazer_daily_recovery,
		"small_prey_predation_pressure": small_prey_predation_pressure,
		"grazer_predation_pressure": grazer_predation_pressure,
		"grazer_starvation_pressure": grazer_starvation_pressure,
		"small_prey_population_trend": small_prey_population_trend,
		"grazer_population_trend": grazer_population_trend,
		"current_niche": current_niche,
		"generations_under_food_stress": generations_under_food_stress,
		"grazer_non_plant_food_events": grazer_non_plant_food_events,
		"status": status
	}

func duplicate_state() -> BiomeEcosystemState:
	var copy: BiomeEcosystemState = BiomeEcosystemState.new()
	copy.load_from_dictionary(to_dictionary())
	return copy

func refresh_derived_state() -> void:
	plant_biomass = clamp(plant_biomass, 0.0, max_plant_biomass)
	plant_biomass_percent = get_biomass_percent()
	food_stress = 1.0 - clamp(plant_biomass / max_plant_biomass, 0.0, 1.0)
	population_count = small_prey_population + grazer_population + varnak_population
	status = get_biomass_status()

func get_biomass_percent() -> float:
	if max_plant_biomass <= 0.0:
		return 0.0
	return clamp(plant_biomass / max_plant_biomass * 100.0, 0.0, 100.0)

func get_biomass_status() -> String:
	if plant_biomass_percent <= 10.0:
		return STATUS_COLLAPSING
	if plant_biomass_percent <= 30.0:
		return STATUS_DEPLETED
	if plant_biomass_percent <= 70.0:
		return STATUS_STRESSED
	return STATUS_HEALTHY

static func from_dictionary(data: Dictionary) -> BiomeEcosystemState:
	var state: BiomeEcosystemState = BiomeEcosystemState.new()
	state.load_from_dictionary(data)
	return state
