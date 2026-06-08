extends Node

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const ECOSYSTEM_COMMAND := preload("res://scripts/systems/ecosystem_command.gd")
const ECOSYSTEM_DELTA := preload("res://scripts/systems/ecosystem_delta.gd")

var biome_states: Dictionary = {}
var tick_timer := 0.0
var initialized := false
var pending_tick_biome_ids: Array[String] = []


func _ecosystem_value(key: String) -> float:
	return float(GAME_BALANCE.ECOSYSTEM[key])


func _population_recovery_value(key: String) -> float:
	return float(GAME_BALANCE.POPULATION_RECOVERY[key])


func _ready() -> void:
	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_signal("game_event"):
		event_bus.game_event.connect(_on_game_event)
	_initialize_biomes()


func _process(delta: float) -> void:
	if not initialized:
		return
	tick_timer += delta
	if not pending_tick_biome_ids.is_empty():
		_process_next_runtime_biome()
		return
	if tick_timer < _ecosystem_value("simulation_tick_seconds"):
		return
	tick_timer = 0.0
	_begin_runtime_ecosystem_tick()
	_process_next_runtime_biome()


func get_biome_states() -> Dictionary:
	return biome_states.duplicate(true)


func get_biome_state(biome_id: String) -> Dictionary:
	return Dictionary(biome_states.get(biome_id, {})).duplicate(true)


func get_save_data() -> Dictionary:
	return {
		"biome_states": biome_states.duplicate(true),
		"tick_timer": tick_timer
	}


func load_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	pending_tick_biome_ids.clear()
	var saved_states = data.get("biome_states", {})
	if typeof(saved_states) == TYPE_DICTIONARY:
		_restore_biome_states(Dictionary(saved_states))
	tick_timer = clamp(float(data.get("tick_timer", tick_timer)), 0.0, _ecosystem_value("simulation_tick_seconds"))
	initialized = true


func get_biome_status(biome_id: String) -> String:
	return str(get_biome_state(biome_id).get("status", "unknown"))


func get_small_prey_traits(biome_id: String) -> Dictionary:
	var state := get_biome_state(biome_id)
	if state.is_empty():
		return {}
	return {
		"biome_id": biome_id,
		"generation": int(state.get("small_prey_generation", 1)),
		"fear": float(state.get("average_small_prey_fear", _ecosystem_value("initial_small_prey_fear"))),
		"speed": float(state.get("average_small_prey_speed", _ecosystem_value("initial_small_prey_speed"))),
		"reproduction_value": float(state.get("average_small_prey_reproduction", _ecosystem_value("initial_small_prey_reproduction"))),
		"plant_diet": 1.0
	}


func get_grazer_traits(biome_id: String) -> Dictionary:
	var state := get_biome_state(biome_id)
	if state.is_empty():
		return {}
	return {
		"biome_id": biome_id,
		"generation": int(state.get("grazer_generation", 1)),
		"plant_diet": float(state.get("average_plant_diet", _ecosystem_value("initial_average_plant_diet"))),
		"meat_diet": float(state.get("average_meat_diet", _ecosystem_value("initial_average_meat_diet"))),
		"scavenger_diet": float(state.get("average_scavenger_diet", _ecosystem_value("initial_average_scavenger_diet"))),
		"aggression": float(state.get("average_aggression", _ecosystem_value("initial_average_aggression"))),
		"reproduction_rate": float(state.get("average_grazer_reproduction", _ecosystem_value("initial_grazer_reproduction"))),
		"current_niche": str(state.get("current_niche", "HERBIVORE"))
	}


func debug_reduce_plant_biomass(position: Vector2) -> void:
	var biome_id := _get_debug_biome_id(position)
	if not biome_states.has(biome_id):
		return
	_debug_set_plant_biomass(
		biome_id,
		float(biome_states[biome_id].get("plant_biomass", 0.0)) - _ecosystem_value("debug_plant_biomass_delta")
	)
	_post_debug_message("Reduced plant biomass", biome_id)


func debug_restore_plant_biomass(position: Vector2) -> void:
	var biome_id := _get_debug_biome_id(position)
	if not biome_states.has(biome_id):
		return
	_debug_set_plant_biomass(biome_id, float(biome_states[biome_id].get("max_plant_biomass", _ecosystem_value("max_plant_biomass"))))
	_post_debug_message("Restored plant biomass", biome_id)


func debug_add_small_prey(position: Vector2) -> void:
	_debug_adjust_population(position, "small_prey_population", _ecosystem_value("debug_small_prey_population_delta"), _ecosystem_value("max_small_prey_population"), "Added SmallPrey")


func debug_remove_small_prey(position: Vector2) -> void:
	_debug_adjust_population(position, "small_prey_population", -_ecosystem_value("debug_small_prey_population_delta"), _ecosystem_value("max_small_prey_population"), "Removed SmallPrey")


func debug_add_grazers(position: Vector2) -> void:
	_debug_adjust_population(position, "grazer_population", _ecosystem_value("debug_grazer_population_delta"), _ecosystem_value("max_grazer_population"), "Added Grazers")


func debug_remove_grazers(position: Vector2) -> void:
	_debug_adjust_population(position, "grazer_population", -_ecosystem_value("debug_grazer_population_delta"), _ecosystem_value("max_grazer_population"), "Removed Grazers")


func debug_force_grazer_food_stress(position: Vector2) -> void:
	var biome_id := _get_debug_biome_id(position)
	if not biome_states.has(biome_id):
		return
	var state: Dictionary = biome_states[biome_id]
	var max_biomass := float(state.get("max_plant_biomass", _ecosystem_value("max_plant_biomass")))
	var stress_percent: float = max(_ecosystem_value("grazer_food_stress_threshold") - _ecosystem_value("debug_forced_food_stress_margin"), 0.0)
	_debug_set_plant_biomass(biome_id, max_biomass * stress_percent / 100.0)
	_post_debug_message("Forced grazer food stress", biome_id)


