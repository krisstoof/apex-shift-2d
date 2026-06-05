extends CharacterBody2D

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")

enum State { IDLE, WANDER, STALK, CHASE, ATTACK, FLEE, HUNT_ECOSYSTEM, EAT_MEAT }

const ATTACK_RANGE := 42.0
const ATTACK_ARC := deg_to_rad(78.0)
const ATTACK_VISUAL_DURATION := 0.14
const EAT_VISUAL_DURATION := 0.55
const BASE_HEALTH := 90.0
const HUNGER_GROWTH_RATE := 0.18
const HUNT_DETECTION_RANGE := 620.0
const HUNT_PLAYER_SAFE_DISTANCE := 160.0
const HUNT_HUNGER_THRESHOLD := 0.32
const HUNT_FEED_AMOUNT := 0.55
const MEAT_CONSUME_RANGE := 38.0
const WORLD_EDGE_PADDING := 32.0
const DEBUG_FRAME_FONT_SIZE := 11
const BASE_HUNGER_TIME_SCALE := 0.05
const MOVEMENT_HUNGER_TIME_SCALE := 0.06

var health := BASE_HEALTH
var max_health := BASE_HEALTH
var species_id := "varnak"
var species_name := "Varnak"
var generation := 1
var population_biome_id := ""
var hunger := 0.0
var energy := 1.0
var age_seconds := 0.0
var speed := 105.0
var aggression := 0.45
var fire_fear := 0.85
var trap_awareness := 0.10
var pack_coordination := 0.20
var night_activity := 0.25
var base_curiosity := 0.10
var stalk_tendency := 0.15
var state := State.WANDER
var player: Node2D
var day_night_system: Node
var wander_target := Vector2.ZERO
var facing_angle := 0.0
var facing_side := 1.0
var attack_cooldown := 0.0
var attack_visual_time := 0.0
var eat_visual_time := 0.0
var target_lock_time := 0.0
var night_health_bonus_active := false
var scared_fire: Node2D
var ecosystem_target: Node2D
var ecosystem_target_kind := ""
var meat_target: Node2D
var dropped_meat := false
var last_food_source := "none"
var decision_reason := "spawn"
var is_dead := false
var meat_diet := 1.0
var scavenger_diet := 0.45

func _ready() -> void:
	add_to_group("varnak")
	player = get_tree().get_first_node_in_group("player")
	_pick_wander_target()
	queue_redraw()


func apply_profile(profile: Dictionary) -> void:
	species_id = str(profile.get("species_id", species_id))
	species_name = str(profile.get("species_name", species_name))
	generation = max(int(profile.get("generation", generation)), 1)
	meat_diet = clamp(float(profile.get("meat_diet", meat_diet)), 0.0, 1.0)
	scavenger_diet = clamp(float(profile.get("scavenger_diet", scavenger_diet)), 0.0, 1.0)
	aggression = float(profile.get("aggression", aggression))
	fire_fear = float(profile.get("fire_fear", fire_fear))
	trap_awareness = float(profile.get("trap_awareness", trap_awareness))
	pack_coordination = float(profile.get("pack_coordination", pack_coordination))
	night_activity = float(profile.get("night_activity", night_activity))
	base_curiosity = float(profile.get("base_curiosity", base_curiosity))
	stalk_tendency = float(profile.get("stalk_tendency", stalk_tendency))
	speed = 90.0 + aggression * 50.0 + pack_coordination * 20.0
	queue_redraw()


func get_save_data() -> Dictionary:
	return {
		"species_id": species_id,
		"species_name": species_name,
		"generation": generation,
		"population_biome_id": _get_current_biome_id(),
		"position": _vector_to_data(global_position),
		"facing_angle": facing_angle,
		"facing_side": facing_side,
		"health": health,
		"max_health": max_health,
		"hunger": hunger,
		"energy": energy,
		"fatigue": 1.0 - energy,
		"rest": energy,
		"age_seconds": age_seconds,
		"night_health_bonus_active": night_health_bonus_active,
		"state": int(state),
		"wander_target": _vector_to_data(wander_target),
		"attack_cooldown": attack_cooldown,
		"last_food_source": last_food_source,
		"meat_diet": meat_diet,
		"scavenger_diet": scavenger_diet,
		"dropped_meat": dropped_meat
	}


func get_debug_data() -> Dictionary:
	return {
		"state": State.keys()[state],
		"species": species_name,
		"species_id": species_id,
		"generation": generation,
		"population_biome_id": _get_current_biome_id(),
		"health": health,
		"max_health": max_health,
		"hunger": hunger,
		"hunger_ratio": hunger,
		"max_hunger": 1.0,
		"hunger_stage": _get_hunger_stage(),
		"energy": energy,
		"fatigue": 1.0 - energy,
		"rest": energy,
		"age_seconds": age_seconds,
		"current_target": _get_current_target_label(),
		"decision_reason": decision_reason,
		"last_food_source": last_food_source,
		"fitness_score": _get_fitness_score(),
		"hunt_drive": _get_hunt_drive(),
		"plant_diet": 0.0,
		"meat_diet": meat_diet,
		"scavenger_diet": scavenger_diet,
		"aggression": aggression,
		"fire_fear": fire_fear,
		"trap_awareness": trap_awareness,
		"pack_coordination": pack_coordination,
		"night_activity": night_activity,
		"base_curiosity": base_curiosity,
		"stalk_tendency": stalk_tendency,
		"speed": speed,
		"attack_cooldown": attack_cooldown,
		"ecosystem_target": ecosystem_target_kind if is_instance_valid(ecosystem_target) else "",
		"night_health_bonus_active": night_health_bonus_active,
		"distance_to_player": global_position.distance_to(player.global_position) if is_instance_valid(player) else -1.0
	}


