# Apex Shift 2D Prototype

Apex Shift 2D is a small Godot 4.x top-down survival prototype. The current build stabilizes the Milestone 1 / Milestone 2 vertical slice and prepares the project for the next milestone: The Pack Remembers.

## Running

1. Open this folder in Godot 4.x.
2. Run the project. The main scene is `res://scenes/main.tscn`.

## Controls

- WASD: move
- Shift: run
- E: gather nearby resources
- Space or left mouse: attack
- G: force Varnak generation change
- R: respawn Varnaks with the current evolution profile
- 1: craft campfire
- 2: craft spear
- 3: craft trap
- 4: craft wall
- 5: craft storage box
- 6: craft tent
- 8: craft torch
- T: activate/deactivate torch

## Prototype Notes

- The main scene is a small playable test map with the player, trees, rocks, bushes, and Varnaks.
- The player starts close to wood, stone, and fiber so the core loop can be tested quickly.
- Trees give wood, rocks give stone, and bushes give fiber.
- The inventory tracks wood, stone, fiber, meat, hide, and bone.
- Crafting keys: `1` campfire, `2` spear, `3` trap.
- A tent can be crafted with `6`; interact with it at night to sleep until morning.
- Missing Varnaks respawn after each night, including nights skipped by sleeping in a tent.
- Press `R` to respawn all Varnaks during testing.
- The HUD includes a compact icon bar for core actions and craftable survival skills.
- The HUD debug section shows day, generation, trap kills, player kills, fire scares, evolution values, and live Varnak count.
- Campfires scare Varnaks while their `fire_fear` is high.
- Traps can kill Varnaks and push future generations toward higher `trap_awareness`.
- Fire scares reduce `fire_fear` and increase `stalk_tendency` on the next generation.
- Player kills increase `aggression` and `pack_coordination` on the next generation.
- New Varnaks spawned by `R`, sleeping, day changes, or generation changes use the current EvolutionDirector profile.
- The HUD shows health, hunger, stamina, key resources, spear status, debug values, interaction prompts, and recent system messages.

## Testing Adaptation

1. Gather nearby wood, stone, and fiber with `E`.
2. Craft a campfire with `1` and a trap with `3`.
3. Lure a Varnak near the campfire to trigger fire fear.
4. Lure a Varnak into the trap to record a trap kill.
5. Press `G` to force a generation change.
6. Press `R` if you want a fresh test group using the current profile.
7. Watch the HUD debug values for `fire_fear`, `trap_awareness`, `aggression`, and `pack_coordination`.

## Manual Test Checklists

- [Torch manual test](docs/torch-manual-test.md)
- [Debug panel manual test](docs/debug-panel-manual-test.md)

## Known Limitations

- Placeholder graphics only.
- No persistent save data yet; `save_system.gd` is a TODO stub.
- No full open world, audio, menus, or polished combat feedback.
- Existing Varnaks update immediately after generation changes for easy testing.
- Varnak adaptation is intentionally lightweight and tuned for fast prototype testing.
- Respawn is a test helper, not a full population simulation.

## Next Milestone: The Pack Remembers

- Preserve memory across more encounters.
- Make pack behavior visible without adding a large world.
- Keep the prototype small while improving clarity around adaptation.
