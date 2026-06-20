extends RefCounted
class_name CreatureNeeds

var hunger := 0.0
var max_hunger := 1.0
var hunger_growth_rate := 0.0
var energy := 1.0
var energy_recovery_rate := 0.0
var hungry_threshold := 0.35
var starving_threshold := 0.60
var desperate_threshold := 0.82


func duplicate_state() -> CreatureNeeds:
	var copy := CreatureNeeds.new()
	copy.load_from_save_data(to_save_data())
	return copy


func tick(delta: float, movement_intensity: float = 0.0) -> void:
	var safe_delta := maxf(delta, 0.0)
	var movement_factor := clampf(movement_intensity, 0.0, 2.0)
	hunger = clampf(hunger + hunger_growth_rate * safe_delta * (1.0 + movement_factor * 0.25), 0.0, max_hunger)
	energy = clampf(energy + energy_recovery_rate * safe_delta - movement_factor * safe_delta * 0.01, 0.0, 1.0)


func eat(amount: float) -> void:
	hunger = clampf(hunger - maxf(amount, 0.0), 0.0, max_hunger)


func is_hungry() -> bool:
	return get_hunger_ratio() >= hungry_threshold


func is_starving() -> bool:
	return get_hunger_ratio() >= starving_threshold


func is_desperate() -> bool:
	return get_hunger_ratio() >= desperate_threshold


func get_hunger_ratio() -> float:
	if max_hunger <= 0.0:
		return 0.0
	return clampf(hunger / max_hunger, 0.0, 1.0)


func get_hunger_stage() -> String:
	if is_desperate():
		return "desperate"
	if is_starving():
		return "starving"
	if is_hungry():
		return "hungry"
	return "sated"


func to_save_data() -> Dictionary:
	return {
		"hunger": hunger,
		"max_hunger": max_hunger,
		"hunger_growth_rate": hunger_growth_rate,
		"energy": energy,
		"energy_recovery_rate": energy_recovery_rate,
		"hungry_threshold": hungry_threshold,
		"starving_threshold": starving_threshold,
		"desperate_threshold": desperate_threshold
	}


func load_from_save_data(data: Dictionary) -> void:
	max_hunger = maxf(_safe_float(data, "max_hunger", max_hunger), 0.01)
	hunger = clampf(_safe_float(data, "hunger", hunger), 0.0, max_hunger)
	hunger_growth_rate = maxf(_safe_float(data, "hunger_growth_rate", hunger_growth_rate), 0.0)
	energy = clampf(_safe_float(data, "energy", energy), 0.0, 1.0)
	energy_recovery_rate = maxf(_safe_float(data, "energy_recovery_rate", energy_recovery_rate), 0.0)
	hungry_threshold = clampf(_safe_float(data, "hungry_threshold", hungry_threshold), 0.0, 1.0)
	starving_threshold = clampf(_safe_float(data, "starving_threshold", starving_threshold), 0.0, 1.0)
	desperate_threshold = clampf(_safe_float(data, "desperate_threshold", desperate_threshold), 0.0, 1.0)


static func _safe_float(data: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = data.get(key, fallback)
	if value == null:
		return fallback
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	if typeof(value) == TYPE_STRING and str(value).is_valid_float():
		return float(value)
	return fallback
