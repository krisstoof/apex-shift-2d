# World Registry, Spatial Index & Visibility Culling Integration Tests

## Overview

This document describes the integration test suite that validates how `World`, `WorldRegistry`, `WorldSpatialIndex`, and visibility culling work together as a cohesive system.

**Purpose**: Ensure that:
- Resources and creatures spawned in the world are properly registered and indexed
- Spatial queries return correct results
- Visibility culling efficiently manages rendering and updates based on camera position
- Entity lifecycle (spawn, move, despawn) is correctly tracked across all systems

**Test File**: [tests/integration/test_world_registry_spatial_visibility_integration.gd](../../tests/integration/test_world_registry_spatial_visibility_integration.gd)

## System Architecture Overview

### WorldRegistry
Maintains lists of all active entities (resources, creatures, buildings) in the world.

**Key methods**:
- `register_resource(node)` — add resource to tracking
- `unregister_resource(node)` — remove resource
- `register_creature(node, creature_type, biome_id)` — add creature to tracking
- `unregister_creature(node)` — remove creature
- `get_resources_near(position, radius, kind_filter)` — proxies to spatial index
- `get_creatures_near(position, radius, creature_type_filter)` — proxies to spatial index

### WorldSpatialIndex
Implements grid-based spatial partitioning for efficient radius/rect queries.

**Structure**:
- **Cell size**: 256.0 pixels
- **Buckets**: Separate cells for resources, creatures, and meat drops
- **Tracking**: `tracked_entities` dict stores WeakRef + metadata for all indexed entities

**Key methods**:
- `register_entity(entity, category, type_name)` — add to appropriate cell bucket
- `unregister_entity(entity)` — remove and clean up
- `update_entity_cell(entity)` — move entity between cells if position changed
- `query_resources_near(position, radius, kind_filter)` — returns resources in radius
- `query_creatures_near(position, radius, type_filter)` — returns creatures by type
- `query_meat_near(position, radius)` — returns meat drops in radius
- `cleanup_stale_entries()` — removes freed/invalid WeakRefs

### Visibility Culling (WorldVisibilityController)
Periodically updates object visibility based on camera position and visible rect.

**Flow**:
1. Every 0.35 seconds: calculate expanded visible rect (camera rect + margin)
2. Query registry for all entities in visible rect
3. Compare against previous frame's visible set
4. Hide nodes that left the rect, show nodes that entered
5. Mark creature as culled if `is_visibility_culled` property exists

**Key methods**:
- `process(delta)` — called each frame, updates on interval
- `force_update()` — immediate visibility check
- `_update_visibility()` — executes the visibility update logic
- `_set_visibility(node, visible)` — toggles visibility, calls `node.visible = true/false`

## Entity Lifecycle Flow

```
┌─────────────────┐
│ SPAWN RESOURCE  │
└────────┬────────┘
         │
         ├─→ Instance scene
         ├─→ Set position
         ├─→ add_child() to World
         │
         ├─→ register_resource_node(resource)
         │   ├─→ registry.register_resource(resource)
         │   │   ├─→ spatial_index.register_entity(resource, "resource", kind)
         │   │   │   ├─→ Calculate cell = position / 256.0
         │   │   │   ├─→ resources_by_cell[cell].append(resource)
         │   │   │   └─→ tracked_entities[id] = {ref, cell, category, kind}
         │   │   └─→ _resource_nodes.append(resource)
         │   └─→ resource visible = false (culled until in view)
         │
         ├─→ Each frame:
         │   ├─→ resource.process(delta) — update position
         │   ├─→ registry.update_entity_cell(resource) — if moved
         │   │   └─→ unregister from old cell + register in new cell
         │   └─→ visibility_controller.process(delta) every 0.35s
         │       ├─→ Query visible_rect
         │       ├─→ spatial_index.query_resources_in_rect(visible_rect)
         │       ├─→ _mark_visible(resource, true)
         │       │   └─→ resource.visible = true
         │       └─→ Hide resources that left rect
         │
         ├─→ REMOVE/DESPAWN
         │   ├─→ unregister_resource(resource)
         │   │   ├─→ spatial_index.unregister_entity(resource)
         │   │   │   ├─→ resources_by_cell[cell].erase(resource)
         │   │   │   └─→ tracked_entities.erase(id)
         │   │   └─→ _resource_nodes.erase(resource)
         │   └─→ queue_free()
         │
         └─→ resource freed, WeakRef becomes invalid
```

