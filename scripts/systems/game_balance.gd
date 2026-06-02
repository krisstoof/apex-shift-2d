extends RefCounted
class_name GameBalance

const CRAFTING_COSTS := {
	"campfire": {"wood": 3, "stone": 2},
	"spear": {"wood": 2, "stone": 1, "fiber": 1},
	"torch": {"wood": 1, "fiber": 1},
	"bow": {"wood": 3, "fiber": 4, "bone": 1},
	"cooked_meat": {"meat": 1},
	"basic_trap": {"wood": 2, "fiber": 2},
	"trap": {"wood": 2, "fiber": 2},
	"wall": {"wood": 3},
	"storage_box": {"wood": 4},
	"tent": {"wood": 4, "fiber": 3}
}

const TORCH_DURATION_SECONDS := 45.0
const TORCH_SAFE_RADIUS := 96.0
const TORCH_DETECTION_RANGE_MULTIPLIER := 0.65
const TORCH_AGGRESSION_MULTIPLIER := 0.7
const TORCH_CLOSE_CHASE_RANGE_MULTIPLIER := 0.65
const TORCH_ATTACK_COOLDOWN_MULTIPLIER := 1.5
const TORCH_FLEE_SPEED_MULTIPLIER := 0.85
const TORCH_LIGHT_RADIUS := 105.0
const TORCH_LIGHT_INTENSITY := 0.7
const TORCH_LIGHT_OFFSET := Vector2(18.0, 0.0)
const TORCH_LIGHT_BASE_STRENGTH := 0.22
const TORCH_LIGHT_NIGHT_STRENGTH := 0.58
const TORCH_LIGHT_FLICKER_BASE := 0.9
const TORCH_LIGHT_FLICKER_PRIMARY_SPEED := 0.018
const TORCH_LIGHT_FLICKER_PRIMARY_AMOUNT := 0.08
const TORCH_LIGHT_FLICKER_SECONDARY_SPEED := 0.031
const TORCH_LIGHT_FLICKER_SECONDARY_AMOUNT := 0.02
const TORCH_LIGHT_OUTER_ALPHA := 0.10
const TORCH_LIGHT_MID_RADIUS_MULTIPLIER := 0.58
const TORCH_LIGHT_MID_ALPHA := 0.16
const TORCH_LIGHT_CORE_RADIUS_MULTIPLIER := 0.24
const TORCH_LIGHT_CORE_ALPHA := 0.24

const CAMPFIRE_SAFE_RADIUS := 150.0
const CAMPFIRE_LIGHT_RADIUS := 165.0
const CAMPFIRE_FUEL_BURN_RATE := 1.0

const PLAYER_MAX_HEALTH := 100.0
const PLAYER_MAX_HUNGER := 100.0
const PLAYER_MAX_STAMINA := 100.0
const PLAYER_MAX_REST := 100.0
const PLAYER_LOW_HUNGER := 25.0
const PLAYER_EXHAUSTED_REST := 20.0
const PLAYER_HUNGER_DECAY_RATE := 0.9
const PLAYER_REST_DECAY_RATE := 0.35
const PLAYER_RUNNING_REST_DECAY_RATE := 0.9
const PLAYER_RUNNING_STAMINA_DECAY_RATE := 18.0
const PLAYER_STARVATION_DAMAGE_PER_SECOND := 3.0
const PLAYER_HEALTH_REGEN_RATE := 0.45
const PLAYER_MEAT_NUTRITION := 32.0
const PLAYER_SLEEP_HUNGER_COST := 8.0
const PLAYER_SLEEP_HEALTH_RESTORE := 35.0
const PLAYER_LOW_HUNGER_SPEED_MULTIPLIER := 0.82
const PLAYER_EXHAUSTED_REST_SPEED_MULTIPLIER := 0.85
const PLAYER_BASE_STAMINA_REGEN := 16.0
const PLAYER_LOW_HUNGER_STAMINA_REGEN_MULTIPLIER := 0.45
const PLAYER_EXHAUSTED_REST_STAMINA_REGEN_MULTIPLIER := 0.55

