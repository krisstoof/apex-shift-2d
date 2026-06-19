# Modularization Plan

## Purpose

This document describes how the project should gradually split gameplay systems into portable core modules, Godot runtime adapters, and rendering/presentation layers.

The goal is to make gameplay logic easier to test, easier to refactor, and less dependent on Godot scene tree behavior.

This is not a big-bang rewrite.

The existing game must continue to work while systems are extracted step by step.

## Safety Rules

- Do not rewrite the whole game at once.
- Do not move large systems without tests.
- Do not change gameplay behavior just to satisfy architecture.
- Do not mix architecture cleanup with balance changes.
- Do not mix architecture cleanup with rendering optimization unless the task explicitly says so.
- Existing save/load behavior must remain compatible.
- Existing tests and benchmark behavior should remain unchanged unless the task explicitly says otherwise.
- Prefer small adapter layers over large rewrites.

## Target Layer Split

The project should move toward three main layers:

```text
scripts/
  core/
    common/
    world/
    survival/
    inventory/
    crafting/
    resources/
    creatures/
    ecosystem/
    spatial/
    save/
    events/
    time/
    buildings/

  godot_runtime/
    world/
    creatures/
    player/
    resources/
    buildings/
    ui/

  rendering/
    world/
    terrain/
    minimap/
    hud/
```

## Layer 1: Core Modules

Core modules contain portable gameplay logic and data structures.

Core modules should be able to run in tests without the Godot scene tree.

Core modules may use simple Godot value types for now, such as:

- `Vector2`
- `Vector2i`
- `Rect2`
- `Dictionary`
- `Array`

However, core modules should avoid Godot runtime objects such as:

- `Node`
- `Node2D`
- `SceneTree`
- `PackedScene`
- `CanvasItem`
- `Texture2D`
- `Sprite2D`
- `Control`
- UI nodes
- rendering nodes

A module is considered portable when:

- it extends `RefCounted` or is a pure static helper,
- it does not depend on `_ready()`, `_process()`, `_physics_process()`, `_enter_tree()`, or `_exit_tree()`,
- it does not call `get_tree()`,
- it does not instantiate scenes,
- it does not require nodes to function,
- it works with entity ids, positions, data records, dictionaries, and value objects,
- it can be tested without manually running the game.

### Examples of Core Modules

Good candidates for `scripts/core/`:

- world generation result data,
- world generation summary,
- world generation hash,
- world generation validation,
- spatial index data structure,
- inventory data,
- crafting recipes and crafting validation,
- resource definitions,
- creature state data,
- hunger/diet rules,
- ecosystem commands and deltas,
- save data schemas,
- day/time calculations,
- event payload definitions,
- building placement rules.

## Layer 2: Godot Runtime Adapters

Godot runtime adapters connect portable core logic to Godot scenes and nodes.

Adapters may use:

- `Node`
- `Node2D`
- signals,
- groups,
- scene tree queries,
- `PackedScene`,
- node lifecycle methods,
- weak references to nodes,
- runtime glue code.

Adapters should be thin.

They should translate between:

```text
Godot Node / Scene
        ↓
entity id + position + metadata
        ↓
core system
        ↓
data result / command / query result
        ↓
Godot Node / Scene update
```

### Examples of Godot Runtime Adapters

Good candidates for `scripts/godot_runtime/`:

- world scene orchestration,
- entity registration from scene nodes,
- player node integration,
- creature node adapters,
- resource node adapters,
- building node adapters,
- save/load file access,
- event bus node integration,
- signal wiring,
- spawning scene instances from core spawn data.

## Layer 3: Rendering and Presentation

Rendering and presentation systems should focus only on visual output.

Rendering systems may use:

- `CanvasItem`
- `Node2D`
- textures,
- draw calls,
- terrain surfaces,
- biome textures,
- minimap textures,
- HUD presentation,
- visual layers,
- animation,
- debug overlays.

Rendering systems should not own gameplay rules.

They should consume data from core/runtime systems.

### Examples of Rendering-Specific Systems

Good candidates for `scripts/rendering/`:

- terrain surface rendering,
- biome texture building,
- minimap rendering,
- map screen rendering,
- decorative vegetation rendering,
- HUD drawing,
- debug overlays,
- visual-only chunk culling,
- night overlay rendering.