## Test Scenarios

### Test 1: Resource Spawned in World is Registered in Registry and Spatial Index

**Objective**: Verify that a spawned resource immediately appears in registry and spatial index.

**Setup**:
- Boot main world
- Spawn resource at known position

**Assertions**:
- Resource is in `world_registry.get_all_registered_resources()`
- Resource appears in `registry.get_resources_near(position, radius)` query
- Registry can find resource by specific kind (`get_resources_near(..., "rock")`)

**Failure Modes**:
- Resource in scene but not in registry
- Resource in registry but not in spatial bucket for its cell
- Spatial query returns stale or freed entities

### Test 2: Creature Spawned in World is Registered in Registry and Spatial Index

**Objective**: Verify creature registration in both systems.

**Setup**:
- Spawn creature (small_prey, grazer, or varnak)

**Assertions**:
- Creature is in `registry.get_all_registered_creatures()`
- Creature appears in `registry.get_creatures_near(position, radius, "small_prey")`
- Creature type is correct in registry

**Failure Modes**:
- Creature type not tracked
- Creature in wrong cell bucket
- Spatial query returns creatures of wrong type

### Test 3: Meat Drop Registered in Meat Bucket

**Objective**: Verify meat drops use separate bucket from regular resources.

**Setup**:
- Spawn meat drop (simulates creature death or direct spawn)

**Assertions**:
- Meat drop is in registry
- `registry.get_meat_near(position, radius)` returns meat drop
- `registry.get_resources_near(position, radius, "meat_drop")` may or may not return it (depends on implementation)
- Meat drop is NOT returned by `get_resources_near(..., "rock")`

**Failure Modes**:
- Meat drop classified as regular resource
- Meat drop missing from meat bucket
- Queries cross-contaminate resource buckets

### Test 4: Moving Creature Updates Spatial Cell

**Objective**: Verify entity migration between grid cells when position changes.

**Setup**:
- Spawn creature at position A (cell 0)
- Move creature to position B (cell 1)
- Update spatial index

**Assertions**:
- Creature no longer in query at old position
- Creature present in query at new position
- `get_entity_cell(creature) == Vector2i(cell_x, cell_y)` correct
- Only one instance of creature in spatial index (no duplicates)

**Failure Modes**:
- Creature exists in both old and new cell
- Creature stuck in old cell after move
- `update_entity_cell()` fails silently

### Test 5: Visibility Culling Shows Nearby Objects

**Objective**: Verify objects near camera/player are visible.

**Setup**:
- Spawn resource and creature near player
- Force visibility update
- Player remains near objects

**Assertions**:
- `resource.visible == true`
- `creature.visible == true`
- Creature is not marked culled (if using `is_visibility_culled` meta)

**Failure Modes**:
- Nearby objects remain hidden
- Visibility not updated after force_update()
- Player in range but objects still culled

### Test 6: Visibility Culling Hides Far Objects

**Objective**: Verify objects outside visible rect become hidden.

**Setup**:
- Spawn resource and creature far from player (2000+ pixels away)
- Force visibility update
- Player remains far away

**Assertions**:
- `resource.visible == false`
- `creature.visible == false`
- Creature marked as culled

**Failure Modes**:
- Far objects remain visible
- Culling fails to trigger on distant objects
- Objects hidden but still in visible_nodes cache

