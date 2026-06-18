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
const CAMPFIRE_STAMINA_REGEN_RADIUS := CAMPFIRE_SAFE_RADIUS

const PLAYER_MAX_HEALTH := 100.0
const PLAYER_MAX_HUNGER := 100.0
const PLAYER_MAX_STAMINA := 100.0
const PLAYER_MAX_REST := 100.0
const PLAYER_LOW_HUNGER := 25.0
const PLAYER_EXHAUSTED_REST := 20.0
const PLAYER_HUNGER_DECAY_RATE := 0.75
const PLAYER_REST_DECAY_RATE := 0.35
const PLAYER_RUNNING_REST_DECAY_RATE := 0.9
const PLAYER_RUNNING_STAMINA_DECAY_RATE := 14.0
const PLAYER_STARVATION_DAMAGE_PER_SECOND := 1.0
const PLAYER_HEALTH_REGEN_RATE := 0.45
const PLAYER_CAMPFIRE_HEALTH_REGEN_MULTIPLIER := 2.2
const PLAYER_MEAT_NUTRITION := 32.0
const PLAYER_SLEEP_HUNGER_COST := 8.0
const PLAYER_SLEEP_HEALTH_RESTORE := 35.0
const PLAYER_LOW_HUNGER_SPEED_MULTIPLIER := 0.82
const PLAYER_EXHAUSTED_REST_SPEED_MULTIPLIER := 0.85
const PLAYER_BASE_STAMINA_REGEN := 16.0
const PLAYER_LOW_HUNGER_STAMINA_REGEN_MULTIPLIER := 0.45
const PLAYER_EXHAUSTED_REST_STAMINA_REGEN_MULTIPLIER := 0.55
const PLAYER_CAMPFIRE_STAMINA_REGEN_MULTIPLIER := 1.75
const PLAYER_CAMPFIRE_REGEN_REFRESH_INTERVAL := 0.33

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

const ANIMAL_LOOT := {
	"small_prey": {
		"meat_min": 1,
		"meat_max": 1
	},
	"grazer": {
		"meat_min": 2,
		"meat_max": 3
	},
	"varnak": {
		"meat_min": 2,
		"meat_max": 4,
		"bone_min": 1,
		"bone_max": 2
	}
}
const CREATURE_SIMULATION_LOD := {
	"near_distance": 900.0,
	"medium_distance": 1800.0,
	"far_update_interval_seconds": 3.0,
	"medium_ai_interval_multiplier": 3.0,
	"medium_spatial_update_multiplier": 2.0,
	"far_hunger_time_scale": 1.0,
	"far_energy_time_scale": 0.35,
	"force_varnak_near_distance": 700.0,
	"debug_enabled": true
}

const WORLD_CHUNKS := {
	"chunk_size": 1024.0,
	"active_radius_chunks": 1,
	"preload_radius_chunks": 2,
	"update_interval_seconds": 0.25,
	"debug_enabled": true
}

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

# Varnak population pressure rises with survived days. Population recovery is
# intentionally batched so a new day cannot create a large spawn spike.
const VARNAK_DAY_SCALING := {
	"day_1_min": 0,
	"day_1_max": 0,
	"day_2_min": 1,
	"day_2_max": 2,
	"day_3_min": 2,
	"day_3_max": 4,
	"max_varnaks": 8,
	"daily_growth": 1,
	"spawn_check_interval_seconds": 10.0,
	"spawn_batch_limit": 2,
	"day_1_spawn_chance": 0.0,
	"day_2_spawn_chance": 0.10,
	"spawn_chance_daily_growth": 0.05,
	"max_spawn_chance": 0.55,
	"other_creature_min_distance": 140.0
}

