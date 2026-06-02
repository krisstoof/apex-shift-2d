extends CharacterBody2D

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const HUNGER_DIET := preload("res://scripts/creatures/hunger_diet.gd")
const SPECIES_PATH := "res://data/species/small_prey.json"

enum State { IDLE, WANDER, SEEK_FOOD, EAT, FLEE, DEAD }

const WANDER_RADIUS := 140.0
const WANDER_REACHED_DISTANCE := 18.0
const PLAYER_FLEE_RANGE := 130.0
const VARNAK_FLEE_RANGE := 180.0
const EAT_INTERVAL_SECONDS := 6.0
const EAT_DURATION_SECONDS := 1.1
const IDLE_DURATION_SECONDS := 0.8
const VEGETATION_EAT_RANGE := 170.0
const VEGETATION_CONSUME_RANGE := 26.0
const WORLD_EDGE_PADDING := 24.0

var health := 20.0
var max_health := 20.0
var speed := 90.0
var fear := 0.9
var hunger := 0.0
var max_hunger := 1.0
var hunger_growth_rate := 0.2
var energy := 1.0
var plant_diet := 1.0
var meat_diet := 0.0
var scavenger_diet := 0.0
var plant_consumption_rate := 0.4
var reproduction_value := 0.6
var state := State.WANDER
var biome_id := ""
var wander_target := Vector2.ZERO
var state_time := 0.0
var eat_cooldown := 0.0
var facing_angle := 0.0
var facing_side := 1.0
var player: Node2D
var flee_origin := Vector2.INF
var plant_target: Node2D
var rng := RandomNumberGenerator.new()
var hunger_diet := HUNGER_DIET.new()


func _ready() -> void:
	add_to_group("small_prey")
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
		"plant_consumption_rate": plant_consumption_rate,
		"reproduction_value": reproduction_value,
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
	eat_cooldown = max(eat_cooldown - delta, 0.0)
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
		plant_target = null
	if state == State.EAT:
		if state_time <= 0.0:
			_consume_plants()
			_set_state(State.WANDER)
			_pick_wander_target()
		return
	if state == State.SEEK_FOOD and _try_update_plant_target():
		return
	if eat_cooldown <= 0.0 and hunger_diet.get_hunger_ratio() > 0.25:
		if _set_nearest_plant_target():
			_set_state(State.SEEK_FOOD)
		else:
			_set_state(State.EAT)
			state_time = EAT_DURATION_SECONDS
		return
	match state:
		State.IDLE:
			if state_time <= 0.0:
				_set_state(State.WANDER)
				_pick_wander_target()
		State.WANDER:
			if global_position.distance_to(wander_target) < WANDER_REACHED_DISTANCE:
				_set_state(State.IDLE)
				state_time = IDLE_DURATION_SECONDS
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
	velocity = direction.normalized() * move_speed * _get_terrain_speed_multiplier()
	_face_target(target)


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
		if player_distance < PLAYER_FLEE_RANGE * fear:
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


func _consume_plants() -> void:
	var eaten_food := _consume_target_vegetation()
	var biomass_impact := plant_consumption_rate
	hunger_diet.eat("plants", max(0.5, eaten_food))
	_sync_hunger_fields()
	eat_cooldown = EAT_INTERVAL_SECONDS
	var current_biome_id := _get_current_biome_id()
	get_node("/root/EventBus").emit_game_event("small_prey_consumed_plants", {
		"biome_id": current_biome_id,
		"position": global_position,
		"plant_consumption_rate": plant_consumption_rate,
		"biomass_impact": biomass_impact
	})
	plant_target = null


func _consume_target_vegetation() -> float:
	if is_instance_valid(plant_target) and _is_edible_vegetation_target(plant_target):
		var distance := global_position.distance_to(plant_target.global_position)
		if distance <= VEGETATION_CONSUME_RANGE and plant_target.has_method("consume_by_creature"):
			return float(plant_target.consume_by_creature(self, plant_consumption_rate))
	return _consume_nearest_vegetation(VEGETATION_CONSUME_RANGE)


func _consume_nearest_vegetation(search_range: float = VEGETATION_EAT_RANGE) -> float:
	var nearest := _find_nearest_edible_vegetation(search_range)
	if is_instance_valid(nearest) and nearest.has_method("consume_by_creature"):
		return float(nearest.consume_by_creature(self, plant_consumption_rate))
	return 0.0


func _try_update_plant_target() -> bool:
	if not is_instance_valid(plant_target) or not _is_edible_vegetation_target(plant_target):
		if not _set_nearest_plant_target():
			_set_state(State.WANDER)
			_pick_wander_target()
			return true
	wander_target = _clamp_to_world(plant_target.global_position)
	if global_position.distance_to(plant_target.global_position) <= VEGETATION_CONSUME_RANGE:
		_set_state(State.EAT)
		state_time = EAT_DURATION_SECONDS
	return true


func _set_nearest_plant_target() -> bool:
	plant_target = _find_nearest_edible_vegetation(VEGETATION_EAT_RANGE)
	if not is_instance_valid(plant_target):
		return false
	wander_target = _clamp_to_world(plant_target.global_position)
	return true


func _find_nearest_edible_vegetation(search_range: float) -> Node2D:
	var nearest: Node2D
	var nearest_distance := search_range
	var current_biome_id := _get_current_biome_id()
	for vegetation in get_tree().get_nodes_in_group("edible_vegetation"):
		if not _is_edible_vegetation_target(vegetation):
			continue
		var distance := global_position.distance_to(vegetation.global_position)
		if _get_biome_id_for_position(vegetation.global_position) != current_biome_id:
			distance *= 1.8
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = vegetation
	return nearest


func _is_edible_vegetation_target(vegetation: Node) -> bool:
	return is_instance_valid(vegetation) and vegetation is Node2D and vegetation.get("is_edible_by_herbivores") == true


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
		plant_target = null
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


func _get_terrain_speed_multiplier() -> float:
	var world := get_tree().current_scene.get_node_or_null("World")
	if world and world.has_method("get_terrain_speed_multiplier"):
		return float(world.get_terrain_speed_multiplier(global_position))
	return 1.0


func _set_state(next_state: State) -> void:
	if state == next_state:
		return
	state = next_state
	queue_redraw()


func _die(source: String) -> void:
	state = State.DEAD
	var event_name := "small_prey_killed_by_player"
	if source == "varnak":
		event_name = "small_prey_killed_by_varnak"
	elif source == "grazer":
		event_name = "small_prey_killed_by_grazer"
	get_node("/root/EventBus").emit_game_event(event_name, {
		"biome_id": _get_current_biome_id(),
		"position": global_position,
		"source": source
	})
	get_node("/root/EventBus").post_message("Small prey killed")
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


func _get_current_biome_id() -> String:
	var current_biome_id := _get_biome_id_for_position(global_position)
	if not current_biome_id.is_empty():
		biome_id = current_biome_id
	return biome_id


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
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
