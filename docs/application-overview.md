# Apex Shift 2D - Application Overview

This document describes the current playable prototype, its core mechanics, and the gameplay values that drive those mechanics. It is meant to be a practical reference for future implementation work.

## High-Level Summary

Apex Shift 2D is a top-down survival prototype built in Godot. The player explores a large biome-based field, collects resources, crafts survival tools, avoids or fights Varnaks, and interacts with an ecosystem made of vegetation, small prey, grazers, predators, ponds, hills, and biome-specific resource pressure.

The main gameplay loop is:

1. Explore the world and read biome danger from color, resources, landmarks, and maps.
2. Gather wood, stone, fiber, berries, grass, and meat from visible world resources.
3. Craft survival items such as spear, torch, campfire, tent, traps, walls, storage, and bow.
4. Manage health, hunger, stamina, and rest while day and night advance.
5. Watch ecosystem state change as animals eat plants, predators hunt, and vegetation biomass rises or collapses.
6. Use the HUD, minimap, field map, and debug panel to inspect and test gameplay systems.

## Project Entry Points

| Area | Main files |
| --- | --- |
| Main scene | `scenes/main.tscn` |
| Game orchestration | `scripts/game_manager.gd` |
| World generation and resources | `scripts/world/world.gd`, `scripts/world/world_config.gd`, `scripts/world/resource_node.gd` |
| Player | `scripts/player/player.gd`, `scripts/player/player_stats.gd` |
| Survival balance | `scripts/systems/game_balance.gd` |
| Day/night | `scripts/systems/day_night_system.gd` |
| Ecosystem simulation | `scripts/systems/ecosystem_director.gd` |
| Creature diet helper | `scripts/creatures/hunger_diet.gd` |
| Creatures | `scripts/creatures/varnak.gd`, `scripts/creatures/small_prey.gd`, `scripts/creatures/grazer.gd` |
| Projectiles | `scripts/projectiles/arrow_projectile.gd`, `scenes/projectiles/arrow_projectile.tscn` |
| HUD and maps | `scripts/ui/hud.gd`, `scripts/ui/minimap.gd`, `scripts/ui/map_screen.gd`, `scripts/ui/debug_panel.gd` |
| Save/load | `scripts/systems/save_system.gd` |
| Data | `data/items.json`, `data/recipes.json`, `data/species/*.json`, `data/species_varnak.json` |

## Parameter Name Index

This section maps readable gameplay names to the actual parameter names used in code. Use it when changing balance values or when tracing visible behavior back to a script constant.

### Crafting Parameters

| Parameter name | Value |
| --- | --- |
| `GameBalance.CRAFTING_COSTS.campfire.wood` | 3 |
| `GameBalance.CRAFTING_COSTS.campfire.stone` | 2 |
| `GameBalance.CRAFTING_COSTS.spear.wood` | 2 |
| `GameBalance.CRAFTING_COSTS.spear.stone` | 1 |
| `GameBalance.CRAFTING_COSTS.spear.fiber` | 1 |
| `GameBalance.CRAFTING_COSTS.torch.wood` | 1 |
| `GameBalance.CRAFTING_COSTS.torch.fiber` | 1 |
| `GameBalance.CRAFTING_COSTS.bow.wood` | 3 |
| `GameBalance.CRAFTING_COSTS.bow.fiber` | 4 |
| `GameBalance.CRAFTING_COSTS.bow.bone` | 1 |
| `GameBalance.CRAFTING_COSTS.cooked_meat.meat` | 1 |
| `GameBalance.CRAFTING_COSTS.basic_trap.wood` | 2 |
| `GameBalance.CRAFTING_COSTS.basic_trap.fiber` | 2 |
| `GameBalance.CRAFTING_COSTS.trap.wood` | 2 |
| `GameBalance.CRAFTING_COSTS.trap.fiber` | 2 |
| `GameBalance.CRAFTING_COSTS.wall.wood` | 3 |
| `GameBalance.CRAFTING_COSTS.storage_box.wood` | 4 |
| `GameBalance.CRAFTING_COSTS.tent.wood` | 4 |
| `GameBalance.CRAFTING_COSTS.tent.fiber` | 3 |

### Player And Survival Parameters

| Parameter name | Value |
| --- | ---: |
| `GameBalance.PLAYER_MAX_HEALTH` | 100 |
| `GameBalance.PLAYER_MAX_HUNGER` | 100 |
| `GameBalance.PLAYER_MAX_STAMINA` | 100 |
| `GameBalance.PLAYER_MAX_REST` | 100 |
| `GameBalance.PLAYER_LOW_HUNGER` | 25 |
| `GameBalance.PLAYER_EXHAUSTED_REST` | 20 |
| `GameBalance.PLAYER_HUNGER_DECAY_RATE` | 0.9 |
| `GameBalance.PLAYER_REST_DECAY_RATE` | 0.35 |
| `GameBalance.PLAYER_RUNNING_REST_DECAY_RATE` | 0.9 |
| `GameBalance.PLAYER_RUNNING_STAMINA_DECAY_RATE` | 18 |
| `GameBalance.PLAYER_STARVATION_DAMAGE_PER_SECOND` | 3 |
| `GameBalance.PLAYER_HEALTH_REGEN_RATE` | 0.45 |
| `GameBalance.PLAYER_MEAT_NUTRITION` | 32 |
| `GameBalance.PLAYER_SLEEP_HUNGER_COST` | 8 |
| `GameBalance.PLAYER_SLEEP_HEALTH_RESTORE` | 35 |
| `GameBalance.PLAYER_LOW_HUNGER_SPEED_MULTIPLIER` | 0.82 |
| `GameBalance.PLAYER_EXHAUSTED_REST_SPEED_MULTIPLIER` | 0.85 |
| `GameBalance.PLAYER_BASE_STAMINA_REGEN` | 16 |
| `GameBalance.PLAYER_LOW_HUNGER_STAMINA_REGEN_MULTIPLIER` | 0.45 |
| `GameBalance.PLAYER_EXHAUSTED_REST_STAMINA_REGEN_MULTIPLIER` | 0.55 |
| `Player.walk_speed` | 180 |
| `Player.run_speed` | 290 |

### Combat Parameters

| Parameter name | Value |
| --- | ---: |
| `Player.ATTACK_RANGE` | 72 |
| `Player.ATTACK_ARC` | 82 degrees |
| `Player.ATTACK_VISUAL_DURATION` | 0.16 |
| `GameBalance.SPEAR_ATTACK_COOLDOWN` | 0 |
| `GameBalance.TRAP_DAMAGE` | 120 |
| `GameBalance.TRAP_EFFECT_DURATION` | 0 |
| `GameBalance.RANGED_COMBAT.bow_damage` | 28 |
| `GameBalance.RANGED_COMBAT.bow_cooldown_seconds` | 0.75 |
| `GameBalance.RANGED_COMBAT.bow_stamina_cost` | 8 |
| `GameBalance.RANGED_COMBAT.arrow_speed` | 780 |
| `GameBalance.RANGED_COMBAT.arrow_lifetime_seconds` | 1.25 |
| `GameBalance.RANGED_COMBAT.arrow_max_range` | 900 |
| `GameBalance.RANGED_COMBAT.arrow_hit_radius` | 8 |

### Torch, Campfire, And Adaptation Parameters