func restore_from_data(data: Dictionary) -> void:
	species_id = str(data.get("species_id", species_id))
	species_name = str(data.get("species_name", species_name))
	generation = max(int(data.get("generation", generation)), 1)
	population_biome_id = str(data.get("population_biome_id", population_biome_id))
	global_position = _clamp_to_world(_data_to_vector(data.get("position", {})))
	facing_angle = float(data.get("facing_angle", data.get("rotation", facing_angle)))
	facing_side = float(data.get("facing_side", 1.0 if cos(facing_angle) >= 0.0 else -1.0))
	max_health = max(float(data.get("max_health", max_health)), 1.0)
	health = clamp(float(data.get("health", health)), 0.0, max_health)
	hunger = clamp(float(data.get("hunger", hunger)), 0.0, 1.0)
	energy = clamp(float(data.get("energy", energy)), 0.0, 1.0)
	age_seconds = max(float(data.get("age_seconds", age_seconds)), 0.0)
	night_health_bonus_active = data.get("night_health_bonus_active", night_health_bonus_active) == true
	state = int(data.get("state", State.WANDER))
	wander_target = _clamp_to_world(_data_to_vector(data.get("wander_target", _vector_to_data(wander_target))))
	attack_cooldown = float(data.get("attack_cooldown", attack_cooldown))
	last_food_source = str(data.get("last_food_source", last_food_source))
	meat_diet = float(data.get("meat_diet", meat_diet))
	scavenger_diet = float(data.get("scavenger_diet", scavenger_diet))
	dropped_meat = data.get("dropped_meat", dropped_meat) == true
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	_update_night_health_bonus()
	var movement_intensity: float = clamp(velocity.length() / max(speed, 1.0), 0.0, 1.0)
	var hunger_growth := _get_hunger_growth_rate()
	hunger = clamp(
		hunger + hunger_growth * BASE_HUNGER_TIME_SCALE * delta + hunger_growth * movement_intensity * MOVEMENT_HUNGER_TIME_SCALE * delta,
		0.0,
		1.0
	)
	age_seconds += delta
	attack_cooldown = max(attack_cooldown - delta, 0.0)
	target_lock_time = max(target_lock_time - delta, 0.0)
	if attack_visual_time > 0.0:
		attack_visual_time = max(attack_visual_time - delta, 0.0)
		queue_redraw()
	if eat_visual_time > 0.0:
		eat_visual_time = max(eat_visual_time - delta, 0.0)
		queue_redraw()
	_update_state()
	_act(delta)
	_update_individual_energy(delta, velocity.length() / max(speed, 1.0))
	move_and_slide()
	_enforce_world_bounds()


func take_damage(amount: float, source: String) -> void:
	if is_dead:
		return
	health = max(health - amount, 0.0)
	if health <= 0.0:
		_die(source)
	else:
		state = State.CHASE


func _update_night_health_bonus() -> void:
	var has_bonus := false
	if day_night_system:
		has_bonus = day_night_system.is_night()
	var target_max: float = BASE_HEALTH * (GAME_BALANCE.NIGHT_DANGER_MULTIPLIER if has_bonus else 1.0)
	if is_equal_approx(max_health, target_max):
		night_health_bonus_active = has_bonus
		return
	var health_ratio: float = clamp(health / max(max_health, 1.0), 0.0, 1.0)
	max_health = target_max
	health = clamp(health_ratio * max_health, 0.0, max_health)
	night_health_bonus_active = has_bonus
	queue_redraw()


