extends RefCounted
class_name PlayerStats

var health := 100.0
var hunger := 100.0
var stamina := 100.0
var rest := 100.0

const MAX_HEALTH := 100.0
const MAX_HUNGER := 100.0
const MAX_STAMINA := 100.0
const MAX_REST := 100.0
const LOW_HUNGER := 25.0
const EXHAUSTED_REST := 20.0

func tick(delta: float, running: bool) -> void:
	hunger = max(hunger - 0.9 * delta, 0.0)
	rest = max(rest - (0.9 if running else 0.35) * delta, 0.0)
	if running:
		stamina = max(stamina - 18.0 * delta, 0.0)
	else:
		stamina = min(stamina + _get_stamina_regen() * delta, MAX_STAMINA)
	if hunger <= 0.0:
		health = max(health - 3.0 * delta, 0.0)
	elif hunger >= LOW_HUNGER and rest >= EXHAUSTED_REST:
		health = min(health + 0.45 * delta, MAX_HEALTH)


func spend_stamina(amount: float) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	return true


func damage(amount: float) -> void:
	health = max(health - amount, 0.0)


func heal(amount: float) -> void:
	health = min(health + amount, MAX_HEALTH)


func reduce_hunger_energy(amount: float) -> void:
	hunger = max(hunger - amount, 0.0)
	stamina = max(stamina - amount, 0.0)
	rest = max(rest - amount, 0.0)


func restore_hunger_energy(amount: float) -> void:
	hunger = min(hunger + amount, MAX_HUNGER)
	stamina = min(stamina + amount, MAX_STAMINA)
	rest = min(rest + amount, MAX_REST)


func eat_food(nutrition: float) -> void:
	hunger = min(hunger + nutrition, MAX_HUNGER)


func sleep_recover() -> void:
	rest = MAX_REST
	stamina = MAX_STAMINA
	hunger = max(hunger - 8.0, 0.0)
	if hunger >= LOW_HUNGER:
		health = min(health + 35.0, MAX_HEALTH)


func can_run() -> bool:
	return stamina > 1.0 and hunger > 5.0 and rest > 5.0


func get_speed_multiplier() -> float:
	var multiplier := 1.0
	if hunger < LOW_HUNGER:
		multiplier *= 0.82
	if rest < EXHAUSTED_REST:
		multiplier *= 0.85
	return multiplier


func get_condition_text() -> String:
	if hunger <= 0.0:
		return "starving"
	if hunger < LOW_HUNGER and rest < EXHAUSTED_REST:
		return "hungry, exhausted"
	if hunger < LOW_HUNGER:
		return "hungry"
	if rest < EXHAUSTED_REST:
		return "exhausted"
	return "steady"


func _get_stamina_regen() -> float:
	var regen := 16.0
	if hunger < LOW_HUNGER:
		regen *= 0.45
	if rest < EXHAUSTED_REST:
		regen *= 0.55
	return regen


func get_save_data() -> Dictionary:
	return {
		"health": health,
		"hunger": hunger,
		"stamina": stamina,
		"rest": rest
	}


func restore_from_data(data: Dictionary) -> void:
	health = clamp(float(data.get("health", health)), 0.0, MAX_HEALTH)
	hunger = clamp(float(data.get("hunger", hunger)), 0.0, MAX_HUNGER)
	stamina = clamp(float(data.get("stamina", stamina)), 0.0, MAX_STAMINA)
	rest = clamp(float(data.get("rest", rest)), 0.0, MAX_REST)
