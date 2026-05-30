extends CharacterBody2D

@export var walk_speed := 180.0
@export var run_speed := 290.0

var stats := PlayerStats.new()
var inventory := Inventory.new()
var has_spear := false
var evolution_director: Node
var nearby_interactables: Array[Node] = []
var recipes := {}

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


func _physics_process(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var wants_run := Input.is_key_pressed(KEY_SHIFT) and stats.stamina > 0.0 and input_vector.length() > 0.0
	var speed := run_speed if wants_run else walk_speed
	velocity = input_vector * speed
	move_and_slide()
	global_position.x = clamp(global_position.x, -690.0, 690.0)
	global_position.y = clamp(global_position.y, -410.0, 410.0)
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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_attack()


func receive_damage(amount: float) -> void:
	stats.damage(amount)
	get_node("/root/EventBus").post_message("Player hit for %s" % int(amount))


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
	var damage := 38.0 if has_spear else 18.0
	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("varnak") and body.has_method("take_damage"):
			body.take_damage(damage, "player")
			get_node("/root/EventBus").post_message("Hit Varnak")
			return
	get_node("/root/EventBus").post_message("Attack missed")


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


func _draw() -> void:
	draw_circle(Vector2.ZERO, 14.0, Color(0.2, 0.48, 1.0))
	draw_line(Vector2.ZERO, Vector2(18, 0), Color.WHITE, 3.0)
