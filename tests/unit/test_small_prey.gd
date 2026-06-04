extends RefCounted

const SMALL_PREY_SCENE := preload("res://scenes/creatures/small_prey.tscn")
const RESOURCE_NODE_SCENE := preload("res://scenes/world/resource_node.tscn")
const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")

class TestWorld:
	extends Node2D

	var terrain_multiplier := 1.0
	var water := false
	var navigation_blocked := false
	var deep_water := false
	var spawned_meat_amount := 0
	var cached_groups := {}

	func get_terrain_speed_multiplier(_position: Vector2) -> float:
		return terrain_multiplier

	func is_position_in_water(_position: Vector2) -> bool:
		return water

	func is_position_in_deep_water(_position: Vector2) -> bool:
		return deep_water

	func is_creature_navigation_blocked(_position: Vector2) -> bool:
		return navigation_blocked

	func spawn_meat_drop_for_animal(_animal_kind: String, _drop_position: Vector2) -> Node:
		spawned_meat_amount += 1
		return Node2D.new()

	func get_cached_group_nodes(group_name: String) -> Array:
		var nodes: Array = cached_groups.get(group_name, [])
		return nodes.duplicate()

	func register_cached_group_node(group_name: String, node: Node) -> void:
		if not cached_groups.has(group_name):
			cached_groups[group_name] = []
		var nodes: Array = cached_groups[group_name]
		if not nodes.has(node):
			nodes.append(node)


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_small_prey_initializes_with_valid_health(failures)
	_test_small_prey_initializes_inside_world(failures)
	_test_small_prey_has_valid_movement_speed(failures)
	_test_small_prey_has_hunger_component(failures)
	_test_small_prey_has_diet(failures)
	_test_small_prey_can_wander(failures)
	_test_small_prey_does_not_leave_world_bounds(failures)
	_test_small_prey_searches_food_when_hungry(failures)
	_test_small_prey_ignores_food_when_not_hungry(failures)
	_test_small_prey_moves_toward_food(failures)
	_test_small_prey_eats_valid_food(failures)
	_test_small_prey_does_not_eat_invalid_food(failures)
	_test_small_prey_hunger_restored_after_eating(failures)
	_test_small_prey_takes_damage_and_flees(failures)
	_test_small_prey_dies_and_drops_meat(failures)
	return failures


func _test_small_prey_initializes_with_valid_health(failures: Array[String]) -> void:
	var prey := _make_small_prey()
	prey.call("_load_species_data")
	TEST_UTILS.expect(prey.max_health > 0.0, failures, "Small prey should load a positive max health")
	TEST_UTILS.expect_close(prey.health, prey.max_health, failures, "Small prey should start at full health after species load")
	prey.queue_free()


func _test_small_prey_initializes_inside_world(failures: Array[String]) -> void:
	var prey := _make_small_prey()
	TEST_UTILS.expect(WORLD_CONFIG.WORLD_RECT.has_point(prey.global_position), failures, "Small prey should start inside the world")
	prey.queue_free()


func _test_small_prey_has_valid_movement_speed(failures: Array[String]) -> void:
	var prey := _make_small_prey()
	prey.call("_load_species_data")
	TEST_UTILS.expect(prey.speed > 0.0, failures, "Small prey speed should be positive")
	prey.queue_free()


func _test_small_prey_has_hunger_component(failures: Array[String]) -> void:
	var prey := _make_small_prey()
	TEST_UTILS.expect(prey.hunger_diet != null, failures, "Small prey should have a hunger component")
	TEST_UTILS.expect(prey.hunger_diet.max_hunger > 0.0, failures, "Hunger component should be initialized")
	prey.queue_free()


func _test_small_prey_has_diet(failures: Array[String]) -> void:
	var prey := _make_small_prey()
	prey.call("_load_species_data")
	TEST_UTILS.expect_close(prey.plant_diet, 1.0, failures, "Small prey should have a plant-only diet")
	TEST_UTILS.expect_close(prey.meat_diet, 0.0, failures, "Small prey should not prefer meat")
	prey.queue_free()


