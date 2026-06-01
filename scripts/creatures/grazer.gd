extends CharacterBody2D

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const HUNGER_DIET := preload("res://scripts/creatures/hunger_diet.gd")
const SPECIES_PATH := "res://data/species/grazer.json"

enum State { IDLE, WANDER, EAT_PLANTS, SEEK_FOOD, FLEE, SCAVENGE, HUNT_SMALL_PREY, DEAD }

const WANDER_RADIUS := 190.0
const WANDER_REACHED_DISTANCE := 22.0
const PLAYER_FLEE_RANGE := 105.0
const VARNAK_FLEE_RANGE := 220.0
const LOW_BIOMASS_PERCENT := 35.0
const EAT_DURATION_SECONDS := 1.4
const SCAVENGE_DURATION_SECONDS := 1.8
const IDLE_DURATION_SECONDS := 0.9
const SMALL_PREY_DETECT_RANGE := 220.0
const SMALL_PREY_ATTACK_RANGE := 28.0
const PLANT_EAT_HUNGER_DROP := 0.45
const MEAT_HUNGER_DROP := 0.65
const WORLD_EDGE_PADDING := 28.0

var health := 45.0
var max_health := 45.0
var speed := 70.0
var fear := 0.7
var aggression := 0.15
var hunger := 0.0
var max_hunger := 1.0
var hunger_growth_rate := 0.3
var energy := 1.0
var plant_consumption_rate := 1.2
var plant_diet := 0.85
var meat_diet := 0.05
var scavenger_diet := 0.10
var current_niche := "HERBIVORE"
var size := 1.35
var reproduction_rate := 0.35
var state := State.WANDER
var biome_id := ""
var wander_target := Vector2.ZERO
var state_time := 0.0
var facing_angle := 0.0
var facing_side := 1.0
var player: Node2D
var flee_origin := Vector2.INF
var prey_target: Node2D
var rng := RandomNumberGenerator.new()
var hunger_diet := HUNGER_DIET.new()


func _ready() -> void:
	add_to_group("grazer")
	rng.randomize()
	player = get_tree().get_first_node_in_group("player")
	_load_species_data()
	if biome_id.is_empty():
		biome_id = _get_biome_id_for_position(global_position)
	_pick_wander_target()
	queue_redraw()


func setup(p_biome_id: String = "") -> void:
	biome_id = p_biome_id


func get_debug_data() -> Dictionary:
	var data := {
		"state": State.keys()[state],
		"biome_id": biome_id,
		"health": health,
		"max_health": max_health,
		"speed": speed,
		"fear": fear,
		"aggression": aggression,
		"current_niche": current_niche,
		"distance_to_player": global_position.distance_to(player.global_position) if is_instance_valid(player) else -1.0
	}
	data.merge(hunger_diet.get_debug_data(), true)
	return data


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
	hunger_diet.tick(delta, velocity.length() / max(speed, 1.0))
	_sync_hunger_fields()
	_update_state()
	_act(delta)
	move_and_slide()
	_enforce_world_bounds()


