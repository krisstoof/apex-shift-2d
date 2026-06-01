extends Node

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")

const SIMULATION_TICK_SECONDS := 5.0
const DEFAULT_PLANT_BIOMASS := 100.0
const DEFAULT_MAX_PLANT_BIOMASS := 100.0
const DEFAULT_PLANT_REGROWTH_RATE := 1.5
const INITIAL_SMALL_PREY_POPULATION := 12.0
const INITIAL_GRAZER_POPULATION := 4.0
const SMALL_PREY_PLANT_CONSUMPTION := 0.08
const GRAZER_PLANT_CONSUMPTION := 0.35
const OVERGRAZING_PRESSURE_SCALE := 10.0
const SMALL_PREY_GROWTH_RATE := 0.75
const SMALL_PREY_PREDATION_RATE := 1.15
const SMALL_PREY_COLLAPSE_LOSS_RATE := 0.65
const GRAZER_GROWTH_RATE := 0.32
const GRAZER_STARVATION_RATE := 0.70
const GRAZER_PREDATION_RATE := 0.65
const MAX_SMALL_PREY_POPULATION := 30.0
const MAX_GRAZER_POPULATION := 14.0
const STRESSED_THRESHOLD := 70.0
const DEPLETED_THRESHOLD := 30.0
const COLLAPSING_THRESHOLD := 10.0
const GRAZER_FOOD_STRESS_THRESHOLD := 30.0
const GRAZER_NICHE_SHIFT_THRESHOLD := 0.45
const GRAZER_DIET_SHIFT_RATE := 0.04
const GRAZER_AGGRESSION_SHIFT_RATE := 0.015
const POPULATION_DECLINE_EVENT_MIN_DELTA := 0.10

var biome_states: Dictionary = {}
var tick_timer := 0.0
var initialized := false


func _ready() -> void:
	get_node("/root/EventBus").game_event.connect(_on_game_event)
	_initialize_biomes()


func _process(delta: float) -> void:
	if not initialized:
		return
	tick_timer += delta
	if tick_timer < SIMULATION_TICK_SECONDS:
		return
	tick_timer = 0.0
	_update_ecosystem_tick()


func get_biome_states() -> Dictionary:
	return biome_states.duplicate(true)


func get_biome_state(biome_id: String) -> Dictionary:
	return Dictionary(biome_states.get(biome_id, {})).duplicate(true)


func get_biome_status(biome_id: String) -> String:
	return str(get_biome_state(biome_id).get("status", "unknown"))


func get_grazer_traits(biome_id: String) -> Dictionary:
	var state := get_biome_state(biome_id)
	if state.is_empty():
		return {}
	return {
		"plant_diet": float(state.get("average_plant_diet", 0.85)),
		"meat_diet": float(state.get("average_meat_diet", 0.05)),
		"scavenger_diet": float(state.get("average_scavenger_diet", 0.10)),
		"aggression": float(state.get("average_aggression", 0.15)),
		"current_niche": str(state.get("current_niche", "HERBIVORE"))
	}


func _initialize_biomes() -> void:
	biome_states.clear()
	for biome in WORLD_CONFIG.get_biome_zones():
		var biome_id := _get_biome_id(biome)
		biome_states[biome_id] = {
			"biome_id": biome_id,
			"name": str(biome.get("name", biome_id)),
			"plant_biomass": DEFAULT_PLANT_BIOMASS,
			"plant_biomass_percent": 100.0,
			"max_plant_biomass": DEFAULT_MAX_PLANT_BIOMASS,
			"plant_regrowth_rate": DEFAULT_PLANT_REGROWTH_RATE,
			"plant_consumption_pressure": 0.0,
			"overgrazing_pressure": 0.0,
			"overgrazing_level": 0.0,
			"small_prey_population": INITIAL_SMALL_PREY_POPULATION,
			"grazer_population": INITIAL_GRAZER_POPULATION,
			"varnak_ecosystem_pressure": 0.0,
			"food_stress": 0.0,
			"average_plant_diet": 0.85,
			"average_meat_diet": 0.05,
			"average_scavenger_diet": 0.10,
			"average_aggression": 0.15,
			"current_niche": "HERBIVORE",
			"generations_under_food_stress": 0,
			"grazer_non_plant_food_events": 0,
			"predator_pressure": 0.0,
			"status": _get_biomass_status(DEFAULT_PLANT_BIOMASS, DEFAULT_MAX_PLANT_BIOMASS)
		}
	initialized = true
	print("[Ecosystem] Initialized biome states: %s" % biome_states)


