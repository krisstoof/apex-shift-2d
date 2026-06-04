extends CharacterBody2D

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")

signal died(reason: String)

@export var walk_speed := 180.0
@export var run_speed := 290.0

const ATTACK_RANGE := 72.0
const ATTACK_ARC := deg_to_rad(82.0)
const ATTACK_VISUAL_DURATION := 0.16

var stats := PlayerStats.new()
var inventory := Inventory.new()
var has_spear := false
var has_bow := false
var torch_active := false
var torch_remaining_seconds := 0.0
var evolution_director: Node
var nearby_interactables: Array[Node] = []
var recipes := {}
var world_limits := WORLD_CONFIG.get_player_limits()
var attack_visual_time := 0.0
var bow_cooldown := 0.0
var is_swimming := false
var swim_ripple_time := 0.0
var is_dead := false
var death_reason := "unknown"

const CAMPFIRE_SCENE := preload("res://scenes/buildings/campfire.tscn")
const TRAP_SCENE := preload("res://scenes/buildings/trap.tscn")
const WALL_SCENE := preload("res://scenes/buildings/wall.tscn")
const STORAGE_BOX_SCENE := preload("res://scenes/buildings/storage_box.tscn")
const TENT_SCENE := preload("res://scenes/buildings/tent.tscn")
const ARROW_PROJECTILE_SCENE := preload("res://scenes/projectiles/arrow_projectile.tscn")

@onready var interaction_area: Area2D = $InteractionArea
@onready var attack_area: Area2D = $AttackArea

func _ready() -> void:
	add_to_group("player")
	recipes = _load_recipes()
	interaction_area.body_entered.connect(_on_interactable_entered)
	interaction_area.body_exited.connect(_on_interactable_exited)
	interaction_area.area_entered.connect(_on_interactable_entered)
	interaction_area.area_exited.connect(_on_interactable_exited)
	queue_redraw()


func _process(delta: float) -> void:
	if is_dead:
		return
	_tick_torch(delta)
	_face_mouse()
	bow_cooldown = max(bow_cooldown - delta, 0.0)
	if is_swimming:
		swim_ripple_time += delta
		queue_redraw()
	if attack_visual_time > 0.0:
		attack_visual_time = max(attack_visual_time - delta, 0.0)
		queue_redraw()
	if is_torch_active():
		queue_redraw()


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return
	_face_mouse()
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var terrain_speed := _get_terrain_speed_multiplier()
	var was_swimming := is_swimming
	is_swimming = _is_in_water()
	if is_swimming != was_swimming:
		queue_redraw()
	var wants_run := Input.is_key_pressed(KEY_SHIFT) and stats.can_run() and input_vector.length() > 0.0 and not is_swimming
	var speed := (run_speed if wants_run else walk_speed) * stats.get_speed_multiplier() * terrain_speed
	velocity = input_vector * speed
	move_and_slide()
	global_position.x = clamp(global_position.x, -world_limits.x, world_limits.x)
	global_position.y = clamp(global_position.y, -world_limits.y, world_limits.y)
	_update_campfire_regen_state()
	stats.tick(delta, wants_run)
	if not is_dead and stats.health <= 0.0:
		_die("hunger")


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_interact()
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				_melee_attack()
			KEY_G:
				if evolution_director:
					evolution_director.force_generation_change()
			KEY_1:
				_craft("campfire")
			KEY_2:
				_craft("spear")
			KEY_3:
				_craft("trap")
			KEY_4:
				_craft("wall")
			KEY_5:
				_craft("storage_box")
			KEY_6:
				_craft("tent")
			KEY_7:
				_eat("meat")
			KEY_8:
				_craft("torch")
			KEY_9:
				_craft("bow")
			KEY_T:
				_activate_torch()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if has_bow:
			_shoot_bow()
		else:
			_melee_attack()


func receive_damage(amount: float, source: String = "unknown") -> void:
	if is_dead:
		return
	stats.damage(amount)
	get_node("/root/EventBus").post_message("Player hit for %s" % int(amount))
	if stats.health <= 0.0:
		_die(source)