func _update_state() -> void:
	flee_origin = _get_flee_origin()
	if flee_origin != Vector2.INF:
		_set_state(State.FLEE)
		return
	if state == State.FLEE:
		_set_state(State.WANDER)
		_pick_wander_target()
	_sync_population_traits()
	var biomass_percent := _get_current_biomass_percent()
	if state == State.EAT_PLANTS and state_time <= 0.0:
		_consume_plants()
		_set_state(State.WANDER)
		_pick_wander_target()
		return
	if state == State.SCAVENGE and state_time <= 0.0:
		_scavenge_food()
		_set_state(State.WANDER)
		_pick_wander_target()
		return
	if state == State.HUNT_SMALL_PREY:
		if not is_instance_valid(prey_target):
			_set_state(State.SEEK_FOOD)
		return
	var nearest_prey := _find_nearest_small_prey()
	var food_target: String = hunger_diet.choose_food_target({
		"plants": clamp(biomass_percent / 100.0, 0.0, 1.0),
		"meat": 1.0 if is_instance_valid(nearest_prey) else 0.0,
		"scavenger": 0.65 if biomass_percent < LOW_BIOMASS_PERCENT else 0.10
	})
	var hunger_ratio: float = hunger_diet.get_hunger_ratio()
	var risk_drive: float = hunger_diet.get_risk_drive()
	if hunger_ratio > 0.28 and food_target == "plants" and biomass_percent >= LOW_BIOMASS_PERCENT:
		_set_state(State.EAT_PLANTS)
		state_time = EAT_DURATION_SECONDS
		return
	if hunger_ratio > 0.55 and biomass_percent < LOW_BIOMASS_PERCENT:
		if risk_drive > 0.74 and food_target == "meat" and meat_diet + aggression > 0.12 and is_instance_valid(nearest_prey):
			prey_target = nearest_prey
			_set_state(State.HUNT_SMALL_PREY)
			return
		if food_target == "scavenger" and scavenger_diet > 0.0:
			_set_state(State.SCAVENGE)
			state_time = SCAVENGE_DURATION_SECONDS
			return
		_set_state(State.SEEK_FOOD)
		return
	match state:
		State.IDLE:
			if state_time <= 0.0:
				_set_state(State.WANDER)
				_pick_wander_target()
		State.WANDER, State.SEEK_FOOD:
			if global_position.distance_to(wander_target) < WANDER_REACHED_DISTANCE:
				_set_state(State.IDLE)
				state_time = IDLE_DURATION_SECONDS


func _act(_delta: float) -> void:
	match state:
		State.IDLE, State.EAT_PLANTS, State.SCAVENGE:
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


func _hunt_small_prey() -> void:
	if not is_instance_valid(prey_target):
		velocity = Vector2.ZERO
		return
	var distance := global_position.distance_to(prey_target.global_position)
	if distance <= SMALL_PREY_ATTACK_RANGE and prey_target.has_method("take_damage"):
		prey_target.take_damage(999.0, "grazer")
		hunger_diet.eat("meat", MEAT_HUNGER_DROP)
		_sync_hunger_fields()
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
	velocity = direction.normalized() * move_speed
	_face_target(target)


func _face_target(target: Vector2) -> void:
	var direction := target - global_position
	if direction.length_squared() <= 1.0:
		return
	facing_angle = direction.angle()
	if abs(direction.x) > 4.0:
		facing_side = 1.0 if direction.x >= 0.0 else -1.0
	queue_redraw()


func _consume_plants() -> void:
	hunger_diet.eat("plants", PLANT_EAT_HUNGER_DROP)
	_sync_hunger_fields()
	get_node("/root/EventBus").emit_game_event("grazer_consumed_plants", {
		"biome_id": _get_current_biome_id(),
		"position": global_position,
		"plant_consumption_rate": plant_consumption_rate
	})


func _scavenge_food() -> void:
	hunger_diet.eat("scavenger", MEAT_HUNGER_DROP)
	_sync_hunger_fields()
	get_node("/root/EventBus").emit_game_event("grazer_scavenged", {
		"biome_id": _get_current_biome_id(),
		"position": global_position
	})


func _get_flee_origin() -> Vector2:
	var nearest_origin := Vector2.INF
	var nearest_distance := INF
	if is_instance_valid(player):
		var player_distance := global_position.distance_to(player.global_position)
		if player_distance < PLAYER_FLEE_RANGE * fear and aggression < 0.45:
			nearest_origin = player.global_position
			nearest_distance = player_distance
	for varnak in get_tree().get_nodes_in_group("varnak"):
		if not is_instance_valid(varnak):
			continue
		var distance := global_position.distance_to(varnak.global_position)
		if distance < VARNAK_FLEE_RANGE * fear and distance < nearest_distance:
			nearest_origin = varnak.global_position
			nearest_distance = distance
	return nearest_origin