# Early-week difficulty curve keeps day 1 gentle, day 3 meaningful, and days 6-7 clearly harsher.
const FIRST_WEEK_DIFFICULTY := {
	1: {
		"varnak_max_population": 0,
		"varnak_spawn_chance": 0.00,
		"varnak_aggression_multiplier": 0.40,
		"varnak_activity_multiplier": 0.55,
		"small_prey_population_multiplier": 1.15,
		"grazer_population_multiplier": 1.10
	},
	2: {
		"varnak_max_population": 1,
		"varnak_spawn_chance": 0.10,
		"varnak_aggression_multiplier": 0.55,
		"varnak_activity_multiplier": 0.68,
		"small_prey_population_multiplier": 1.08,
		"grazer_population_multiplier": 1.05
	},
	3: {
		"varnak_max_population": 2,
		"varnak_spawn_chance": 0.18,
		"varnak_aggression_multiplier": 0.70,
		"varnak_activity_multiplier": 0.80,
		"small_prey_population_multiplier": 1.00,
		"grazer_population_multiplier": 1.00
	},
	4: {
		"varnak_max_population": 3,
		"varnak_spawn_chance": 0.26,
		"varnak_aggression_multiplier": 0.82,
		"varnak_activity_multiplier": 0.90,
		"small_prey_population_multiplier": 0.95,
		"grazer_population_multiplier": 0.98
	},
	5: {
		"varnak_max_population": 4,
		"varnak_spawn_chance": 0.34,
		"varnak_aggression_multiplier": 0.92,
		"varnak_activity_multiplier": 1.00,
		"small_prey_population_multiplier": 0.92,
		"grazer_population_multiplier": 0.96
	},
	6: {
		"varnak_max_population": 5,
		"varnak_spawn_chance": 0.42,
		"varnak_aggression_multiplier": 1.02,
		"varnak_activity_multiplier": 1.10,
		"small_prey_population_multiplier": 0.88,
		"grazer_population_multiplier": 0.92
	},
	7: {
		"varnak_max_population": 6,
		"varnak_spawn_chance": 0.50,
		"varnak_aggression_multiplier": 1.12,
		"varnak_activity_multiplier": 1.22,
		"small_prey_population_multiplier": 0.84,
		"grazer_population_multiplier": 0.90
	}
}

const VARNAK_SPAWN := {
	"default_biome_weight": 1.0,
	"dangerous_biome_weight_multiplier": 3.0,
	"fallback_attempt_multiplier": 3,
	"avoid_camera_margin": 160.0
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
	"water_search_radius": 680.0,
	"target_lock_seconds": 0.85,
	"failed_food_retarget_seconds": 0.55,
	"grazer_predation_min_drive": 0.82,
	"grazer_predation_min_aggression": 0.22
}

const CREATURE_SPAWN := {
	"horizon_margin": 140.0,
	"horizon_fallback_distance": 720.0,
	"horizon_ring_width": 180.0
}

# SmallPrey behavior constants for movement, fleeing, and feeding.
const SMALL_PREY_AI := {
	"wander_radius": 140.0,
	"wander_reached_distance": 18.0,
	"player_flee_range": 130.0,
	"varnak_flee_range": 180.0,
	"flee_duration_seconds": 3.0,
	"eat_interval_seconds": 6.0,
	"eat_duration_seconds": 1.1,
	"eat_visual_duration": 0.48,
	"idle_duration_seconds": 0.8,
	"vegetation_eat_range": 170.0,
	"vegetation_consume_range": 26.0,
	"world_edge_padding": 24.0,
	"avoidance_lookahead_distance": 46.0,
	"wall_avoid_radius": 58.0,
	"biome_return_chance": 0.64
}

# Grazer behavior constants for movement, predation awareness, and feeding.
const GRAZER_AI := {
	"wander_radius": 190.0,
	"wander_reached_distance": 22.0,
	"player_flee_range": 105.0,
	"varnak_flee_range": 220.0,
	"flee_duration_seconds": 4.0,
	"eat_duration_seconds": 1.4,
	"eat_visual_duration": 0.55,
	"idle_duration_seconds": 0.9,
	"vegetation_eat_range": 220.0,
	"vegetation_consume_range": 44.0,
	"meat_eat_range": 300.0,
	"meat_consume_range": 44.0,
	"world_edge_padding": 28.0,
	"avoidance_lookahead_distance": 62.0,
	"wall_avoid_radius": 78.0,
	"biome_return_chance": 0.58,
	"small_prey_detect_range": 220.0,
	"small_prey_attack_range": 28.0,
	"low_biomass_percent": 35.0,
	"plant_eat_hunger_drop": 0.45,
	"meat_hunger_drop": 0.65
}