func activate_torch() -> bool:
	if is_dead:
		return false
	if torch_active and torch_remaining_seconds <= 0.0:
		deactivate_torch("expired")
	if is_torch_active():
		get_node("/root/EventBus").post_message("Torch already active")
		return false
	if not inventory.remove_item("torch", 1):
		get_node("/root/EventBus").post_message("No torch to activate")
		return false
	torch_active = true
	torch_remaining_seconds = GAME_BALANCE.TORCH_DURATION_SECONDS
	get_node("/root/EventBus").emit_game_event("torch_activated", {"active": torch_active, "remaining_seconds": torch_remaining_seconds})
	get_node("/root/EventBus").post_message("Torch activated")
	queue_redraw()
	return true


func is_torch_active() -> bool:
	return torch_active and torch_remaining_seconds > 0.0


func get_torch_remaining_seconds() -> float:
	return torch_remaining_seconds if is_torch_active() else 0.0


func _get_terrain_speed_multiplier() -> float:
	var world := get_tree().current_scene.get_node_or_null("World")
	if world and world.has_method("get_terrain_speed_multiplier"):
		return float(world.get_terrain_speed_multiplier(global_position))
	return 1.0


func _is_in_water() -> bool:
	var world := get_tree().current_scene.get_node_or_null("World")
	if world and world.has_method("is_position_in_water"):
		return world.is_position_in_water(global_position) == true
	return false


func _update_campfire_regen_state() -> void:
	var nearest_active_distance := INF
	var regen_active := false
	for campfire_node in get_tree().get_nodes_in_group("campfires"):
		if not is_instance_valid(campfire_node):
			continue
		if campfire_node.get("active") != true:
			continue
		var campfire := campfire_node as Node2D
		if not campfire:
			continue
		var distance := global_position.distance_to(campfire.global_position)
		nearest_active_distance = min(nearest_active_distance, distance)
		var radius := GAME_BALANCE.CAMPFIRE_STAMINA_REGEN_RADIUS
		var custom_radius: Variant = campfire_node.get("stamina_regen_radius")
		if custom_radius != null:
			radius = float(custom_radius)
		if distance <= radius:
			regen_active = true
	stats.set_campfire_regen(regen_active, nearest_active_distance if regen_active else -1.0)


func debug_add_item(item_name: String, amount := 1) -> void:
	if is_dead:
		return
	if item_name == "spear":
		has_spear = true
	elif item_name == "bow":
		debug_add_bow()
		return
	else:
		inventory.add_item(item_name, amount)
	get_node("/root/EventBus").emit_game_event("debug_item_added", {"item": item_name, "amount": amount})
	get_node("/root/EventBus").post_message("Debug added %s" % item_name)


func debug_add_bow() -> void:
	if is_dead:
		return
	has_bow = true
	get_node("/root/EventBus").emit_game_event("debug_item_added", {"item": "bow", "amount": 1})
	get_node("/root/EventBus").post_message("Debug gave bow")


func debug_damage_player() -> void:
	receive_damage(GAME_BALANCE.DEBUG_PLAYER_DAMAGE_AMOUNT, "debug damage")
	get_node("/root/EventBus").emit_game_event("debug_player_damaged", {"amount": GAME_BALANCE.DEBUG_PLAYER_DAMAGE_AMOUNT})


func debug_heal_player() -> void:
	if is_dead:
		return
	stats.heal(GAME_BALANCE.DEBUG_PLAYER_HEAL_AMOUNT)
	get_node("/root/EventBus").emit_game_event("debug_player_healed", {"amount": GAME_BALANCE.DEBUG_PLAYER_HEAL_AMOUNT})
	get_node("/root/EventBus").post_message("Debug healed player")


func debug_reduce_hunger_energy() -> void:
	if is_dead:
		return
	stats.reduce_hunger_energy(GAME_BALANCE.DEBUG_PLAYER_HUNGER_ENERGY_AMOUNT)
	get_node("/root/EventBus").emit_game_event("debug_player_hunger_energy_reduced", {"amount": GAME_BALANCE.DEBUG_PLAYER_HUNGER_ENERGY_AMOUNT})
	get_node("/root/EventBus").post_message("Debug reduced hunger/energy")


