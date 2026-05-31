extends CharacterBody2D

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")

@export var walk_speed := 180.0
@export var run_speed := 290.0

const ATTACK_RANGE := 72.0
const ATTACK_ARC := deg_to_rad(82.0)
const ATTACK_VISUAL_DURATION := 0.16

var stats := PlayerStats.new()
var inventory := Inventory.new()
var has_spear := false
var torch_active := false
var torch_remaining_seconds := 0.0
var evolution_director: Node
var nearby_interactables: Array[Node] = []
var recipes := {}
var world_limits := WORLD_CONFIG.get_player_limits()
var attack_visual_time := 0.0

const CAMPFIRE_SCENE := preload("res://scenes/buildings/campfire.tscn")
const TRAP_SCENE := preload("res://scenes/buildings/trap.tscn")
const WALL_SCENE := preload("res://scenes/buildings/wall.tscn")
const STORAGE_BOX_SCENE := preload("res://scenes/buildings/storage_box.tscn")
const TENT_SCENE := preload("res://scenes/buildings/tent.tscn")

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
	_tick_torch(delta)
	_face_mouse()
	if attack_visual_time > 0.0:
		attack_visual_time = max(attack_visual_time - delta, 0.0)
		queue_redraw()
	if is_torch_active():
		queue_redraw()


func _physics_process(delta: float) -> void:
	_face_mouse()
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var wants_run := Input.is_key_pressed(KEY_SHIFT) and stats.can_run() and input_vector.length() > 0.0
	var speed := (run_speed if wants_run else walk_speed) * stats.get_speed_multiplier()
	velocity = input_vector * speed
	move_and_slide()
	global_position.x = clamp(global_position.x, -world_limits.x, world_limits.x)
	global_position.y = clamp(global_position.y, -world_limits.y, world_limits.y)
	stats.tick(delta, wants_run)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_interact()
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				_attack()
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
			KEY_T:
				_activate_torch()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_attack()


func receive_damage(amount: float) -> void:
	stats.damage(amount)
	get_node("/root/EventBus").post_message("Player hit for %s" % int(amount))


func activate_torch() -> bool:
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


func debug_add_item(item_name: String, amount := 1) -> void:
	if item_name == "spear":
		has_spear = true
	else:
		inventory.add_item(item_name, amount)
	get_node("/root/EventBus").emit_game_event("debug_item_added", {"item": item_name, "amount": amount})
	get_node("/root/EventBus").post_message("Debug added %s" % item_name)


func debug_damage_player() -> void:
	receive_damage(GAME_BALANCE.DEBUG_PLAYER_DAMAGE_AMOUNT)
	get_node("/root/EventBus").emit_game_event("debug_player_damaged", {"amount": GAME_BALANCE.DEBUG_PLAYER_DAMAGE_AMOUNT})


func debug_heal_player() -> void:
	stats.heal(GAME_BALANCE.DEBUG_PLAYER_HEAL_AMOUNT)
	get_node("/root/EventBus").emit_game_event("debug_player_healed", {"amount": GAME_BALANCE.DEBUG_PLAYER_HEAL_AMOUNT})
	get_node("/root/EventBus").post_message("Debug healed player")


func debug_reduce_hunger_energy() -> void:
	stats.reduce_hunger_energy(GAME_BALANCE.DEBUG_PLAYER_HUNGER_ENERGY_AMOUNT)
	get_node("/root/EventBus").emit_game_event("debug_player_hunger_energy_reduced", {"amount": GAME_BALANCE.DEBUG_PLAYER_HUNGER_ENERGY_AMOUNT})
	get_node("/root/EventBus").post_message("Debug reduced hunger/energy")


func debug_restore_hunger_energy() -> void:
	stats.restore_hunger_energy(GAME_BALANCE.DEBUG_PLAYER_HUNGER_ENERGY_AMOUNT)
	get_node("/root/EventBus").emit_game_event("debug_player_hunger_energy_restored", {"amount": GAME_BALANCE.DEBUG_PLAYER_HUNGER_ENERGY_AMOUNT})
	get_node("/root/EventBus").post_message("Debug restored hunger/energy")