| Parameter name | Value |
| --- | ---: |
| `GameBalance.TORCH_DURATION_SECONDS` | 45 |
| `GameBalance.TORCH_SAFE_RADIUS` | 96 |
| `GameBalance.TORCH_DETECTION_RANGE_MULTIPLIER` | 0.65 |
| `GameBalance.TORCH_AGGRESSION_MULTIPLIER` | 0.7 |
| `GameBalance.TORCH_CLOSE_CHASE_RANGE_MULTIPLIER` | 0.65 |
| `GameBalance.TORCH_ATTACK_COOLDOWN_MULTIPLIER` | 1.5 |
| `GameBalance.TORCH_FLEE_SPEED_MULTIPLIER` | 0.85 |
| `GameBalance.TORCH_LIGHT_RADIUS` | 105 |
| `GameBalance.TORCH_LIGHT_INTENSITY` | 0.7 |
| `GameBalance.TORCH_LIGHT_OFFSET` | `(18, 0)` |
| `GameBalance.TORCH_LIGHT_BASE_STRENGTH` | 0.22 |
| `GameBalance.TORCH_LIGHT_NIGHT_STRENGTH` | 0.58 |
| `GameBalance.TORCH_LIGHT_FLICKER_BASE` | 0.9 |
| `GameBalance.TORCH_LIGHT_FLICKER_PRIMARY_SPEED` | 0.018 |
| `GameBalance.TORCH_LIGHT_FLICKER_PRIMARY_AMOUNT` | 0.08 |
| `GameBalance.TORCH_LIGHT_FLICKER_SECONDARY_SPEED` | 0.031 |
| `GameBalance.TORCH_LIGHT_FLICKER_SECONDARY_AMOUNT` | 0.02 |
| `GameBalance.TORCH_LIGHT_OUTER_ALPHA` | 0.10 |
| `GameBalance.TORCH_LIGHT_MID_RADIUS_MULTIPLIER` | 0.58 |
| `GameBalance.TORCH_LIGHT_MID_ALPHA` | 0.16 |
| `GameBalance.TORCH_LIGHT_CORE_RADIUS_MULTIPLIER` | 0.24 |
| `GameBalance.TORCH_LIGHT_CORE_ALPHA` | 0.24 |
| `GameBalance.CAMPFIRE_SAFE_RADIUS` | 150 |
| `GameBalance.CAMPFIRE_LIGHT_RADIUS` | 165 |
| `GameBalance.CAMPFIRE_FUEL_BURN_RATE` | 1 |
| `GameBalance.NIGHT_DANGER_MULTIPLIER` | 1.2 |
| `GameBalance.ADAPTATION_DEBUG_GROWTH` | 0.05 |
| `GameBalance.ADAPTATION_TRAP_AWARENESS_GROWTH` | 0.15 |
| `GameBalance.ADAPTATION_FIRE_FEAR_DELTA` | -0.10 |
| `GameBalance.ADAPTATION_STALK_TENDENCY_GROWTH` | 0.10 |
| `GameBalance.ADAPTATION_PLAYER_AGGRESSION_GROWTH` | 0.10 |
| `GameBalance.ADAPTATION_PACK_COORDINATION_GROWTH` | 0.10 |
| `GameBalance.ADAPTATION_WALL_CURIOSITY_GROWTH` | 0.10 |

### Day And Night Parameters

| Parameter name | Value |
| --- | ---: |
| `DayNightSystem.day_length_seconds` | 120 |
| `DayNightSystem.START_HOUR` | 8 |
| `DayNightSystem.MORNING_HOUR` | 6 |
| `DayNightSystem.NIGHT_HOUR` | 20 |
| `DayNightSystem.DAWN_START_HOUR` | 5 |
| `DayNightSystem.DUSK_END_HOUR` | 21 |
| `DayNightSystem.DEBUG_PHASE_HOURS` | `[6, 20, 21, 5]` |

### World And Resource Spawn Parameters

| Parameter name | Value |
| --- | ---: |
| `WorldConfig.WORLD_SCALE` | 2.2 |
| `WorldConfig.BASE_WORLD_RECT` | `Rect2(-1440, -880, 2880, 1760)` |
| `WorldConfig.WORLD_RECT` | `BASE_WORLD_RECT * WORLD_SCALE` |
| `WorldConfig.PLAYER_EDGE_PADDING` | 40 |
| `WorldConfig.TREE_COUNT` | 48 |
| `WorldConfig.ROCK_COUNT` | 24 |
| `WorldConfig.BUSH_COUNT` | 36 |
| `WorldConfig.SMALL_BUSH_COUNT` | 28 |
| `WorldConfig.BERRY_BUSH_COUNT` | 14 |
| `WorldConfig.GRASS_PATCH_COUNT` | 72 |
| `WorldConfig.DENSE_GRASS_COUNT` | 34 |
| `WorldConfig.RESOURCE_SPAWN_MARGIN` | 95 |
| `WorldConfig.RESOURCE_MIN_DISTANCE` | 90 |
| `WorldConfig.RESOURCE_PLAYER_SAFE_DISTANCE` | 260 |
| `WorldConfig.RESOURCE_SPAWN_ATTEMPTS` | 120 |
| `GameBalance.LIVING_WORLD.world_scale` | 2.2 |
| `GameBalance.LIVING_WORLD.tree_density_per_world_area` | 0.0000035 |
| `GameBalance.LIVING_WORLD.rock_density_per_world_area` | 0.0000018 |
| `GameBalance.LIVING_WORLD.bush_density_per_world_area` | 0.0000026 |
| `GameBalance.LIVING_WORLD.grass_patch_density_per_world_area` | 0.000010 |
| `GameBalance.LIVING_WORLD.dense_vegetation_zone_bonus` | 1.35 |
| `GameBalance.LIVING_WORLD.resource_spawn_margin` | 95 |
| `GameBalance.LIVING_WORLD.resource_min_distance` | 90 |
| `GameBalance.LIVING_WORLD.resource_player_safe_distance` | 260 |
| `GameBalance.LIVING_WORLD.resource_spawn_attempts` | 120 |

### Creature Spawn Parameters

| Parameter name | Value |
| --- | ---: |
| `WorldConfig.VARNAK_TARGET_COUNT` | 8 |
| `WorldConfig.VARNAK_PLAYER_SAFE_DISTANCE` | 560 |
| `WorldConfig.VARNAK_SPAWN_ATTEMPTS` | 36 |
| `WorldConfig.VARNAK_SPAWN_POINTS` | 16 points |
| `GameBalance.LIVING_WORLD.small_prey_visible_spawn_radius` | 850 |
| `GameBalance.LIVING_WORLD.small_prey_player_safe_distance` | 240 |
| `GameBalance.LIVING_WORLD.small_prey_min_distance` | 190 |
| `GameBalance.LIVING_WORLD.grazer_visible_spawn_radius` | 1000 |
| `GameBalance.LIVING_WORLD.grazer_player_safe_distance` | 340 |
| `GameBalance.LIVING_WORLD.grazer_min_distance` | 300 |
| `GameBalance.LIVING_WORLD.varnak_player_safe_distance` | 560 |
| `GameBalance.LIVING_WORLD.varnak_spawn_attempts` | 36 |

### Animal AI Parameters

| Parameter name | Value |
| --- | ---: |
| `GameBalance.ANIMAL_AI.grass_food_value` | 0.20 |
| `GameBalance.ANIMAL_AI.bush_food_value` | 0.45 |
| `GameBalance.ANIMAL_AI.tree_food_value` | 0.10 |
| `GameBalance.ANIMAL_AI.meat_food_value` | 0.65 |
| `GameBalance.ANIMAL_AI.scavenger_food_value` | 0.55 |
| `GameBalance.ANIMAL_AI.hungry_threshold` | 0.35 |
| `GameBalance.ANIMAL_AI.starving_threshold` | 0.60 |
| `GameBalance.ANIMAL_AI.desperate_threshold` | 0.82 |
| `GameBalance.ANIMAL_AI.food_search_radius` | 520 |
| `GameBalance.ANIMAL_AI.desperate_food_search_radius` | 780 |
| `GameBalance.ANIMAL_AI.prey_detect_radius` | 260 |
| `GameBalance.ANIMAL_AI.water_search_radius` | 680 |
| `GameBalance.VARNAK_HUNTING.hunger_growth_rate` | 0.18 |
| `GameBalance.VARNAK_HUNTING.hungry_threshold` | 0.32 |
| `GameBalance.VARNAK_HUNTING.starving_threshold` | 0.58 |
| `GameBalance.VARNAK_HUNTING.desperate_threshold` | 0.80 |
| `GameBalance.VARNAK_HUNTING.prey_detect_radius` | 620 |
| `GameBalance.VARNAK_HUNTING.player_intrusion_radius` | 240 |
| `GameBalance.VARNAK_HUNTING.prey_chase_priority` | 0.65 |
| `GameBalance.VARNAK_HUNTING.player_chase_priority` | 0.85 |
| `GameBalance.VARNAK_HUNTING.night_hunting_multiplier` | 1.25 |
| `GameBalance.VARNAK_HUNTING.fire_avoidance_priority` | 1.10 |
| `GameBalance.VARNAK_HUNTING.torch_avoidance_priority` | 0.75 |

