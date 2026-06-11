extends RefCounted

const PLAYER_STATS := preload("res://scripts/player/player_stats.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_default_values_are_maxed(failures)
	_test_damage_clamps_at_zero(failures)
	_test_heal_clamps_at_max(failures)
	_test_spend_stamina_success_subtracts(failures)
	_test_spend_stamina_failure_does_not_mutate(failures)
	_test_reduce_hunger_energy_clamps_at_zero(failures)
	_test_restore_hunger_energy_clamps_at_max(failures)
	_test_starvation_tick_damages_health(failures)
	_test_god_mode_blocks_damage(failures)
	_test_god_mode_blocks_hunger_energy_decay(failures)
	_test_save_load_round_trip(failures)
	_test_restore_invalid_data_clamps_values(failures)
	_test_condition_text_boundaries(failures)
	return failures


func _test_default_values_are_maxed(failures: Array[String]) -> void:
	var stats := PLAYER_STATS.new()
	TEST_UTILS.expect_equal(stats.health, PLAYER_STATS.MAX_HEALTH, failures, "Default health should start at max")
	TEST_UTILS.expect_equal(stats.hunger, PLAYER_STATS.MAX_HUNGER, failures, "Default hunger should start at max")
	TEST_UTILS.expect_equal(stats.stamina, PLAYER_STATS.MAX_STAMINA, failures, "Default stamina should start at max")
	TEST_UTILS.expect_equal(stats.rest, PLAYER_STATS.MAX_REST, failures, "Default rest should start at max")


func _test_damage_clamps_at_zero(failures: Array[String]) -> void:
	var stats := PLAYER_STATS.new()
	stats.damage(PLAYER_STATS.MAX_HEALTH * 10.0)
	TEST_UTILS.expect_equal(stats.health, 0.0, failures, "Damage should clamp health at zero")


func _test_heal_clamps_at_max(failures: Array[String]) -> void:
	var stats := PLAYER_STATS.new()
	stats.health = 1.0
	stats.heal(PLAYER_STATS.MAX_HEALTH * 10.0)
	TEST_UTILS.expect_equal(stats.health, PLAYER_STATS.MAX_HEALTH, failures, "Heal should clamp health at max")


func _test_spend_stamina_success_subtracts(failures: Array[String]) -> void:
	var stats := PLAYER_STATS.new()
	stats.stamina = 12.0
	TEST_UTILS.expect(stats.spend_stamina(5.0), failures, "Spending available stamina should succeed")
	TEST_UTILS.expect_equal(stats.stamina, 7.0, failures, "Successful stamina spending should subtract the amount")


func _test_spend_stamina_failure_does_not_mutate(failures: Array[String]) -> void:
	var stats := PLAYER_STATS.new()
	stats.stamina = 6.0
	TEST_UTILS.expect(not stats.spend_stamina(99.0), failures, "Spending too much stamina should fail")
	TEST_UTILS.expect_equal(stats.stamina, 6.0, failures, "Failed stamina spending should not mutate stamina")


func _test_reduce_hunger_energy_clamps_at_zero(failures: Array[String]) -> void:
	var stats := PLAYER_STATS.new()
	stats.reduce_hunger_energy(999.0)
	TEST_UTILS.expect_equal(stats.hunger, 0.0, failures, "Hunger should clamp at zero")
	TEST_UTILS.expect_equal(stats.stamina, 0.0, failures, "Stamina should clamp at zero")
	TEST_UTILS.expect_equal(stats.rest, 0.0, failures, "Rest should clamp at zero")


func _test_restore_hunger_energy_clamps_at_max(failures: Array[String]) -> void:
	var stats := PLAYER_STATS.new()
	stats.hunger = 1.0
	stats.stamina = 2.0
	stats.rest = 3.0
	stats.restore_hunger_energy(999.0)
	TEST_UTILS.expect_equal(stats.hunger, PLAYER_STATS.MAX_HUNGER, failures, "Hunger restore should clamp at max")
	TEST_UTILS.expect_equal(stats.stamina, PLAYER_STATS.MAX_STAMINA, failures, "Stamina restore should clamp at max")
	TEST_UTILS.expect_equal(stats.rest, PLAYER_STATS.MAX_REST, failures, "Rest restore should clamp at max")


func _test_starvation_tick_damages_health(failures: Array[String]) -> void:
	var stats := PLAYER_STATS.new()
	stats.hunger = 0.0
	stats.health = PLAYER_STATS.MAX_HEALTH
	stats.tick(1.0, false)
	TEST_UTILS.expect(stats.health < PLAYER_STATS.MAX_HEALTH, failures, "Starvation should reduce health")


func _test_god_mode_blocks_damage(failures: Array[String]) -> void:
	var stats := PLAYER_STATS.new()
	stats.set_god_mode(true)
	stats.damage(10.0)
	TEST_UTILS.expect_equal(stats.health, PLAYER_STATS.MAX_HEALTH, failures, "God mode should block damage")


func _test_god_mode_blocks_hunger_energy_decay(failures: Array[String]) -> void:
	var stats := PLAYER_STATS.new()
	stats.set_god_mode(true)
	stats.hunger = PLAYER_STATS.MAX_HUNGER
	stats.stamina = PLAYER_STATS.MAX_STAMINA
	stats.rest = PLAYER_STATS.MAX_REST
	stats.tick(1.0, true)
	TEST_UTILS.expect_equal(stats.hunger, PLAYER_STATS.MAX_HUNGER, failures, "God mode should block hunger decay")
	TEST_UTILS.expect_equal(stats.rest, PLAYER_STATS.MAX_REST, failures, "God mode should block rest decay")
	TEST_UTILS.expect(stats.stamina <= PLAYER_STATS.MAX_STAMINA, failures, "God mode should still keep stamina within bounds")


func _test_save_load_round_trip(failures: Array[String]) -> void:
	var stats := PLAYER_STATS.new()
	stats.health = 12.0
	stats.hunger = 34.0
	stats.stamina = 56.0
	stats.rest = 78.0
	var save_data := stats.get_save_data()
	var restored := PLAYER_STATS.new()
	restored.restore_from_data(save_data)
	TEST_UTILS.expect_equal(restored.get_save_data(), save_data, failures, "PlayerStats save/load should round-trip cleanly")


func _test_restore_invalid_data_clamps_values(failures: Array[String]) -> void:
	var stats := PLAYER_STATS.new()
	stats.restore_from_data({
		"health": PLAYER_STATS.MAX_HEALTH + 999.0,
		"hunger": -10.0,
		"stamina": PLAYER_STATS.MAX_STAMINA + 999.0,
		"rest": -5.0
	})
	TEST_UTILS.expect_equal(stats.health, PLAYER_STATS.MAX_HEALTH, failures, "Health should clamp on restore")
	TEST_UTILS.expect_equal(stats.hunger, 0.0, failures, "Hunger should clamp on restore")
	TEST_UTILS.expect_equal(stats.stamina, PLAYER_STATS.MAX_STAMINA, failures, "Stamina should clamp on restore")
	TEST_UTILS.expect_equal(stats.rest, 0.0, failures, "Rest should clamp on restore")


func _test_condition_text_boundaries(failures: Array[String]) -> void:
	var stats := PLAYER_STATS.new()
	TEST_UTILS.expect_equal(stats.get_condition_text(), "steady", failures, "Full stats should be steady")
	stats.hunger = 0.0
	TEST_UTILS.expect_equal(stats.get_condition_text(), "starving", failures, "Zero hunger should report starving")
	stats.hunger = PLAYER_STATS.LOW_HUNGER - 1.0
	stats.rest = PLAYER_STATS.EXHAUSTED_REST - 1.0
	TEST_UTILS.expect_equal(stats.get_condition_text(), "hungry, exhausted", failures, "Low hunger and low rest should combine labels")
