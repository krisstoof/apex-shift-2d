# Creature AI Decision Priorities

This note documents the current decision order for creature AI. The goal is to keep state changes readable, debuggable, and stable.

## Shared Rules

1. Survival threats win first.
   Creatures enter flee states when a valid threat is close enough. Threat states exit when the threat is gone, then the creature returns to wander and chooses a fresh target.
2. Existing food targets are kept briefly.
   `target_lock_time` prevents rapid switching between nearby food or prey targets. Threats and world bounds still override the lock.
3. Hunger gates food behavior.
   Comfortable animals wander or idle. Hungry animals search for preferred food. Starving or desperate animals expand search behavior.
4. Navigation validates the next step.
   Movement targets are clamped to world bounds and checked against water, hills, and player-built walls where each creature supports avoidance.
5. Debug explains the current choice.
   Each creature exposes `decision_reason` with `current_target`, state, hunger stage, and last food source.

## SmallPrey

- `FLEE` enters from player or Varnak threat range, scaled by `fear`.
- `SEEK_FOOD` enters only while hungry and when edible vegetation exists.
- `EAT` enters after reaching a plant, or as a starving no-plant fallback.
- `WANDER` and `IDLE` run when comfortable, after eating, after losing a threat, or after reaching a wander target.

## Grazer

- Initial grazers are distributed across safe, vegetation-friendly biomes instead of being spawned beside the player.
- `FLEE` enters from player or Varnak threat range, unless aggression is high enough to resist player fear.
- `SEEK_FOOD` prioritizes edible vegetation when hungry or starving.
- `SCAVENGE` is allowed when hungry and no plant target exists.
- `HUNT_SMALL_PREY` requires no plant target and starvation pressure. Desperate grazers may hunt; non-desperate grazers need omnivore niche pressure, high risk drive, and enough aggression/meat bias.
- `EAT_PLANTS` enters after reaching a plant and exits after consumption.
- `WANDER` and `IDLE` run when no stronger need is active.

## Varnak

- `FLEE` enters from active campfire fear or torch protection.
- `ATTACK`, `CHASE`, and `STALK` enter when the player is close enough or aggression/night activity makes the player a priority.
- `EAT_MEAT` enters when hungry and a valid meat drop exists.
- `HUNT_ECOSYSTEM` enters when hunt drive or hunger justifies hunting SmallPrey/Grazer and the player is not intruding too closely.
- `WANDER` runs after eating, losing prey, leaving threat range, or reaching a patrol target. Comfortable Varnaks patrol locally; hungry Varnaks without a visible target pick a much farther hunting roam target, and starving/high-drive Varnaks may cross biome boundaries while searching.

## Debug Fields

- `state`: current finite state.
- `current_target`: current target category, such as `plant`, `meat_drop`, `small_prey`, `grazer`, `player`, `fire`, or `wander`.
- `decision_reason`: why the current state/target was selected.
- `hunger_stage`: `comfortable`, `hungry`, `starving`, or `desperate`.
