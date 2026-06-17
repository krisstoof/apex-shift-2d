extends RefCounted
class_name TestCreatureBuildingQueries

const INTEGRATION_TEST_UTILS := preload("res://tests/integration/integration_test_utils.gd")

var expect: Callable
var expect_equal: Callable
var expect_close: Callable


func _init() -> void:
	expect = INTEGRATION_TEST_UTILS.expect
	expect_equal = INTEGRATION_TEST_UTILS.expect_equal
	expect_close = INTEGRATION_TEST_UTILS.expect_close


func run() -> Array:
	var failures: Array[String] = []
	
	if await _test_small_prey_uses_wall_avoidance_with_building_query():
		failures.append("_test_small_prey_uses_wall_avoidance_with_building_query")
	
	if await _test_grazer_uses_wall_avoidance_with_building_query():
		failures.append("_test_grazer_uses_wall_avoidance_with_building_query")
	
	if await _test_varnak_uses_trap_avoidance_with_building_query():
		failures.append("_test_varnak_uses_trap_avoidance_with_building_query")
	
	if await _test_varnak_uses_campfire_fear_with_building_query():
		failures.append("_test_varnak_uses_campfire_fear_with_building_query")
	
	if await _test_creature_building_query_finds_nearby_only():
		failures.append("_test_creature_building_query_finds_nearby_only")
	
	if await _test_building_queries_filter_by_type():
		failures.append("_test_building_queries_filter_by_type")
	
	if await _test_multiple_creatures_can_query_same_buildings():
		failures.append("_test_multiple_creatures_can_query_same_buildings")
	
	if await _test_creature_building_query_with_moved_target():
		failures.append("_test_creature_building_query_with_moved_target")
	
	return failures


func _test_small_prey_uses_wall_avoidance_with_building_query() -> bool:
	var boot_result = INTEGRATION_TEST_UTILS.boot_main()
	if not boot_result.success:
		return true
	
	var world = boot_result.world
	var registry = world.get_registry()
	
	# Spawn SmallPrey
	var prey = INTEGRATION_TEST_UTILS.spawn_creature(world, "small_prey", Vector2(100.0, 100.0))
	await INTEGRATION_TEST_UTILS.wait_frames(2)
	
	# Spawn wall near prey
	var wall = INTEGRATION_TEST_UTILS.spawn_building(world, "wall", Vector2(130.0, 100.0))
	await INTEGRATION_TEST_UTILS.wait_frames(2)
	
	# Check that wall is in registry
	var nearby_walls = registry.get_buildings_near(prey.global_position, 100.0, "wall")
	expect_equal(nearby_walls.size(), 1, "Wall should be nearby prey")
	
	# Test _get_wall_avoidance_vector - this is the AI method that now uses building queries
	var avoidance = prey._get_wall_avoidance_vector()
	expect(avoidance.length_squared() > 0.0, "Wall avoidance should be non-zero when wall is nearby")
	
	INTEGRATION_TEST_UTILS.shutdown()
	return false


func _test_grazer_uses_wall_avoidance_with_building_query() -> bool:
	var boot_result = INTEGRATION_TEST_UTILS.boot_main()
	if not boot_result.success:
		return true
	
	var world = boot_result.world
	var registry = world.get_registry()
	
	# Spawn Grazer
	var grazer = INTEGRATION_TEST_UTILS.spawn_creature(world, "grazer", Vector2(200.0, 200.0))
	await INTEGRATION_TEST_UTILS.wait_frames(2)
	
	# Spawn wall near grazer
	var wall = INTEGRATION_TEST_UTILS.spawn_building(world, "wall", Vector2(230.0, 200.0))
	await INTEGRATION_TEST_UTILS.wait_frames(2)
	
	# Check that wall is in registry
	var nearby_walls = registry.get_buildings_near(grazer.global_position, 100.0, "wall")
	expect_equal(nearby_walls.size(), 1, "Wall should be nearby grazer")
	
	# Test _get_wall_avoidance_vector - this is the AI method that now uses building queries
	var avoidance = grazer._get_wall_avoidance_vector()
	expect(avoidance.length_squared() > 0.0, "Wall avoidance should be non-zero when wall is nearby")
	
	INTEGRATION_TEST_UTILS.shutdown()
	return false


