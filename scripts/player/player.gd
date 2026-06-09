extends CharacterBody2D

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const INVENTORY := preload("res://scripts/player/inventory.gd")

signal died(reason: String)

@export var walk_speed := 180.0
@export var run_speed := 290.0

const ATTACK_RANGE := 72.0
const ATTACK_ARC := deg_to_rad(82.0)
const ATTACK_VISUAL_DURATION := 0.16

var stats := PlayerStats.new()
var inventory := INVENTORY.new()
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
var god_mode := false
var checked_start_safe_spawn := false
var campfire_regen_refresh_timer := 0.0
var debug_world_query_override: Variant = null
var torch_light: PointLight2D
var torch_light_flicker_time := 0.0
static var cached_light_texture: Texture2D
@onready var player_camera: Camera2D = $Camera2D

const CAMPFIRE_SCENE := preload("res://scenes/buildings/campfire.tscn")
const TRAP_SCENE := preload("res://scenes/buildings/trap.tscn")
const WALL_SCENE := preload("res://scenes/buildings/wall.tscn")
const STORAGE_BOX_SCENE := preload("res://scenes/buildings/storage_box.tscn")
const TENT_SCENE := preload("res://scenes/buildings/tent.tscn")
const ARROW_PROJECTILE_SCENE := preload("res://scenes/projectiles/arrow_projectile.tscn")
const MIN_CAMERA_ZOOM := 1.30
const MAX_CAMERA_ZOOM := 1.80
const DEFAULT_CAMERA_ZOOM := Vector2(1.50, 1.50)
const CAMERA_ZOOM_STEP := 0.10

const PLAYER_SKIN_COLOR := Color(0.82, 0.68, 0.54)
const PLAYER_HAIR_COLOR := Color(0.24, 0.16, 0.10)
const PLAYER_SHIRT_COLOR := Color(0.32, 0.52, 0.28)
const PLAYER_SHIRT_SHADE_COLOR := Color(0.18, 0.28, 0.18)
const PLAYER_PANTS_COLOR := Color(0.24, 0.18, 0.15)
const PLAYER_PANTS_SHADE_COLOR := Color(0.12, 0.10, 0.08)
const PLAYER_SHOE_COLOR := Color(0.10, 0.09, 0.08)
const PLAYER_HUMAN_HEAD_RADIUS := 6.2
const PLAYER_POSE_PIVOT := Vector2(7.0, 7.0)
const PLAYER_POSE_MAX_TILT := deg_to_rad(16.0)

@onready var interaction_area: Area2D = $InteractionArea
@onready var attack_area: Area2D = $AttackArea

var aim_direction := Vector2.RIGHT

func _ready() -> void:
	add_to_group("player")
	recipes = _load_recipes()
	interaction_area.body_entered.connect(_on_interactable_entered)
	interaction_area.body_exited.connect(_on_interactable_exited)
	interaction_area.area_entered.connect(_on_interactable_entered)
	interaction_area.area_exited.connect(_on_interactable_exited)
	rotation = 0.0
	_apply_default_camera_zoom()
	var main := get_tree().current_scene
	var world := main.get_node_or_null("World") if main else null
	var hud := main.get_node_or_null("HUD") if main else null
	print("[VIEW_SCALE_DEBUG] window_size=%s viewport_size=%s camera_zoom=%s player_scale=%s main_scale=%s world_scale=%s hud_scale=%s" % [
		DisplayServer.window_get_size(),
		get_viewport().get_visible_rect().size,
		player_camera.zoom if player_camera else Vector2.ZERO,
		scale,
		main.scale if main and main is Node2D else Vector2.ONE,
		world.scale if world and world is Node2D else Vector2.ONE,
		hud.scale if hud and hud is CanvasLayer else Vector2.ONE
	])
	_ensure_torch_light()
	_update_campfire_regen_state()
	queue_redraw()


