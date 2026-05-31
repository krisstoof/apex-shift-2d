extends CharacterBody2D

enum State { IDLE, WANDER, STALK, CHASE, ATTACK, FLEE }

const ATTACK_RANGE := 42.0
const ATTACK_ARC := deg_to_rad(78.0)
const ATTACK_VISUAL_DURATION := 0.14

var health := 90.0
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
var scared_fire: Node2D

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
		"state": int(state),
		"wander_target": _vector_to_data(wander_target),
		"attack_cooldown": attack_cooldown
	}


func restore_from_data(data: Dictionary) -> void:
	global_position = _data_to_vector(data.get("position", {}))
	facing_angle = float(data.get("facing_angle", data.get("rotation", facing_angle)))
	facing_side = float(data.get("facing_side", 1.0 if cos(facing_angle) >= 0.0 else -1.0))
	health = float(data.get("health", health))
	state = int(data.get("state", State.WANDER))
	wander_target = _data_to_vector(data.get("wander_target", _vector_to_data(wander_target)))
	attack_cooldown = float(data.get("attack_cooldown", attack_cooldown))
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	attack_cooldown = max(attack_cooldown - delta, 0.0)
	if attack_visual_time > 0.0:
		attack_visual_time = max(attack_visual_time - delta, 0.0)
		queue_redraw()
	_update_state()
	_act(delta)
	move_and_slide()


func take_damage(amount: float, source: String) -> void:
	health -= amount
	if health <= 0.0:
		_die(source)
	else:
		state = State.CHASE


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
	var distance := global_position.distance_to(player.global_position)
	var night_bonus := night_activity * 70.0 if day_night_system and day_night_system.is_night() else 0.0
	var detect_range := 210.0 + base_curiosity * 120.0 + night_bonus
	if distance < 34.0:
		state = State.ATTACK
	elif distance < detect_range:
		state = State.CHASE if aggression > 0.5 or distance < 115.0 else State.STALK
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
				attack_cooldown = 1.2
		State.FLEE:
			if not is_instance_valid(scared_fire):
				state = State.WANDER
				_pick_wander_target()
				_move_toward(wander_target, speed * 0.42)
				return
			var away := (global_position - scared_fire.global_position).normalized()
			velocity = away * speed * (1.1 + fire_fear)
			_face_target(global_position + away)


func _move_toward(target: Vector2, move_speed: float) -> void:
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


func _pick_wander_target() -> void:
	wander_target = Vector2(randf_range(-620, 620), randf_range(-360, 360))


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
	elif state == State.CHASE or state == State.ATTACK:
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
