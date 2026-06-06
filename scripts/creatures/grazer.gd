extends CharacterBody2D

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const HUNGER_DIET := preload("res://scripts/creatures/hunger_diet.gd")
const SPECIES_PATH := "res://data/species/grazer.json"
const AI_DECISION_INTERVAL_SECONDS := 0.14

enum State { IDLE, WANDER, EAT_PLANTS, SEEK_FOOD, FLEE, SCAVENGE, HUNT_SMALL_PREY, DEAD }

var wander_radius := 0.0
var wander_reached_distance := 0.0
var player_flee_range := 0.0
var varnak_flee_range := 0.0
var flee_duration_seconds := 0.0
var low_biomass_percent := 0.0
var eat_duration_seconds := 0.0
var eat_visual_duration := 0.0
var idle_duration_seconds := 0.0
var small_prey_detect_range := 0.0
var small_prey_attack_range := 0.0
var plant_eat_hunger_drop := 0.0
var meat_hunger_drop := 0.0
var vegetation_eat_range := 0.0
var vegetation_consume_range := 0.0
var meat_eat_range := 0.0
var meat_consume_range := 0.0
var world_edge_padding := 0.0
var avoidance_lookahead_distance := 0.0
var wall_avoid_radius := 0.0
var biome_return_chance := 0.0
const DEBUG_FRAME_FONT_SIZE := 11

var species_id := "grazer"
var species_name := "Grazer"
var generation := 1
var health := 45.0
var max_health := 45.0
var speed := 70.0
var fear := 0.7
var aggression := 0.15
var hunger := 0.0
var max_hunger := 1.0
var hunger_growth_rate := 0.3
var energy := 1.0
var age_seconds := 0.0
var plant_consumption_rate := 1.2
var plant_diet := 0.85
var meat_diet := 0.05
var scavenger_diet := 0.10
var current_niche := "HERBIVORE"
var size := 1.35
var reproduction_rate := 0.35
var state := State.WANDER
var biome_id := ""
var home_biome_id := ""
var population_biome_id := ""
var wander_target := Vector2.ZERO
var state_time := 0.0
var eat_visual_time := 0.0
var target_lock_time := 0.0
var facing_angle := 0.0
var facing_side := 1.0
var player: Node2D
var flee_origin := Vector2.INF
var prey_target: Node2D
var plant_target: Node2D
var meat_target: Node2D
var dropped_meat := false
var last_food_source := "none"
var decision_reason := "spawn"
var ai_decision_timer := 0.0
var rng := RandomNumberGenerator.new()
var hunger_diet := HUNGER_DIET.new()

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("grazer")
	rng.randomize()
	player = get_tree().get_first_node_in_group("player")
	_initialize_from_game_balance()
	_load_species_data()
	if biome_id.is_empty():
		biome_id = _get_biome_id_for_position(global_position)
	if home_biome_id.is_empty():
		home_biome_id = biome_id
	ai_decision_timer = rng.randf_range(0.0, AI_DECISION_INTERVAL_SECONDS)
	_pick_wander_target()
	queue_redraw()


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
		"aggression": aggression,
		"age_seconds": age_seconds,
		"fatigue": 1.0 - energy,
		"rest": energy,
		"current_target": _get_current_target_label(),
		"decision_reason": decision_reason,
		"last_food_source": last_food_source,
		"fitness_score": _get_fitness_score(),
		"current_niche": current_niche,
		"reproduction_rate": reproduction_rate,
		"home_biome_id": home_biome_id,
		"distance_to_player": global_position.distance_to(player.global_position) if is_instance_valid(player) else -1.0
	}
	data.merge(hunger_diet.get_debug_data(), true)
	return data


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
		"aggression": aggression,
		"hunger": hunger,
		"max_hunger": max_hunger,
		"hunger_growth_rate": hunger_growth_rate,
		"energy": energy,
		"age_seconds": age_seconds,
		"plant_consumption_rate": plant_consumption_rate,
		"plant_diet": plant_diet,
		"meat_diet": meat_diet,
		"scavenger_diet": scavenger_diet,
		"current_niche": current_niche,
		"size": size,
		"reproduction_rate": reproduction_rate,
		"state": int(state),
		"biome_id": biome_id,
		"home_biome_id": home_biome_id,
		"population_biome_id": population_biome_id,
		"wander_target": _vector_to_data(wander_target),
		"state_time": state_time,
		"last_food_source": last_food_source,
		"dropped_meat": dropped_meat
	}