func _update_state() -> void:
	scared_fire = _nearest_active_campfire()
	if scared_fire and fire_fear > 0.25:
		decision_reason = "active_campfire_fear"
		state = State.FLEE
		if randf() < 0.012:
			get_node("/root/EventBus").emit_game_event("varnak_scared_by_fire", {"position": global_position})
			get_node("/root/EventBus").post_message("Varnak scared by fire")
		return
	if state == State.FLEE:
		decision_reason = "threat_lost_return_wander"
		state = State.WANDER
	if not is_instance_valid(ecosystem_target):
		ecosystem_target = null
		ecosystem_target_kind = ""
	if not is_instance_valid(meat_target):
		meat_target = null
	var distance := global_position.distance_to(player.global_position)
	var night_bonus := night_activity * 70.0 if day_night_system and day_night_system.is_night() else 0.0
	var detect_range := 210.0 + base_curiosity * 120.0 + night_bonus
	var close_chase_range := 115.0
	var effective_aggression := aggression
	var torch_protecting := _is_torch_protecting_player(distance)
	if torch_protecting:
		detect_range *= GAME_BALANCE.TORCH_DETECTION_RANGE_MULTIPLIER
		effective_aggression *= GAME_BALANCE.TORCH_AGGRESSION_MULTIPLIER
		close_chase_range *= GAME_BALANCE.TORCH_CLOSE_CHASE_RANGE_MULTIPLIER
		if distance > ATTACK_RANGE:
			decision_reason = "torch_protects_player"
			state = State.FLEE
			return
	if _should_prioritize_player(distance, detect_range, close_chase_range, effective_aggression):
		ecosystem_target = null
		ecosystem_target_kind = ""
		meat_target = null
		if distance < 34.0:
			decision_reason = "player_in_attack_range"
			state = State.ATTACK
		elif distance < detect_range:
			decision_reason = "player_priority_aggression"
			state = State.CHASE if effective_aggression > 0.5 or distance < close_chase_range else State.STALK
		return
	if state == State.EAT_MEAT and _try_update_meat_target():
		decision_reason = "locked_meat_target" if is_instance_valid(meat_target) else decision_reason
		return
	if state == State.HUNT_ECOSYSTEM and target_lock_time > 0.0 and is_instance_valid(ecosystem_target) and _should_hunt_ecosystem(distance):
		decision_reason = "locked_ecosystem_prey"
		return
	if hunger >= _get_hungry_threshold() and _set_nearest_meat_target(_get_meat_search_range()):
		ecosystem_target = null
		ecosystem_target_kind = ""
		decision_reason = "hungry_scavenge_meat"
		state = State.EAT_MEAT
		return
	var prey := _find_ecosystem_target()
	if is_instance_valid(prey) and _should_hunt_ecosystem(distance):
		ecosystem_target = prey
		ecosystem_target_kind = _get_ecosystem_target_kind(prey)
		meat_target = null
		target_lock_time = _get_target_lock_seconds()
		decision_reason = "hunt_drive_ecosystem_prey"
		state = State.HUNT_ECOSYSTEM
		return
	if _should_roam_for_food(distance):
		_pick_hunt_roam_target()
		decision_reason = "hungry_hunt_roam"
		state = State.WANDER
		return
	if distance < 34.0:
		decision_reason = "player_too_close"
		state = State.ATTACK
	elif distance < detect_range:
		decision_reason = "player_detected_patrol"
		state = State.CHASE if effective_aggression > 0.5 or distance < close_chase_range else State.STALK
	elif global_position.distance_to(wander_target) < _get_wander_target_reached_distance():
		decision_reason = "wander_target_reached"
		state = State.WANDER
		_pick_wander_target()


func _act(delta: float) -> void:
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
		State.WANDER:
			_move_toward(wander_target, speed * 0.42)
		State.STALK:
			var desired := player.global_position + (global_position - player.global_position).normalized() * (90.0 + stalk_tendency * 70.0)
			_move_toward(desired, speed * 0.48)
		State.CHASE:
			_move_toward(_avoid_trap_target(player.global_position), speed)
		State.ATTACK:
			velocity = Vector2.ZERO
			_face_target(player.global_position)
			if attack_cooldown <= 0.0 and player.has_method("receive_damage") and _is_player_in_attack_arc():
				player.receive_damage(10.0 + aggression * 8.0, "varnak")
				get_node("/root/EventBus").emit_game_event("varnak_attacked_player", {"damage": 10.0 + aggression * 8.0})
				attack_visual_time = ATTACK_VISUAL_DURATION
				queue_redraw()
				attack_cooldown = 1.2 * (GAME_BALANCE.TORCH_ATTACK_COOLDOWN_MULTIPLIER if _is_torch_protecting_player(global_position.distance_to(player.global_position)) else 1.0)
		State.HUNT_ECOSYSTEM:
			_hunt_ecosystem_target()
		State.EAT_MEAT:
			if is_instance_valid(meat_target):
				_move_toward(meat_target.global_position, speed * 0.58)
			else:
				velocity = Vector2.ZERO
		State.FLEE:
			var flee_origin := _get_flee_origin()
			if flee_origin == Vector2.INF:
				state = State.WANDER
				_pick_wander_target()
				_move_toward(wander_target, speed * 0.42)
				return
			var away := (global_position - flee_origin).normalized()
			var flee_multiplier := 1.1 + fire_fear if is_instance_valid(scared_fire) else GAME_BALANCE.TORCH_FLEE_SPEED_MULTIPLIER
			var flee_target := _get_bounded_flee_target(away)
			_move_toward(flee_target, speed * flee_multiplier)