### Test 7: Culled Creature Skips Full Physics Update

**Objective**: Verify culled creatures don't execute expensive physics logic.

**Setup**:
- Spawn creature far from player
- Force cull
- Monitor physics update counter

**Assertions**:
- Creature is marked culled: `creature.is_visibility_culled == true`
- (Optional) Physics update count does not increase while culled
- Background simulation may still run (if implemented)

**Failure Modes**:
- Creature not marked culled despite being far
- Full physics still running while culled
- Update counters not exposed for testing

### Test 8: Unculled Creature Resumes Physics Update

**Objective**: Verify creature physics resumes when returning to visible area.

**Setup**:
- Spawn creature far (culled)
- Move player/camera near creature
- Force uncull
- Monitor physics counter

**Assertions**:
- Creature no longer culled: `creature.is_visibility_culled == false`
- Creature visible: `creature.visible == true`
- Physics update counter increases (full physics resumed)

**Failure Modes**:
- Creature remains culled after player moves near
- Creature not visible after unculling
- Physics doesn't resume

### Test 9: Removed Resource Disappears from Spatial Query

**Objective**: Verify cleanup after resource deletion.

**Setup**:
- Spawn resource
- Queue free
- Wait for cleanup tick
- Query spatial index

**Assertions**:
- Resource no longer in registry
- Spatial query doesn't return freed resource
- No invalid/stale WeakRefs in queries

**Failure Modes**:
- Freed resource still in spatial bucket
- Queries crash on invalid WeakRef
- Resource not unregistered after queue_free

### Test 10: Removed Creature Disappears from Spatial Query

**Objective**: Verify creature cleanup.

**Setup**:
- Spawn creature
- Queue free (or death flow)
- Wait for cleanup
- Query spatial index

**Assertions**:
- Creature no longer in registry
- Spatial query doesn't return freed creature
- No invalid refs in queries
- If death flow: meat drop appears in meat bucket

**Failure Modes**:
- Freed creature still queries
- Meat drop not created on death
- Creature exists in stale cache

## Common Failure Patterns & Debugging

### Problem: "Object is in scene, but not in registry"

**Cause**: Entity not registered or registration fails silently.

**Debug**:
```gdscript
var world = get_node("World")
var all_resources = world.get_all_registered_resources()
print("Registered resources: %d" % all_resources.size())
print("Resource in registry: %s" % all_resources.has(my_resource))
```

**Fix**: Ensure `register_resource_node()` is called during spawn flow.

### Problem: "Object is in registry, but not in spatial index"

**Cause**: Registry registered but spatial index registration failed or wrong category.

**Debug**:
```gdscript
var spatial_index = world.get_registry().spatial_index
var query = spatial_index.query_resources_near(position, 100.0, "rock")
print("Found in spatial: %s" % query.has(my_resource))
var debug = spatial_index.get_debug_counts()
print("Debug counts: %s" % JSON.stringify(debug))
```

**Fix**: Verify correct category ("resource", "creature", "meat") passed to `register_entity()`.

### Problem: "Object in spatial index after queue_free"

**Cause**: WeakRef not checked, or cleanup not called.

**Debug**:
```gdscript
my_resource.queue_free()
await get_tree().process_frame
await get_tree().process_frame
spatial_index.cleanup_stale_entries()  # Manual cleanup if needed
var query = spatial_index.query_resources_near(pos, 100.0, "rock")
print("Still in query: %s" % query.has(my_resource))  # Should be false/null
```

**Fix**: Ensure `cleanup_stale_entries()` is called periodically (World should do this).

### Problem: "Object in two spatial cells at once"

**Cause**: Entity moved but `update_entity_cell()` not called.

