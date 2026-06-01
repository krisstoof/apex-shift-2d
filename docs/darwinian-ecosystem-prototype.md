# Darwinian Ecosystem Prototype

This document describes the current ecosystem and niche-shift prototype in Apex
Shift 2D. It is a reference for future ecosystem issues and balancing work.

## Design Goal

The ecosystem prototype extends the Varnak adaptation loop with a simple food
web. The player, herbivores, prey animals, vegetation, and Varnaks all apply
pressure to the same biome-level state.

The goal is not biological accuracy yet. The goal is a readable simulation where
the player can see that local actions change a biome and that creatures react to
those changes.

## Main Runtime Owners

- `scripts/systems/ecosystem_director.gd` owns biome ecosystem state.
- `scripts/world/world.gd` owns visible world entities and vegetation resource
  nodes.
- `scripts/creatures/small_prey.gd` owns individual SmallPrey behavior.
- `scripts/creatures/grazer.gd` owns individual Grazer behavior and diet
  choices.
- `scripts/creatures/varnak.gd` owns Varnak predator behavior.
- `scripts/systems/game_balance.gd` contains tunable ecosystem values under
  `GameBalance.ECOSYSTEM`.
- `data/species/small_prey.json` and `data/species/grazer.json` define base
  creature traits.

## Biome State

Each biome has a state entry in `EcosystemDirector`. The current state includes:

- `plant_biomass`
- `plant_biomass_percent`
- `max_plant_biomass`
- `plant_regrowth_rate`
- `plant_consumption_pressure`
- `overgrazing_pressure`
- `overgrazing_level`
- `small_prey_population`
- `grazer_population`
- `varnak_ecosystem_pressure`
- `food_stress`
- Grazer average diet traits
- Grazer average aggression
- Grazer current niche
- `generations_under_food_stress`
- `grazer_non_plant_food_events`
- biomass status: `healthy`, `stressed`, `depleted`, or `collapsing`

Biome state is saved and loaded through `SaveSystem`.

## Trophic Levels

The prototype currently uses four simple trophic levels.

### Vegetation

Vegetation is the base resource layer. It is represented in two ways:

- abstract biome biomass in `EcosystemDirector`
- visible resource nodes in `World`

Plant resources include:

- `conifer_tree`
- `leafy_tree`
- `bush`
- `dry_bush`

Rocks are not vegetation and do not respond to plant biomass.

When plant biomass drops, the biome becomes visually more depleted and the world
reduces the number of visible plant resources in that biome. When biomass is
restored or regrows, the world can add plant resources back. This makes biomass
more than a debug number: it affects the actual amount of wood/fiber vegetation
available in the biome.

### SmallPrey

SmallPrey are tier-1 plant eaters. They consume vegetation, flee threats, and
serve as food for Varnaks and hungry Grazers.

SmallPrey pressure is represented in two layers:

- biome-level population in `EcosystemDirector`
- visible creatures spawned by `World`

Their base traits are loaded from `data/species/small_prey.json`. Important
traits include health, speed, fear, hunger rate, diet, plant consumption, and
reproduction rate.

### Grazers

Grazers are tier-2 flexible herbivores. They primarily eat plants, but the
ecosystem can push them toward omnivory when plant food becomes scarce.

Grazer state is also represented in two layers:

- biome-level population and average traits in `EcosystemDirector`
- visible creatures spawned by `World`

Their base traits are loaded from `data/species/grazer.json`. Important traits
include health, speed, fear, aggression, hunger rate, plant diet, meat diet,
scavenger diet, plant consumption, reproduction rate, and evolution tuning.

### Varnaks

Varnaks are the current apex predator. They can hunt SmallPrey and Grazers, and
their local presence creates predator pressure in biome state.

Varnaks still have their separate generation-adaptation system in
`EvolutionDirector`. The ecosystem layer does not replace that system. Instead,
it gives Varnaks a role in the food web and lets them shape prey and Grazer
populations.

## Plant Biomass

Plant biomass is a biome-level value. It changes through:

- natural regrowth
- consumption by SmallPrey
- consumption by Grazers
- player harvesting plant resources
- debug panel controls

Biomass status thresholds are configured in `GameBalance.ECOSYSTEM`:

- stressed threshold
- depleted threshold
- collapsing threshold