const NIGHT_DANGER_MULTIPLIER := 1.2
const ADAPTATION_DEBUG_GROWTH := 0.05
const ADAPTATION_TRAP_AWARENESS_GROWTH := 0.15
const ADAPTATION_FIRE_FEAR_DELTA := -0.10
const ADAPTATION_STALK_TENDENCY_GROWTH := 0.10
const ADAPTATION_PLAYER_AGGRESSION_GROWTH := 0.10
const ADAPTATION_PACK_COORDINATION_GROWTH := 0.10
const ADAPTATION_WALL_CURIOSITY_GROWTH := 0.10

const SPEAR_ATTACK_COOLDOWN := 0.0
const TRAP_DAMAGE := 120.0
const TRAP_EFFECT_DURATION := 0.0

# Larger-world generation values. These are used or reserved for world scale,
# vegetation density, spawn spacing, and biome content distribution.
const LIVING_WORLD := {
	"world_scale": 2.2,
	"tree_density_per_world_area": 0.0000035,
	"rock_density_per_world_area": 0.0000018,
	"bush_density_per_world_area": 0.0000026,
	"grass_patch_density_per_world_area": 0.000010,
	"dense_vegetation_zone_bonus": 1.35,
	"resource_spawn_margin": 95.0,
	"resource_min_distance": 90.0,
	"resource_player_safe_distance": 260.0,
	"resource_spawn_attempts": 120,
	"small_prey_visible_spawn_radius": 850.0,
	"small_prey_player_safe_distance": 240.0,
	"small_prey_min_distance": 190.0,
	"grazer_visible_spawn_radius": 1000.0,
	"grazer_player_safe_distance": 340.0,
	"grazer_min_distance": 300.0,
	"varnak_player_safe_distance": 560.0,
	"varnak_spawn_attempts": 36
}

# Food values and decision thresholds for living creatures. Future creature AI
# should read these instead of baking hunger and food-search numbers locally.
const ANIMAL_AI := {
	"grass_food_value": 0.20,
	"bush_food_value": 0.45,
	"tree_food_value": 0.10,
	"meat_food_value": 0.65,
	"scavenger_food_value": 0.55,
	"hungry_threshold": 0.35,
	"starving_threshold": 0.60,
	"desperate_threshold": 0.82,
	"food_search_radius": 520.0,
	"desperate_food_search_radius": 780.0,
	"prey_detect_radius": 260.0,
	"water_search_radius": 680.0
}

# Predator behavior tuning for Varnaks when they participate in the ecosystem
# food web instead of only reacting to the player.
const VARNAK_HUNTING := {
	"hunger_growth_rate": 0.18,
	"hungry_threshold": 0.32,
	"starving_threshold": 0.58,
	"desperate_threshold": 0.80,
	"prey_detect_radius": 620.0,
	"player_intrusion_radius": 240.0,
	"prey_chase_priority": 0.65,
	"player_chase_priority": 0.85,
	"night_hunting_multiplier": 1.25,
	"fire_avoidance_priority": 1.10,
	"torch_avoidance_priority": 0.75
}

# Ranged combat values reserved for the bow and arrow projectile systems.
const RANGED_COMBAT := {
	"bow_damage": 28.0,
	"bow_cooldown_seconds": 0.75,
	"bow_stamina_cost": 8.0,
	"arrow_speed": 780.0,
	"arrow_lifetime_seconds": 1.25,
	"arrow_max_range": 900.0,
	"arrow_hit_radius": 8.0
}

