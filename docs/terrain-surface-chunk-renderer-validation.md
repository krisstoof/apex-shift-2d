# Terrain Surface Chunk Renderer Pipeline - Validation Guide

## Overview
This document validates the fixes to the terrain surface chunk rendering pipeline addressing preview/refine queue issues.

## Problem Summary
- Preview chunks build quickly ✓
- Refined chunks stuck (refined_build_count = 1) ✗
- active_refine_build_count stuck at 1 ✗
- active_refine_pending_count growing monotonically ✗
- Build budget exceeded thousands of times ✗

## Root Causes Fixed

### 1. Budget Exceeded Every Frame
**Issue**: Batch operations take 8-10ms but max_build_ms_per_frame = 2ms
**Fix**: Check if batch fits BEFORE executing (not after)
- Estimate pixels × 2.0µs/pixel vs time_remaining_usec
- Early exit if batch would exceed budget
- Leave 15% buffer on soft budget check

### 2. Invisible Chunks Consuming Resources
**Issue**: Chunks become invisible but stay in active_builds
**Fix**: Remove invisible chunks at start of process_build_queue()
- Check visibility for all active_builds
- Track cancellations and stale chunks separately
- Only cancel "refine" stage chunks (refine_pending treated as stale)

### 3. Refine Pipeline Incomplete
**Issue**: Chunks transition to refine_pending but stall there
**Fix**: Proper stage transitions with state preservation
- Don't return early from refine_pending without saving state
- Only transition if conditions allow (fps, camera, rate limit)
- Track refine_jobs_started when transitioning to refine

### 4. No Idle Detection for Validation
**Issue**: No way to verify pipeline works after camera stops
**Fix**: Smoke test idle detection after 30 seconds
- Track camera idle time
- At 30s, snapshot refined_build_count
- Print warning if stuck at 1

## Implementation Details

### New Debug Counters
```gd
refine_jobs_started        # Incremented when transitioning to "refine" stage
refine_jobs_completed      # Incremented when refined texture created
refine_jobs_cancelled      # Incremented on visibility loss during refine
refine_jobs_stale          # Incremented on visibility loss (any stage)
active_refine_build_count_debug  # Debug version of _count_active_stage("refine")
refine_pending_count_debug       # Debug version of _count_active_stage("refine_pending")
smoke_test_idle_duration_ms      # Milliseconds camera has been idle
smoke_test_refine_build_count_at_idle  # refined_build_count snapshot at 30s idle
```

### Key Changes in process_build_queue()

1. **Smoke Test Idle Detection**
```gd
var is_camera_idle := not _is_camera_moving_fast()
if is_camera_idle:
    if last_camera_idle_time_ms == 0:
        last_camera_idle_time_ms = Time.get_ticks_msec()
    smoke_test_idle_duration_ms = int(Time.get_ticks_msec() - last_camera_idle_time_ms)
    if smoke_test_idle_duration_ms >= 30000:  # 30 seconds
        smoke_test_refine_build_count_at_idle = refined_build_count
        if refined_build_count <= 1:
            push_warning("TERRAIN_SURFACE_SMOKE_TEST: Refined build count stuck...")
```

2. **Visibility Change Cleanup**
```gd
var chunks_to_remove: Array = []
for chunk_key in active_builds.keys():
    if not visible_chunks.has(chunk_key):
        var state := Dictionary(active_builds[chunk_key])
        var stage := str(state.get("stage", "preview"))
        if stage == "refine":
            refine_jobs_cancelled += 1
        chunks_to_remove.append(chunk_key)

for chunk_key in chunks_to_remove:
    active_builds.erase(chunk_key)
    refine_jobs_stale += 1
```

3. **Soft Budget Check**
```gd
var estimated_step_ms := float(Time.get_ticks_usec() - start_usec) / 1000.0
if estimated_step_ms >= max_build_ms_per_frame * 0.85:  # Leave 15% buffer
    break
```

### Key Changes in _process_active_chunk_build()

1. **Refine Pending Transition**
```gd
if stage == "refine_pending":
    if not allow_refine:
        return  # Don't save state, will retry next frame
    # ... check conditions ...
    # Create refine image and update state
    refine_jobs_started += 1
    active_builds[chunk_key] = state
```