func _should_prioritize_player(distance: float, detect_range: float, close_chase_range: float, effective_aggression: float) -> bool:
	if distance <= close_chase_range:
		return true
	if state == State.HUNT_ECOSYSTEM and distance <= _get_player_intrusion_radius() * (0.72 + effective_aggression):
		return true
	if state == State.EAT_MEAT and distance <= _get_player_intrusion_radius() * (0.54 + effective_aggression):
		return true
	if state == State.CHASE or state == State.STALK or state == State.ATTACK:
		return distance < detect_range
	if effective_aggression > 0.62 and distance < detect_range:
		return true
	if day_night_system and day_night_system.is_night() and night_activity > 0.55 and distance < detect_range:
		return true
	return false


func _should_hunt_ecosystem(player_distance: float) -> bool:
	var player_safe_distance := _get_player_intrusion_radius() * 0.66
	if player_distance < player_safe_distance:
		return false
	if hunger >= _get_hungry_threshold():
		return true
	return _get_biome_prey_pressure() > 0.35 and player_distance > player_safe_distance * 1.4 and _get_hunt_drive() > 0.32


func _hunt_ecosystem_target() -> void:
	if not is_instance_valid(ecosystem_target):
		decision_reason = "ecosystem_target_lost"
		state = State.WANDER
		_pick_wander_target()
		return
	var distance := global_position.distance_to(ecosystem_target.global_position)
	if distance <= ATTACK_RANGE and attack_cooldown <= 0.0 and ecosystem_target.has_method("take_damage"):
		var hunted_kind := ecosystem_target_kind
		ecosystem_target.take_damage(999.0, "varnak")
		hunger = max(hunger - _get_hunt_feed_amount(hunted_kind), 0.0)
		energy = clamp(energy + _get_hunt_feed_amount(hunted_kind) * 0.38, 0.0, 1.0)
		eat_visual_time = EAT_VISUAL_DURATION
		last_food_source = "%s_meat" % hunted_kind
		var event_name := "varnak_hunted_grazer" if hunted_kind == "grazer" else "varnak_hunted_small_prey"
		get_node("/root/EventBus").emit_game_event(event_name, {"position": global_position})
		get_node("/root/EventBus").post_message("Varnak hunted %s" % ("Grazer" if hunted_kind == "grazer" else "SmallPrey"))
		attack_visual_time = ATTACK_VISUAL_DURATION
		attack_cooldown = 1.0
		ecosystem_target = null
		ecosystem_target_kind = ""
		decision_reason = "finished_hunt_feed"
		state = State.WANDER
		queue_redraw()
		return
	_move_toward(ecosystem_target.global_position, speed * 0.92)


func _try_update_meat_target() -> bool:
	if not is_instance_valid(meat_target) or not _is_meat_drop_target(meat_target):
		if not _set_nearest_meat_target(_get_meat_search_range()):
			state = State.WANDER
			_pick_wander_target()
			return true
	wander_target = _clamp_to_world(meat_target.global_position)
	if global_position.distance_to(meat_target.global_position) <= MEAT_CONSUME_RANGE:
		_consume_meat_target()
		state = State.WANDER
		_pick_wander_target()
	return true


func _set_nearest_meat_target(search_range: float) -> bool:
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


func _consume_meat_target() -> void:
	if not is_instance_valid(meat_target) or not _is_meat_drop_target(meat_target) or not meat_target.has_method("consume_by_creature"):
		meat_target = null
		return
	var eaten_food := float(meat_target.consume_by_creature(self, 1.0))
	if eaten_food <= 0.0:
		meat_target = null
		return
	hunger = max(hunger - max(HUNT_FEED_AMOUNT, eaten_food), 0.0)
	energy = clamp(energy + eaten_food * 0.34, 0.0, 1.0)
	eat_visual_time = EAT_VISUAL_DURATION
	last_food_source = "meat_drop"
	get_node("/root/EventBus").emit_game_event("varnak_scavenged_meat", {
		"position": global_position,
		"nutrition": eaten_food
	})
	get_node("/root/EventBus").post_message("Varnak ate meat")
	meat_target = null


func _get_meat_search_range() -> float:
	return max(_get_prey_detect_radius() * 0.72, float(GAME_BALANCE.ANIMAL_AI.get("food_search_radius", 260.0)))


func _find_ecosystem_target() -> Node2D:
	var best_target: Node2D
	var best_score := INF
	var detect_range := _get_prey_detect_radius()
	for group_name in ["small_prey", "grazer"]:
		for creature in _get_cached_group_nodes(group_name):
			if not is_instance_valid(creature):
				continue
			if not _get_world_rect().has_point(creature.global_position):
				continue
			var distance := global_position.distance_to(creature.global_position)
			if distance > detect_range:
				continue
			var prey_priority := _get_prey_priority(str(group_name))
			var score: float = distance / max(prey_priority, 0.05)
			if score < best_score:
				best_score = score
				best_target = creature
	return best_target


func _get_prey_priority(group_name: String) -> float:
	var base_priority := float(GAME_BALANCE.VARNAK_HUNTING.get("prey_chase_priority", 0.65))
	var hunger_bias: float = clamp(hunger, 0.0, 1.0)
	if group_name == "grazer":
		return base_priority * lerp(0.72, 1.22, hunger_bias)
	return base_priority * lerp(1.18, 0.92, hunger_bias)


