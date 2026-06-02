extends RefCounted
class_name HungerDiet

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const BASE_HUNGER_TIME_SCALE := 0.05
const MOVEMENT_HUNGER_TIME_SCALE := 0.06

var hunger := 0.0
var max_hunger := 1.0
var hunger_growth_rate := 0.2
var energy := 1.0
var plant_diet := 1.0
var meat_diet := 0.0
var scavenger_diet := 0.0
var hungry_threshold := 0.35
var starving_threshold := 0.60
var desperate_threshold := 0.82


func configure(traits: Dictionary, defaults: Dictionary = {}) -> void:
	max_hunger = float(traits.get("max_hunger", defaults.get("max_hunger", max_hunger)))
	hunger_growth_rate = float(traits.get("hunger_growth_rate", traits.get("hunger_rate", defaults.get("hunger_growth_rate", hunger_growth_rate))))
	energy = float(traits.get("energy", defaults.get("energy", energy)))
	plant_diet = float(traits.get("plant_diet", defaults.get("plant_diet", plant_diet)))
	meat_diet = float(traits.get("meat_diet", defaults.get("meat_diet", meat_diet)))
	scavenger_diet = float(traits.get("scavenger_diet", defaults.get("scavenger_diet", scavenger_diet)))
	hungry_threshold = float(traits.get("hungry_threshold", defaults.get("hungry_threshold", GAME_BALANCE.ANIMAL_AI.get("hungry_threshold", hungry_threshold))))
	starving_threshold = float(traits.get("starving_threshold", defaults.get("starving_threshold", GAME_BALANCE.ANIMAL_AI.get("starving_threshold", starving_threshold))))
	desperate_threshold = float(traits.get("desperate_threshold", defaults.get("desperate_threshold", GAME_BALANCE.ANIMAL_AI.get("desperate_threshold", desperate_threshold))))
	max_hunger = max(max_hunger, 0.01)
	hunger = clamp(float(traits.get("hunger", defaults.get("hunger", hunger))), 0.0, max_hunger)
	energy = clamp(energy, 0.0, 1.0)
	hungry_threshold = clamp(hungry_threshold, 0.01, 0.98)
	starving_threshold = clamp(max(starving_threshold, hungry_threshold + 0.01), 0.02, 0.99)
	desperate_threshold = clamp(max(desperate_threshold, starving_threshold + 0.01), 0.03, 1.0)


func tick(delta: float, movement_intensity: float = 0.0) -> void:
	var movement_factor: float = clamp(movement_intensity, 0.0, 1.0)
	var base_hunger_delta: float = hunger_growth_rate * BASE_HUNGER_TIME_SCALE * delta
	var movement_hunger_delta: float = hunger_growth_rate * movement_factor * MOVEMENT_HUNGER_TIME_SCALE * delta
	hunger = clamp(hunger + base_hunger_delta + movement_hunger_delta, 0.0, max_hunger)
	var energy_delta: float = delta * (0.015 + movement_factor * 0.035)
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


func get_hunger_stage() -> String:
	var ratio := get_hunger_ratio()
	if ratio >= desperate_threshold:
		return "desperate"
	if ratio >= starving_threshold:
		return "starving"
	if ratio >= hungry_threshold:
		return "hungry"
	return "comfortable"


func is_hungry() -> bool:
	return get_hunger_ratio() >= hungry_threshold


func is_starving() -> bool:
	return get_hunger_ratio() >= starving_threshold


func is_desperate() -> bool:
	return get_hunger_ratio() >= desperate_threshold


func get_food_search_radius() -> float:
	if is_desperate():
		return float(GAME_BALANCE.ANIMAL_AI.get("desperate_food_search_radius", 780.0))
	return float(GAME_BALANCE.ANIMAL_AI.get("food_search_radius", 520.0))


func get_risk_drive() -> float:
	return clamp(get_hunger_ratio() * 0.75 + (1.0 - energy) * 0.25, 0.0, 1.0)


func get_debug_data() -> Dictionary:
	return {
		"hunger": hunger,
		"max_hunger": max_hunger,
		"hunger_ratio": get_hunger_ratio(),
		"hunger_stage": get_hunger_stage(),
		"hunger_growth_rate": hunger_growth_rate,
		"energy": energy,
		"plant_diet": plant_diet,
		"meat_diet": meat_diet,
		"scavenger_diet": scavenger_diet,
		"risk_drive": get_risk_drive()
	}
