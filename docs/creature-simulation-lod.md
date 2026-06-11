# Creature Simulation LOD

## Goal

Reduce AI and physics cost for creatures far from the player.

## Levels

### Near

Full simulation.

### Medium

Reduced AI decision frequency and reduced target search frequency.

### Far

No full movement or combat. Only hunger, age, energy and lightweight state data are updated.

## Rules

- Varnak near the player always uses full AI.
- Simulation level is distance-based.
- Thresholds are configured in `GameBalance.CREATURE_SIMULATION_LOD`.
- Save/load does not persist simulation level directly.
- Simulation level is visible in debug data.

## Manual Test

1. Spawn multiple creatures.
2. Move away from part of the population.
3. Confirm debug data shows near/medium/far.
4. Confirm near creatures behave normally.
5. Confirm far creatures do not run full AI.
6. Confirm Varnak near player attacks normally.
7. Save and load.
8. Confirm no teleport or broken state after restore.