func debug_force_grazer_niche_shift_check(position: Vector2) -> void:
	var biome_id := _get_debug_biome_id(position)
	if not biome_states.has(biome_id):
		return
	var state: Dictionary = biome_states[biome_id]
	var max_biomass := float(state.get("max_plant_biomass", _ecosystem_value("max_plant_biomass")))
	var stress_percent: float = max(_ecosystem_value("grazer_food_stress_threshold") - _ecosystem_value("debug_forced_food_stress_margin"), 0.0)
	state["plant_biomass"] = max_biomass * stress_percent / 100.0
	state["small_prey_population"] = max(float(state.get("small_prey_population", 0.0)), _ecosystem_value("debug_min_population_floor"))
	state["grazer_population"] = max(float(state.get("grazer_population", 0.0)), _ecosystem_value("debug_min_population_floor"))
	state["average_plant_diet"] = min(float(state.get("average_plant_diet", _ecosystem_value("initial_average_plant_diet"))), _ecosystem_value("debug_forced_niche_plant_diet"))
	state["average_meat_diet"] = max(float(state.get("average_meat_diet", _ecosystem_value("initial_average_meat_diet"))), _ecosystem_value("debug_forced_niche_meat_diet"))
	state["average_scavenger_diet"] = max(float(state.get("average_scavenger_diet", _ecosystem_value("initial_average_scavenger_diet"))), _ecosystem_value("debug_forced_niche_scavenger_diet"))
	state["grazer_non_plant_food_events"] = int(state.get("grazer_non_plant_food_events", 0)) + 1
	_refresh_biome_derived_state(state)
	_update_grazer_niche_shift(state)
	biome_states[biome_id] = state
	_emit_vegetation_changed(state)
	_post_debug_message("Forced grazer niche shift check", biome_id)


func debug_advance_ecosystem_tick() -> void:
	_update_ecosystem_tick()
	tick_timer = 0.0
	var event_bus := _get_event_bus()
	if event_bus:
		event_bus.post_message("Debug advanced ecosystem tick")


func _initialize_biomes() -> void:
	biome_states.clear()
	pending_tick_biome_ids.clear()
	var default_plant_biomass := _ecosystem_value("default_plant_biomass")
	var max_plant_biomass := _ecosystem_value("max_plant_biomass")
	for biome in WORLD_CONFIG.get_biome_zones():
		var biome_id := _get_biome_id(biome)
		biome_states[biome_id] = {
			"biome_id": biome_id,
			"name": str(biome.get("name", biome_id)),
			"plant_biomass": default_plant_biomass,
			"plant_biomass_percent": 100.0,
			"max_plant_biomass": max_plant_biomass,
			"plant_regrowth_rate": _ecosystem_value("plant_regrowth_rate"),
			"plant_consumption_pressure": 0.0,
			"overgrazing_pressure": 0.0,
			"overgrazing_level": 0.0,
			"small_prey_population": _ecosystem_value("initial_small_prey_population"),
			"grazer_population": _ecosystem_value("initial_grazer_population"),
			"varnak_population": 0.0,
			"population_count": _ecosystem_value("initial_small_prey_population") + _ecosystem_value("initial_grazer_population"),
			"average_hunger": 0.0,
			"average_energy": 1.0,
			"small_prey_generation": 1,
			"small_prey_pressure_ticks": 0,
			"average_small_prey_fear": _ecosystem_value("initial_small_prey_fear"),
			"average_small_prey_speed": _ecosystem_value("initial_small_prey_speed"),
			"average_small_prey_reproduction": _ecosystem_value("initial_small_prey_reproduction"),
			"average_small_prey_fitness": 0.0,
			"average_varnak_hunger": 0.0,
			"average_varnak_energy": 1.0,
			"average_varnak_fitness": 0.0,
			"average_varnak_meat_diet": 1.0,
			"average_varnak_scavenger_diet": 0.45,
			"average_varnak_hunt_drive": 0.0,
			"varnak_generation": 1,
			"varnak_ecosystem_pressure": 0.0,
			"food_stress": 0.0,
			"starvation_pressure": 0.0,
			"average_plant_diet": _ecosystem_value("initial_average_plant_diet"),
			"average_meat_diet": _ecosystem_value("initial_average_meat_diet"),
			"average_scavenger_diet": _ecosystem_value("initial_average_scavenger_diet"),
			"average_aggression": _ecosystem_value("initial_average_aggression"),
			"grazer_generation": 1,
			"grazer_pressure_ticks": 0,
			"average_grazer_reproduction": _ecosystem_value("initial_grazer_reproduction"),
			"average_grazer_fitness": 0.0,
			"birth_rate": 0.0,
			"death_rate": 0.0,
			"small_prey_daily_recovery": 0.0,
			"grazer_daily_recovery": 0.0,
			"small_prey_predation_pressure": 0.0,
			"grazer_predation_pressure": 0.0,
			"grazer_starvation_pressure": 0.0,
			"small_prey_population_trend": "stable",
			"grazer_population_trend": "stable",
			"current_niche": "HERBIVORE",
			"generations_under_food_stress": 0,
			"grazer_non_plant_food_events": 0,
			"predator_pressure": 0.0,
			"status": _get_biomass_status(default_plant_biomass, max_plant_biomass)
	}
	initialized = true


