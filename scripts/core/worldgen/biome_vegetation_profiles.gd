extends RefCounted
class_name BiomeVegetationProfiles

const DENSITY_MULTIPLIERS := {
	"very_low": 0.25,
	"low": 0.45,
	"low_medium": 0.65,
	"medium": 1.0,
	"high": 1.45,
	"very_high": 1.9
}

const PROFILES := {
	"westwood": {
		"density": "high",
		"tree_density": "very_high",
		"mix": {
			"conifer_tree": 65,
			"leafy_tree": 3,
			"dry_tree": 1,
			"dry_bush": 2,
			"small_bush": 12,
			"berry_bush": 5,
			"grass_patch": 8,
			"dense_grass": 4
		}
	},
	"south_thicket": {
		"density": "high",
		"tree_density": "high",
		"mix": {
			"leafy_tree": 50,
			"conifer_tree": 3,
			"dry_tree": 1,
			"dry_bush": 2,
			"small_bush": 25,
			"berry_bush": 10,
			"grass_patch": 5,
			"dense_grass": 4
		}
	},
	"hearth_meadow": {
		"density": "medium",
		"tree_density": "low",
		"mix": {
			"grass_patch": 40,
			"dense_grass": 25,
			"leafy_tree": 10,
			"small_bush": 10,
			"berry_bush": 12,
			"conifer_tree": 3,
			"dry_tree": 0,
			"dry_bush": 0
		}
	},
	"stoneback_ridge": {
		"density": "low_medium",
		"tree_density": "low",
		"mix": {
			"conifer_tree": 18,
			"dry_tree": 8,
			"dry_bush": 15,
			"small_bush": 10,
			"grass_patch": 25,
			"dense_grass": 22,
			"leafy_tree": 2,
			"berry_bush": 0
		}
	},
	"redfang_wilds": {
		"density": "medium",
		"tree_density": "low",
		"mix": {
			"dry_tree": 22,
			"dry_bush": 35,
			"small_bush": 8,
			"grass_patch": 20,
			"dense_grass": 13,
			"conifer_tree": 2,
			"leafy_tree": 0,
			"berry_bush": 0
		}
	},
	"shore": {
		"density": "medium",
		"tree_density": "very_low",
		"mix": {
			"reed": 35,
			"grass_patch": 35,
			"dense_grass": 23,
			"small_bush": 8,
			"berry_bush": 2,
			"conifer_tree": 2,
			"leafy_tree": 2,
			"dry_bush": 3,
			"dry_tree": 0
		}
	}
}


static func get_profile(biome_id: String) -> Dictionary:
	return Dictionary(PROFILES.get(biome_id, {})).duplicate(true)


static func get_density_multiplier(biome_id: String) -> float:
	var profile := get_profile(biome_id)
	var density_key := str(profile.get("density", "medium"))
	return float(DENSITY_MULTIPLIERS.get(density_key, 1.0))


static func get_mix(biome_id: String) -> Dictionary:
	var profile := get_profile(biome_id)
	return Dictionary(profile.get("mix", {})).duplicate(true)


static func pick_kind_for_biome(biome_id: String, rng: RandomNumberGenerator) -> String:
	var mix := get_mix(biome_id)
	if mix.is_empty():
		return ""
	var total := 0.0
	for value in mix.values():
		total += maxf(float(value), 0.0)
	if total <= 0.0:
		return ""
	var roll := rng.randf_range(0.0, total)
	var cursor := 0.0
	for kind in mix.keys():
		cursor += maxf(float(mix[kind]), 0.0)
		if roll <= cursor:
			return str(kind)
	return str(mix.keys()[0])


static func get_expected_dominant_kind(biome_id: String) -> String:
	var mix := get_mix(biome_id)
	var best_kind := ""
	var best_value := -1.0
	for kind in mix.keys():
		var value := float(mix[kind])
		if value > best_value:
			best_value = value
			best_kind = str(kind)
	return best_kind
