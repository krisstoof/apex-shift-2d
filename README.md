# Apex Shift 2D v0.1.2

## Overview

Apex Shift 2D is a Godot 4.x top-down survival prototype focused on gathering resources, crafting survival tools, managing inventory and storage, and testing a living world with prey, grazers, and Varnaks.

The current build is meant for tester validation and release checks. It includes a lightweight Varnak adaptation profile, a living world with biome landmarks, and a UI set that is now broad enough for real playthrough testing instead of a tiny isolated demo.

## Current prototype features

- Start menu with new game, continue, load save, settings, and exit flow.
- Settings menu.
- Pause menu.
- Game over screen.
- Expanded HUD with player stats, prompts, messages, and resource icons.
- Inventory screen.
- Storage box interaction.
- Minimap and full map screen.
- Debug panel for diagnostics and testing.
- Living world with small prey, grazers, and Varnaks.
- Lightweight Varnak adaptation profile.
- Island/world layout with landmarks, ponds, hills, and biome zones.
- Resource gathering and crafting.
- Basic save/load.

## Running the game

1. Open the project in Godot 4.x.
2. Run the project.
3. The project starts from `res://scenes/ui/start_menu.tscn`.

Use New Game for a clean test run. Use Continue or Load Save only when validating persistence.

## Normal controls

- `WASD` - move
- `Shift` - run
- `E` - interact / gather nearby resources
- `I` - open or close inventory
- `M` - open or close map
- `Esc` - pause or close the current screen
- `Space` or left mouse button - attack
- `T` - activate or deactivate torch
- Mouse wheel - zoom the camera

## Crafting hotkeys

- `1` - craft campfire
- `2` - craft spear
- `3` - craft trap
- `4` - craft wall
- `5` - craft storage box
- `6` - craft tent
- `7` - eat meat
- `8` - craft torch
- `9` - craft bow

## Debug controls

- `F3` - show or hide the Debug Panel

The Debug Panel is for testing and diagnostics. It may include tools for adding resources, damaging or healing the player, changing hunger/stamina/rest, advancing day or time, spawning Varnaks, forcing animal or adaptation steps, running benchmark tools, and inspecting world or performance state.

## Gameplay systems to test

- Resource gathering from trees, rocks, bushes, grass, and other world resources.
- Crafting survival tools and structures.
- Survival stats, including health, hunger, stamina, rest, and torch use.
- Interaction feedback and prompt visibility.
- Combat feedback against creatures and world entities.
- Save/load behavior across play sessions.
- World state persistence after day changes and progression.

## Inventory and storage

The inventory screen is used to inspect carried resources and items. The HUD also shows resource icons for quick feedback. Storage boxes can be crafted and used to store supplies outside the player inventory.

Inventory and storage are prototype-level features, so they should be tested carefully for save/load regressions, item transfer issues, and interaction edge cases.

## Map, minimap and debug panel

- The minimap is visible in the HUD.
- `M` opens the full map screen.
- The map shows the world layout, landmarks, resources, and creatures when available.
- `F3` opens the Debug Panel.

The debug panel is intended for testing, inspection, and benchmark runs rather than normal play.

## Living world

The living world currently includes:

- Small prey
- Grazers
- Varnaks
- Biomes, ponds, hills, and landmark-driven world layout
- Resource and vegetation interactions
- Creature movement, hunger behavior, and out-of-bounds protection

The Varnak adaptation system is currently lightweight. It adjusts behavior profile values based on player actions, but it is not a full genetics or species evolution simulation.

## Save/load

Save/load exists for prototype testing and stores the local save in `user://savegame.json`.

When validating persistence, pay special attention to:

- inventory contents
- storage box contents
- resource states
- drops
- animals
- day and time state

## Prototype limitations

- Placeholder graphics and simple UI visuals.
- Combat feedback is still prototype-level.
- Audio and final presentation are not complete.
- Save/load is functional but still under active validation.
- Varnak adaptation is lightweight, not a full species evolution model.
- World generation, chunking, and spatial index work are still evolving.
- Balance is temporary and tuned for testing.
- Debug tools are available and can alter normal progression.
- The world is still prototype-scale and does not represent final content scope.

## Testing resources

- [Application overview](docs/application-overview.md)
- [Creature AI priorities](docs/creature-ai-priorities.md)
- [Torch manual test](docs/torch-manual-test.md)
- [Island world validation](docs/island-world-validation.md)
- [Object pooling](docs/object-pooling.md)
- [Chunk manager](docs/chunk-manager.md)
- [Creature simulation LOD](docs/creature-simulation-lod.md)
- [Debug panel manual test](docs/debug-panel-manual-test.md)
- [Unit tests](docs/unit-tests.md)
- [Integration tests](docs/integration-tests.md)
- [Regression test strategy](docs/regression-tests-strategy.md)
- [Performance benchmark checklist](docs/performance-benchmark-checklist.md)
- [Ecosystem manual test](docs/ecosystem-manual-test.md)
- [Vision notes](docs/vision.md)

Release notes and known issues will be added in future documentation passes.

## Next focus

- Keep validating the current prototype loop with save/load, inventory, storage, and creature behavior.
- Use the benchmark and debug tools to catch regressions before adding new systems.
- Continue tightening the README and test notes as the prototype grows.
