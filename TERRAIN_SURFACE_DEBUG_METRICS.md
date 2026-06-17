# Terrain Surface Debug Metrics Reference

## New Debug Counters (from get_debug_data())

### Refine Job Tracking
| Metric | Description | Expected | Issue if |
|--------|-------------|----------|----------|
| `terrain_surface_refine_jobs_started` | Chunks entering refine stage | Equals refined_build_count | < refined_build_count means stalls |
| `terrain_surface_refine_jobs_completed` | Completed refine jobs | Equals refined_build_count | < refined_build_count means incomplete |
| `terrain_surface_refine_jobs_cancelled` | Refine jobs cancelled (lost visibility) | 0 initially | > 0 after panning away (normal) |
| `terrain_surface_refine_jobs_stale` | Any chunks removed from active | Low | High = visibility thrashing |

### Active Build Counts
| Metric | Description | Expected | Issue if |
|--------|-------------|----------|----------|
| `terrain_surface_active_refine_count` | Chunks currently building refined | 0-1 | = 1 after 30s idle (stuck) |
| `terrain_surface_refine_pending_count` | Chunks waiting for refine delay | 0 when idle | > 0 and growing (stalled) |
| `terrain_surface_active_refine_build_count` | Legacy name for active_refine_count | 0 at idle | Stuck at 1 (OLD BUG) |
| `terrain_surface_active_refine_pending_count` | Legacy name for refine_pending_count | 0 at idle | Growing endlessly (OLD BUG) |

### Smoke Test Idle Detection
| Metric | Description | Expected | Issue if |
|--------|-------------|----------|----------|
| `terrain_surface_smoke_test_idle_duration_ms` | Milliseconds camera has been idle | Resets when moving | High number = idle detected |
| `terrain_surface_smoke_test_refine_count_at_idle` | refined_build_count snapshot at 30s idle | > 1 | = 1 means pipeline failed |

### Budget Compliance
| Metric | Description | Expected | Issue if |
|--------|-------------|----------|----------|
| `terrain_surface_build_budget_exceeded_count` | Times budget was exceeded | Low (< 5) | High (> 100) = constant overruns |
| `terrain_surface_chunk_max_build_ms` | Peak build time in one frame | 1.5-2.0ms | > 2.5ms consistently |
| `terrain_surface_chunk_last_build_ms` | Build time last frame | 0.5-2.0ms | > 3.0ms = spike |

### Build Progress
| Metric | Description | Expected | Issue if |
|--------|-------------|----------|----------|
| `terrain_surface_refined_build_count` | Total refined chunks created | Growing | Stuck at 1 (OLD BUG) |
| `terrain_surface_refined_chunks_built_last_frame` | Chunks refined last frame | 0-1 | 0 for many frames (stuck) |
| `terrain_surface_build_chunks_started_last_frame` | Chunks started building | 0-1 | > 1 = high load |
| `terrain_surface_build_chunks_completed_last_frame` | Chunks completed | 0-1 | 0 = stuck |

### Quality Checks
| Metric | Description | Expected | Issue if |
|--------|-------------|----------|----------|
| `terrain_surface_chunk_preview_count` | Chunks with preview texture | > 0 | 0 = no preview (bad) |
| `terrain_surface_chunk_refined_count` | Chunks with refined texture | Growing | Stuck at 0 = refine never happens |
| `terrain_surface_visible_chunks_without_texture` | Visible chunks missing texture | 0 (after preview) | > 0 = texture lost |

## Monitoring Strategy

### Continuous Monitoring (every frame)
```
Budget:
- chunk_last_build_ms < 2.5ms ✓
- build_budget_exceeded_count growing slowly ✓

Progress:
- preview_chunks_built_last_frame > 0 (first few frames) ✓
- refined_chunks_built_last_frame starts > 0 after 0.3s ✓

Visibility:
- visible_chunks_without_texture = 0 (after preview) ✓
- active_refine_pending_count > 0 but not growing ✓
```

### At 30-Second Idle
```
Expected state:
- smoke_test_idle_duration_ms >= 30000 ✓
- refined_build_count > 1 ✓
- active_refine_build_count = 0 ✓
- active_refine_pending_count = 0 ✓
- refine_jobs_completed == refined_build_count ✓
- chunk_max_build_ms <= 2.5ms ✓
```

### After Pan Away (visibility change)
```
Expected state:
- refine_jobs_stale > 0 ✓
- active_build_count = 0 ✓
- active_refine_build_count = 0 ✓
```

## Red Flags (Indicates Problems)

### 🚨 Critical Issues
- `refined_build_count == 1` after 30s idle → **Pipeline Stuck**
- `active_refine_build_count == 1` and `refine_jobs_started == 0` → **Never Started Refine**
- `chunk_max_build_ms > 4.0ms` consistently → **Budget Failing**

### ⚠️  Warnings
- `active_refine_pending_count > visible_chunk_count` → **Pending List Growing**
- `build_budget_exceeded_count > 50` in one session → **Constant Overruns**
- `refine_jobs_completed < refined_build_count` → **Jobs Not Finishing**
- `refine_jobs_stale > 50` in one frame → **Visibility Thrashing**

### ℹ️ Information
- `refine_jobs_cancelled > 0` after panning → **Normal (chunks left viewport)**
- `refine_skipped_due_to_camera_movement_count > 0` while moving → **Normal (preview mode)**
- `refine_skipped_due_to_fps_count > 0` when FPS < 45 → **Normal (rate limit)**

## Console Warnings

### Smoke Test Warning (Expected Once at 30s Idle if Bug)
```
TERRAIN_SURFACE_SMOKE_TEST: Refined build count stuck at 1 after 30s idle. Check refine pipeline.
```
**Meaning**: After 30 seconds of no camera movement, refined_build_count is still 1  
**Action**: Investigate refine_pending stage and _can_process_refine() conditions

## Performance Baselines

### Target Metrics (After Fix)
| Metric | Value | Unit |
|--------|-------|------|
| chunk_last_build_ms | 0.5-2.0 | ms |
| chunk_max_build_ms | < 2.5 | ms |
| build_budget_exceeded_count | < 5 | per session |
| refined_build_count at 30s idle | > 8 | chunks |
| active_refine_build_count at 30s idle | 0 | chunks |
| preview_time_to_first_chunk | < 100 | ms |
| preview_time_to_visible_coverage | < 500 | ms |

### Regression Detection
If any of these regress to pre-fix values, investigate:
- Refine transition logic (process_visibility timing)
- Budget estimation (avg_us_per_pixel = 2.0 might need tuning)
- Camera movement detection (threshold tuning)
- FPS rate limiting (refine_pause_when_fps_below)

## Quick Validation Checklist

Run this checklist every time you test:

- [ ] Load world, wait 5 seconds
  - `preview_build_count > 0` ✓
  - `refined_build_count > 1` ✓
  - `chunk_max_build_ms < 3.0ms` ✓

- [ ] Wait 30+ seconds without moving camera
  - `smoke_test_idle_duration_ms >= 30000` ✓
  - `refined_build_count >= 8` ✓
  - `active_refine_build_count == 0` ✓
  - No console warnings ✓

- [ ] Pan camera away quickly
  - `refine_jobs_stale > 0` ✓
  - `active_build_count → 0` ✓

- [ ] Pan camera back
  - Preview chunks rebuild ✓
  - Refined chunks rebuild starts ✓
  - No frame time spikes > 4ms ✓
