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
const STRESSED_THRESHOLD := 70.0
const DEPLETED_THRESHOLD := 30.0
const COLLAPSING_THRESHOLD := 10.0

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
		state["predator_pressure"] = _calculate_predator_pressure(biome_id)
		state["status"] = _get_biomass_status(
			float(state.get("plant_biomass", 0.0)),
			float(state.get("max_plant_biomass", DEFAULT_MAX_PLANT_BIOMASS))
		)
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


func _get_state_biomass_percent(state: Dictionary) -> float:
	var max_biomass := float(state.get("max_plant_biomass", DEFAULT_MAX_PLANT_BIOMASS))
	if max_biomass <= 0.0:
		return 0.0
	return float(state.get("plant_biomass", 0.0)) / max_biomass * 100.0


func _calculate_predator_pressure(biome_id: String) -> float:
	var varnak_count := 0
	var total_varnaks := 0
	for varnak in get_tree().get_nodes_in_group("varnak"):
		if not is_instance_valid(varnak):
			continue
		total_varnaks += 1
		if _get_biome_id_for_position(varnak.global_position) == biome_id:
			varnak_count += 1
	if total_varnaks <= 0:
		return 0.0
	return clamp(float(varnak_count) / float(total_varnaks), 0.0, 1.0)


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


func _apply_visible_plant_consumption(payload: Dictionary) -> void:
	var biome_id := str(payload.get("biome_id", ""))
	if not biome_states.has(biome_id):
		return
	var state: Dictionary = biome_states[biome_id]
	var previous_status := str(state.get("status", "healthy"))
	var plant_biomass := float(state.get("plant_biomass", 0.0))
	var consumption := float(payload.get("plant_consumption_rate", 0.0))
	state["plant_biomass"] = max(plant_biomass - consumption, 0.0)
	state["plant_biomass_percent"] = _get_state_biomass_percent(state)
	state["status"] = _get_biomass_status(
		float(state.get("plant_biomass", 0.0)),
		float(state.get("max_plant_biomass", DEFAULT_MAX_PLANT_BIOMASS))
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