func _test_varnak_uses_trap_avoidance_with_building_query() -> bool:
	var boot_result = INTEGRATION_TEST_UTILS.boot_main()
	if not boot_result.success:
		return true
	
	var world = boot_result.world
	var registry = world.get_registry()
	
	# Spawn Varnak with trap_awareness
	var varnak = INTEGRATION_TEST_UTILS.spawn_creature(world, "varnak", Vector2(300.0, 300.0))
	varnak.trap_awareness = 0.8  # Make it aware of traps
	await INTEGRATION_TEST_UTILS.wait_frames(2)
	
	# Spawn trap near varnak
	var trap = INTEGRATION_TEST_UTILS.spawn_building(world, "trap", Vector2(330.0, 300.0))
	await INTEGRATION_TEST_UTILS.wait_frames(2)
	
	# Check that trap is in registry
	var nearby_traps = registry.get_buildings_near(varnak.global_position, 100.0, "trap")
	expect_equal(nearby_traps.size(), 1, "Trap should be nearby varnak")
	
	# Test _avoid_trap_target - this is the AI method that now uses building queries
	var original_target = Vector2(350.0, 300.0)
	var avoided_target = varnak._avoid_trap_target(original_target)
	expect(avoided_target != original_target, "Trap avoidance should modify target")
	
	INTEGRATION_TEST_UTILS.shutdown()
	return false


func _test_varnak_uses_campfire_fear_with_building_query() -> bool:
	var boot_result = INTEGRATION_TEST_UTILS.boot_main()
	if not boot_result.success:
		return true
	
	var world = boot_result.world
	var registry = world.get_registry()
	
	# Spawn Varnak
	var varnak = INTEGRATION_TEST_UTILS.spawn_creature(world, "varnak", Vector2(400.0, 400.0))
	await INTEGRATION_TEST_UTILS.wait_frames(2)
	
	# Spawn campfire near varnak
	var campfire = INTEGRATION_TEST_UTILS.spawn_building(world, "campfire", Vector2(430.0, 400.0))
	campfire.active = true
	campfire.fear_radius = 100.0
	await INTEGRATION_TEST_UTILS.wait_frames(2)
	
	# Check that campfire is in registry
	var nearby_campfires = registry.get_buildings_near(varnak.global_position, 350.0, "campfire")
	expect_equal(nearby_campfires.size(), 1, "Campfire should be nearby varnak")
	
	# Test _nearest_active_campfire - this is the AI method that now uses building queries
	var nearest_fire = varnak._nearest_active_campfire()
	expect_equal(is_instance_valid(nearest_fire) and nearest_fire == campfire, true, "Should find nearest active campfire")
	
	INTEGRATION_TEST_UTILS.shutdown()
	return false


func _test_creature_building_query_finds_nearby_only() -> bool:
	var boot_result = INTEGRATION_TEST_UTILS.boot_main()
	if not boot_result.success:
		return true
	
	var world = boot_result.world
	var registry = world.get_registry()
	
	var prey = INTEGRATION_TEST_UTILS.spawn_creature(world, "small_prey", Vector2(500.0, 500.0))
	await INTEGRATION_TEST_UTILS.wait_frames(2)
	
	# Spawn multiple walls at different distances
	var close_wall = INTEGRATION_TEST_UTILS.spawn_building(world, "wall", Vector2(520.0, 500.0))  # 20px
	var far_wall = INTEGRATION_TEST_UTILS.spawn_building(world, "wall", Vector2(600.0, 500.0))   # 100px
	await INTEGRATION_TEST_UTILS.wait_frames(2)
	
	# Query nearby walls with 50px radius
	var nearby_walls = registry.get_buildings_near(prey.global_position, 50.0, "wall")
	expect_equal(nearby_walls.size(), 1, "Should find only close wall")
	expect(nearby_walls.has(close_wall), "Should include close wall")
	
	INTEGRATION_TEST_UTILS.shutdown()
	return false


