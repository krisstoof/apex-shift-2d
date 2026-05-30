# Apex Shift 2D Prototype

Apex Shift 2D is a small Godot 4.x top-down survival prototype. The player gathers resources, crafts simple tools and buildings, fights Varnaks, and can force a new Varnak generation to see adaptation parameters change.

## Running

1. Open this folder in Godot 4.x.
2. Run the project. The main scene is `res://scenes/main.tscn`.

## Controls

- WASD: move
- Shift: run
- E: gather nearby resources
- Space or left mouse: attack
- G: force Varnak generation change
- 1: craft campfire
- 2: craft spear
- 3: craft trap
- 4: craft wall
- 5: craft storage box

## Prototype Notes

- Trees give wood, rocks give stone, and bushes give fiber.
- Campfires scare Varnaks while their `fire_fear` is high.
- Traps can kill Varnaks and push future generations toward higher `trap_awareness`.
- Repeated fire scares reduce `fire_fear` and increase `stalk_tendency`.
- Repeated player kills increase `aggression` and `pack_coordination`.

## Known Limitations

- Placeholder graphics only.
- No persistent save data yet; `save_system.gd` is a TODO stub.
- No full open world, audio, menus, or polished combat feedback.
- Existing Varnaks update immediately after generation changes for easy testing.

## Next Steps

- Add proper sprites and animations.
- Add stronger Varnak pack behavior.
- Persist world state and evolution data.
- Add clearer interaction prompts and crafting feedback.