func _update_ecosystem_tick() -> void:
	for biome_id in biome_states.keys():
		var state: Dictionary = biome_states[biome_id]
		var previous_status := str(state.get("status", "healthy"))
		_update_biome_biomass(state)
		_update_predator_pressure(state, biome_id)
		_update_biome_populations(state)
		state["status"] = _get_biomass_status(
			float(state.get("plant_biomass", 0.0)),
			float(state.get("max_plant_biomass", DEFAULT_MAX_PLANT_BIOMASS))
		)
		_update_grazer_niche_shift(state)
		biome_states[biome_id] = state
		_emit_status_event_if_needed(previous_status, state)
	print("[Ecosystem] Tick: %s" % biome_states)


func _update_biome_biomass(state: Dictionary) -> void:
	var max_biomass := float(state.get("max_plant_biomass", DEFAULT_MAX_PLANT_BIOMASS))
	var plant_biomass := float(state.get("plant_biomass", DEFAULT_PLANT_BIOMASS))
	var regrowth_rate := float(state.get("plant_regrowth_rate", DEFAULT_PLANT_REGROWTH_RATE))
	var small_prey_population := float(state.get("small_prey_population", 0.0))
	var grazer_population := float(state.get("grazer_population", 0.0))
	var consumption_pressure := (
		small_prey_population * SMALL_PREY_PLANT_CONSUMPTION
		+ grazer_population * GRAZER_PLANT_CONSUMPTION
	)
	var regrowth := regrowth_rate if plant_biomass < max_biomass else 0.0
	plant_biomass = clamp(plant_biomass + regrowth - consumption_pressure, 0.0, max_biomass)
	state["plant_biomass"] = plant_biomass
	state["plant_biomass_percent"] = _get_state_biomass_percent(state)
	state["plant_consumption_pressure"] = consumption_pressure
	state["overgrazing_pressure"] = consumption_pressure
	state["overgrazing_level"] = clamp(consumption_pressure / OVERGRAZING_PRESSURE_SCALE, 0.0, 1.0)
	state["food_stress"] = 1.0 - clamp(plant_biomass / max_biomass, 0.0, 1.0)


func _update_predator_pressure(state: Dictionary, biome_id: String) -> void:
	var varnak_count := 0
	var total_varnaks := 0
	for varnak in get_tree().get_nodes_in_group("varnak"):
		if not is_instance_valid(varnak):
			continue
		total_varnaks += 1
		if _get_biome_id_for_position(varnak.global_position) == biome_id:
			varnak_count += 1
	if total_varnaks <= 0:
		state["varnak_ecosystem_pressure"] = 0.0
		state["predator_pressure"] = 0.0
		return
	var pressure: float = clamp(float(varnak_count) / float(total_varnaks), 0.0, 1.0)
	state["varnak_ecosystem_pressure"] = pressure
	state["predator_pressure"] = pressure


func _update_biome_populations(state: Dictionary) -> void:
	var biomass_factor: float = clamp(float(state.get("plant_biomass_percent", 0.0)) / 100.0, 0.0, 1.0)
	var predator_pressure := float(state.get("varnak_ecosystem_pressure", 0.0))
	var food_stress := float(state.get("food_stress", 0.0))
	var small_prey_population := float(state.get("small_prey_population", 0.0))
	var grazer_population := float(state.get("grazer_population", 0.0))
	var omnivore_resilience := float(state.get("average_meat_diet", 0.05)) + float(state.get("average_scavenger_diet", 0.10))
	var small_prey_delta: float = biomass_factor * SMALL_PREY_GROWTH_RATE
	small_prey_delta -= predator_pressure * SMALL_PREY_PREDATION_RATE
	if biomass_factor < 0.12:
		small_prey_delta -= SMALL_PREY_COLLAPSE_LOSS_RATE
	var grazer_delta: float = biomass_factor * GRAZER_GROWTH_RATE
	grazer_delta -= food_stress * GRAZER_STARVATION_RATE * (1.0 - clamp(omnivore_resilience, 0.0, 0.85))
	grazer_delta -= predator_pressure * GRAZER_PREDATION_RATE
	state["small_prey_population"] = clamp(small_prey_population + small_prey_delta, 0.0, MAX_SMALL_PREY_POPULATION)
	state["grazer_population"] = clamp(grazer_population + grazer_delta, 0.0, MAX_GRAZER_POPULATION)
	_emit_population_decline_events_if_needed(state, small_prey_population, grazer_population)


