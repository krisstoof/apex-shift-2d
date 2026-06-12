# Chunk Manager

Stage 1 chunk manager groups the world into fixed in-memory chunks without streaming or generation changes.

## What it tracks

- Player chunk position
- Active chunk state around the player
- Entity-to-chunk assignments for resources, creatures, and decorations
- Debug counters for chunk changes, activations, and deactivations

## Configuration

Chunk settings live in `scripts/systems/game_balance.gd` under `WORLD_CHUNKS`.

## Current scope

- No scene streaming
- No terrain regeneration
- No save format changes
- No unloading of world content

The system is intentionally lightweight so it can be expanded later without replacing the existing spatial index.