# Predator behavior tuning for Varnaks when they participate in the ecosystem
# food web instead of only reacting to the player.
const VARNAK_HUNTING := {
	"attack_range": 42.0,
	"attack_arc_degrees": 78.0,
	"attack_visual_duration": 0.14,
	"eat_visual_duration": 0.55,
	"base_health": 90.0,
	"hunger_growth_rate": 0.18,
	"hunt_detection_range": 620.0,
	"hunt_player_safe_distance": 160.0,
	"hungry_threshold": 0.32,
	"starving_threshold": 0.58,
	"desperate_threshold": 0.80,
	"hunt_feed_amount": 0.55,
	"meat_consume_range": 38.0,
	"world_edge_padding": 32.0,
	"base_hunger_time_scale": 0.05,
	"movement_hunger_time_scale": 0.06,
	"prey_detect_radius": 620.0,
	"player_intrusion_radius": 240.0,
	"prey_chase_priority": 0.65,
	"player_chase_priority": 0.85,
	"night_hunting_multiplier": 1.35,
	"fire_avoidance_priority": 1.10,
	"torch_avoidance_priority": 0.75,
	"target_lock_seconds": 1.25,
	"local_patrol_radius": 320.0,
	"hungry_roam_radius": 720.0,
	"starving_roam_radius": 1120.0,
	"hunting_roam_target_reached_distance": 90.0,
	"cross_biome_hunt_drive": 0.62
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
	"pond_count": 7,
	"dense_vegetation_zone_count": 5,
	"animal_hotspot_count": 3,
	"hill_spawn_margin": 220.0,
	"hill_shape_irregularity": 0.10,
	"hill_shape_sample_count": 40,
	"hill_mid_elevation_factor": 0.70,
	"hill_peak_elevation_factor": 0.38,
	"pond_spawn_margin": 260.0,
	"landmark_min_distance": 420.0,
	"pond_vegetation_bonus": 2.0,
	"pond_vegetation_base_count": 6,
	"pond_deep_water_radius_factor": 0.68,
	"pond_shallow_water_radius_factor": 1.0,
	"pond_shore_radius_factor": 1.12,
	"pond_deep_speed_multiplier": 0.42,
	"pond_shallow_speed_multiplier": 0.68,
	"pond_shape_irregularity": 0.16,
	"pond_shape_sample_count": 48,
	"pond_shore_detail_count": 18,
	"pond_aquatic_vegetation_count": 12,
	"pond_vegetation_min_distance": 46.0,
	"pond_vegetation_player_safe_distance": 36.0,
	"pond_vegetation_inner_ring_factor": 1.18,
	"pond_vegetation_outer_ring_factor": 1.48,
	"pond_tree_water_margin": 1.22,
	"pond_bush_water_margin": 1.12,
	"pond_grass_water_margin": 1.04,
	"pond_grass_food_bonus": 1.0,
	"pond_vegetation_visual_scale": 1.0,
	"legacy_pond_landmark_water_enabled": false,
	"legacy_hill_landmark_collision_enabled": false,
	"legacy_topography_landmark_areas_enabled": false,
	"legacy_topography_landmarks_visible": false,
	"legacy_topography_landmark_debug_overlay_enabled": false,
	"topography_pond_deep_threshold": 0.70,
	"topography_pond_shallow_threshold": 0.56,
	"topography_pond_shore_threshold": 0.46,
	"topography_pond_deep_speed_multiplier": 0.42,
	"topography_pond_shallow_speed_multiplier": 0.68,
	"topography_pond_shore_speed_multiplier": 0.88,
	"topography_pond_vegetation_enabled": true,
	"topography_pond_vegetation_per_pond_min": 10,
	"topography_pond_vegetation_per_pond_max": 24,
	"topography_pond_vegetation_ring_inner": 0.50,
	"topography_pond_vegetation_ring_outer": 1.18,
	"decorative_vegetation_dynamic_budget_enabled": true,
	"decorative_vegetation_budget_when_surface_building": 120,
	"decorative_vegetation_budget_when_fps_low": 90,
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
	"tree_regrowth_time_days": 15,
	"dry_bush_regrowth_time_days": 3,
	"growth_tick_seconds": 5.0
}

const RESOURCE_SPAWN_OPTIMIZATION := {
	"decorative_visual_spawn_attempts": 18,
	"decorative_visual_spawn_attempts_low_end": 10,
	"resource_spawn_failure_warning_ratio": 0.50,
	"max_spawn_failure_log_entries": 24,
	"spawn_failure_log_enabled": true,
	"spawn_failure_rejection_summary_enabled": true,
	"deterministic_slot_fallback_enabled": true,
	"precomputed_biome_spawn_points_enabled": true,
	"precomputed_biome_spawn_points_per_biome": 96
}

const RESOURCE_ACTIVATION := {
	"player_interaction_radius": 420.0,
	"resource_collision_activation_radius": 900.0,
	"ai_food_activation_radius": 1200.0,
	"activation_update_interval": 0.45,
	"activation_changes_per_frame": 28,
	"interactive_grass_node_limit": 64,
	"interactive_edible_vegetation_node_limit": 96
}