func debug_restore_hunger_energy() -> void:
	if is_dead:
		return
	stats.restore_hunger_energy(GAME_BALANCE.DEBUG_PLAYER_HUNGER_ENERGY_AMOUNT)
	get_node("/root/EventBus").emit_game_event("debug_player_hunger_energy_restored", {"amount": GAME_BALANCE.DEBUG_PLAYER_HUNGER_ENERGY_AMOUNT})
	get_node("/root/EventBus").post_message("Debug restored hunger/energy")


func deactivate_torch(reason := "manual") -> void:
	if is_dead:
		return
	if not torch_active and torch_remaining_seconds <= 0.0:
		return
	torch_active = false
	torch_remaining_seconds = 0.0
	if reason == "expired":
		get_node("/root/EventBus").emit_game_event("torch_expired", {"active": false, "remaining_seconds": 0.0})
	get_node("/root/EventBus").emit_game_event("torch_deactivated", {"active": false, "remaining_seconds": 0.0, "reason": reason})
	get_node("/root/EventBus").post_message("Torch burned out" if reason == "expired" else "Torch deactivated")
	queue_redraw()


func clear_inactive_torch_state() -> void:
	if is_dead:
		return
	torch_active = false
	torch_remaining_seconds = 0.0
	queue_redraw()


func recover_from_sleep() -> void:
	if is_dead:
		return
	stats.sleep_recover()


func _interact() -> void:
	if is_dead:
		return
	for node in nearby_interactables.duplicate():
		if is_instance_valid(node) and node.has_method("interact"):
			node.interact(self)
			return
	get_node("/root/EventBus").post_message("Nothing to interact with")


func get_interaction_prompt() -> String:
	if is_dead:
		return ""
	for node in nearby_interactables:
		if is_instance_valid(node) and node.has_method("get_prompt"):
			return node.get_prompt()
		if is_instance_valid(node) and node.has_method("interact"):
			return "E: interact"
	return ""


func _melee_attack() -> void:
	if is_dead:
		return
	if not stats.spend_stamina(12.0):
		get_node("/root/EventBus").post_message("Too tired to attack")
		return
	attack_visual_time = ATTACK_VISUAL_DURATION
	queue_redraw()
	var damage := 38.0 if has_spear else 18.0
	var target := _get_attack_target()
	if target:
		target.take_damage(damage, "player")
		get_node("/root/EventBus").post_message("Hit %s" % _get_attack_target_label(target))
		return
	get_node("/root/EventBus").post_message("Attack missed")


func _shoot_bow() -> void:
	if is_dead:
		return
	if bow_cooldown > 0.0:
		return
	var stamina_cost := float(GAME_BALANCE.RANGED_COMBAT.get("bow_stamina_cost", 8.0))
	if not stats.spend_stamina(stamina_cost):
		get_node("/root/EventBus").post_message("Too tired to shoot")
		return
	var direction := get_global_mouse_position() - global_position
	if direction.length_squared() <= 0.0:
		direction = Vector2.RIGHT.rotated(rotation)
	else:
		direction = direction.normalized()
	var arrow := ARROW_PROJECTILE_SCENE.instantiate() as Node2D
	arrow.global_position = global_position + direction * 24.0
	get_tree().current_scene.add_child(arrow)
	if arrow.has_method("setup"):
		arrow.setup(direction, self, float(GAME_BALANCE.RANGED_COMBAT.get("bow_damage", 28.0)), "player")
	bow_cooldown = float(GAME_BALANCE.RANGED_COMBAT.get("bow_cooldown_seconds", 0.75))
	get_node("/root/EventBus").emit_game_event("arrow_fired", {
		"position": global_position,
		"direction": direction
	})


func _get_attack_target() -> Node:
	var best_target: Node
	var best_distance := INF
	for body in attack_area.get_overlapping_bodies():
		if not _is_attackable_creature(body):
			continue
		if not _is_in_attack_arc(body.global_position):
			continue
		var distance := global_position.distance_to(body.global_position)
		if distance < best_distance:
			best_distance = distance
			best_target = body
	return best_target


func _is_attackable_creature(body: Node) -> bool:
	if not body.has_method("take_damage"):
		return false
	return body.is_in_group("varnak") or body.is_in_group("small_prey") or body.is_in_group("grazer")


func _get_attack_target_label(target: Node) -> String:
	if target.is_in_group("grazer"):
		return "Grazer"
	if target.is_in_group("small_prey"):
		return "SmallPrey"
	return "Varnak"