func _get_state_biomass_percent(state: Dictionary) -> float:
	var max_biomass := float(state.get("max_plant_biomass", DEFAULT_MAX_PLANT_BIOMASS))
	if max_biomass <= 0.0:
		return 0.0
	return float(state.get("plant_biomass", 0.0)) / max_biomass * 100.0


func _emit_status_event_if_needed(previous_status: String, state: Dictionary) -> void:
	var status := str(state.get("status", "healthy"))
	if status == previous_status or status == "healthy":
		return
	var event_name := ""
	match status:
		"stressed":
			event_name = "ecosystem_biome_stressed"
		"depleted":
			event_name = "ecosystem_biome_depleted"
		"collapsing":
			event_name = "ecosystem_biome_collapsing"
	if event_name.is_empty():
		return
	get_node("/root/EventBus").emit_game_event(event_name, state.duplicate(true))


func _emit_population_decline_events_if_needed(state: Dictionary, previous_small_prey: float, previous_grazers: float) -> void:
	var current_small_prey := float(state.get("small_prey_population", 0.0))
	var current_grazers := float(state.get("grazer_population", 0.0))
	if previous_small_prey - current_small_prey >= POPULATION_DECLINE_EVENT_MIN_DELTA:
		var payload := state.duplicate(true)
		payload["previous_population"] = previous_small_prey
		payload["current_population"] = current_small_prey
		get_node("/root/EventBus").emit_game_event("small_prey_population_declining", payload)
	if previous_grazers - current_grazers >= POPULATION_DECLINE_EVENT_MIN_DELTA:
		var payload := state.duplicate(true)
		payload["previous_population"] = previous_grazers
		payload["current_population"] = current_grazers
		get_node("/root/EventBus").emit_game_event("grazer_population_declining", payload)


func _on_game_event(event_name: String, payload: Dictionary) -> void:
	match event_name:
		"small_prey_killed_by_player", "small_prey_killed_by_varnak", "small_prey_killed_by_grazer":
			_apply_small_prey_death(payload)
		"small_prey_consumed_plants":
			_apply_visible_plant_consumption(payload)
		"grazer_killed_by_player", "grazer_killed_by_varnak":
			_apply_grazer_death(payload)
		"grazer_consumed_plants":
			_apply_visible_plant_consumption(payload)
		"grazer_scavenged", "grazer_hunted_small_prey":
			_record_grazer_non_plant_food(payload)
		"plant_resource_harvested":
			_apply_harvested_plant_pressure(payload)


func _apply_small_prey_death(payload: Dictionary) -> void:
	var biome_id := str(payload.get("biome_id", ""))
	if not biome_states.has(biome_id):
		return
	var state: Dictionary = biome_states[biome_id]
	state["small_prey_population"] = max(float(state.get("small_prey_population", 0.0)) - 1.0, 0.0)
	biome_states[biome_id] = state


func _apply_grazer_death(payload: Dictionary) -> void:
	var biome_id := str(payload.get("biome_id", ""))
	if not biome_states.has(biome_id):
		return
	var state: Dictionary = biome_states[biome_id]
	state["grazer_population"] = max(float(state.get("grazer_population", 0.0)) - 1.0, 0.0)
	biome_states[biome_id] = state


func _record_grazer_non_plant_food(payload: Dictionary) -> void:
	var biome_id := str(payload.get("biome_id", ""))
	if not biome_states.has(biome_id):
		return
	var state: Dictionary = biome_states[biome_id]
	state["grazer_non_plant_food_events"] = int(state.get("grazer_non_plant_food_events", 0)) + 1
	biome_states[biome_id] = state