func _restore_biome_states(saved_states: Dictionary) -> void:
	for biome_id in biome_states.keys():
		if not saved_states.has(biome_id) or typeof(saved_states[biome_id]) != TYPE_DICTIONARY:
			continue
		var state: Dictionary = biome_states[biome_id]
		var saved_state := Dictionary(saved_states[biome_id])
		for key in saved_state.keys():
			state[key] = saved_state[key]
		state["biome_id"] = biome_id
		_ensure_biome_state_defaults(state)
		state["plant_biomass_percent"] = _get_state_biomass_percent(state)
		state["status"] = _get_biomass_status(
			float(state.get("plant_biomass", 0.0)),
			float(state.get("max_plant_biomass", _ecosystem_value("max_plant_biomass")))
		)
		var max_biomass := float(state.get("max_plant_biomass", _ecosystem_value("max_plant_biomass")))
		state["food_stress"] = 1.0 if max_biomass <= 0.0 else 1.0 - clamp(float(state.get("plant_biomass", 0.0)) / max_biomass, 0.0, 1.0)
		biome_states[biome_id] = state


func _ensure_biome_state_defaults(state: Dictionary) -> void:
	state["small_prey_generation"] = int(state.get("small_prey_generation", 1))
	state["small_prey_pressure_ticks"] = int(state.get("small_prey_pressure_ticks", 0))
	state["average_small_prey_fear"] = float(state.get("average_small_prey_fear", _ecosystem_value("initial_small_prey_fear")))
	state["average_small_prey_speed"] = float(state.get("average_small_prey_speed", _ecosystem_value("initial_small_prey_speed")))
	state["average_small_prey_reproduction"] = float(state.get("average_small_prey_reproduction", _ecosystem_value("initial_small_prey_reproduction")))
	state["average_small_prey_fitness"] = float(state.get("average_small_prey_fitness", 0.0))
	state["grazer_generation"] = int(state.get("grazer_generation", 1))
	state["grazer_pressure_ticks"] = int(state.get("grazer_pressure_ticks", 0))
	state["average_grazer_reproduction"] = float(state.get("average_grazer_reproduction", _ecosystem_value("initial_grazer_reproduction")))
	state["average_grazer_fitness"] = float(state.get("average_grazer_fitness", 0.0))
	state["varnak_population"] = float(state.get("varnak_population", 0.0))
	state["average_varnak_hunger"] = float(state.get("average_varnak_hunger", 0.0))
	state["average_varnak_energy"] = float(state.get("average_varnak_energy", 1.0))
	state["average_varnak_fitness"] = float(state.get("average_varnak_fitness", 0.0))
	state["average_varnak_meat_diet"] = float(state.get("average_varnak_meat_diet", 1.0))
	state["average_varnak_scavenger_diet"] = float(state.get("average_varnak_scavenger_diet", 0.45))
	state["average_varnak_hunt_drive"] = float(state.get("average_varnak_hunt_drive", 0.0))
	state["varnak_generation"] = int(state.get("varnak_generation", 1))
	state["small_prey_daily_recovery"] = float(state.get("small_prey_daily_recovery", 0.0))
	state["grazer_daily_recovery"] = float(state.get("grazer_daily_recovery", 0.0))
	state["small_prey_predation_pressure"] = float(state.get("small_prey_predation_pressure", 0.0))
	state["grazer_predation_pressure"] = float(state.get("grazer_predation_pressure", 0.0))
	state["grazer_starvation_pressure"] = float(state.get("grazer_starvation_pressure", 0.0))
	state["small_prey_population_trend"] = str(state.get("small_prey_population_trend", "stable"))
	state["grazer_population_trend"] = str(state.get("grazer_population_trend", "stable"))


func _get_debug_biome_id(position: Vector2) -> String:
	var biome_id := _get_biome_id_for_position(position)
	if not biome_id.is_empty() and biome_states.has(biome_id):
		return biome_id
	var biome_ids := biome_states.keys()
	biome_ids.sort()
	return str(biome_ids[0]) if not biome_ids.is_empty() else ""


func _debug_set_plant_biomass(biome_id: String, plant_biomass: float) -> void:
	if not biome_states.has(biome_id):
		return
	var state: Dictionary = biome_states[biome_id]
	var previous_status := str(state.get("status", "healthy"))
	var max_biomass := float(state.get("max_plant_biomass", _ecosystem_value("max_plant_biomass")))
	state["plant_biomass"] = clamp(plant_biomass, 0.0, max_biomass)
	_refresh_biome_derived_state(state)
	biome_states[biome_id] = state
	_emit_vegetation_changed(state)
	_emit_status_event_if_needed(previous_status, state)


func _debug_adjust_population(position: Vector2, key: String, delta: float, max_population: float, message: String) -> void:
	var biome_id := _get_debug_biome_id(position)
	if not biome_states.has(biome_id):
		return
	var state: Dictionary = biome_states[biome_id]
	state[key] = clamp(float(state.get(key, 0.0)) + delta, 0.0, max_population)
	biome_states[biome_id] = state
	_post_debug_message(message, biome_id)


func _refresh_biome_derived_state(state: Dictionary) -> void:
	var max_biomass := float(state.get("max_plant_biomass", _ecosystem_value("max_plant_biomass")))
	state["plant_biomass_percent"] = _get_state_biomass_percent(state)
	state["food_stress"] = 1.0 if max_biomass <= 0.0 else 1.0 - clamp(float(state.get("plant_biomass", 0.0)) / max_biomass, 0.0, 1.0)
	state["status"] = _get_biomass_status(float(state.get("plant_biomass", 0.0)), max_biomass)


func _post_debug_message(message: String, biome_id: String) -> void:
	if not biome_states.has(biome_id):
		return
	var state: Dictionary = biome_states[biome_id]
	var event_bus := _get_event_bus()
	if event_bus:
		event_bus.post_message("%s in %s" % [message, str(state.get("name", biome_id))])


func _update_ecosystem_tick() -> void:
	pending_tick_biome_ids.clear()
	for biome_id in biome_states.keys():
		_update_ecosystem_biome(str(biome_id))