### Small Prey Parameters

| Parameter name | Value |
| --- | ---: |
| `SmallPrey.WANDER_RADIUS` | 140 |
| `SmallPrey.WANDER_REACHED_DISTANCE` | 18 |
| `SmallPrey.PLAYER_FLEE_RANGE` | 130 |
| `SmallPrey.VARNAK_FLEE_RANGE` | 180 |
| `SmallPrey.EAT_INTERVAL_SECONDS` | 6 |
| `SmallPrey.EAT_DURATION_SECONDS` | 1.1 |
| `SmallPrey.IDLE_DURATION_SECONDS` | 0.8 |
| `SmallPrey.VEGETATION_EAT_RANGE` | 170 |
| `SmallPrey.VEGETATION_CONSUME_RANGE` | 26 |
| `SmallPrey.WORLD_EDGE_PADDING` | 24 |
| `SmallPrey.AVOIDANCE_LOOKAHEAD_DISTANCE` | 46 |
| `SmallPrey.WALL_AVOID_RADIUS` | 58 |
| `SmallPrey.BIOME_RETURN_CHANCE` | 0.64 |
| `data/species/small_prey.json.health` | 20 |
| `data/species/small_prey.json.speed` | 90 |
| `data/species/small_prey.json.fear` | 0.90 |
| `data/species/small_prey.json.hunger_growth_rate` | 0.20 |
| `data/species/small_prey.json.diet_profile.plant` | 1.00 |
| `data/species/small_prey.json.diet_profile.meat` | 0 |
| `data/species/small_prey.json.diet_profile.scavenger` | 0 |
| `data/species/small_prey.json.plant_consumption_rate` | 0.40 |
| `data/species/small_prey.json.reproduction_rate` | 0.60 |

### Grazer Parameters

| Parameter name | Value |
| --- | ---: |
| `Grazer.WANDER_RADIUS` | 190 |
| `Grazer.WANDER_REACHED_DISTANCE` | 22 |
| `Grazer.PLAYER_FLEE_RANGE` | 105 |
| `Grazer.VARNAK_FLEE_RANGE` | 220 |
| `Grazer.LOW_BIOMASS_PERCENT` | 35 |
| `Grazer.EAT_DURATION_SECONDS` | 1.4 |
| `Grazer.SCAVENGE_DURATION_SECONDS` | 1.8 |
| `Grazer.IDLE_DURATION_SECONDS` | 0.9 |
| `Grazer.SMALL_PREY_DETECT_RANGE` | 220 |
| `Grazer.SMALL_PREY_ATTACK_RANGE` | 28 |
| `Grazer.PLANT_EAT_HUNGER_DROP` | 0.45 |
| `Grazer.MEAT_HUNGER_DROP` | 0.65 |
| `Grazer.VEGETATION_EAT_RANGE` | 220 |
| `Grazer.VEGETATION_CONSUME_RANGE` | 34 |
| `Grazer.WORLD_EDGE_PADDING` | 28 |
| `Grazer.AVOIDANCE_LOOKAHEAD_DISTANCE` | 62 |
| `Grazer.WALL_AVOID_RADIUS` | 78 |
| `Grazer.BIOME_RETURN_CHANCE` | 0.58 |
| `data/species/grazer.json.health` | 45 |
| `data/species/grazer.json.speed` | 70 |
| `data/species/grazer.json.fear` | 0.70 |
| `data/species/grazer.json.aggression` | 0.15 |
| `data/species/grazer.json.hunger_growth_rate` | 0.30 |
| `data/species/grazer.json.plant_consumption_rate` | 1.20 |
| `data/species/grazer.json.diet_profile.plant` | 0.85 |
| `data/species/grazer.json.diet_profile.meat` | 0.05 |
| `data/species/grazer.json.diet_profile.scavenger` | 0.10 |
| `data/species/grazer.json.size` | 1.35 |
| `data/species/grazer.json.reproduction_rate` | 0.35 |
| `data/species/grazer.json.evolution.mutation_rate` | 0.03 |
| `data/species/grazer.json.evolution.diet_shift` | 0.02 |

### Ecosystem Parameters

| Parameter name | Value |
| --- | ---: |
| `GameBalance.ECOSYSTEM.simulation_tick_seconds` | 5 |
| `GameBalance.ECOSYSTEM.default_plant_biomass` | 100 |
| `GameBalance.ECOSYSTEM.max_plant_biomass` | 100 |
| `GameBalance.ECOSYSTEM.plant_regrowth_rate` | 1.5 |
| `GameBalance.ECOSYSTEM.initial_small_prey_population` | 12 |
| `GameBalance.ECOSYSTEM.initial_grazer_population` | 4 |
| `GameBalance.ECOSYSTEM.small_prey_plant_consumption` | 0.08 |
| `GameBalance.ECOSYSTEM.grazer_plant_consumption` | 0.35 |
| `GameBalance.ECOSYSTEM.overgrazing_pressure_scale` | 10 |
| `GameBalance.ECOSYSTEM.small_prey_growth_rate` | 0.75 |
| `GameBalance.ECOSYSTEM.small_prey_predation_rate` | 1.15 |
| `GameBalance.ECOSYSTEM.small_prey_collapse_biomass_factor` | 0.12 |
| `GameBalance.ECOSYSTEM.small_prey_collapse_loss_rate` | 0.65 |
| `GameBalance.ECOSYSTEM.grazer_growth_rate` | 0.32 |
| `GameBalance.ECOSYSTEM.grazer_starvation_rate` | 0.70 |
| `GameBalance.ECOSYSTEM.grazer_predation_rate` | 0.65 |
| `GameBalance.ECOSYSTEM.max_small_prey_population` | 30 |
| `GameBalance.ECOSYSTEM.max_grazer_population` | 14 |
| `GameBalance.ECOSYSTEM.stressed_threshold` | 70 |
| `GameBalance.ECOSYSTEM.depleted_threshold` | 30 |
| `GameBalance.ECOSYSTEM.collapsing_threshold` | 10 |
| `GameBalance.ECOSYSTEM.grazer_food_stress_threshold` | 30 |
| `GameBalance.ECOSYSTEM.grazer_niche_shift_threshold` | 0.45 |
| `GameBalance.ECOSYSTEM.grazer_diet_shift_rate` | 0.04 |
| `GameBalance.ECOSYSTEM.grazer_aggression_shift_rate` | 0.015 |
| `GameBalance.ECOSYSTEM.population_decline_event_min_delta` | 0.10 |
| `GameBalance.ECOSYSTEM.tree_biomass_impact` | 4 |
| `GameBalance.ECOSYSTEM.bush_biomass_impact` | 1 |
| `GameBalance.ECOSYSTEM.small_bush_biomass_impact` | 0.45 |
| `GameBalance.ECOSYSTEM.berry_bush_biomass_impact` | 0.55 |
| `GameBalance.ECOSYSTEM.dry_bush_biomass_impact` | 0.25 |
| `GameBalance.ECOSYSTEM.grass_biomass_impact` | 0.15 |
| `GameBalance.ECOSYSTEM.initial_average_plant_diet` | 0.85 |
| `GameBalance.ECOSYSTEM.initial_average_meat_diet` | 0.05 |
| `GameBalance.ECOSYSTEM.initial_average_scavenger_diet` | 0.10 |
| `GameBalance.ECOSYSTEM.initial_average_aggression` | 0.15 |
| `GameBalance.ECOSYSTEM.max_omnivore_resilience` | 0.85 |
| `GameBalance.ECOSYSTEM.grazer_meat_diet_shift_ratio` | 0.65 |
| `GameBalance.ECOSYSTEM.grazer_scavenger_diet_shift_ratio` | 0.35 |
| `GameBalance.ECOSYSTEM.debug_plant_biomass_delta` | 25 |
| `GameBalance.ECOSYSTEM.debug_small_prey_population_delta` | 3 |
| `GameBalance.ECOSYSTEM.debug_grazer_population_delta` | 2 |
| `GameBalance.ECOSYSTEM.debug_forced_food_stress_margin` | 5 |
| `GameBalance.ECOSYSTEM.debug_forced_niche_plant_diet` | 0.58 |
| `GameBalance.ECOSYSTEM.debug_forced_niche_meat_diet` | 0.28 |
| `GameBalance.ECOSYSTEM.debug_forced_niche_scavenger_diet` | 0.14 |
| `GameBalance.ECOSYSTEM.debug_min_population_floor` | 1 |
| `GameBalance.DEBUG_PLAYER_DAMAGE_AMOUNT` | 25 |
| `GameBalance.DEBUG_PLAYER_HEAL_AMOUNT` | 25 |
| `GameBalance.DEBUG_PLAYER_HUNGER_ENERGY_AMOUNT` | 25 |

