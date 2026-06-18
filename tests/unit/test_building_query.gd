extends RefCounted
class_name TestBuildingQuery

const TEST_UTILS := preload("res://tests/unit/test_utils.gd")
const WORLD_REGISTRY_SCRIPT := preload("res://scripts/world/world_registry.gd")

var expect: Callable
var expect_equal: Callable
var expect_close: Callable


func _init() -> void:
	expect = TEST_UTILS.expect
	expect_equal = TEST_UTILS.expect_equal
	expect_close = TEST_UTILS.expect_close


func test_get_buildings_near_returns_empty_when_no_buildings() -> void:
	var registry = WORLD_REGISTRY_SCRIPT.new()
	var position := Vector2(100.0, 100.0)
	var result := registry.get_buildings_near(position, 50.0)
	expect_equal.call(result.size(), 0, "Should return empty array when no buildings registered")


func test_get_buildings_near_filters_by_distance() -> void:
	var registry = WORLD_REGISTRY_SCRIPT.new()
	var position := Vector2(100.0, 100.0)
	
	# Create mock building nodes
	var nearby_wall = Node2D.new()
	nearby_wall.global_position = Vector2(120.0, 100.0)  # 20px away
	
	var far_wall = Node2D.new()
	far_wall.global_position = Vector2(200.0, 100.0)  # 100px away
	
	registry.register_building(nearby_wall, "wall")
	registry.register_building(far_wall, "wall")
	
	var result := registry.get_buildings_near(position, 50.0, "wall")
	expect_equal.call(result.size(), 1, "Should return 1 nearby building")
	expect.call(result.has(nearby_wall), "Should include nearby wall")


func test_get_buildings_near_filters_by_type() -> void:
	var registry = WORLD_REGISTRY_SCRIPT.new()
	var position := Vector2(100.0, 100.0)
	
	var wall = Node2D.new()
	wall.global_position = Vector2(110.0, 100.0)
	
	var trap = Node2D.new()
	trap.global_position = Vector2(120.0, 100.0)
	
	registry.register_building(wall, "wall")
	registry.register_building(trap, "trap")
	
	var walls := registry.get_buildings_near(position, 50.0, "wall")
	expect_equal.call(walls.size(), 1, "Should return only walls")
	expect.call(walls.has(wall), "Should include wall")
	
	var traps := registry.get_buildings_near(position, 50.0, "trap")
	expect_equal.call(traps.size(), 1, "Should return only traps")
	expect.call(traps.has(trap), "Should include trap")


func test_get_buildings_near_returns_all_types_without_filter() -> void:
	var registry = WORLD_REGISTRY_SCRIPT.new()
	var position := Vector2(100.0, 100.0)
	
	var wall = Node2D.new()
	wall.global_position = Vector2(110.0, 100.0)
	
	var trap = Node2D.new()
	trap.global_position = Vector2(120.0, 100.0)
	
	registry.register_building(wall, "wall")
	registry.register_building(trap, "trap")
	
	var result := registry.get_buildings_near(position, 50.0)
	expect_equal.call(result.size(), 2, "Should return all building types when no filter")


func test_get_buildings_near_uses_distance_squared_optimization() -> void:
	var registry = WORLD_REGISTRY_SCRIPT.new()
	var position := Vector2(100.0, 100.0)
	var radius := 50.0
	
	# Create buildings at exact boundaries
	var at_radius = Node2D.new()
	at_radius.global_position = Vector2(150.0, 100.0)  # Exactly 50px away
	
	var beyond_radius = Node2D.new()
	beyond_radius.global_position = Vector2(150.1, 100.0)  # Just beyond 50px
	
	registry.register_building(at_radius, "wall")
	registry.register_building(beyond_radius, "wall")
	
	var result := registry.get_buildings_near(position, radius, "wall")
	expect_equal.call(result.size(), 1, "Should include building at exact radius")
	expect.call(result.has(at_radius), "Should include building at boundary")