func _process(delta: float) -> void:
	if is_dead:
		return
	_tick_torch(delta)
	_update_torch_light(delta)
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
	if not checked_start_safe_spawn:
		checked_start_safe_spawn = true
		var world := _get_world_node()
		if world and world.has_method("get_safe_player_start_position") and world_query_is_deep_water(global_position):
			global_position = world.call("get_safe_player_start_position")
	_face_mouse()
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var terrain_speed := _get_terrain_speed_multiplier()
	var previous_position := global_position
	var was_swimming := is_swimming
	is_swimming = _is_in_water()
	if is_swimming != was_swimming:
		queue_redraw()
	var wants_run := Input.is_key_pressed(KEY_SHIFT) and stats.can_run() and input_vector.length() > 0.0 and not is_swimming
	var speed := (run_speed if wants_run else walk_speed) * stats.get_speed_multiplier() * terrain_speed
	var world_query: Variant = _get_world_query()
	velocity = input_vector * speed
	move_and_slide()
	var in_deep_water := false
	if world_query != null and world_query.has_method("is_position_in_deep_water"):
		in_deep_water = world_query.is_position_in_deep_water(global_position) == true
	if not WORLD_CONFIG.WORLD_RECT.grow(-32.0).has_point(global_position) or in_deep_water:
		global_position = previous_position
		velocity = Vector2.ZERO
	_refresh_campfire_regen_state(delta)
	var previous_health := stats.health
	stats.tick(delta, wants_run)
	if god_mode and stats.health < previous_health:
		stats.health = previous_health
	if not is_dead and stats.health <= 0.0:
		_die("hunger")


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_change_camera_zoom(CAMERA_ZOOM_STEP)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_change_camera_zoom(-CAMERA_ZOOM_STEP)
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_interact()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				_melee_attack()
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


func receive_damage(amount: float, source: String = "unknown") -> bool:
	if is_dead:
		return false
	if god_mode:
		if source == "debug damage":
			_post_event_message("God mode blocked damage")
		return false
	stats.damage(amount)
	var damage_message := "Took %d damage" % int(round(amount))
	if source == "varnak":
		damage_message = "Took %d damage from Varnak" % int(round(amount))
	_post_event_message(damage_message)
	if stats.health <= 0.0:
		_die(source)
	return true


func get_health() -> float:
	return stats.health


func get_max_health() -> float:
	return PlayerStats.MAX_HEALTH


func activate_torch() -> bool:
	if is_dead:
		return false
	if torch_active and torch_remaining_seconds <= 0.0:
		deactivate_torch("expired")
	if is_torch_active():
		_post_event_message("Torch already active")
		return false
	if not inventory.remove_item("torch", 1):
		_post_event_message("No torch to activate")
		return false
	torch_active = true
	torch_remaining_seconds = GAME_BALANCE.TORCH_DURATION_SECONDS
	_emit_game_event("torch_activated", {"active": torch_active, "remaining_seconds": torch_remaining_seconds})
	_post_event_message("Torch activated")
	queue_redraw()
	return true


func is_torch_active() -> bool:
	return torch_active and torch_remaining_seconds > 0.0


func get_torch_remaining_seconds() -> float:
	return torch_remaining_seconds if is_torch_active() else 0.0


func _get_terrain_speed_multiplier() -> float:
	var world_query: Variant = _get_world_query()
	if world_query != null:
		return float(world_query.get_terrain_speed_multiplier(global_position))
	return 1.0


func _is_in_water() -> bool:
	var world_query: Variant = _get_world_query()
	if world_query != null and world_query.has_method("is_position_in_water"):
		return world_query.is_position_in_water(global_position) == true
	return false


func world_query_is_deep_water(world_position: Vector2) -> bool:
	var world_query: Variant = _get_world_query()
	if world_query != null and world_query.has_method("is_position_in_deep_water"):
		return world_query.is_position_in_deep_water(world_position) == true
	return false


func _update_campfire_regen_state() -> void:
	var nearest_active_distance := INF
	var regen_active := false
	for campfire_node in _get_campfires():
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


func _refresh_campfire_regen_state(delta: float) -> void:
	campfire_regen_refresh_timer = max(campfire_regen_refresh_timer - delta, 0.0)
	if campfire_regen_refresh_timer > 0.0:
		return
	campfire_regen_refresh_timer = GAME_BALANCE.PLAYER_CAMPFIRE_REGEN_REFRESH_INTERVAL
	_update_campfire_regen_state()


func _get_campfires() -> Array:
	var world := _get_world_node()
	if world and world.has_method("get_cached_group_nodes"):
		return world.get_cached_group_nodes("campfires")
	return get_tree().get_nodes_in_group("campfires")


