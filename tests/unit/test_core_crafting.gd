extends RefCounted

const INVENTORY_STATE := preload("res://scripts/core/inventory/inventory_state.gd")
const CRAFTING_CATALOG := preload("res://scripts/core/crafting/crafting_catalog.gd")
const CRAFTING_RECIPE := preload("res://scripts/core/crafting/crafting_recipe.gd")
const CRAFTING_SYSTEM := preload("res://scripts/core/crafting/crafting_system.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_craft_success(failures)
	_test_missing_ingredients(failures)
	_test_inventory_update_and_output_rolls_back_on_full_inventory(failures)
	_test_recipe_without_output(failures)
	return failures


func _build_catalog():
	var catalog := CRAFTING_CATALOG.new()
	catalog.add_recipe(CRAFTING_RECIPE.new("torch", {"wood": 2, "fiber": 1}, {"torch": 1}, {"effect": "craft_item"}))
	catalog.add_recipe(CRAFTING_RECIPE.new("spear", {"wood": 3, "fiber": 2}, {}, {"effect": "unlock_flag", "flag": "has_spear"}))
	catalog.add_recipe(CRAFTING_RECIPE.new("bulk_torch", {"wood": 2, "fiber": 1}, {"torch": 21}, {"effect": "craft_item"}))
	return catalog


func _test_craft_success(failures: Array[String]) -> void:
	var inventory := INVENTORY_STATE.new(9)
	inventory.add_item("wood", 2)
	inventory.add_item("fiber", 1)
	var system := CRAFTING_SYSTEM.new(_build_catalog())
	var result = system.craft("torch", inventory)
	TEST_UTILS.expect(result.is_success(), failures, "Torch craft should succeed")
	TEST_UTILS.expect_equal(inventory.get_amount("wood"), 0, failures, "Torch craft should consume wood")
	TEST_UTILS.expect_equal(inventory.get_amount("fiber"), 0, failures, "Torch craft should consume fiber")
	TEST_UTILS.expect_equal(inventory.get_amount("torch"), 1, failures, "Torch craft should produce torch")


func _test_missing_ingredients(failures: Array[String]) -> void:
	var inventory := INVENTORY_STATE.new(9)
	inventory.add_item("wood", 1)
	var system := CRAFTING_SYSTEM.new(_build_catalog())
	TEST_UTILS.expect(not system.can_craft("torch", inventory), failures, "Torch should not be craftable with missing resources")
	var missing := system.get_missing_ingredients("torch", inventory)
	TEST_UTILS.expect_equal(int(missing.get("wood", 0)), 1, failures, "Missing wood should be reported")
	TEST_UTILS.expect_equal(int(missing.get("fiber", 0)), 1, failures, "Missing fiber should be reported")
	var result = system.craft("torch", inventory)
	TEST_UTILS.expect(not result.is_success(), failures, "Craft should fail when ingredients are missing")
	TEST_UTILS.expect_equal(inventory.get_amount("wood"), 1, failures, "Failed craft should not change inventory")


func _test_inventory_update_and_output_rolls_back_on_full_inventory(failures: Array[String]) -> void:
	var inventory := INVENTORY_STATE.new(2)
	inventory.add_item("wood", 2)
	inventory.add_item("fiber", 1)
	inventory.add_item("stone", 20)
	var system := CRAFTING_SYSTEM.new(_build_catalog())
	var result = system.craft("bulk_torch", inventory)
	TEST_UTILS.expect(not result.is_success(), failures, "Craft should fail when output cannot fit")
	TEST_UTILS.expect_equal(inventory.get_amount("wood"), 2, failures, "Failed craft should roll back consumed wood")
	TEST_UTILS.expect_equal(inventory.get_amount("fiber"), 1, failures, "Failed craft should roll back consumed fiber")
	TEST_UTILS.expect_equal(inventory.get_amount("torch"), 0, failures, "Failed craft should not add output")


func _test_recipe_without_output(failures: Array[String]) -> void:
	var inventory := INVENTORY_STATE.new(9)
	inventory.add_item("wood", 3)
	inventory.add_item("fiber", 2)
	var system := CRAFTING_SYSTEM.new(_build_catalog())
	var result = system.craft("spear", inventory)
	TEST_UTILS.expect(result.is_success(), failures, "Spear craft should succeed")
	TEST_UTILS.expect_equal(inventory.get_amount("wood"), 0, failures, "Spear craft should consume wood")
	TEST_UTILS.expect_equal(inventory.get_amount("fiber"), 0, failures, "Spear craft should consume fiber")
	TEST_UTILS.expect_equal(inventory.get_amount("torch"), 0, failures, "Spear craft should not produce items")
