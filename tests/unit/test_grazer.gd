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
	var query_service

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

	func get_query_service():
		return query_service


class TestWorldQueryService:
	extends RefCounted

	var terrain_multiplier := 0.48
	var navigation_blocked := true

	func get_terrain_speed_multiplier(_position: Vector2) -> float:
		return terrain_multiplier

	func is_creature_navigation_blocked(_position: Vector2) -> bool:
		return navigation_blocked


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_grazer_initializes_with_valid_health(failures)
	_test_grazer_initializes_inside_world(failures)
	_test_grazer_has_hunger_component(failures)
	_test_grazer_has_herbivore_diet(failures)
	_test_grazer_has_valid_speed(failures)
	_test_grazer_throttles_ai_decisions(failures)
	_test_grazer_can_wander(failures)
	_test_grazer_does_not_leave_world_bounds(failures)
	_test_grazer_prefers_world_query_service_for_navigation_and_terrain(failures)
	_test_grazer_searches_plants_when_hungry(failures)
	_test_grazer_builds_decision_context(failures)
	_test_grazer_moves_toward_nearest_food(failures)
	_test_grazer_eats_plant_resource(failures)
	_test_grazer_consumes_nearby_plant_over_time(failures)
	_test_grazer_consumes_large_bush_at_edge_distance(failures)
	_test_grazer_does_not_eat_meat_when_plants_exist(failures)
	_test_grazer_can_eat_meat_when_desperate(failures)
	_test_grazer_skips_freed_meat_drop_targets(failures)
	_test_grazer_hunger_restored_after_eating(failures)
	_test_grazer_restore_from_data_handles_null_fields(failures)
	_test_grazer_visibility_culling_sleeps_ai_and_collision(failures)
	_test_grazer_returns_to_wandering_after_eating(failures)
	_test_grazer_takes_damage(failures)
	_test_grazer_dies_at_zero_health(failures)
	_test_grazer_drops_meat_on_death(failures)
	_test_grazer_does_not_duplicate_meat_drop_on_repeated_death(failures)
	_test_grazer_removed_from_ecosystem_after_death(failures)
	return failures


