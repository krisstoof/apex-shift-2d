extends RefCounted
class_name WorldSnapshotBuilder


func build_snapshot(input: Dictionary) -> Dictionary:
	return {
		"player": Dictionary(input.get("player", {})).duplicate(true),
		"time": Dictionary(input.get("time", {})).duplicate(true),
		"world": Dictionary(input.get("world", {})).duplicate(true),
		"markers": Dictionary(input.get("markers", {})).duplicate(true),
		"ecosystem": Dictionary(input.get("ecosystem", {})).duplicate(true),
		"evolution": Dictionary(input.get("evolution", {})).duplicate(true),
		"debug": Dictionary(input.get("debug", {})).duplicate(true)
	}


func build_player_snapshot(input: Dictionary) -> Dictionary:
	return {
		"position": Vector2(input.get("position", Vector2.ZERO)),
		"health": float(input.get("health", 0.0)),
		"hunger": float(input.get("hunger", 0.0)),
		"stamina": float(input.get("stamina", 0.0)),
		"rest": float(input.get("rest", 0.0)),
		"condition_text": str(input.get("condition_text", "")),
		"prompt_text": str(input.get("prompt_text", "")),
		"campfire_regen_active": bool(input.get("campfire_regen_active", false)),
		"campfire_regen_distance": float(input.get("campfire_regen_distance", -1.0)),
		"inventory": Dictionary(input.get("inventory", {})).duplicate(true),
		"has_spear": bool(input.get("has_spear", false)),
		"has_bow": bool(input.get("has_bow", false)),
		"torch_active": bool(input.get("torch_active", false)),
		"torch_remaining_seconds": float(input.get("torch_remaining_seconds", 0.0))
	}


func build_time_snapshot(input: Dictionary) -> Dictionary:
	return {
		"day": int(input.get("day", 1)),
		"clock_time": str(input.get("clock_time", "--:--")),
		"time_label": str(input.get("time_label", "")),
		"phase_label": str(input.get("phase_label", "")),
		"night_amount": float(input.get("night_amount", 0.0))
	}


func build_world_snapshot(input: Dictionary) -> Dictionary:
	return {
		"world_rect": Rect2(input.get("world_rect", Rect2())),
		"biome_zones": Array(input.get("biome_zones", [])).duplicate(true),
		"landmarks": Array(input.get("landmarks", [])).duplicate(true),
		"landmark_counts": Dictionary(input.get("landmark_counts", {})).duplicate(true),
		"world_seed": int(input.get("world_seed", 0)),
		"current_biome_name": str(input.get("current_biome_name", "")),
		"current_biome_texture_id": str(input.get("current_biome_texture_id", "none")),
		"nearest_landmark": Dictionary(input.get("nearest_landmark", {})).duplicate(true),
		"out_of_bounds_count": int(input.get("out_of_bounds_count", 0)),
		"resource_counts": Dictionary(input.get("resource_counts", {})).duplicate(true),
		"building_counts": Dictionary(input.get("building_counts", {})).duplicate(true),
		"biome_texture_cache": Dictionary(input.get("biome_texture_cache", {})).duplicate(true),
		"small_prey_spawn_sync": Dictionary(input.get("small_prey_spawn_sync", {})).duplicate(true),
		"varnak_spawn_sync": Dictionary(input.get("varnak_spawn_sync", {})).duplicate(true),
		"varnak_population": Dictionary(input.get("varnak_population", {})).duplicate(true),
		"creature_ai_state_counts": Dictionary(input.get("creature_ai_state_counts", {})).duplicate(true),
		"visibility_culling": Dictionary(input.get("visibility_culling", {})).duplicate(true),
		"vegetation_spawn": Dictionary(input.get("vegetation_spawn", {})).duplicate(true),
		"landmark_overlay_enabled": bool(input.get("landmark_overlay_enabled", false)),
		"biome_textures_enabled": bool(input.get("biome_textures_enabled", true)),
		"biome_terrain_accents_enabled": bool(input.get("biome_terrain_accents_enabled", false)),
		"low_end_rendering": bool(input.get("low_end_rendering", false))
	}


func build_marker_snapshot(resources: Array, campfires: Array, varnaks: Array, small_prey: Array, grazers: Array) -> Dictionary:
	return {
		"resources": resources.duplicate(true),
		"campfires": campfires.duplicate(true),
		"varnaks": varnaks.duplicate(true),
		"small_prey": small_prey.duplicate(true),
		"grazers": grazers.duplicate(true)
	}


func build_debug_snapshot(input: Dictionary) -> Dictionary:
	return Dictionary(input).duplicate(true)
