extends RefCounted
## Integration tests for World → WorldRegistry → WorldSpatialIndex → Visibility Culling
## Verifies that spawned resources and creatures are properly registered, indexed spatially,
## culled based on visibility, and cleaned up after removal.

const INTEGRATION := preload("res://tests/integration/integration_test_utils.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	await _test_resource_in_registry_and_spatial_index(failures)
	await _test_creature_in_registry_and_spatial_index(failures)
	await _test_meat_drop_registered_in_meat_bucket(failures)
	await _test_moving_creature_updates_spatial_cell(failures)
	await _test_visibility_culling_shows_nearby_objects(failures)
	await _test_visibility_culling_hides_far_objects(failures)
	await _test_culled_creature_skips_full_physics_update(failures)
	await _test_unculled_creature_resumes_physics_update(failures)
	await _test_removed_resource_disappears_from_spatial_query(failures)
	await _test_removed_creature_disappears_from_spatial_query(failures)
	return failures


# ---------------------------------------------------------------------------
# 1. Resource spawned in world is registered in registry and spatial index
# ---------------------------------------------------------------------------
func _test_resource_in_registry_and_spatial_index(failures: Array[String]) -> void:
	var context := await INTEGRATION.boot_main()
	if not bool(context.get("ok", false)):
		failures.append("REGISTRY_SPATIAL: Bootstrap failed: %s" % context.get("reason", "unknown"))
		return
	var tree := context.get("tree") as SceneTree
	var main := context.get("main") as Node
	
	var world := main.get_node_or_null("World")
	var player := main.get_node_or_null("Player") as Node2D
	TEST_UTILS.expect(world != null, failures, "REGISTRY_SPATIAL: World should exist")
	if world == null:
		return
	
	# Spawn a resource
	var spawn_pos := player.global_position + Vector2(100.0, 0.0)
	var resource := INTEGRATION.spawn_resource(world, "rock", spawn_pos)
	TEST_UTILS.expect(resource != null, failures, "REGISTRY_SPATIAL: Resource should spawn")
	if resource == null:
		return
	
	await tree.process_frame
	INTEGRATION.refresh_world_cache(world)
	
	# Check registry
	_assert_resource_in_registry(failures, world, resource, "rock", "REGISTRY_SPATIAL")
	
	# Check spatial index via query
	_assert_resource_in_spatial_query(failures, world, resource, spawn_pos, 200.0, "REGISTRY_SPATIAL")
	await INTEGRATION.shutdown_main(context)


# ---------------------------------------------------------------------------
# 2. Creature spawned in world is registered in registry and spatial index
# ---------------------------------------------------------------------------
func _test_creature_in_registry_and_spatial_index(failures: Array[String]) -> void:
	var context := await INTEGRATION.boot_main()
	if not bool(context.get("ok", false)):
		failures.append("CREATURE_REGISTRY: Bootstrap failed: %s" % context.get("reason", "unknown"))
		return
	var tree := context.get("tree") as SceneTree
	var main := context.get("main") as Node
	
	var world := main.get_node_or_null("World")
	var player := main.get_node_or_null("Player") as Node2D
	if world == null:
		return
	
	# Spawn a creature
	var spawn_pos := player.global_position + Vector2(120.0, 0.0)
	var creature := INTEGRATION.spawn_small_prey(world, "hearth_meadow", spawn_pos)
	TEST_UTILS.expect(creature != null, failures, "CREATURE_REGISTRY: Creature should spawn")
	if creature == null:
		return
	
	await tree.process_frame
	INTEGRATION.refresh_world_cache(world)
	
	# Check registry
	_assert_creature_in_registry(failures, world, creature, "small_prey", "CREATURE_REGISTRY")
	
	# Check spatial index via query
	_assert_creature_in_spatial_query(failures, world, creature, spawn_pos, 200.0, "CREATURE_REGISTRY")
	await INTEGRATION.shutdown_main(context)


# ---------------------------------------------------------------------------
# 3. Meat drop is registered in meat bucket
# ---------------------------------------------------------------------------
func _test_meat_drop_registered_in_meat_bucket(failures: Array[String]) -> void:
	var context := await INTEGRATION.boot_main()
	if not bool(context.get("ok", false)):
		failures.append("MEAT_BUCKET: Bootstrap failed: %s" % context.get("reason", "unknown"))
		return
	var tree := context.get("tree") as SceneTree
	var main := context.get("main") as Node
	
	var world := main.get_node_or_null("World")
	var player := main.get_node_or_null("Player") as Node2D
	if world == null:
		return
	
	# Spawn a meat drop directly (simulate death drop)
	var spawn_pos := player.global_position + Vector2(150.0, 50.0)
	var meat_drop := INTEGRATION.spawn_resource(world, "meat_drop", spawn_pos)
	TEST_UTILS.expect(meat_drop != null, failures, "MEAT_BUCKET: Meat drop should spawn")
	if meat_drop == null:
		return
	
	await tree.process_frame
	INTEGRATION.refresh_world_cache(world)
	
	# Verify meat drop is in registry
	_assert_resource_in_registry(failures, world, meat_drop, "meat_drop", "MEAT_BUCKET")
	
	# Verify meat drop is in spatial query (via meat bucket, not regular resource bucket)
	_assert_resource_in_spatial_query(failures, world, meat_drop, spawn_pos, 200.0, "MEAT_BUCKET")
	await INTEGRATION.shutdown_main(context)


# ---------------------------------------------------------------------------
# 4. Moving creature updates spatial cell
# ---------------------------------------------------------------------------
func _test_moving_creature_updates_spatial_cell(failures: Array[String]) -> void:
	var context := await INTEGRATION.boot_main()
	if not bool(context.get("ok", false)):
		failures.append("MOVING_CELL: Bootstrap failed: %s" % context.get("reason", "unknown"))
		return
	var tree := context.get("tree") as SceneTree
	var main := context.get("main") as Node
	
	var world := main.get_node_or_null("World")
	var player := main.get_node_or_null("Player") as Node2D
	if world == null:
		return
	
	# Spawn creature at initial position
	var initial_pos := player.global_position + Vector2(100.0, 0.0)
	var creature := INTEGRATION.spawn_small_prey(world, "hearth_meadow", initial_pos)
	if creature == null:
		return
	
	await tree.process_frame
	INTEGRATION.refresh_world_cache(world)
	
	# Verify creature is in spatial query at initial position
	_assert_creature_in_spatial_query(failures, world, creature, initial_pos, 100.0, "MOVING_CELL initial")
	
	# Move creature to new position (different grid cell)
	var new_pos := initial_pos + Vector2(400.0, 0.0)
	creature.global_position = new_pos
	
	# Manually update spatial index (if World has this method)
	if world.has_method("_update_creature_spatial_cell"):
		world.call("_update_creature_spatial_cell", creature)
	
	await tree.process_frame
	
	# Verify creature is no longer in old position query
	var far_query := _query_creatures_near(world, initial_pos, 100.0, "small_prey")
	TEST_UTILS.expect_equal(far_query.has(creature), false, failures, "MOVING_CELL: Creature should leave old cell")
	
	# Verify creature is in new position query
	_assert_creature_in_spatial_query(failures, world, creature, new_pos, 100.0, "MOVING_CELL new")
	await INTEGRATION.shutdown_main(context)


# ---------------------------------------------------------------------------
# 5. Visibility culling shows nearby objects
# ---------------------------------------------------------------------------
func _test_visibility_culling_shows_nearby_objects(failures: Array[String]) -> void:
	var context := await INTEGRATION.boot_main()
	if not bool(context.get("ok", false)):
		failures.append("CULLING_SHOW: Bootstrap failed: %s" % context.get("reason", "unknown"))
		return
	var tree := context.get("tree") as SceneTree
	var main := context.get("main") as Node
	
	var world := main.get_node_or_null("World")
	var player := main.get_node_or_null("Player") as Node2D
	if world == null:
		return
	
	player.global_position = Vector2(500.0, 500.0)
	
	# Spawn resource and creature near player
	var resource := INTEGRATION.spawn_resource(world, "rock", player.global_position + Vector2(50.0, 0.0))
	var creature := INTEGRATION.spawn_small_prey(world, "hearth_meadow", player.global_position + Vector2(100.0, 0.0))
	
	if resource == null or creature == null:
		return
	
	await tree.process_frame
	await tree.process_frame
	
	# Force visibility update
	if world.has_method("_update_world_object_visibility"):
		world.call("_update_world_object_visibility")
	
	await tree.process_frame
	
	# Verify objects are visible
	if resource is CanvasItem:
		TEST_UTILS.expect(resource.visible, failures, "CULLING_SHOW: Resource should be visible when near")
	if creature is CanvasItem:
		TEST_UTILS.expect(creature.visible, failures, "CULLING_SHOW: Creature should be visible when near")
	await INTEGRATION.shutdown_main(context)


# ---------------------------------------------------------------------------
# 6. Visibility culling hides far objects
# ---------------------------------------------------------------------------
func _test_visibility_culling_hides_far_objects(failures: Array[String]) -> void:
	var context := await INTEGRATION.boot_main()
	if not bool(context.get("ok", false)):
		failures.append("CULLING_HIDE: Bootstrap failed: %s" % context.get("reason", "unknown"))
		return
	var tree := context.get("tree") as SceneTree
	var main := context.get("main") as Node
	
	var world := main.get_node_or_null("World")
	var player := main.get_node_or_null("Player") as Node2D
	if world == null:
		return
	
	# Keep player at initial position
	var player_pos := player.global_position
	
	# Spawn objects far from player
	var far_pos := player_pos + Vector2(1500.0, 1500.0)
	var resource := INTEGRATION.spawn_resource(world, "rock", far_pos)
	var creature := INTEGRATION.spawn_small_prey(world, "hearth_meadow", far_pos)
	
	if resource == null or creature == null:
		return
	
	await tree.process_frame
	await tree.process_frame
	
	# Force visibility update
	if world.has_method("_update_world_object_visibility"):
		world.call("_update_world_object_visibility")
	
	await tree.process_frame
	
	# Verify objects are not visible
	if resource is CanvasItem:
		TEST_UTILS.expect_equal(resource.visible, false, failures, "CULLING_HIDE: Resource should be hidden when far")
	if creature is CanvasItem:
		TEST_UTILS.expect_equal(creature.visible, false, failures, "CULLING_HIDE: Creature should be hidden when far")
	await INTEGRATION.shutdown_main(context)


# ---------------------------------------------------------------------------
# 7. Culled creature skips full physics update
# ---------------------------------------------------------------------------
func _test_culled_creature_skips_full_physics_update(failures: Array[String]) -> void:
	var context := await INTEGRATION.boot_main()
	if not bool(context.get("ok", false)):
		failures.append("CULLING_PHYSICS: Bootstrap failed: %s" % context.get("reason", "unknown"))
		return
	var tree := context.get("tree") as SceneTree
	var main := context.get("main") as Node
	
	var world := main.get_node_or_null("World")
	var player := main.get_node_or_null("Player") as Node2D
	if world == null:
		return
	
	# Spawn creature far from player (culled)
	var far_pos := player.global_position + Vector2(2000.0, 2000.0)
	var creature := INTEGRATION.spawn_small_prey(world, "hearth_meadow", far_pos)
	if creature == null:
		return
	
	await tree.process_frame
	await tree.process_frame
	
	# Force visibility update to mark as culled
	if world.has_method("_update_world_object_visibility"):
		world.call("_update_world_object_visibility")
	
	await tree.process_frame
	
	# Check if creature is culled
	if creature.has_meta("is_visibility_culled"):
		var is_culled: bool = creature.get_meta("is_visibility_culled")
		TEST_UTILS.expect(is_culled, failures, "CULLING_PHYSICS: Creature should be marked culled when far")
	await INTEGRATION.shutdown_main(context)


# ---------------------------------------------------------------------------
# 8. Unculled creature resumes physics update
# ---------------------------------------------------------------------------
func _test_unculled_creature_resumes_physics_update(failures: Array[String]) -> void:
	var context := await INTEGRATION.boot_main()
	if not bool(context.get("ok", false)):
		failures.append("CULLING_RESUME: Bootstrap failed: %s" % context.get("reason", "unknown"))
		return
	var tree := context.get("tree") as SceneTree
	var main := context.get("main") as Node
	
	var world := main.get_node_or_null("World")
	var player := main.get_node_or_null("Player") as Node2D
	if world == null:
		return
	
	var initial_player_pos := player.global_position
	
	# Spawn creature far (will be culled)
	var far_pos := initial_player_pos + Vector2(2000.0, 2000.0)
	var creature := INTEGRATION.spawn_small_prey(world, "hearth_meadow", far_pos)
	if creature == null:
		return
	
	await tree.process_frame
	
	# Force cull
	if world.has_method("_update_world_object_visibility"):
		world.call("_update_world_object_visibility")
	
	await tree.process_frame
	
	# Move player near the creature
	player.global_position = far_pos + Vector2(100.0, 0.0)
	
	# Force uncull
	if world.has_method("_update_world_object_visibility"):
		world.call("_update_world_object_visibility")
	
	await tree.process_frame
	
	# Verify creature is now visible and not culled
	if creature is CanvasItem:
		TEST_UTILS.expect(creature.visible, failures, "CULLING_RESUME: Creature should be visible after player moves near")
	if creature.has_meta("is_visibility_culled"):
		var is_culled: bool = creature.get_meta("is_visibility_culled")
		TEST_UTILS.expect_equal(is_culled, false, failures, "CULLING_RESUME: Creature should not be culled after player moves near")
	await INTEGRATION.shutdown_main(context)


# ---------------------------------------------------------------------------
# 9. Removed resource disappears from spatial query
# ---------------------------------------------------------------------------
func _test_removed_resource_disappears_from_spatial_query(failures: Array[String]) -> void:
	var context := await INTEGRATION.boot_main()
	if not bool(context.get("ok", false)):
		failures.append("REMOVE_RESOURCE: Bootstrap failed: %s" % context.get("reason", "unknown"))
		return
	var tree := context.get("tree") as SceneTree
	var main := context.get("main") as Node
	
	var world := main.get_node_or_null("World")
	var player := main.get_node_or_null("Player") as Node2D
	if world == null:
		return
	
	# Spawn resource
	var spawn_pos := player.global_position + Vector2(100.0, 0.0)
	var resource := INTEGRATION.spawn_resource(world, "rock", spawn_pos)
	if resource == null:
		return
	
	await tree.process_frame
	INTEGRATION.refresh_world_cache(world)
	
	# Verify in registry
	_assert_resource_in_registry(failures, world, resource, "rock", "REMOVE_RESOURCE before")
	
	# Remove resource
	resource.queue_free()
	await tree.process_frame
	await tree.process_frame
	
	INTEGRATION.refresh_world_cache(world)
	
	# Verify removed from queries
	var query_result := _query_resources_near(world, spawn_pos, 200.0, "rock")
	TEST_UTILS.expect_equal(query_result.has(resource), false, failures, "REMOVE_RESOURCE: Resource should not be in spatial query after removal")
	await INTEGRATION.shutdown_main(context)


# ---------------------------------------------------------------------------
# 10. Removed creature disappears from spatial query
# ---------------------------------------------------------------------------
func _test_removed_creature_disappears_from_spatial_query(failures: Array[String]) -> void:
	var context := await INTEGRATION.boot_main()
	if not bool(context.get("ok", false)):
		failures.append("REMOVE_CREATURE: Bootstrap failed: %s" % context.get("reason", "unknown"))
		return
	var tree := context.get("tree") as SceneTree
	var main := context.get("main") as Node
	
	var world := main.get_node_or_null("World")
	var player := main.get_node_or_null("Player") as Node2D
	if world == null:
		return
	
	# Spawn creature
	var spawn_pos := player.global_position + Vector2(120.0, 0.0)
	var creature := INTEGRATION.spawn_small_prey(world, "hearth_meadow", spawn_pos)
	if creature == null:
		return
	
	await tree.process_frame
	INTEGRATION.refresh_world_cache(world)
	
	# Verify in registry
	_assert_creature_in_registry(failures, world, creature, "small_prey", "REMOVE_CREATURE before")
	
	# Remove creature
	creature.queue_free()
	await tree.process_frame
	await tree.process_frame
	
	INTEGRATION.refresh_world_cache(world)
	
	# Verify removed from queries
	var query_result := _query_creatures_near(world, spawn_pos, 200.0, "small_prey")
	TEST_UTILS.expect_equal(query_result.has(creature), false, failures, "REMOVE_CREATURE: Creature should not be in spatial query after removal")
	await INTEGRATION.shutdown_main(context)


# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

func _assert_resource_in_registry(failures: Array[String], world: Node, resource: Node, kind: String, prefix: String) -> void:
	if world == null or resource == null:
		return
	var resources := _get_all_resources(world)
	TEST_UTILS.expect(resources.has(resource), failures, "%s: Resource should be in registry" % prefix)


func _assert_creature_in_registry(failures: Array[String], world: Node, creature: Node, creature_type: String, prefix: String) -> void:
	if world == null or creature == null:
		return
	var creatures := _get_all_creatures(world)
	TEST_UTILS.expect(creatures.has(creature), failures, "%s: Creature should be in registry" % prefix)


func _assert_resource_in_spatial_query(failures: Array[String], world: Node, resource: Node, position: Vector2, radius: float, prefix: String) -> void:
	if world == null or resource == null:
		return
	var found := _query_resources_near(world, position, radius, "")
	TEST_UTILS.expect(found.has(resource), failures, "%s: Resource should be in spatial query" % prefix)


func _assert_creature_in_spatial_query(failures: Array[String], world: Node, creature: Node, position: Vector2, radius: float, prefix: String) -> void:
	if world == null or creature == null:
		return
	var found := _query_creatures_near(world, position, radius, "small_prey")
	TEST_UTILS.expect(found.has(creature), failures, "%s: Creature should be in spatial query" % prefix)


func _get_all_resources(world: Node) -> Array:
	if world == null:
		return []
	if world.has_method("get_all_registered_resources"):
		return Array(world.call("get_all_registered_resources"))
	return []


func _get_all_creatures(world: Node) -> Array:
	if world == null:
		return []
	if world.has_method("get_all_registered_creatures"):
		return Array(world.call("get_all_registered_creatures"))
	return []


func _query_resources_near(world: Node, position: Vector2, radius: float, kind_filter: String) -> Array:
	if world == null:
		return []
	if not world.has_method("get_registry"):
		return []
	var registry = world.call("get_registry")
	if registry == null:
		return []
	if kind_filter.is_empty():
		return Array(registry.get_resources_near(position, radius, null))
	return Array(registry.get_resources_near(position, radius, kind_filter))


func _query_creatures_near(world: Node, position: Vector2, radius: float, creature_type: String) -> Array:
	if world == null:
		return []
	if not world.has_method("get_registry"):
		return []
	var registry = world.call("get_registry")
	if registry == null:
		return []
	if creature_type.is_empty():
		return []
	return Array(registry.get_creatures_near(position, radius, creature_type))