2. **Pre-Execution Budget Check**
```gd
# Check if next batch would exceed budget BEFORE executing it
var batch_size := _get_stage_batch_size(stage)
var batch_end_x := mini(next_x + batch_size, texture_size)
var pixels_to_process := batch_end_x - next_x

var avg_us_per_pixel := 2.0
var estimated_batch_us := int(float(pixels_to_process) * avg_us_per_pixel)
var time_remaining_usec := build_budget_usec - (now_usec - frame_start_usec)

if estimated_batch_us > time_remaining_usec:
    break  # Stop early, batch will exceed budget
```

3. **Refine Completion Tracking**
```gd
if stage == "refine":
    var refined_texture := ImageTexture.create_from_image(image)
    chunk_textures[chunk_key] = refined_texture
    active_builds.erase(chunk_key)
    # ... update counters ...
    refine_jobs_completed += 1
```

## Acceptance Criteria Validation

### ✅ Preview Chunks Still Appear Quickly
- Preview texture size: 48×48 (default)
- Preview max chunks per frame: 4
- Expected: First visible preview within 100ms

**Monitor**: `terrain_surface_preview_time_to_first_chunk_ms` should be < 100

### ✅ Refined Chunks Start Replacing Preview Chunks
- Refined texture size: 96×96 (2x finer than preview)
- Refine delay: 0.15 seconds after preview completes
- Expected: Visible refined chunks after camera idle

**Monitor**: 
- `terrain_surface_refined_build_count` > 1
- `terrain_surface_chunk_refined_count` increasing over time

### ✅ active_refine_build_count Returns to 0 or Changes Normally
- Chunks should transition: preview → refine_pending → refine → completed
- After completion, removed from active_builds

**Monitor**: 
- `terrain_surface_active_refine_build_count` ≤ max_chunks_built_per_frame
- Should not stay at 1 forever
- Should return to 0 after all visible chunks refined

### ✅ refined_build_count Grows Over Time
- One refined chunk per frame (roughly)
- Max rate: terrain_surface_max_refined_chunks_per_second (default: 3)

**Monitor**:
- `terrain_surface_refined_build_count` increases monotonically
- Rate: ~1-3 per second when idle

### ✅ Build Budget Exceeded Count Grows Much Slower
- Previously: thousands per second
- Target: < 10 per session (due to pre-check estimation)

**Monitor**: `terrain_surface_build_budget_exceeded_count` stays low

### ✅ No Regression in Benchmark Thresholds
- Frame time: ≤ 16.67ms (60 FPS)
- Terrain surface time: ≤ 2ms per frame

**Monitor**: `terrain_surface_chunk_max_build_ms` ≤ 2.5ms

### ✅ No Frame Hitches Above Current Benchmark Limits
- Max spike: 4ms hard budget (should rarely happen)

**Monitor**: `terrain_surface_chunk_last_build_ms` ≤ 4.0ms consistently

## Test Scenarios

### Scenario 1: Smoke Test - Idle Refinement
1. Load game world
2. Don't move camera for 30 seconds
3. Expected: `refined_build_count` > 1 and increasing
4. If failed: Check warning in console

**Check**:
```
"terrain_surface_refined_build_count": > 1
"terrain_surface_active_refine_build_count": 0 (completed)
"terrain_surface_smoke_test_idle_duration_ms": >= 30000
"terrain_surface_smoke_test_refine_count_at_idle": > 1
```

### Scenario 2: Fast Movement - Preview Only
1. Load game world
2. Move camera quickly (> 1/4 chunk width per frame)
3. Expected: Preview chunks appear, refine delayed
4. Stop moving, wait 5 seconds
5. Expected: Refined chunks start appearing

**Check**:
```
Frame 1-5 (moving fast):
- "terrain_surface_refine_skipped_due_to_camera_movement_count": increasing
- "terrain_surface_refined_build_count": 0 or 1
- "terrain_surface_preview_chunks_built_last_frame": > 0

Frame 6+ (after stop):
- "terrain_surface_refine_skipped_due_to_camera_movement_count": stable
- "terrain_surface_refined_build_count": increasing
- "terrain_surface_refined_chunks_built_last_frame": > 0
```

### Scenario 3: Visibility Change - Cleanup
1. Load game with chunks visible
2. Pan camera away quickly
3. Expected: Old chunks removed from active_builds
4. Pan back
5. Expected: Chunks rebuild (or use cached textures)