func _begin_runtime_ecosystem_tick() -> void:
	pending_tick_biome_ids.clear()
	for biome_id in biome_states.keys():
		pending_tick_biome_ids.append(str(biome_id))
	pending_tick_biome_ids.sort()


func _take_next_pending_biome_id() -> String:
	if pending_tick_biome_ids.is_empty():
		return ""
	return pending_tick_biome_ids.pop_front()


func _process_next_runtime_biome() -> void:
	var biome_id := _take_next_pending_biome_id()
	if biome_id.is_empty():
		return
	_update_ecosystem_biome(biome_id)


func _update_ecosystem_biome(biome_id: String) -> void:
	if not biome_states.has(biome_id):
		return
	var state: Dictionary = biome_states[biome_id]
	var previous_status := str(state.get("status", "healthy"))
	_update_biome_biomass(state)
	_update_predator_pressure(state, biome_id)
	_update_visible_creature_aggregates(state, biome_id)
	_update_biome_populations(state)
	state["status"] = _get_biomass_status(
		float(state.get("plant_biomass", 0.0)),
		float(state.get("max_plant_biomass", _ecosystem_value("max_plant_biomass")))
	)
	_update_grazer_niche_shift(state)
	_update_species_generations(state)
	biome_states[biome_id] = state
	_emit_vegetation_changed(state)
	_emit_status_event_if_needed(previous_status, state)


func _update_biome_biomass(state: Dictionary) -> void:
	var max_biomass := float(state.get("max_plant_biomass", _ecosystem_value("max_plant_biomass")))
	var plant_biomass := float(state.get("plant_biomass", _ecosystem_value("default_plant_biomass")))
	var regrowth_rate := float(state.get("plant_regrowth_rate", _ecosystem_value("plant_regrowth_rate")))
	var small_prey_population := float(state.get("small_prey_population", 0.0))
	var grazer_population := float(state.get("grazer_population", 0.0))
	var consumption_pressure := (
		small_prey_population * _ecosystem_value("small_prey_plant_consumption")
		+ grazer_population * _ecosystem_value("grazer_plant_consumption")
	)
	var regrowth := regrowth_rate if plant_biomass < max_biomass else 0.0
	plant_biomass = clamp(plant_biomass + regrowth - consumption_pressure, 0.0, max_biomass)
	state["plant_biomass"] = plant_biomass
	state["plant_biomass_percent"] = _get_state_biomass_percent(state)
	state["plant_consumption_pressure"] = consumption_pressure
	state["overgrazing_pressure"] = consumption_pressure
	state["overgrazing_level"] = clamp(consumption_pressure / _ecosystem_value("overgrazing_pressure_scale"), 0.0, 1.0)
	state["food_stress"] = 1.0 - clamp(plant_biomass / max_biomass, 0.0, 1.0)
	state["starvation_pressure"] = state["food_stress"]


func _update_predator_pressure(state: Dictionary, biome_id: String) -> void:
	var varnak_count := 0
	var total_varnaks := 0
	var hunger_total := 0.0
	var energy_total := 0.0
	var fitness_total := 0.0
	var meat_diet_total := 0.0
	var scavenger_diet_total := 0.0
	var hunt_drive_total := 0.0
	var generation_total := 0
	for varnak in _get_creature_nodes("varnak"):
		if not is_instance_valid(varnak) or not varnak.has_method("get_debug_data"):
			continue
		total_varnaks += 1
		if _get_biome_id_for_position(varnak.global_position) == biome_id:
			varnak_count += 1
			var data: Dictionary = varnak.get_debug_data()
			hunger_total += float(data.get("hunger_ratio", data.get("hunger", 0.0)))
			energy_total += float(data.get("energy", 0.0))
			fitness_total += float(data.get("fitness_score", 0.0))
			meat_diet_total += float(data.get("meat_diet", 1.0))
			scavenger_diet_total += float(data.get("scavenger_diet", 0.45))
			hunt_drive_total += float(data.get("hunt_drive", 0.0))
			generation_total += int(data.get("generation", 1))
	state["varnak_population"] = float(varnak_count)
	if total_varnaks <= 0:
		state["varnak_ecosystem_pressure"] = 0.0
		state["predator_pressure"] = 0.0
		state["average_varnak_hunger"] = 0.0
		state["average_varnak_energy"] = 1.0
		state["average_varnak_fitness"] = 0.0
		state["average_varnak_hunt_drive"] = 0.0
		return
	var pressure: float = clamp(float(varnak_count) / float(total_varnaks), 0.0, 1.0)
	state["varnak_ecosystem_pressure"] = pressure
	state["predator_pressure"] = pressure
	if varnak_count <= 0:
		state["average_varnak_hunger"] = 0.0
		state["average_varnak_energy"] = 1.0
		state["average_varnak_fitness"] = 0.0
		state["average_varnak_hunt_drive"] = 0.0
		return
	state["average_varnak_hunger"] = hunger_total / float(varnak_count)
	state["average_varnak_energy"] = energy_total / float(varnak_count)
	state["average_varnak_fitness"] = fitness_total / float(varnak_count)
	state["average_varnak_meat_diet"] = meat_diet_total / float(varnak_count)
	state["average_varnak_scavenger_diet"] = scavenger_diet_total / float(varnak_count)
	state["average_varnak_hunt_drive"] = hunt_drive_total / float(varnak_count)
	state["varnak_generation"] = int(round(float(generation_total) / float(varnak_count)))