func restore_from_data(data: Dictionary) -> void:
	species_id = str(data.get("species_id", species_id))
	species_name = str(data.get("species_name", species_name))
	generation = max(int(data.get("generation", generation)), 1)
	global_position = _clamp_to_world(_data_to_vector(data.get("position", {})))
	facing_angle = float(data.get("facing_angle", facing_angle))
	facing_side = float(data.get("facing_side", facing_side))
	max_health = max(float(data.get("max_health", max_health)), 1.0)
	health = clamp(float(data.get("health", health)), 0.0, max_health)
	speed = float(data.get("speed", speed))
	fear = float(data.get("fear", fear))
	aggression = float(data.get("aggression", aggression))
	max_hunger = max(float(data.get("max_hunger", max_hunger)), 0.01)
	hunger = clamp(float(data.get("hunger", hunger)), 0.0, max_hunger)
	hunger_growth_rate = float(data.get("hunger_growth_rate", hunger_growth_rate))
	energy = clamp(float(data.get("energy", energy)), 0.0, 1.0)
	age_seconds = max(float(data.get("age_seconds", age_seconds)), 0.0)
	plant_consumption_rate = float(data.get("plant_consumption_rate", plant_consumption_rate))
	plant_diet = float(data.get("plant_diet", plant_diet))
	meat_diet = float(data.get("meat_diet", meat_diet))
	scavenger_diet = float(data.get("scavenger_diet", scavenger_diet))
	current_niche = str(data.get("current_niche", current_niche))
	size = float(data.get("size", size))
	reproduction_rate = float(data.get("reproduction_rate", reproduction_rate))
	state = int(data.get("state", State.WANDER))
	if state == State.DEAD:
		state = State.WANDER
	biome_id = str(data.get("biome_id", biome_id))
	home_biome_id = str(data.get("home_biome_id", home_biome_id))
	population_biome_id = str(data.get("population_biome_id", population_biome_id))
	wander_target = _clamp_to_world(_data_to_vector(data.get("wander_target", _vector_to_data(wander_target))))
	state_time = max(float(data.get("state_time", state_time)), 0.0)
	last_food_source = str(data.get("last_food_source", last_food_source))
	dropped_meat = data.get("dropped_meat", dropped_meat) == true
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
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	state_time = max(state_time - delta, 0.0)
	target_lock_time = max(target_lock_time - delta, 0.0)
	if eat_visual_time > 0.0:
		eat_visual_time = max(eat_visual_time - delta, 0.0)
		queue_redraw()
	age_seconds += delta
	hunger_diet.tick(delta, velocity.length() / max(speed, 1.0))
	_sync_hunger_fields()
	if _should_update_ai_decision(delta):
		_update_state()
	_act(delta)
	move_and_slide()
	_enforce_world_bounds()