const BIOME_VISUALS := {
	"biome_blend_radius": 300.0,
	"biomass_depleted_tint": Color(0.34, 0.31, 0.22),
	"biomass_tint_max_strength": 0.38,
	"biomass_darkening_max_strength": 0.08,
	"biomass_visual_bucket_percent": 5.0
}

const BIOME_TEXTURES := {
	"detail_overlay_enabled": false,
	"detail_chunk_world_size": 768.0,
	"detail_chunk_texture_size": 32,
	"detail_visible_chunk_radius": 1,
	"detail_overlay_alpha": 0.22,
	"use_cell_terrain_renderer": false,
	"use_biome_shape_renderer": false,
	"use_biome_shape_renderer_in_world": false,
	"biome_shape_renderer_world_background_only": false,
	"use_biome_shape_map_for_maps": true,
	"use_terrain_surface_chunk_renderer": true,
	"terrain_surface_chunk_world_size": 1024.0,
	"terrain_surface_chunk_texture_size": 96,
	"terrain_surface_preview_enabled": true,
	"terrain_surface_preview_texture_size": 64,
	"terrain_surface_preview_max_chunks_built_per_frame": 10,
	"terrain_surface_preview_active_build_limit": 6,
	"terrain_surface_preview_build_cell_batch_size": 64,
	"terrain_surface_visible_margin_chunks": 1,
	"terrain_surface_max_chunks_built_per_frame": 4,
	"terrain_surface_max_rows_built_per_frame": 12,
	"terrain_surface_max_build_ms_per_frame": 6.0,
	"terrain_surface_refined_texture_size": 160,
	"terrain_surface_refine_max_rows_built_per_frame": 12,
	"terrain_surface_refine_max_build_ms_per_frame": 6.0,
	"terrain_surface_refined_build_cell_batch_size": 16,
	"terrain_surface_refine_delay_seconds": 0.05,
	"terrain_surface_refine_pause_when_fps_below": 25,
	"terrain_surface_refine_pause_when_camera_moving": true,
	"terrain_surface_max_refined_chunks_per_second": 8,
	"terrain_surface_hard_budget_enabled": true,
	"terrain_surface_hard_budget_ms": 4.0,
	"terrain_surface_build_cell_batch_size": 16,
	"terrain_surface_preview_only_during_fast_movement": false,
	"terrain_surface_texture_filter_nearest": false,
	"terrain_surface_transition_sample_distance": 96.0,
	"terrain_surface_transition_strength": 0.0,
	"terrain_surface_transition_enabled": false,
	"terrain_surface_noise_enabled": true,
	"terrain_surface_noise_strength": 0.10,
	"terrain_surface_detail_noise_strength": 0.055,
	"terrain_surface_draw_placeholders": true,
	"terrain_surface_placeholder_alpha": 0.92,
	"terrain_surface_ocean_background_enabled": true,
	"legacy_biome_detail_overlay_enabled_with_surface_renderer": false,
	"terrain_surface_sample_cache_enabled": true,
	"terrain_surface_sample_cache_step": 8.0,
	"terrain_surface_use_shape_map_sampling": true,
	"terrain_surface_use_exact_shape_sampling": false,
	"terrain_surface_edge_supersampling_enabled": false,
	"terrain_surface_edge_supersample_radius": 6.0,
	"terrain_surface_edge_supersample_count": 5,
	"biome_shape_visual_surface_gap_fill_passes": 2,
	"minimap_draw_grid_overlay": false,
	"map_screen_draw_grid_overlay": true,
	"minimap_draw_sample_grid_underlay": false,
	"map_screen_draw_sample_grid_underlay": false,
	"minimap_draw_cell_map_fallback": true,
	"map_screen_draw_cell_map_fallback": true,
	"minimap_redraw_on_player_move_distance": 24.0,
	"minimap_redraw_interval_when_static": 1.5,
	"draw_topography_labels_on_map": false,
	"draw_topography_labels_on_minimap": false,
	"draw_pond_hill_landmarks": false,
	"disable_global_biome_blend_texture": true,
	"disable_global_surface_texture_on_boot": true,
	"terrain_cell_size": 96.0,
	"terrain_chunk_cell_size": 16,
	"max_terrain_chunks_built_per_frame": 2,
	"terrain_texture_filter_nearest": true,
	"terrain_edge_noise_enabled": true,
	"terrain_detail_enabled": false,
	"terrain_cell_renderer_debug_enabled": false,
	"biome_shape_sample_size": 96.0,
	"biome_shape_runtime_sample_size": 48.0,
	"biome_shape_contour_cell_size": 96.0,
	"biome_shape_min_region_cells": 4,
	"biome_shape_max_polygons_per_layer": 128,
	"biome_shape_max_points_per_polygon": 192,
	"biome_shape_smoothing_passes": 2,
	"biome_shape_edge_jitter_world": 26.0,
	"biome_shape_polygon_build_budget_per_frame": 0,
	"biome_shape_detail_enabled": true,
	"biome_shape_detail_max_visible": 260,
	"biome_shape_detail_spacing": 220.0,
	"biome_shape_detail_world_margin": 320.0,
	"transition_textures_enabled": false,
	"transition_texture_strength": 0.18,
	"transition_texture_width": 48.0,
	"transition_texture_noise_width": 24.0,
	"transition_texture_pattern_scale": 150.0,
	"transition_texture_alpha": 0.05,
	"transition_texture_min_map_strength": 0.04,
	"transition_texture_max_strength": 0.32,
	"transition_pairs": {
		"westwood|hearth_meadow": {
			"pattern": "leaf_grass_mix",
			"strength": 0.18,
			"width": 240.0
		},
		"westwood|south_thicket": {
			"pattern": "leaf_thicket_mix",
			"strength": 0.20,
			"width": 260.0
		},
		"hearth_meadow|stoneback_ridge": {
			"pattern": "grass_plate_mix",
			"strength": 0.18,
			"width": 220.0
		},
		"hearth_meadow|redfang_wilds": {
			"pattern": "grass_crack_mix",
			"strength": 0.16,
			"width": 240.0
		},
		"south_thicket|redfang_wilds": {
			"pattern": "thicket_crack_mix",
			"strength": 0.20,
			"width": 250.0
		},
		"stoneback_ridge|redfang_wilds": {
			"pattern": "plate_crack_mix",
			"strength": 0.22,
			"width": 230.0
		}
	},
	"detail_tile_world_size": 128.0,
	"blend_cache_scale": 0.65,
	"blend_cache_scale_min": 0.15,
	"blend_cache_scale_max": 0.85,
	"blend_texture_filter_linear": true,
	"visual_biome_query_bypasses_cell_cache": true,
	"visual_biome_shapes_enabled": true,
	"visual_biome_shape_use_raw_scores": true,
	"visual_biome_shape_edge_noise_strength": 0.08,
	"visual_biome_shape_edge_noise_scale": 220.0,
	"detail_chunk_build_budget_per_frame": 1,
	"detail_filter_nearest": true,
	"detail_density_multiplier": 1.0,
	"detail_alpha": 0.08,
	"secondary_detail_alpha": 0.06,
	"variation_noise_strength": 0.08,
	"max_detail_per_chunk": 80
}