## Debug and Benchmark-Only Systems

Debug and benchmark systems should be clearly separated from gameplay logic.

They may inspect runtime state, but should not be required for gameplay to work.

Debug/benchmark systems include:

- benchmark runner,
- benchmark report formatting,
- debug panel,
- debug overlays,
- performance attribution helpers,
- temporary diagnostics,
- profiler summary builders.

Rules:

- Debug systems can read gameplay data.
- Debug systems should not mutate gameplay state unless explicitly designed to do so.
- Benchmark code should not be required by normal gameplay systems.
- Benchmark thresholds should not be changed during unrelated refactors.
- Performance diagnostics should not become gameplay dependencies.

## Current Major Gameplay Systems

The current project contains several large gameplay areas that should be gradually separated.

### World

Current responsibilities include:

- world generation,
- terrain and biome data,
- resource spawning,
- creature spawning,
- landmark generation,
- player spawn placement,
- runtime orchestration,
- rendering coordination.

Target direction:

- move generation data and validation to `scripts/core/world/`,
- keep scene orchestration in Godot runtime,
- keep terrain/minimap/visual rendering in rendering modules.

### WorldConfig / GameBalance

Current responsibilities include:

- world dimensions,
- balance constants,
- spawn settings,
- survival settings,
- creature/resource tuning.

Target direction:

- data-only config can be core,
- Godot-specific exports/resources stay in runtime,
- balance should be read by core systems through data structures where possible.

### EcosystemDirector

Current responsibilities include:

- living world updates,
- animal/resource interactions,
- ecosystem events,
- command/delta processing.

Target direction:

- decision rules, commands, and deltas should move to core,
- scene/node execution should stay in runtime adapters.

### ResourceNode

Current responsibilities include:

- resource state,
- harvesting,
- regrowth,
- collision/interaction,
- visual node behavior.

Target direction:

- resource state and rules should move to core,
- Node2D, collision, visuals, and interaction wiring should stay in runtime/rendering.

### Creatures

Current creature systems include:

- SmallPrey,
- Grazer,
- Varnak,
- hunger,
- diet rules,
- movement,
- hunting,
- eating,
- death/drop behavior.

Target direction:

- creature state, hunger/diet rules, and decision logic should move to core,
- Node movement, animation, collision, and scene behavior should stay in runtime adapters.

### Inventory and Crafting

Current/future responsibilities include:

- inventory slots,
- item stacks,
- crafting recipes,
- crafting validation,
- item consumption,
- tool creation.

Target direction:

- inventory and crafting rules should be core,
- UI screens should be presentation/runtime,
- item scene spawning should be runtime.

### Buildings

Current/future responsibilities include:

- campfires,
- storage boxes,
- traps,
- walls,
- tents,
- placement rules.

Target direction:

- placement validation and building data should be core,
- spawned building scenes should be runtime,
- visual representation should be rendering/presentation.

### SaveSystem

Current responsibilities include:

- collecting game state,
- serializing state,
- restoring runtime objects,
- restoring world state.

Target direction:

- save schemas and pure validation should be core,
- file access and node restoration should be runtime,
- save/load should be able to compare generation summary/hash.

### Spatial Index

Current responsibilities include:

- finding nearby resources,
- finding nearby creatures,
- finding meat drops,
- rectangle queries,
- cleanup of stale node references.

Target direction:

- core index should work with entity ids, positions, categories, and metadata,
- Godot adapter may map Node2D to entity id + position,
- query results should be data-first,
- Node references may exist only as optional adapter payloads.

### Minimap and Map Screen

Current responsibilities include:

- presenting world data,
- texture generation,
- landmarks display,
- viewport/map interaction.

Target direction:

- map/minimap rendering should be rendering layer,
- any pure map summary data can be core,
- UI interaction stays in runtime/presentation.

### DebugPanel and BenchmarkRunner

Current responsibilities include:

- runtime diagnostics,
- benchmark reports,
- performance attribution,
- debug text.

Target direction:

- debug-only systems should remain separate,
- they can consume core/runtime/rendering metrics,
- gameplay must not depend on debug panel or benchmark runner.