func _should_update_ai_decision(delta: float) -> bool:
	ai_decision_timer -= delta
	if ai_decision_timer > 0.0:
		return false
	ai_decision_timer = AI_DECISION_INTERVAL_SECONDS
	return true


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
		plant_target = null
		meat_target = null
	_sync_population_traits()
	var biomass_percent := _get_current_biomass_percent()
	if state == State.EAT_PLANTS:
		decision_reason = "eating_target_plant"
		if state_time <= 0.0:
			_consume_plants()
			decision_reason = "finished_eating"
			_set_state(State.WANDER)
			_pick_wander_target()
		return
	if state == State.SEEK_FOOD and _try_update_plant_target():
		decision_reason = "locked_plant_target" if is_instance_valid(plant_target) else decision_reason
		return
	if state == State.SCAVENGE and _try_update_meat_target():
		decision_reason = "locked_meat_target" if is_instance_valid(meat_target) else decision_reason
		return
	if state == State.HUNT_SMALL_PREY:
		if not is_instance_valid(prey_target):
			decision_reason = "prey_lost_seek_food"
			_set_state(State.SEEK_FOOD)
		else:
			decision_reason = "hunting_small_prey"
		return
	var food_search_range := _get_food_search_range()
	var nearest_plant := _find_nearest_edible_vegetation(food_search_range)
	var nearest_prey := _find_nearest_small_prey()
	var nearest_meat := _find_nearest_meat_drop(food_search_range)
	var hunger_stage := hunger_diet.get_hunger_stage()
	var risk_drive: float = hunger_diet.get_risk_drive()
	if hunger_stage == "hungry" and is_instance_valid(nearest_plant):
		decision_reason = "hungry_prefer_plants"
		plant_target = nearest_plant
		meat_target = null
		prey_target = null
		wander_target = _clamp_to_world(plant_target.global_position)
		_set_state(State.SEEK_FOOD)
		return
	if hunger_stage == "hungry" and _can_hunt_small_prey(nearest_plant, nearest_prey, risk_drive):
		decision_reason = "hungry_no_plants_predation"
		prey_target = nearest_prey
		plant_target = null
		meat_target = null
		_set_state(State.HUNT_SMALL_PREY)
		return
	if hunger_stage == "hungry" and not is_instance_valid(nearest_plant) and _set_nearest_meat_target(food_search_range):
		decision_reason = "hungry_scavenge_no_plants"
		plant_target = null
		prey_target = null
		_set_state(State.SCAVENGE)
		return
	if hunger_stage == "hungry" and biomass_percent >= low_biomass_percent:
		if _set_nearest_plant_target(food_search_range):
			decision_reason = "hungry_biomass_seek_plant"
			_set_state(State.SEEK_FOOD)
		else:
			decision_reason = "hungry_no_food_wander"
			_set_state(State.WANDER)
			_pick_wander_target()
		return
	if hunger_diet.is_starving():
		if is_instance_valid(nearest_plant):
			decision_reason = "starving_still_prefers_plant"
			plant_target = nearest_plant
			meat_target = null
			prey_target = null
			wander_target = _clamp_to_world(plant_target.global_position)
			_set_state(State.SEEK_FOOD)
			return
		if _can_hunt_small_prey(nearest_plant, nearest_prey, risk_drive):
			decision_reason = "starving_predation_allowed"
			prey_target = nearest_prey
			plant_target = null
			meat_target = null
			_set_state(State.HUNT_SMALL_PREY)
			return
		if _set_nearest_meat_target(food_search_range):
			decision_reason = "starving_scavenge"
			plant_target = null
			prey_target = null
			_set_state(State.SCAVENGE)
			return
		decision_reason = "starving_no_food"
		_set_state(State.SEEK_FOOD)
		return
	match state:
		State.IDLE:
			if state_time <= 0.0:
				decision_reason = "idle_complete"
				_set_state(State.WANDER)
				_pick_wander_target()
		State.WANDER, State.SEEK_FOOD:
			if global_position.distance_to(wander_target) < wander_reached_distance:
				decision_reason = "wander_target_reached"
				_set_state(State.IDLE)
				state_time = idle_duration_seconds


func _act(_delta: float) -> void:
	match state:
		State.IDLE, State.EAT_PLANTS:
			velocity = Vector2.ZERO
		State.WANDER:
			_move_toward(wander_target, speed * 0.55)
		State.SEEK_FOOD:
			_move_toward(wander_target, speed * 0.72)
		State.FLEE:
			var away := (global_position - flee_origin).normalized()
			var flee_target := _get_bounded_flee_target(away)
			_move_toward(flee_target, speed * (1.0 + fear))
		State.HUNT_SMALL_PREY:
			_hunt_small_prey()
		State.SCAVENGE:
			if is_instance_valid(meat_target):
				_move_toward(meat_target.global_position, speed * 0.64)
			else:
				velocity = Vector2.ZERO