const RENDER_PERFORMANCE := {
	"target_fps": 50,
	"low_fps_threshold": 45,
	"recover_fps_threshold": 55,
	"fps_ema_alpha": 0.08,
	"normal": {
		"decorative_vegetation_max_drawn": 280,
		"decorative_far_lod_every_nth": 2,
		"minimap_redraw_interval": 0.50,
		"minimap_marker_rebuild_interval": 1.0,
		"minimap_player_redraw_interval": 0.08,
		"minimap_marker_view_recenter_distance": 96.0,
		"terrain_visible_margin_chunks": 1,
		"terrain_refined_chunks_per_frame": 1,
		"terrain_build_budget_ms": 2.0,
		"terrain_refined_texture_size": 128,
		"terrain_refine_pause_when_fps_below": 45,
		"terrain_max_refined_chunks_per_second": 4,
		"resource_far_update_interval": 0.25
	},
	"pressure": {
		"decorative_vegetation_max_drawn": 160,
		"decorative_far_lod_every_nth": 4,
		"minimap_redraw_interval": 0.90,
		"minimap_marker_rebuild_interval": 1.25,
		"minimap_player_redraw_interval": 0.10,
		"minimap_marker_view_recenter_distance": 160.0,
		"terrain_visible_margin_chunks": 0,
		"terrain_refined_chunks_per_frame": 1,
		"terrain_build_budget_ms": 0.75,
		"terrain_refined_texture_size": 96,
		"terrain_refine_pause_when_fps_below": 25,
		"terrain_max_refined_chunks_per_second": 2,
		"resource_far_update_interval": 0.75
	},
	"recovery_seconds": 3.0
}