func _is_in_attack_arc(target_position: Vector2) -> bool:
	var to_target := target_position - global_position
	var distance := to_target.length()
	if distance <= 0.0 or distance > ATTACK_RANGE:
		return false
	var forward := Vector2.RIGHT.rotated(rotation)
	return abs(forward.angle_to(to_target.normalized())) <= ATTACK_ARC * 0.5


func _craft(item_name: String) -> void:
	if is_dead:
		return
	var recipe: Dictionary = recipes.get(item_name, {})
	if recipe.is_empty():
		get_node("/root/EventBus").post_message("Unknown recipe: %s" % item_name)
		return
	if item_name == "bow" and has_bow:
		get_node("/root/EventBus").post_message("Bow already crafted")
		return
	var missing := _get_missing_ingredients(recipe)
	if not missing.is_empty():
		get_node("/root/EventBus").post_message("Not enough resources for %s: %s" % [item_name, ", ".join(missing)])
		return
	for ingredient in recipe.keys():
		inventory.remove_item(ingredient, int(recipe[ingredient]))
	if item_name == "torch":
		inventory.add_item("torch", 1)
		get_node("/root/EventBus").emit_game_event("player_crafted_torch", {"count": inventory.get_amount("torch")})
		get_node("/root/EventBus").post_message("Crafted torch")
		return
	if item_name == "spear":
		has_spear = true
		get_node("/root/EventBus").post_message("Crafted spear")
		return
	if item_name == "bow":
		has_bow = true
		get_node("/root/EventBus").emit_game_event("player_crafted_bow", {"has_bow": has_bow})
		get_node("/root/EventBus").post_message("Crafted bow")
		return
	var scene: PackedScene = {
		"campfire": CAMPFIRE_SCENE,
		"trap": TRAP_SCENE,
		"wall": WALL_SCENE,
		"storage_box": STORAGE_BOX_SCENE,
		"tent": TENT_SCENE
	}[item_name]
	var building := scene.instantiate()
	building.global_position = global_position + Vector2(56, 0).rotated(rotation)
	get_tree().current_scene.add_child(building)
	get_node("/root/EventBus").emit_game_event("player_crafted_%s" % item_name, {"position": building.global_position})
	get_node("/root/EventBus").post_message("Crafted %s" % item_name)


func _eat(item_name: String) -> void:
	if is_dead:
		return
	if item_name != "meat":
		return
	if not inventory.remove_item(item_name, 1):
		get_node("/root/EventBus").post_message("No meat to eat")
		return
	stats.eat_food(GAME_BALANCE.PLAYER_MEAT_NUTRITION)
	get_node("/root/EventBus").post_message("Ate meat")


func _activate_torch() -> void:
	if is_dead:
		return
	if is_torch_active():
		deactivate_torch("manual")
		return
	activate_torch()


func _tick_torch(delta: float) -> void:
	if is_dead:
		return
	if not torch_active:
		return
	torch_remaining_seconds = max(torch_remaining_seconds - delta, 0.0)
	if torch_remaining_seconds > 0.0:
		return
	deactivate_torch("expired")


