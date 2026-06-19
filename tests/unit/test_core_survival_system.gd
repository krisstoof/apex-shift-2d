extends RefCounted

const SURVIVAL_STATE := preload("res://scripts/core/survival/survival_state.gd")
const SURVIVAL_RULES := preload("res://scripts/core/survival/survival_rules.gd")
const SURVIVAL_SYSTEM := preload("res://scripts/core/survival/survival_system.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_hunger_decay(failures)
	_test_rest_decay_and_running_stamina_drain(failures)
	_test_stamina_regen(failures)
	_test_starvation_damage(failures)
	_test_food_restore(failures)
	_test_damage_and_lethal_damage(failures)
	_test_campfire_regen_and_sleep_recover(failures)
	_test_god_mode_and_speed_multiplier(failures)
	return failures

func _test_hunger_decay(failures: Array[String]) -> void:
	var state := SURVIVAL_STATE.new()
	var system := SURVIVAL_SYSTEM.new()
	state.hunger = 100.0
	system.tick_survival(state, 1.0)
	TEST_UTILS.expect(state.hunger < 100.0, failures, "Tick should decay hunger")

func _test_rest_decay_and_running_stamina_drain(failures: Array[String]) -> void:
	var state := SURVIVAL_STATE.new()
	var system := SURVIVAL_SYSTEM.new()
	state.rest = 100.0
	state.stamina = 100.0
	system.tick_survival(state, 1.0, {"running": true})
	TEST_UTILS.expect(state.rest < 100.0, failures, "Running should decay rest")
	TEST_UTILS.expect(state.stamina < 100.0, failures, "Running should drain stamina")

func _test_stamina_regen(failures: Array[String]) -> void:
	var state := SURVIVAL_STATE.new()
	var system := SURVIVAL_SYSTEM.new()
	state.stamina = 10.0
	state.hunger = SURVIVAL_RULES.new().low_hunger + 10.0
	state.rest = SURVIVAL_RULES.new().exhausted_rest + 10.0
	system.tick_survival(state, 1.0, {"running": false})
	TEST_UTILS.expect(state.stamina > 10.0, failures, "Not running should regenerate stamina")

func _test_starvation_damage(failures: Array[String]) -> void:
	var state := SURVIVAL_STATE.new()
	var system := SURVIVAL_SYSTEM.new()
	state.hunger = 0.0
	state.health = 50.0
	system.tick_survival(state, 1.0)
	TEST_UTILS.expect(state.health < 50.0, failures, "Starvation should damage health")

func _test_food_restore(failures: Array[String]) -> void:
	var state := SURVIVAL_STATE.new()
	var system := SURVIVAL_SYSTEM.new()
	state.hunger = 10.0
	system.apply_food(state, 15.0)
	TEST_UTILS.expect(state.hunger > 10.0, failures, "Food should restore hunger")

func _test_damage_and_lethal_damage(failures: Array[String]) -> void:
	var state := SURVIVAL_STATE.new()
	var system := SURVIVAL_SYSTEM.new()
	state.health = 20.0
	system.apply_damage(state, 5.0)
	TEST_UTILS.expect_equal(state.health, 15.0, failures, "Damage should subtract health")
	system.apply_damage(state, 999.0)
	TEST_UTILS.expect_equal(state.health, 0.0, failures, "Lethal damage should clamp health to zero")

func _test_campfire_regen_and_sleep_recover(failures: Array[String]) -> void:
	var state := SURVIVAL_STATE.new()
	var system := SURVIVAL_SYSTEM.new()
	state.health = 50.0
	state.hunger = 80.0
	state.rest = 20.0
	state.stamina = 30.0
	state.campfire_regen_active = true
	system.tick_survival(state, 1.0)
	TEST_UTILS.expect(state.health > 50.0, failures, "Campfire regen should heal")
	state.health = 50.0
	state.hunger = 80.0
	state.rest = 20.0
	state.stamina = 30.0
	system.sleep_recover(state)
	TEST_UTILS.expect_equal(state.rest, SURVIVAL_RULES.new().max_rest, failures, "Sleep should restore rest")
	TEST_UTILS.expect_equal(state.stamina, SURVIVAL_RULES.new().max_stamina, failures, "Sleep should restore stamina")

func _test_god_mode_and_speed_multiplier(failures: Array[String]) -> void:
	var state := SURVIVAL_STATE.new()
	var system := SURVIVAL_SYSTEM.new()
	state.god_mode = true
	state.hunger = 100.0
	state.stamina = 5.0
	system.tick_survival(state, 1.0, {"running": true})
	TEST_UTILS.expect_equal(state.hunger, 100.0, failures, "God mode should block hunger decay")
	TEST_UTILS.expect_equal(state.stamina, 5.0 + system.get_stamina_regen_rate(state), failures, "God mode should still allow stamina regen")
	state.god_mode = false
	state.hunger = SURVIVAL_RULES.new().low_hunger - 1.0
	state.rest = SURVIVAL_RULES.new().exhausted_rest - 1.0
	TEST_UTILS.expect(system.get_speed_multiplier(state) < 1.0, failures, "Low hunger and rest should reduce speed")