# Landmark generation and biome modifiers for ponds, hills, dense vegetation,
# and future animal hotspots.
const LANDMARKS := {
	"hill_count": 8,
	"pond_count": 5,
	"dense_vegetation_zone_count": 7,
	"animal_hotspot_count": 4,
	"hill_spawn_margin": 220.0,
	"pond_spawn_margin": 260.0,
	"landmark_min_distance": 420.0,
	"pond_vegetation_bonus": 2.0,
	"pond_vegetation_base_count": 14,
	"pond_vegetation_min_distance": 28.0,
	"pond_vegetation_player_safe_distance": 36.0,
	"pond_vegetation_inner_ring_factor": 1.18,
	"pond_vegetation_outer_ring_factor": 1.48,
	"pond_grass_food_bonus": 1.45,
	"pond_vegetation_visual_scale": 1.28,
	"dense_vegetation_resource_bonus": 1.60,
	"animal_hotspot_population_bonus": 1.25
}

# Resource regrowth stages for future gradual multi-day regrowth. Yield values
# are multipliers applied to the mature resource yield.
const RESOURCE_REGROWTH := {
	"stages": ["depleted", "sprout", "young", "mature"],
	"days_per_growth_stage": 1,
	"yield_by_growth_stage": {
		"depleted": 0.0,
		"sprout": 0.25,
		"young": 0.60,
		"mature": 1.0
	},
	"grass_regrowth_time_days": 1,
	"bush_regrowth_time_days": 2,
	"tree_regrowth_time_days": 3,
	"dry_bush_regrowth_time_days": 3,
	"growth_tick_seconds": 5.0
}

const ECOSYSTEM := {
	"simulation_tick_seconds": 5.0,
	"default_plant_biomass": 100.0,
	"max_plant_biomass": 100.0,
	"plant_regrowth_rate": 1.5,
	"initial_small_prey_population": 12.0,
	"initial_grazer_population": 4.0,
	"small_prey_plant_consumption": 0.08,
	"grazer_plant_consumption": 0.35,
	"overgrazing_pressure_scale": 10.0,
	"small_prey_growth_rate": 0.75,
	"small_prey_predation_rate": 1.15,
	"small_prey_collapse_biomass_factor": 0.12,
	"small_prey_collapse_loss_rate": 0.65,
	"grazer_growth_rate": 0.32,
	"grazer_starvation_rate": 0.70,
	"grazer_predation_rate": 0.65,
	"max_small_prey_population": 30.0,
	"max_grazer_population": 14.0,
	"stressed_threshold": 70.0,
	"depleted_threshold": 30.0,
	"collapsing_threshold": 10.0,
	"grazer_food_stress_threshold": 30.0,
	"grazer_niche_shift_threshold": 0.45,
	"grazer_diet_shift_rate": 0.04,
	"grazer_aggression_shift_rate": 0.015,
	"population_decline_event_min_delta": 0.10,
	"tree_biomass_impact": 4.0,
	"bush_biomass_impact": 1.0,
	"small_bush_biomass_impact": 0.45,
	"berry_bush_biomass_impact": 0.55,
	"dry_bush_biomass_impact": 0.25,
	"grass_biomass_impact": 0.15,
	"initial_average_plant_diet": 0.85,
	"initial_average_meat_diet": 0.05,
	"initial_average_scavenger_diet": 0.10,
	"initial_average_aggression": 0.15,
	"max_omnivore_resilience": 0.85,
	"grazer_meat_diet_shift_ratio": 0.65,
	"grazer_scavenger_diet_shift_ratio": 0.35,
	"debug_plant_biomass_delta": 25.0,
	"debug_small_prey_population_delta": 3.0,
	"debug_grazer_population_delta": 2.0,
	"debug_forced_food_stress_margin": 5.0,
	"debug_forced_niche_plant_diet": 0.58,
	"debug_forced_niche_meat_diet": 0.28,
	"debug_forced_niche_scavenger_diet": 0.14,
	"debug_min_population_floor": 1.0
}

const DEBUG_PLAYER_DAMAGE_AMOUNT := 25.0
const DEBUG_PLAYER_HEAL_AMOUNT := 25.0
const DEBUG_PLAYER_HUNGER_ENERGY_AMOUNT := 25.0