func _get_missing_ingredients(recipe: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	for ingredient in recipe.keys():
		var required := int(recipe[ingredient])
		var owned := inventory.get_amount(ingredient)
		if owned < required:
			missing.append("%s %d/%d" % [ingredient, owned, required])
	return missing


func _on_interactable_entered(node: Node) -> void:
	if node.has_method("interact") and not nearby_interactables.has(node):
		nearby_interactables.append(node)


func _on_interactable_exited(node: Node) -> void:
	nearby_interactables.erase(node)


func _load_recipes() -> Dictionary:
	return GAME_BALANCE.CRAFTING_COSTS.duplicate(true)


func _face_mouse() -> void:
	if is_dead:
		return
	var direction := get_global_mouse_position() - global_position
	if direction.length_squared() > 1.0:
		rotation = direction.angle()


func _draw() -> void:
	_draw_torch_light()
	_draw_attack_visual()
	if is_swimming:
		_draw_swimming_body()
	else:
		draw_circle(Vector2.ZERO, 14.0, Color(0.2, 0.48, 1.0))
		draw_line(Vector2.ZERO, Vector2(18, 0), Color.WHITE, 3.0)


func _draw_swimming_body() -> void:
	var ripple_phase := sin(swim_ripple_time * 8.0) * 0.5 + 0.5
	draw_arc(Vector2.ZERO, 23.0 + ripple_phase * 4.0, deg_to_rad(20.0), deg_to_rad(160.0), 24, Color(0.72, 0.93, 1.0, 0.45), 2.0)
	draw_arc(Vector2.ZERO, 28.0 - ripple_phase * 3.0, deg_to_rad(200.0), deg_to_rad(340.0), 24, Color(0.72, 0.93, 1.0, 0.34), 2.0)
	draw_circle(Vector2.ZERO, 10.5, Color(0.18, 0.42, 0.92))
	draw_line(Vector2.ZERO, Vector2(15, 0), Color(0.86, 0.95, 1.0), 2.0)


func _die(reason: String) -> void:
	if is_dead:
		return
	is_dead = true
	death_reason = reason if not reason.is_empty() else "unknown"
	velocity = Vector2.ZERO
	attack_visual_time = 0.0
	bow_cooldown = 0.0
	is_swimming = false
	swim_ripple_time = 0.0
	set_process(false)
	set_physics_process(false)
	set_process_unhandled_input(false)
	queue_redraw()
	died.emit(death_reason)


func _draw_torch_light() -> void:
	if not is_torch_active():
		return
	var night_amount := _get_night_amount()
	var flicker := GAME_BALANCE.TORCH_LIGHT_FLICKER_BASE
	flicker += sin(Time.get_ticks_msec() * GAME_BALANCE.TORCH_LIGHT_FLICKER_PRIMARY_SPEED) * GAME_BALANCE.TORCH_LIGHT_FLICKER_PRIMARY_AMOUNT
	flicker += sin(Time.get_ticks_msec() * GAME_BALANCE.TORCH_LIGHT_FLICKER_SECONDARY_SPEED) * GAME_BALANCE.TORCH_LIGHT_FLICKER_SECONDARY_AMOUNT
	var strength := (GAME_BALANCE.TORCH_LIGHT_BASE_STRENGTH + night_amount * GAME_BALANCE.TORCH_LIGHT_NIGHT_STRENGTH) * GAME_BALANCE.TORCH_LIGHT_INTENSITY * flicker
	var radius := GAME_BALANCE.TORCH_LIGHT_RADIUS
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.48, 0.08, strength * GAME_BALANCE.TORCH_LIGHT_OUTER_ALPHA))
	draw_circle(Vector2.ZERO, radius * GAME_BALANCE.TORCH_LIGHT_MID_RADIUS_MULTIPLIER, Color(1.0, 0.62, 0.12, strength * GAME_BALANCE.TORCH_LIGHT_MID_ALPHA))
	draw_circle(GAME_BALANCE.TORCH_LIGHT_OFFSET, radius * GAME_BALANCE.TORCH_LIGHT_CORE_RADIUS_MULTIPLIER, Color(1.0, 0.86, 0.28, strength * GAME_BALANCE.TORCH_LIGHT_CORE_ALPHA))


func _get_night_amount() -> float:
	var scene := get_tree().current_scene
	if not scene:
		return 0.0
	var day_night_system := scene.get_node_or_null("DayNightSystem")
	if day_night_system:
		return float(day_night_system.night_amount)
	return 0.0


func _draw_attack_visual() -> void:
	if attack_visual_time <= 0.0:
		return
	var progress := attack_visual_time / ATTACK_VISUAL_DURATION
	var alpha := 0.18 + progress * 0.34
	var points := PackedVector2Array([Vector2.ZERO])
	var start_angle := -ATTACK_ARC * 0.5
	var steps := 9
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var angle: float = lerp(start_angle, -start_angle, t)
		points.append(Vector2.RIGHT.rotated(angle) * ATTACK_RANGE)
	draw_colored_polygon(points, Color(1.0, 0.86, 0.30, alpha))
	draw_arc(Vector2.ZERO, ATTACK_RANGE, start_angle, -start_angle, steps, Color(1.0, 0.92, 0.48, alpha + 0.25), 4.0)
