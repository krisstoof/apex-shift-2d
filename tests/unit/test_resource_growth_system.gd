extends RefCounted

const ResourceState := preload("res://scripts/core/resources/resource_state.gd")
const ResourceGrowthSystem := preload("res://scripts/core/resources/resource_growth_system.gd")


func run() -> Dictionary:
	var failures: Array[String] = []
	_test_advance_growth_days_increases_stage(failures)
	_test_fully_grown_resource_does_not_change(failures)
	_test_force_full_regrowth(failures)
	_test_reset_growth(failures)
	_test_save_restore_roundtrip(failures)
	return {"passed": failures.is_empty(), "failures": failures}


func _test_advance_growth_days_increases_stage(failures: Array[String]) -> void:
	var state := ResourceState.new()
	state.id = "r1"
	state.kind = "berry_bush"
	state.growth_stage = 0
	state.max_growth_stage = 3
	state.days_per_growth_stage = 1.0
	state.depleted = true
	state.amount = 0
	state.max_amount = 2
	var system := ResourceGrowthSystem.new()
	var changed := system.advance_growth_days([state], 1.0)
	if changed != 1:
		failures.append("Expected changed count 1 after growth advance")
	if state.growth_stage != 1:
		failures.append("Expected growth_stage 1, got %d" % state.growth_stage)
	if state.depleted:
		failures.append("Expected depleted=false after growth_stage > 0")


func _test_fully_grown_resource_does_not_change(failures: Array[String]) -> void:
	var state := ResourceState.new()
	state.id = "r2"
	state.kind = "conifer_tree"
	state.growth_stage = 3
	state.max_growth_stage = 3
	state.amount = 1
	state.max_amount = 1
	var system := ResourceGrowthSystem.new()
	var changed := system.advance_growth_days([state], 10.0)
	if changed != 0:
		failures.append("Expected no changes for fully grown resource")


func _test_force_full_regrowth(failures: Array[String]) -> void:
	var state := ResourceState.new()
	state.id = "r3"
	state.kind = "small_bush"
	state.growth_stage = 0
	state.max_growth_stage = 3
	state.amount = 0
	state.max_amount = 4
	state.depleted = true
	var system := ResourceGrowthSystem.new()
	var changed := system.force_full_regrowth([state])
	if changed != 1:
		failures.append("Expected force_full_regrowth changed count 1")
	if state.growth_stage != 3:
		failures.append("Expected growth_stage 3 after force regrowth")
	if state.depleted:
		failures.append("Expected depleted=false after force regrowth")
	if state.amount != 4:
		failures.append("Expected amount restored to max_amount")


func _test_reset_growth(failures: Array[String]) -> void:
	var state := ResourceState.new()
	state.id = "r4"
	state.kind = "berry_bush"
	state.growth_stage = 3
	state.amount = 2
	state.depleted = false
	var system := ResourceGrowthSystem.new()
	var changed := system.reset_growth([state])
	if changed != 1:
		failures.append("Expected reset_growth changed count 1")
	if state.growth_stage != 0:
		failures.append("Expected growth_stage reset to 0")
	if not state.depleted:
		failures.append("Expected depleted=true after reset")
	if state.amount != 0:
		failures.append("Expected amount reset to 0")


func _test_save_restore_roundtrip(failures: Array[String]) -> void:
	var state := ResourceState.new()
	state.id = "r5"
	state.kind = "dry_bush"
	state.position = Vector2(12.0, 34.0)
	state.biome_id = "redfang_wilds"
	state.growth_stage = 2
	state.max_growth_stage = 3
	state.amount = 1
	state.max_amount = 2
	state.depleted = false
	var data := state.to_dictionary()
	var restored := ResourceState.from_dictionary(data)
	if restored.id != state.id:
		failures.append("Expected restored id to match")
	if restored.kind != state.kind:
		failures.append("Expected restored kind to match")
	if restored.position != state.position:
		failures.append("Expected restored position to match")
	if restored.biome_id != state.biome_id:
		failures.append("Expected restored biome_id to match")
	if restored.growth_stage != state.growth_stage:
		failures.append("Expected restored growth_stage to match")