### Resource Regrowth Parameters

| Parameter name | Value |
| --- | --- |
| `GameBalance.RESOURCE_REGROWTH.stages` | `["depleted", "sprout", "young", "mature"]` |
| `GameBalance.RESOURCE_REGROWTH.days_per_growth_stage` | 1 |
| `GameBalance.RESOURCE_REGROWTH.yield_by_growth_stage.depleted` | 0 |
| `GameBalance.RESOURCE_REGROWTH.yield_by_growth_stage.sprout` | 0.25 |
| `GameBalance.RESOURCE_REGROWTH.yield_by_growth_stage.young` | 0.60 |
| `GameBalance.RESOURCE_REGROWTH.yield_by_growth_stage.mature` | 1 |
| `GameBalance.RESOURCE_REGROWTH.grass_regrowth_time_days` | 1 |
| `GameBalance.RESOURCE_REGROWTH.bush_regrowth_time_days` | 2 |
| `GameBalance.RESOURCE_REGROWTH.tree_regrowth_time_days` | 3 |
| `GameBalance.RESOURCE_REGROWTH.dry_bush_regrowth_time_days` | 3 |
| `GameBalance.RESOURCE_REGROWTH.growth_tick_seconds` | 5 |
| `ResourceNode.item_name` | Exported resource item id |
| `ResourceNode.amount` | Exported default yield |
| `ResourceNode.color` | Exported draw color |
| `ResourceNode.radius` | Exported draw radius |

### Landmark And Biome Parameters

| Parameter name | Meaning |
| --- | --- |
| `WorldConfig.LANDMARKS[].id` | Landmark id |
| `WorldConfig.LANDMARKS[].type` | `hill` or `pond` |
| `WorldConfig.LANDMARKS[].position` | Base unscaled world position |
| `WorldConfig.LANDMARKS[].radius` | Base unscaled radius |
| `WorldConfig.LANDMARKS[].biome_id` | Owning biome id |
| `WorldConfig.LANDMARKS[].gameplay_tags` | Gameplay tags |
| `WorldConfig.BIOME_ZONES[].name` | Display name |
| `WorldConfig.BIOME_ZONES[].points` | Base unscaled polygon points |
| `WorldConfig.BIOME_ZONES[].color` | Biome terrain color |
| `WorldConfig.BIOME_ZONES[].tree_weight` | Tree spawn weighting |
| `WorldConfig.BIOME_ZONES[].rock_weight` | Rock spawn weighting |
| `WorldConfig.BIOME_ZONES[].bush_weight` | Bush spawn weighting |
| `WorldConfig.BIOME_ZONES[].grass_weight` | Grass spawn weighting |
| `WorldConfig.BIOME_ZONES[].dangerous` | Whether the biome is dangerous |
| `GameBalance.LANDMARKS.hill_count` | 8 |
| `GameBalance.LANDMARKS.pond_count` | 5 |
| `GameBalance.LANDMARKS.dense_vegetation_zone_count` | 7 |
| `GameBalance.LANDMARKS.animal_hotspot_count` | 4 |
| `GameBalance.LANDMARKS.hill_spawn_margin` | 220 |
| `GameBalance.LANDMARKS.pond_spawn_margin` | 260 |
| `GameBalance.LANDMARKS.landmark_min_distance` | 420 |
| `GameBalance.LANDMARKS.pond_vegetation_bonus` | 2 |
| `GameBalance.LANDMARKS.pond_vegetation_base_count` | 14 |
| `GameBalance.LANDMARKS.pond_vegetation_min_distance` | 28 |
| `GameBalance.LANDMARKS.pond_vegetation_player_safe_distance` | 36 |
| `GameBalance.LANDMARKS.pond_vegetation_inner_ring_factor` | 1.18 |
| `GameBalance.LANDMARKS.pond_vegetation_outer_ring_factor` | 1.48 |
| `GameBalance.LANDMARKS.pond_grass_food_bonus` | 1.45 |
| `GameBalance.LANDMARKS.pond_vegetation_visual_scale` | 1.28 |
| `GameBalance.LANDMARKS.dense_vegetation_resource_bonus` | 1.60 |
| `GameBalance.LANDMARKS.animal_hotspot_population_bonus` | 1.25 |

### Loot Parameters

| Parameter name | Value |
| --- | ---: |
| `GameBalance.ANIMAL_LOOT.small_prey.meat_min` | 1 |
| `GameBalance.ANIMAL_LOOT.small_prey.meat_max` | 1 |
| `GameBalance.ANIMAL_LOOT.grazer.meat_min` | 2 |
| `GameBalance.ANIMAL_LOOT.grazer.meat_max` | 3 |
| `GameBalance.ANIMAL_LOOT.varnak.meat_min` | 2 |
| `GameBalance.ANIMAL_LOOT.varnak.meat_max` | 4 |

## Controls

| Input | Behavior |
| --- | --- |
| Movement keys | Move the player. |
| Run input | Uses running speed while stamina, hunger, and rest allow it. |
| Space | Melee attack. |
| Left mouse | Shoots the bow if the player has a bow, otherwise performs a melee attack. |
| Key 1 | Craft campfire. |
| Key 2 | Craft spear. |
| Key 3 | Eat meat. |
| Key 4 | Sleep in a tent when allowed. |
| Key 5 | Craft trap. |
| Key 6 | Craft tent. |
| Key 7 | Eat available food. |
| Key 8 | Craft torch. |
| Key 9 | Craft bow. |
| Torch activation input | Activates the torch when one is available. |
| Debug/map inputs | Open debug tools, minimap, and full field map depending on current input mapping. |

## Player Stats

Player stats are managed by `PlayerStats` and balanced through `GameBalance.PLAYER_STATS`.

| Value | Number |
| --- | ---: |
| Max health | 100 |
| Max hunger | 100 |
| Max stamina | 100 |
| Max rest | 100 |
| Low hunger threshold | 25 |
| Exhausted rest threshold | 20 |
| Hunger decay | 0.9 per second |
| Rest decay | 0.35 per second |
| Running rest decay | 0.9 per second |
| Running stamina decay | 18 per second |
| Starvation damage | 3 per second |
| Health regeneration | 0.45 per second |
| Meat nutrition | 32 |
| Sleep hunger cost | 8 |
| Sleep health restore | 35 |
| Low hunger speed multiplier | 0.82 |
| Exhausted rest speed multiplier | 0.85 |
| Base stamina regeneration | 16 per second |
| Low hunger stamina regeneration multiplier | 0.45 |
| Exhausted rest stamina regeneration multiplier | 0.55 |

Important behavior:

- Hunger and rest decay continuously.
- Running drains stamina and rest faster.
- The player can run only if stamina is above 1, hunger is above 5, and rest is above 5.
- Health regenerates only when hunger is at or above the low hunger threshold and rest is at or above the exhausted threshold.
- Starvation damages the player when hunger reaches zero.
- Low hunger and exhausted rest slow the player and reduce stamina recovery.

## Player Movement And Water

The player moves on land with normal walking and running speeds. Water areas are handled as visible pond landmarks and use the same shape logic for rendering, spawning, and movement checks.

Water is split into zones:

| Zone | Meaning | Speed multiplier |
| --- | --- | ---: |
| Land | Normal movement area | 1.00 |
| Shore | Visual transition band around ponds | 1.00 |
| Shallow water | Traversable water with penalty | 0.68 |
| Deep water | Full water body and strongest penalty | 0.42 |

Important behavior:

- Vegetation is blocked from spawning inside the visible pond water shape.
- Trees, bushes, and grass use wider pond-water margins than pond shore visuals.
- Deep water blocks creature navigation and spawn placement.
- Shallow water is traversable, but it visibly slows movement.
- Sprinting is disabled while swimming.
- Swimming uses a distinct body pose plus ripple feedback so the state is obvious.
- Pond vegetation is spawned around the perimeter, not inside the open water body.

## Combat

### Melee

Melee attack behavior is handled in the player script.

| Value | Number |
| --- | ---: |
| Attack range | 72 |
| Attack arc | 82 degrees |
| Attack visual duration | 0.16 seconds |
| Bare-handed damage | 18 |
| Spear damage | 38 |
| Melee stamina cost | 12 |

Important behavior:

- The player can attack with bare hands or with a spear.
- Spear attacks deal higher damage.
- Melee attacks consume stamina.
- Hits are arc-based and affect valid nearby creature targets.

### Bow And Arrows

Bow crafting and arrow combat are balanced by `GameBalance.RANGED_COMBAT`.

| Value | Number |
| --- | ---: |
| Bow damage | 28 |
| Bow cooldown | 0.75 seconds |
| Bow stamina cost | 8 |
| Arrow speed | 780 |
| Arrow lifetime | 1.25 seconds |
| Arrow max range | 900 |
| Arrow hit radius | 8 |

Important behavior:

- The bow is crafted with resources and grants ranged attacks.
- The current bow uses infinite arrows.
- Left mouse fires the bow when the player has one.
- Arrow projectiles damage Varnaks, small prey, and grazers.
- Arrows are removed after impact, lifetime expiration, or max range.

### Traps

| Value | Number |
| --- | ---: |
| Trap damage | 120 |
| Trap effect duration | 0 |
| Trap awareness growth | 0.15 |

Traps are craftable world objects. They can deal strong damage and contribute to Varnak adaptation pressure.

## Crafting

Crafting costs are defined in `GameBalance.CRAFTING_COSTS`.

| Item | Wood | Stone | Fiber | Meat | Hide | Bone |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Campfire | 3 | 2 | 0 | 0 | 0 | 0 |
| Spear | 2 | 1 | 1 | 0 | 0 | 0 |
| Torch | 1 | 0 | 1 | 0 | 0 | 0 |
| Bow | 3 | 0 | 4 | 0 | 0 | 1 |
| Cooked meat | 0 | 0 | 0 | 1 | 0 | 0 |
| Basic trap | 2 | 0 | 2 | 0 | 0 | 0 |
| Trap | 2 | 0 | 2 | 0 | 0 | 0 |
| Wall | 3 | 0 | 0 | 0 | 0 | 0 |
| Storage box | 4 | 0 | 0 | 0 | 0 | 0 |
| Tent | 4 | 0 | 3 | 0 | 0 | 0 |

Recipes are also represented in `data/recipes.json`, while item metadata is stored in `data/items.json`.

## Items And Inventory

Core resources:

| Item | Main source |
| --- | --- |
| Wood | Trees, conifers, leafy trees |
| Stone | Rocks |
| Fiber | Bushes and dry bushes |
| Meat | Creature deaths and meat drops |
| Hide | Inventory item reserved for survival crafting |
| Bone | Inventory item used by the bow recipe |
| Berries | Berry bushes, currently not player-harvestable unless changed |
| Grass | Grass patches and dense grass, currently animal food |

Creature meat drops are defined by `GameBalance.ANIMAL_LOOT`.

| Creature | Meat drop |
| --- | ---: |
| Small prey | 1 to 1 |
| Grazer | 2 to 3 |
| Varnak | 2 to 4 |

## Fire, Torch, And Campfire

### Torch Values

| Value | Number |
| --- | ---: |
| Duration | 45 seconds |
| Safe radius | 96 |
| Detection range multiplier | 0.65 |
| Aggression multiplier | 0.7 |
| Close chase range multiplier | 0.65 |
| Attack cooldown multiplier | 1.5 |
| Flee speed multiplier | 0.85 |
| Light radius | 105 |
| Light intensity | 0.7 |
| Light offset | `(18, 0)` |
| Base light strength | 0.22 |
| Night light strength | 0.58 |
| Flicker base | 0.9 |
| Flicker primary speed | 0.018 |
| Flicker primary amount | 0.08 |
| Flicker secondary speed | 0.031 |
| Flicker secondary amount | 0.02 |
| Outer alpha | 0.10 |
| Mid radius multiplier | 0.58 |
| Mid alpha | 0.16 |
| Core radius multiplier | 0.24 |
| Core alpha | 0.24 |

Torch behavior:

- A torch creates a temporary safe zone.
- It reduces Varnak detection, aggression, and close chase pressure.
- It increases attack cooldown and can slow fleeing behavior around fire.
- It provides visible light with flicker.

### Campfire Values

| Value | Number |
| --- | ---: |
| Safe radius | 150 |
| Light radius | 165 |
| Fuel burn rate | 1.0 |

Campfire behavior:

- A campfire creates a larger safety radius than a torch.
- It produces a larger light radius.
- It can influence Varnak adaptation through fire fear.

## Day And Night

Day/night behavior is managed by `DayNightSystem`.

| Value | Number |
| --- | ---: |
| Day length | 120 seconds |
| Start hour | 8 |
| Morning hour | 6 |
| Night starts | 20 |
| Dawn starts | 5 |
| Dusk ends | 21 |
| Night danger multiplier | 1.2 |

Phase logic:

| Phase | Condition |
| --- | --- |
| Dawn | Hour is below 6 but not below 5-night label rules |
| Day | Hour is 6 through 19 |
| Dusk | Hour is 20 |
| Night | Hour is 21 or later, or before 5 |

Important behavior:

- Night is active when the hour is at least 20 or below 6.
- Sleeping is available only at night through the tent flow.
- Sleeping advances time to morning hour 6.
- Sleeping emits the end-of-day flow with reason `slept_in_tent`.

## World Size

The playable world is configured in `WorldConfig`.

| Value | Number |
| --- | ---: |
| World scale | 2.2 |
| Base world rect | `Rect2(-1440, -880, 2880, 1760)` |
| Runtime world rect position | `(-3168, -1936)` |
| Runtime world rect size | `(6336, 3872)` |
| Player edge padding | 40 |

## Biomes

Biomes are generated from configured points and zones in `WorldConfig`. Resource generation uses biome weights, and biome state is tracked by the ecosystem director.

| Biome id | Display name | Color | Tree | Rock | Bush | Grass | Danger |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- |
| `westwood` | Westwood | `(0.10, 0.24, 0.13)` | 7 | 1 | 3 | 5 | false |
| `stoneback_ridge` | Stoneback Ridge | `(0.22, 0.25, 0.23)` | 1 | 7 | 1 | 1 | false |
| `hearth_meadow` | Hearth Meadow | `(0.16, 0.30, 0.14)` | 3 | 2 | 4 | 7 | false |
| `south_thicket` | South Thicket | `(0.20, 0.34, 0.12)` | 2 | 1 | 7 | 6 | false |
| `redfang_wilds` | Redfang Wilds | `(0.26, 0.18, 0.13)` | 3 | 4 | 2 | 2 | true |

Biome blending:

- World biome visuals are rendered as a cached blended texture instead of per-frame polygon overlays.
- The cache prevents stuttering from expensive terrain redraws.
- Map and minimap use the same biome and landmark data so the field view and maps remain consistent.
- Vegetation changes are batched so multiple biome updates still produce one redraw pass.

## Landmarks

Landmarks are configured in `WorldConfig` and scaled by `WORLD_SCALE` at runtime.