func _find_nearest_small_prey() -> Node2D:
	var nearest: Node2D
	var nearest_distance := INF
	for small_prey in get_tree().get_nodes_in_group("small_prey"):
		if not is_instance_valid(small_prey):
			continue
		var distance := global_position.distance_to(small_prey.global_position)
		if distance < SMALL_PREY_DETECT_RANGE and distance < nearest_distance:
			nearest = small_prey
			nearest_distance = distance
	return nearest


func _pick_wander_target() -> void:
	var current_biome_id := _get_current_biome_id()
	for _attempt in 16:
		var candidate := global_position + Vector2(
			rng.randf_range(-WANDER_RADIUS, WANDER_RADIUS),
			rng.randf_range(-WANDER_RADIUS, WANDER_RADIUS)
		)
		if _is_position_in_biome(candidate, current_biome_id):
			wander_target = _clamp_to_world(candidate)
			return
	var limits := WORLD_CONFIG.get_player_limits()
	wander_target = _clamp_to_world(Vector2(
		clamp(global_position.x + rng.randf_range(-WANDER_RADIUS, WANDER_RADIUS), -limits.x, limits.x),
		clamp(global_position.y + rng.randf_range(-WANDER_RADIUS, WANDER_RADIUS), -limits.y, limits.y)
	))


func debug_return_to_world() -> void:
	_enforce_world_bounds(true)


func _enforce_world_bounds(force_retarget := false) -> void:
	var clamped_position := _clamp_to_world(global_position)
	if force_retarget or clamped_position.distance_squared_to(global_position) > 0.01:
		global_position = clamped_position
		velocity = Vector2.ZERO
		prey_target = null
		_set_state(State.WANDER)
		_pick_wander_target()


func _get_bounded_flee_target(away: Vector2) -> Vector2:
	var target := _clamp_to_world(global_position + away * WANDER_RADIUS)
	if target.distance_squared_to(global_position) <= 16.0:
		target = _get_world_rect().get_center()
	return target


func _clamp_to_world(position: Vector2) -> Vector2:
	var rect := _get_world_rect()
	return Vector2(
		clamp(position.x, rect.position.x, rect.end.x),
		clamp(position.y, rect.position.y, rect.end.y)
	)


func _get_world_rect() -> Rect2:
	return WORLD_CONFIG.WORLD_RECT.grow(-WORLD_EDGE_PADDING)


func _set_state(next_state: State) -> void:
	if state == next_state:
		return
	state = next_state
	queue_redraw()


func _die(source: String) -> void:
	state = State.DEAD
	var event_name := "grazer_killed_by_varnak" if source == "varnak" else "grazer_killed_by_player"
	get_node("/root/EventBus").emit_game_event(event_name, {
		"biome_id": _get_current_biome_id(),
		"position": global_position,
		"source": source
	})
	get_node("/root/EventBus").post_message("Grazer killed")
	queue_free()


func _load_species_data() -> void:
	if not FileAccess.file_exists(SPECIES_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPECIES_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var traits: Variant = Dictionary(parsed).get("base_traits", {})
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
		"scavenger_diet": scavenger_diet
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
	if not ecosystem or not ecosystem.has_method("get_grazer_traits"):
		return
	var traits: Dictionary = ecosystem.get_grazer_traits(_get_current_biome_id())
	if traits.is_empty():
		return
	plant_diet = float(traits.get("plant_diet", plant_diet))
	meat_diet = float(traits.get("meat_diet", meat_diet))
	scavenger_diet = float(traits.get("scavenger_diet", scavenger_diet))
	aggression = float(traits.get("aggression", aggression))
	current_niche = str(traits.get("current_niche", current_niche))
	hunger_diet.plant_diet = plant_diet
	hunger_diet.meat_diet = meat_diet
	hunger_diet.scavenger_diet = scavenger_diet


func _get_current_biome_id() -> String:
	var current_biome_id := _get_biome_id_for_position(global_position)
	if not current_biome_id.is_empty():
		biome_id = current_biome_id
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
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_filled_ellipse(rect: Rect2, ellipse_color: Color) -> void:
	var points := PackedVector2Array()
	var center := rect.get_center()
	var radii := rect.size * 0.5
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, ellipse_color)