func _hunt_small_prey() -> void:
	if not is_instance_valid(prey_target):
		velocity = Vector2.ZERO
		return
	var distance := global_position.distance_to(prey_target.global_position)
	if distance <= small_prey_attack_range and prey_target.has_method("take_damage"):
		prey_target.take_damage(999.0, "grazer")
		_eat_emergency_meat(meat_hunger_drop)
		_sync_hunger_fields()
		eat_visual_time = eat_visual_duration
		last_food_source = "small_prey_meat"
		get_node("/root/EventBus").emit_game_event("grazer_hunted_small_prey", {
			"biome_id": _get_current_biome_id(),
			"position": global_position
		})
		prey_target = null
		_set_state(State.WANDER)
		_pick_wander_target()
		return
	_move_toward(prey_target.global_position, speed * (0.9 + aggression))


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
	var adjusted_direction := (desired_direction + avoidance * 1.2).normalized()
	if _is_navigation_position_valid(global_position + adjusted_direction * avoidance_lookahead_distance):
		return adjusted_direction
	var candidates := [
		desired_direction.rotated(0.68),
		desired_direction.rotated(-0.68),
		desired_direction.rotated(1.18),
		desired_direction.rotated(-1.18),
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


func _consume_plants() -> void:
	var eaten_food := _consume_target_vegetation()
	if eaten_food <= 0.0:
		plant_target = null
		return
	var biomass_impact := plant_consumption_rate
	hunger_diet.eat("plants", max(plant_eat_hunger_drop, eaten_food))
	_sync_hunger_fields()
	eat_visual_time = eat_visual_duration
	last_food_source = "plants"
	get_node("/root/EventBus").emit_game_event("grazer_consumed_plants", {
		"biome_id": _get_current_biome_id(),
		"position": global_position,
		"plant_consumption_rate": plant_consumption_rate,
		"biomass_impact": biomass_impact
	})
	plant_target = null


func _consume_target_vegetation() -> float:
	if is_instance_valid(plant_target) and _is_edible_vegetation_target(plant_target):
		var distance := global_position.distance_to(plant_target.global_position)
		if distance <= _get_vegetation_consume_distance(plant_target) and plant_target.has_method("consume_by_creature"):
			return float(plant_target.consume_by_creature(self, plant_consumption_rate))
	return _consume_nearest_vegetation()


func _consume_nearest_vegetation() -> float:
	var nearest := _find_nearest_consumable_vegetation()
	if not is_instance_valid(nearest) or not nearest.has_method("consume_by_creature"):
		return 0.0
	return float(nearest.consume_by_creature(self, plant_consumption_rate))


func _try_update_plant_target() -> bool:
	if not is_instance_valid(plant_target) or not _is_edible_vegetation_target(plant_target):
		if not _set_nearest_plant_target(_get_food_search_range()):
			_set_state(State.WANDER)
			_pick_wander_target()
			return true
	wander_target = _clamp_to_world(plant_target.global_position)
	if global_position.distance_to(plant_target.global_position) <= _get_vegetation_consume_distance(plant_target):
		_set_state(State.EAT_PLANTS)
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
		base_range *= 1.12
	if hunger_diet.is_desperate():
		base_range *= 1.25
	return base_range


func _find_nearest_edible_vegetation(search_range: float) -> Node2D:
	var nearest: Node2D
	var nearest_distance := search_range
	var current_biome_id := _get_current_biome_id()
	for vegetation in _get_cached_group_nodes("edible_vegetation"):
		if not _is_edible_vegetation_target(vegetation):
			continue
		var distance := global_position.distance_to(vegetation.global_position)
		if vegetation.is_in_group("pond_vegetation"):
			distance *= 0.68
		if _get_biome_id_for_position(vegetation.global_position) != current_biome_id:
			distance *= 1.6
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = vegetation
	return nearest


func _find_nearest_consumable_vegetation() -> Node2D:
	var nearest: Node2D
	var nearest_distance := INF
	for vegetation in _get_cached_group_nodes("edible_vegetation"):
		if not _is_edible_vegetation_target(vegetation):
			continue
		var distance := global_position.distance_to(vegetation.global_position)
		if distance > _get_vegetation_consume_distance(vegetation):
			continue
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = vegetation
	return nearest


func _is_edible_vegetation_target(vegetation: Node) -> bool:
	return is_instance_valid(vegetation) and vegetation is Node2D and vegetation.get("is_edible_by_herbivores") == true


func _get_vegetation_consume_distance(vegetation: Node2D) -> float:
	var vegetation_radius := _get_target_radius(vegetation)
	return vegetation_consume_range + vegetation_radius * 0.5


func _get_target_radius(target: Node2D) -> float:
	if not is_instance_valid(target):
		return 0.0
	var radius_value: Variant = target.get("radius")
	if typeof(radius_value) not in [TYPE_FLOAT, TYPE_INT]:
		return 0.0
	return max(float(radius_value), 0.0)


func _can_hunt_small_prey(nearest_plant: Node2D, nearest_prey: Node2D, risk_drive: float) -> bool:
	if is_instance_valid(nearest_plant):
		return false
	if not is_instance_valid(nearest_prey):
		return false
	if not hunger_diet.is_starving():
		return false
	if hunger_diet.is_desperate():
		return true
	var required_drive := float(GAME_BALANCE.ANIMAL_AI.get("grazer_predation_min_drive", 0.82))
	var required_aggression := float(GAME_BALANCE.ANIMAL_AI.get("grazer_predation_min_aggression", 0.22))
	return current_niche == "OMNIVORE" and risk_drive >= required_drive and aggression + meat_diet >= required_aggression


func _try_update_meat_target() -> bool:
	if not is_instance_valid(meat_target) or not _is_meat_drop_target(meat_target):
		if not _set_nearest_meat_target(_get_food_search_range()):
			_set_state(State.WANDER)
			_pick_wander_target()
			return true
	wander_target = _clamp_to_world(meat_target.global_position)
	if global_position.distance_to(meat_target.global_position) <= meat_consume_range:
		_consume_meat_target()
		_set_state(State.WANDER)
		_pick_wander_target()
	return true


func _set_nearest_meat_target(search_range: float = meat_eat_range) -> bool:
	if not _can_eat_meat_drop():
		meat_target = null
		return false
	if target_lock_time > 0.0 and is_instance_valid(meat_target) and _is_meat_drop_target(meat_target):
		wander_target = _clamp_to_world(meat_target.global_position)
		return true
	meat_target = _find_nearest_meat_drop(search_range)
	if not is_instance_valid(meat_target):
		return false
	wander_target = _clamp_to_world(meat_target.global_position)
	target_lock_time = _get_target_lock_seconds()
	return true


func _find_nearest_meat_drop(search_range: float) -> Node2D:
	var nearest: Node2D
	var nearest_distance := search_range
	for resource in _get_cached_group_nodes("meat_drops"):
		if not is_instance_valid(resource):
			continue
		if not (resource is Node2D):
			continue
		var meat_drop := resource as Node2D
		if not is_instance_valid(meat_drop) or not _is_meat_drop_target(meat_drop):
			continue
		var distance := global_position.distance_to(meat_drop.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = meat_drop
	return nearest


func _is_meat_drop_target(resource: Node) -> bool:
	if not is_instance_valid(resource):
		return false
	var meat_drop := resource as Node2D
	if meat_drop == null:
		return false
	return meat_drop.get("resource_kind") == "meat_drop" and int(meat_drop.get("amount")) > 0


func _can_eat_meat_drop() -> bool:
	return meat_diet > 0.0 or scavenger_diet > 0.0


func _get_meat_food_kind() -> String:
	return "scavenger" if scavenger_diet >= meat_diet else "meat"


func _consume_meat_target() -> void:
	if not is_instance_valid(meat_target) or not _is_meat_drop_target(meat_target) or not meat_target.has_method("consume_by_creature"):
		meat_target = null
		return
	var eaten_food := float(meat_target.consume_by_creature(self, 1.0))
	if eaten_food <= 0.0:
		meat_target = null
		return
	_eat_emergency_meat(max(meat_hunger_drop, eaten_food))
	_sync_hunger_fields()
	eat_visual_time = eat_visual_duration
	last_food_source = "meat_drop"
	get_node("/root/EventBus").emit_game_event("grazer_scavenged", {
		"biome_id": _get_current_biome_id(),
		"position": global_position,
		"food_source": "meat_drop",
		"nutrition": eaten_food
	})
	meat_target = null


func _eat_emergency_meat(nutrition: float) -> void:
	var before_hunger := hunger_diet.hunger
	var preferred_reduction := hunger_diet.eat(_get_meat_food_kind(), nutrition)
	var minimum_reduction := nutrition * 0.38
	if preferred_reduction < minimum_reduction:
		hunger_diet.hunger = max(before_hunger - minimum_reduction, 0.0)


func _get_flee_origin() -> Vector2:
	var nearest_origin := Vector2.INF
	var nearest_distance := INF
	if is_instance_valid(player):
		var player_distance := global_position.distance_to(player.global_position)
		if player_distance < player_flee_range * fear and aggression < 0.45:
			nearest_origin = player.global_position
			nearest_distance = player_distance
	for varnak in _get_cached_group_nodes("varnak"):
		if not is_instance_valid(varnak):
			continue
		var distance := global_position.distance_to(varnak.global_position)
		if distance < varnak_flee_range * fear and distance < nearest_distance:
			nearest_origin = varnak.global_position
			nearest_distance = distance
	return nearest_origin


func _find_nearest_small_prey() -> Node2D:
	var nearest: Node2D
	var nearest_distance := INF
	for small_prey in _get_cached_group_nodes("small_prey"):
		if not is_instance_valid(small_prey):
			continue
		var distance := global_position.distance_to(small_prey.global_position)
		if distance < small_prey_detect_range and distance < nearest_distance:
			nearest = small_prey
			nearest_distance = distance
	return nearest


func _pick_wander_target() -> void:
	var preferred_biome_id := _get_preferred_wander_biome_id()
	for _attempt in 24:
		var candidate := global_position + Vector2(
			rng.randf_range(-wander_radius, wander_radius),
			rng.randf_range(-wander_radius, wander_radius)
		)
		if _is_navigation_position_valid(candidate) and _is_position_in_biome(candidate, preferred_biome_id):
			wander_target = _clamp_to_world(candidate)
			return
	for _attempt in 12:
		var candidate := global_position + Vector2(
			rng.randf_range(-wander_radius, wander_radius),
			rng.randf_range(-wander_radius, wander_radius)
		)
		if _is_navigation_position_valid(candidate):
			wander_target = _clamp_to_world(candidate)
			return
	var limits := WORLD_CONFIG.get_player_limits()
	wander_target = _clamp_to_world(Vector2(
		clamp(global_position.x + rng.randf_range(-wander_radius, wander_radius), -limits.x, limits.x),
		clamp(global_position.y + rng.randf_range(-wander_radius, wander_radius), -limits.y, limits.y)
	))


func _get_preferred_wander_biome_id() -> String:
	var current_biome_id := _get_current_biome_id()
	if home_biome_id.is_empty():
		home_biome_id = current_biome_id
	if not home_biome_id.is_empty() and current_biome_id != home_biome_id and rng.randf() < biome_return_chance:
		return home_biome_id
	if rng.randf() < 0.76:
		return current_biome_id
	return home_biome_id


func _is_navigation_position_valid(position: Vector2) -> bool:
	var clamped_position := _clamp_to_world(position)
	if clamped_position.distance_squared_to(position) > 0.01:
		return false
	var world_query: Variant = _get_world_query()
	if world_query and world_query.has_method("is_creature_navigation_blocked") and world_query.is_creature_navigation_blocked(position) == true:
		return false
	for wall in _get_cached_group_nodes("walls"):
		var wall_node := wall as Node2D
		if is_instance_valid(wall_node) and position.distance_to(wall_node.global_position) < wall_avoid_radius * 0.72:
			return false
	return true


func debug_return_to_world() -> void:
	_enforce_world_bounds(true)


func _enforce_world_bounds(force_retarget := false) -> void:
	var clamped_position := _clamp_to_world(global_position)
	if force_retarget or clamped_position.distance_squared_to(global_position) > 0.01:
		global_position = clamped_position
		velocity = Vector2.ZERO
		prey_target = null
		plant_target = null
		meat_target = null
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
		var candidate := _clamp_to_world(global_position + candidate_direction * wander_radius)
		if candidate.distance_squared_to(global_position) > 16.0 and _is_navigation_position_valid(candidate):
			return candidate
	return _clamp_to_world(global_position + direction * wander_radius * 0.45)


func _clamp_to_world(position: Vector2) -> Vector2:
	var rect := _get_world_rect()
	return Vector2(
		clamp(position.x, rect.position.x, rect.end.x),
		clamp(position.y, rect.position.y, rect.end.y)
	)


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
	var event_name := "grazer_killed_by_varnak" if source == "varnak" else "grazer_killed_by_player"
	get_node("/root/EventBus").emit_game_event(event_name, {
		"biome_id": _get_current_biome_id(),
		"species_id": species_id,
		"generation": generation,
		"fitness_score": _get_fitness_score(),
		"position": global_position,
		"source": source
	})
	get_node("/root/EventBus").post_message("Grazer killed")
	queue_free()


func _drop_meat_once() -> void:
	if dropped_meat:
		return
	dropped_meat = true
	var world := get_tree().current_scene.get_node_or_null("World")
	if world and world.has_method("spawn_meat_drop_for_animal"):
		world.spawn_meat_drop_for_animal("grazer", global_position)


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
	aggression = float(base_traits.get("aggression", aggression))
	hunger_growth_rate = float(base_traits.get("hunger_growth_rate", base_traits.get("hunger_rate", hunger_growth_rate)))
	max_hunger = float(base_traits.get("max_hunger", max_hunger))
	energy = float(base_traits.get("energy", energy))
	plant_consumption_rate = float(base_traits.get("plant_consumption_rate", plant_consumption_rate))
	plant_diet = float(base_traits.get("plant_diet", plant_diet))
	meat_diet = float(base_traits.get("meat_diet", meat_diet))
	scavenger_diet = float(base_traits.get("scavenger_diet", scavenger_diet))
	size = float(base_traits.get("size", size))
	reproduction_rate = float(base_traits.get("reproduction_rate", reproduction_rate))
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


func _get_current_target_label() -> String:
	if is_instance_valid(plant_target):
		return "plant"
	if is_instance_valid(prey_target):
		return "prey"
	if is_instance_valid(meat_target):
		return "meat_drop"
	if state == State.SCAVENGE:
		return "scavenge"
	if state == State.FLEE:
		return "threat"
	if state == State.WANDER:
		return "wander"
	return "none"


func _get_target_lock_seconds() -> float:
	return float(GAME_BALANCE.ANIMAL_AI.get("target_lock_seconds", 0.85))


func _get_fitness_score() -> float:
	var health_ratio: float = clamp(health / max(max_health, 1.0), 0.0, 1.0)
	var diet_flexibility: float = clamp(meat_diet + scavenger_diet, 0.0, 1.0)
	return clamp(health_ratio * 0.40 + (1.0 - hunger_diet.get_hunger_ratio()) * 0.30 + energy * 0.20 + diet_flexibility * 0.10, 0.0, 1.0)


func _sync_population_traits() -> void:
	var ecosystem := get_tree().current_scene.get_node_or_null("EcosystemDirector")
	if not ecosystem or not ecosystem.has_method("get_grazer_traits"):
		return
	var traits: Dictionary = ecosystem.get_grazer_traits(_get_current_biome_id())
	if traits.is_empty():
		return
	generation = max(int(traits.get("generation", generation)), 1)
	population_biome_id = str(traits.get("biome_id", population_biome_id))
	plant_diet = float(traits.get("plant_diet", plant_diet))
	meat_diet = float(traits.get("meat_diet", meat_diet))
	scavenger_diet = float(traits.get("scavenger_diet", scavenger_diet))
	aggression = float(traits.get("aggression", aggression))
	reproduction_rate = clamp(float(traits.get("reproduction_rate", reproduction_rate)), 0.0, 1.5)
	current_niche = str(traits.get("current_niche", current_niche))
	hunger_diet.plant_diet = plant_diet
	hunger_diet.meat_diet = meat_diet
	hunger_diet.scavenger_diet = scavenger_diet


func _get_current_biome_id() -> String:
	var current_biome_id := _get_biome_id_for_position(global_position)
	if not current_biome_id.is_empty():
		biome_id = current_biome_id
		population_biome_id = current_biome_id
	return biome_id


func _get_current_biomass_percent() -> float:
	var ecosystem := get_tree().current_scene.get_node_or_null("EcosystemDirector")
	if not ecosystem or not ecosystem.has_method("get_biome_state"):
		return 100.0
	var state_data: Dictionary = ecosystem.get_biome_state(_get_current_biome_id())
	return float(state_data.get("plant_biomass_percent", 100.0))


func _get_biome_id_for_position(position: Vector2) -> String:
	for biome in WORLD_CONFIG.get_biome_zones():
		if Geometry2D.is_point_in_polygon(position, PackedVector2Array(biome["points"])):
			return _get_biome_id(biome)
	return ""


func _is_position_in_biome(position: Vector2, target_biome_id: String) -> bool:
	if target_biome_id.is_empty():
		return WORLD_CONFIG.WORLD_RECT.has_point(position)
	for biome in WORLD_CONFIG.get_biome_zones():
		if _get_biome_id(biome) == target_biome_id:
			return Geometry2D.is_point_in_polygon(position, PackedVector2Array(biome["points"]))
	return false


func _get_biome_id(biome: Dictionary) -> String:
	return str(biome.get("name", "biome")).to_snake_case()


func _vector_to_data(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


func _data_to_vector(data: Variant) -> Vector2:
	if typeof(data) != TYPE_DICTIONARY:
		return Vector2.ZERO
	return Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))


func _draw() -> void:
	var body_color := Color(0.44, 0.50, 0.30)
	var horn_color := Color(0.72, 0.66, 0.48)
	if state == State.FLEE:
		body_color = Color(0.67, 0.46, 0.25)
	elif state == State.SEEK_FOOD or state == State.SCAVENGE:
		body_color = Color(0.50, 0.42, 0.28)
	elif state == State.HUNT_SMALL_PREY:
		body_color = Color(0.58, 0.30, 0.24)
	draw_set_transform(Vector2.ZERO, clamp(sin(facing_angle), -1.0, 1.0) * 0.10, Vector2(facing_side, 1.0) * size)
	_draw_filled_ellipse(Rect2(-22, -12, 42, 24), body_color)
	_draw_filled_ellipse(Rect2(8, -14, 24, 22), body_color.lightened(0.12))
	draw_polygon([Vector2(17, -12), Vector2(16, -27), Vector2(23, -13)], [horn_color])
	draw_polygon([Vector2(27, -10), Vector2(34, -22), Vector2(32, -6)], [horn_color.lightened(0.08)])
	draw_circle(Vector2(22, -5), 2.2, Color(0.03, 0.02, 0.01))
	draw_line(Vector2(-14, 10), Vector2(-19, 25), Color(0.18, 0.13, 0.08), 4.0)
	draw_line(Vector2(8, 10), Vector2(6, 25), Color(0.18, 0.13, 0.08), 4.0)
	draw_line(Vector2(-24, -1), Vector2(-38, 4), Color(0.24, 0.17, 0.09), 4.0)
	_draw_eating_visual()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_debug_stat_frame()


func _draw_eating_visual() -> void:
	if eat_visual_time <= 0.0:
		return
	var progress := eat_visual_time / eat_visual_duration
	var alpha := 0.25 + progress * 0.45
	var bite_color := _get_eating_visual_color(alpha)
	draw_arc(Vector2(31, -2), 11.0 + progress * 3.0, -0.85, 0.85, 8, bite_color, 2.5)
	draw_circle(Vector2(38, -8), 2.4 + progress * 1.2, bite_color)
	draw_circle(Vector2(37, 5), 1.8 + progress, bite_color.lightened(0.16))


func _get_eating_visual_color(alpha: float) -> Color:
	match last_food_source:
		"plants":
			return Color(0.58, 0.95, 0.28, alpha)
		"meat_drop", "small_prey_meat":
			return Color(0.95, 0.12, 0.08, alpha)
		_:
			return Color(0.58, 0.95, 0.28, alpha)


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
	_draw_debug_lines(lines, Vector2(-70.0, -96.0))


func _get_debug_action_label() -> String:
	if eat_visual_time > 0.0:
		return "eating_meat" if _get_debug_food_label().contains("meat") else "eating_plants"
	match state:
		State.EAT_PLANTS:
			return "chewing_wait"
		State.SEEK_FOOD:
			return "seeking_plant" if is_instance_valid(plant_target) else "no_plant"
		State.SCAVENGE:
			return "seeking_meat" if is_instance_valid(meat_target) else "no_meat"
		State.HUNT_SMALL_PREY:
			return "hunting_prey"
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
	var width: float = max(132.0, float(max_chars) * 6.3 + 12.0)
	var height: float = float(lines.size()) * 13.0 + 10.0
	var rect := Rect2(top_left, Vector2(width, height))
	draw_rect(rect, Color(0.03, 0.05, 0.04, 0.76), true)
	draw_rect(rect, Color(0.76, 0.92, 0.46, 0.86), false, 1.3)
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


func _initialize_from_game_balance() -> void:
	var ai_config := GAME_BALANCE.GRAZER_AI
	wander_radius = float(ai_config.get("wander_radius", 190.0))
	wander_reached_distance = float(ai_config.get("wander_reached_distance", 22.0))
	player_flee_range = float(ai_config.get("player_flee_range", 105.0))
	varnak_flee_range = float(ai_config.get("varnak_flee_range", 220.0))
	flee_duration_seconds = float(ai_config.get("flee_duration_seconds", 4.0))
	low_biomass_percent = float(ai_config.get("low_biomass_percent", 35.0))
	eat_duration_seconds = float(ai_config.get("eat_duration_seconds", 1.4))
	eat_visual_duration = float(ai_config.get("eat_visual_duration", 0.55))
	idle_duration_seconds = float(ai_config.get("idle_duration_seconds", 0.9))
	small_prey_detect_range = float(ai_config.get("small_prey_detect_range", 220.0))
	small_prey_attack_range = float(ai_config.get("small_prey_attack_range", 28.0))
	plant_eat_hunger_drop = float(ai_config.get("plant_eat_hunger_drop", 0.45))
	meat_hunger_drop = float(ai_config.get("meat_hunger_drop", 0.65))
	vegetation_eat_range = float(ai_config.get("vegetation_eat_range", 220.0))
	vegetation_consume_range = float(ai_config.get("vegetation_consume_range", 34.0))
	meat_eat_range = float(ai_config.get("meat_eat_range", 300.0))
	meat_consume_range = float(ai_config.get("meat_consume_range", 34.0))
	world_edge_padding = float(ai_config.get("world_edge_padding", 28.0))
	avoidance_lookahead_distance = float(ai_config.get("avoidance_lookahead_distance", 62.0))
	wall_avoid_radius = float(ai_config.get("wall_avoid_radius", 78.0))
	biome_return_chance = float(ai_config.get("biome_return_chance", 0.58))


func _is_debug_overlay_visible() -> bool:
	var scene := get_tree().current_scene
	if not scene:
		return false
	var debug_panel := scene.get_node_or_null("HUD/DebugPanel")
	return is_instance_valid(debug_panel) and debug_panel.visible


func _draw_filled_ellipse(rect: Rect2, ellipse_color: Color) -> void:
	var points := PackedVector2Array()
	var center := rect.get_center()
	var radii := rect.size * 0.5
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, ellipse_color)