Biomass affects:

- debug panel values
- HUD ecosystem messages
- biome visual color
- visible plant resource count
- SmallPrey population growth
- Grazer food stress
- Grazer niche-shift checks

## Hunger And Diet

SmallPrey and Grazers use `scripts/creatures/hunger_diet.gd` for hunger and diet
tracking. The diet model tracks:

- hunger
- max hunger
- hunger growth rate
- energy
- plant diet preference
- meat diet preference
- scavenger diet preference

SmallPrey are almost fully plant-focused. Grazers start as herbivores but can
shift toward meat/scavenger behavior under sustained food stress.

## Grazer Niche Shift

Grazers start in the `HERBIVORE` niche. The ecosystem can move a biome's average
Grazer profile toward `OMNIVORE`.

The current shift requires:

- plant biomass below the configured food-stress threshold
- a nonzero Grazer population
- a nonzero SmallPrey population
- at least one non-plant food event, such as hunting SmallPrey or scavenging

When a shift check succeeds, the biome's average Grazer traits change:

- plant diet decreases
- meat diet increases
- scavenger diet increases
- aggression increases

When the non-plant diet passes the configured niche threshold, the biome's
Grazer niche changes from `HERBIVORE` to `OMNIVORE`, and a
`grazer_niche_shifted` event is emitted.

## Player Impact

The player affects the ecosystem through direct and indirect pressure.

Direct pressure:

- harvesting trees and bushes reduces plant biomass in the current biome
- killing SmallPrey reduces biome SmallPrey population
- killing Grazers reduces biome Grazer population
- debug panel controls can force ecosystem states for testing

Indirect pressure:

- reducing vegetation lowers future food availability
- low biomass can reduce visible plant resources
- low biomass makes Grazers more likely to seek non-plant food
- Varnak pressure changes local prey and Grazer survival

The key rule is local consequence: biome state should make the current biome
feel different after sustained pressure.

## Events And Feedback

The ecosystem uses `EventBus` for cross-system feedback.

Important events include:

- `plant_resource_harvested`
- `ecosystem_vegetation_changed`
- `ecosystem_biome_stressed`
- `ecosystem_biome_depleted`
- `ecosystem_biome_collapsing`
- `small_prey_population_declining`
- `grazer_population_declining`
- `grazer_niche_shifted`
- `small_prey_consumed_plants`
- `grazer_consumed_plants`
- `grazer_scavenged`
- `grazer_hunted_small_prey`

The HUD turns important ecosystem events into short player-facing messages with
cooldowns. The debug panel exposes detailed biome state for testing.

## Save And Load

Ecosystem state is saved through `EcosystemDirector.get_save_data()` and loaded
through `EcosystemDirector.load_save_data()`.

Saved state includes biome states and the simulation tick timer. Older saves
without ecosystem data are allowed: loading an empty ecosystem section keeps the
freshly initialized default biome state.

## Debug Controls

The debug panel currently supports ecosystem testing actions:

- reduce plant biomass
- restore plant biomass
- add SmallPrey
- remove SmallPrey
- add Grazers
- remove Grazers
- force Grazer food stress
- force Grazer niche shift check
- advance ecosystem tick

Controls target the biome where the player currently stands. If no player biome
can be found, the system falls back to the first known biome.

Debug actions should be visible immediately when possible. Population controls
spawn or remove visible creatures, and biomass controls affect both biome color
and plant resource counts.

## Current Scope

The current model is intentionally biome-level. It tracks populations and
average traits per biome, not full individual genetics.

The model is meant to support:

- readable cause and effect
- quick tuning through `GameBalance`
- manual testing through the debug panel
- future expansion into richer food webs and evolution

## Not In Scope

The current prototype does not include:

- full genetics for individual creatures
- migration between biomes
- multiple predator species
- seasons
- disease
- individual-by-individual reproduction
- full 3D

## Future Extension Notes

Good next steps include:

- making visible vegetation counts smoother over time
- adding more plant resource types
- making resource spawning more strongly biome-specific
- exposing selected biome controls in the debug panel
- adding migration pressure between neighboring biomes
- adding more ecosystem events to save data if message cooldowns become
  gameplay-relevant
- connecting future species data to the same trait-loading pattern