func _get_hunt_drive() -> float:
	var night_multiplier := _get_night_hunting_multiplier()
	var prey_pressure := _get_biome_prey_pressure()
	return clamp((hunger * 0.62 + (1.0 - energy) * 0.12 + prey_pressure * 0.16 + aggression * 0.10) * night_multiplier, 0.0, 1.0)


func _update_individual_energy(delta: float, movement_intensity: float) -> void:
	var movement_cost: float = clamp(movement_intensity, 0.0, 1.0) * 0.032
	var hunger_recovery_penalty: float = hunger * 0.012
	var recovery: float = 0.018 * (1.0 - hunger)
	energy = clamp(energy - delta * (0.010 + movement_cost + hunger_recovery_penalty) + delta * recovery, 0.0, 1.0)


func _get_hunger_stage() -> String:
	if hunger >= _get_desperate_threshold():
		return "desperate"
	if hunger >= _get_starving_threshold():
		return "starving"
	if hunger >= _get_hungry_threshold():
		return "hungry"
	return "comfortable"


func _get_current_target_label() -> String:
	if is_instance_valid(ecosystem_target):
		return ecosystem_target_kind
	if is_instance_valid(meat_target):
		return "meat_drop"
	if is_instance_valid(scared_fire):
		return "fire"
	match state:
		State.CHASE, State.ATTACK:
			return "player"
		State.FLEE:
			return "avoid"
		State.WANDER:
			return "wander"
		_:
			return "none"


func _get_fitness_score() -> float:
	var health_ratio: float = clamp(health / max(max_health, 1.0), 0.0, 1.0)
	return clamp(health_ratio * 0.42 + (1.0 - hunger) * 0.30 + energy * 0.18 + aggression * 0.10, 0.0, 1.0)


func _get_hunger_growth_rate() -> float:
	return float(GAME_BALANCE.VARNAK_HUNTING.get("hunger_growth_rate", HUNGER_GROWTH_RATE))


func _get_hungry_threshold() -> float:
	return float(GAME_BALANCE.VARNAK_HUNTING.get("hungry_threshold", HUNT_HUNGER_THRESHOLD))


func _get_starving_threshold() -> float:
	return float(GAME_BALANCE.VARNAK_HUNTING.get("starving_threshold", 0.58))


func _get_desperate_threshold() -> float:
	return float(GAME_BALANCE.VARNAK_HUNTING.get("desperate_threshold", 0.80))


func _get_prey_detect_radius() -> float:
	var radius := float(GAME_BALANCE.VARNAK_HUNTING.get("prey_detect_radius", HUNT_DETECTION_RANGE))
	return radius * _get_night_hunting_multiplier()


func _get_player_intrusion_radius() -> float:
	return float(GAME_BALANCE.VARNAK_HUNTING.get("player_intrusion_radius", HUNT_PLAYER_SAFE_DISTANCE))


func _get_night_hunting_multiplier() -> float:
	if day_night_system and day_night_system.is_night():
		return float(GAME_BALANCE.VARNAK_HUNTING.get("night_hunting_multiplier", 1.25))
	return 1.0


func _get_hunt_feed_amount(hunted_kind: String) -> float:
	return HUNT_FEED_AMOUNT * (1.25 if hunted_kind == "grazer" else 1.0)


func _get_ecosystem_target_kind(target: Node) -> String:
	if target.is_in_group("grazer"):
		return "grazer"
	return "small_prey"


func _get_current_biome_id() -> String:
	var current_biome_id := _get_biome_id_for_position(global_position)
	if not current_biome_id.is_empty():
		population_biome_id = current_biome_id
	return population_biome_id


func _get_biome_prey_pressure() -> float:
	var ecosystem := get_tree().current_scene.get_node_or_null("EcosystemDirector")
	if not ecosystem or not ecosystem.has_method("get_biome_state"):
		return 0.0
	var biome_id := _get_biome_id_for_position(global_position)
	var state_data: Dictionary = ecosystem.get_biome_state(biome_id)
	var small_prey_population := float(state_data.get("small_prey_population", 0.0))
	var grazer_population := float(state_data.get("grazer_population", 0.0))
	return clamp((small_prey_population + grazer_population * 1.5) / 18.0, 0.0, 1.0)


func _get_biome_id_for_position(position: Vector2) -> String:
	for biome in WORLD_CONFIG.get_biome_zones():
		if Geometry2D.is_point_in_polygon(position, PackedVector2Array(biome["points"])):
			return _get_biome_id(biome)
	return ""


func _get_biome_id(biome: Dictionary) -> String:
	return str(biome.get("name", "biome")).to_snake_case()


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
	if _is_navigation_position_valid(global_position + desired_direction * 58.0):
		return desired_direction
	var candidates := [
		desired_direction.rotated(0.64),
		desired_direction.rotated(-0.64),
		desired_direction.rotated(1.18),
		desired_direction.rotated(-1.18),
		desired_direction.rotated(PI)
	]
	for candidate_direction in candidates:
		if _is_navigation_position_valid(global_position + candidate_direction * 58.0):
			return candidate_direction
	var fallback := (target - global_position).normalized()
	return fallback if fallback.length_squared() > 0.0 else Vector2.RIGHT


