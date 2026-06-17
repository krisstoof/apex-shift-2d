# World Generation Tests

## Overview

This document describes the procedural island world generation test suite. These tests ensure that the world generator produces stable, deterministic, and playable island layouts before textures and complex biome/landmark systems are added.

**Goal**: Validate the generator output at the data layer (not the renderer), ensuring correctness of terrain, biomes, spawn positions, and save/load integrity.

## Test Categories

### 1. Determinism Tests

These tests verify that the same seed always produces the same world.

- **`test_deterministic_hash`**: Same seed → same `world_generation_hash`
- **`test_hash_sensitivity`**: Different seeds → different hashes (no trivial collisions)
- **`test_world_generation_hash_stability`**: Same seed run 3 times → identical hash all runs

**Why it matters**: Players expect reproducible worlds. Tools (debug, level editors, save/load) depend on seed stability.

### 2. Content Validation Tests

These tests verify that generated worlds contain the required terrain types.

- **`test_world_contains_land`**: World must have land terrain
- **`test_world_contains_water`**: World must have water (ocean or pond)
- **`test_terrain_coverage`**: Land fraction ≥ 20%, ocean ≤ 75%
- **`test_biomes_exist_on_land`**: Biomes placed on land with meaningful coverage (≥ 50 samples each)

**Why it matters**: Unplayable worlds (all water, no water, no biomes) indicate generator corruption.

### 3. Spawn Validation Tests

These tests verify that player and creature spawn positions are on valid terrain.

- **`test_no_water_spawns`**: No creature spawn zone in water or out-of-bounds
- **`test_player_spawn_on_land`**: Player spawn position on land, not water
- **`test_creatures_spawn_on_valid_terrain`**: Creature spawns on land or shallow water (not deep ocean)
- **`test_points_in_bounds`**: All spawn zones inside `world_rect`

**Why it matters**: Players and creatures appearing in water is a critical failure. Spawns define gameplay viability.

### 4. Seed Sensitivity Tests

These tests verify that different seeds produce meaningfully different worlds.

- **`test_different_seeds_create_different_worlds`**: ≥ 80% of seeds produce unique hashes

**Why it matters**: If seed is ignored, all worlds will be identical (game-breaking).

## Test Seeds

All deterministic tests use a fixed seed list for reproducibility and regression detection:

```
1, 2, 3, 42, 100, 999,
12345, 54321, 99999,
2069809369, 1780589108, 1364451488,
7, 1337
```

That's **14 seeds × 8 test methods = 112 test cases** in the stability suite.

Special seeds:
- `42` — "Answer to the Ultimate Question"
- `1337` — Developer joke seed
- `2069809369`, `1780589108`, `1364451488` — Seeds from production benchmark logs

## Terrain Type Definitions

The generator produces 4 base terrain types, sampled on a noise-based grid:

| Terrain Type | Description | Terrain Zone | Water? | Spawn Valid? |
|---|---|---|---|---|
| **land** | Flat, walkable terrain | `"land"` | No | Yes |
| **highland** | Hill/ridge terrain | `"highland"` | No | Yes |
| **pond** | Shallow inland water | `"pond"` | Yes | No (by default) |
| **ocean** | Deep water, map boundary | `"ocean"` | Yes | No |

Terrain zones are queried via `WorldGenerator.get_terrain_zone(position: Vector2) -> String`.

### Shallow vs Deep Water

- **Shallow water** (`"pond"`): Inland water, often between islands
  - Creatures that explicitly flag `can_spawn_in_shallow_water` may spawn here
  - Vegetation normally does not spawn here
- **Deep water** (`"ocean"`): Ocean/map boundary
  - No land spawns permitted
  - Reserved for water creatures (if they exist)

## Spawn Position Validation Rules

### Player Spawn

- Must be in `world_rect`
- Must be on land (`"land"` or `"highland"`)
- Must not be in pond or ocean
- Nearby area must be navigable (connected land)

### Creature Spawn Zones

- Must be in `world_rect`
- Must be on land by default
- Some creature types (e.g., aquatic/amphibious) may allow `"pond"` with explicit flag
- Deep water (`"ocean"`) never permitted for land creatures
- Detected: `WorldGenerationValidator.validate()` returns errors for violating zones

### Vegetation / Resource Spawns

- Nodes are in `resource_zones` layout
- Land vegetation must be on `"land"` or `"highland"`
- Vegetation does not spawn in `"pond"` or `"ocean"` (test coverage: none currently)
- Special water vegetation types (if added) will have explicit type flags

## World Generation Hash

The `world_generation_hash` is a deterministic hash of the world layout:

```gdscript
func build_world_generation_hash(summary: Dictionary) -> String:
    return str(hash(JSON.stringify(summary)))
```

**Layout includes**:
- Seed
- World rectangle (`world_rect`)
- Land/water terrain counts
- Player spawn position
- Biome regions (IDs + sample counts)
- Creature spawn zones (positions + creature types)
- Resource zones (positions + resource kinds)

**Why hash instead of full comparison**:
- Handles floating-point rounding errors
- Compressible for save/load systems
- Quick collision detection across seeds

**Note**: Hash is **deterministic per seed** but may change if generator algorithm changes (e.g., noise layer tuning, biome thresholds). Treat hash as "layout fingerprint", not "immutable identifier".

## Running Tests Locally

### In the Editor

Run the full test suite via the debug panel or console:

```gdscript
var test_suite = preload("res://tests/unit/test_world_generation_stability.gd").new()
var failures = test_suite.run()
if failures.is_empty():
    print("✓ All tests passed!")
else:
    for failure in failures:
        print("✗ " + failure)
```

Or use the integrated unit test runner:

```gdscript
var runner = preload("res://tests/unit_test_runner.gd").new()
runner.run()  # Runs all test suites including world generation
```

### Command Line (Godot Headless)

```bash
godot --headless --script tests/unit/test_world_generation_stability.gd
```

### Smoke Test

For quick verification during development:

```gdscript
var gen = preload("res://scripts/world/world_generator.gd").new()
var layout = gen.generate_world(42)  # Use seed 42
var result = preload("res://scripts/world/world_generation_result.gd").from_layout(layout)
var validator = preload("res://scripts/world/world_generation_validator.gd").new()
var report = validator.validate(result, gen)
print("Valid: ", report.get("valid", false))
print("Errors: ", report.get("errors", []))
```

## Test Coverage Matrix

| Test | Determinism | Content | Spawns | Biomes | Landmarks | Save/Load |
|---|---|---|---|---|---|---|
| deterministic_hash | ✓ | | | | | |
| hash_sensitivity | ✓ | | | | | |
| world_contains_land | | ✓ | | | | |
| world_contains_water | | ✓ | | | | |
| terrain_coverage | | ✓ | | | | |
| player_spawn_on_land | | | ✓ | | | |
| creatures_spawn_on_valid | | | ✓ | | | |
| no_water_spawns | | | ✓ | | | |
| biomes_exist_on_land | | | | ✓ | | |
| different_seeds_create_different | ✓ | ✓ | | | | |
| world_generation_hash_stability | ✓ | | | | | |

**Currently Not Tested** (future expansion):
- Landmark placement validation (overlaps, terrain, proximity)
- Resource spawn coverage
- Save/load layout restoration
- Biome-specific spawn rules
- Island connectivity (reachability analysis)

## Implementation Notes

### Test Data

All tests use preload to avoid dependency on scene tree:

```gdscript
const WORLD_GENERATOR := preload("res://scripts/world/world_generator.gd")
const WORLD_GENERATION_RESULT := preload("res://scripts/world/world_generation_result.gd")
const WORLD_GENERATION_VALIDATOR := preload("res://scripts/world/world_generation_validator.gd")
```

### Test Structure

Each test method:
1. Iterates over `TEST_SEEDS` array
2. For each seed, generates layout via `WorldGenerator.generate_world(seed)`
3. Validates specific property (land coverage, spawn positions, etc.)
4. Returns `Array[String]` of failure messages (empty = all pass)

Example failure message format:
```
"PLAYER_SPAWN seed=42: spawn at (256, 192) is in water zone 'ocean'"
```

### Validator Rules (hardcoded constraints)

- `MIN_LAND_FRACTION` = 0.20 (20% land minimum)
- `MAX_OCEAN_FRACTION` = 0.75 (75% ocean maximum)
- `MIN_BIOME_SAMPLE_COUNT` = 50 (each biome ≥ 50 samples)
- No spawn zone in water or out-of-bounds

## Debugging Failed Tests

### Player Spawn in Water

1. Check seed: Log `world_generation_hash` for the failing seed
2. Query terrain: `gen.get_terrain_zone(player_spawn_pos)` should return `"land"` or `"highland"`
3. Inspect layout: `layout["player_spawn_position"]` in the debug output
4. Check generator: May indicate noise layer or biome boundary issue

### Low Biome Coverage

1. Verify biome threshold in `WorldGenerator` (biome boundary calculation)
2. Check if biome is present in `layout["biomes"]` array
3. Increase `MIN_BIOME_SAMPLE_COUNT` if intentional (e.g., rare biomes)

### Different Seeds Produce Identical Hashes

1. Verify seed is properly passed to generator: `gen.generate_world(test_seed)`
2. Check `FastNoiseLite.seed` is set correctly in noise layer initialization
3. Log `JSON.stringify(layout)` for two different seeds and compare
4. May indicate generator is not seeding all noise layers

### Terrain Coverage Out of Bounds

1. Log `terrain_counts` from `layout["debug"]["terrain_counts"]`
2. Verify land/water calculation: `(land + highland) / total`
3. Adjust noise octaves or thresholds if intended

## Future Expansions

### Save/Load Validation

Once save system is integrated:
- Generate world with seed X
- Save game
- Load game
- Verify `world_generation_hash` matches original
- Verify `player_spawn_position` unchanged

### Landmark Placement

Once landmark system is finalized:
- Test no overlaps between landmarks
- Test no landmark on player spawn
- Test landmark terrain validity (land/water)
- Test minimum distance enforcement

### Reachability Analysis

Once navigation is integrated:
- Verify player spawn is on main landmass (not isolated island)
- Verify creature spawns are reachable from player spawn
- Verify resources are accessible (not surrounded by water)

## References

- [WorldGenerator](../../scripts/world/world_generator.gd)
- [WorldGenerationResult](../../scripts/world/world_generation_result.gd)
- [WorldGenerationValidator](../../scripts/world/world_generation_validator.gd)
- [TerrainMaterialResolver](../../scripts/world/terrain_material_resolver.gd)
- [Test Suite](../../tests/unit/test_world_generation_stability.gd)
