# Apex Shift 2D Application Overview

This document describes the current Godot 4.x prototype as it exists in the
repository. It covers the runtime flow, gameplay systems, UI, data files,
scenes, and the responsibilities of the important scripts.

## High-Level Concept

Apex Shift 2D is a top-down survival prototype built around a compact loop:

1. The player gathers wood, stone, fiber, and animal materials.
2. The player crafts survival tools and simple buildings.
3. Varnaks roam the world, react to the player, fire, traps, walls, night, and
   the torch.
4. The EvolutionDirector records player pressure and changes future Varnak
   generations.
5. Day/night progression changes danger, visibility, sleep, resource respawn,
   and Varnak behavior.

The current game is intentionally prototype-like: visuals are drawn in code,
systems favor fast iteration, and debug tools are part of the primary workflow.

## Project Entry Points

- `project.godot` defines `res://scenes/main.tscn` as the main scene.
- `EventBus` is registered as an autoload singleton from
  `res://scripts/systems/event_bus.gd`.
- Built-in input actions in `project.godot` cover WASD movement. Most gameplay
  keys are handled directly in scripts.
- `scenes/main.tscn` composes the main runtime nodes:
  - `EvolutionDirector`
  - `DayNightSystem`
  - `SaveSystem`
  - `World`
  - `Player`
  - `HUD`
  - `GameManager`

## Runtime Startup Flow

1. Godot loads `scenes/main.tscn`.
2. `GameManager` finds the main scene systems and binds them together.
3. `Player` receives a reference to `EvolutionDirector`.
4. `HUD` binds to `Player`, `EvolutionDirector`, `DayNightSystem`, `World`, and
   `SaveSystem`.
5. `World` waits one frame so the systems are ready, then spawns resources and
   Varnaks.
6. `EventBus` distributes system messages, center notifications, and gameplay
   events.

The result is a single-scene prototype where systems communicate through direct
references for core binding and through `EventBus` for cross-system gameplay
events.

## Controls

- `WASD`: move.
- `Shift`: run while stamina is available.
- `E`: interact with the closest valid target, including resources and tents.
- `Space` or left mouse: attack.
- `G`: force a Varnak generation change.
- `R`: respawn all Varnaks with the current evolution profile.
- `1`: craft campfire.
- `2`: craft spear.
- `3`: craft trap.
- `4`: craft wall.
- `5`: craft storage box.
- `6`: craft tent.
- `7`: eat meat.
- `8`: craft torch.
- `T`: activate or deactivate torch.
- `M`: open or close the full map.
- `F3`: show or hide debug panel.
- `F5`: save game.
- `F9`: load game.
- `Esc`: open or close pause menu.

## Core Systems

### EventBus

File: `scripts/systems/event_bus.gd`

`EventBus` is the global event and message channel. It exposes:

- `game_event(event_name, payload)`: broad gameplay event signal.
- `message_posted(message)`: short message signal for the HUD.
- `emit_game_event(event_name, payload)`: emits and logs gameplay events.
- `post_message(message)`: sends and logs player-facing messages.

Important events include Varnak deaths, fire scares, wall attacks, day changes,
generation changes, torch activation, and center notifications.

### GameManager

File: `scripts/systems/game_manager.gd`

`GameManager` is the runtime binder. It locates major nodes in the main scene,
wires the player and HUD to shared systems, and posts the startup message. It
also handles global debug/save inputs:

- `R`: asks the world to respawn Varnaks.
- `F5`: saves through `SaveSystem`.
- `F9`: loads through `SaveSystem`.

### GameBalance

File: `scripts/systems/game_balance.gd`

`GameBalance` is the central constant table. It contains:

- Crafting costs for campfire, spear, torch, cooked meat, trap variants, wall,
  storage box, and tent.
- Torch duration, protection radius, light radius, protection multipliers, and
  flicker settings.
- Campfire protection and light radii.
- Player stat maximums, hunger/rest/stamina decay, regeneration, sleep recovery,
  and meat values.
- Night danger multipliers.
- Adaptation deltas and debug growth values.
- Trap and spear tuning constants.

Gameplay scripts generally read balance values from this file instead of
duplicating constants locally.

### DayNightSystem

File: `scripts/systems/day_night_system.gd`

`DayNightSystem` advances time, calculates the current phase, and drives night
effects. The day starts at 08:00 and a full day lasts 120 real seconds by
default.

Phases:

- Dawn: before 06:00.
- Day: 06:00 to 20:00.
- Dusk: 20:00 to 21:00.
- Night: 21:00 to 05:00.

Night danger is considered active from 20:00 until 06:00, while labels still
distinguish dusk, night, dawn, and day. The `night_amount` value ramps at dusk
and dawn and is used by world darkness, campfire light, torch visuals, and
creature behavior.