func _update_visible_creature_aggregates(state: Dictionary, biome_id: String) -> void:
	var count := 0
	var hunger_total := 0.0
	var energy_total := 0.0
	var small_prey_count := 0
	var small_prey_generation_total := 0
	var small_prey_fear_total := 0.0
	var small_prey_speed_total := 0.0
	var small_prey_reproduction_total := 0.0
	var small_prey_fitness_total := 0.0
	var grazer_count := 0
	var grazer_generation_total := 0
	var grazer_reproduction_total := 0.0
	var grazer_fitness_total := 0.0
	for group_name in ["small_prey", "grazer", "varnak"]:
		for creature in _get_creature_nodes(group_name):
			if not is_instance_valid(creature) or not creature.has_method("get_debug_data"):
				continue
			if _get_biome_id_for_position(creature.global_position) != biome_id:
				continue
			var data: Dictionary = creature.get_debug_data()
			hunger_total += float(data.get("hunger_ratio", data.get("hunger", 0.0)))
			energy_total += float(data.get("energy", 0.0))
			count += 1
			if group_name == "small_prey":
				small_prey_count += 1
				small_prey_generation_total += int(data.get("generation", 1))
				small_prey_fear_total += float(data.get("fear", _ecosystem_value("initial_small_prey_fear")))
				small_prey_speed_total += float(data.get("speed", _ecosystem_value("initial_small_prey_speed")))
				small_prey_reproduction_total += float(data.get("reproduction_value", _ecosystem_value("initial_small_prey_reproduction")))
				small_prey_fitness_total += float(data.get("fitness_score", 0.0))
			elif group_name == "grazer":
				grazer_count += 1
				grazer_generation_total += int(data.get("generation", 1))
				grazer_reproduction_total += float(data.get("reproduction_rate", _ecosystem_value("initial_grazer_reproduction")))
				grazer_fitness_total += float(data.get("fitness_score", 0.0))
	if small_prey_count > 0:
		var visible_small_prey_generation := int(round(float(small_prey_generation_total) / float(small_prey_count)))
		state["small_prey_generation"] = max(int(state.get("small_prey_generation", 1)), visible_small_prey_generation)
		state["average_small_prey_fear"] = small_prey_fear_total / float(small_prey_count)
		state["average_small_prey_speed"] = small_prey_speed_total / float(small_prey_count)
		state["average_small_prey_reproduction"] = small_prey_reproduction_total / float(small_prey_count)
		state["average_small_prey_fitness"] = small_prey_fitness_total / float(small_prey_count)
	else:
		state["average_small_prey_fitness"] = 0.0
	if grazer_count > 0:
		var visible_grazer_generation := int(round(float(grazer_generation_total) / float(grazer_count)))
		state["grazer_generation"] = max(int(state.get("grazer_generation", 1)), visible_grazer_generation)
		state["average_grazer_reproduction"] = grazer_reproduction_total / float(grazer_count)
		state["average_grazer_fitness"] = grazer_fitness_total / float(grazer_count)
	else:
		state["average_grazer_fitness"] = 0.0
	if count <= 0:
		state["average_hunger"] = 0.0
		state["average_energy"] = 1.0
		return
	state["average_hunger"] = hunger_total / float(count)
	state["average_energy"] = energy_total / float(count)


func _get_creature_nodes(group_name: String) -> Array:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return []
	var world := tree.current_scene.get_node_or_null("World")
	if world and world.has_method("get_registered_creatures_by_type"):
		return world.get_registered_creatures_by_type(group_name)
	return tree.get_nodes_in_group(group_name)


func _update_biome_populations(state: Dictionary) -> void:
	var biomass_factor: float = clamp(float(state.get("plant_biomass_percent", 0.0)) / 100.0, 0.0, 1.0)
	var predator_pressure := float(state.get("varnak_ecosystem_pressure", 0.0))
	var food_stress := float(state.get("food_stress", 0.0))
	var small_prey_population := float(state.get("small_prey_population", 0.0))
	var grazer_population := float(state.get("grazer_population", 0.0))
	var varnak_population := float(state.get("varnak_population", 0.0))
	var omnivore_resilience := (
		float(state.get("average_meat_diet", _ecosystem_value("initial_average_meat_diet")))
		+ float(state.get("average_scavenger_diet", _ecosystem_value("initial_average_scavenger_diet")))
	)
	var small_prey_predation_multiplier := _get_critical_predation_multiplier(
		small_prey_population,
		_population_recovery_value("small_prey_min_population")
	)
	var grazer_predation_multiplier := _get_critical_predation_multiplier(
		grazer_population,
		_population_recovery_value("grazer_min_population")
	)
	var small_prey_predation_pressure: float = predator_pressure * _ecosystem_value("small_prey_predation_rate") * small_prey_predation_multiplier
	var grazer_predation_pressure: float = predator_pressure * _ecosystem_value("grazer_predation_rate") * grazer_predation_multiplier
	var grazer_starvation_pressure: float = food_stress * _ecosystem_value("grazer_starvation_rate") * (1.0 - clamp(omnivore_resilience, 0.0, _ecosystem_value("max_omnivore_resilience")))
	var small_prey_delta: float = biomass_factor * _ecosystem_value("small_prey_growth_rate")
	small_prey_delta -= small_prey_predation_pressure
	if biomass_factor < _ecosystem_value("small_prey_collapse_biomass_factor"):
		small_prey_delta -= _ecosystem_value("small_prey_collapse_loss_rate")

	var grazer_delta: float = biomass_factor * _ecosystem_value("grazer_growth_rate")
	grazer_delta -= grazer_starvation_pressure
	grazer_delta -= grazer_predation_pressure

	state["small_prey_population"] = clamp(
		small_prey_population + small_prey_delta,
		0.0,
		_population_recovery_value("small_prey_max_population")
	)

	state["grazer_population"] = clamp(
		grazer_population + grazer_delta,
		0.0,
		_population_recovery_value("grazer_max_population")
	)
	var actual_small_prey_delta := float(state.get("small_prey_population", 0.0)) - small_prey_population
	var actual_grazer_delta := float(state.get("grazer_population", 0.0)) - grazer_population
	var total_delta := small_prey_delta + grazer_delta
	state["population_count"] = float(state.get("small_prey_population", 0.0)) + float(state.get("grazer_population", 0.0)) + varnak_population
	state["birth_rate"] = max(total_delta, 0.0)
	state["death_rate"] = max(-total_delta, 0.0)
	state["starvation_pressure"] = food_stress
	state["small_prey_predation_pressure"] = small_prey_predation_pressure
	state["grazer_predation_pressure"] = grazer_predation_pressure
	state["grazer_starvation_pressure"] = grazer_starvation_pressure
	state["small_prey_population_trend"] = _get_population_trend(actual_small_prey_delta)
	state["grazer_population_trend"] = _get_population_trend(actual_grazer_delta)
	_emit_population_decline_events_if_needed(state, small_prey_population, grazer_population)


