extends RefCounted
class_name BiomeRules

static func score_biomes(conditions: Dictionary) -> Dictionary:
	var height := float(conditions.get("height", 0.0))
	var moisture := float(conditions.get("moisture", 0.0))
	var vegetation := float(conditions.get("vegetation_density", 0.0))
	var danger := float(conditions.get("danger", 0.0))
	var distance_to_shore := float(conditions.get("distance_to_shore", 1.0))
	return {
		"shore": 2.8 - distance_to_shore * 3.2,
		"stoneback_ridge": height * 2.6 - vegetation * 1.5 - moisture * 0.4,
		"westwood": moisture * 1.8 + vegetation * 1.0 - danger * 0.25,
		"hearth_meadow": (1.0 - absf(moisture - 0.5) * 2.0) + (1.0 - vegetation) * 0.9 + (1.0 - danger) * 0.55,
		"south_thicket": moisture * 2.0 + vegetation * 1.8 + (1.0 - distance_to_shore) * 0.8,
		"redfang_wilds": danger * 2.2 + (1.0 - moisture) * 1.1 + distance_to_shore * 0.9
	}


static func pick_biome_id(scores: Dictionary) -> String:
	var best_id := ""
	var best_score := -INF
	for biome_id in scores.keys():
		var score := float(scores[biome_id])
		if score > best_score:
			best_score = score
			best_id = str(biome_id)
	return best_id if not best_id.is_empty() else "hearth_meadow"