Sleeping through a tent calls `sleep_until_morning()`. This only works at night,
increments the day, emits relevant events, and allows resource/Varnak respawn.

### EvolutionDirector

File: `scripts/systems/evolution_director.gd`

`EvolutionDirector` owns the current Varnak species profile. It starts from
`data/species_varnak.json` and records survival pressure:

- Varnaks killed by traps.
- Varnaks killed by the player.
- Fire scares.
- Wall attacks.
- Days since the last generation.

When a generation changes, the director mutates Varnak traits according to
recent pressure, emits events/messages, resets counters, and updates existing
Varnaks through the world.

Tracked traits:

- `generation`
- `aggression`
- `fire_fear`
- `trap_awareness`
- `pack_coordination`
- `night_activity`
- `base_curiosity`
- `stalk_tendency`

Debug controls can force generation changes or increase adaptation values
directly.

### SaveSystem

File: `scripts/systems/save_system.gd`

`SaveSystem` persists the game to `user://savegame.json`. It saves and restores:

- Player position.
- Player stats.
- Player inventory.
- Spear ownership.
- Torch active state and remaining duration.
- World resources.
- Placed buildings.
- Live Varnaks and their traits/state.
- Day/night state.
- EvolutionDirector profile and counters.

Loading clears live world objects that are restored from save data, then
recreates resources, Varnaks, and buildings. It also normalizes invalid torch
state so inactive torch visuals do not remain after loading.

## World

### WorldConfig

File: `scripts/world/world_config.gd`

`WorldConfig` defines the playable rectangle, resource counts, safe spawn
distances, target Varnak count, Varnak spawn points, and biome polygons.

Current biomes:

- Westwood
- Stoneback Ridge
- Hearth Meadow
- South Thicket
- Redfang Wilds

Each biome has resource weights and a danger value used by spawning and map
rendering.

### World

File: `scripts/world/world.gd`

`World` is responsible for generated content and world rendering:

- Draws world bounds and biome polygons.
- Draws a night overlay using `DayNightSystem.night_amount`.
- Spawns trees, rocks, bushes, and dry bushes.
- Spawns Varnaks from the current evolution profile.
- Respawns resources after sleep.
- Respawns missing Varnaks after sleep.
- Respawns all Varnaks when requested by debug input or generation change.
- Saves and restores resources, Varnaks, and placed buildings.
- Provides debug spawning for aggressive or neutral animals.

Resource spawning respects world limits, player-safe radius, biome weights, and
minimum distances between nodes. Varnak spawning uses configured spawn points and
favors more dangerous biomes when possible.

### ResourceNode

File: `scripts/world/resource_node.gd`

`ResourceNode` is the interactable resource object. It supports these kinds:

- `conifer_tree`: gives wood.
- `leafy_tree`: gives wood.
- `rock`: gives stone.
- `bush`: gives fiber.
- `dry_bush`: gives fiber.

When the player interacts with a resource, the node adds the item to inventory,
posts a HUD message, and removes itself from the world.

## Player

### Inventory

File: `scripts/player/inventory.gd`

`Inventory` is a `RefCounted` container with item amounts for:

- wood
- stone
- fiber
- meat
- hide
- bone
- torch

It supports adding, removing, checking, saving, and restoring item amounts.

### PlayerStats

File: `scripts/player/player_stats.gd`

`PlayerStats` tracks:

- health
- hunger
- stamina
- rest

Stats tick every frame. Hunger and rest decay over time, stamina drains while
running, stamina regenerates while not running, starvation damages health, and
good hunger/rest allow health regeneration. Sleep restores multiple stats at
once.

### Player Controller

File: `scripts/player/player.gd`

The player script owns movement, interaction, combat, crafting, torch state,
stat ticking, and player visuals.

Movement:

- Reads WASD input.
- Supports Shift running if stamina allows it.
- Faces the mouse cursor.
- Clamps movement to the world bounds.

Interaction:

- Uses `InteractionArea` from `scenes/player/player.tscn`.
- Picks a nearby body or area with an `interact(player)` method.
- Shows prompts through the HUD.

Combat:

- Uses `AttackArea` from the player scene.
- Requires stamina.
- Checks attack direction and range.
- Deals higher damage with a spear.
- Can kill Varnaks and trigger evolution pressure.

Crafting:

- Reads costs from `GameBalance.CRAFTING_COSTS`.
- Builds campfires, traps, walls, storage boxes, and tents in front of the
  player.
- Spear is an equipment flag (`has_spear`).
- Torch is an inventory item.
- Meat can be eaten with `7`.

Torch:

- Crafted with `8`.
- Activated or deactivated with `T`.
- Activation consumes one torch from inventory.
- Active torch has a countdown timer.
- Active torch draws a light/protection visual around the player.
- Varnaks inside the torch protection radius become less aggressive, less able
  to detect/chase, and may flee unless already in immediate attack range.

## Creatures

### Varnak

File: `scripts/creatures/varnak.gd`

Varnaks are adaptive hostile creatures. Each Varnak is a `CharacterBody2D` in
the `varnak` group.

AI states:

- `IDLE`
- `WANDER`
- `STALK`
- `CHASE`
- `ATTACK`
- `FLEE`

Trait inputs:

- Health and speed.
- Aggression.
- Fire fear.
- Trap awareness.
- Pack coordination.
- Night activity.
- Base curiosity.
- Stalk tendency.

Behavior:

- Wanders when no strong target is detected.
- Detects the player based on distance, curiosity, aggression, and night
  activity.
- Stalks or chases depending on aggression and distance.
- Attacks when close enough and off cooldown.
- Flees active campfires when fire fear is high.
- Avoids armed traps when trap awareness is high.
- Receives night health bonuses during dangerous hours.
- Reacts to player torch protection at dusk/night.

Death:

- Death by trap emits trap pressure.
- Death by player emits player-kill pressure.
- If the player is nearby, the Varnak can award meat, hide, and bone.

The script also exposes debug snapshots used by the debug panel.

## Buildings

### Campfire

Files:

- `scenes/buildings/campfire.tscn`
- `scripts/buildings/campfire.gd`

Campfires are active by default and belong to the `campfires` group. They draw
their own placeholder fire, light glow, and fear radius. Varnaks use active
campfires to decide whether to flee based on their `fire_fear` trait.

### Trap

Files:

- `scenes/buildings/trap.tscn`
- `scripts/buildings/trap.gd`

Traps belong to the `traps` group. They start armed, damage the first Varnak
that enters, post a message, then remove themselves. Trap kills feed Varnak
adaptation through the death source.

### Wall

Files:

- `scenes/buildings/wall.tscn`
- `scripts/buildings/wall.gd`

Walls are static bodies in the `walls` group. They have health and emit
`varnak_attacked_wall` when damaged. Destroyed walls remove themselves.

### Tent

Files:

- `scenes/buildings/tent.tscn`
- `scripts/buildings/tent.gd`

Tents are interactable areas in the `tents` group. Interacting with a tent at
night sleeps until morning through `DayNightSystem`, restores player stats, and
posts a message. If sleep is unavailable, the tent reports that there is no safe
place to sleep.

### Storage Box

Files:

- `scenes/buildings/storage_box.tscn`
- `scripts/buildings/storage_box.gd`

Storage boxes are currently visual/static prototype objects in the
`storage_boxes` group. They are saved/restored as placed buildings but do not
yet expose storage inventory behavior.

## UI

### HUD

Files:

- `scenes/ui/hud.tscn`
- `scripts/ui/hud.gd`

The HUD is a `CanvasLayer` that shows:

- Health, hunger, stamina, rest, and condition.
- Core resources.
- Meat and torch counts.
- Spear status.
- Torch active/inactive status.
- Interaction prompt.
- Recent messages.
- Center notifications.
- Clock and day phase.
- Skill icon bar.
- Minimap.
- Debug panel.
- Full map screen.
- Pause menu.

The HUD also handles UI toggles for map, pause menu, and debug panel, and keeps
the scene paused when full-screen overlays require it.

### SkillIconBar

File: `scripts/ui/skill_icon_bar.gd`

The skill bar is a drawn control that summarizes core actions and craftable
items. Current slots:

- `Shift`: Run
- `E`: Use
- `Space`: Attack
- `G`: Gen
- `1`: Fire
- `2`: Spear
- `3`: Trap
- `4`: Wall
- `5`: Box
- `6`: Tent
- `7`: Meat
- `8/T`: Torch

Each slot has an icon, label, key, and availability state. Craftable slots use
player inventory and recipe costs to decide whether they are available.

### Minimap

File: `scripts/ui/minimap.gd`

The minimap draws:

- Biomes.
- Grid.
- Resource markers.
- Varnak markers.
- Player marker.
- Current biome/zone label.

It uses the same world rectangle and biome polygons as the full world.

### MapScreen

File: `scripts/ui/map_screen.gd`

The full map is opened with `M`. It draws a larger world map and an info panel
with:

- Current zone.
- Day and clock.
- Live Varnak count.
- Player stats.
- Inventory summary.
- Varnak evolution profile.

It runs in `PROCESS_MODE_ALWAYS` so it can draw while the game is paused.

### PauseMenu

File: `scripts/ui/pause_menu.gd`

The pause menu is opened with `Esc` and provides:

- Resume.
- Save Game.
- Load Game.
- Quit.

It emits signals that the HUD connects to save/load/pause behavior.

### DebugPanel

File: `scripts/ui/debug_panel.gd`

The debug panel is opened with `F3`. It is a scrollable diagnostic and testing
surface. It shows:

- Day, phase, and night amount.
- Adaptation generation and pressure.
- Player health, hunger, stamina, rest.
- Resource counts.
- Crafted/placed object counts.
- Campfire/torch state.
- Live Varnak count and state distribution.
- Evolution trait values.
- Event counters.
- Generation day counters.
- Average Varnak health.
- Nearest Varnak distance/state/health.

It also exposes test buttons:

- Add wood, stone, fiber, meat, torch, and spear.
- Advance phase or day.
- Increase adaptation.
- Spawn aggressive or neutral animals.
- Damage or heal the player.
- Reduce or restore hunger/energy.

## Data Files

### species_varnak.json

File: `data/species_varnak.json`

Defines the initial Varnak species profile loaded by `EvolutionDirector`.

### items.json

File: `data/items.json`

Defines item display metadata. Current gameplay logic primarily uses item ids
from inventory and balance constants.

### recipes.json

File: `data/recipes.json`

Contains recipe data matching the prototype crafting set. The current player
crafting logic uses `GameBalance.CRAFTING_COSTS` as the active source of truth,
so this JSON is best treated as reference/legacy data unless crafting is moved
back to data-driven recipes.

## Scene Files

Important scenes:

- `scenes/main.tscn`: main composition scene.
- `scenes/player/player.tscn`: player body, camera, interaction area, attack
  area.
- `scenes/world/world.tscn`: world node.
- `scenes/world/resource_node.tscn`: generic resource instance.
- `scenes/creatures/varnak.tscn`: Varnak creature scene.
- `scenes/buildings/campfire.tscn`: campfire.
- `scenes/buildings/trap.tscn`: trap.
- `scenes/buildings/wall.tscn`: wall.
- `scenes/buildings/tent.tscn`: tent.
- `scenes/buildings/storage_box.tscn`: storage box.
- `scenes/ui/hud.tscn`: all primary UI controls.
- `scenes/systems/game_manager.tscn`: GameManager scene wrapper.

## Gameplay Loops

### Gather and Craft

1. Find a resource marker in the world or on the minimap.
2. Move close and press `E`.
3. Inventory increases and the resource node disappears.
4. Press a crafting key when costs are available.
5. Crafted buildings appear in front of the player or equipment/inventory state
   changes.

### Survive Night

1. Time advances through day, dusk, night, and dawn.
2. Night increases danger and affects Varnak behavior.
3. Campfires and torches create protective spaces.
4. Tents allow sleep until morning if used at night.
5. Morning can respawn resources and missing Varnaks.

### Adaptation

1. Varnaks encounter traps, fire, walls, and player attacks.
2. `EventBus` sends pressure events.
3. `EvolutionDirector` tracks counters.
4. A generation change mutates the Varnak profile.
5. New or respawned Varnaks use the updated profile.

### Save and Load

1. Press `F5` or use Pause > Save Game.
2. `SaveSystem` writes player, world, creature, building, time, and evolution
   state.
3. Press `F9` or use Pause > Load Game.
4. Runtime objects are restored from save data.

## Debug and Manual Testing

Existing manual checklists:

- `docs/torch-manual-test.md`
- `docs/debug-panel-manual-test.md`

Recommended debug workflow:

1. Press `F3`.
2. Add enough resources with debug buttons.
3. Spawn aggressive or neutral animals as needed.
4. Advance phase/day to test night, sleep, and adaptation.
5. Watch Varnak state distribution, profile values, and event counters.

## Current Limitations

- Visuals are placeholder shapes drawn in GDScript.
- Storage boxes do not yet store items.
- Recipes exist both as JSON reference data and `GameBalance` constants, but
  active crafting uses `GameBalance`.
- Combat feedback is functional but minimal.
- Varnak pack behavior is represented by traits and pressure values, not by a
  complete group tactics system yet.
- Audio, menus beyond pause, and polished world content are not implemented.

## Extension Notes

- Add or retune gameplay constants in `GameBalance` first.
- Add new craftable buildings through player crafting, a scene, a script, save
  restore support, and skill bar availability.
- Add new Varnak adaptation pressure through `EventBus` events and
  `EvolutionDirector` counters.
- Keep debug panel values updated when new systems affect Varnaks, player stats,
  or day/night flow.
- If crafting should become fully data-driven, move the active source of truth
  from `GameBalance.CRAFTING_COSTS` to `data/recipes.json` and update all UI
  availability checks together.
