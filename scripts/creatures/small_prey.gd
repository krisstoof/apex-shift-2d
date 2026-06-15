extends CharacterBody2D

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const HUNGER_DIET := preload("res://scripts/creatures/hunger_diet.gd")
const SIMULATION_LOD := preload("res://scripts/creatures/creature_simulation_lod.gd")
const SPECIES_PATH := "res://data/species/small_prey.json"
const AI_DECISION_INTERVAL_SECONDS := 0.14
const SPATIAL_UPDATE_INTERVAL_SECONDS := 0.20
const MAX_PHYSICS_DELTA := 0.08
const LARGE_MOVEMENT_WARNING_DISTANCE := 220.0
const MAX_WANDER_TARGET_DISTANCE := 600.0
const MAX_FLEE_TARGET_DISTANCE := 600.0

enum State { IDLE, WANDER, SEEK_FOOD, EAT, FLEE, DEAD }

var wander_radius := 0.0
var wander_reached_distance := 0.0
var player_flee_range := 0.0
var varnak_flee_range := 0.0
var flee_duration_seconds := 0.0
var eat_interval_seconds := 0.0
var eat_duration_seconds := 0.0
var eat_visual_duration := 0.0
var idle_duration_seconds := 0.0
var vegetation_eat_range := 0.0
var vegetation_consume_range := 0.0
var world_edge_padding := 0.0
var avoidance_lookahead_distance := 0.0
var wall_avoid_radius := 0.0
var biome_return_chance := 0.0
const DEBUG_FRAME_FONT_SIZE := 11

var species_id := "small_prey"
var species_name := "Small Prey"
var generation := 1
var health := 20.0
var max_health := 20.0
var speed := 90.0
var fear := 0.9
var hunger := 0.0
var max_hunger := 1.0
var hunger_growth_rate := 0.2
var energy := 1.0
var age_seconds := 0.0
var plant_diet := 1.0
var meat_diet := 0.0
var scavenger_diet := 0.0
var plant_consumption_rate := 0.4
var reproduction_value := 0.6
var state := State.WANDER
var biome_id := ""
var home_biome_id := ""
var population_biome_id := ""
var wander_target := Vector2.ZERO
var state_time := 0.0
var eat_cooldown := 0.0
var eat_visual_time := 0.0
var target_lock_time := 0.0
var facing_angle := 0.0
var facing_side := 1.0
var player: Node2D
var flee_origin := Vector2.INF
var plant_target: Node2D
var dropped_meat := false
var last_food_source := "none"
var decision_reason := "spawn"
var ai_decision_interval := 0.30
var ai_decision_timer := 0.0
var ai_decision_count := 0
var spatial_update_timer := 0.0
var rng := RandomNumberGenerator.new()
var hunger_diet := HUNGER_DIET.new()
var is_visibility_culled := false
var stored_collision_layer := 0
var stored_collision_mask := 0
var simulation_level := SIMULATION_LOD.Level.NEAR
var simulation_level_name := "near"
var simulation_distance_to_player := 0.0
var simulation_lod_timer := 0.0
var far_simulation_timer := 0.0
var simulation_lod_change_count := 0
var last_simulation_level := SIMULATION_LOD.Level.NEAR
var movement_spike_count := 0
var max_movement_spike_distance := 0.0


func _get_event_bus() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("EventBus")


func _post_event_message(message: String) -> void:
	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_method("post_message"):
		event_bus.post_message(message)


func _emit_game_event(event_name: String, payload: Dictionary = {}) -> void:
	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_method("emit_game_event"):
		event_bus.emit_game_event(event_name, payload)


func _ready() -> void:
	add_to_group("small_prey")
	rng.randomize()
	player = get_tree().get_first_node_in_group("player")
	stored_collision_layer = collision_layer
	stored_collision_mask = collision_mask
	_initialize_from_game_balance()
	_load_species_data()
	if biome_id.is_empty():
		biome_id = _get_biome_id_for_position(global_position)
	if home_biome_id.is_empty():
		home_biome_id = biome_id
	ai_decision_timer = rng.randf_range(0.0, AI_DECISION_INTERVAL_SECONDS)
	_pick_wander_target()
	queue_redraw()


func set_visibility_culled(should_be_visible: bool) -> void:
	is_visibility_culled = not should_be_visible
	visible = should_be_visible
	_update_simulation_level()
	if should_be_visible:
		match simulation_level:
			SIMULATION_LOD.Level.NEAR:
				_restore_full_simulation()
			SIMULATION_LOD.Level.MEDIUM:
				_apply_medium_simulation()
			_:
				_apply_far_simulation()
		queue_redraw()
		return
	if simulation_level == SIMULATION_LOD.Level.FAR:
		_apply_far_simulation()
	else:
		collision_layer = stored_collision_layer
		collision_mask = stored_collision_mask
		set_physics_process(true)
		set_process(false)


func setup(p_biome_id: String = "") -> void:
	biome_id = p_biome_id
	home_biome_id = p_biome_id
	population_biome_id = p_biome_id


func get_debug_data() -> Dictionary:
	var data := {
		"species": species_name,
		"species_id": species_id,
		"generation": generation,
		"state": State.keys()[state],
		"biome_id": biome_id,
		"population_biome_id": population_biome_id,
		"health": health,
		"max_health": max_health,
		"speed": speed,
		"fear": fear,
		"age_seconds": age_seconds,
		"fatigue": 1.0 - energy,
		"rest": energy,
		"current_target": _get_current_target_label(),
		"decision_reason": decision_reason,
		"last_food_source": last_food_source,
		"fitness_score": _get_fitness_score(),
		"home_biome_id": home_biome_id,
		"plant_consumption_rate": plant_consumption_rate,
		"reproduction_value": reproduction_value,
		"distance_to_player": global_position.distance_to(player.global_position) if is_instance_valid(player) else -1.0,
		"simulation_level": simulation_level_name,
		"simulation_distance_to_player": simulation_distance_to_player,
		"simulation_lod_change_count": simulation_lod_change_count,
		"is_visibility_culled": is_visibility_culled,
		"ai_decision_interval_effective": _get_effective_ai_decision_interval()
	}
	data.merge(hunger_diet.get_debug_data(), true)
	return data


