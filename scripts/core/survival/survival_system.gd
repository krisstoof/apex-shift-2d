extends RefCounted
class_name SurvivalSystem

class SurvivalResult:
	extends RefCounted

	var state: SurvivalState
	var changed := false
	var died := false
	var death_reason := ""
	var health_delta := 0.0
	var hunger_delta := 0.0
	var stamina_delta := 0.0
	var rest_delta := 0.0
	var events: Array[String] = []

const RULES_SCRIPT := preload("res://scripts/core/survival/survival_rules.gd")

var rules: SurvivalRules

func _init(custom_rules: SurvivalRules = null) -> void:
	rules = custom_rules if custom_rules != null else RULES_SCRIPT.new()

func tick_survival(state: SurvivalState, delta: float, context: Dictionary = {}) -> SurvivalResult:
	var result := SurvivalResult.new()
	result.state = state
	if state == null or delta <= 0.0:
		return result
	var running := bool(context.get("running", false))
	if not state.god_mode:
		result.hunger_delta -= rules.hunger_decay_rate * delta
		state.hunger = maxf(state.hunger + result.hunger_delta, 0.0)
		result.rest_delta -= (rules.running_rest_decay_rate if running else rules.rest_decay_rate) * delta
		state.rest = maxf(state.rest + result.rest_delta, 0.0)
		if running:
			result.stamina_delta -= rules.running_stamina_decay_rate * delta
			state.stamina = maxf(state.stamina + result.stamina_delta, 0.0)
		else:
			var stamina_regen := get_stamina_regen_rate(state)
			result.stamina_delta += stamina_regen * delta
			state.stamina = minf(state.stamina + stamina_regen * delta, rules.max_stamina)
		if state.hunger <= 0.0:
			result.health_delta -= rules.starvation_damage_per_second * delta
			state.health = maxf(state.health + result.health_delta, 0.0)
			if state.health <= 0.0:
				result.died = true
				result.death_reason = "starvation"
		elif state.hunger >= rules.low_hunger and state.rest >= rules.exhausted_rest:
			var health_regen := get_health_regen_rate(state)
			result.health_delta += health_regen * delta
			state.health = minf(state.health + health_regen * delta, rules.max_health)
	else:
		var stamina_regen := get_stamina_regen_rate(state)
		result.stamina_delta += stamina_regen * delta
		state.stamina = minf(state.stamina + stamina_regen * delta, rules.max_stamina)
		if state.hunger >= rules.low_hunger and state.rest >= rules.exhausted_rest:
			var health_regen := get_health_regen_rate(state)
			result.health_delta += health_regen * delta
			state.health = minf(state.health + health_regen * delta, rules.max_health)
	if _state_changed(result):
		result.changed = true
	return result

func apply_food(state: SurvivalState, nutrition: float) -> SurvivalResult:
	var result := _make_simple_result(state)
	if state == null:
		return result
	var before := state.hunger
	state.hunger = minf(state.hunger + nutrition, rules.max_hunger)
	result.hunger_delta = state.hunger - before
	result.changed = not is_equal_approx(result.hunger_delta, 0.0)
	return result

func apply_damage(state: SurvivalState, amount: float) -> SurvivalResult:
	var result := _make_simple_result(state)
	if state == null or state.god_mode:
		return result
	var before := state.health
	state.health = maxf(state.health - amount, 0.0)
	result.health_delta = state.health - before
	result.changed = not is_equal_approx(result.health_delta, 0.0)
	if state.health <= 0.0 and before > 0.0:
		result.died = true
		result.death_reason = "damage"
	return result

func apply_heal(state: SurvivalState, amount: float) -> SurvivalResult:
	var result := _make_simple_result(state)
	if state == null:
		return result
	var before := state.health
	state.health = minf(state.health + amount, rules.max_health)
	result.health_delta = state.health - before
	result.changed = not is_equal_approx(result.health_delta, 0.0)
	return result

func spend_stamina(state: SurvivalState, amount: float) -> bool:
	if state == null:
		return false
	if state.god_mode:
		return true
	if state.stamina < amount:
		return false
	state.stamina -= amount
	return true