## Systems to Extract Gradually

The following systems are good candidates for extraction into portable modules.

### Already started or high priority

```text
scripts/core/common/
scripts/core/world/world_generation_result.gd
scripts/core/world/world_generation_summary.gd
scripts/core/world/world_generation_hash.gd
scripts/core/world/world_generation_validator.gd
scripts/core/spatial/world_spatial_index.gd
scripts/core/spatial/spatial_query.gd
scripts/core/spatial/spatial_query_result.gd
```

### Next extraction candidates

```text
scripts/core/inventory/
scripts/core/crafting/
scripts/core/resources/
scripts/core/creatures/
scripts/core/ecosystem/
scripts/core/save/
scripts/core/buildings/
scripts/core/time/
scripts/core/events/
```

### Systems that should remain adapters

```text
scripts/godot_runtime/world/
scripts/godot_runtime/player/
scripts/godot_runtime/resources/
scripts/godot_runtime/creatures/
scripts/godot_runtime/buildings/
scripts/godot_runtime/ui/
```

### Systems that should remain rendering/presentation

```text
scripts/rendering/world/
scripts/rendering/terrain/
scripts/rendering/minimap/
scripts/rendering/hud/
```

## Rules for Writing New Modules

### Prefer Core by Default for Gameplay Rules

New gameplay rules should start in `scripts/core/` when possible.

Good examples:

```gdscript
func can_craft(recipe_id: String, inventory: InventoryState) -> GameResult
```

```gdscript
func calculate_hunger_delta(current_hunger: float, elapsed_seconds: float) -> float
```

```gdscript
func query_circle(position: Vector2, radius: float, category_filter: Variant = null) -> Array
```

Bad examples:

```gdscript
func can_craft_from_ui(crafting_panel: Control) -> bool
```

```gdscript
func calculate_hunger_from_node(creature: Node2D) -> float
```

```gdscript
func query_nearby_resources_from_scene_tree(world: Node) -> Array
```

### Use Data Inputs, Not Scene Inputs

Good:

```gdscript
register_entity(entity_id, position, category, metadata)
```

Bad:

```gdscript
register_entity(node: Node2D)
```

Acceptable in adapter only:

```gdscript
func register_node(node: Node2D) -> void:
	var entity_id := node.get_instance_id()
	var position := node.global_position
	core_index.register_entity(entity_id, position, "resource", {"payload": node})
```

### Return Data Results

Good:

```gdscript
return GameResult.ok({"crafted_item": item_id})
```

```gdscript
return SpatialQueryResult.from_record(record)
```

Bad:

```gdscript
return get_tree().get_nodes_in_group("resources")
```

### Keep Rendering Out of Core

Good:

```gdscript
var biome_id := biome_map.get_biome_id_at(position)
```

Bad:

```gdscript
var color := biome_texture.get_pixel(x, y)
```

Good rendering adapter:

```gdscript
func draw_biome_layer(biome_data: Dictionary) -> void
```

### Avoid Hidden Runtime Dependencies

Core modules should not require:

- a loaded scene,
- a current scene,
- a player node,
- UI nodes,
- a debug panel,
- a minimap,
- benchmark runner,
- collision shapes,
- signals from scene nodes.

## Rules for Migrating Existing Systems

### Step 1: Identify Data and Behavior

Before moving code, split each system into:

- state data,
- pure rules,
- runtime node integration,
- rendering/presentation,
- debug instrumentation.

### Step 2: Extract Data Objects First

Create simple data objects before moving behavior.

Examples:

```text
ResourceState
CreatureState
InventoryState
CraftingRecipe
WorldGenerationResult
SpatialQueryResult
SaveGameSnapshot
```

### Step 3: Add Core Tests

Every extracted core module should have tests.

Minimum tests should cover:

- creation,
- serialization if applicable,
- main rules,
- edge cases,
- invalid inputs,
- compatibility expectations.

### Step 4: Keep Old API Through an Adapter

If existing systems depend on an old Node-based API, keep that API temporarily.

Good migration pattern:

```text
scripts/core/spatial/world_spatial_index.gd
  pure data index

scripts/world/world_spatial_index.gd
  Godot adapter preserving old Node-based API
```