func _get_critical_predation_multiplier(population: float, minimum_population: float) -> float:
	if population >= minimum_population:
		return 1.0
	return _population_recovery_value("critical_population_predation_multiplier")


func _get_population_trend(delta: float) -> String:
	if delta > 0.05:
		return "growing"
	if delta < -0.05:
		return "declining"
	return "stable"


func _apply_daily_population_recovery() -> void:
	for biome_id_value in biome_states.keys():
		var biome_id := str(biome_id_value)
		var state: Dictionary = biome_states[biome_id]
		var small_prey_recovery := _recover_population_for_day(state, "small_prey")
		var grazer_recovery := _recover_population_for_day(state, "grazer")
		state["small_prey_daily_recovery"] = small_prey_recovery
		state["grazer_daily_recovery"] = grazer_recovery
		state["small_prey_population_trend"] = _get_population_trend(small_prey_recovery)
		state["grazer_population_trend"] = _get_population_trend(grazer_recovery)
		state["population_count"] = (
			float(state.get("small_prey_population", 0.0))
			+ float(state.get("grazer_population", 0.0))
			+ float(state.get("varnak_population", 0.0))
		)
		biome_states[biome_id] = state


func _recover_population_for_day(state: Dictionary, species: String) -> float:
	var population_key: String = "%s_population" % species
	var current_population: float = float(state.get(population_key, 0.0))
	var target_population: float = _population_recovery_value("%s_target_population" % species)
	var max_population: float = _population_recovery_value("%s_max_population" % species)
	if current_population >= target_population or current_population >= max_population:
		return 0.0
	var biomass_multiplier: float = _get_biomass_recovery_multiplier(float(state.get("plant_biomass_percent", 0.0)))
	var recovery_per_day: float = _population_recovery_value("%s_recovery_per_day" % species)
	var recovery: float = minf(recovery_per_day * biomass_multiplier, target_population - current_population)
	var recovered_population: float = clampf(current_population + recovery, 0.0, max_population)
	state[population_key] = recovered_population
	return recovered_population - current_population


func _get_biomass_recovery_multiplier(biomass_percent: float) -> float:
	var depleted_threshold := _ecosystem_value("depleted_threshold")
	var healthy_threshold := _ecosystem_value("stressed_threshold")
	var depleted_multiplier := _population_recovery_value("depleted_biomass_recovery_multiplier")
	var healthy_multiplier := _population_recovery_value("healthy_biomass_recovery_multiplier")
	if biomass_percent <= depleted_threshold:
		return depleted_multiplier
	if biomass_percent >= healthy_threshold:
		return healthy_multiplier
	var blend := inverse_lerp(depleted_threshold, healthy_threshold, biomass_percent)
	return lerpf(depleted_multiplier, healthy_multiplier, blend)


func _get_state_biomass_percent(state: Dictionary) -> float:
	var max_biomass := float(state.get("max_plant_biomass", _ecosystem_value("max_plant_biomass")))
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
	var event_bus := _get_event_bus()
	if event_bus:
		event_bus.emit_game_event(event_name, state.duplicate(true))


func _emit_vegetation_changed(state: Dictionary, delta: Dictionary = {}) -> void:
	var payload := state.duplicate(true)
	if not delta.is_empty():
		payload["ecosystem_delta"] = Dictionary(delta).duplicate(true)
	var event_bus := _get_event_bus()
	if event_bus:
		event_bus.emit_game_event("ecosystem_vegetation_changed", payload)


func _emit_population_decline_events_if_needed(state: Dictionary, previous_small_prey: float, previous_grazers: float) -> void:
	var current_small_prey := float(state.get("small_prey_population", 0.0))
	var current_grazers := float(state.get("grazer_population", 0.0))
	var decline_min_delta := _ecosystem_value("population_decline_event_min_delta")
	if previous_small_prey - current_small_prey >= decline_min_delta:
		var payload := state.duplicate(true)
		payload["previous_population"] = previous_small_prey
		payload["current_population"] = current_small_prey
		var event_bus := _get_event_bus()
		if event_bus:
			event_bus.emit_game_event("small_prey_population_declining", payload)
	if previous_grazers - current_grazers >= decline_min_delta:
		var payload := state.duplicate(true)
		payload["previous_population"] = previous_grazers
		payload["current_population"] = current_grazers
		var event_bus := _get_event_bus()
		if event_bus:
			event_bus.emit_game_event("grazer_population_declining", payload)