func _test_small_prey_can_wander(failures: Array[String]) -> void:
	var prey := _make_small_prey()
	prey.call("_load_species_data")
	var world := _ensure_world()
	world.navigation_blocked = false
	prey.global_position = Vector2.ZERO
	prey.call("_pick_wander_target")
	TEST_UTILS.expect(prey.wander_target != Vector2.ZERO, failures, "Small prey should pick a wander target")
	prey.queue_free()


func _test_small_prey_does_not_leave_world_bounds(failures: Array[String]) -> void:
	var prey := _make_small_prey()
	prey.global_position = Vector2(WORLD_CONFIG.WORLD_RECT.end.x + 500.0, WORLD_CONFIG.WORLD_RECT.end.y + 500.0)
	prey.call("_enforce_world_bounds")
	var clamped_world := WORLD_CONFIG.WORLD_RECT.grow(-prey.world_edge_padding)
	TEST_UTILS.expect(prey.global_position.x >= clamped_world.position.x and prey.global_position.x <= clamped_world.end.x, failures, "Small prey should stay within the clamped world width")
	TEST_UTILS.expect(prey.global_position.y >= clamped_world.position.y and prey.global_position.y <= clamped_world.end.y, failures, "Small prey should stay within the clamped world height")
	prey.queue_free()


func _test_small_prey_searches_food_when_hungry(failures: Array[String]) -> void:
	var prey := _make_small_prey()
	var world := _ensure_world()
	var resource := _spawn_grass(world, Vector2(120.0, 0.0))
	prey.call("_load_species_data")
	prey.hunger_diet.hunger = 0.90
	prey.call("_sync_hunger_fields")
	_neutralize_threats(prey)
	prey.global_position = Vector2.ZERO
	prey.call("_update_state")
	TEST_UTILS.expect_equal(prey.state, prey.State.SEEK_FOOD, failures, "Hungry small prey should seek food")
	TEST_UTILS.expect(is_instance_valid(prey.plant_target), failures, "Hungry small prey should lock a plant target")
	resource.queue_free()
	prey.queue_free()


func _test_small_prey_ignores_food_when_not_hungry(failures: Array[String]) -> void:
	var prey := _make_small_prey()
	var world := _ensure_world()
	var resource := _spawn_grass(world, Vector2(120.0, 0.0))
	prey.call("_load_species_data")
	prey.hunger_diet.hunger = 0.0
	prey.call("_sync_hunger_fields")
	_neutralize_threats(prey)
	prey.global_position = Vector2.ZERO
	prey.call("_update_state")
	TEST_UTILS.expect(prey.state != prey.State.SEEK_FOOD, failures, "Comfortable small prey should not switch to seeking food")
	TEST_UTILS.expect(not is_instance_valid(prey.plant_target), failures, "Comfortable small prey should not lock a plant target")
	resource.queue_free()
	prey.queue_free()


func _test_small_prey_moves_toward_food(failures: Array[String]) -> void:
	var prey := _make_small_prey()
	_ensure_world()
	var resource := _spawn_grass(Engine.get_main_loop().current_scene.get_node("World"), Vector2(140.0, 0.0))
	prey.call("_load_species_data")
	prey.global_position = Vector2.ZERO
	prey.plant_target = resource
	prey.state = prey.State.SEEK_FOOD
	prey.call("_act", 0.0)
	TEST_UTILS.expect(prey.velocity.length() > 0.0, failures, "Small prey should move toward food when seeking")
	resource.queue_free()
	prey.queue_free()


