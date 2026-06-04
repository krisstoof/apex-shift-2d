extends RefCounted

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const HUNGER_DIET := preload("res://scripts/creatures/hunger_diet.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_hunger_thresholds(failures)
	_test_tick_increases_hunger_and_reduces_energy(failures)
	_test_eating_reduces_hunger(failures)
	_test_choose_food_target_prefers_plants(failures)
	_test_desperate_search_radius_switches(failures)
	return failures


func _test_hunger_thresholds(failures: Array[String]) -> void:
	var diet := _make_diet(0.34, 1.0, 0.4, 1.0)
	TEST_UTILS.expect_equal(diet.get_hunger_stage(), "comfortable", failures, "Hunger below the hungry threshold should be comfortable")

	diet.hunger = 0.35
	TEST_UTILS.expect(diet.is_hungry(), failures, "Hunger at the threshold should count as hungry")
	TEST_UTILS.expect_equal(diet.get_hunger_stage(), "hungry", failures, "Hunger at the threshold should report hungry")

	diet.hunger = 0.60
	TEST_UTILS.expect(diet.is_starving(), failures, "Hunger at the starving threshold should count as starving")
	TEST_UTILS.expect_equal(diet.get_hunger_stage(), "starving", failures, "Hunger at the starving threshold should report starving")

	diet.hunger = 0.82
	TEST_UTILS.expect(diet.is_desperate(), failures, "Hunger at the desperate threshold should count as desperate")
	TEST_UTILS.expect_equal(diet.get_hunger_stage(), "desperate", failures, "Hunger at the desperate threshold should report desperate")


func _test_tick_increases_hunger_and_reduces_energy(failures: Array[String]) -> void:
	var diet := _make_diet(0.0, 1.0, 0.4, 0.75)
	var before_hunger := diet.hunger
	var before_energy := diet.energy
	diet.tick(10.0, 1.0)
	TEST_UTILS.expect(diet.hunger > before_hunger, failures, "Ticking should increase hunger")
	TEST_UTILS.expect(diet.energy < before_energy, failures, "Ticking should reduce energy")


func _test_eating_reduces_hunger(failures: Array[String]) -> void:
	var diet := _make_diet(0.50, 1.0, 0.4, 0.50)
	var reduction := float(diet.eat("plants", 0.4))
	TEST_UTILS.expect_close(reduction, 0.34, failures, "Eating plants should use plant preference when reducing hunger")
	TEST_UTILS.expect_close(diet.hunger, 0.16, failures, "Eating plants should reduce hunger by the expected amount")
	TEST_UTILS.expect(diet.energy > 0.50, failures, "Eating should restore some energy")


func _test_choose_food_target_prefers_plants(failures: Array[String]) -> void:
	var diet := _make_diet(0.50, 1.0, 0.4, 0.90)
	var target := str(diet.choose_food_target({
		"meat": 1.0,
		"plants": 1.0,
		"scavenger": 1.0
	}))
	TEST_UTILS.expect_equal(target, "plants", failures, "The helper should prefer plants for a grazer when availability is equal")


func _test_desperate_search_radius_switches(failures: Array[String]) -> void:
	var diet := _make_diet(0.50, 1.0, 0.4, 0.60)
	TEST_UTILS.expect_close(
		diet.get_food_search_radius(),
		float(GAME_BALANCE.ANIMAL_AI.get("food_search_radius", 520.0)),
		failures,
		"Non-desperate creatures should use the normal food search radius"
	)
	diet.hunger = 0.90
	TEST_UTILS.expect_close(
		diet.get_food_search_radius(),
		float(GAME_BALANCE.ANIMAL_AI.get("desperate_food_search_radius", 780.0)),
		failures,
		"Desperate creatures should use the wider food search radius"
	)


func _make_diet(hunger_value: float, max_hunger_value: float, hunger_growth_rate_value: float, energy_value: float) -> HungerDiet:
	var diet := HungerDiet.new()
	diet.configure({
		"hunger": hunger_value,
		"max_hunger": max_hunger_value,
		"hunger_growth_rate": hunger_growth_rate_value,
		"energy": energy_value,
		"plant_diet": 0.85,
		"meat_diet": 0.05,
		"scavenger_diet": 0.10,
		"hungry_threshold": 0.35,
		"starving_threshold": 0.60,
		"desperate_threshold": 0.82
	})
	return diet
