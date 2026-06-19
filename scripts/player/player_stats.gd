extends RefCounted
class_name PlayerStats

const SURVIVAL_STATE := preload("res://scripts/core/survival/survival_state.gd")
const SURVIVAL_SYSTEM := preload("res://scripts/core/survival/survival_system.gd")
const SURVIVAL_RULES := preload("res://scripts/core/survival/survival_rules.gd")

const MAX_HEALTH := SURVIVAL_RULES.GAME_BALANCE.PLAYER_MAX_HEALTH
const MAX_HUNGER := SURVIVAL_RULES.GAME_BALANCE.PLAYER_MAX_HUNGER
const MAX_STAMINA := SURVIVAL_RULES.GAME_BALANCE.PLAYER_MAX_STAMINA
const MAX_REST := SURVIVAL_RULES.GAME_BALANCE.PLAYER_MAX_REST
const LOW_HUNGER := SURVIVAL_RULES.GAME_BALANCE.PLAYER_LOW_HUNGER
const EXHAUSTED_REST := SURVIVAL_RULES.GAME_BALANCE.PLAYER_EXHAUSTED_REST

var _state: SurvivalState = SURVIVAL_STATE.new()
var _system: SurvivalSystem = SURVIVAL_SYSTEM.new()

var health: float:
	get:
		return _state.health
	set(value):
		_state.health = clampf(value, 0.0, MAX_HEALTH)

var hunger: float:
	get:
		return _state.hunger
	set(value):
		_state.hunger = clampf(value, 0.0, MAX_HUNGER)

var stamina: float:
	get:
		return _state.stamina
	set(value):
		_state.stamina = clampf(value, 0.0, MAX_STAMINA)

var rest: float:
	get:
		return _state.rest
	set(value):
		_state.rest = clampf(value, 0.0, MAX_REST)

var campfire_regen_active: bool:
	get:
		return _state.campfire_regen_active
	set(value):
		_state.campfire_regen_active = value

var campfire_regen_distance: float:
	get:
		return _state.campfire_regen_distance
	set(value):
		_state.campfire_regen_distance = value

var god_mode: bool:
	get:
		return _state.god_mode
	set(value):
		_state.god_mode = value

func tick(delta: float, running: bool) -> void:
	_system.tick_survival(_state, delta, {"running": running})

func spend_stamina(amount: float) -> bool:
	return _system.spend_stamina(_state, amount)

func damage(amount: float) -> void:
	_system.apply_damage(_state, amount)

func heal(amount: float) -> void:
	_system.apply_heal(_state, amount)

func reduce_hunger_energy(amount: float) -> void:
	_system.reduce_hunger_energy(_state, amount)

func restore_hunger_energy(amount: float) -> void:
	_system.restore_hunger_energy(_state, amount)

func eat_food(nutrition: float) -> void:
	_system.apply_food(_state, nutrition)

func sleep_recover() -> void:
	_system.sleep_recover(_state)

func can_run() -> bool:
	return _system.can_run(_state)

func get_speed_multiplier() -> float:
	return _system.get_speed_multiplier(_state)

func get_condition_text() -> String:
	return _system.get_condition_text(_state)

func set_campfire_regen(active: bool, nearest_distance := -1.0) -> void:
	campfire_regen_active = active
	campfire_regen_distance = nearest_distance if active else -1.0

func set_god_mode(enabled: bool) -> void:
	god_mode = enabled

func is_god_mode_enabled() -> bool:
	return god_mode

func get_stamina_regen_rate() -> float:
	return _system.get_stamina_regen_rate(_state)

func get_health_regen_rate() -> float:
	return _system.get_health_regen_rate(_state)

func get_save_data() -> Dictionary:
	return {
		"health": health,
		"hunger": hunger,
		"stamina": stamina,
		"rest": rest
	}

func restore_from_data(data: Dictionary) -> void:
	health = clampf(float(data.get("health", health)), 0.0, MAX_HEALTH)
	hunger = clampf(float(data.get("hunger", hunger)), 0.0, MAX_HUNGER)
	stamina = clampf(float(data.get("stamina", stamina)), 0.0, MAX_STAMINA)
	rest = clampf(float(data.get("rest", rest)), 0.0, MAX_REST)
