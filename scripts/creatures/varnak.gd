extends CharacterBody2D

enum State { IDLE, WANDER, STALK, CHASE, ATTACK, FLEE }

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
var attack_cooldown := 0.0
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


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	attack_cooldown = max(attack_cooldown - delta, 0.0)
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
			if attack_cooldown <= 0.0 and player.has_method("receive_damage"):
				player.receive_damage(10.0 + aggression * 8.0)
				get_node("/root/EventBus").emit_game_event("varnak_attacked_player", {"damage": 10.0 + aggression * 8.0})
				attack_cooldown = 1.2
		State.FLEE:
			if not is_instance_valid(scared_fire):
				state = State.WANDER
				_pick_wander_target()
				_move_toward(wander_target, speed * 0.42)
				return
			var away := (global_position - scared_fire.global_position).normalized()
			velocity = away * speed * (1.1 + fire_fear)


func _move_toward(target: Vector2, move_speed: float) -> void:
	velocity = (target - global_position).normalized() * move_speed


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
	var body_color := Color(0.78, 0.12, 0.1)
	if state == State.FLEE:
		body_color = Color(0.95, 0.35, 0.08)
	elif state == State.CHASE or state == State.ATTACK:
		body_color = Color(0.95, 0.05, 0.03)
	draw_circle(Vector2.ZERO, 15.0, body_color)
	draw_circle(Vector2(7, -5), 3.0, Color.BLACK)