func _update_grazer_niche_shift(state: Dictionary) -> void:
	var biomass_percent := float(state.get("plant_biomass_percent", 100.0))
	var grazer_population := float(state.get("grazer_population", 0.0))
	var small_prey_population := float(state.get("small_prey_population", 0.0))
	var non_plant_food_events := int(state.get("grazer_non_plant_food_events", 0))
	var under_stress := (
		biomass_percent < GRAZER_FOOD_STRESS_THRESHOLD
		and grazer_population > 0.0
		and small_prey_population > 0.0
	)
	if not under_stress:
		state["generations_under_food_stress"] = 0
		state["grazer_non_plant_food_events"] = 0
		return
	state["generations_under_food_stress"] = int(state.get("generations_under_food_stress", 0)) + 1
	if non_plant_food_events <= 0:
		return
	state["average_plant_diet"] = clamp(float(state.get("average_plant_diet", 0.85)) - GRAZER_DIET_SHIFT_RATE, 0.0, 1.0)
	state["average_meat_diet"] = clamp(float(state.get("average_meat_diet", 0.05)) + GRAZER_DIET_SHIFT_RATE * 0.65, 0.0, 1.0)
	state["average_scavenger_diet"] = clamp(float(state.get("average_scavenger_diet", 0.10)) + GRAZER_DIET_SHIFT_RATE * 0.35, 0.0, 1.0)
	state["average_aggression"] = clamp(float(state.get("average_aggression", 0.15)) + GRAZER_AGGRESSION_SHIFT_RATE, 0.0, 1.0)
	state["grazer_non_plant_food_events"] = 0
	_update_grazer_niche_status(state)


func _update_grazer_niche_status(state: Dictionary) -> void:
	var current_niche := str(state.get("current_niche", "HERBIVORE"))
	if current_niche != "HERBIVORE":
		return
	var non_plant_diet := float(state.get("average_meat_diet", 0.0)) + float(state.get("average_scavenger_diet", 0.0))
	if non_plant_diet <= GRAZER_NICHE_SHIFT_THRESHOLD:
		return
	state["current_niche"] = "OMNIVORE"
	get_node("/root/EventBus").emit_game_event("grazer_niche_shifted", {
		"biome_id": str(state.get("biome_id", "")),
		"old_niche": current_niche,
		"new_niche": "OMNIVORE",
		"average_plant_diet": float(state.get("average_plant_diet", 0.0)),
		"average_meat_diet": float(state.get("average_meat_diet", 0.0)),
		"average_scavenger_diet": float(state.get("average_scavenger_diet", 0.0)),
		"average_aggression": float(state.get("average_aggression", 0.0))
	})


func _apply_visible_plant_consumption(payload: Dictionary) -> void:
	var biome_id := str(payload.get("biome_id", ""))
	var consumption := float(payload.get("plant_consumption_rate", 0.0))
	_apply_plant_biomass_loss(biome_id, consumption)


func _apply_harvested_plant_pressure(payload: Dictionary) -> void:
	var biome_id := str(payload.get("biome_id", ""))
	var biomass_impact := float(payload.get("biomass_impact", 0.0))
	_apply_plant_biomass_loss(biome_id, biomass_impact)


func _apply_plant_biomass_loss(biome_id: String, biomass_loss: float) -> void:
	if not biome_states.has(biome_id) or biomass_loss <= 0.0:
		return
	var state: Dictionary = biome_states[biome_id]
	var previous_status := str(state.get("status", "healthy"))
	var plant_biomass := float(state.get("plant_biomass", 0.0))
	state["plant_biomass"] = max(plant_biomass - biomass_loss, 0.0)
	state["plant_biomass_percent"] = _get_state_biomass_percent(state)
	var max_biomass := float(state.get("max_plant_biomass", DEFAULT_MAX_PLANT_BIOMASS))
	state["food_stress"] = 1.0 if max_biomass <= 0.0 else 1.0 - clamp(float(state.get("plant_biomass", 0.0)) / max_biomass, 0.0, 1.0)
	state["status"] = _get_biomass_status(
		float(state.get("plant_biomass", 0.0)),
		max_biomass
	)
	biome_states[biome_id] = state
	_emit_status_event_if_needed(previous_status, state)


func _get_biomass_status(plant_biomass: float, max_plant_biomass: float) -> String:
	var percent := 0.0 if max_plant_biomass <= 0.0 else plant_biomass / max_plant_biomass * 100.0
	if percent < COLLAPSING_THRESHOLD:
		return "collapsing"
	if percent < DEPLETED_THRESHOLD:
		return "depleted"
	if percent < STRESSED_THRESHOLD:
		return "stressed"
	return "healthy"


func _get_biome_id(biome: Dictionary) -> String:
	return str(biome.get("name", "biome")).to_snake_case()


func _get_biome_id_for_position(position: Vector2) -> String:
	for biome in WORLD_CONFIG.get_biome_zones():
		if Geometry2D.is_point_in_polygon(position, PackedVector2Array(biome["points"])):
			return _get_biome_id(biome)
	return ""
