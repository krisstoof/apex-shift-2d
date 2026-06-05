extends RefCounted

const ECOSYSTEM_COMMAND := preload("res://scripts/systems/ecosystem_command.gd")
const ECOSYSTEM_DELTA := preload("res://scripts/systems/ecosystem_delta.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_command_and_delta_round_trip_to_dictionaries(failures)
	return failures


func _test_command_and_delta_round_trip_to_dictionaries(failures: Array[String]) -> void:
	var command = ECOSYSTEM_COMMAND.new_with(
		ECOSYSTEM_COMMAND.PLANT_CONSUMED,
		"hearth_meadow",
		{
			"biome_id": "hearth_meadow",
			"biomass_impact": 14.5
		}
	)
	var command_data: Dictionary = command.to_dict()
	TEST_UTILS.expect_equal(str(command_data.get("kind", "")), ECOSYSTEM_COMMAND.PLANT_CONSUMED, failures, "EcosystemCommand should keep its kind when serialized")
	TEST_UTILS.expect_equal(str(command_data.get("biome_id", "")), "hearth_meadow", failures, "EcosystemCommand should keep its biome id when serialized")
	var delta = ECOSYSTEM_DELTA.new_with(
		"hearth_meadow",
		80.0,
		65.5,
		true,
		"stressed",
		-1,
		command_data
	)
	var delta_data: Dictionary = delta.to_dict()
	TEST_UTILS.expect_equal(str(delta_data.get("biome_id", "")), "hearth_meadow", failures, "EcosystemDelta should keep its biome id when serialized")
	TEST_UTILS.expect_close(float(delta_data.get("biomass_percent_before", 0.0)), 80.0, failures, "EcosystemDelta should keep the previous biomass percent")
	TEST_UTILS.expect_close(float(delta_data.get("biomass_percent_after", 0.0)), 65.5, failures, "EcosystemDelta should keep the new biomass percent")
	TEST_UTILS.expect_equal(bool(delta_data.get("status_changed", false)), true, failures, "EcosystemDelta should remember status changes")
	TEST_UTILS.expect_equal(str(delta_data.get("new_status", "")), "stressed", failures, "EcosystemDelta should keep the new status")
	TEST_UTILS.expect_equal(int(delta_data.get("vegetation_target_delta", 0)), -1, failures, "EcosystemDelta should store vegetation target changes")
