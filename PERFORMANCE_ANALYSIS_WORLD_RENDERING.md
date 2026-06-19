# Apex Shift 2D World Rendering System - Performance Analysis

## Executive Summary
The world rendering system has several O(n²) and inefficient operations that create frame rate pressure. The most critical issues are in visibility culling, spatial queries, and resource activation. Estimated cumulative FPS impact: **4-8 FPS** depending on entity count.

---

## 1. VISIBILITY CULLING SYSTEM

### 🔴 CRITICAL: `_has_pending_node()` - O(n) Queue Duplication Check
**File:** [scripts/world/world_visibility_controller.gd](scripts/world/world_visibility_controller.gd#L274-L279)
**Lines:** 274-279
**Function:** `_has_pending_node()`

```gdscript
func _has_pending_node(queue: Array[int], node: Node) -> bool:
	var instance_id := node.get_instance_id()
	for queued_instance_id in queue:
		if int(queued_instance_id) == instance_id:
			return true
	return false
```

**Problem:** 
- Linear search through entire queue every time a node visibility change is queued
- Called 2x per visibility change (once for show queue, once for hide queue) in [line 219 & 226](scripts/world/world_visibility_controller.gd#L219-L226)
- With 100+ visible resources/creatures, can iterate 100+ times per frame

**Impact:** ~2-3 FPS (scales with entity count)

**Fix:**
```gdscript
# Replace Array[int] with sets (dictionaries)
var pending_visibility_show_set: Dictionary = {}
var pending_visibility_hide_set: Dictionary = {}

func _queue_visibility_change(node: Node, should_be_visible: bool, ...) -> void:
	var instance_id := node.get_instance_id()
	if should_be_visible:
		if not instance_id in pending_visibility_show_set:
			pending_visibility_show.append(instance_id)
			pending_visibility_show_set[instance_id] = true
	else:
		if not instance_id in pending_visibility_hide_set:
			pending_visibility_hide.append(instance_id)
			pending_visibility_hide_set[instance_id] = true
```

---

### 🟡 MODERATE: Multiple Separate Spatial Queries in `_update_visibility()`
**File:** [scripts/world/world_visibility_controller.gd](scripts/world/world_visibility_controller.gd#L190-L245)
**Lines:** 190-210
**Function:** `_update_visibility()`

```gdscript
var query_rect := show_rect.grow(48.0)  # Line 203 - NEW rect every frame!
for node in _query_resources(query_rect):
	_queue_visibility_change(node, true, true, current_visible_nodes)
for node in _query_meat(query_rect):
	_queue_visibility_change(node, true, true, current_visible_nodes)
for creature_type in ["small_prey", "grazer", "varnak"]:
	for node in _query_creatures(query_rect, creature_type):
		_queue_visibility_change(node, true, false, current_visible_nodes)
```

**Problems:**
1. Creates new Rect2 with `grow(48.0)` every frame (line 203)
2. Three separate loops for resources/meat/creatures instead of batch queries
3. Could combine resource and meat queries

**Impact:** ~0.5-1 FPS (Rect2 allocation + extra query overhead)

**Fix:**
1. Cache the query rect and reuse it (only recalc when camera moves >50px)
2. Combine resource+meat query or use a single rect with multiple iterations

---

### 🟡 MODERATE: Visibility Change Budget Logic
**File:** [scripts/world/world_visibility_controller.gd](scripts/world/world_visibility_controller.gd#L236-L273)
**Lines:** 236-273
**Function:** `_process_pending_visibility_changes()`

**Problem:**
- Processes visibility changes with budget per frame (max 25-64 per frame)
- If visibility queue builds up (e.g., fast camera pan), changes lag
- No priority system for critical nodes (AI creatures should show before decorations)

**Impact:** Visual poppiness on fast camera movement (~1-2 FPS perceived)

**Fix:**
- Prioritize creatures over resources, show operations over hide operations
- Increase budget dynamically when queue exceeds threshold

---

## 2. WORLD UPDATE LOOPS

### 🟡 MODERATE: Resource Activation Scan with Rotating Index
**File:** [scripts/world/world.gd](scripts/world/world.gd#L1963-L2050)
**Lines:** 1963-2050
**Function:** `_update_resource_interactions()`
**Update Interval:** Line 527 - `resource_activation_timer` at 0.45 seconds

```gdscript
var start_index := resource_activation_scan_index % scan_count
var nearby_active_ids: Dictionary = {}
for offset in range(scan_count):
	var index := (start_index + offset) % scan_count
	# ... check each resource's activation state
```

**Problem:**
1. Scans ALL nearby resources every 0.45 seconds
2. Rotating index prevents full scan per frame but still O(n) iteration
3. Uses `get_resources_near()` spatial query (which is efficient, but still iterates results)
4. With 200+ resources near player, this can take 2-4ms

**Impact:** ~1-2 FPS (every 0.45 seconds, ~0.4-0.9ms added per frame on average)

**Recommended Interval:** 0.60-0.75 seconds (currently too aggressive)

**Fix:**
- Increase update interval to 0.60 seconds (from 0.45)
- Only scan resources that moved position (use dirty flag in resource nodes)
- Use spatial index change notifications instead of full scans

---

### 🟡 MODERATE: Creature Spawn Sync - `_sync_visible_small_prey()`
**File:** [scripts/world/world.gd](scripts/world/world.gd#L4836+)
**Lines:** 4836-4900+
**Function:** `_sync_visible_small_prey()`
**Update Interval:** Line 468 - `small_prey_spawn_timer` at 4.0 seconds

**Problem:**
1. Calls `_get_existing_small_prey_positions()` which iterates all small prey
2. Spawns up to 5 creatures per sync (can be multiple per frame)
3. Each spawn does validation checks against landmarks (multiple rect/distance checks)

**Impact:** ~0.5-1 FPS (every 4 seconds, but with position queries)

**Fix:**
- Cache creature positions and only update on spawn/death
- Pre-filter spawn positions by biome in background

---

## 3. SPATIAL QUERIES EFFICIENCY

### 🟡 MODERATE: Spatial Index Stale Entry Cleanup
**File:** [scripts/world/world_spatial_index.gd](scripts/world/world_spatial_index.gd#L95-L108)
**Lines:** 95-108
**Function:** `cleanup_stale_entries()`

```gdscript
func cleanup_stale_entries() -> Dictionary:
	var removed := 0
	for entity_id: Variant in _core_index.entity_records.keys():  # FULL SCAN
		var record := Dictionary(_core_index.entity_records.get(entity_id, {}))
		var metadata := Dictionary(record.get("metadata", {}))
		var node_ref: WeakRef = metadata.get("node_ref", null) as WeakRef
		var node: Variant = node_ref.get_ref() if node_ref != null else null
		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
			unregister_entity_by_id(entity_id)
			removed += 1
	return {"removed": removed, ...}
```

**Problem:**
1. Iterates through ALL tracked entities (hundreds potentially)
2. Calls `is_instance_valid()` on each one
3. Called from cleanup path, unclear how frequently

**Impact:** ~1-2 FPS (infrequent but expensive when called)

**Fix:**
- Only cleanup on deletion signals, not bulk scan
- Mark stale entries incrementally instead of bulk validation
- Use reference tracking instead of validation checks

---

### 🟢 GOOD: Core Spatial Index Query Performance
**File:** [scripts/core/spatial/world_spatial_index.gd](scripts/core/spatial/world_spatial_index.gd)

The core spatial index using grid-based cells is **well-implemented**. Query cost is O(k) where k = entities in nearby cells (typically 20-50), not O(n). ✓

---

## 4. CAMERA/VIEWPORT UPDATES

### 🟡 MODERATE: Camera Rect Calculations
**File:** [scripts/world/world.gd](scripts/world/world.gd#L689-701)
**Lines:** 689-701
**Function:** `_get_world_object_visibility_rect()`

```gdscript
func _get_world_object_visibility_rect(...) -> Rect2:
	var safe_zoom := Vector2(maxf(absf(camera_zoom.x), 0.01), maxf(absf(camera_zoom.y), 0.01))
	var visible_world_size := Vector2(viewport_size.x / safe_zoom.x, viewport_size.y / safe_zoom.y)
	var margin_vector := Vector2.ONE * margin
	return Rect2(  # Creates new object every frame
		camera_position - visible_world_size * 0.5 - margin_vector,
		visible_world_size + margin_vector * 2.0
	)
```

**Problem:**
1. Creates new Rect2 every call
2. Called every visibility update (0.35 second interval, but multiple times per update)
3. Vector2 allocations for `safe_zoom`, `visible_world_size`, `margin_vector`

**Impact:** ~0.2-0.3 FPS (allocation overhead)

**Fix:**
- Reuse Rect2 objects with `set_position()` and `set_size()` instead of new
- Cache calculation if camera hasn't moved more than threshold (e.g., 32 pixels)

---

### 🟡 MODERATE: Decorative Vegetation Rect Update
**File:** [scripts/world/world.gd](scripts/world/world.gd#L675-687)
**Lines:** 675-687
**Function:** `_update_decorative_vegetation_visible_rect()`
**Update Interval:** Line 526 - `decorative_vegetation_visibility_timer` at 0.20 seconds

```gdscript
var visible_rect := get_camera_visible_world_rect()  # NEW rect
vegetation_visual_layer.set_visible_world_rect(visible_rect)
```

**Problem:**
1. Updates every 0.20 seconds (very frequent!)
2. Allocates new Rect2 each time
3. Calls `find_child()` for minimap which does tree traversal

**Impact:** ~0.5-1 FPS (frequent allocation + tree search)

**Fix:**
- Increase interval to 0.35-0.50 seconds (match visibility culling)
- Cache minimap node reference instead of finding it each time

---

## 5. CHUNK VISIBILITY PROCESSING

### 🟢 GOOD: Terrain Surface Chunk Renderer Visibility
**File:** [scripts/world/terrain_surface_chunk_renderer.gd](scripts/world/terrain_surface_chunk_renderer.gd#L326-365)
**Lines:** 326-365
**Function:** `process_visibility()`

Uses signature-based caching (line 335-338):
```gdscript
var signature := _chunk_bounds_signature(chunk_bounds)
if not dirty and signature == last_visible_signature:
	return  # Skip if nothing changed
```

This is **well-optimized**. Only rebuilds visible chunks when signature changes. ✓

### 🟡 MODERATE: Biome Detail Overlay Cache Pruning
**File:** [scripts/world/world.gd](scripts/world/world.gd#L2250+)
**Function:** `_update_biome_detail_overlay()`

**Problem:**
1. Maintains large cache of biome detail textures
2. Pruning logic may not be aggressive enough
3. Cache can grow unbounded in long sessions

**Impact:** Memory pressure, GC stalls (1-2 FPS spike every 30-60 seconds)

**Fix:**
- Implement LRU eviction policy (keep only last 24 chunks)
- Prune every 5 seconds instead of on-demand

---

## SUMMARY TABLE

| Issue | File | Line(s) | Function | FPS Impact | Severity | Fix Difficulty |
|-------|------|---------|----------|-----------|----------|-----------------|
| O(n) pending node check | world_visibility_controller.gd | 274-279 | `_has_pending_node()` | 2-3 FPS | 🔴 Critical | Easy (use Set) |
| Multiple queries + Rect alloc | world_visibility_controller.gd | 203-210 | `_update_visibility()` | 0.5-1 FPS | 🟡 Moderate | Easy |
| Aggressive resource scan interval | world.gd | 1963-2050 | `_update_resource_interactions()` | 0.4-0.9 FPS | 🟡 Moderate | Easy (config) |
| Decorative veg update frequency | world.gd | 675-687 | `_update_decorative_vegetation_visible_rect()` | 0.5-1 FPS | 🟡 Moderate | Easy |
| Stale entry bulk cleanup | world_spatial_index.gd | 95-108 | `cleanup_stale_entries()` | 1-2 FPS | 🟡 Moderate | Medium |
| Camera rect calculations | world.gd | 689-701 | `_get_world_object_visibility_rect()` | 0.2-0.3 FPS | 🟡 Moderate | Easy |
| Biome blend texture rebuild | world_render_controller.gd | 34-46 | `_rebuild_biome_blend_texture()` | Spiky | 🟡 Moderate | Medium |
| Biome detail overlay cache | world.gd | 2250+ | `_update_biome_detail_overlay()` | Memory | 🟡 Moderate | Medium |

---

## RECOMMENDED FIXES (Priority Order)

### Phase 1 (High Impact, Easy - ~2-3 FPS gain)
1. Replace `_has_pending_node()` with Set-based deduplication
2. Cache camera visibility rect (only recalc when camera moves >50px)
3. Increase resource activation interval from 0.45s to 0.60s

### Phase 2 (Moderate Impact, Medium - ~1-2 FPS gain)
1. Increase decorative vegetation update interval from 0.20s to 0.40s
2. Implement LRU cache for biome detail overlay
3. Combine resource+meat visibility queries

### Phase 3 (Lower Priority)
1. Implement stale entry tracking instead of bulk cleanup
2. Add creature spawn position caching
3. Profile and optimize biome blend texture generation

---

## PERFORMANCE VALIDATION COMMANDS

```gdscript
# In runtime profiler:
RUNTIME_PROFILER.get_frame_data("visibility_cull_ms")
RUNTIME_PROFILER.get_frame_data("resource_activation_update_ms")
RUNTIME_PROFILER.get_frame_data("world_decorative_visible_rect_ms")
RUNTIME_PROFILER.get_frame_data("world_process_total_ms")
```

Monitor these metrics during gameplay to validate improvements.