func _test_grazer_throttles_ai_decisions(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	grazer.ai_decision_timer = 0.10
	TEST_UTILS.expect(not grazer.call("_should_update_ai_decision", 0.05), failures, "Grazer should skip decisions before its AI interval elapses")
	TEST_UTILS.expect(grazer.call("_should_update_ai_decision", 0.06), failures, "Grazer should run a decision after its AI interval elapses")
	TEST_UTILS.expect(not grazer.call("_should_update_ai_decision", 0.01), failures, "Grazer should reset its decision interval after an update")
	grazer.queue_free()


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


func _test_grazer_prefers_world_query_service_for_navigation_and_terrain(failures: Array[String]) -> void:
	var world := _ensure_world()
	world.query_service = TestWorldQueryService.new()
	world.navigation_blocked = false
	world.terrain_multiplier = 1.0
	var grazer := _make_grazer()
	grazer.global_position = Vector2.ZERO
	TEST_UTILS.expect_close(float(grazer.call("_get_terrain_speed_multiplier")), 0.48, failures, "Grazer should read terrain speed from WorldQueryService when exposed by the world")
	TEST_UTILS.expect(not grazer.call("_is_navigation_position_valid", Vector2(40.0, 0.0)), failures, "Grazer should use WorldQueryService navigation blocking when exposed by the world")
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


func _test_grazer_builds_decision_context(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	grazer.call("_load_species_data")
	grazer.global_position = Vector2(88.0, 40.0)
	grazer.biome_id = "hearth_meadow"
	grazer.home_biome_id = "hearth_meadow"
	grazer.hunger_diet.hunger = 0.78
	grazer.call("_sync_hunger_fields")
	var context = grazer.call("build_decision_context")
	var context_data := context.to_dictionary() if context != null and context.has_method("to_dictionary") else Dictionary(context)
	TEST_UTILS.expect(context != null, failures, "Grazer should expose a decision context helper")
	TEST_UTILS.expect_equal(str(context_data.get("current_biome", "")), "hearth_meadow", failures, "Grazer decision context should include the current biome")
	TEST_UTILS.expect_equal(str(context_data.get("hunger_stage", "")), "starving", failures, "Grazer decision context should include hunger stage")
	TEST_UTILS.expect_equal(str(context_data.get("current_behavior", "")), "wander", failures, "Grazer decision context should expose behavior")
	TEST_UTILS.expect_equal(bool(context_data.get("is_inside_home_biome", false)), true, failures, "Grazer decision context should reflect home biome membership")
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


func _test_grazer_consumes_nearby_plant_over_time(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	var world := _ensure_world()
	var resource := _spawn_grass(world, Vector2(18.0, 0.0))
	grazer.call("_initialize_from_game_balance")
	grazer.call("_load_species_data")
	grazer.global_position = Vector2.ZERO
	grazer.hunger_diet.hunger = 0.90
	grazer.call("_sync_hunger_fields")
	_neutralize_threats(grazer)
	var hunger_before: float = grazer.hunger_diet.hunger
	var ate_plant := false
	for _i in range(120):
		grazer.call("_physics_process", 0.1)
		if grazer.last_food_source == "plants":
			ate_plant = true
			break
	var target_distance := -1.0
	if is_instance_valid(grazer.plant_target):
		target_distance = grazer.global_position.distance_to(grazer.plant_target.global_position)
	var debug_state := "%s | reason=%s | target=%s | hunger=%.3f | state_time=%.3f | last=%s" % [
		str(grazer.state),
		grazer.decision_reason,
		grazer._get_current_target_label() if grazer.has_method("_get_current_target_label") else "unknown",
		grazer.hunger_diet.hunger,
		grazer.state_time,
		grazer.last_food_source
	]
	var distance_debug := "distance=%.3f | %s" % [target_distance, debug_state]
	TEST_UTILS.expect(ate_plant, failures, "Grazer should eventually eat a nearby plant during the normal physics loop (%s)" % distance_debug)
	TEST_UTILS.expect(grazer.hunger_diet.hunger < hunger_before, failures, "Grazer hunger should decrease after the normal plant-eating loop (%s)" % distance_debug)
	TEST_UTILS.expect(float(resource.get("growth_stage")) < float(resource.get("max_growth_stage")), failures, "Grazer should partially consume the plant resource during the normal loop (%s)" % distance_debug)
	resource.queue_free()
	grazer.queue_free()


func _test_grazer_consumes_large_bush_at_edge_distance(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	var world := _ensure_world()
	var resource := _spawn_bush(world, Vector2(50.0, 0.0))
	grazer.call("_initialize_from_game_balance")
	grazer.call("_load_species_data")
	grazer.global_position = Vector2.ZERO
	grazer.hunger_diet.hunger = 0.88
	grazer.call("_sync_hunger_fields")
	_neutralize_threats(grazer)
	grazer.plant_target = resource
	grazer.state = grazer.State.SEEK_FOOD
	grazer.call("_try_update_plant_target")
	TEST_UTILS.expect_equal(grazer.state, grazer.State.EAT_PLANTS, failures, "Grazer should start eating when it reaches the edge of a large bush, not only its center")
	var before_hunger: float = grazer.hunger_diet.hunger
	grazer.call("_consume_plants")
	TEST_UTILS.expect(grazer.hunger_diet.hunger < before_hunger, failures, "Eating a large bush from edge distance should still reduce hunger")
	TEST_UTILS.expect_equal(grazer.last_food_source, "plants", failures, "Large bush edge consumption should still register as plant eating")
	resource.queue_free()
	grazer.queue_free()


func _test_grazer_does_not_eat_meat_when_plants_exist(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	var world := _ensure_world()
	var grass := _spawn_grass(world, Vector2(8.0, 0.0))
	var meat := _spawn_meat_drop(world, Vector2(10.0, 0.0))
	grazer.call("_initialize_from_game_balance")
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


func _test_grazer_skips_freed_meat_drop_targets(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	var world := _ensure_world()
	var live_meat := _spawn_meat_drop(world, Vector2(160.0, 0.0))
	var stale_meat := _spawn_meat_drop(world, Vector2(24.0, 0.0))
	stale_meat.free()
	var found: Node2D = grazer.call("_find_nearest_meat_drop", 500.0) as Node2D
	TEST_UTILS.expect_equal(found, live_meat, failures, "Grazer should ignore freed meat drops and pick the live target")
	grazer.queue_free()


func _test_grazer_can_eat_meat_when_desperate(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	var world := _ensure_world()
	var meat := _spawn_meat_drop(world, Vector2(8.0, 0.0))
	grazer.call("_initialize_from_game_balance")
	grazer.call("_load_species_data")
	grazer.global_position = Vector2.ZERO
	grazer.hunger_diet.hunger = min(grazer.hunger_diet.desperate_threshold + 0.02, 0.99)
	grazer.call("_sync_hunger_fields")
	_neutralize_threats(grazer)
	grazer.call("_update_state")
	TEST_UTILS.expect_equal(grazer.state, grazer.State.SCAVENGE, failures, "Desperate grazer should switch to scavenging meat")
	TEST_UTILS.expect_equal(grazer.decision_reason, "starving_scavenge", failures, "Desperate grazer should choose scavenging because it is starving and no plants are available")
	TEST_UTILS.expect(is_instance_valid(grazer.meat_target), failures, "Desperate grazer should lock a meat target")
	TEST_UTILS.expect_equal(grazer.meat_target, meat, failures, "Desperate grazer should choose the spawned meat drop")
	var before_hunger: float = grazer.hunger_diet.hunger
	grazer.global_position = meat.global_position
	grazer.call("_consume_meat_target")
	TEST_UTILS.expect(grazer.hunger_diet.hunger < before_hunger, failures, "Eating meat should reduce grazer hunger")
	TEST_UTILS.expect_equal(grazer.last_food_source, "meat_drop", failures, "Meat eating should be recorded as the last food source")
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


func _test_grazer_restore_from_data_handles_null_fields(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	var before_health: float = grazer.health
	grazer.restore_from_data({
		"facing_angle": null,
		"health": null,
		"speed": null,
		"dropped_meat": null
	})
	TEST_UTILS.expect_close(grazer.health, before_health, failures, "Grazer restore should ignore null health values")
	TEST_UTILS.expect(grazer.facing_angle == grazer.facing_angle, failures, "Grazer restore should not produce an invalid facing angle")
	grazer.queue_free()


func _test_grazer_visibility_culling_sleeps_ai_and_collision(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	grazer.player = Node2D.new()
	grazer.player.global_position = Vector2(100000.0, 100000.0)
	var original_layer: int = grazer.collision_layer
	var original_mask: int = grazer.collision_mask
	var before_position: Vector2 = grazer.global_position
	var before_ai_decisions: int = grazer.ai_decision_count
	TEST_UTILS.expect(grazer.has_method("set_visibility_culled"), failures, "Grazer should expose visibility culling")
	grazer.call("set_visibility_culled", false)
	TEST_UTILS.expect_equal(grazer.visible, false, failures, "Culled grazers should be hidden")
	TEST_UTILS.expect_equal(bool(grazer.get("is_visibility_culled")), true, failures, "Culled grazers should remember they are sleeping")
	TEST_UTILS.expect_equal(grazer.collision_layer, 0, failures, "Culled grazers should disable their collision layer")
	TEST_UTILS.expect_equal(grazer.collision_mask, 0, failures, "Culled grazers should disable their collision mask")
	TEST_UTILS.expect_equal(grazer.is_physics_processing(), false, failures, "Culled grazers should stop physics processing")
	TEST_UTILS.expect_equal(grazer.is_processing(), false, failures, "Culled grazers should stop frame processing")
	grazer.call("_physics_process", 0.2)
	TEST_UTILS.expect_equal(grazer.ai_decision_count, before_ai_decisions, failures, "Sleeping grazers should not advance AI decisions")
	TEST_UTILS.expect_equal(grazer.global_position, before_position, failures, "Sleeping grazers should not move")
	grazer.call("set_visibility_culled", true)
	TEST_UTILS.expect_equal(grazer.visible, true, failures, "Reactivated grazers should be visible")
	TEST_UTILS.expect_equal(bool(grazer.get("is_visibility_culled")), false, failures, "Reactivated grazers should clear the sleeping flag")
	TEST_UTILS.expect_equal(grazer.collision_layer, original_layer, failures, "Reactivated grazers should restore their collision layer")
	TEST_UTILS.expect_equal(grazer.collision_mask, original_mask, failures, "Reactivated grazers should restore their collision mask")
	TEST_UTILS.expect_equal(grazer.is_physics_processing(), true, failures, "Reactivated grazers should resume physics")
	TEST_UTILS.expect_equal(grazer.is_processing(), true, failures, "Reactivated grazers should resume frame processing")
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
	TEST_UTILS.expect_close(grazer.state_time, 4.0, failures, "Grazer should keep fleeing for the configured duration")
	_neutralize_threats(grazer)
	grazer.state_time = 1.0
	grazer.call("_update_state")
	TEST_UTILS.expect_equal(grazer.state, grazer.State.FLEE, failures, "Grazer should continue fleeing briefly after losing the threat")
	TEST_UTILS.expect_equal(grazer.decision_reason, "threat_lost_keep_fleeing", failures, "Grazer should explain that it remembers the lost threat")
	grazer.state_time = 0.0
	grazer.call("_update_state")
	TEST_UTILS.expect_equal(grazer.state, grazer.State.WANDER, failures, "Grazer should return to wandering after the flee timer expires")
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


func _test_grazer_does_not_duplicate_meat_drop_on_repeated_death(failures: Array[String]) -> void:
	var grazer := _make_grazer()
	var world := _ensure_world()
	world.spawned_meat_amount = 0
	grazer.take_damage(999.0, "player")
	grazer.take_damage(999.0, "player")
	TEST_UTILS.expect_equal(world.spawned_meat_amount, 1, failures, "Grazer death should drop meat only once")
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
	resource.global_position = position
	resource.call("setup", "grass_patch")
	world.register_cached_group_node("edible_vegetation", resource)
	return resource


func _spawn_bush(world: TestWorld, position: Vector2) -> Node:
	var resource := RESOURCE_NODE_SCENE.instantiate()
	world.add_child(resource)
	resource.global_position = position
	resource.call("setup", "bush")
	world.register_cached_group_node("edible_vegetation", resource)
	return resource


func _spawn_meat_drop(world: TestWorld, position: Vector2) -> Node:
	var resource := RESOURCE_NODE_SCENE.instantiate()
	world.add_child(resource)
	resource.global_position = position
	resource.call("setup", "meat_drop")
	world.register_cached_group_node("meat_drops", resource)
	return resource


func _neutralize_threats(grazer: Node) -> void:
	grazer.player = Node2D.new()
	grazer.player.global_position = Vector2(100000.0, 100000.0)
