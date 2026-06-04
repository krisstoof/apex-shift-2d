extends RefCounted

const GRAZER_SCENE := preload("res://scenes/creatures/grazer.tscn")
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
	_test_grazer_initializes_with_valid_health(failures)
	_test_grazer_initializes_inside_world(failures)
	_test_grazer_has_hunger_component(failures)
	_test_grazer_has_herbivore_diet(failures)
	_test_grazer_has_valid_speed(failures)
	_test_grazer_can_wander(failures)
	_test_grazer_does_not_leave_world_bounds(failures)
	_test_grazer_searches_plants_when_hungry(failures)
	_test_grazer_moves_toward_nearest_food(failures)
	_test_grazer_eats_plant_resource(failures)
	_test_grazer_does_not_eat_meat_when_plants_exist(failures)
	_test_grazer_hunger_restored_after_eating(failures)
	_test_grazer_returns_to_wandering_after_eating(failures)
	_test_grazer_takes_damage(failures)
	_test_grazer_dies_at_zero_health(failures)
	_test_grazer_drops_meat_on_death(failures)
	_test_grazer_removed_from_ecosystem_after_death(failures)
	return failures


func _test_grazer_initializes_with_valid_health(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	grazer.call("_load_species_data")
	TEST_UTILS.expect(grazer.max_health > 0.0, failures, "Grazer should load a positive max health")
	TEST_UTILS.expect_close(grazer.health, grazer.max_health, failures, "Grazer should start at full health after species load")
	grazer.queue_free()


func _test_grazer_initializes_inside_world(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	TEST_UTILS.expect(WORLD_CONFIG.WORLD_RECT.has_point(grazer.global_position), failures, "Grazer should start inside the world")
	grazer.queue_free()


func _test_grazer_has_hunger_component(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	TEST_UTILS.expect(grazer.hunger_diet != null, failures, "Grazer should have a hunger component")
	TEST_UTILS.expect(grazer.hunger_diet.max_hunger > 0.0, failures, "Grazer hunger component should be initialized")
	grazer.queue_free()


func _test_grazer_has_herbivore_diet(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	grazer.call("_load_species_data")
	TEST_UTILS.expect(grazer.plant_diet > grazer.meat_diet, failures, "Grazer should prefer plants over meat")
	TEST_UTILS.expect(grazer.plant_diet > grazer.scavenger_diet, failures, "Grazer should prefer plants over scavenging")
	grazer.queue_free()


func _test_grazer_has_valid_speed(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	grazer.call("_load_species_data")
	TEST_UTILS.expect(grazer.speed > 0.0, failures, "Grazer speed should be positive")
	grazer.queue_free()


func _test_grazer_can_wander(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	grazer.call("_load_species_data")
	var world := _ensure_world()
	world.navigation_blocked = false
	grazer.global_position = Vector2.ZERO
	grazer.call("_pick_wander_target")
	TEST_UTILS.expect(grazer.wander_target != Vector2.ZERO, failures, "Grazer should pick a wander target")
	grazer.queue_free()


func _test_grazer_does_not_leave_world_bounds(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	grazer.global_position = Vector2(WORLD_CONFIG.WORLD_RECT.end.x + 400.0, WORLD_CONFIG.WORLD_RECT.end.y + 400.0)
	grazer.call("_enforce_world_bounds")
	var clamped_world := WORLD_CONFIG.WORLD_RECT.grow(-grazer.world_edge_padding)
	TEST_UTILS.expect(grazer.global_position.x >= clamped_world.position.x and grazer.global_position.x <= clamped_world.end.x, failures, "Grazer should stay within the clamped world width")
	TEST_UTILS.expect(grazer.global_position.y >= clamped_world.position.y and grazer.global_position.y <= clamped_world.end.y, failures, "Grazer should stay within the clamped world height")
	grazer.queue_free()


func _test_grazer_searches_plants_when_hungry(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	var world := _ensure_world()
	var resource := _spawn_grass(world, Vector2(120.0, 0.0))
	grazer.call("_load_species_data")
	grazer.hunger_diet.hunger = 0.90
	grazer.call("_sync_hunger_fields")
	_neutralize_threats(grazer)
	grazer.global_position = Vector2.ZERO
	grazer.call("_update_state")
	TEST_UTILS.expect_equal(grazer.state, grazer.State.SEEK_FOOD, failures, "Hungry grazer should seek plants")
	TEST_UTILS.expect(is_instance_valid(grazer.plant_target), failures, "Hungry grazer should lock a plant target")
	resource.queue_free()
	grazer.queue_free()


func _test_grazer_moves_toward_nearest_food(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	var world := _ensure_world()
	var resource := _spawn_grass(world, Vector2(140.0, 0.0))
	grazer.call("_load_species_data")
	grazer.global_position = Vector2.ZERO
	grazer.plant_target = resource
	grazer.state = grazer.State.SEEK_FOOD
	grazer.call("_act", 0.0)
	TEST_UTILS.expect(grazer.velocity.length() > 0.0, failures, "Grazer should move toward food when seeking")
	resource.queue_free()
	grazer.queue_free()


func _test_grazer_eats_plant_resource(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	var world := _ensure_world()
	var resource := _spawn_grass(world, Vector2(8.0, 0.0))
	grazer.call("_load_species_data")
	grazer.global_position = Vector2.ZERO
	grazer.hunger_diet.hunger = 0.20
	grazer.call("_sync_hunger_fields")
	_neutralize_threats(grazer)
	grazer.plant_target = resource
	var before_hunger: float = grazer.hunger_diet.hunger
	grazer.call("_consume_plants")
	TEST_UTILS.expect(grazer.hunger_diet.hunger < before_hunger, failures, "Eating plants should reduce grazer hunger")
	TEST_UTILS.expect_equal(grazer.last_food_source, "plants", failures, "Plant eating should record the food source")
	resource.queue_free()
	grazer.queue_free()


func _test_grazer_does_not_eat_meat_when_plants_exist(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	var world := _ensure_world()
	var grass := _spawn_grass(world, Vector2(8.0, 0.0))
	var meat := _spawn_meat_drop(world, Vector2(10.0, 0.0))
	grazer.call("_load_species_data")
	grazer.global_position = Vector2.ZERO
	grazer.hunger_diet.hunger = 0.80
	grazer.call("_sync_hunger_fields")
	_neutralize_threats(grazer)
	grazer.call("_update_state")
	TEST_UTILS.expect_equal(grazer.state, grazer.State.SEEK_FOOD, failures, "Hungry grazer should still prefer plants when plants are available")
	TEST_UTILS.expect(is_instance_valid(grazer.plant_target), failures, "Grazer should lock a plant target when plants are present")
	TEST_UTILS.expect(grazer.meat_target == null, failures, "Grazer should not switch to meat while plants are available")
	grass.queue_free()
	meat.queue_free()
	grazer.queue_free()


func _test_grazer_hunger_restored_after_eating(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	var world := _ensure_world()
	var resource := _spawn_grass(world, Vector2(8.0, 0.0))
	grazer.call("_load_species_data")
	grazer.global_position = Vector2.ZERO
	grazer.hunger_diet.hunger = 0.10
	grazer.call("_sync_hunger_fields")
	_neutralize_threats(grazer)
	grazer.plant_target = resource
	grazer.call("_consume_plants")
	TEST_UTILS.expect(grazer.hunger_diet.hunger < 0.10, failures, "Eating should reduce hunger")
	resource.queue_free()
	grazer.queue_free()


func _test_grazer_returns_to_wandering_after_eating(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	var world := _ensure_world()
	var resource := _spawn_grass(world, Vector2(8.0, 0.0))
	grazer.call("_load_species_data")
	grazer.global_position = Vector2.ZERO
	grazer.hunger_diet.hunger = 0.10
	grazer.call("_sync_hunger_fields")
	_neutralize_threats(grazer)
	grazer.plant_target = resource
	grazer.state = grazer.State.EAT_PLANTS
	grazer.state_time = 0.0
	grazer.call("_update_state")
	TEST_UTILS.expect_equal(grazer.state, grazer.State.WANDER, failures, "Grazer should return to wandering after eating")
	resource.queue_free()
	grazer.queue_free()


func _test_grazer_takes_damage(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	var before_health: float = grazer.health
	grazer.take_damage(5.0, "player")
	TEST_UTILS.expect(grazer.health < before_health, failures, "Damage should reduce grazer health")
	TEST_UTILS.expect_equal(grazer.state, grazer.State.FLEE, failures, "Surviving damage should make grazer flee")
	grazer.queue_free()


func _test_grazer_dies_at_zero_health(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	grazer.take_damage(999.0, "player")
	TEST_UTILS.expect_equal(grazer.state, grazer.State.DEAD, failures, "Fatal damage should mark the grazer as dead")
	grazer.queue_free()


func _test_grazer_drops_meat_on_death(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	var world := _ensure_world()
	world.spawned_meat_amount = 0
	grazer.take_damage(999.0, "player")
	TEST_UTILS.expect(world.spawned_meat_amount > 0, failures, "Dead grazer should spawn meat")
	grazer.queue_free()


func _test_grazer_removed_from_ecosystem_after_death(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	grazer.take_damage(999.0, "player")
	TEST_UTILS.expect(grazer.is_queued_for_deletion(), failures, "Dead grazer should be queued for removal")
	grazer.queue_free()


func _make_grazer() -> Node:
	var grazer := GRAZER_SCENE.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.current_scene.add_child(grazer)
	return grazer


func _ensure_world() -> TestWorld:
	var tree := Engine.get_main_loop() as SceneTree
	var current_scene: Node = tree.current_scene
	var existing_world: Node = current_scene.get_node_or_null("World")
	if existing_world and not (existing_world is TestWorld):
		existing_world.name = "LiveWorld"
	var world: TestWorld = current_scene.get_node_or_null("World") as TestWorld
	if world:
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


func _spawn_meat_drop(world: TestWorld, position: Vector2) -> Node:
	var resource := RESOURCE_NODE_SCENE.instantiate()
	world.add_child(resource)
	resource.position = position
	resource.call("setup", "meat_drop")
	world.register_cached_group_node("meat_drops", resource)
	return resource


func _neutralize_threats(grazer: Node) -> void:
	grazer.player = Node2D.new()
	grazer.player.global_position = Vector2(100000.0, 100000.0)