func _get_world_query():
	if debug_world_query_override != null:
		return debug_world_query_override
	var world := _get_world_node()
	if world == null:
		return null
	var query_service: Variant = world.get("query_service")
	if query_service != null:
		return query_service
	if world.has_method("get_query_service"):
		query_service = world.call("get_query_service")
		if query_service != null:
			return query_service
	return world


func _get_world_node() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var world_candidates: Array[Node] = []
	if tree.current_scene != null:
		world_candidates.append_array(tree.current_scene.find_children("World", "", true, false))
	world_candidates.append_array(tree.root.find_children("World", "", true, false))
	for candidate in world_candidates:
		if not is_instance_valid(candidate):
			continue
		var candidate_query_service: Variant = null
		if candidate.has_method("get_query_service"):
			candidate_query_service = candidate.call("get_query_service")
		else:
			candidate_query_service = candidate.get("query_service")
		if candidate_query_service != null:
			return candidate
	for candidate in world_candidates:
		if is_instance_valid(candidate):
			return candidate
	return null


func _get_event_bus() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("EventBus")


func _post_event_message(message: String) -> void:
	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_method("post_message"):
		event_bus.post_message(message)


func _format_item_label(item_id: String) -> String:
	return str(item_id).replace("_", " ")


func _emit_game_event(event_name: String, payload: Dictionary = {}) -> void:
	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_method("emit_game_event"):
		event_bus.emit_game_event(event_name, payload)


func debug_add_item(item_name: String, amount := 1) -> void:
	if is_dead:
		return
	if item_name == "spear":
		has_spear = true
	elif item_name == "bow":
		debug_add_bow()
		return
	else:
		var remaining := inventory.add_item(item_name, amount)
		var added := amount - remaining
		if added > 0:
			_post_event_message("Debug added %s x%d" % [item_name, added])
		if remaining > 0:
			_post_event_message("Inventory full")
	_emit_game_event("debug_item_added", {"item": item_name, "amount": amount})
	if item_name == "spear":
		_post_event_message("Debug added %s" % item_name)


func debug_add_bow() -> void:
	if is_dead:
		return
	has_bow = true
	_emit_game_event("debug_item_added", {"item": "bow", "amount": 1})
	_post_event_message("Debug gave bow")


func debug_damage_player() -> void:
	if receive_damage(GAME_BALANCE.DEBUG_PLAYER_DAMAGE_AMOUNT, "debug damage"):
		_emit_game_event("debug_player_damaged", {"amount": GAME_BALANCE.DEBUG_PLAYER_DAMAGE_AMOUNT})


func debug_heal_player() -> void:
	if is_dead:
		return
	stats.heal(GAME_BALANCE.DEBUG_PLAYER_HEAL_AMOUNT)
	_emit_game_event("debug_player_healed", {"amount": GAME_BALANCE.DEBUG_PLAYER_HEAL_AMOUNT})
	_post_event_message("Debug healed player")


func debug_reduce_hunger_energy() -> void:
	if is_dead:
		return
	stats.reduce_hunger_energy(GAME_BALANCE.DEBUG_PLAYER_HUNGER_ENERGY_AMOUNT)
	_emit_game_event("debug_player_hunger_energy_reduced", {"amount": GAME_BALANCE.DEBUG_PLAYER_HUNGER_ENERGY_AMOUNT})
	_post_event_message("Debug reduced hunger/energy")


func debug_restore_hunger_energy() -> void:
	if is_dead:
		return
	stats.restore_hunger_energy(GAME_BALANCE.DEBUG_PLAYER_HUNGER_ENERGY_AMOUNT)
	_emit_game_event("debug_player_hunger_energy_restored", {"amount": GAME_BALANCE.DEBUG_PLAYER_HUNGER_ENERGY_AMOUNT})
	_post_event_message("Debug restored hunger/energy")


func set_default_camera_zoom() -> void:
	_apply_default_camera_zoom()


func deactivate_torch(reason := "manual") -> void:
	if is_dead:
		return
	if not torch_active and torch_remaining_seconds <= 0.0:
		return
	torch_active = false
	torch_remaining_seconds = 0.0
	if reason == "expired":
		_emit_game_event("torch_expired", {"active": false, "remaining_seconds": 0.0})
	_emit_game_event("torch_deactivated", {"active": false, "remaining_seconds": 0.0, "reason": reason})
	_post_event_message("Torch burned out" if reason == "expired" else "Torch deactivated")
	queue_redraw()