func _is_navigation_position_valid(position: Vector2) -> bool:
	var clamped_position := _clamp_to_world(position)
	if clamped_position.distance_squared_to(position) > 0.01:
		return false
	var world_query: Variant = _get_world_query()
	if world_query and world_query.has_method("is_creature_navigation_blocked") and world_query.is_creature_navigation_blocked(position) == true:
		return false
	return true


func _face_target(target: Vector2) -> void:
	var direction := target - global_position
	if direction.length_squared() > 1.0:
		var previous_angle := facing_angle
		var previous_side := facing_side
		facing_angle = direction.angle()
		if abs(direction.x) > 4.0:
			facing_side = 1.0 if direction.x >= 0.0 else -1.0
		if abs(angle_difference(previous_angle, facing_angle)) > 0.03 or previous_side != facing_side:
			queue_redraw()


func _is_player_in_attack_arc() -> bool:
	if not is_instance_valid(player):
		return false
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	if distance <= 0.0 or distance > ATTACK_RANGE:
		return false
	var forward := Vector2.RIGHT.rotated(facing_angle)
	return abs(forward.angle_to(to_player.normalized())) <= ATTACK_ARC * 0.5


func _avoid_trap_target(target: Vector2) -> Vector2:
	if trap_awareness < 0.45:
		return target
	for trap in _get_cached_group_nodes("traps"):
		if global_position.distance_to(trap.global_position) < 85.0:
			return target + (global_position - trap.global_position).normalized() * 120.0
	return target


func _nearest_active_campfire() -> Node2D:
	var nearest: Node2D
	var nearest_distance := INF
	for campfire in _get_cached_group_nodes("campfires"):
		if not is_instance_valid(campfire):
			continue
		if not campfire.active:
			continue
		var distance := global_position.distance_to(campfire.global_position)
		if distance < campfire.fear_radius and distance < nearest_distance:
			nearest = campfire
			nearest_distance = distance
	return nearest


func _is_torch_protecting_player(distance_to_player: float) -> bool:
	if not _is_dusk_or_night():
		return false
	if distance_to_player > GAME_BALANCE.TORCH_SAFE_RADIUS:
		return false
	return is_instance_valid(player) and player.has_method("is_torch_active") and player.is_torch_active()


func _is_dusk_or_night() -> bool:
	return day_night_system and day_night_system.night_amount > 0.0


func _get_flee_origin() -> Vector2:
	if is_instance_valid(scared_fire):
		return scared_fire.global_position
	if is_instance_valid(player) and _is_torch_protecting_player(global_position.distance_to(player.global_position)):
		return player.global_position
	return Vector2.INF


func _pick_wander_target() -> void:
	var rect := _get_world_rect()
	var current_biome_id := _get_current_biome_id()
	var local_radius := _get_local_patrol_radius()
	for _attempt in 24:
		var candidate := global_position + Vector2(
			randf_range(-local_radius, local_radius),
			randf_range(-local_radius, local_radius)
		)
		if _is_navigation_position_valid(candidate) and (current_biome_id.is_empty() or _get_biome_id_for_position(candidate) == current_biome_id):
			wander_target = _clamp_to_world(candidate)
			return
	for _attempt in 24:
		var candidate := Vector2(
			randf_range(rect.position.x, rect.end.x),
			randf_range(rect.position.y, rect.end.y)
		)
		if _is_navigation_position_valid(candidate):
			wander_target = candidate
			return
	wander_target = _clamp_to_world(global_position)


func _pick_hunt_roam_target() -> void:
	var current_biome_id := _get_current_biome_id()
	var roam_radius := _get_hunt_roam_radius()
	var allow_cross_biome := _can_cross_biome_for_hunt()
	for _attempt in 36:
		var angle := randf_range(0.0, TAU)
		var distance := randf_range(roam_radius * 0.55, roam_radius)
		var candidate := _clamp_to_world(global_position + Vector2.RIGHT.rotated(angle) * distance)
		if not _is_navigation_position_valid(candidate):
			continue
		if not allow_cross_biome and not current_biome_id.is_empty() and _get_biome_id_for_position(candidate) != current_biome_id:
			continue
		wander_target = candidate
		target_lock_time = max(target_lock_time, _get_target_lock_seconds() * 2.0)
		return
	_pick_wander_target()


func debug_return_to_world() -> void:
	_enforce_world_bounds(true)


func _enforce_world_bounds(force_retarget := false) -> void:
	var clamped_position := _clamp_to_world(global_position)
	if force_retarget or clamped_position.distance_squared_to(global_position) > 0.01:
		global_position = clamped_position
		velocity = Vector2.ZERO
		ecosystem_target = null
		ecosystem_target_kind = ""
		meat_target = null
		decision_reason = "world_bounds_retarget"
		state = State.WANDER
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
		var candidate := _clamp_to_world(global_position + candidate_direction * 180.0)
		if candidate.distance_squared_to(global_position) > 16.0 and _is_navigation_position_valid(candidate):
			return candidate
	return _clamp_to_world(global_position + direction * 90.0)