| Id | Type | Base position | Base radius | Biome | Tags |
| --- | --- | ---: | ---: | --- | --- |
| `westwood_old_hill` | Hill | `(-1120, -430)` | 170 | Westwood | `high_ground`, `navigation` |
| `westwood_shade_pond` | Pond | `(-980, 360)` | 145 | Westwood | `water_source`, `vegetation_bonus` |
| `stoneback_spine` | Hill | `(-180, -640)` | 210 | Stoneback Ridge | `high_ground`, `rocky` |
| `stoneback_basin` | Pond | `(300, -540)` | 115 | Stoneback Ridge | `water_source`, `rare` |
| `hearth_watch_hill` | Hill | `(-260, 40)` | 150 | Hearth Meadow | `high_ground`, `safe_landmark` |
| `hearth_mirror_pond` | Pond | `(230, 120)` | 130 | Hearth Meadow | `water_source`, `vegetation_bonus`, `safe_landmark` |
| `south_thicket_mound` | Hill | `(-180, 600)` | 165 | South Thicket | `high_ground`, `dense_cover` |
| `south_thicket_pool` | Pond | `(310, 620)` | 150 | South Thicket | `water_source`, `vegetation_bonus`, `dense_cover` |
| `redfang_lookout` | Hill | `(940, -520)` | 190 | Redfang Wilds | `high_ground`, `danger` |
| `redfang_teeth` | Hill | `(1050, 460)` | 230 | Redfang Wilds | `high_ground`, `danger`, `navigation` |
| `redfang_darkwater` | Pond | `(910, 60)` | 135 | Redfang Wilds | `water_source`, `danger` |

Landmark reserve values from `GameBalance.LANDMARKS`:

| Value | Number |
| --- | ---: |
| Hill count target | 8 |
| Pond count target | 5 |
| Dense vegetation zone count | 7 |
| Animal hotspot count | 4 |
| Hill spawn margin | 220 |
| Pond spawn margin | 260 |
| Minimum landmark distance | 420 |
| Pond vegetation bonus | 2.0 |
| Pond vegetation base count | 14 |
| Pond vegetation minimum distance | 28 |
| Pond vegetation player safe distance | 36 |
| Pond vegetation inner ring factor | 1.18 |
| Pond vegetation outer ring factor | 1.48 |
| Pond grass food bonus | 1.45 |
| Pond vegetation visual scale | 1.28 |
| Dense vegetation resource bonus | 1.60 |
| Animal hotspot population bonus | 1.25 |

### Landmark Shapes And Visual Rules

Hills and ponds are no longer simple circles. They are drawn and sampled with irregular polygon shapes so the world reads as terrain instead of markers.

| Value | Number |
| --- | ---: |
| Hill resource block radius factor | 0.72 |
| Hill shape irregularity | 0.10 |
| Hill shape sample count | 40 |
| Hill mid elevation factor | 0.70 |
| Hill peak elevation factor | 0.38 |
| Pond deep water radius factor | 0.68 |
| Pond shallow water radius factor | 1.00 |
| Pond shore radius factor | 1.12 |
| Pond deep speed multiplier | 0.42 |
| Pond shallow speed multiplier | 0.68 |
| Pond shape irregularity | 0.16 |
| Pond shape sample count | 48 |
| Pond shore detail count | 18 |
| Pond aquatic vegetation count | 12 |
| Pond vegetation visual scale | 1.28 |

Important behavior:

- Hills are rendered as layered irregular polygons with a lower central peak and softer mid-slope ring.
- Hill obstacle checks use the same shape sampler as the visuals, so resources and creatures avoid the actual hill body.
- Ponds are rendered as layered irregular water shapes with shore, shallow, and deep bands.
- Shore details and aquatic vegetation are drawn around the pond edge so the water no longer reads like a flat puddle.
- The minimap and field map reuse the same shape sampling rules, so the terrain outline stays consistent across views.

Pond vegetation behavior:

- Plants are distributed around the full pond perimeter using balanced angular slots.
- Plants are rejected if they would spawn inside the visible water area.
- Pond vegetation receives stronger food value and larger visuals.
- Pond plants are tagged with the `pond_vegetation` group.

## Resource Generation

Base resource counts in `WorldConfig`:

| Resource | Count |
| --- | ---: |
| Trees | 48 |
| Rocks | 24 |
| Bushes | 36 |
| Small bushes | 28 |
| Berry bushes | 14 |
| Grass patches | 72 |
| Dense grass | 34 |

Resource spawn values:

| Value | Number |
| --- | ---: |
| Spawn margin | 95 |
| Minimum resource distance | 90 |
| Player safe distance | 260 |
| Spawn attempts | 120 |
| Dense vegetation zone bonus | 1.35 |

Density values from `GameBalance.LIVING_WORLD`:

| Resource | Density |
| --- | ---: |
| Tree | 0.0000035 |
| Rock | 0.0000018 |
| Bush | 0.0000026 |
| Grass patch | 0.000010 |

Important resource rules:

- Resources are visible world entities owned by `World`.
- Rocks do not affect plant biomass.
- Plant harvesting affects ecosystem biomass through configured biomass impact.
- Resource cleanup should only remove the harvested resource, not unrelated nearby resources.

## Resource Types

Resource behavior is defined by `ResourceNode`.

| Kind | Item | Mature amount | Regrows | Player harvestable | Food value |
| --- | --- | ---: | --- | --- | ---: |
| `tree` | Wood | 4 | Yes | Yes | 0.10 |
| `conifer_tree` | Wood | 4 | Yes | Yes | 0.10 |
| `leafy_tree` | Wood | 4 | Yes | Yes | 0.10 |
| `rock` | Stone | 2 | No | Yes | 0 |
| `meat_drop` | Meat | 1 default | No | Yes | 0.65 |
| `bush` | Fiber | 2 | Yes | Yes | 0.45 |
| `dry_bush` | Fiber | 1 | Yes | Yes | 0.2025 |
| `small_bush` | Fiber | 1 | Yes | Yes | 0.2925 |
| `berry_bush` | Berries | 1 | Yes | No | 0.405 |
| `grass_patch` | Grass | 1 | Yes | No | 0.20 |
| `dense_grass` | Grass | 1 | Yes | No | 0.30 |

Visual defaults:

| Kind | Mature color | Mature radius |
| --- | --- | ---: |
| `conifer_tree` / `tree` | `(0.08, 0.36, 0.16)` | 24 |
| `leafy_tree` | `(0.16, 0.52, 0.18)` | 24 |
| `rock` | `(0.45, 0.45, 0.50)` | 15 |
| `meat_drop` | `(0.72, 0.12, 0.10)` | 10 |
| `bush` | `(0.45, 0.90, 0.28)` | 13 |
| `dry_bush` | `(0.68, 0.54, 0.26)` | 14 |
| `small_bush` | `(0.34, 0.74, 0.20)` | 10 |
| `berry_bush` | `(0.25, 0.64, 0.23)` | 12 |
| `grass_patch` | Green grass visual | 8 |
| `dense_grass` | Green grass visual | 12 |

## Resource Regrowth

Regrowth is balanced through `GameBalance.RESOURCE_REGROWTH`.

| Value | Number |
| --- | ---: |
| Growth tick | 5 seconds |
| Days per growth stage | 1 |
| Grass regrowth | 1 day |
| Bush regrowth | 2 days |
| Tree regrowth | 3 days |
| Dry bush regrowth | 3 days |

Growth stages:

| Stage | Name | Yield multiplier |
| ---: | --- | ---: |
| 0 | Depleted | 0 |
| 1 | Sprout | 0.25 |
| 2 | Young | 0.60 |
| 3 | Mature | 1.00 |

Important behavior:

- Harvesting a regrowing plant moves it to depleted stage.
- Growth advances over days and periodic growth ticks.
- Stage 0 gives no resources.
- Stages above 0 give scaled yield, with a minimum yield of 1 when a resource is produced.
- Animal consumption can lower a plant by one growth stage.
- Non-regrowing resources are removed after harvesting.

## Ecosystem Simulation

The ecosystem is managed by `EcosystemDirector`. It tracks invisible biome-level state and connects it to visible resources and creatures.

### Core Ecosystem Values

| Value | Number |
| --- | ---: |
| Simulation tick | 5 seconds |
| Default plant biomass | 100 |
| Max plant biomass | 100 |
| Plant regrowth | 1.5 per tick |
| Initial small prey population | 12 |
| Initial grazer population | 4 |
| Small prey plant consumption | 0.08 |
| Grazer plant consumption | 0.35 |
| Overgrazing pressure scale | 10 |
| Small prey growth | 0.75 |
| Small prey predation | 1.15 |
| Small prey collapse biomass factor | 0.12 |
| Small prey collapse loss rate | 0.65 |
| Grazer growth | 0.32 |
| Grazer starvation | 0.70 |
| Grazer predation | 0.65 |
| Max small prey population | 30 |
| Max grazer population | 14 |
| Stressed biomass percent | Below 70 |
| Depleted biomass percent | Below 30 |
| Collapsing biomass percent | Below 10 |
| Grazer food stress threshold | 30 |
| Grazer niche shift threshold | 0.45 |
| Grazer diet shift rate | 0.04 |
| Grazer aggression shift rate | 0.015 |
| Population decline minimum delta | 0.10 |