func clear_inactive_torch_state() -> void:
	if is_dead:
		return
	torch_active = false
	torch_remaining_seconds = 0.0
	queue_redraw()


func set_god_mode(enabled: bool) -> void:
	god_mode = enabled
	if stats and stats.has_method("set_god_mode"):
		stats.set_god_mode(enabled)
	_post_event_message("God mode %s" % ("enabled" if god_mode else "disabled"))


func toggle_god_mode() -> bool:
	set_god_mode(not god_mode)
	return god_mode


func is_god_mode_enabled() -> bool:
	return god_mode


func recover_from_sleep() -> void:
	if is_dead:
		return
	stats.sleep_recover()


func _interact() -> void:
	if is_dead:
		return
	_refresh_nearby_interactables_from_area()
	for node in nearby_interactables.duplicate():
		if is_instance_valid(node) and node.has_method("interact"):
			node.interact(self)
			return
	_post_event_message("Nothing to interact with")


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
		_post_event_message("Too tired to attack")
		return
	attack_visual_time = ATTACK_VISUAL_DURATION
	queue_redraw()
	var damage := 38.0 if has_spear else 18.0
	var target := _get_attack_target()
	if target:
		target.take_damage(damage, "player")
		_post_event_message("Hit %s" % _get_attack_target_label(target))
		return
	_post_event_message("Attack missed")