func get_debug_ai_state() -> String:
	return _get_debug_action_label()


func get_save_data() -> Dictionary:
	return {
		"species_id": species_id,
		"species_name": species_name,
		"generation": generation,
		"position": _vector_to_data(global_position),
		"facing_angle": facing_angle,
		"facing_side": facing_side,
		"health": health,
		"max_health": max_health,
		"speed": speed,
		"fear": fear,
		"hunger": hunger,
		"max_hunger": max_hunger,
		"hunger_growth_rate": hunger_growth_rate,
		"energy": energy,
		"age_seconds": age_seconds,
		"plant_diet": plant_diet,
		"meat_diet": meat_diet,
		"scavenger_diet": scavenger_diet,
		"plant_consumption_rate": plant_consumption_rate,
		"reproduction_value": reproduction_value,
		"state": int(state),
		"biome_id": biome_id,
		"home_biome_id": home_biome_id,
		"population_biome_id": population_biome_id,
		"wander_target": _vector_to_data(wander_target),
		"state_time": state_time,
		"eat_cooldown": eat_cooldown,
		"last_food_source": last_food_source,
		"dropped_meat": dropped_meat
	}


func restore_from_data(data: Dictionary) -> void:
	species_id = str(data.get("species_id", species_id))
	species_name = str(data.get("species_name", species_name))
	generation = max(_safe_int(data, "generation", generation), 1)
	global_position = _clamp_to_world(_data_to_vector(data.get("position", {})))
	facing_angle = _safe_float(data, "facing_angle", facing_angle)
	facing_side = _safe_float(data, "facing_side", facing_side)
	max_health = max(_safe_float(data, "max_health", max_health), 1.0)
	health = clamp(_safe_float(data, "health", health), 0.0, max_health)
	speed = _safe_float(data, "speed", speed)
	fear = _safe_float(data, "fear", fear)
	max_hunger = max(_safe_float(data, "max_hunger", max_hunger), 0.01)
	hunger = clamp(_safe_float(data, "hunger", hunger), 0.0, max_hunger)
	hunger_growth_rate = _safe_float(data, "hunger_growth_rate", hunger_growth_rate)
	energy = clamp(_safe_float(data, "energy", energy), 0.0, 1.0)
	age_seconds = max(_safe_float(data, "age_seconds", age_seconds), 0.0)
	plant_diet = _safe_float(data, "plant_diet", plant_diet)
	meat_diet = _safe_float(data, "meat_diet", meat_diet)
	scavenger_diet = _safe_float(data, "scavenger_diet", scavenger_diet)
	plant_consumption_rate = _safe_float(data, "plant_consumption_rate", plant_consumption_rate)
	reproduction_value = _safe_float(data, "reproduction_value", reproduction_value)
	state = _safe_int(data, "state", State.WANDER) as State
	if state == State.DEAD:
		state = State.WANDER
	biome_id = str(data.get("biome_id", biome_id))
	home_biome_id = str(data.get("home_biome_id", home_biome_id))
	population_biome_id = str(data.get("population_biome_id", population_biome_id))
	wander_target = _clamp_to_world(_data_to_vector(data.get("wander_target", _vector_to_data(wander_target))))
	state_time = max(_safe_float(data, "state_time", state_time), 0.0)
	eat_cooldown = max(_safe_float(data, "eat_cooldown", eat_cooldown), 0.0)
	last_food_source = str(data.get("last_food_source", last_food_source))
	dropped_meat = _safe_bool(data, "dropped_meat", dropped_meat)
	velocity = Vector2.ZERO
	simulation_level = SIMULATION_LOD.Level.NEAR
	simulation_level_name = "near"
	far_simulation_timer = 0.0
	hunger_diet.configure({
		"hunger": hunger,
		"max_hunger": max_hunger,
		"hunger_growth_rate": hunger_growth_rate,
		"energy": energy,
		"plant_diet": plant_diet,
		"meat_diet": meat_diet,
		"scavenger_diet": scavenger_diet
	})
	_sync_hunger_fields()
	queue_redraw()


