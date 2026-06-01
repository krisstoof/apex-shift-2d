extends CharacterBody2D

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")

enum State { IDLE, WANDER, STALK, CHASE, ATTACK, FLEE, HUNT_ECOSYSTEM }

const ATTACK_RANGE := 42.0
const ATTACK_ARC := deg_to_rad(78.0)
const ATTACK_VISUAL_DURATION := 0.14
const BASE_HEALTH := 90.0
const HUNGER_GROWTH_RATE := 0.045
const HUNT_DETECTION_RANGE := 260.0
const HUNT_PLAYER_SAFE_DISTANCE := 135.0
const HUNT_HUNGER_THRESHOLD := 0.35
const HUNT_FEED_AMOUNT := 0.55
const WORLD_EDGE_PADDING := 32.0

var health := BASE_HEALTH
var max_health := BASE_HEALTH
var hunger := 0.0
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
var night_health_bonus_active := false
var scared_fire: Node2D
var ecosystem_target: Node2D
var ecosystem_target_kind := ""

func _ready() -> void:
	add_to_group("varnak")
	player = get_tree().get_first_node_in_group("player")
	_pick_wander_target()
	queue_redraw()


func apply_profile(profile: Dictionary) -> void:
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
		"position": _vector_to_data(global_position),
		"facing_angle": facing_angle,
		"facing_side": facing_side,
		"health": health,
		"max_health": max_health,
		"hunger": hunger,
		"night_health_bonus_active": night_health_bonus_active,
		"state": int(state),
		"wander_target": _vector_to_data(wander_target),
		"attack_cooldown": attack_cooldown
	}


