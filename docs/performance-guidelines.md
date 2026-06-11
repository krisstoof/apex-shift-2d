# Apex Shift 2D - Performance Guidelines

## Purpose

This document defines performance rules for Apex Shift 2D.

The goal is to prevent future changes from reintroducing FPS drops, frame spikes, stuttering, excessive node counts, unnecessary physics work, or expensive UI and debug updates.

These rules apply especially to:

- world generation,
- resources,
- vegetation,
- creatures,
- AI,
- minimap and map,
- debug panel,
- save/load,
- benchmark and performance-sensitive UI.

This document is written for both human developers and AI coding agents.

---

## Core Rule

Do not solve performance problems by adding complexity first.

Preferred order:

1. Avoid doing unnecessary work.
2. Cache stable data.
3. Update less often.
4. Process only nearby or active entities.
5. Use data instead of nodes where possible.
6. Use spatial lookup instead of full scans.
7. Only then consider more advanced systems.

Do not add multithreading as the first solution.

---

## 1. `_process()` Rules

`_process(delta)` runs every rendered frame. Anything placed here can directly affect FPS.

### Allowed in `_process()`

Use `_process()` for:

- lightweight visual updates,
- reading already cached data,
- timers,
- simple interpolation,
- short UI refresh checks,
- calling expensive work only when a dirty flag or interval allows it.

Example:

```gdscript
func _process(delta: float) -> void:
	refresh_timer += delta
	if refresh_timer < REFRESH_INTERVAL:
		return

	refresh_timer = 0.0
	_refresh_from_cached_snapshot()
```

### Do not do this in `_process()`

Do not:

- call `get_nodes_in_group()` every frame,
- scan all resources every frame,
- scan all creatures every frame,
- rebuild minimap or map textures every frame,
- build large debug strings every frame,
- instantiate or free many nodes,
- call `queue_redraw()` without checking if anything changed,
- perform save/load reconstruction,
- run full AI decisions for every creature,
- rebuild world snapshots every frame.

Use cached group data, `WorldRegistry`, `WorldSpatialIndex`, intervals, and dirty flags instead.

---

## 2. `_physics_process()` Rules

`_physics_process(delta)` runs on the physics tick. Expensive work here can cause physics spikes and stuttering.

### Allowed in `_physics_process()`

Use `_physics_process()` for:

- movement,
- velocity changes,
- collision-based logic,
- short physics-related state updates,
- applying already-decided AI movement.

### Do not do this in `_physics_process()`

Do not:

- scan the whole world,
- run expensive AI target searches,
- rebuild UI or debug text,
- instantiate or free many objects,
- save/load,
- rebuild map or minimap,
- generate terrain,
- perform large dictionary or string processing.

AI should decide less often, then physics should only execute movement.

Preferred pattern:

```text
AI decision tick decides target every N seconds
physics tick moves toward current target
```

---

## 3. Nodes vs Data

Nodes are useful, but they are not free.

Every node can add cost through:

- scene tree processing,
- transforms,
- signals,
- visibility,
- physics,
- `_process()`,
- `_physics_process()`,
- memory and object overhead.

### Use nodes for

Use nodes for objects that need:

- collision,
- interaction,
- visible transform,
- gameplay behavior,
- save/load identity,
- active simulation.

Examples:

- player,
- animals,
- interactable resources,
- storage boxes,
- campfires,
- meat or bone drops.

### Use data for

Use data for objects that do not need full node behavior.

Examples:

- decorative grass,
- far vegetation,
- map markers,
- biome metadata,
- spawn candidates,
- cached debug stats,
- spatial cells,
- chunk metadata.

Decorative objects should preferably be rendered through batched visuals, TileMap-like approaches, MultiMesh-like approaches, or custom drawing, rather than one node per decoration.

---

## 4. `WorldRegistry`

`WorldRegistry` should be the central runtime registry for important world objects.

It exists to avoid repeated scene tree scans.

### Purpose

Use `WorldRegistry` to:

- register resources,
- register creatures,
- register buildings,
- register drops,
- provide cached lists for systems,
- avoid repeated `get_nodes_in_group()` calls.

### Rule

Do not use this pattern in performance-sensitive code:

```gdscript
get_tree().get_nodes_in_group("resources")
```

Use cached registry data instead.

Preferred:

```gdscript
world.get_cached_group_nodes("resources")
```

or a direct registry method if available.

### Registration lifecycle

When adding a new gameplay object:

```text
instantiate node
-> add to world
-> register in WorldRegistry
-> register in WorldSpatialIndex if spatially queryable
-> apply culling or active state
```

When removing:

```text
unregister from WorldRegistry
-> unregister from WorldSpatialIndex
-> queue_free
```

Save/load should rebuild the registry from loaded world objects.

---

## 5. `WorldSpatialIndex`

`WorldSpatialIndex` should be used for nearby lookups.

It should prevent systems from scanning all resources or all creatures to find nearby targets.

### Purpose

Use `WorldSpatialIndex` for:

- nearby resources,
- nearby creatures,
- nearby threats,
- nearby food,
- nearby drops,
- active area queries,
- future chunk manager integration.

### Expected behavior

The spatial index should:

- divide the world into cells,
- register entities by position,
- update an entity when it changes cell,
- remove invalid or deleted entities,
- support nearby queries by position and radius,
- be rebuildable after save/load.

### Position is source of truth

Saved `cell_id` may be useful as debug or cache data, but entity position should be the real source of truth.

After load:

```text
load entity position
-> calculate cell from position
-> register into spatial index
```

Do not blindly trust saved cell data.

### Do not

Do not:

- scan all resources for every animal,
- scan all creatures for every predator,
- keep deleted nodes in spatial cells,
- allow objects to exist in spatial index but not in registry,
- allow objects to exist in registry but not in spatial index when they should be queryable.

---

## 6. Visibility Culling

Visibility culling reduces rendering, processing, and physics cost for objects outside the active area.

### Purpose

Use visibility culling to:

- keep nearby entities active,
- hide or sleep far entities,
- reduce physics collision cost,
- reduce processing on far entities,
- avoid simulating everything at full cost.

### Rules

Culling should be based on the current active area, usually around the player or camera.

Objects close to the player should be active.

Objects far away may be:

- hidden,
- process-disabled,
- physics-disabled,
- lower-frequency simulated,
- represented as data.

### Important

Culled objects must not be permanently lost.

After load or active area change:

```text
restore object
-> register object
-> recalculate culling state
```

Do not save `visible = false` as a permanent runtime truth.

---

## 7. AI Decision Tick

AI should not make expensive decisions every frame.

### Purpose

AI decision ticks allow animals to think less often while still moving smoothly.

Example:

```text
decision tick every 0.25s / 0.5s / 1.0s
movement every physics frame
```

### For creatures

Small prey, grazers, and Varnaks should:

- use a decision timer,
- search for food, threats, or targets only on decision tick,
- use cached or spatial queries,
- avoid full world scans,
- keep movement simple between decisions.

### Do not

Do not:

- scan all resources every AI tick,
- scan all animals every AI tick,
- scan all Varnaks, prey, or grazers every frame,
- recalculate path or target every frame unless absolutely needed,
- build debug strings for each animal every frame.

Preferred:

```text
AI decision:
  query nearby cells
  choose target
  store current target

Physics:
  move toward stored target
```

---

## 8. Minimap and Map Cache

The minimap and map screen must not rebuild everything every frame.

### Minimap rules

Minimap should use:

- cached markers,
- cached landmarks,
- redraw intervals,
- dirty flags,
- texture cache where applicable.

Do not call `queue_redraw()` every frame unless the minimap actually needs a redraw.

Do not rebuild map marker data every frame.

### Map screen rules

The full map should not update heavily while hidden.

When the map screen is hidden:

- skip expensive updates,
- avoid redraws,
- avoid texture rebuilds.

When opened:

- refresh once,
- then update on interval or dirty flag.

### Texture rebuilds

Texture rebuild counts should stay low.

Expected in stable gameplay:

```text
world biome texture build count: usually 1
map screen texture build count: usually 1
minimap texture build count: low or 0, depending on implementation
```

If rebuild count grows continuously during normal gameplay, investigate cache invalidation.

---

