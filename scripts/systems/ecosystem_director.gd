extends Node

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")

var biome_states: Dictionary = {}
var tick_timer := 0.0
var initialized := false


func _ecosystem_value(key: String) -> float:
	return float(GAME_BALANCE.ECOSYSTEM[key])


func _ready() -> void:
	get_node("/root/EventBus").game_event.connect(_on_game_event)
	_initialize_biomes()


func _process(delta: float) -> void:
	if not initialized:
		return
	tick_timer += delta
	if tick_timer < _ecosystem_value("simulation_tick_seconds"):
		return
	tick_timer = 0.0
	_update_ecosystem_tick()


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
	var saved_states = data.get("biome_states", {})
	if typeof(saved_states) == TYPE_DICTIONARY:
		_restore_biome_states(Dictionary(saved_states))
	tick_timer = clamp(float(data.get("tick_timer", tick_timer)), 0.0, _ecosystem_value("simulation_tick_seconds"))
	initialized = true


func get_biome_status(biome_id: String) -> String:
	return str(get_biome_state(biome_id).get("status", "unknown"))


func get_grazer_traits(biome_id: String) -> Dictionary:
	var state := get_biome_state(biome_id)
	if state.is_empty():
		return {}
	return {
		"plant_diet": float(state.get("average_plant_diet", _ecosystem_value("initial_average_plant_diet"))),
		"meat_diet": float(state.get("average_meat_diet", _ecosystem_value("initial_average_meat_diet"))),
		"scavenger_diet": float(state.get("average_scavenger_diet", _ecosystem_value("initial_average_scavenger_diet"))),
		"aggression": float(state.get("average_aggression", _ecosystem_value("initial_average_aggression"))),
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
	get_node("/root/EventBus").post_message("Debug advanced ecosystem tick")


func _initialize_biomes() -> void:
	biome_states.clear()
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
			"population_count": _ecosystem_value("initial_small_prey_population") + _ecosystem_value("initial_grazer_population"),
			"average_hunger": 0.0,
			"average_energy": 1.0,
			"varnak_ecosystem_pressure": 0.0,
			"food_stress": 0.0,
			"starvation_pressure": 0.0,
			"average_plant_diet": _ecosystem_value("initial_average_plant_diet"),
			"average_meat_diet": _ecosystem_value("initial_average_meat_diet"),
			"average_scavenger_diet": _ecosystem_value("initial_average_scavenger_diet"),
			"average_aggression": _ecosystem_value("initial_average_aggression"),
			"birth_rate": 0.0,
			"death_rate": 0.0,
			"current_niche": "HERBIVORE",
			"generations_under_food_stress": 0,
			"grazer_non_plant_food_events": 0,
			"predator_pressure": 0.0,
			"status": _get_biomass_status(default_plant_biomass, max_plant_biomass)
		}
	initialized = true
	print("[Ecosystem] Initialized biome states: %s" % biome_states)


func _restore_biome_states(saved_states: Dictionary) -> void:
	for biome_id in biome_states.keys():
		if not saved_states.has(biome_id) or typeof(saved_states[biome_id]) != TYPE_DICTIONARY:
			continue
		var state: Dictionary = biome_states[biome_id]
		var saved_state := Dictionary(saved_states[biome_id])
		for key in saved_state.keys():
			state[key] = saved_state[key]
		state["biome_id"] = biome_id
		state["plant_biomass_percent"] = _get_state_biomass_percent(state)
		state["status"] = _get_biomass_status(
			float(state.get("plant_biomass", 0.0)),
			float(state.get("max_plant_biomass", _ecosystem_value("max_plant_biomass")))
		)
		var max_biomass := float(state.get("max_plant_biomass", _ecosystem_value("max_plant_biomass")))
		state["food_stress"] = 1.0 if max_biomass <= 0.0 else 1.0 - clamp(float(state.get("plant_biomass", 0.0)) / max_biomass, 0.0, 1.0)
		biome_states[biome_id] = state


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
	get_node("/root/EventBus").post_message("%s in %s" % [message, str(state.get("name", biome_id))])


func _update_ecosystem_tick() -> void:
	for biome_id in biome_states.keys():
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
		biome_states[biome_id] = state
		_emit_vegetation_changed(state)
		_emit_status_event_if_needed(previous_status, state)
	print("[Ecosystem] Tick: %s" % biome_states)


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


func _update_visible_creature_aggregates(state: Dictionary, biome_id: String) -> void:
	var count := 0
	var hunger_total := 0.0
	var energy_total := 0.0
	for group_name in ["small_prey", "grazer"]:
		for creature in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(creature) or not creature.has_method("get_debug_data"):
				continue
			if _get_biome_id_for_position(creature.global_position) != biome_id:
				continue
			var data: Dictionary = creature.get_debug_data()
			hunger_total += float(data.get("hunger_ratio", data.get("hunger", 0.0)))
			energy_total += float(data.get("energy", 0.0))
			count += 1
	if count <= 0:
		state["average_hunger"] = 0.0
		state["average_energy"] = 1.0
		return
	state["average_hunger"] = hunger_total / float(count)
	state["average_energy"] = energy_total / float(count)