func reduce_hunger_energy(state: SurvivalState, amount: float) -> SurvivalResult:
	var result := _make_simple_result(state)
	if state == null or state.god_mode:
		return result
	var before_hunger := state.hunger
	var before_stamina := state.stamina
	var before_rest := state.rest
	state.hunger = maxf(state.hunger - amount, 0.0)
	state.stamina = maxf(state.stamina - amount, 0.0)
	state.rest = maxf(state.rest - amount, 0.0)
	result.hunger_delta = state.hunger - before_hunger
	result.stamina_delta = state.stamina - before_stamina
	result.rest_delta = state.rest - before_rest
	result.changed = true
	return result

func restore_hunger_energy(state: SurvivalState, amount: float) -> SurvivalResult:
	var result := _make_simple_result(state)
	if state == null:
		return result
	var before_hunger := state.hunger
	var before_stamina := state.stamina
	var before_rest := state.rest
	state.hunger = minf(state.hunger + amount, rules.max_hunger)
	state.stamina = minf(state.stamina + amount, rules.max_stamina)
	state.rest = minf(state.rest + amount, rules.max_rest)
	result.hunger_delta = state.hunger - before_hunger
	result.stamina_delta = state.stamina - before_stamina
	result.rest_delta = state.rest - before_rest
	result.changed = true
	return result

func sleep_recover(state: SurvivalState) -> SurvivalResult:
	var result := _make_simple_result(state)
	if state == null:
		return result
	var before_hunger := state.hunger
	var before_health := state.health
	var before_stamina := state.stamina
	var before_rest := state.rest
	state.rest = rules.max_rest
	state.stamina = rules.max_stamina
	if not state.god_mode:
		state.hunger = maxf(state.hunger - rules.sleep_hunger_cost, 0.0)
	if state.hunger >= rules.low_hunger:
		state.health = minf(state.health + rules.sleep_health_restore, rules.max_health)
	result.hunger_delta = state.hunger - before_hunger
	result.health_delta = state.health - before_health
	result.stamina_delta = state.stamina - before_stamina
	result.rest_delta = state.rest - before_rest
	result.changed = true
	return result

func can_run(state: SurvivalState) -> bool:
	if state == null:
		return false
	return state.stamina > 1.0 and state.hunger > 5.0 and state.rest > 5.0

func get_speed_multiplier(state: SurvivalState) -> float:
	if state == null:
		return 1.0
	var multiplier := 1.0
	if state.hunger < rules.low_hunger:
		multiplier *= rules.low_hunger_speed_multiplier
	if state.rest < rules.exhausted_rest:
		multiplier *= rules.exhausted_rest_speed_multiplier
	return multiplier

func get_condition_text(state: SurvivalState) -> String:
	if state == null:
		return "steady"
	if state.hunger <= 0.0:
		return "starving"
	if state.hunger < rules.low_hunger and state.rest < rules.exhausted_rest:
		return "hungry, exhausted"
	if state.hunger < rules.low_hunger:
		return "hungry"
	if state.rest < rules.exhausted_rest:
		return "exhausted"
	return "steady"

func get_stamina_regen_rate(state: SurvivalState) -> float:
	if state == null:
		return rules.base_stamina_regen
	var regen := rules.base_stamina_regen
	if state.hunger < rules.low_hunger:
		regen *= rules.low_hunger_stamina_regen_multiplier
	if state.rest < rules.exhausted_rest:
		regen *= rules.exhausted_rest_stamina_regen_multiplier
	if state.campfire_regen_active:
		regen *= rules.campfire_stamina_regen_multiplier
	return regen

func get_health_regen_rate(state: SurvivalState) -> float:
	if state == null:
		return rules.health_regen_rate
	var regen := rules.health_regen_rate
	if state.campfire_regen_active:
		regen *= rules.campfire_health_regen_multiplier
	return regen

func _make_simple_result(state: SurvivalState) -> SurvivalResult:
	var result := SurvivalResult.new()
	result.state = state
	return result

func _state_changed(result: SurvivalResult) -> bool:
	return not is_equal_approx(result.health_delta, 0.0) or not is_equal_approx(result.hunger_delta, 0.0) or not is_equal_approx(result.stamina_delta, 0.0) or not is_equal_approx(result.rest_delta, 0.0)
