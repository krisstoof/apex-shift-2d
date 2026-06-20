extends RefCounted

const TEST_UTILS := preload("res://tests/unit/test_utils.gd")
const CREATURE_CONTEXT := preload("res://scripts/core/creatures/creature_context.gd")
const CREATURE_DECISION := preload("res://scripts/core/creatures/creature_decision.gd")
const CREATURE_STATE := preload("res://scripts/core/creatures/creature_state.gd")
const SMALL_PREY_BRAIN := preload("res://scripts/core/creatures/small_prey_brain.gd")
const GRAZER_BRAIN := preload("res://scripts/core/creatures/grazer_brain.gd")
const VARNAK_BRAIN := preload("res://scripts/core/creatures/varnak_brain.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_small_prey_flees_from_predator(failures)
	_test_small_prey_eats_food_in_range(failures)
	_test_grazer_hunts_when_hungry_without_plants(failures)
	_test_grazer_avoids_trap(failures)
	_test_varnak_avoids_campfire(failures)
	_test_creature_state_delegates_to_species_brain(failures)
	_test_brains_do_not_touch_godot_tree_or_groups(failures)
	return failures


func _test_small_prey_flees_from_predator(failures: Array[String]) -> void:
	var brain := SMALL_PREY_BRAIN.new()
	var context := CREATURE_CONTEXT.new()
	context.position = Vector2.ZERO
	context.set_predator_threat(Vector2(20.0, 0.0), 10, "varnak")
	var decision: CreatureDecision = brain.decide(_state_for("small_prey"), context)
	TEST_UTILS.expect_equal(decision.action, CREATURE_DECISION.ACTION_FLEE, failures, "Small prey should flee predator threats")
	TEST_UTILS.expect_equal(decision.target_kind, "varnak", failures, "Small prey flee decision should preserve threat kind")


func _test_small_prey_eats_food_in_range(failures: Array[String]) -> void:
	var brain := SMALL_PREY_BRAIN.new()
	var context := CREATURE_CONTEXT.new()
	context.hunger_stage = "hungry"
	context.hunger_ratio = 0.5
	context.set_food_target("plant", Vector2(8.0, 0.0), 20, true)
	var decision: CreatureDecision = brain.decide(_state_for("small_prey"), context)
	TEST_UTILS.expect_equal(decision.action, CREATURE_DECISION.ACTION_EAT, failures, "Small prey should eat reachable food")
	TEST_UTILS.expect_equal(bool(decision.metadata.get("consume", false)), true, failures, "Eat decision should request consumption through metadata")


func _test_grazer_hunts_when_hungry_without_plants(failures: Array[String]) -> void:
	var brain := GRAZER_BRAIN.new()
	var context := CREATURE_CONTEXT.new()
	context.hunger_stage = "starving"
	context.hunger_ratio = 0.72
	context.set_prey_target("small_prey", Vector2(64.0, 0.0), 30, false)
	var decision: CreatureDecision = brain.decide(_state_for("grazer"), context)
	TEST_UTILS.expect_equal(decision.action, CREATURE_DECISION.ACTION_HUNT, failures, "Hungry grazer should be able to hunt when no plant target is available")
	TEST_UTILS.expect_equal(decision.target_kind, "small_prey", failures, "Grazer hunt decision should target small prey")


func _test_grazer_avoids_trap(failures: Array[String]) -> void:
	var brain := GRAZER_BRAIN.new()
	var context := CREATURE_CONTEXT.new()
	context.hunger_stage = "hungry"
	context.set_building_hazard("trap", Vector2(12.0, 5.0), 40)
	context.set_food_target("plant", Vector2(4.0, 0.0), 41, true)
	var decision: CreatureDecision = brain.decide(_state_for("grazer"), context)
	TEST_UTILS.expect_equal(decision.action, CREATURE_DECISION.ACTION_AVOID_BUILDING, failures, "Grazer should avoid trap before eating")
	TEST_UTILS.expect_equal(decision.target_kind, "trap", failures, "Grazer avoid-building decision should identify trap")


func _test_varnak_avoids_campfire(failures: Array[String]) -> void:
	var brain := VARNAK_BRAIN.new()
	var context := CREATURE_CONTEXT.new()
	context.set_fire_threat(Vector2(-16.0, 0.0), 50)
	context.set_prey_target("small_prey", Vector2(4.0, 0.0), 51, true)
	var decision: CreatureDecision = brain.decide(_state_for("varnak"), context)
	TEST_UTILS.expect_equal(decision.action, CREATURE_DECISION.ACTION_FLEE, failures, "Varnak should flee active campfires")
	TEST_UTILS.expect_equal(decision.target_kind, "campfire", failures, "Varnak fire avoidance should expose campfire target kind")


func _test_creature_state_delegates_to_species_brain(failures: Array[String]) -> void:
	var state := _state_for("varnak")
	var context := CREATURE_CONTEXT.new()
	context.set_prey_target("small_prey", Vector2(32.0, 0.0), 60, false)
	var result := state.decide_next_behavior(context.to_dictionary())
	TEST_UTILS.expect_equal(result.behavior, CREATURE_DECISION.ACTION_HUNT, failures, "CreatureState should delegate varnak decisions to VarnakBrain")
	TEST_UTILS.expect_equal(result.target_entity_id, 60, failures, "CreatureState decision result should preserve target entity id")


func _test_brains_do_not_touch_godot_tree_or_groups(failures: Array[String]) -> void:
	for path in [
		"res://scripts/core/creatures/small_prey_brain.gd",
		"res://scripts/core/creatures/grazer_brain.gd",
		"res://scripts/core/creatures/varnak_brain.gd"
	]:
		var source := FileAccess.get_file_as_string(path)
		TEST_UTILS.expect(not source.contains("get_tree("), failures, "%s should not use get_tree()" % path)
		TEST_UTILS.expect(not source.contains("get_first_node_in_group"), failures, "%s should not scan Godot groups" % path)
		TEST_UTILS.expect(not source.contains("get_nodes_in_group"), failures, "%s should not scan Godot groups" % path)


func _state_for(creature_type: String) -> CreatureState:
	var state := CREATURE_STATE.new()
	state.creature_type = creature_type
	state.species_id = creature_type
	state.stats.health = 10.0
	state.stats.max_health = 10.0
	state.needs.max_hunger = 1.0
	state.needs.hunger = 0.0
	state.needs.energy = 1.0
	return state
