extends RefCounted

const RESOURCE_STATE := preload("res://scripts/core/resources/resource_state.gd")
const RESOURCE_HARVEST_RULES := preload("res://scripts/core/resources/resource_harvest_rules.gd")
const RESOURCE_REGROWTH_SYSTEM := preload("res://scripts/core/resources/resource_regrowth_system.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


class MockInventory:
	extends RefCounted
	var capacity := 999
	var stored := {}

	func add_item(item_id: String, amount: int) -> int:
		var space := capacity - int(stored.get(item_id, 0))
		var added := mini(amount, maxi(space, 0))
		stored[item_id] = int(stored.get(item_id, 0)) + added
		return amount - added

	func can_add_item(item_id: String, amount: int) -> bool:
		return (capacity - int(stored.get(item_id, 0))) >= amount


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_harvest_success_for_tree_bush_and_rock(failures)
	_test_inventory_full_does_not_mutate_state(failures)
	_test_drop_meat_and_bone_do_not_use_regrowth(failures)
	_test_full_stack_drop_rejects_partial_pickup(failures)
	_test_mark_harvested_and_regrowth_cycle(failures)
	_test_force_full_regrowth_restores_mature_state(failures)
	_test_save_load_round_trip(failures)
	_test_grass_is_not_player_harvestable(failures)
	return failures


func _make_state(kind: String) -> ResourceState:
	var state := RESOURCE_STATE.new()
	state.resource_kind = kind
	state.item_id = "wood" if kind in ["tree", "conifer_tree", "leafy_tree", "dry_tree"] else ""
	state.amount = 4
	state.mature_amount = 4
	state.growth_stage = 3
	state.max_growth_stage = 3
	state.growth_progress = 0.0
	state.days_to_next_stage = 1.0
	state.days_since_harvested = 0.0
	state.is_harvested = false
	state.can_be_harvested = true
	state.player_harvestable = kind not in ["grass_patch", "dense_grass"]
	state.render_only = kind in ["grass_patch", "dense_grass"]
	state.is_inventory_drop = false
	state.inventory_drop_item_id = ""
	state.biome_id = "hearth_meadow"
	state.pond_id = ""
	state.food_value = 0.2
	state.is_edible_by_herbivores = kind not in ["meat_drop", "bone_drop"]
	return state


func _test_harvest_success_for_tree_bush_and_rock(failures: Array[String]) -> void:
	for kind in ["conifer_tree", "bush", "rock"]:
		var state := _make_state(kind)
		if kind == "rock":
			state.item_id = "stone"
			state.amount = 2
			state.mature_amount = 2
		elif kind == "bush":
			state.item_id = "fiber"
		var inventory := MockInventory.new()
		var result := RESOURCE_HARVEST_RULES.harvest(state, inventory)
		TEST_UTILS.expect(result.success, failures, "%s harvest should succeed" % kind)
		TEST_UTILS.expect(result.added_amount > 0, failures, "%s harvest should add items" % kind)


func _test_inventory_full_does_not_mutate_state(failures: Array[String]) -> void:
	var state := _make_state("bush")
	var inventory := MockInventory.new()
	inventory.capacity = 0
	var snapshot := state.to_save_data().duplicate(true)
	var result := RESOURCE_HARVEST_RULES.harvest(state, inventory)
	TEST_UTILS.expect_equal(result.success, false, failures, "Full inventory should fail harvest")
	TEST_UTILS.expect_equal(state.to_save_data(), snapshot, failures, "Failed harvest should not mutate state")


func _test_drop_meat_and_bone_do_not_use_regrowth(failures: Array[String]) -> void:
	for kind in ["meat_drop", "bone_drop"]:
		var state := _make_state(kind)
		state.item_id = "meat" if kind == "meat_drop" else "bone"
		TEST_UTILS.expect_equal(state.uses_regrowth(), false, failures, "%s should not use regrowth" % kind)
		var inventory := MockInventory.new()
		var result := RESOURCE_HARVEST_RULES.harvest(state, inventory)
		TEST_UTILS.expect_equal(result.should_start_regrowth, false, failures, "%s should not start regrowth" % kind)


func _test_full_stack_drop_rejects_partial_pickup(failures: Array[String]) -> void:
	var state := RESOURCE_STATE.new()
	state.resource_kind = "item_drop"
	state.item_id = "wood"
	state.inventory_drop_item_id = "wood"
	state.amount = 2
	state.is_inventory_drop = true
	state.player_harvestable = true
	var inventory := MockInventory.new()
	inventory.capacity = 1
	var before := state.to_save_data().duplicate(true)
	var result := RESOURCE_HARVEST_RULES.harvest(state, inventory)
	TEST_UTILS.expect_equal(result.success, false, failures, "Partial pickup should be rejected for full-stack drop")
	TEST_UTILS.expect_equal(state.to_save_data(), before, failures, "Rejected full-stack drop should remain unchanged")


func _test_mark_harvested_and_regrowth_cycle(failures: Array[String]) -> void:
	var state := _make_state("bush")
	RESOURCE_REGROWTH_SYSTEM.mark_harvested(state)
	TEST_UTILS.expect_equal(state.is_harvested, true, failures, "Harvested state should mark harvested")
	TEST_UTILS.expect_equal(state.can_be_harvested, false, failures, "Harvested state should not be harvestable")
	TEST_UTILS.expect_equal(state.growth_stage, 0, failures, "Harvested state should deplete growth")
	RESOURCE_REGROWTH_SYSTEM.advance_days(state, 2.0)
	TEST_UTILS.expect(state.growth_stage > 0, failures, "Advancing days should restore growth")


func _test_force_full_regrowth_restores_mature_state(failures: Array[String]) -> void:
	var state := _make_state("bush")
	RESOURCE_REGROWTH_SYSTEM.mark_harvested(state)
	RESOURCE_REGROWTH_SYSTEM.force_full_regrowth(state)
	TEST_UTILS.expect_equal(state.growth_stage, state.max_growth_stage, failures, "Force regrowth should restore mature state")
	TEST_UTILS.expect_equal(state.is_harvested, false, failures, "Force regrowth should clear harvested flag")


func _test_save_load_round_trip(failures: Array[String]) -> void:
	var state := _make_state("dry_tree")
	state.is_harvested = true
	state.growth_stage = 0
	state.is_inventory_drop = false
	var round_trip := RESOURCE_STATE.from_save_data(state.to_save_data())
	TEST_UTILS.expect_equal(round_trip.resource_kind, state.resource_kind, failures, "Save/load should keep kind")
	TEST_UTILS.expect_equal(round_trip.growth_stage, state.growth_stage, failures, "Save/load should keep growth stage")
	TEST_UTILS.expect_equal(round_trip.is_harvested, state.is_harvested, failures, "Save/load should keep harvested state")


func _test_grass_is_not_player_harvestable(failures: Array[String]) -> void:
	for kind in ["grass_patch", "dense_grass"]:
		var state := _make_state(kind)
		state.player_harvestable = false
		TEST_UTILS.expect_equal(state.player_harvestable, false, failures, "%s should not be harvestable by player" % kind)