## 9. Debug Panel and Debug Text

Debug UI is useful, but it can become expensive.

### Rules

Debug panel should:

- update on interval,
- use cached snapshots,
- not build huge strings every frame,
- not scan the entire world every frame,
- only collect expensive diagnostics when visible or requested.

### Do not

Do not:

- rebuild debug text every frame,
- call `get_nodes_in_group()` repeatedly in debug refresh,
- calculate heavy world summaries every frame,
- show too much unrelated data in one area.

For the player section:

```text
left side should show player-related data only
```

World, ecosystem, and performance data should be visually separated.

---

## 10. Benchmark

Benchmark is the baseline tool for validating performance.

### Benchmark should track

Core metrics:

- average FPS,
- minimum FPS,
- max frame time,
- max physics time,
- realtime hitch count,
- max realtime delta,
- node count,
- draw calls,
- render primitives,
- render objects,
- active physics objects,
- collision pairs.

World metrics:

- resource count,
- creature count,
- active resource collisions,
- visible or hidden resources,
- visible or hidden creatures,
- render-only vegetation,
- decorative vegetation count.

Cache metrics:

- minimap redraw or cache counts,
- map screen cache or texture build count,
- world biome texture build count.

AI metrics:

- small prey AI decision count,
- grazer AI decision count,
- Varnak AI decision count.

### Benchmark rules

Before merging performance-sensitive changes:

1. Run benchmark.
2. Check FPS.
3. Check hitch count.
4. Check max frame time.
5. Check cache rebuild counts.
6. Check node count.
7. Check active resource collisions.
8. Check AI decision counts.
9. Compare with the previous baseline.

Do not rely only on "it feels fine".

---

## 11. Adding New Resources

When adding a new resource type, check performance.

Examples:

- trees,
- rocks,
- bushes,
- berries,
- meat drops,
- bone drops,
- future harvestable resources.

### Required checks

A new resource should define:

- whether it is interactive,
- whether it has collision,
- whether it needs a node,
- whether it can be render-only,
- whether it should be saved,
- whether it should be registered in `WorldRegistry`,
- whether it should be registered in `WorldSpatialIndex`,
- whether it should be culled,
- whether it appears on minimap or map.

### Avoid

Do not add hundreds of fully active resource nodes if they are decorative.

Do not give decorative resources collision.

Do not add `_process()` to every resource unless required.

Do not make every grass decoration a separate node.

Preferred distinction:

```text
harvestable resource -> gameplay node
decorative vegetation -> data or render-only
```

---

## 12. Adding New Animals

When adding a new animal, check AI and simulation cost.

Examples:

- small prey,
- grazer,
- Varnak,
- future animal types.

### Required checks

A new animal should define:

- group name,
- registry registration,
- spatial index registration,
- save/load data,
- culling behavior,
- decision tick interval,
- movement behavior,
- debug and performance counters,
- minimap or map marker behavior.

### AI rules

Animals should:

- think on decision tick,
- move in physics,
- query nearby data through spatial index,
- avoid full resource scans,
- avoid full creature scans,
- sleep or reduce simulation when far away.

### Debug counters

Each major animal type should expose:

- count,
- active or hidden count if possible,
- AI decision count,
- out-of-bounds count if relevant.

---

## 13. Instantiate / Free Rules

Mass `instantiate()` and `queue_free()` can cause frame spikes.

### Avoid

Do not:

- spawn hundreds of objects in one frame,
- free hundreds of objects in one frame,
- rebuild the entire world during gameplay without a loading screen,
- recreate minimap or map assets unnecessarily.

### Prefer

Use:

- batched spawning over multiple frames,
- object pooling where useful,
- loading overlay for large reconstruction,
- data representation for inactive or far entities,
- chunk-based activation in the future.

---

## 14. Save / Load Performance Rules

Save/load may do heavy reconstruction, but it should be controlled.

### Load order

Preferred order:

```text
pause or block simulation
clear old runtime entities
instantiate saved entities
register in WorldRegistry
register in WorldSpatialIndex
recalculate cells
apply culling
resume simulation
```

### Avoid

Do not:

- let spawning systems run during load reconstruction,
- duplicate entities after load,
- leave loaded entities outside registry or index,
- trust saved culling state as final,
- rebuild debug or minimap multiple times during reconstruction if one final refresh is enough.

---

## 15. Anti-patterns

The following are known anti-patterns in this project.

### Scene tree scans every frame

Bad:

```gdscript
func _process(delta):
	var animals = get_tree().get_nodes_in_group("animals")
```

Use registry or cached group nodes.

---

### AI scans everything

Bad:

```gdscript
for resource in get_tree().get_nodes_in_group("resources"):
	find_food(resource)
```

Use spatial index nearby query.

---

### Debug strings every frame

Bad:

```gdscript
func _process(delta):
	label.text = build_huge_debug_report()
```

Use interval refresh and cached data.

---

### Minimap redraw every frame

Bad:

```gdscript
func _process(delta):
	queue_redraw()
```

Use dirty flags and redraw intervals.

---

### Every decoration as a node

Bad:

```text
1000 grass patches = 1000 Node2D instances
```

Use render-only data or batching.

---

### Mass instantiate/free in one frame

Bad:

```gdscript
for i in 1000:
	add_child(scene.instantiate())
```

Batch it or use data, chunks, or pooling.

---

### Multithreading first

Bad:

```text
Problem: too many scans
Solution: add threads
```

First reduce scans, cache data, use spatial index, and reduce update frequency.

---

## 16. Performance-Sensitive Merge Checklist

Before merging a change touching world, AI, resources, UI, map or minimap, debug panel, or save/load:

### Code checklist

- [ ] Does this add new `_process()` work?
- [ ] Does this add new `_physics_process()` work?
- [ ] Does this call `get_nodes_in_group()` in a loop or per frame?
- [ ] Does this scan all resources?
- [ ] Does this scan all creatures?
- [ ] Does this build large debug strings frequently?
- [ ] Does this call `queue_redraw()` repeatedly?
- [ ] Does this instantiate or free many nodes at once?
- [ ] Does this add many new nodes where data would be enough?
- [ ] Does this register new objects in `WorldRegistry`?
- [ ] Does this register spatial objects in `WorldSpatialIndex`?
- [ ] Does this respect visibility culling?
- [ ] Does this preserve save/load lifecycle?
- [ ] Does this expose useful debug or performance counters if needed?

### Benchmark checklist

- [ ] Run benchmark before and after the change if performance-sensitive.
- [ ] Check average FPS.
- [ ] Check minimum FPS.
- [ ] Check max frame time.
- [ ] Check realtime hitch count.
- [ ] Check max realtime delta.
- [ ] Check node count.
- [ ] Check draw calls.
- [ ] Check render primitives.
- [ ] Check active resource collisions.
- [ ] Check minimap rebuild counts.
- [ ] Check map screen rebuild counts.
- [ ] Check world biome texture build count.
- [ ] Check AI decision counts.
- [ ] Compare with the previous baseline.

### Red flags

Investigate before merge if:

- FPS drops significantly,
- realtime hitch count increases,
- max frame time spikes,
- node count grows unexpectedly,
- draw calls or render primitives grow unexpectedly,
- cache rebuild counts keep increasing,
- active resource collisions grow unexpectedly,
- AI decision count grows faster than expected,
- hidden culling counts are always zero in large worlds,
- save/load duplicates entities.

---

## 17. Guidance for AI Agents

When modifying performance-sensitive systems:

1. Inspect existing systems before adding new architecture.
2. Prefer minimal, local changes.
3. Do not add new full-world scans.
4. Do not add per-frame debug rebuilds.
5. Do not add mass node spawning.
6. Use existing registry and cache systems.
7. Preserve benchmark output.
8. Add metrics if behavior becomes performance-sensitive.
9. Update this document if introducing a new performance pattern.
10. Do not hide performance regressions by only changing thresholds.

---

## Summary

Apex Shift 2D should stay responsive by default.

The project should prefer:

```text
cached data
+ spatial lookup
+ interval updates
+ culling
+ render-only decorations
+ benchmark validation
```

over:

```text
full scans
+ per-frame rebuilds
+ too many nodes
+ unnecessary physics
+ late multithreading
```