func _safe_float(data: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = data.get(key, fallback)
	if value == null:
		return fallback
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	if typeof(value) == TYPE_STRING and str(value).is_valid_float():
		return float(value)
	return fallback


func _safe_int(data: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = data.get(key, fallback)
	if value == null:
		return fallback
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	if typeof(value) == TYPE_STRING and str(value).is_valid_int():
		return int(value)
	return fallback


func _safe_bool(data: Dictionary, key: String, fallback: bool) -> bool:
	var value: Variant = data.get(key, fallback)
	if value == null:
		return fallback
	if typeof(value) == TYPE_BOOL:
		return bool(value)
	if typeof(value) == TYPE_STRING:
		var normalized := str(value).to_lower()
		if normalized == "true":
			return true
		if normalized == "false":
			return false
	return fallback


func take_damage(amount: float, source: String = "unknown") -> void:
	if state == State.DEAD:
		return
	health = max(health - amount, 0.0)
	if health <= 0.0:
		_die(source)
	else:
		_set_state(State.FLEE)
		flee_origin = player.global_position if is_instance_valid(player) else global_position - Vector2.RIGHT


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	var safe_delta := minf(delta, MAX_PHYSICS_DELTA)
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	_update_simulation_level()
	if simulation_level == SIMULATION_LOD.Level.FAR:
		_tick_far_simulation(safe_delta)
		return
	if is_visibility_culled:
		return
	state_time = max(state_time - safe_delta, 0.0)
	eat_cooldown = max(eat_cooldown - safe_delta, 0.0)
	target_lock_time = max(target_lock_time - safe_delta, 0.0)
	if eat_visual_time > 0.0:
		eat_visual_time = max(eat_visual_time - safe_delta, 0.0)
		queue_redraw()
	age_seconds += safe_delta
	hunger_diet.tick(safe_delta, velocity.length() / max(speed, 1.0))
	_sync_hunger_fields()
	ai_decision_timer -= safe_delta
	var position_before_move := global_position
	if ai_decision_timer <= 0.0:
		ai_decision_timer = _get_effective_ai_decision_interval()
		ai_decision_count += 1
		_update_state()
	_act(safe_delta)
	move_and_slide()
	_record_movement_spike(position_before_move)
	_enforce_world_bounds()
	_update_spatial_cell_tick(safe_delta)


func force_ai_decision_for_tests() -> void:
	ai_decision_timer = 0.0
	_update_state()


func _should_update_ai_decision(delta: float) -> bool:
	return ai_decision_timer - delta <= 0.0


func _get_effective_ai_decision_interval() -> float:
	if simulation_level == SIMULATION_LOD.Level.MEDIUM:
		return SIMULATION_LOD.get_medium_ai_interval(ai_decision_interval, _get_simulation_lod_config())
	return ai_decision_interval


func _get_simulation_lod_config() -> Dictionary:
	return GAME_BALANCE.CREATURE_SIMULATION_LOD


func _update_simulation_level() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		_set_simulation_level(SIMULATION_LOD.Level.NEAR)
		return
	simulation_distance_to_player = global_position.distance_to(player.global_position)
	var creature_type := species_id if species_id != "" else name.to_snake_case()
	var next_level: CreatureSimulationLOD.Level = SIMULATION_LOD.resolve_level(
		simulation_distance_to_player,
		_get_simulation_lod_config(),
		creature_type
	) as CreatureSimulationLOD.Level
	_set_simulation_level(next_level)


func _set_simulation_level(next_level: CreatureSimulationLOD.Level) -> void:
	if simulation_level == next_level:
		return
	last_simulation_level = simulation_level
	simulation_level = next_level
	simulation_level_name = SIMULATION_LOD.get_level_name(simulation_level)
	simulation_lod_change_count += 1
	match simulation_level:
		SIMULATION_LOD.Level.NEAR:
			_restore_full_simulation()
		SIMULATION_LOD.Level.MEDIUM:
			_apply_medium_simulation()
		SIMULATION_LOD.Level.FAR:
			_apply_far_simulation()


func _restore_full_simulation() -> void:
	visible = true
	collision_layer = stored_collision_layer
	collision_mask = stored_collision_mask
	set_physics_process(true)
	set_process(true)
	velocity = Vector2.ZERO
	queue_redraw()


func _apply_medium_simulation() -> void:
	visible = true
	collision_layer = stored_collision_layer
	collision_mask = stored_collision_mask
	set_physics_process(true)
	set_process(true)


func _apply_far_simulation() -> void:
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	set_process(false)
	set_physics_process(true)


func _tick_far_simulation(delta: float) -> void:
	far_simulation_timer += delta
	var interval := SIMULATION_LOD.get_far_update_interval(_get_simulation_lod_config())
	if far_simulation_timer < interval:
		return
	var tick_delta := far_simulation_timer
	far_simulation_timer = 0.0
	age_seconds += tick_delta
	hunger_diet.tick(tick_delta, 0.0)
	_sync_hunger_fields()
	state_time = max(state_time - tick_delta, 0.0)
	target_lock_time = max(target_lock_time - tick_delta, 0.0)
	eat_cooldown = max(eat_cooldown - tick_delta, 0.0)
	velocity = Vector2.ZERO
	_update_spatial_cell_tick(tick_delta)


func get_ai_performance_debug() -> Dictionary:
	return {
		"decision_interval": ai_decision_interval,
		"decision_timer": ai_decision_timer,
		"decision_count": ai_decision_count,
		"movement_spike_count": movement_spike_count,
		"max_movement_spike_distance": max_movement_spike_distance
	}


func _update_state() -> void:
	var detected_flee_origin := _get_flee_origin()
	if detected_flee_origin != Vector2.INF:
		flee_origin = detected_flee_origin
		decision_reason = "threat_detected"
		_set_state(State.FLEE)
		return
	if state == State.FLEE:
		if state_time > 0.0:
			decision_reason = "threat_lost_keep_fleeing"
			return
		decision_reason = "threat_lost_return_wander"
		_set_state(State.WANDER)
		_pick_wander_target()
		return
	_sync_population_traits()
	if state == State.EAT:
		decision_reason = "eating_target_plant"
		if state_time <= 0.0:
			_consume_plants()
			decision_reason = "finished_eating"
			_set_state(State.WANDER)
			_pick_wander_target()
		return
	if state == State.SEEK_FOOD and _try_update_plant_target():
		decision_reason = "locked_food_target" if is_instance_valid(plant_target) else decision_reason
		return
	if eat_cooldown <= 0.0 and hunger_diet.is_hungry():
		var food_search_range := _get_food_search_range()
		if _has_valid_food_target(food_search_range) or _set_nearest_plant_target(food_search_range):
			decision_reason = "hungry_seek_plant"
			_set_state(State.SEEK_FOOD)
		elif hunger_diet.is_starving():
			decision_reason = "starving_no_plant"
			_set_state(State.EAT)
			state_time = eat_duration_seconds
		else:
			decision_reason = "hungry_no_food_wander"
			target_lock_time = _get_failed_food_retarget_seconds()
		return
	match state:
		State.IDLE:
			if state_time <= 0.0:
				decision_reason = "idle_complete"
				_set_state(State.WANDER)
				_pick_wander_target()
		State.WANDER:
			if global_position.distance_to(wander_target) < wander_reached_distance:
				decision_reason = "wander_target_reached"
				_set_state(State.IDLE)
				state_time = idle_duration_seconds
		State.SEEK_FOOD:
			pass
		State.EAT:
			pass


func _act(_delta: float) -> void:
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
		State.WANDER:
			_move_toward(wander_target, speed * 0.55)
		State.SEEK_FOOD:
			_move_toward(wander_target, speed * 0.72)
		State.EAT:
			velocity = Vector2.ZERO
		State.FLEE:
			var away := (global_position - flee_origin).normalized()
			var flee_target := _get_bounded_flee_target(away)
			_move_toward(flee_target, speed * (1.0 + fear))


func _move_toward(target: Vector2, move_speed: float) -> void:
	target = _clamp_to_world(target)
	var direction := target - global_position
	if direction.length_squared() <= 1.0:
		velocity = Vector2.ZERO
		return
	var move_direction := _get_navigation_direction(direction.normalized(), target)
	velocity = move_direction * move_speed * _get_terrain_speed_multiplier()
	_face_target(global_position + move_direction)


func _get_navigation_direction(desired_direction: Vector2, target: Vector2) -> Vector2:
	var avoidance := _get_wall_avoidance_vector()
	var adjusted_direction := (desired_direction + avoidance * 1.35).normalized()
	if _is_navigation_position_valid(global_position + adjusted_direction * avoidance_lookahead_distance):
		return adjusted_direction
	var candidates := [
		desired_direction.rotated(0.72),
		desired_direction.rotated(-0.72),
		desired_direction.rotated(1.28),
		desired_direction.rotated(-1.28),
		desired_direction.rotated(PI)
	]
	for candidate_direction in candidates:
		if _is_navigation_position_valid(global_position + candidate_direction * avoidance_lookahead_distance):
			return candidate_direction
	var fallback := (target - global_position).normalized()
	return fallback if fallback.length_squared() > 0.0 else Vector2.RIGHT


func _get_wall_avoidance_vector() -> Vector2:
	var avoidance := Vector2.ZERO
	for wall in _get_cached_group_nodes("walls"):
		if not is_instance_valid(wall) or not wall is Node2D:
			continue
		var wall_node := wall as Node2D
		var offset: Vector2 = global_position - wall_node.global_position
		var distance: float = offset.length()
		if distance > 0.0 and distance < wall_avoid_radius:
			avoidance += offset.normalized() * (1.0 - distance / wall_avoid_radius)
	return avoidance


func _face_target(target: Vector2) -> void:
	var direction := target - global_position
	if direction.length_squared() <= 1.0:
		return
	facing_angle = direction.angle()
	if abs(direction.x) > 4.0:
		facing_side = 1.0 if direction.x >= 0.0 else -1.0
	queue_redraw()


func _get_flee_origin() -> Vector2:
	var nearest_origin := Vector2.INF
	var nearest_distance := INF
	if is_instance_valid(player):
		var player_distance := global_position.distance_to(player.global_position)
		if player_distance < player_flee_range * fear:
			nearest_origin = player.global_position
			nearest_distance = player_distance
	for varnak in _get_nearby_creatures(varnak_flee_range * fear, "varnak"):
		if not is_instance_valid(varnak):
			continue
		var distance := global_position.distance_to(varnak.global_position)
		if distance < varnak_flee_range * fear and distance < nearest_distance:
			nearest_origin = varnak.global_position
			nearest_distance = distance
	return nearest_origin


func _consume_plants() -> void:
	var eaten_food := _consume_target_vegetation()
	if eaten_food <= 0.0:
		plant_target = null
		return
	var biomass_impact := plant_consumption_rate
	hunger_diet.eat("plants", max(0.5, eaten_food))
	_sync_hunger_fields()
	eat_visual_time = eat_visual_duration
	last_food_source = "plants"
	eat_cooldown = eat_interval_seconds
	var current_biome_id := _get_current_biome_id()
	_emit_game_event("small_prey_consumed_plants", {
		"biome_id": current_biome_id,
		"position": global_position,
		"plant_consumption_rate": plant_consumption_rate,
		"biomass_impact": biomass_impact
	})
	plant_target = null


func _consume_target_vegetation() -> float:
	if is_instance_valid(plant_target) and _is_edible_vegetation_target(plant_target):
		var distance := global_position.distance_to(plant_target.global_position)
		if distance <= vegetation_consume_range and plant_target.has_method("consume_by_creature"):
			var world_query: Variant = _get_world_query()
			if world_query and world_query.has_method("consume_edible_vegetation"):
				return float(world_query.consume_edible_vegetation(plant_target, self, plant_consumption_rate))
			return float(plant_target.consume_by_creature(self, plant_consumption_rate))
	return _consume_nearest_vegetation(vegetation_consume_range)


func _consume_nearest_vegetation(search_range: float = vegetation_eat_range) -> float:
	var nearest := _find_nearest_edible_vegetation(search_range)
	if is_instance_valid(nearest) and nearest.has_method("consume_by_creature"):
		var world_query: Variant = _get_world_query()
		if world_query and world_query.has_method("consume_edible_vegetation"):
			return float(world_query.consume_edible_vegetation(nearest, self, plant_consumption_rate))
		return float(nearest.consume_by_creature(self, plant_consumption_rate))
	return 0.0


func _has_valid_food_target(search_range: float) -> bool:
	if not is_instance_valid(plant_target):
		return false
	if not plant_target.is_in_group("edible_vegetation"):
		return false
	if plant_target.global_position.distance_to(global_position) > search_range * 1.25:
		return false
	return true


func _try_update_plant_target() -> bool:
	var food_search_range := _get_food_search_range()
	if _has_valid_food_target(food_search_range):
		wander_target = _clamp_to_world(plant_target.global_position)
		if global_position.distance_to(plant_target.global_position) <= vegetation_consume_range:
			_set_state(State.EAT)
			state_time = eat_duration_seconds
		return true
	if not is_instance_valid(plant_target) or not _is_edible_vegetation_target(plant_target):
		if not _set_nearest_plant_target(food_search_range):
			_set_state(State.WANDER)
			_pick_wander_target()
			return true
	wander_target = _clamp_to_world(plant_target.global_position)
	if global_position.distance_to(plant_target.global_position) <= vegetation_consume_range:
		_set_state(State.EAT)
		state_time = eat_duration_seconds
	return true


func _set_nearest_plant_target(search_range: float = vegetation_eat_range) -> bool:
	if target_lock_time > 0.0 and is_instance_valid(plant_target) and _is_edible_vegetation_target(plant_target):
		wander_target = _clamp_to_world(plant_target.global_position)
		return true
	plant_target = _find_nearest_edible_vegetation(search_range)
	if not is_instance_valid(plant_target):
		return false
	wander_target = _clamp_to_world(plant_target.global_position)
	target_lock_time = _get_target_lock_seconds()
	return true


func _get_food_search_range() -> float:
	var base_range: float = max(vegetation_eat_range, hunger_diet.get_food_search_radius())
	if hunger_diet.is_starving():
		base_range *= 1.18
	if hunger_diet.is_desperate():
		base_range *= 1.28
	return base_range


func _find_nearest_edible_vegetation(search_range: float) -> Node2D:
	var current_biome_id := _get_current_biome_id()
	var world_query: Variant = _get_world_query()
	if world_query and world_query.has_method("get_edible_vegetation_near"):
		var world_targets: Array = world_query.get_edible_vegetation_near(global_position, search_range, current_biome_id)
		for target_value in world_targets:
			var target := target_value as Node2D
			if is_instance_valid(target) and _is_edible_vegetation_target(target):
				return target

	var nearest: Node2D
	var nearest_distance := search_range
	var candidates := _get_nearby_resources(search_range, [
		"bush",
		"dry_bush",
		"small_bush",
		"berry_bush"
	])
	for vegetation in candidates:
		if not _is_edible_vegetation_target(vegetation):
			continue
		var distance := global_position.distance_to(vegetation.global_position)
		if vegetation.is_in_group("pond_vegetation"):
			distance *= 0.75
		if _get_biome_id_for_position(vegetation.global_position) != current_biome_id:
			distance *= 1.8
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = vegetation
	return nearest


func _is_edible_vegetation_target(vegetation: Node) -> bool:
	return is_instance_valid(vegetation) and vegetation is Node2D and vegetation.get("is_edible_by_herbivores") == true


func _pick_wander_target() -> void:
	var preferred_biome_id := _get_preferred_wander_biome_id()
	for _attempt in 24:
		var candidate := global_position + Vector2(
			rng.randf_range(-wander_radius, wander_radius),
			rng.randf_range(-wander_radius, wander_radius)
		)
		candidate = _clamp_target_distance(candidate, MAX_WANDER_TARGET_DISTANCE)
		if _is_navigation_position_valid(candidate) and _is_position_in_biome(candidate, preferred_biome_id):
			wander_target = _clamp_to_world(candidate)
			return
	for _attempt in 12:
		var candidate := global_position + Vector2(
			rng.randf_range(-wander_radius, wander_radius),
			rng.randf_range(-wander_radius, wander_radius)
		)
		candidate = _clamp_target_distance(candidate, MAX_WANDER_TARGET_DISTANCE)
		if _is_navigation_position_valid(candidate):
			wander_target = _clamp_to_world(candidate)
			return
	var limits := WORLD_CONFIG.get_player_limits()
	wander_target = _clamp_to_world(_clamp_target_distance(Vector2(
		clamp(global_position.x + rng.randf_range(-wander_radius, wander_radius), -limits.x, limits.x),
		clamp(global_position.y + rng.randf_range(-wander_radius, wander_radius), -limits.y, limits.y)
	), MAX_WANDER_TARGET_DISTANCE))


func _get_preferred_wander_biome_id() -> String:
	var current_biome_id := _get_current_biome_id()
	if home_biome_id.is_empty():
		home_biome_id = current_biome_id
	if not home_biome_id.is_empty() and current_biome_id != home_biome_id and rng.randf() < biome_return_chance:
		return home_biome_id
	if rng.randf() < 0.82:
		return current_biome_id
	return home_biome_id


func _is_navigation_position_valid(nav_position: Vector2) -> bool:
	var clamped_position := _clamp_to_world(nav_position)
	if clamped_position.distance_squared_to(nav_position) > 0.01:
		return false
	var world_query: Variant = _get_world_query()
	if world_query and world_query.has_method("is_creature_navigation_blocked") and world_query.is_creature_navigation_blocked(nav_position) == true:
		return false
	for wall in _get_cached_group_nodes("walls"):
		var wall_node := wall as Node2D
		if is_instance_valid(wall_node) and nav_position.distance_to(wall_node.global_position) < wall_avoid_radius * 0.72:
			return false
	return true


func debug_return_to_world() -> void:
	_enforce_world_bounds(true)


func _enforce_world_bounds(force_retarget := false) -> void:
	var clamped_position := _clamp_to_world(global_position)
	if force_retarget or clamped_position.distance_squared_to(global_position) > 0.01:
		global_position = clamped_position
		velocity = Vector2.ZERO
		plant_target = null
		decision_reason = "world_bounds_retarget"
		_set_state(State.WANDER)
		_pick_wander_target()


func _get_bounded_flee_target(away: Vector2) -> Vector2:
	var direction := away.normalized()
	if direction.length_squared() <= 0.0:
		direction = Vector2.RIGHT
	var candidates := [
		direction,
		direction.rotated(0.62),
		direction.rotated(-0.62),
		direction.rotated(1.18),
		direction.rotated(-1.18),
		direction.rotated(PI * 0.5),
		direction.rotated(-PI * 0.5)
	]
	for candidate_direction in candidates:
		var candidate := _clamp_to_world(_clamp_target_distance(global_position + candidate_direction * wander_radius, MAX_FLEE_TARGET_DISTANCE))
		if candidate.distance_squared_to(global_position) > 16.0 and _is_navigation_position_valid(candidate):
			return candidate
	return _clamp_to_world(_clamp_target_distance(global_position + direction * wander_radius * 0.45, MAX_FLEE_TARGET_DISTANCE))


func _clamp_to_world(world_point: Vector2) -> Vector2:
	var rect := _get_world_rect()
	return Vector2(
		clamp(world_point.x, rect.position.x, rect.end.x),
		clamp(world_point.y, rect.position.y, rect.end.y)
	)


func _clamp_target_distance(target: Vector2, max_distance: float) -> Vector2:
	var offset := target - global_position
	if offset.length() <= max_distance:
		return target
	return global_position + offset.normalized() * max_distance


func _record_movement_spike(previous_position: Vector2) -> void:
	var moved_distance := global_position.distance_to(previous_position)
	if moved_distance <= LARGE_MOVEMENT_WARNING_DISTANCE:
		return
	movement_spike_count += 1
	max_movement_spike_distance = maxf(max_movement_spike_distance, moved_distance)
	push_warning("SmallPrey movement spike: %.1f px" % moved_distance)


func _get_world_rect() -> Rect2:
	return WORLD_CONFIG.WORLD_RECT.grow(-world_edge_padding)


func _get_terrain_speed_multiplier() -> float:
	var world_query: Variant = _get_world_query()
	if world_query and world_query.has_method("get_terrain_speed_multiplier"):
		return float(world_query.get_terrain_speed_multiplier(global_position))
	return 1.0


func _get_world_query():
	var world := _get_world_node()
	if world and world.has_method("get_query_service"):
		return world.get_query_service()
	return world


func _set_state(next_state: State) -> void:
	if next_state == State.FLEE:
		state_time = maxf(state_time, flee_duration_seconds)
	if state == next_state:
		return
	state = next_state
	queue_redraw()


func _die(source: String) -> void:
	state = State.DEAD
	_drop_meat_once()
	var event_name := "small_prey_killed_by_player"
	if source == "varnak":
		event_name = "small_prey_killed_by_varnak"
	elif source == "grazer":
		event_name = "small_prey_killed_by_grazer"
	_emit_game_event(event_name, {
		"biome_id": _get_current_biome_id(),
		"species_id": species_id,
		"generation": generation,
		"fitness_score": _get_fitness_score(),
		"position": global_position,
		"source": source
	})
	_post_event_message("Small prey killed")
	queue_free()


func _drop_meat_once() -> void:
	if dropped_meat:
		return
	dropped_meat = true
	var world := get_tree().current_scene.get_node_or_null("World")
	if world and world.has_method("spawn_meat_drop_for_animal"):
		world.spawn_meat_drop_for_animal("small_prey", global_position)


func _load_species_data() -> void:
	if not FileAccess.file_exists(SPECIES_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPECIES_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var profile := Dictionary(parsed)
	species_id = str(profile.get("species_id", profile.get("id", species_id)))
	species_name = str(profile.get("species_name", profile.get("display_name", species_name)))
	generation = max(int(profile.get("generation", generation)), 1)
	var traits: Variant = profile.get("base_traits", {})
	if typeof(traits) != TYPE_DICTIONARY:
		return
	var base_traits := Dictionary(traits)
	max_health = float(base_traits.get("health", max_health))
	health = max_health
	speed = float(base_traits.get("speed", speed))
	fear = float(base_traits.get("fear", fear))
	hunger_growth_rate = float(base_traits.get("hunger_growth_rate", base_traits.get("hunger_rate", hunger_growth_rate)))
	max_hunger = float(base_traits.get("max_hunger", max_hunger))
	energy = float(base_traits.get("energy", energy))
	plant_diet = float(base_traits.get("plant_diet", plant_diet))
	meat_diet = float(base_traits.get("meat_diet", meat_diet))
	scavenger_diet = float(base_traits.get("scavenger_diet", scavenger_diet))
	plant_consumption_rate = float(base_traits.get("plant_consumption_rate", plant_consumption_rate))
	reproduction_value = float(base_traits.get("reproduction_rate", base_traits.get("reproduction_value", reproduction_value)))
	hunger_diet.configure(base_traits, {
		"max_hunger": max_hunger,
		"hunger_growth_rate": hunger_growth_rate,
		"energy": energy,
		"plant_diet": plant_diet,
		"meat_diet": meat_diet,
		"scavenger_diet": scavenger_diet,
		"hungry_threshold": GAME_BALANCE.ANIMAL_AI.get("hungry_threshold", 0.35),
		"starving_threshold": GAME_BALANCE.ANIMAL_AI.get("starving_threshold", 0.60),
		"desperate_threshold": GAME_BALANCE.ANIMAL_AI.get("desperate_threshold", 0.82)
	})
	_sync_hunger_fields()


func _sync_hunger_fields() -> void:
	hunger = hunger_diet.hunger
	max_hunger = hunger_diet.max_hunger
	hunger_growth_rate = hunger_diet.hunger_growth_rate
	energy = hunger_diet.energy
	plant_diet = hunger_diet.plant_diet
	meat_diet = hunger_diet.meat_diet
	scavenger_diet = hunger_diet.scavenger_diet


func _sync_population_traits() -> void:
	var ecosystem := get_tree().current_scene.get_node_or_null("EcosystemDirector")
	if not ecosystem or not ecosystem.has_method("get_small_prey_traits"):
		return
	var traits: Dictionary = ecosystem.get_small_prey_traits(_get_current_biome_id())
	if traits.is_empty():
		return
	generation = max(int(traits.get("generation", generation)), 1)
	population_biome_id = str(traits.get("biome_id", population_biome_id))
	fear = clamp(float(traits.get("fear", fear)), 0.0, 2.0)
	speed = max(float(traits.get("speed", speed)), 1.0)
	reproduction_value = clamp(float(traits.get("reproduction_value", reproduction_value)), 0.0, 1.5)
	plant_diet = clamp(float(traits.get("plant_diet", plant_diet)), 0.0, 1.0)
	hunger_diet.plant_diet = plant_diet


func _get_current_target_label() -> String:
	if is_instance_valid(plant_target):
		return "plant"
	if state == State.FLEE:
		return "threat"
	if state == State.WANDER:
		return "wander"
	return "none"


func _get_target_lock_seconds() -> float:
	return float(GAME_BALANCE.ANIMAL_AI.get("target_lock_seconds", 0.85))


func _get_failed_food_retarget_seconds() -> float:
	return float(GAME_BALANCE.ANIMAL_AI.get("failed_food_retarget_seconds", 0.55))


func _get_fitness_score() -> float:
	var health_ratio: float = clamp(health / max(max_health, 1.0), 0.0, 1.0)
	return clamp(health_ratio * 0.45 + (1.0 - hunger_diet.get_hunger_ratio()) * 0.35 + energy * 0.20, 0.0, 1.0)


func _get_current_biome_id() -> String:
	var current_biome_id := _get_biome_id_for_position(global_position)
	if not current_biome_id.is_empty():
		biome_id = current_biome_id
		population_biome_id = current_biome_id
	return biome_id


func _get_biome_id_for_position(pos: Vector2) -> String:
	var world := _get_world()
	if world != null and world.has_method("get_biome_id_at"):
		return str(world.get_biome_id_at(pos))
	for biome in WORLD_CONFIG.get_biome_zones():
		if Geometry2D.is_point_in_polygon(pos, PackedVector2Array(biome["points"])):
			return _get_biome_id(biome)
	return ""


func _is_position_in_biome(pos: Vector2, target_biome_id: String) -> bool:
	if target_biome_id.is_empty():
		return WORLD_CONFIG.WORLD_RECT.has_point(pos)
	for biome in WORLD_CONFIG.get_biome_zones():
		if _get_biome_id(biome) == target_biome_id:
			return Geometry2D.is_point_in_polygon(pos, PackedVector2Array(biome["points"]))
	return false


func _get_biome_id(biome: Dictionary) -> String:
	var biome_id := str(biome.get("id", ""))
	if not biome_id.is_empty():
		return biome_id
	return str(biome.get("name", "biome")).to_snake_case()


func _get_world() -> Node:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.get_node_or_null("World")


func _vector_to_data(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


func _data_to_vector(data: Variant) -> Vector2:
	if typeof(data) != TYPE_DICTIONARY:
		return Vector2.ZERO
	var x_raw: Variant = data.get("x", 0.0)
	var y_raw: Variant = data.get("y", 0.0)
	var x_value := 0.0
	var y_value := 0.0
	if x_raw != null:
		x_value = float(x_raw)
	if y_raw != null:
		y_value = float(y_raw)
	return Vector2(x_value, y_value)


func _draw() -> void:
	var body_color := Color(0.68, 0.58, 0.36)
	var ear_color := Color(0.78, 0.66, 0.42)
	if state == State.EAT:
		body_color = Color(0.62, 0.70, 0.36)
	elif state == State.FLEE:
		body_color = Color(0.86, 0.50, 0.28)
	draw_set_transform(Vector2.ZERO, clamp(sin(facing_angle), -1.0, 1.0) * 0.12, Vector2(facing_side, 1.0))
	draw_circle(Vector2(-5, 0), 10.0, body_color)
	draw_circle(Vector2(7, -2), 7.0, body_color.lightened(0.12))
	draw_polygon([Vector2(2, -8), Vector2(4, -20), Vector2(9, -7)], [ear_color])
	draw_polygon([Vector2(10, -7), Vector2(16, -18), Vector2(16, -4)], [ear_color.lightened(0.08)])
	draw_circle(Vector2(10, -4), 1.8, Color(0.03, 0.02, 0.01))
	draw_line(Vector2(-12, 5), Vector2(-22, 10), Color(0.28, 0.20, 0.11), 3.0)
	draw_line(Vector2(-4, 8), Vector2(-8, 16), Color(0.22, 0.15, 0.08), 2.0)
	draw_line(Vector2(4, 7), Vector2(8, 15), Color(0.22, 0.15, 0.08), 2.0)
	_draw_eating_visual()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_debug_stat_frame()


func _draw_eating_visual() -> void:
	if eat_visual_time <= 0.0:
		return
	var progress := eat_visual_time / eat_visual_duration
	var alpha := 0.28 + progress * 0.42
	var bite_color := Color(0.58, 0.96, 0.30, alpha)
	draw_arc(Vector2(14, -2), 7.0 + progress * 2.4, -0.85, 0.85, 8, bite_color, 2.0)
	draw_circle(Vector2(19, -6), 1.8 + progress, bite_color)
	draw_circle(Vector2(18, 4), 1.4 + progress * 0.8, bite_color.lightened(0.18))


func _draw_debug_stat_frame() -> void:
	if not _is_debug_overlay_visible():
		return
	var satiety_percent := int(round((1.0 - hunger_diet.get_hunger_ratio()) * 100.0))
	var lines: Array[String] = [
		"%s G%d" % [species_name, generation],
		"HP %d/%d Sat %d%%" % [int(health), int(max_health), satiety_percent],
		"E %d%% Act %s" % [int(round(energy * 100.0)), _get_debug_action_label()],
		"Target %s" % _get_current_target_label(),
		"Why %s" % decision_reason,
		"Last %s" % _get_debug_food_label()
	]
	_draw_debug_lines(lines, Vector2(-58.0, -76.0))


func _get_debug_action_label() -> String:
	if eat_visual_time > 0.0:
		return "eating_plants"
	match state:
		State.EAT:
			return "chewing_wait"
		State.SEEK_FOOD:
			return "seeking_plant" if is_instance_valid(plant_target) else "no_plant"
		State.FLEE:
			return "fleeing"
		State.IDLE:
			if hunger_diet.is_starving():
				return "starving_idle"
			if hunger_diet.is_hungry():
				return "hungry_idle"
			return "idle"
		State.WANDER:
			if hunger_diet.is_starving():
				return "starving_no_food"
			if hunger_diet.is_hungry():
				return "hungry_wander"
			return "wandering"
		_:
			return State.keys()[state].to_lower()


func _get_debug_food_label() -> String:
	if last_food_source == "none" or last_food_source.is_empty():
		return "not_yet"
	return last_food_source


func _draw_debug_lines(lines: Array[String], top_left: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	var max_chars := 0
	for line in lines:
		max_chars = max(max_chars, line.length())
	var width: float = max(116.0, float(max_chars) * 6.3 + 12.0)
	var height: float = float(lines.size()) * 13.0 + 10.0
	var rect := Rect2(top_left, Vector2(width, height))
	draw_rect(rect, Color(0.03, 0.05, 0.04, 0.76), true)
	draw_rect(rect, Color(0.60, 0.92, 0.48, 0.86), false, 1.3)
	for i in range(lines.size()):
		draw_string(font, top_left + Vector2(6.0, 15.0 + float(i) * 13.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, DEBUG_FRAME_FONT_SIZE, Color(0.92, 0.96, 0.88))


func _get_world_node() -> Node2D:
	var scene := get_tree().current_scene
	if not scene:
		return null
	return scene.get_node_or_null("World") as Node2D


func _get_cached_group_nodes(group_name: String) -> Array:
	var world := _get_world_node()
	if world and world.has_method("get_cached_group_nodes"):
		return world.get_cached_group_nodes(group_name)
	return get_tree().get_nodes_in_group(group_name)


func _get_nearby_resources(search_range: float, kind_filter: Variant = null) -> Array:
	var world := _get_world_node()
	if world and world.has_method("get_resources_near"):
		return world.get_resources_near(global_position, search_range, kind_filter)
	return _get_cached_group_nodes("edible_vegetation")


func _get_nearby_creatures(search_range: float, creature_type_filter: Variant = null) -> Array:
	var world := _get_world_node()
	if world and world.has_method("get_creatures_near"):
		return world.get_creatures_near(global_position, search_range, creature_type_filter)
	return _get_cached_group_nodes(str(creature_type_filter))


func _update_spatial_cell_tick(delta: float) -> void:
	spatial_update_timer -= delta
	if spatial_update_timer > 0.0:
		return
	spatial_update_timer = SPATIAL_UPDATE_INTERVAL_SECONDS
	_update_spatial_cell()


func _update_spatial_cell() -> void:
	var world := _get_world_node()
	if world and world.has_method("update_spatial_entity_cell"):
		world.update_spatial_entity_cell(self)


func _initialize_from_game_balance() -> void:
	var ai_config := GAME_BALANCE.SMALL_PREY_AI
	wander_radius = float(ai_config.get("wander_radius", 140.0))
	wander_reached_distance = float(ai_config.get("wander_reached_distance", 18.0))
	player_flee_range = float(ai_config.get("player_flee_range", 130.0))
	varnak_flee_range = float(ai_config.get("varnak_flee_range", 180.0))
	flee_duration_seconds = float(ai_config.get("flee_duration_seconds", 3.0))
	eat_interval_seconds = float(ai_config.get("eat_interval_seconds", 6.0))
	eat_duration_seconds = float(ai_config.get("eat_duration_seconds", 1.1))
	eat_visual_duration = float(ai_config.get("eat_visual_duration", 0.48))
	idle_duration_seconds = float(ai_config.get("idle_duration_seconds", 0.8))
	vegetation_eat_range = float(ai_config.get("vegetation_eat_range", 170.0))
	vegetation_consume_range = float(ai_config.get("vegetation_consume_range", 26.0))
	world_edge_padding = float(ai_config.get("world_edge_padding", 24.0))
	avoidance_lookahead_distance = float(ai_config.get("avoidance_lookahead_distance", 46.0))
	wall_avoid_radius = float(ai_config.get("wall_avoid_radius", 58.0))
	biome_return_chance = float(ai_config.get("biome_return_chance", 0.64))


func _is_debug_overlay_visible() -> bool:
	var scene := get_tree().current_scene
	if not scene:
		return false
	var debug_panel := scene.get_node_or_null("HUD/DebugPanel")
	return is_instance_valid(debug_panel) and debug_panel.visible