func get_debug_data() -> Dictionary:
	return {
		"state": State.keys()[state],
		"health": health,
		"max_health": max_health,
		"hunger": hunger,
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
	global_position = _clamp_to_world(_data_to_vector(data.get("position", {})))
	facing_angle = float(data.get("facing_angle", data.get("rotation", facing_angle)))
	facing_side = float(data.get("facing_side", 1.0 if cos(facing_angle) >= 0.0 else -1.0))
	max_health = max(float(data.get("max_health", max_health)), 1.0)
	health = clamp(float(data.get("health", health)), 0.0, max_health)
	hunger = clamp(float(data.get("hunger", hunger)), 0.0, 1.0)
	night_health_bonus_active = data.get("night_health_bonus_active", night_health_bonus_active) == true
	state = int(data.get("state", State.WANDER))
	wander_target = _clamp_to_world(_data_to_vector(data.get("wander_target", _vector_to_data(wander_target))))
	attack_cooldown = float(data.get("attack_cooldown", attack_cooldown))
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	_update_night_health_bonus()
	hunger = clamp(hunger + HUNGER_GROWTH_RATE * delta, 0.0, 1.0)
	attack_cooldown = max(attack_cooldown - delta, 0.0)
	if attack_visual_time > 0.0:
		attack_visual_time = max(attack_visual_time - delta, 0.0)
		queue_redraw()
	_update_state()
	_act(delta)
	move_and_slide()
	_enforce_world_bounds()


func take_damage(amount: float, source: String) -> void:
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
		state = State.FLEE
		if randf() < 0.012:
			get_node("/root/EventBus").emit_game_event("varnak_scared_by_fire", {"position": global_position})
			get_node("/root/EventBus").post_message("Varnak scared by fire")
		return
	if state == State.FLEE:
		state = State.WANDER
	if not is_instance_valid(ecosystem_target):
		ecosystem_target = null
		ecosystem_target_kind = ""
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
			state = State.FLEE
			return
	if _should_prioritize_player(distance, detect_range, close_chase_range, effective_aggression):
		ecosystem_target = null
		ecosystem_target_kind = ""
		if distance < 34.0:
			state = State.ATTACK
		elif distance < detect_range:
			state = State.CHASE if effective_aggression > 0.5 or distance < close_chase_range else State.STALK
		return
	var prey := _find_ecosystem_target()
	if is_instance_valid(prey) and _should_hunt_ecosystem(distance):
		ecosystem_target = prey
		ecosystem_target_kind = _get_ecosystem_target_kind(prey)
		state = State.HUNT_ECOSYSTEM
		return
	if distance < 34.0:
		state = State.ATTACK
	elif distance < detect_range:
		state = State.CHASE if effective_aggression > 0.5 or distance < close_chase_range else State.STALK
	elif global_position.distance_to(wander_target) < 20.0:
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
				player.receive_damage(10.0 + aggression * 8.0)
				get_node("/root/EventBus").emit_game_event("varnak_attacked_player", {"damage": 10.0 + aggression * 8.0})
				attack_visual_time = ATTACK_VISUAL_DURATION
				queue_redraw()
				attack_cooldown = 1.2 * (GAME_BALANCE.TORCH_ATTACK_COOLDOWN_MULTIPLIER if _is_torch_protecting_player(global_position.distance_to(player.global_position)) else 1.0)
		State.HUNT_ECOSYSTEM:
			_hunt_ecosystem_target()
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
	if state == State.CHASE or state == State.STALK or state == State.ATTACK:
		return distance < detect_range
	if effective_aggression > 0.62 and distance < detect_range:
		return true
	if day_night_system and day_night_system.is_night() and night_activity > 0.55 and distance < detect_range:
		return true
	return false


func _should_hunt_ecosystem(player_distance: float) -> bool:
	if player_distance < HUNT_PLAYER_SAFE_DISTANCE:
		return false
	if hunger >= HUNT_HUNGER_THRESHOLD:
		return true
	return _get_biome_prey_pressure() > 0.35 and player_distance > HUNT_PLAYER_SAFE_DISTANCE * 1.4


func _hunt_ecosystem_target() -> void:
	if not is_instance_valid(ecosystem_target):
		state = State.WANDER
		_pick_wander_target()
		return
	var distance := global_position.distance_to(ecosystem_target.global_position)
	if distance <= ATTACK_RANGE and attack_cooldown <= 0.0 and ecosystem_target.has_method("take_damage"):
		var hunted_kind := ecosystem_target_kind
		ecosystem_target.take_damage(999.0, "varnak")
		hunger = max(hunger - HUNT_FEED_AMOUNT, 0.0)
		var event_name := "varnak_hunted_grazer" if hunted_kind == "grazer" else "varnak_hunted_small_prey"
		get_node("/root/EventBus").emit_game_event(event_name, {"position": global_position})
		get_node("/root/EventBus").post_message("Varnak hunted %s" % ("Grazer" if hunted_kind == "grazer" else "SmallPrey"))
		attack_visual_time = ATTACK_VISUAL_DURATION
		attack_cooldown = 1.0
		ecosystem_target = null
		ecosystem_target_kind = ""
		state = State.WANDER
		queue_redraw()
		return
	_move_toward(ecosystem_target.global_position, speed * 0.92)


func _find_ecosystem_target() -> Node2D:
	var best_target: Node2D
	var best_score := INF
	for group_name in ["small_prey", "grazer"]:
		for creature in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(creature):
				continue
			if not _get_world_rect().has_point(creature.global_position):
				continue
			var distance := global_position.distance_to(creature.global_position)
			if distance > HUNT_DETECTION_RANGE:
				continue
			var score := distance * (1.35 if group_name == "grazer" else 1.0)
			if score < best_score:
				best_score = score
				best_target = creature
	return best_target


func _get_ecosystem_target_kind(target: Node) -> String:
	if target.is_in_group("grazer"):
		return "grazer"
	return "small_prey"


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
	velocity = direction.normalized() * move_speed
	_face_target(target)


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
	for trap in get_tree().get_nodes_in_group("traps"):
		if global_position.distance_to(trap.global_position) < 85.0:
			return target + (global_position - trap.global_position).normalized() * 120.0
	return target


func _nearest_active_campfire() -> Node2D:
	var nearest: Node2D
	var nearest_distance := INF
	for campfire in get_tree().get_nodes_in_group("campfires"):
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
	wander_target = Vector2(
		randf_range(rect.position.x, rect.end.x),
		randf_range(rect.position.y, rect.end.y)
	)


func debug_return_to_world() -> void:
	_enforce_world_bounds(true)


func _enforce_world_bounds(force_retarget := false) -> void:
	var clamped_position := _clamp_to_world(global_position)
	if force_retarget or clamped_position.distance_squared_to(global_position) > 0.01:
		global_position = clamped_position
		velocity = Vector2.ZERO
		ecosystem_target = null
		ecosystem_target_kind = ""
		state = State.WANDER
		_pick_wander_target()


func _get_bounded_flee_target(away: Vector2) -> Vector2:
	var target := _clamp_to_world(global_position + away * 180.0)
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


func _die(source: String) -> void:
	var event_name := "varnak_killed_by_trap" if source == "trap" else "varnak_killed_by_player"
	get_node("/root/EventBus").emit_game_event(event_name, {"position": global_position})
	get_node("/root/EventBus").post_message("Varnak killed by %s" % source)
	if is_instance_valid(player) and global_position.distance_to(player.global_position) < 90.0:
		player.inventory.add_item("meat", 1)
		player.inventory.add_item("hide", 1)
		player.inventory.add_item("bone", 1)
	queue_free()


func _draw() -> void:
	_draw_attack_visual()
	var body_color := Color(0.78, 0.12, 0.1)
	var jaw_color := Color(0.42, 0.05, 0.04)
	var ear_color := Color(0.58, 0.06, 0.05)
	if state == State.FLEE:
		body_color = Color(0.95, 0.35, 0.08)
		ear_color = Color(0.80, 0.22, 0.05)
	elif state == State.CHASE or state == State.ATTACK or state == State.HUNT_ECOSYSTEM:
		body_color = Color(0.95, 0.05, 0.03)
		jaw_color = Color(0.55, 0.02, 0.02)
	_apply_upright_body_transform()
	_draw_varnak_body(body_color, jaw_color, ear_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