func _clamp_to_world(position: Vector2) -> Vector2:
	var rect := _get_world_rect()
	return Vector2(
		clamp(position.x, rect.position.x, rect.end.x),
		clamp(position.y, rect.position.y, rect.end.y)
	)


func _get_world_rect() -> Rect2:
	return WORLD_CONFIG.WORLD_RECT.grow(-WORLD_EDGE_PADDING)


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


func _get_target_lock_seconds() -> float:
	return float(GAME_BALANCE.VARNAK_HUNTING.get("target_lock_seconds", 1.10))


func _get_local_patrol_radius() -> float:
	return float(GAME_BALANCE.VARNAK_HUNTING.get("local_patrol_radius", 320.0))


func _get_hunt_roam_radius() -> float:
	if hunger >= _get_starving_threshold():
		return float(GAME_BALANCE.VARNAK_HUNTING.get("starving_roam_radius", 1120.0))
	return float(GAME_BALANCE.VARNAK_HUNTING.get("hungry_roam_radius", 720.0))


func _get_wander_target_reached_distance() -> float:
	if decision_reason == "hungry_hunt_roam":
		return float(GAME_BALANCE.VARNAK_HUNTING.get("hunting_roam_target_reached_distance", 90.0))
	return 20.0


func _can_cross_biome_for_hunt() -> bool:
	if hunger >= _get_starving_threshold():
		return true
	return _get_hunt_drive() >= float(GAME_BALANCE.VARNAK_HUNTING.get("cross_biome_hunt_drive", 0.55))


func _should_roam_for_food(player_distance: float) -> bool:
	if hunger < _get_hungry_threshold():
		return false
	if player_distance < _get_player_intrusion_radius() * 0.70:
		return false
	if state != State.WANDER and state != State.IDLE:
		return false
	if decision_reason == "hungry_hunt_roam" and global_position.distance_to(wander_target) > _get_wander_target_reached_distance():
		return false
	return true


func _die(source: String) -> void:
	if is_dead:
		return
	is_dead = true
	_drop_meat_once()
	var event_name := "varnak_killed_by_trap" if source == "trap" else "varnak_killed_by_player"
	get_node("/root/EventBus").emit_game_event(event_name, {
		"position": global_position,
		"biome_id": _get_current_biome_id(),
		"species_id": species_id,
		"generation": generation,
		"fitness_score": _get_fitness_score()
	})
	get_node("/root/EventBus").post_message("Varnak killed by %s" % source)
	if is_instance_valid(player) and global_position.distance_to(player.global_position) < 90.0:
		player.inventory.add_item("hide", 1)
		player.inventory.add_item("bone", 1)
	queue_free()


func _drop_meat_once() -> void:
	if dropped_meat:
		return
	dropped_meat = true
	var world := get_tree().current_scene.get_node_or_null("World")
	if world and world.has_method("spawn_meat_drop_for_animal"):
		world.spawn_meat_drop_for_animal("varnak", global_position)


func _draw() -> void:
	_draw_attack_visual()
	var body_color := Color(0.78, 0.12, 0.1)
	var jaw_color := Color(0.42, 0.05, 0.04)
	var ear_color := Color(0.58, 0.06, 0.05)
	if state == State.FLEE:
		body_color = Color(0.95, 0.35, 0.08)
		ear_color = Color(0.80, 0.22, 0.05)
	elif state == State.CHASE or state == State.ATTACK or state == State.HUNT_ECOSYSTEM or state == State.EAT_MEAT:
		body_color = Color(0.95, 0.05, 0.03)
		jaw_color = Color(0.55, 0.02, 0.02)
	_apply_upright_body_transform()
	_draw_varnak_body(body_color, jaw_color, ear_color)
	_draw_eating_visual()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_debug_stat_frame()


func _draw_attack_visual() -> void:
	if attack_visual_time <= 0.0:
		return
	var progress := attack_visual_time / ATTACK_VISUAL_DURATION
	var alpha := 0.18 + progress * 0.36
	var points := PackedVector2Array([Vector2(18, 0)])
	var start_angle := -ATTACK_ARC * 0.5
	var steps := 8
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var angle: float = lerp(start_angle, -start_angle, t)
		points.append(Vector2.RIGHT.rotated(facing_angle + angle) * ATTACK_RANGE)
	points[0] = Vector2.RIGHT.rotated(facing_angle) * 18.0
	draw_colored_polygon(points, Color(1.0, 0.18, 0.10, alpha))
	draw_arc(Vector2.ZERO, ATTACK_RANGE, facing_angle + start_angle, facing_angle - start_angle, steps, Color(1.0, 0.52, 0.24, alpha + 0.20), 3.0)