### Biomass Impact Per Resource

| Resource kind | Biomass impact |
| --- | ---: |
| Tree | 4 |
| Bush | 1 |
| Small bush | 0.45 |
| Berry bush | 0.55 |
| Dry bush | 0.25 |
| Grass | 0.15 |

Rocks have no plant biomass impact.

### Grazer Trait Defaults

| Trait | Value |
| --- | ---: |
| Average plant diet | 0.85 |
| Average meat diet | 0.05 |
| Average scavenger diet | 0.10 |
| Average aggression | 0.15 |
| Max omnivore resilience | 0.85 |
| Grazer meat diet shift ratio | 0.65 |
| Grazer scavenger diet shift ratio | 0.35 |

### Debug Ecosystem Values

| Debug value | Number |
| --- | ---: |
| Plant biomass delta | 25 |
| Small prey delta | 3 |
| Grazer delta | 2 |
| Forced food stress margin | 5 |
| Forced niche plant diet | 0.58 |
| Forced niche meat diet | 0.28 |
| Forced niche scavenger diet | 0.14 |
| Debug minimum population floor | 1 |
| Player damage delta | 25 |
| Player heal delta | 25 |
| Player hunger/energy delta | 25 |

### Ecosystem Tick Behavior

Each simulation tick:

1. Plant consumption is calculated from biome small prey and grazer populations.
2. Plant biomass regrows if it is below max biomass.
3. Biomass is clamped between 0 and 100.
4. Predator pressure is calculated from Varnak presence in the biome.
5. Visible creature aggregates are refreshed from actual biome residents.
6. Small prey and grazer populations change from growth, predation, starvation, and collapse pressure.
7. Biome status changes to healthy, stressed, depleted, or collapsing.
8. Grazer diet and aggression may shift toward omnivory when plant biomass is low.
9. Species generations can advance when pressure stays high long enough.
10. Ecosystem events are emitted for HUD, debug tools, and world reactions.

### Tracked Biome State

Each biome keeps the live values that drive both the visible world and the debug panel:

- `plant_biomass`, `plant_biomass_percent`, `food_stress`, `starvation_pressure`
- `status`
- `small_prey_population`, `grazer_population`, `varnak_population`, `population_count`
- `birth_rate`, `death_rate`
- `average_hunger`, `average_energy`
- `average_small_prey_fear`, `average_small_prey_speed`, `average_small_prey_reproduction`, `average_small_prey_fitness`
- `average_grazer_reproduction`, `average_grazer_fitness`
- `average_varnak_hunger`, `average_varnak_energy`, `average_varnak_fitness`
- `average_varnak_meat_diet`, `average_varnak_scavenger_diet`, `average_varnak_hunt_drive`
- `small_prey_generation`, `grazer_generation`, `varnak_generation`
- `current_niche`, `generations_under_food_stress`, `grazer_pressure_ticks`

### Ecosystem Events

Important events include:

- `ecosystem_biome_stressed`
- `ecosystem_biome_depleted`
- `ecosystem_biome_collapsing`
- `small_prey_population_declining`
- `grazer_population_declining`
- `grazer_niche_shifted`
- `ecosystem_vegetation_changed`
- `plant_resource_harvested`
- `plant_resource_consumed`
- `small_prey_death`
- `grazer_death`
- `varnak_death`

## Animal Hunger And Diet

`HungerDiet` is the shared helper for animal hunger, food preference, energy, and hunger stage.

| Value | Behavior |
| --- | --- |
| Hunger growth | `hunger_growth_rate * delta` |
| Energy drain | `delta * (0.015 + movement_intensity * 0.035)` |
| Energy regeneration | `delta * 0.02 * (1 - hunger_ratio)` |
| Eating | Reduces hunger by `nutrition * preference` |
| Eating energy gain | Adds `nutrition * 0.35` |
| Food choice | Chooses highest `availability * preference` |
| Risk drive | `hunger_ratio * 0.75 + (1 - energy) * 0.25` |

Hunger stages:

| Stage | Threshold |
| --- | ---: |
| Comfortable | Below hungry threshold |
| Hungry | 0.35 |
| Starving | 0.60 |
| Desperate | 0.82 |

Food search values:

| Value | Number |
| --- | ---: |
| Food search radius | 520 |
| Desperate food search radius | 780 |
| Prey detect radius | 260 |
| Water search radius | 680 |

Food values:

| Food | Value |
| --- | ---: |
| Grass | 0.20 |
| Bush | 0.45 |
| Tree | 0.10 |
| Meat | 0.65 |
| Scavenger | 0.55 |

Shared AI decision order:

1. Immediate threats always win over food.
2. A locked target is kept until it becomes invalid or times out, which reduces jitter.
3. Hunger stage decides whether the creature only wanders, searches for food, or becomes desperate.
4. Food is chosen by availability multiplied by diet preference.
5. World bounds, water, hills, and walls are avoided before the creature commits to a move.
6. If food is unreachable, the creature returns to wander or idle instead of spinning in place.

This is why the debug panel now needs to show the current target and decision reason for each selected creature.

## Small Prey

Small prey values come from `data/species/small_prey.json` and local behavior constants in `small_prey.gd`.

### Small Prey Data

| Value | Number |
| --- | ---: |
| Health | 20 |
| Speed | 90 |
| Fear | 0.90 |
| Hunger growth rate | 0.20 |
| Plant diet | 1.00 |
| Meat diet | 0 |
| Scavenger diet | 0 |
| Plant consumption rate | 0.40 |
| Reproduction rate | 0.60 |

### Small Prey Behavior Values

| Value | Number |
| --- | ---: |
| Wander radius | 140 |
| Wander reached distance | 18 |
| Player flee range | 130 |
| Varnak flee range | 180 |
| Eat interval | 6 seconds |
| Eat duration | 1.1 seconds |
| Idle duration | 0.8 seconds |
| Vegetation eat range | 170 |
| Vegetation consume range | 26 |
| World edge padding | 24 |
| Avoidance lookahead | 46 |
| Wall avoid radius | 58 |
| Biome return chance | 0.64 |

Small prey states:

- `IDLE`
- `WANDER`
- `SEEK_FOOD`
- `EAT`
- `FLEE`
- `DEAD`

Important behavior:

- Small prey eat visible edible vegetation when hungry.
- They prefer nearby pond vegetation through a distance multiplier.
- They flee from the player and Varnaks.
- They avoid water, hills, walls, and world edges.
- On death they drop meat once.
- Their diet remains plant-only, so they should not switch to meat unless the balance data changes.

## Grazers

Grazer values come from `data/species/grazer.json` and local behavior constants in `grazer.gd`.

### Grazer Data

| Value | Number |
| --- | ---: |
| Health | 45 |
| Speed | 70 |
| Fear | 0.70 |
| Aggression | 0.15 |
| Hunger growth rate | 0.30 |
| Plant consumption rate | 1.20 |
| Plant diet | 0.85 |
| Meat diet | 0.05 |
| Scavenger diet | 0.10 |
| Size | 1.35 |
| Reproduction rate | 0.35 |
| Mutation rate | 0.03 |
| Diet shift | 0.02 |

### Grazer Behavior Values

| Value | Number |
| --- | ---: |
| Wander radius | 190 |
| Wander reached distance | 22 |
| Player flee range | 105 |
| Varnak flee range | 220 |
| Low biomass percent | 35 |
| Eat duration | 1.4 seconds |
| Scavenge duration | 1.8 seconds |
| Idle duration | 0.9 seconds |
| Small prey detect range | 220 |
| Small prey attack range | 28 |
| Plant eat hunger drop | 0.45 |
| Meat hunger drop | 0.65 |
| Vegetation eat range | 220 |
| Vegetation consume range | 34 |
| World edge padding | 28 |
| Avoidance lookahead | 62 |
| Wall avoid radius | 78 |
| Biome return chance | 0.58 |

