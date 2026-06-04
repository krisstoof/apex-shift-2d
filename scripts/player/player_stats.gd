extends RefCounted
class_name PlayerStats

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")

const MAX_HEALTH := GAME_BALANCE.PLAYER_MAX_HEALTH
const MAX_HUNGER := GAME_BALANCE.PLAYER_MAX_HUNGER
const MAX_STAMINA := GAME_BALANCE.PLAYER_MAX_STAMINA
const MAX_REST := GAME_BALANCE.PLAYER_MAX_REST
const LOW_HUNGER := GAME_BALANCE.PLAYER_LOW_HUNGER
const EXHAUSTED_REST := GAME_BALANCE.PLAYER_EXHAUSTED_REST

var health := MAX_HEALTH
var hunger := MAX_HUNGER
var stamina := MAX_STAMINA
var rest := MAX_REST
var campfire_regen_active := false
var campfire_regen_distance := -1.0
var god_mode := false

func tick(delta: float, running: bool) -> void:
	if not god_mode:
		hunger = max(hunger - GAME_BALANCE.PLAYER_HUNGER_DECAY_RATE * delta, 0.0)
		rest = max(rest - (GAME_BALANCE.PLAYER_RUNNING_REST_DECAY_RATE if running else GAME_BALANCE.PLAYER_REST_DECAY_RATE) * delta, 0.0)
		if running:
			stamina = max(stamina - GAME_BALANCE.PLAYER_RUNNING_STAMINA_DECAY_RATE * delta, 0.0)
		else:
			stamina = min(stamina + _get_stamina_regen() * delta, MAX_STAMINA)
	else:
		stamina = min(stamina + _get_stamina_regen() * delta, MAX_STAMINA)
	if not god_mode:
		if hunger <= 0.0:
			health = max(health - GAME_BALANCE.PLAYER_STARVATION_DAMAGE_PER_SECOND * delta, 0.0)
		elif hunger >= LOW_HUNGER and rest >= EXHAUSTED_REST:
			health = min(health + GAME_BALANCE.PLAYER_HEALTH_REGEN_RATE * delta, MAX_HEALTH)
	elif hunger >= LOW_HUNGER and rest >= EXHAUSTED_REST:
		health = min(health + GAME_BALANCE.PLAYER_HEALTH_REGEN_RATE * delta, MAX_HEALTH)


func spend_stamina(amount: float) -> bool:
	if god_mode:
		return true
	if stamina < amount:
		return false
	stamina -= amount
	return true


func damage(amount: float) -> void:
	if god_mode:
		return
	health = max(health - amount, 0.0)


func heal(amount: float) -> void:
	health = min(health + amount, MAX_HEALTH)


func reduce_hunger_energy(amount: float) -> void:
	if god_mode:
		return
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
	if not god_mode:
		hunger = max(hunger - GAME_BALANCE.PLAYER_SLEEP_HUNGER_COST, 0.0)
	if hunger >= LOW_HUNGER:
		health = min(health + GAME_BALANCE.PLAYER_SLEEP_HEALTH_RESTORE, MAX_HEALTH)


func can_run() -> bool:
	return stamina > 1.0 and hunger > 5.0 and rest > 5.0


func get_speed_multiplier() -> float:
	var multiplier := 1.0
	if hunger < LOW_HUNGER:
		multiplier *= GAME_BALANCE.PLAYER_LOW_HUNGER_SPEED_MULTIPLIER
	if rest < EXHAUSTED_REST:
		multiplier *= GAME_BALANCE.PLAYER_EXHAUSTED_REST_SPEED_MULTIPLIER
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


func set_campfire_regen(active: bool, nearest_distance := -1.0) -> void:
	campfire_regen_active = active
	campfire_regen_distance = nearest_distance if active else -1.0


func set_god_mode(enabled: bool) -> void:
	god_mode = enabled


func is_god_mode_enabled() -> bool:
	return god_mode


func get_stamina_regen_rate() -> float:
	return _get_stamina_regen()


func _get_stamina_regen() -> float:
	var regen := GAME_BALANCE.PLAYER_BASE_STAMINA_REGEN
	if hunger < LOW_HUNGER:
		regen *= GAME_BALANCE.PLAYER_LOW_HUNGER_STAMINA_REGEN_MULTIPLIER
	if rest < EXHAUSTED_REST:
		regen *= GAME_BALANCE.PLAYER_EXHAUSTED_REST_STAMINA_REGEN_MULTIPLIER
	if campfire_regen_active:
		regen *= GAME_BALANCE.PLAYER_CAMPFIRE_STAMINA_REGEN_MULTIPLIER
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