func deactivate_torch(reason := "manual") -> void:
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
	torch_active = false
	torch_remaining_seconds = 0.0
	queue_redraw()


func recover_from_sleep() -> void:
	stats.sleep_recover()


func _interact() -> void:
	for node in nearby_interactables.duplicate():
		if is_instance_valid(node) and node.has_method("interact"):
			node.interact(self)
			return
	get_node("/root/EventBus").post_message("Nothing to interact with")


func get_interaction_prompt() -> String:
	for node in nearby_interactables:
		if is_instance_valid(node) and node.has_method("get_prompt"):
			return node.get_prompt()
		if is_instance_valid(node) and node.has_method("interact"):
			return "E: interact"
	return ""


func _attack() -> void:
	if not stats.spend_stamina(12.0):
		get_node("/root/EventBus").post_message("Too tired to attack")
		return
	attack_visual_time = ATTACK_VISUAL_DURATION
	queue_redraw()
	var damage := 38.0 if has_spear else 18.0
	var target := _get_attack_target()
	if target:
		target.take_damage(damage, "player")
		get_node("/root/EventBus").post_message("Hit Varnak")
		return
	get_node("/root/EventBus").post_message("Attack missed")


func _get_attack_target() -> Node:
	var best_target: Node
	var best_distance := INF
	for body in attack_area.get_overlapping_bodies():
		if not body.is_in_group("varnak") or not body.has_method("take_damage"):
			continue
		if not _is_in_attack_arc(body.global_position):
			continue
		var distance := global_position.distance_to(body.global_position)
		if distance < best_distance:
			best_distance = distance
			best_target = body
	return best_target


func _is_in_attack_arc(target_position: Vector2) -> bool:
	var to_target := target_position - global_position
	var distance := to_target.length()
	if distance <= 0.0 or distance > ATTACK_RANGE:
		return false
	var forward := Vector2.RIGHT.rotated(rotation)
	return abs(forward.angle_to(to_target.normalized())) <= ATTACK_ARC * 0.5


func _craft(item_name: String) -> void:
	var recipe: Dictionary = recipes.get(item_name, {})
	if recipe.is_empty():
		get_node("/root/EventBus").post_message("Unknown recipe: %s" % item_name)
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
	if item_name != "meat":
		return
	if not inventory.remove_item(item_name, 1):
		get_node("/root/EventBus").post_message("No meat to eat")
		return
	stats.eat_food(GAME_BALANCE.PLAYER_MEAT_NUTRITION)
	get_node("/root/EventBus").post_message("Ate meat")


func _activate_torch() -> void:
	if is_torch_active():
		deactivate_torch("manual")
		return
	activate_torch()


func _tick_torch(delta: float) -> void:
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
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/recipes.json"))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _face_mouse() -> void:
	var direction := get_global_mouse_position() - global_position
	if direction.length_squared() > 1.0:
		rotation = direction.angle()


func _draw() -> void:
	_draw_torch_light()
	_draw_attack_visual()
	draw_circle(Vector2.ZERO, 14.0, Color(0.2, 0.48, 1.0))
	draw_line(Vector2.ZERO, Vector2(18, 0), Color.WHITE, 3.0)


func _draw_torch_light() -> void:
	if not is_torch_active():
		return
	var night_amount := _get_night_amount()
	var flicker := 0.9 + sin(Time.get_ticks_msec() * 0.018) * 0.08 + sin(Time.get_ticks_msec() * 0.031) * 0.02
	var strength := (0.22 + night_amount * 0.58) * GAME_BALANCE.TORCH_LIGHT_INTENSITY * flicker
	var radius := GAME_BALANCE.TORCH_LIGHT_RADIUS
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.48, 0.08, strength * 0.10))
	draw_circle(Vector2.ZERO, radius * 0.58, Color(1.0, 0.62, 0.12, strength * 0.16))
	draw_circle(Vector2(18, 0), radius * 0.24, Color(1.0, 0.86, 0.28, strength * 0.24))


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