Grazer states:

- `IDLE`
- `WANDER`
- `EAT_PLANTS`
- `SEEK_FOOD`
- `FLEE`
- `SCAVENGE`
- `HUNT_SMALL_PREY`
- `DEAD`

Important behavior:

- Grazers normally eat plants.
- When biome biomass drops, they can become more omnivorous through ecosystem trait shifts.
- Hungry grazers search for visible edible plants.
- If plants are unavailable and hunger is high enough, desperate grazers can hunt small prey or scavenge meat.
- The predation fallback is gated by biomass stress, hunger stage, and aggression so grazing remains the default behavior.
- They can scavenge depending on diet, biomass stress, and hunger stage.
- They avoid water, hills, walls, Varnaks, and world edges.
- On death they drop meat once.

## Varnaks

Varnaks are the main hostile predators. Their base species data is stored in `data/species_varnak.json`, while many hunting and adaptation values are balanced in `GameBalance`.

### Varnak Population And Spawning

| Value | Number |
| --- | ---: |
| Target Varnak count | 8 |
| Player safe spawn distance | 560 |
| Spawn attempts | 36 |

Base spawn points in `WorldConfig`:

| Point |
| --- |
| `(220, 0)` |
| `(-470, -300)` |
| `(420, 330)` |
| `(-980, -560)` |
| `(1040, 520)` |
| `(760, -680)` |
| `(980, -120)` |
| `(1220, -420)` |
| `(1160, 760)` |
| `(-1140, 580)` |
| `(-1290, -120)` |
| `(-1040, 790)` |
| `(-240, -760)` |
| `(90, 700)` |
| `(620, 810)` |
| `(1360, 110)` |

Spawn point positions are scaled by `WORLD_SCALE`.

### Varnak Hunting Values

| Value | Number |
| --- | ---: |
| Hunger growth | 0.18 |
| Hungry threshold | 0.32 |
| Starving threshold | 0.58 |
| Desperate threshold | 0.80 |
| Prey detect range | 620 |
| Player intrusion range | 240 |
| Prey chase priority | 0.65 |
| Player chase priority | 0.85 |
| Night hunting multiplier | 1.25 |
| Fire avoidance priority | 1.10 |
| Torch avoidance priority | 0.75 |

### Varnak Adaptation Values

| Value | Number |
| --- | ---: |
| Debug adaptation growth | 0.05 |
| Fire fear delta | -0.10 |
| Stalk tendency growth | 0.10 |
| Player aggression growth | 0.10 |
| Pack coordination growth | 0.10 |
| Wall curiosity growth | 0.10 |

Important behavior:

- Varnaks are part of the ecosystem, not just a player threat: they contribute to biome predator pressure, average hunger and energy, and generation drift.
- Their target selection can favor ecosystem prey, meat scavenging, or the player depending on hunger, distance, and priorities.
- Their hunting pressure is stronger at night.
- Fire and torch effects can reduce immediate Varnak pressure.
- Varnak deaths feed the ecosystem event stream and create meat drops.

## Living World Creature Spawning

Creature visibility and spacing values from `GameBalance.LIVING_WORLD`:

| Value | Number |
| --- | ---: |
| Small prey visible radius | 850 |
| Small prey player safe distance | 240 |
| Small prey minimum distance | 190 |
| Grazer visible radius | 1000 |
| Grazer player safe distance | 340 |
| Grazer minimum distance | 300 |
| Varnak player safe distance | 560 |
| Varnak spawn attempts | 36 |

Important behavior:

- Creature spawning is constrained by player safety and spacing.
- Small prey and grazers use visibility and safe-distance rules, while Varnaks use wider roam and spawn pressure.
- Visible creature counts should represent ecosystem state, not just what happened to spawn near the player.
- Creature movement keeps world-bound enforcement intact.

## Maps And HUD

### HUD

The HUD displays:

- Player health, hunger, stamina, and rest.
- Current day, time, and phase.
- Inventory resources.
- Equipped or crafted survival items.
- Ecosystem and event messages.
- Minimap and map access.

### Minimap

The minimap draws:

- Player position.
- Biome color field.
- Resource and creature markers.
- Pond and hill landmarks.

Readable-map rule:

- Grass patches, dense grass, and berry bushes are hidden from the map if they are not player-harvestable, which keeps the map from becoming a noise field.
- The minimap and field map refresh landmark data from the world when needed, so ponds and hills stay visible even when the UI opens early in a run.

### Full Field Map

The full map draws:

- Larger biome field.
- Player-harvestable resources plus visible creature and landmark markers.
- Varnaks.
- Player position.
- Pond markers.
- Hill markers.
- Legend.
- Zone, day/time, pond count, hill count, live Varnaks, player stats, inventory, and Varnak profile.

Map landmark behavior:

- Map data is refreshed from the world when the local map landmark list is empty.
- This prevents ponds and hills from disappearing when the UI opens before runtime landmark state has been cached.

## Debug Panel

The debug panel exposes grouped controls for testing current systems.

Main debug areas:

- Ecosystem state.
- Creature counts and behavior.
- Evolution and adaptation.
- Combat tools.
- Event logs.
- Utility tools.

Debug controls are expected to produce visible effects when possible. For example, biomass debug changes should affect visible vegetation counts, not only hidden ecosystem numbers.
- Population summaries show the aggregate biome model, while the selected-creature frames show state, target, decision reason, health, satiety, hunger, energy, diet, aggression, fear, biome, home biome, reproduction, and consumption.
- Missing creature fields fall back to `0` in the debug text instead of disappearing, which keeps the panel stable while stats are still being populated.
- If the selected creature despawns or is freed, the panel drops the stale reference and reselects the nearest valid one instead of throwing errors.

## Save And Load

The save system stores and restores current run state.

Important saved areas:

- Player stats.
- Player position and inventory.
- Crafted or unlocked survival items, including bow state.
- World resources and regrowth state.
- Creature state where supported.
- Ecosystem state.
- Day/night state.
- Varnak adaptation/profile data.

Important restore rule:

- When a saved resource is restored, derived groups and visual state must be reapplied from its kind and context. For example, pond vegetation needs its group and visual multiplier restored.

## Performance Notes

Known performance-sensitive areas:

- Biome terrain visuals should use cached textures instead of heavy per-frame polygon drawing.
- Map rendering should reuse world configuration and cached data where possible.
- Resource and creature loops should avoid unnecessary full-world scans during every frame.
- Debug text should be readable but not rebuilt more often than needed.
- World startup now batches resource and pond-vegetation spawning, and biome vegetation syncs are deferred, so the first seconds should be noticeably calmer than a full-frame spawn burst.

## Verification Commands

After script changes, run the GDScript parser check:

```powershell
$godot='C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'; $failed = @(); Get-ChildItem -Recurse -Filter '*.gd' | ForEach-Object { $rel = $_.FullName.Substring((Get-Location).Path.Length + 1).Replace('\','/'); $resPath = 'res://' + $rel; & $godot --headless --path . --check-only --script $resPath | Out-Null; if ($LASTEXITCODE -ne 0) { $failed += $resPath } }; if ($failed.Count -eq 0) { 'All GDScript files parsed successfully.' } else { 'Failed:'; $failed }
```

After gameplay, scene, UI, or autoload behavior changes, run the headless smoke test:

```powershell
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --scene res://scenes/main.tscn --quit-after 30
```

After JSON data changes, parse the changed JSON files before summarizing the task.

## Current Design Rules

Use these rules when extending the prototype:

- Keep ecosystem model state in `EcosystemDirector`.
- Keep visible world resources and spawned entities in `World`.
- Keep HUD, minimap, map, and debug presentation in UI scripts.
- Put gameplay tuning constants in `GameBalance` when the value is balance-driven.
- Make debug effects visible when possible.
- Make vegetation and biomass changes visible enough to inspect in-game.
- Do not let pond vegetation spawn inside visible water.
- Do not let rocks affect plant biomass unless explicitly requested.
- Prefer named hunger stages over scattered magic thresholds.
- Give each creature behavior clear visible feedback when it searches, moves, eats, hunts, flees, or dies.