func _on_game_event(event_name: String, payload: Dictionary) -> void:
	match event_name:
		"day_ended":
			_apply_daily_population_recovery()
		"small_prey_killed_by_player", "small_prey_killed_by_varnak", "small_prey_killed_by_grazer":
			_apply_small_prey_death(payload)
		"small_prey_consumed_plants":
			apply_command(ECOSYSTEM_COMMAND.new_with(ECOSYSTEM_COMMAND.PLANT_CONSUMED, str(payload.get("biome_id", "")), payload))
		"grazer_killed_by_player", "grazer_killed_by_varnak":
			_apply_grazer_death(payload)
		"grazer_consumed_plants":
			apply_command(ECOSYSTEM_COMMAND.new_with(ECOSYSTEM_COMMAND.PLANT_CONSUMED, str(payload.get("biome_id", "")), payload))
		"grazer_scavenged", "grazer_hunted_small_prey":
			_record_grazer_non_plant_food(payload)
		"varnak_killed_by_player", "varnak_killed_by_trap":
			_apply_varnak_death(payload)
		"plant_resource_harvested":
			apply_command(ECOSYSTEM_COMMAND.new_with(ECOSYSTEM_COMMAND.PLANT_HARVESTED, str(payload.get("biome_id", "")), payload))


func apply_command(command_value: Variant) -> Dictionary:
	var command := _normalize_command(command_value)
	if command.is_empty():
		return {}
	return _apply_command(command)


func _normalize_command(command_value: Variant) -> Dictionary:
	if command_value != null and command_value.has_method("to_dict"):
		return command_value.to_dict()
	if typeof(command_value) != TYPE_DICTIONARY:
		return {}
	var command := Dictionary(command_value).duplicate(true)
	command["kind"] = str(command.get("kind", ""))
	command["biome_id"] = str(command.get("biome_id", ""))
	if typeof(command.get("payload", {})) == TYPE_DICTIONARY:
		command["payload"] = Dictionary(command.get("payload", {})).duplicate(true)
	else:
		command["payload"] = {}
	return command


func _apply_command(command: Dictionary) -> Dictionary:
	var kind := str(command.get("kind", ""))
	var payload: Dictionary = Dictionary(command.get("payload", {}))
	match kind:
		ECOSYSTEM_COMMAND.PLANT_CONSUMED:
			return _apply_visible_plant_consumption(payload)
		ECOSYSTEM_COMMAND.PLANT_HARVESTED:
			return _apply_harvested_plant_pressure(payload)
		ECOSYSTEM_COMMAND.SMALL_PREY_DEATH:
			_apply_small_prey_death(payload)
		ECOSYSTEM_COMMAND.GRAZER_DEATH:
			_apply_grazer_death(payload)
		ECOSYSTEM_COMMAND.VARNAK_DEATH:
			_apply_varnak_death(payload)
		ECOSYSTEM_COMMAND.GRAZER_NON_PLANT_FOOD:
			_record_grazer_non_plant_food(payload)
	return {}


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


func _apply_varnak_death(payload: Dictionary) -> void:
	var biome_id := str(payload.get("biome_id", ""))
	if not biome_states.has(biome_id):
		return
	var state: Dictionary = biome_states[biome_id]
	state["varnak_population"] = max(float(state.get("varnak_population", 0.0)) - 1.0, 0.0)
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
		biomass_percent < _ecosystem_value("grazer_food_stress_threshold")
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
	var diet_shift_rate := _ecosystem_value("grazer_diet_shift_rate")
	state["average_plant_diet"] = clamp(float(state.get("average_plant_diet", _ecosystem_value("initial_average_plant_diet"))) - diet_shift_rate, 0.0, 1.0)
	state["average_meat_diet"] = clamp(float(state.get("average_meat_diet", _ecosystem_value("initial_average_meat_diet"))) + diet_shift_rate * _ecosystem_value("grazer_meat_diet_shift_ratio"), 0.0, 1.0)
	state["average_scavenger_diet"] = clamp(float(state.get("average_scavenger_diet", _ecosystem_value("initial_average_scavenger_diet"))) + diet_shift_rate * _ecosystem_value("grazer_scavenger_diet_shift_ratio"), 0.0, 1.0)
	state["average_aggression"] = clamp(float(state.get("average_aggression", _ecosystem_value("initial_average_aggression"))) + _ecosystem_value("grazer_aggression_shift_rate"), 0.0, 1.0)
	state["grazer_non_plant_food_events"] = 0
	_update_grazer_niche_status(state)


func _update_grazer_niche_status(state: Dictionary) -> void:
	var current_niche := str(state.get("current_niche", "HERBIVORE"))
	if current_niche != "HERBIVORE":
		return
	var non_plant_diet := float(state.get("average_meat_diet", 0.0)) + float(state.get("average_scavenger_diet", 0.0))
	if non_plant_diet <= _ecosystem_value("grazer_niche_shift_threshold"):
		return
	state["current_niche"] = "OMNIVORE"
	var event_bus := _get_event_bus()
	if event_bus:
		event_bus.emit_game_event("grazer_niche_shifted", {
		"biome_id": str(state.get("biome_id", "")),
		"old_niche": current_niche,
		"new_niche": "OMNIVORE",
		"average_plant_diet": float(state.get("average_plant_diet", 0.0)),
		"average_meat_diet": float(state.get("average_meat_diet", 0.0)),
		"average_scavenger_diet": float(state.get("average_scavenger_diet", 0.0)),
		"average_aggression": float(state.get("average_aggression", 0.0))
		})