func _draw_eating_visual() -> void:
	if eat_visual_time <= 0.0:
		return
	var progress := eat_visual_time / EAT_VISUAL_DURATION
	var alpha := 0.28 + progress * 0.48
	var bite_color := Color(1.0, 0.10, 0.06, alpha)
	draw_arc(Vector2(35, 3), 13.0 + progress * 4.0, -0.65, 0.65, 8, bite_color, 3.0)
	draw_circle(Vector2(42, -3), 3.0 + progress * 1.4, bite_color)
	draw_circle(Vector2(39, 10), 2.2 + progress, bite_color.darkened(0.12))


func _draw_debug_stat_frame() -> void:
	if not _is_debug_overlay_visible():
		return
	var satiety_percent := int(round((1.0 - hunger) * 100.0))
	var lines: Array[String] = [
		"Varnak",
		"HP %d/%d Sat %d%%" % [int(health), int(max_health), satiety_percent],
		"E %d%% Act %s" % [int(round(energy * 100.0)), _get_debug_action_label()],
		"Target %s" % _get_current_target_label(),
		"Why %s" % decision_reason,
		"Last %s" % _get_debug_food_label()
	]
	_draw_debug_lines(lines, Vector2(-72.0, -102.0))


func _get_debug_action_label() -> String:
	if eat_visual_time > 0.0:
		return "eating_meat"
	match state:
		State.EAT_MEAT:
			return "seeking_meat" if is_instance_valid(meat_target) else "no_meat"
		State.HUNT_ECOSYSTEM:
			return "hunting_%s" % ecosystem_target_kind if is_instance_valid(ecosystem_target) else "hunt_lost"
		State.CHASE, State.ATTACK:
			return "attacking_player"
		State.STALK:
			return "stalking_player"
		State.FLEE:
			return "fleeing"
		State.IDLE:
			return "hungry_idle" if hunger >= _get_hungry_threshold() else "idle"
		State.WANDER:
			return "hungry_wander" if hunger >= _get_hungry_threshold() else "wandering"
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
	var width: float = max(136.0, float(max_chars) * 6.3 + 12.0)
	var height: float = float(lines.size()) * 13.0 + 10.0
	var rect := Rect2(top_left, Vector2(width, height))
	draw_rect(rect, Color(0.05, 0.03, 0.03, 0.78), true)
	draw_rect(rect, Color(0.98, 0.32, 0.22, 0.88), false, 1.3)
	for i in range(lines.size()):
		draw_string(font, top_left + Vector2(6.0, 15.0 + float(i) * 13.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, DEBUG_FRAME_FONT_SIZE, Color(0.98, 0.92, 0.88))


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


func _is_debug_overlay_visible() -> bool:
	var scene := get_tree().current_scene
	if not scene:
		return false
	var debug_panel := scene.get_node_or_null("HUD/DebugPanel")
	return is_instance_valid(debug_panel) and debug_panel.visible


func _apply_upright_body_transform() -> void:
	var facing := Vector2.RIGHT.rotated(facing_angle)
	var visual_angle: float = clamp(facing.y, -1.0, 1.0) * 0.22
	if facing_side < 0.0:
		visual_angle = -visual_angle
	draw_set_transform(Vector2.ZERO, visual_angle, Vector2(facing_side, 1.0))


func _draw_varnak_body(body_color: Color, jaw_color: Color, ear_color: Color) -> void:
	var outline := Color(0.14, 0.02, 0.02)
	draw_polygon([Vector2(-24, 0), Vector2(-36, -8), Vector2(-38, 6)], [outline])
	draw_polygon([Vector2(-12, -14), Vector2(-3, -31), Vector2(5, -13)], [ear_color])
	draw_polygon([Vector2(14, -12), Vector2(25, -28), Vector2(29, -8)], [ear_color.lightened(0.08)])
	_draw_filled_ellipse(Rect2(-27, -15, 42, 30), body_color)
	_draw_filled_ellipse(Rect2(-4, -17, 34, 28), body_color.lightened(0.10))
	draw_polygon([Vector2(16, 6), Vector2(37, 12), Vector2(27, 21), Vector2(8, 15)], [jaw_color])
	draw_polygon([Vector2(18, 0), Vector2(39, -4), Vector2(35, 8), Vector2(15, 9)], [body_color.lightened(0.16)])
	draw_line(Vector2(22, 8), Vector2(35, 10), Color(0.95, 0.76, 0.55), 2.0)
	draw_circle(Vector2(16, -7), 3.3, Color(0.02, 0.01, 0.01))
	draw_circle(Vector2(17, -8), 1.1, Color(1.0, 0.82, 0.35))
	draw_line(Vector2(-13, 14), Vector2(-19, 27), outline, 4.0)
	draw_line(Vector2(7, 13), Vector2(4, 27), outline, 4.0)
	draw_line(Vector2(22, 9), Vector2(27, 21), outline, 3.0)


func _draw_filled_ellipse(rect: Rect2, ellipse_color: Color) -> void:
	var points := PackedVector2Array()
	var center := rect.get_center()
	var radii := rect.size * 0.5
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, ellipse_color)


func _vector_to_data(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


func _data_to_vector(data: Variant) -> Vector2:
	if typeof(data) != TYPE_DICTIONARY:
		return Vector2.ZERO
	return Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
