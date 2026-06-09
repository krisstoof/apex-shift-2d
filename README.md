# Apex Shift 2D Prototype

Apex Shift 2D is a small Godot 4.x top-down survival prototype. The current build stabilizes the Milestone 1 / Milestone 2 vertical slice and prepares the project for the next milestone: The Pack Remembers.

## Running

1. Open this folder in Godot 4.x.
2. Run the project. The project start with scene `res://scenes/ui/start_menu.tscn`.

## Normal controls

- WASD: move
- Shift: run
- E: gather nearby resources
- Space or left mouse: attack
- 1: craft campfire
- 2: craft spear
- 3: craft trap
- 4: craft wall
- 5: craft storage box
- 6: craft tent
- 8: craft torch
- T: activate/deactivate torch
- Mouse wheel: zoom camera

## Debug controls

- F3: show/hide Debug Panel

Debug tools are available inside the Debug Panel:
- add resources
- damage/heal player
- reduce/restore hunger and stamina
- advance day or time phase
- spawn Varnaks
- force animal adaptation step
- rebuild debug/cache tools, if available
- run benchmark tools, if available

## Prototype Notes

- The main scene is a small playable test map with the player, trees, rocks, bushes, and Varnaks.
- The player starts close to wood, stone, and fiber so the core loop can be tested quickly.
- Trees give wood, rocks give stone, and bushes give fiber.
- The inventory tracks wood, stone, fiber, meat, hide, and bone.
- Crafting keys: `1` campfire, `2` spear, `3` trap.
- A tent can be crafted with `6`; interact with it at night to sleep until morning.
- Missing Varnaks respawn after each night, including nights skipped by sleeping in a tent.
- The HUD includes a compact icon bar for core actions and craftable survival skills.
- The HUD debug section shows day, generation, trap kills, player kills, fire scares, adaptation values, and live Varnak count.
- Campfires scare Varnaks while their `fire_fear` is high.
- Traps can kill Varnaks and push future generations toward higher `trap_awareness`.
- Fire scares reduce `fire_fear` and increase `stalk_tendency` on the next generation.
- Player kills increase `aggression` and `pack_coordination` on the next generation.
- New Varnaks spawned by the Debug Panel, sleeping, day changes, or generation changes use the current adaptation profile.
- The HUD shows health, hunger, stamina, key resources, spear status, debug values, interaction prompts, and recent system messages.

## Testing Animal Adaptation

1. Gather nearby wood, stone, and fiber with `E`.
2. Craft a campfire with `1` and a trap with `3`.
3. Lure a Varnak near the campfire to trigger fire fear.
4. Lure a Varnak into the trap to record a trap kill.
5. Press `F3` to open the Debug Panel.
6. Use the Debug Panel to force an animal adaptation step when needed.
7. Use the Debug Panel to spawn a fresh Varnak test group when needed.
8. Watch the HUD debug values for `fire_fear`, `trap_awareness`, `aggression`, and `pack_coordination`.

## Manual Test Checklists

- [Application overview](docs/application-overview.md)
- [Creature AI priorities](docs/creature-ai-priorities.md)
- [Torch manual test](docs/torch-manual-test.md)
- [Debug panel manual test](docs/debug-panel-manual-test.md)

## Known Limitations

- Placeholder graphics only.
- Persistent save/load exists, but it is still prototype-level and local to `user://savegame.json`.
- No full open world, audio, or polished combat feedback.
- Animal adaptation is intentionally lightweight and tuned for fast prototype testing.
- Debug tools can force adaptation steps or spawn test Varnaks, but these tools are kept inside the Debug Panel.
- The main game loop is survival, resource gathering, crafting, storage, and increasing danger across days.

## Next Milestone: The Pack Remembers

- Preserve memory across more encounters.
- Make pack behavior visible without adding a large world.
- Keep the prototype small while improving clarity around adaptation.