func _update_species_generations(state: Dictionary) -> void:
	var required_ticks: int = max(int(round(_ecosystem_value("species_generation_ticks_required"))), 1)
	var threshold: float = _ecosystem_value("species_generation_pressure_threshold")
	var predator_pressure := float(state.get("predator_pressure", 0.0))
	var food_stress := float(state.get("food_stress", 0.0))
	var small_prey_population := float(state.get("small_prey_population", 0.0))
	var grazer_population := float(state.get("grazer_population", 0.0))
	var small_prey_pressure: float = clamp(predator_pressure * 0.75 + food_stress * 0.25, 0.0, 1.0)
	var grazer_pressure: float = clamp(food_stress * 0.70 + predator_pressure * 0.30, 0.0, 1.0)
	if small_prey_population > 0.0 and small_prey_pressure >= threshold:
		state["small_prey_pressure_ticks"] = int(state.get("small_prey_pressure_ticks", 0)) + 1
		if int(state.get("small_prey_pressure_ticks", 0)) >= required_ticks:
			state["small_prey_generation"] = int(state.get("small_prey_generation", 1)) + 1
			state["average_small_prey_fear"] = clamp(
				float(state.get("average_small_prey_fear", _ecosystem_value("initial_small_prey_fear"))) + _ecosystem_value("small_prey_fear_shift_rate"),
				0.2,
				1.8
			)
			state["average_small_prey_speed"] = clamp(
				float(state.get("average_small_prey_speed", _ecosystem_value("initial_small_prey_speed"))) + _ecosystem_value("small_prey_speed_shift_rate"),
				35.0,
				150.0
			)
			state["average_small_prey_reproduction"] = clamp(
				float(state.get("average_small_prey_reproduction", _ecosystem_value("initial_small_prey_reproduction"))) - _ecosystem_value("small_prey_reproduction_shift_rate") * food_stress,
				0.12,
				1.2
			)
			state["small_prey_pressure_ticks"] = 0
	else:
		state["small_prey_pressure_ticks"] = 0
	if grazer_population > 0.0 and grazer_pressure >= threshold:
		state["grazer_pressure_ticks"] = int(state.get("grazer_pressure_ticks", 0)) + 1
		if int(state.get("grazer_pressure_ticks", 0)) >= required_ticks:
			state["grazer_generation"] = int(state.get("grazer_generation", 1)) + 1
			state["average_aggression"] = clamp(
				float(state.get("average_aggression", _ecosystem_value("initial_average_aggression"))) + _ecosystem_value("grazer_generation_aggression_shift_rate"),
				0.0,
				1.0
			)
			var reproduction_delta: float = _ecosystem_value("grazer_generation_reproduction_shift_rate")
			if food_stress > predator_pressure:
				reproduction_delta *= -1.0
			state["average_grazer_reproduction"] = clamp(
				float(state.get("average_grazer_reproduction", _ecosystem_value("initial_grazer_reproduction"))) + reproduction_delta,
				0.08,
				1.0
			)
			state["grazer_pressure_ticks"] = 0
	else:
		state["grazer_pressure_ticks"] = 0


func _apply_visible_plant_consumption(payload: Dictionary) -> Dictionary:
	var biome_id := str(payload.get("biome_id", ""))
	var consumption := float(payload.get("plant_consumption_rate", 0.0))
	var biomass_impact := float(payload.get("biomass_impact", consumption))
	return _apply_plant_biomass_loss(biome_id, max(consumption, biomass_impact), payload)


func _apply_harvested_plant_pressure(payload: Dictionary) -> Dictionary:
	var biome_id := str(payload.get("biome_id", ""))
	var biomass_impact := float(payload.get("biomass_impact", 0.0))
	return _apply_plant_biomass_loss(biome_id, biomass_impact, payload)


func _apply_plant_biomass_loss(biome_id: String, biomass_loss: float, payload: Dictionary = {}) -> Dictionary:
	if not biome_states.has(biome_id) or biomass_loss <= 0.0:
		return {}
	var state: Dictionary = biome_states[biome_id]
	var previous_status := str(state.get("status", "healthy"))
	var previous_biomass_percent := float(state.get("plant_biomass_percent", _get_state_biomass_percent(state)))
	var plant_biomass := float(state.get("plant_biomass", 0.0))
	state["plant_biomass"] = max(plant_biomass - biomass_loss, 0.0)
	state["plant_biomass_percent"] = _get_state_biomass_percent(state)
	var max_biomass := float(state.get("max_plant_biomass", _ecosystem_value("max_plant_biomass")))
	state["food_stress"] = 1.0 if max_biomass <= 0.0 else 1.0 - clamp(float(state.get("plant_biomass", 0.0)) / max_biomass, 0.0, 1.0)
	state["status"] = _get_biomass_status(
		float(state.get("plant_biomass", 0.0)),
		max_biomass
	)
	biome_states[biome_id] = state
	var delta = ECOSYSTEM_DELTA.new_with(
		biome_id,
		previous_biomass_percent,
		float(state.get("plant_biomass_percent", previous_biomass_percent)),
		previous_status != str(state.get("status", "healthy")),
		str(state.get("status", "healthy")),
		-1,
		payload
	)
	_emit_vegetation_changed(state, delta.to_dict())
	_emit_status_event_if_needed(previous_status, state)
	var event_bus := _get_event_bus()
	if event_bus:
		event_bus.emit_game_event("ecosystem_delta_applied", delta.to_dict())
	return delta.to_dict()


func _get_biomass_status(plant_biomass: float, max_plant_biomass: float) -> String:
	var percent := 0.0 if max_plant_biomass <= 0.0 else plant_biomass / max_plant_biomass * 100.0
	var healthy_threshold := minf(_ecosystem_value("stressed_threshold"), 60.0)
	if percent < _ecosystem_value("collapsing_threshold"):
		return "collapsing"
	if percent < _ecosystem_value("depleted_threshold"):
		return "depleted"
	if percent < healthy_threshold:
		return "stressed"
	return "healthy"


func _get_biome_id(biome: Dictionary) -> String:
	return str(biome.get("name", "biome")).to_snake_case()


func _get_biome_id_for_position(position: Vector2) -> String:
	for biome in WORLD_CONFIG.get_biome_zones():
		if Geometry2D.is_point_in_polygon(position, PackedVector2Array(biome["points"])):
			return _get_biome_id(biome)
	return ""


func _get_event_bus() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/EventBus")