func _test_small_prey_eats_valid_food(failures: Array[String]) -> void:
	var prey := _make_small_prey()
	var world := _ensure_world()
	var resource := _spawn_grass(world, Vector2(8.0, 0.0))
	prey.call("_load_species_data")
	prey.global_position = Vector2.ZERO
	prey.hunger_diet.hunger = 0.20
	prey.call("_sync_hunger_fields")
	_neutralize_threats(prey)
	prey.plant_target = resource
	var before_hunger: float = prey.hunger_diet.hunger
	prey.call("_consume_plants")
	TEST_UTILS.expect(prey.hunger_diet.hunger < before_hunger, failures, "Eating plants should reduce small prey hunger")
	TEST_UTILS.expect_equal(prey.last_food_source, "plants", failures, "Plant eating should record the food source")
	TEST_UTILS.expect(prey.eat_cooldown > 0.0, failures, "Eating should start a cooldown")
	resource.queue_free()
	prey.queue_free()


func _test_small_prey_does_not_eat_invalid_food(failures: Array[String]) -> void:
	var prey := _make_small_prey()
	prey.call("_load_species_data")
	var rock := Node2D.new()
	rock.set("is_edible_by_herbivores", false)
	prey.plant_target = rock
	TEST_UTILS.expect(prey.call("_is_edible_vegetation_target", rock) != true, failures, "Small prey should not treat non-edible targets as food")
	TEST_UTILS.expect_equal(prey.last_food_source, "none", failures, "Invalid food targets should not change the food source")
	prey.queue_free()


func _test_small_prey_hunger_restored_after_eating(failures: Array[String]) -> void:
	var prey := _make_small_prey()
	var world := _ensure_world()
	var resource := _spawn_grass(world, Vector2(8.0, 0.0))
	prey.call("_load_species_data")
	prey.global_position = Vector2.ZERO
	prey.hunger_diet.hunger = 0.10
	prey.call("_sync_hunger_fields")
	_neutralize_threats(prey)
	prey.plant_target = resource
	prey.call("_consume_plants")
	TEST_UTILS.expect(prey.hunger_diet.hunger < 0.10, failures, "Eating should reduce hunger")
	resource.queue_free()
	prey.queue_free()


func _test_small_prey_takes_damage_and_flees(failures: Array[String]) -> void:
	var prey := _make_small_prey()
	var before_health: float = prey.health
	prey.take_damage(5.0, "player")
	TEST_UTILS.expect(prey.health < before_health, failures, "Damage should reduce small prey health")
	TEST_UTILS.expect_equal(prey.state, prey.State.FLEE, failures, "Surviving damage should make small prey flee")
	prey.queue_free()


func _test_small_prey_dies_and_drops_meat(failures: Array[String]) -> void:
	var prey := _make_small_prey()
	var world := _ensure_world()
	world.spawned_meat_amount = 0
	prey.take_damage(999.0, "player")
	TEST_UTILS.expect_equal(prey.state, prey.State.DEAD, failures, "Fatal damage should mark small prey as dead")
	TEST_UTILS.expect(world.spawned_meat_amount > 0, failures, "Dead small prey should spawn meat")
	prey.queue_free()


func _make_small_prey() -> Node:
	var prey := SMALL_PREY_SCENE.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.current_scene.add_child(prey)
	return prey


func _ensure_world() -> TestWorld:
	var tree := Engine.get_main_loop() as SceneTree
	var current_scene: Node = tree.current_scene
	var existing_world: Node = current_scene.get_node_or_null("World")
	if existing_world and not (existing_world is TestWorld):
		existing_world.name = "LiveWorld"
	var world: TestWorld = current_scene.get_node_or_null("World") as TestWorld
	if world:
		world.cached_groups.clear()
		world.spawned_meat_amount = 0
		return world
	var new_world := TestWorld.new()
	new_world.name = "World"
	current_scene.add_child(new_world)
	return new_world


func _spawn_grass(world: TestWorld, position: Vector2) -> Node:
	var resource := RESOURCE_NODE_SCENE.instantiate()
	world.add_child(resource)
	resource.position = position
	resource.call("setup", "grass_patch")
	world.register_cached_group_node("edible_vegetation", resource)
	return resource


func _neutralize_threats(prey: Node) -> void:
	prey.player = Node2D.new()
	prey.player.global_position = Vector2(100000.0, 100000.0)