### Step 5: Move Callers Gradually

Do not update all callers at once.

Migration order should be:

1. add core module,
2. add adapter,
3. add tests,
4. keep old behavior working,
5. gradually update callers,
6. remove old compatibility only when no longer used.

### Step 6: Do Not Mix Refactor With Design Changes

Avoid combining modularization with:

- balance changes,
- spawn rate changes,
- AI behavior changes,
- rendering optimizations,
- save format changes,
- benchmark threshold changes.

## Good API Examples

### Portable Resource Rule

```gdscript
func can_harvest(resource_state: ResourceState, tool_id: String) -> GameResult:
	if resource_state.is_depleted:
		return GameResult.fail("Resource is depleted")
	if not resource_state.allowed_tools.has(tool_id):
		return GameResult.fail("Wrong tool")
	return GameResult.ok()
```

Why this is good:

- no `Node`,
- no scene tree,
- no rendering,
- easy to test.

### Portable Spatial Query

```gdscript
index.register_entity("resource:42", Vector2(100, 100), "resource", {"type": "berry_bush"})
var results := index.query_circle(Vector2(100, 100), 64.0, "resource")
```

Why this is good:

- entity id instead of node,
- explicit position,
- category as data,
- metadata is optional.

### Runtime Adapter

```gdscript
func register_resource_node(node: Node2D) -> void:
	var entity_id := node.get_instance_id()
	var metadata := {
		"type": node.resource_kind,
		"payload": node
	}
	spatial_index.register_entity(entity_id, node.global_position, "resource", metadata)
```

Why this is acceptable:

- Node usage is isolated in adapter,
- core remains data-only.

## Bad API Examples

### Bad: Core Depends on Node

```gdscript
func update_creature(creature: Node2D) -> void:
	creature.global_position += Vector2.RIGHT
```

Problem:

- requires a scene node,
- cannot be tested as portable logic,
- mixes movement rules and runtime object mutation.

### Bad: Core Reads Scene Tree

```gdscript
func find_food() -> Array:
	return get_tree().get_nodes_in_group("food")
```

Problem:

- depends on SceneTree,
- hard to test,
- hidden global dependency.

### Bad: Gameplay Depends on Rendering

```gdscript
func is_water_at_position(position: Vector2) -> bool:
	return terrain_texture.get_pixelv(position) == WATER_COLOR
```

Problem:

- gameplay rule depends on texture representation,
- rendering changes could break gameplay,
- not portable.

### Bad: Debug System Mutates Gameplay

```gdscript
func update_debug_panel() -> void:
	world.spawn_extra_creatures()
```

Problem:

- debug code changes gameplay,
- benchmark/debug behavior may affect the actual game.

## Migration Priorities

### Priority 1: Stabilize Data Boundaries

- world generation result,
- world generation summary/hash,
- world generation validator,
- spatial index,
- core common data types.

### Priority 2: Extract Player-Independent Rules

- hunger/diet rules,
- resource regrowth rules,
- creature decision helpers,
- crafting validation,
- inventory operations.

### Priority 3: Extract Save/Load Schemas

- save snapshot data,
- save validation,
- generation summary/hash comparison,
- migration helpers.

### Priority 4: Extract Runtime Adapters

- resource node adapter,
- creature node adapter,
- building node adapter,
- world generation runtime adapter,
- save/load runtime adapter.

### Priority 5: Separate Rendering

- terrain rendering,
- biome texture rendering,
- minimap rendering,
- map screen rendering,
- decorative vegetation rendering,
- HUD presentation.

## Definition of Done for a Portable Module

A module can be considered portable when:

- it is under `scripts/core/`,
- it extends `RefCounted` or is a pure static helper,
- it does not require `Node`,
- it does not require `SceneTree`,
- it does not instantiate scenes,
- it does not access rendering nodes/textures,
- it can be tested from unit tests,
- it accepts data inputs,
- it returns data outputs,
- runtime Node references are optional metadata only,
- existing gameplay behavior remains unchanged.

## Final Rule

Modularization is a gradual extraction process.

The goal is not to make the code look perfect immediately.

The goal is to reduce risk while slowly moving gameplay rules into portable, testable modules.

Every step should preserve the current game.
