extends RefCounted
class_name HungerDiet

var hunger := 0.0
var max_hunger := 1.0
var hunger_growth_rate := 0.2
var energy := 1.0
var plant_diet := 1.0
var meat_diet := 0.0
var scavenger_diet := 0.0


func configure(traits: Dictionary, defaults: Dictionary = {}) -> void:
	max_hunger = float(traits.get("max_hunger", defaults.get("max_hunger", max_hunger)))
	hunger_growth_rate = float(traits.get("hunger_growth_rate", traits.get("hunger_rate", defaults.get("hunger_growth_rate", hunger_growth_rate))))
	energy = float(traits.get("energy", defaults.get("energy", energy)))
	plant_diet = float(traits.get("plant_diet", defaults.get("plant_diet", plant_diet)))
	meat_diet = float(traits.get("meat_diet", defaults.get("meat_diet", meat_diet)))
	scavenger_diet = float(traits.get("scavenger_diet", defaults.get("scavenger_diet", scavenger_diet)))
	max_hunger = max(max_hunger, 0.01)
	hunger = clamp(float(traits.get("hunger", defaults.get("hunger", hunger))), 0.0, max_hunger)
	energy = clamp(energy, 0.0, 1.0)


func tick(delta: float, movement_intensity: float = 0.0) -> void:
	hunger = clamp(hunger + hunger_growth_rate * delta, 0.0, max_hunger)
	var energy_delta: float = delta * (0.015 + clamp(movement_intensity, 0.0, 1.0) * 0.035)
	energy = clamp(energy - energy_delta + delta * 0.02 * (1.0 - get_hunger_ratio()), 0.0, 1.0)


func eat(food_kind: String, nutrition: float) -> float:
	var preference := get_preference(food_kind)
	var reduction: float = nutrition * max(preference, 0.05)
	hunger = max(hunger - reduction, 0.0)
	energy = clamp(energy + nutrition * 0.35, 0.0, 1.0)
	return reduction


func get_preference(food_kind: String) -> float:
	match food_kind:
		"plants":
			return plant_diet
		"meat":
			return meat_diet
		"scavenger":
			return scavenger_diet
		_:
			return 0.0


func choose_food_target(available_food: Dictionary) -> String:
	var best_kind := ""
	var best_score := 0.0
	for food_kind in available_food.keys():
		var availability := float(available_food[food_kind])
		var score := availability * get_preference(str(food_kind))
		if score > best_score:
			best_kind = str(food_kind)
			best_score = score
	return best_kind


func get_hunger_ratio() -> float:
	return clamp(hunger / max_hunger, 0.0, 1.0)


func get_risk_drive() -> float:
	return clamp(get_hunger_ratio() * 0.75 + (1.0 - energy) * 0.25, 0.0, 1.0)


func get_debug_data() -> Dictionary:
	return {
		"hunger": hunger,
		"max_hunger": max_hunger,
		"hunger_ratio": get_hunger_ratio(),
		"hunger_growth_rate": hunger_growth_rate,
		"energy": energy,
		"plant_diet": plant_diet,
		"meat_diet": meat_diet,
		"scavenger_diet": scavenger_diet,
		"risk_drive": get_risk_drive()
	}
