# RuntimeContext Validation

Use this checklist to confirm the RuntimeContext block is healthy before freezing further refactoring work.

## Validation Checklist

- Game starts.
- `RuntimeBootstrapper` prints diagnostic status.
- `world` is found.
- `player` is found.
- `day_night_system` is found when present.
- `event_bus` is found.
- `game_session` is found.
- `snapshot_service` may be missing.
- Player spawns at safe start.
- `ChunkManager` binds to player.
- Minimap works.
- Map screen works.
- Benchmark runs without crashing.
- No major FPS regression is observed.

## Refactor Freeze Criteria

Freeze RuntimeContext refactoring when all of the following are true:

- Unit tests pass.
- Game starts.
- `RuntimeBootstrapper` status is acceptable.
- Benchmark runs without crashing.
- No blocking gameplay regression is found.

## Known Acceptable Leftovers

These are acceptable for now and do not require further refactoring by themselves:

- Some direct `get_tree()` lookups may remain.
- Some `godot_adapters` paths may remain outside RuntimeContext.
- `snapshot_service` may be missing from RuntimeContext.
- `World.gd` is not fully decomposed yet.

## Notes

This document marks the end of the RuntimeContext cleanup block. Further changes should only happen if they fix a real bug, crash, benchmark regression, or block the v0.1.3 gameplay work.