func _test_building_queries_filter_by_type() -> bool:
	var boot_result = INTEGRATION_TEST_UTILS.boot_main()
	if not boot_result.success:
		return true
	
	var world = boot_result.world
	var registry = world.get_registry()
	
	var prey = INTEGRATION_TEST_UTILS.spawn_creature(world, "small_prey", Vector2(600.0, 600.0))
	await INTEGRATION_TEST_UTILS.wait_frames(2)
	
	# Spawn mixed buildings nearby
	var wall = INTEGRATION_TEST_UTILS.spawn_building(world, "wall", Vector2(620.0, 600.0))
	var trap = INTEGRATION_TEST_UTILS.spawn_building(world, "trap", Vector2(630.0, 600.0))
	var campfire = INTEGRATION_TEST_UTILS.spawn_building(world, "campfire", Vector2(640.0, 600.0))
	await INTEGRATION_TEST_UTILS.wait_frames(2)
	
	# Test type filtering
	var only_walls = registry.get_buildings_near(prey.global_position, 50.0, "wall")
	expect_equal(only_walls.size(), 1, "Should find only walls")
	expect(only_walls.has(wall), "Should include wall")
	
	var only_traps = registry.get_buildings_near(prey.global_position, 50.0, "trap")
	expect_equal(only_traps.size(), 1, "Should find only traps")
	expect(only_traps.has(trap), "Should include trap")
	
	var only_campfires = registry.get_buildings_near(prey.global_position, 50.0, "campfire")
	expect_equal(only_campfires.size(), 1, "Should find only campfires")
	expect(only_campfires.has(campfire), "Should include campfire")
	
	INTEGRATION_TEST_UTILS.shutdown()
	return false


func _test_multiple_creatures_can_query_same_buildings() -> bool:
	var boot_result = INTEGRATION_TEST_UTILS.boot_main()
	if not boot_result.success:
		return true
	
	var world = boot_result.world
	var registry = world.get_registry()
	
	# Spawn two creatures
	var prey = INTEGRATION_TEST_UTILS.spawn_creature(world, "small_prey", Vector2(700.0, 700.0))
	var grazer = INTEGRATION_TEST_UTILS.spawn_creature(world, "grazer", Vector2(710.0, 710.0))
	await INTEGRATION_TEST_UTILS.wait_frames(2)
	
	# Spawn shared wall
	var shared_wall = INTEGRATION_TEST_UTILS.spawn_building(world, "wall", Vector2(720.0, 700.0))
	await INTEGRATION_TEST_UTILS.wait_frames(2)
	
	# Both creatures should find the same wall
	var prey_nearby = registry.get_buildings_near(prey.global_position, 50.0, "wall")
	var grazer_nearby = registry.get_buildings_near(grazer.global_position, 50.0, "wall")
	
	expect_equal(prey_nearby.size(), 1, "Prey should find wall")
	expect_equal(grazer_nearby.size(), 1, "Grazer should find wall")
	expect(prey_nearby.has(shared_wall), "Prey should find shared wall")
	expect(grazer_nearby.has(shared_wall), "Grazer should find shared wall")
	
	INTEGRATION_TEST_UTILS.shutdown()
	return false


func _test_creature_building_query_with_moved_target() -> bool:
	var boot_result = INTEGRATION_TEST_UTILS.boot_main()
	if not boot_result.success:
		return true
	
	var world = boot_result.world
	var registry = world.get_registry()
	
	var prey = INTEGRATION_TEST_UTILS.spawn_creature(world, "small_prey", Vector2(800.0, 800.0))
	await INTEGRATION_TEST_UTILS.wait_frames(2)
	
	# Spawn wall
	var wall = INTEGRATION_TEST_UTILS.spawn_building(world, "wall", Vector2(830.0, 800.0))
	await INTEGRATION_TEST_UTILS.wait_frames(2)
	
	# Wall should be nearby
	var nearby_before = registry.get_buildings_near(prey.global_position, 50.0, "wall")
	expect_equal(nearby_before.size(), 1, "Wall should be nearby initially")
	
	# Move prey far away
	prey.global_position = Vector2(1000.0, 800.0)
	await INTEGRATION_TEST_UTILS.wait_frames(1)
	
	# Wall should no longer be nearby
	var nearby_after = registry.get_buildings_near(prey.global_position, 50.0, "wall")
	expect_equal(nearby_after.size(), 0, "Wall should not be nearby after move")
	
	INTEGRATION_TEST_UTILS.shutdown()
	return false