**Debug**:
```gdscript
my_creature.global_position = new_pos
world.registry.update_entity_cell(my_creature)  # Must call this after move
var old_cell_query = spatial_index.query_creatures_near(old_pos, 50.0, "small_prey")
var new_cell_query = spatial_index.query_creatures_near(new_pos, 50.0, "small_prey")
print("In old cell: %s, In new cell: %s" % [old_cell_query.has(my_creature), new_cell_query.has(my_creature)])
```

**Fix**: Call `update_entity_cell()` after manual position changes in tests.

### Problem: "Culled creature still executing full physics"

**Cause**: Culling not properly disabling expensive updates.

**Debug**:
```gdscript
print("Creature culled: %s" % creature.is_visibility_culled)
print("Creature visible: %s" % creature.visible)
var before = creature.debug_full_physics_update_count
simulate_physics_ticks(5)
var after = creature.debug_full_physics_update_count
print("Physics updates while culled: %d" % (after - before))
```

**Fix**: Ensure creature respects `is_visibility_culled` flag and skips physics if true.

### Problem: "Object doesn't become visible after entering visible rect"

**Cause**: Visibility update not triggered or cache not refreshed.

**Debug**:
```gdscript
world.force_visibility_update()  # Or _update_world_object_visibility()
await get_tree().process_frame
print("Object visible: %s" % my_resource.visible)
var debug = world.get_visibility_culling_debug()
print("Debug: visible=%d, hidden=%d" % [debug.get("visible_resources", 0), debug.get("hidden_resources", 0)])
```

**Fix**: Call `force_update()` on visibility controller after moving player/camera.

## Running the Tests

### In VS Code with Godot

1. Open project in Godot
2. Run integration tests:
   ```bash
   # Terminal in VS Code
   godot --no-window --scene tests/integration/integration_test_runner.tscn
   ```
3. Or run specific test:
   ```gdscript
   var test = preload("res://tests/integration/test_world_registry_spatial_visibility_integration.gd").new()
   var failures = await test.run()
   for failure in failures:
       print("✗ " + failure)
   ```

### Automated Test Runner

Tests are registered in `integration_test_runner.gd` and run as part of the full integration test suite.

## Performance Considerations

### Spatial Index Cell Size
- Current: 256.0 pixels
- Larger cells: faster queries but less precise
- Smaller cells: more precise but more overhead

### Query Radius
- Large radius queries span many cells
- Tests use 200px radius for balanced coverage

### Visibility Check Interval
- Current: 0.35 seconds
- More frequent: better responsiveness, higher CPU
- Less frequent: lower CPU, visible pop-in

### Bucket Cleanup
- Stale WeakRef cleanup runs periodically
- Prevents spatial index bloat over long play sessions

## Test Utilities

### Helper Functions

```gdscript
# Internal helpers (within test file)
_assert_resource_in_registry(failures, world, resource, kind, prefix)
_assert_creature_in_registry(failures, world, creature, type, prefix)
_assert_resource_in_spatial_query(failures, world, resource, pos, radius, prefix)
_assert_creature_in_spatial_query(failures, world, creature, pos, radius, prefix)

# Integration utilities (integration_test_utils.gd)
INTEGRATION.boot_main() → {ok, tree, main, reason}
INTEGRATION.spawn_resource(world, kind, pos) → resource_node
INTEGRATION.spawn_small_prey(world, biome, pos) → creature_node
INTEGRATION.spawn_grazer(world, biome, pos) → creature_node
INTEGRATION.spawn_varnak(world, pos) → creature_node
INTEGRATION.refresh_world_cache(world)
INTEGRATION.shutdown_main(context)
```

## References

- [WorldRegistry](../../scripts/world/world_registry.gd)
- [WorldSpatialIndex](../../scripts/world/world_spatial_index.gd)
- [WorldVisibilityController](../../scripts/world/world_visibility_controller.gd)
- [World](../../scripts/world/world.gd)
- [Integration Tests](../../tests/integration/test_world_registry_spatial_visibility_integration.gd)
- [Integration Test Utils](../../tests/integration/integration_test_utils.gd)