const DEBUG_HITCH_VERBOSE_LOGGING := false

const BIOME_TEXTURES_PRESETS := {
	"normal": {
		"blend_cache_scale": 0.65,
		"blend_cache_scale_min": 0.15,
		"biome_textures_enabled": true,
		"use_terrain_surface_chunk_renderer": true,
		"terrain_surface_chunk_texture_size": 96,
		"terrain_surface_refined_texture_size": 160,
		"terrain_surface_max_chunks_built_per_frame": 4,
		"terrain_surface_max_rows_built_per_frame": 12,
		"terrain_surface_max_build_ms_per_frame": 6.0,
		"terrain_surface_refine_max_rows_built_per_frame": 12,
		"terrain_surface_refine_max_build_ms_per_frame": 6.0,
	},
	"low_end": {
		"blend_cache_scale": 0.20,
		"blend_cache_scale_min": 0.15,
		"biome_textures_enabled": false,
		"use_terrain_surface_chunk_renderer": false,
		"disable_global_biome_blend_texture": true,
		"disable_global_surface_texture_on_boot": true,
		"decorative_vegetation_max_drawn": 160,
		"terrain_surface_chunk_texture_size": 64,
		"terrain_surface_refined_texture_size": 96,
		"terrain_surface_max_chunks_built_per_frame": 2,
		"terrain_surface_max_rows_built_per_frame": 8,
		"terrain_surface_max_build_ms_per_frame": 3.0,
		"terrain_surface_refine_max_rows_built_per_frame": 8,
		"terrain_surface_refine_max_build_ms_per_frame": 3.0,
	}
}

const POPULATION_RECOVERY := {
	"small_prey_min_population": 12.0,
	"small_prey_target_population": 25.0,
	"small_prey_max_population": 40.0,
	"small_prey_recovery_per_day": 4.0,
	"grazer_min_population": 6.0,
	"grazer_target_population": 14.0,
	"grazer_max_population": 25.0,
	"grazer_recovery_per_day": 2.0,
	"critical_population_predation_multiplier": 0.35,
	"healthy_biomass_recovery_multiplier": 1.25,
	"depleted_biomass_recovery_multiplier": 0.45
}

const ECOSYSTEM := {
	"simulation_tick_seconds": 5.0,
	"default_plant_biomass": 100.0,
	"max_plant_biomass": 100.0,
	"plant_regrowth_rate": 1.5,
	"initial_small_prey_population": 12.0,
	"initial_grazer_population": 6.0,
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
	"max_small_prey_population": POPULATION_RECOVERY["small_prey_max_population"],
	"max_grazer_population": POPULATION_RECOVERY["grazer_max_population"],
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
	"initial_small_prey_fear": 0.90,
	"initial_small_prey_speed": 90.0,
	"initial_small_prey_reproduction": 0.60,
	"initial_grazer_reproduction": 0.35,
	"species_generation_pressure_threshold": 0.56,
	"species_generation_ticks_required": 3.0,
	"small_prey_fear_shift_rate": 0.035,
	"small_prey_speed_shift_rate": 2.5,
	"small_prey_reproduction_shift_rate": 0.025,
	"grazer_generation_aggression_shift_rate": 0.012,
	"grazer_generation_reproduction_shift_rate": 0.020,
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


static func get_biome_textures_with_preset(preset_name: String = "normal") -> Dictionary:
	"""Apply a BIOME_TEXTURES preset by name, returning merged BIOME_TEXTURES dict."""
	var result: Dictionary = {}
	for key in BIOME_TEXTURES.keys():
		result[key] = BIOME_TEXTURES[key]
	if not BIOME_TEXTURES_PRESETS.has(preset_name):
		push_warning("Unknown biome_textures preset: %s, using normal" % preset_name)
		preset_name = "normal"
	
	var preset: Dictionary = Dictionary(BIOME_TEXTURES_PRESETS.get(preset_name, {}))
	# Merge preset values into result (preset values override defaults)
	for key in preset.keys():
		result[key] = preset[key]
	return result


static func get_first_week_difficulty(day: int) -> Dictionary:
	var clamped_day: int = clampi(day, 1, 7)
	return Dictionary(FIRST_WEEK_DIFFICULTY.get(clamped_day, FIRST_WEEK_DIFFICULTY[7]))