func _shoot_bow() -> void:
	if is_dead:
		return
	if bow_cooldown > 0.0:
		return
	var stamina_cost := float(GAME_BALANCE.RANGED_COMBAT.get("bow_stamina_cost", 8.0))
	if not stats.spend_stamina(stamina_cost):
		_post_event_message("Too tired to shoot")
		return
	var direction := get_global_mouse_position() - global_position
	if direction.length_squared() <= 0.0:
		direction = _get_aim_vector()
	else:
		direction = direction.normalized()
	var arrow := ARROW_PROJECTILE_SCENE.instantiate() as Node2D
	arrow.global_position = global_position + direction * 24.0
	get_tree().current_scene.add_child(arrow)
	if arrow.has_method("setup"):
		arrow.setup(direction, self, float(GAME_BALANCE.RANGED_COMBAT.get("bow_damage", 28.0)), "player")
	bow_cooldown = float(GAME_BALANCE.RANGED_COMBAT.get("bow_cooldown_seconds", 0.75))
	_emit_game_event("arrow_fired", {
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
	var forward := _get_aim_vector()
	return abs(forward.angle_to(to_target.normalized())) <= ATTACK_ARC * 0.5


func _craft(item_name: String) -> void:
	if is_dead:
		return
	var recipe: Dictionary = recipes.get(item_name, {})
	if recipe.is_empty():
		_post_event_message("Unknown recipe: %s" % item_name)
		return
	if item_name == "bow" and has_bow:
		_post_event_message("Bow already crafted")
		return
	if not _can_afford_recipe(recipe):
		_post_event_message("Missing resources")
		return
	if not _pay_recipe_cost(recipe):
		_post_event_message("Missing resources")
		return
	if item_name == "torch":
		var torch_leftover := inventory.add_item("torch", 1)
		if torch_leftover > 0:
			_refund_recipe_cost(recipe)
			_post_event_message("Inventory full")
			return
		_emit_game_event("player_crafted_torch", {"count": inventory.get_amount("torch")})
		_post_event_message("Crafted torch")
		return
	if item_name == "spear":
		has_spear = true
		_post_event_message("Crafted spear")
		return
	if item_name == "bow":
		has_bow = true
		_emit_game_event("player_crafted_bow", {"has_bow": has_bow})
		_post_event_message("Crafted bow")
		return
	var scene: PackedScene = {
		"campfire": CAMPFIRE_SCENE,
		"trap": TRAP_SCENE,
		"wall": WALL_SCENE,
		"storage_box": STORAGE_BOX_SCENE,
		"tent": TENT_SCENE
	}[item_name]
	var building := scene.instantiate()
	building.global_position = global_position + _get_aim_vector() * 56.0
	get_tree().current_scene.add_child(building)
	var world := get_tree().current_scene.get_node_or_null("World")
	if world and world.has_method("register_building_node"):
		world.register_building_node(building, item_name)
	_emit_game_event("player_crafted_%s" % item_name, {"position": building.global_position})
	_post_event_message("Crafted %s" % _format_item_label(item_name))


func _eat(item_name: String) -> void:
	if is_dead:
		return
	if item_name != "meat":
		return
	if not inventory.has_item("meat", 1):
		_post_event_message("No meat to eat")
		return
	if not inventory.remove_item(item_name, 1):
		_post_event_message("No meat to eat")
		return
	stats.eat_food(GAME_BALANCE.PLAYER_MEAT_NUTRITION)
	_post_event_message("Ate meat")


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


func _ensure_torch_light() -> void:
	if torch_light != null:
		return
	torch_light = PointLight2D.new()
	torch_light.name = "TorchLight"
	torch_light.texture = _get_radial_light_texture()
	torch_light.energy = 1.35
	torch_light.texture_scale = 4.2
	torch_light.color = Color(1.0, 0.76, 0.40)
	torch_light.shadow_enabled = false
	torch_light.enabled = false
	torch_light.visible = false
	add_child(torch_light)
	print("[LIGHTING] Torch light created")


func _update_torch_light(delta: float) -> void:
	_ensure_torch_light()
	var active := is_torch_active()
	torch_light.visible = active
	torch_light.enabled = active
	if not active:
		return
	torch_light.global_position = global_position
	torch_light_flicker_time += delta
	var flicker := 0.92 + sin(torch_light_flicker_time * 9.0) * 0.05 + sin(torch_light_flicker_time * 17.0) * 0.03
	torch_light.energy = 1.35 * flicker * _get_light_visibility_multiplier()


func _get_light_visibility_multiplier() -> float:
	var night_amount := _get_night_amount()
	return lerpf(0.35, 1.0, clampf(night_amount, 0.0, 1.0))


static func _get_radial_light_texture() -> Texture2D:
	if cached_light_texture != null:
		return cached_light_texture
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var radius := float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var p := Vector2(x, y)
			var distance := p.distance_to(center)
			var t := clampf(1.0 - distance / radius, 0.0, 1.0)
			t *= t
			image.set_pixel(x, y, Color(1.0, 0.82, 0.45, t))
	cached_light_texture = ImageTexture.create_from_image(image)
	return cached_light_texture


func _can_afford_recipe(costs: Dictionary) -> bool:
	for item_id in costs.keys():
		var amount := int(costs[item_id])
		if not inventory.has_item(str(item_id), amount):
			return false
	return true


func _pay_recipe_cost(costs: Dictionary) -> bool:
	if not _can_afford_recipe(costs):
		return false
	for item_id in costs.keys():
		var amount := int(costs[item_id])
		if not inventory.remove_item(str(item_id), amount):
			return false
	return true


func _refund_recipe_cost(costs: Dictionary) -> void:
	for item_id in costs.keys():
		var amount := int(costs[item_id])
		if amount > 0:
			inventory.add_item(str(item_id), amount)


func _on_interactable_entered(node: Node) -> void:
	if node.has_method("interact") and not nearby_interactables.has(node):
		nearby_interactables.append(node)


func _on_interactable_exited(node: Node) -> void:
	nearby_interactables.erase(node)


func _refresh_nearby_interactables_from_area() -> void:
	var filtered: Array[Node] = []
	for node in nearby_interactables:
		if is_instance_valid(node):
			filtered.append(node)
	nearby_interactables = filtered
	for body in interaction_area.get_overlapping_bodies():
		if body.has_method("interact") and not nearby_interactables.has(body):
			nearby_interactables.append(body)
	for area in interaction_area.get_overlapping_areas():
		if area.has_method("interact") and not nearby_interactables.has(area):
			nearby_interactables.append(area)


func _load_recipes() -> Dictionary:
	return GAME_BALANCE.CRAFTING_COSTS.duplicate(true)


func _face_mouse() -> void:
	if is_dead:
		return
	var direction := get_global_mouse_position() - global_position
	if direction.length_squared() > 1.0:
		var next_direction := direction.normalized()
		if aim_direction.distance_to(next_direction) > 0.001:
			aim_direction = next_direction
			queue_redraw()


func _draw() -> void:
	_draw_torch_light()
	_draw_attack_visual()
	if is_swimming:
		_draw_swimming_body()
	else:
		_draw_human_body()


func _draw_swimming_body() -> void:
	var layout: Dictionary = _get_player_visual_layout()
	var ripple_phase: float = sin(swim_ripple_time * 8.0) * 0.5 + 0.5
	draw_arc(Vector2.ZERO, 23.0 + ripple_phase * 4.0, deg_to_rad(20.0), deg_to_rad(160.0), 24, Color(0.72, 0.93, 1.0, 0.45), 2.0)
	draw_arc(Vector2.ZERO, 28.0 - ripple_phase * 3.0, deg_to_rad(200.0), deg_to_rad(340.0), 24, Color(0.72, 0.93, 1.0, 0.34), 2.0)
	_draw_player_visual_layout(layout, 0.78, Color(0.18, 0.42, 0.92), Color(0.12, 0.24, 0.36), Color(0.80, 0.90, 1.0), 0.74)


func _draw_human_body() -> void:
	var layout: Dictionary = _get_player_visual_layout()
	_draw_player_visual_layout(layout, 1.0, PLAYER_SHIRT_COLOR, PLAYER_SHIRT_SHADE_COLOR, PLAYER_SKIN_COLOR, 1.0)


func _draw_player_visual_layout(layout: Dictionary, scale_factor: float, shirt_color: Color, shade_color: Color, skin_color: Color, alpha: float) -> void:
	var pose := _get_player_draw_pose()
	var transformed_layout := _transform_player_visual_layout(layout, bool(pose["flip_x"]), float(pose["body_angle"]))
	var shadow_center: Vector2 = Vector2(layout["shadow_center"])
	var shadow_radius: float = float(layout["shadow_radius"]) * scale_factor
	draw_circle(shadow_center, shadow_radius, Color(0.02, 0.03, 0.04, 0.22 * alpha))
	var back_leg: PackedVector2Array = transformed_layout["back_leg"]
	var front_leg: PackedVector2Array = transformed_layout["front_leg"]
	var back_arm: PackedVector2Array = transformed_layout["back_arm"]
	var front_arm: PackedVector2Array = transformed_layout["front_arm"]
	var torso: PackedVector2Array = transformed_layout["torso"]
	var head_center: Vector2 = Vector2(transformed_layout["head_center"])
	var head_radius: float = float(transformed_layout["head_radius"]) * scale_factor
	_draw_scaled_polygon(back_leg, scale_factor, Vector2.ZERO, PLAYER_PANTS_SHADE_COLOR, alpha)
	_draw_scaled_polygon(front_leg, scale_factor, Vector2.ZERO, PLAYER_PANTS_COLOR, alpha)
	_draw_scaled_polygon(back_arm, scale_factor, Vector2.ZERO, shade_color, alpha)
	_draw_scaled_polygon(torso, scale_factor, Vector2.ZERO, shirt_color, alpha)
	_draw_scaled_polygon(front_arm, scale_factor, Vector2.ZERO, shirt_color.lightened(0.10), alpha)
	_draw_scaled_circle(head_center, head_radius, skin_color, alpha)
	_draw_scaled_circle(head_center + Vector2(-1.2, -2.6), head_radius * 0.86, PLAYER_HAIR_COLOR, alpha)
	_draw_scaled_circle(head_center + Vector2(1.4, -0.8), head_radius * 0.10, Color(0.98, 0.95, 0.90), alpha)
	_draw_scaled_circle(head_center + Vector2(2.1, -0.7), head_radius * 0.10, Color(0.98, 0.95, 0.90), alpha)
	_draw_scaled_line(Vector2(transformed_layout["neck_start"]), Vector2(transformed_layout["neck_end"]), shade_color.darkened(0.1), 2.2 * scale_factor, alpha)
	_draw_scaled_line(Vector2(transformed_layout["spine_start"]), Vector2(transformed_layout["spine_end"]), PLAYER_SHIRT_SHADE_COLOR.darkened(0.1), 2.0 * scale_factor, alpha)
	_draw_scaled_line(Vector2(transformed_layout["belt_start"]), Vector2(transformed_layout["belt_end"]), PLAYER_PANTS_SHADE_COLOR.lightened(0.1), 1.5 * scale_factor, alpha)
	_draw_scaled_circle(Vector2(transformed_layout["backpack_center"]), float(transformed_layout["backpack_radius"]) * scale_factor, Color(0.17, 0.14, 0.11), alpha * 0.8)
	if has_spear:
		_draw_scaled_line(Vector2(transformed_layout["spear_hand_start"]), Vector2(transformed_layout["spear_tip"]), Color(0.44, 0.29, 0.17), 2.0 * scale_factor, alpha)
		_draw_scaled_triangle(Vector2(transformed_layout["spear_tip"]), Vector2(transformed_layout["spear_wing_a"]), Vector2(transformed_layout["spear_wing_b"]), Color(0.74, 0.75, 0.78), alpha)


func _draw_scaled_polygon(points: PackedVector2Array, scale_factor: float, offset: Vector2, color: Color, alpha: float) -> void:
	var scaled_points := PackedVector2Array()
	for point in points:
		scaled_points.append(offset + point * scale_factor)
	draw_colored_polygon(scaled_points, Color(color.r, color.g, color.b, color.a * alpha))


func _draw_scaled_circle(center: Vector2, radius: float, color: Color, alpha: float) -> void:
	draw_circle(center, radius, Color(color.r, color.g, color.b, color.a * alpha))


func _draw_scaled_line(start: Vector2, end: Vector2, color: Color, width: float, alpha: float) -> void:
	draw_line(start, end, Color(color.r, color.g, color.b, color.a * alpha), width)


func _draw_scaled_triangle(a: Vector2, b: Vector2, c: Vector2, color: Color, alpha: float) -> void:
	draw_colored_polygon(PackedVector2Array([a, b, c]), Color(color.r, color.g, color.b, color.a * alpha))


func _get_player_visual_layout() -> Dictionary:
	return {
		"shadow_center": Vector2(4.0, 12.0),
		"shadow_radius": 11.0,
		"head_center": Vector2(16.0, -6.0),
		"head_radius": PLAYER_HUMAN_HEAD_RADIUS,
		"torso": PackedVector2Array([
			Vector2(-5.0, -3.0),
			Vector2(6.0, -7.0),
			Vector2(14.0, -3.0),
			Vector2(15.5, 5.0),
			Vector2(9.5, 12.0),
			Vector2(-1.0, 10.5),
			Vector2(-7.0, 3.0)
		]),
		"back_arm": PackedVector2Array([
			Vector2(-4.5, -1.0),
			Vector2(1.0, -2.0),
			Vector2(-2.0, 6.0),
			Vector2(-7.0, 4.0)
		]),
		"front_arm": PackedVector2Array([
			Vector2(9.0, -1.5),
			Vector2(18.0, 0.0),
			Vector2(20.0, 6.0),
			Vector2(13.0, 6.0)
		]),
		"back_leg": PackedVector2Array([
			Vector2(0.0, 10.0),
			Vector2(4.5, 10.2),
			Vector2(1.5, 22.0),
			Vector2(-3.0, 20.0)
		]),
		"front_leg": PackedVector2Array([
			Vector2(6.0, 10.2),
			Vector2(11.0, 11.0),
			Vector2(15.0, 22.0),
			Vector2(10.0, 23.0)
		]),
		"neck_start": Vector2(12.5, -2.5),
		"neck_end": Vector2(13.8, 0.0),
		"spine_start": Vector2(3.0, -1.0),
		"spine_end": Vector2(10.0, 6.0),
		"belt_start": Vector2(0.0, 9.0),
		"belt_end": Vector2(9.0, 9.8),
		"backpack_center": Vector2(-3.0, 2.5),
		"backpack_radius": 3.5,
		"spear_hand_start": Vector2(18.0, 3.5),
		"spear_tip": Vector2(28.0, -5.0),
		"spear_wing_a": Vector2(26.0, -4.2),
		"spear_wing_b": Vector2(29.0, -6.2)
	}


func _transform_player_visual_layout(layout: Dictionary, flip_x: bool, body_angle: float) -> Dictionary:
	return {
		"shadow_center": Vector2(layout["shadow_center"]),
		"shadow_radius": float(layout["shadow_radius"]),
		"head_center": _transform_visual_point(Vector2(layout["head_center"]), flip_x, body_angle),
		"head_radius": float(layout["head_radius"]),
		"torso": _transform_visual_points(PackedVector2Array(layout["torso"]), flip_x, body_angle),
		"back_arm": _transform_visual_points(PackedVector2Array(layout["back_arm"]), flip_x, body_angle),
		"front_arm": _transform_visual_points(PackedVector2Array(layout["front_arm"]), flip_x, body_angle),
		"back_leg": _transform_visual_points(PackedVector2Array(layout["back_leg"]), flip_x, body_angle),
		"front_leg": _transform_visual_points(PackedVector2Array(layout["front_leg"]), flip_x, body_angle),
		"neck_start": _transform_visual_point(Vector2(layout["neck_start"]), flip_x, body_angle),
		"neck_end": _transform_visual_point(Vector2(layout["neck_end"]), flip_x, body_angle),
		"spine_start": _transform_visual_point(Vector2(layout["spine_start"]), flip_x, body_angle),
		"spine_end": _transform_visual_point(Vector2(layout["spine_end"]), flip_x, body_angle),
		"belt_start": _transform_visual_point(Vector2(layout["belt_start"]), flip_x, body_angle),
		"belt_end": _transform_visual_point(Vector2(layout["belt_end"]), flip_x, body_angle),
		"backpack_center": _transform_visual_point(Vector2(layout["backpack_center"]), flip_x, body_angle),
		"backpack_radius": float(layout["backpack_radius"]),
		"spear_hand_start": _transform_visual_point(Vector2(layout["spear_hand_start"]), flip_x, body_angle),
		"spear_tip": _transform_visual_point(Vector2(layout["spear_tip"]), flip_x, body_angle),
		"spear_wing_a": _transform_visual_point(Vector2(layout["spear_wing_a"]), flip_x, body_angle),
		"spear_wing_b": _transform_visual_point(Vector2(layout["spear_wing_b"]), flip_x, body_angle)
	}


func _transform_visual_points(points: PackedVector2Array, flip_x: bool, body_angle: float) -> PackedVector2Array:
	var transformed := PackedVector2Array()
	for point in points:
		transformed.append(_transform_visual_point(point, flip_x, body_angle))
	return transformed


func _transform_visual_point(point: Vector2, flip_x: bool, body_angle: float) -> Vector2:
	var transformed := point - PLAYER_POSE_PIVOT
	if flip_x:
		transformed.x = -transformed.x
	transformed = transformed.rotated(body_angle)
	return PLAYER_POSE_PIVOT + transformed


func _get_aim_vector() -> Vector2:
	if aim_direction.length_squared() <= 0.0001:
		return Vector2.RIGHT
	return aim_direction.normalized()


func _get_player_draw_pose() -> Dictionary:
	var look_direction := _get_aim_vector()
	return {
		"direction": look_direction,
		"flip_x": look_direction.x < 0.0,
		"body_angle": clampf(look_direction.y, -1.0, 1.0) * PLAYER_POSE_MAX_TILT
	}


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
	var aim_angle := _get_aim_vector().angle()
	var start_angle := aim_angle - ATTACK_ARC * 0.5
	var steps := 9
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var angle: float = lerp(start_angle, start_angle + ATTACK_ARC, t)
		points.append(Vector2.RIGHT.rotated(angle) * ATTACK_RANGE)
	draw_colored_polygon(points, Color(1.0, 0.86, 0.30, alpha))
	draw_arc(Vector2.ZERO, ATTACK_RANGE, start_angle, start_angle + ATTACK_ARC, steps, Color(1.0, 0.92, 0.48, alpha + 0.25), 4.0)


func _apply_default_camera_zoom() -> void:
	if player_camera == null:
		return
	player_camera.zoom = DEFAULT_CAMERA_ZOOM


func _change_camera_zoom(delta: float) -> void:
	if player_camera == null:
		return
	var next_zoom := clampf(player_camera.zoom.x + delta, MIN_CAMERA_ZOOM, MAX_CAMERA_ZOOM)
	player_camera.zoom = Vector2(next_zoom, next_zoom)
