# Performance Benchmark Checklist

Use this checklist for every performance-focused PR so results are compared with the same benchmark scenario and recorded in a repeatable way.

## Goal

- Measure the same 60 s benchmark before and after the change.
- Record the same metrics every time.
- Avoid judging performance changes "by eye".
- Keep a short baseline note for the known old rendering problem so regressions are easier to spot.

## Benchmark Scenario

- Run the 60 s benchmark in the normal game scene.
- Keep the same branch, seed, and gameplay conditions for the before/after comparison.
- Do not rely on one-off manual observation.
- Capture the benchmark output from the same machine when possible.

## Metrics To Record

Write down these values for both the before and after run:

- `average_fps`
- `min_fps`
- `max_frame_time_ms`
- `average_frame_time_ms`
- `frame_time_s`
- `physics_2d_active`
- `physics_2d_collision_pairs`
- `draw_calls`
- `render_primitives`
- `realtime_hitch_count`
- `world_biome_texture_build_count`
- `world_biome_texture_last_build_ms`
- `minimap_texture_build_count`
- `map_screen_texture_build_count`
- `benchmark_sample_build_ms`
- `hud_snapshot_build_ms`

Record any additional diagnostic fields that the benchmark JSON already prints, but do not invent new ones for comparison unless they are stable and meaningful.

## Baseline Note For The Old Rendering Problem

Known old issue to keep in mind:

- Draw calls and render primitives used to be much higher during the buggy render path.
- The old symptom was periodic stuttering caused by blocking work on the main thread, especially texture builds and other heavy cache updates.
- A healthy result should keep draw calls roughly in the expected optimized range and should not reintroduce large spikes in `frame_time_s`.

Use this baseline note as a sanity check, not as a replacement for the recorded metrics.

## Before / After Template

Paste this block into the PR and fill it in for every benchmark run:

```text
Performance Benchmark Report

Branch:
- before:
- after:

Scenario:
- 60 s benchmark
- machine:
- build:
- seed / scene:

Before:
- average_fps:
- min_fps:
- max_frame_time_ms:
- average_frame_time_ms:
- frame_time_s:
- physics_2d_active:
- physics_2d_collision_pairs:
- draw_calls:
- render_primitives:
- realtime_hitch_count:
- world_biome_texture_build_count:
- world_biome_texture_last_build_ms:
- minimap_texture_build_count:
- map_screen_texture_build_count:
- benchmark_sample_build_ms:
- hud_snapshot_build_ms:

After:
- average_fps:
- min_fps:
- max_frame_time_ms:
- average_frame_time_ms:
- frame_time_s:
- physics_2d_active:
- physics_2d_collision_pairs:
- draw_calls:
- render_primitives:
- realtime_hitch_count:
- world_biome_texture_build_count:
- world_biome_texture_last_build_ms:
- minimap_texture_build_count:
- map_screen_texture_build_count:
- benchmark_sample_build_ms:
- hud_snapshot_build_ms:

Notes:
- what changed:
- expected effect:
- observed effect:
- any regressions:
```

## Quick Validation Checklist

- [ ] Ran the same 60 s benchmark before and after.
- [ ] Recorded the same metrics for both runs.
- [ ] Confirmed `realtime_hitch_count` did not increase unexpectedly.
- [ ] Confirmed `draw_calls` and `render_primitives` stayed in the expected optimized range.
- [ ] Checked `max_frame_time_ms` for new spikes.
- [ ] Confirmed the benchmark result was not judged from visual impression alone.
- [ ] Added the before/after summary to the PR description or review comment.

