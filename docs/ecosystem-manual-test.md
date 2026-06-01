# Ecosystem Manual Test Checklist

Use this checklist to verify the Darwinian ecosystem prototype after gameplay,
debug, save/load, or balancing changes.

## Setup

1. Run `res://scenes/main.tscn`.
   Expected: The game starts without errors, the HUD is visible, and the player can move.

2. Press `F3` to open the debug panel.
   Expected: The debug panel opens and shows an `Ecosystem` section.

3. Review the biome rows in the debug panel.
   Expected: Each biome shows plant biomass, status, SmallPrey population, Grazer population, Grazer niche, diet values, food stress, and overgrazing values.

4. Move through at least two biome areas.
   Expected: The debug panel continues updating and the current biome can be tested through player-position-based debug controls.

## Plant Biomass

1. Open the debug panel and press `Reduce plants`.
   Expected: The current biome's plant percentage decreases, food stress increases, and the biome may change status.

2. Watch the world after reducing plant biomass.
   Expected: The biome color becomes more depleted and some visible plant resources such as trees or bushes disappear.

3. Press `Restore plants`.
   Expected: The current biome's plant biomass returns near maximum and visible vegetation can return.

4. Press `Advance tick`.
   Expected: Ecosystem values update immediately instead of waiting for the normal simulation timer.

## Player Harvest Pressure

1. Find a `conifer_tree` or `leafy_tree` resource and gather it with `E`.
   Expected: Wood is added, the tree disappears, and the current biome's plant biomass decreases.

2. Gather a `bush`.
   Expected: Fiber is added and plant biomass can decrease by a smaller amount than a tree.

3. Gather a `dry_bush`.
   Expected: Fiber is added and biomass impact is small.

4. Gather a `rock`.
   Expected: Stone is added, but plant biomass does not decrease because rocks are not vegetation.

5. Watch the same biome after several plant harvests.
   Expected: The debug panel and visible vegetation both show local depletion.

## SmallPrey

1. Press `Add SmallPrey`.
   Expected: The current biome's SmallPrey population increases in the debug panel and visible SmallPrey spawn near the player.

2. Watch SmallPrey behavior for a few seconds.
   Expected: SmallPrey wander, flee from threats, and occasionally enter an eating state.

3. Press `Remove SmallPrey`.
   Expected: The current biome's SmallPrey population decreases and visible SmallPrey near the player are removed.

4. Let SmallPrey consume plants or press `Advance tick` after they have been active.
   Expected: Plant consumption pressure can be reflected in the ecosystem state.

## Grazers

1. Press `Add Grazers`.
   Expected: The current biome's Grazer population increases and visible Grazers spawn near the player.

2. Watch a Grazer under normal biomass conditions.
   Expected: Grazers wander and can enter plant-eating behavior.

3. Press `Reduce plants` several times or press `Force food stress`.
   Expected: Plant biomass drops below the Grazer food-stress threshold and food stress rises.

4. Watch Grazer behavior under food stress.
   Expected: Grazers become more likely to seek food, scavenge, or hunt SmallPrey depending on hunger, biomass, and available prey.

5. Press `Remove Grazers`.
   Expected: The current biome's Grazer population decreases and visible Grazers near the player are removed.

## Grazer Niche Shift

1. Ensure the current biome has at least one Grazer and at least one SmallPrey.
   Expected: The debug panel shows nonzero Grazer and SmallPrey populations.

2. Press `Force food stress`.
   Expected: The current biome's plant biomass falls below the configured food-stress threshold.

3. Press `Force niche check`.
   Expected: Grazer diet values move toward meat/scavenger behavior, aggression can increase, and the niche can change from `herbivore` to `omnivore`.

4. Watch the HUD messages.
   Expected: A Grazer niche shift is communicated to the player without message spam.

## Varnak Predator Pressure

1. Use existing debug controls to spawn an aggressive animal.
   Expected: A Varnak appears near the player.

2. Let the Varnak approach SmallPrey or Grazers.
   Expected: Varnaks can hunt ecosystem creatures when they encounter them.

3. Watch the ecosystem debug values.
   Expected: Predator pressure and affected populations update for the biome where hunting occurs.

4. If the Varnak kills SmallPrey or Grazers, watch HUD/debug feedback.
   Expected: The relevant population decreases and ecosystem messages can appear with cooldowns.

## Save And Load

1. Use the debug panel to change ecosystem state in the current biome.
   Expected: Plant biomass, populations, or niche values differ from defaults.

2. Press `F5` or use Pause > Save Game.
   Expected: The HUD posts `Game saved`.

3. Change the ecosystem state again after saving.
   Expected: Debug values visibly differ from the saved state.

4. Press `F9` or use Pause > Load Game.
   Expected: The HUD posts `Game loaded`.

5. Open the debug panel and inspect the same biome.
   Expected: Plant biomass, populations, Grazer traits, current niche, and food stress match the saved state.

6. Load an older save that has no ecosystem section if one is available.
   Expected: Loading does not crash and the ecosystem falls back to initialized defaults.

## Regression Notes

1. Verify that rocks remain independent of plant biomass.
   Expected: Reducing or restoring biomass does not remove rocks.

2. Verify that vegetation changes are biome-local.
   Expected: Reducing biomass in one biome does not immediately deplete every other biome.

3. Verify that debug controls stay readable.
   Expected: All ecosystem buttons remain visible and the state text remains scrollable.

4. Verify normal gameplay still works after ecosystem testing.
   Expected: The player can gather, craft, fight, save, and load without ecosystem debug controls breaking the core loop.