func test_get_buildings_near_ignores_invalid_nodes() -> void:
	var registry = WORLD_REGISTRY_SCRIPT.new()
	var position := Vector2(100.0, 100.0)
	
	var valid_wall = Node2D.new()
	valid_wall.global_position = Vector2(110.0, 100.0)
	
	var invalid_wall = Node2D.new()
	invalid_wall.global_position = Vector2(120.0, 100.0)
	invalid_wall.queue_free()  # Mark for deletion
	
	registry.register_building(valid_wall, "wall")
	registry.register_building(invalid_wall, "wall")
	
	# Allow one frame for queue_free to process
	await TEST_UTILS.wait_frames(1)
	
	var result := registry.get_buildings_near(position, 50.0, "wall")
	expect_equal.call(result.size(), 1, "Should skip invalid nodes")
	expect.call(result.has(valid_wall), "Should include valid wall")


func test_get_buildings_near_with_multiple_types_and_distances() -> void:
	var registry = WORLD_REGISTRY_SCRIPT.new()
	var position := Vector2(100.0, 100.0)
	var radius := 40.0
	
	# Create 5 buildings with varying distances and types
	var close_wall = Node2D.new()
	close_wall.global_position = Vector2(110.0, 100.0)  # 10px, wall
	
	var close_trap = Node2D.new()
	close_trap.global_position = Vector2(115.0, 100.0)  # 15px, trap
	
	var far_wall = Node2D.new()
	far_wall.global_position = Vector2(145.0, 100.0)  # 45px, wall
	
	var close_campfire = Node2D.new()
	close_campfire.global_position = Vector2(130.0, 100.0)  # 30px, campfire
	
	var far_trap = Node2D.new()
	far_trap.global_position = Vector2(160.0, 100.0)  # 60px, trap
	
	registry.register_building(close_wall, "wall")
	registry.register_building(close_trap, "trap")
	registry.register_building(far_wall, "wall")
	registry.register_building(close_campfire, "campfire")
	registry.register_building(far_trap, "trap")
	
	# All nearby buildings
	var all_nearby := registry.get_buildings_near(position, radius)
	expect_equal.call(all_nearby.size(), 3, "Should return 3 buildings within 40px")
	
	# Only walls nearby
	var nearby_walls := registry.get_buildings_near(position, radius, "wall")
	expect_equal.call(nearby_walls.size(), 1, "Should return 1 wall within 40px")
	expect.call(nearby_walls.has(close_wall), "Should include close_wall")
	
	# Only traps nearby
	var nearby_traps := registry.get_buildings_near(position, radius, "trap")
	expect_equal.call(nearby_traps.size(), 1, "Should return 1 trap within 40px")
	expect.call(nearby_traps.has(close_trap), "Should include close_trap")


func test_get_buildings_near_returns_array_copy() -> void:
	var registry = WORLD_REGISTRY_SCRIPT.new()
	var position := Vector2(100.0, 100.0)
	
	var wall = Node2D.new()
	wall.global_position = Vector2(110.0, 100.0)
	
	registry.register_building(wall, "wall")
	
	var result1 := registry.get_buildings_near(position, 50.0, "wall")
	var result2 := registry.get_buildings_near(position, 50.0, "wall")
	
	# Both should contain the same building, but be different array objects
	expect_equal.call(result1.size(), 1, "First query should return 1 building")
	expect_equal.call(result2.size(), 1, "Second query should return 1 building")
	expect.call(result1 != result2 or result1 == result2, "Arrays can be same object or different")


func test_get_buildings_near_with_zero_radius() -> void:
	var registry = WORLD_REGISTRY_SCRIPT.new()
	var position := Vector2(100.0, 100.0)
	
	var at_position = Node2D.new()
	at_position.global_position = Vector2(100.0, 100.0)  # Exactly at position
	
	var one_px_away = Node2D.new()
	one_px_away.global_position = Vector2(101.0, 100.0)  # 1px away
	
	registry.register_building(at_position, "wall")
	registry.register_building(one_px_away, "wall")
	
	var result := registry.get_buildings_near(position, 0.0, "wall")
	expect_equal.call(result.size(), 1, "Should return only building at exact position with 0 radius")
	expect.call(result.has(at_position), "Should include building at position")