func _update_biome_populations(state: Dictionary) -> void:
	var biomass_factor: float = clamp(float(state.get("plant_biomass_percent", 0.0)) / 100.0, 0.0, 1.0)
	var predator_pressure := float(state.get("varnak_ecosystem_pressure", 0.0))
	var food_stress := float(state.get("food_stress", 0.0))
	var small_prey_population := float(state.get("small_prey_population", 0.0))
	var grazer_population := float(state.get("grazer_population", 0.0))
	var omnivore_resilience := (
		float(state.get("average_meat_diet", _ecosystem_value("initial_average_meat_diet")))
		+ float(state.get("average_scavenger_diet", _ecosystem_value("initial_average_scavenger_diet")))
	)
	var small_prey_delta: float = biomass_factor * _ecosystem_value("small_prey_growth_rate")
	small_prey_delta -= predator_pressure * _ecosystem_value("small_prey_predation_rate")
	if biomass_factor < _ecosystem_value("small_prey_collapse_biomass_factor"):
		small_prey_delta -= _ecosystem_value("small_prey_collapse_loss_rate")
	var grazer_delta: float = biomass_factor * _ecosystem_value("grazer_growth_rate")
	grazer_delta -= food_stress * _ecosystem_value("grazer_starvation_rate") * (1.0 - clamp(omnivore_resilience, 0.0, _ecosystem_value("max_omnivore_resilience")))
	grazer_delta -= predator_pressure * _ecosystem_value("grazer_predation_rate")
	state["small_prey_population"] = clamp(small_prey_population + small_prey_delta, 0.0, _ecosystem_value("max_small_prey_population"))
	state["grazer_population"] = clamp(grazer_population + grazer_delta, 0.0, _ecosystem_value("max_grazer_population"))
	var total_delta := small_prey_delta + grazer_delta
	state["population_count"] = float(state.get("small_prey_population", 0.0)) + float(state.get("grazer_population", 0.0))
	state["birth_rate"] = max(total_delta, 0.0)
	state["death_rate"] = max(-total_delta, 0.0)
	state["starvation_pressure"] = food_stress
	_emit_population_decline_events_if_needed(state, small_prey_population, grazer_population)


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
	get_node("/root/EventBus").emit_game_event(event_name, state.duplicate(true))


func _emit_vegetation_changed(state: Dictionary) -> void:
	get_node("/root/EventBus").emit_game_event("ecosystem_vegetation_changed", state.duplicate(true))


func _emit_population_decline_events_if_needed(state: Dictionary, previous_small_prey: float, previous_grazers: float) -> void:
	var current_small_prey := float(state.get("small_prey_population", 0.0))
	var current_grazers := float(state.get("grazer_population", 0.0))
	var decline_min_delta := _ecosystem_value("population_decline_event_min_delta")
	if previous_small_prey - current_small_prey >= decline_min_delta:
		var payload := state.duplicate(true)
		payload["previous_population"] = previous_small_prey
		payload["current_population"] = current_small_prey
		get_node("/root/EventBus").emit_game_event("small_prey_population_declining", payload)
	if previous_grazers - current_grazers >= decline_min_delta:
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
	var biomass_impact := float(payload.get("biomass_impact", consumption))
	_apply_plant_biomass_loss(biome_id, max(consumption, biomass_impact))


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
	var max_biomass := float(state.get("max_plant_biomass", _ecosystem_value("max_plant_biomass")))
	state["food_stress"] = 1.0 if max_biomass <= 0.0 else 1.0 - clamp(float(state.get("plant_biomass", 0.0)) / max_biomass, 0.0, 1.0)
	state["status"] = _get_biomass_status(
		float(state.get("plant_biomass", 0.0)),
		max_biomass
	)
	biome_states[biome_id] = state
	_emit_vegetation_changed(state)
	_emit_status_event_if_needed(previous_status, state)


func _get_biomass_status(plant_biomass: float, max_plant_biomass: float) -> String:
	var percent := 0.0 if max_plant_biomass <= 0.0 else plant_biomass / max_plant_biomass * 100.0
	if percent < _ecosystem_value("collapsing_threshold"):
		return "collapsing"
	if percent < _ecosystem_value("depleted_threshold"):
		return "depleted"
	if percent < _ecosystem_value("stressed_threshold"):
		return "stressed"
	return "healthy"


func _get_biome_id(biome: Dictionary) -> String:
	return str(biome.get("name", "biome")).to_snake_case()


func _get_biome_id_for_position(position: Vector2) -> String:
	for biome in WORLD_CONFIG.get_biome_zones():
		if Geometry2D.is_point_in_polygon(position, PackedVector2Array(biome["points"])):
			return _get_biome_id(biome)
	return ""