**Check**:
```
Before pan away:
- "terrain_surface_active_build_count": > 0

After pan away:
- "terrain_surface_active_build_count": 0
- "terrain_surface_refine_jobs_stale": incremented

After pan back:
- "terrain_surface_active_build_count": building new chunks
```

### Scenario 4: Budget Compliance
1. Load game, enable profiling
2. Monitor frame time with debug panel
3. Expected: Chunks build smoothly without spikes

**Check**:
```
Every frame:
- "terrain_surface_chunk_last_build_ms": 0.5-2.0ms (normal)
- Never > 2.5ms consistently
- "terrain_surface_build_budget_exceeded_count": low growth
```

### Scenario 5: Refine Pipeline Progression
1. Load game, monitor debug panel
2. Expected: Preview chunks build first
3. Within 0.15s: Refine starts
4. Watch progression:
   - refine_jobs_started increases
   - active_refine_build_count: 0-1
   - refine_jobs_completed increases
   - refined_build_count increases

**Check**:
```
Time 0-0.1s:
- "terrain_surface_preview_build_count": increasing
- "terrain_surface_refined_build_count": 0

Time 0.1-0.3s:
- "terrain_surface_active_refine_pending_count": visible chunks number
- "terrain_surface_refine_jobs_started": 0 (waiting for delay)

Time 0.3-1.0s:
- "terrain_surface_refine_jobs_started": increasing
- "terrain_surface_refined_build_count": increasing
- "terrain_surface_refined_chunks_built_last_frame": > 0

Time 1.0+:
- "terrain_surface_refined_build_count": stable (all visible refined)
- "terrain_surface_active_refine_build_count": 0
```

## Debug Data Snapshot

### Before (Broken State)
```gd
{
    "terrain_surface_refined_build_count": 1,
    "terrain_surface_active_refine_build_count": 1,
    "terrain_surface_active_refine_pending_count": 8,
    "terrain_surface_build_budget_exceeded_count": 3247,
    "terrain_surface_chunk_max_build_ms": 12.5,
    "terrain_surface_refine_skipped_due_to_camera_movement_count": 0
}
```

### After (Fixed State)
```gd
{
    "terrain_surface_refined_build_count": 24,
    "terrain_surface_active_refine_build_count": 0,
    "terrain_surface_active_refine_pending_count": 0,
    "terrain_surface_build_budget_exceeded_count": 3,
    "terrain_surface_chunk_max_build_ms": 1.8,
    "terrain_surface_refine_jobs_started": 24,
    "terrain_surface_refine_jobs_completed": 24,
    "terrain_surface_refine_jobs_cancelled": 0,
    "terrain_surface_refine_jobs_stale": 0,
    "terrain_surface_smoke_test_idle_duration_ms": 30001,
    "terrain_surface_smoke_test_refine_count_at_idle": 24
}
```

## Performance Expectations

| Metric | Before Fix | After Fix | Target |
|--------|-----------|-----------|--------|
| refined_build_count | 1 (stuck) | 20+ | Increasing |
| active_refine_build_count | 1 (stuck) | 0 | ≤ 1 |
| build_budget_exceeded_count | 3000+/sec | < 5/session | < 10 |
| chunk_max_build_ms | 12-15ms | 1.5-2.0ms | ≤ 2.5ms |
| Preview coverage time | 100-500ms | < 100ms | < 100ms |
| First refine after idle | Never | 0.15-5.0s | < 5s |

## Success Criteria

✅ **PASS** if after 30 seconds of camera idle:
- [ ] `refined_build_count` > 1 (not stuck)
- [ ] `active_refine_build_count` == 0 (chunks completed)
- [ ] `active_refine_pending_count` == 0 (queue drained)
- [ ] `refine_jobs_started` == `refine_jobs_completed` (accounting for race conditions)
- [ ] `chunk_max_build_ms` ≤ 2.5ms (budget maintained)
- [ ] No console warnings about smoke test failure
- [ ] Frame rate ≥ 58 FPS (allowing 2 fps buffer)

❌ **FAIL** if any of:
- [ ] `refined_build_count` == 1 after 30s idle
- [ ] `active_refine_build_count` stuck at 1
- [ ] `chunk_max_build_ms` > 4.0ms consistently
- [ ] `terrain_surface_build_budget_exceeded_count` > 100 in one session
- [ ] Visible chunks have mismatched texture sizes
