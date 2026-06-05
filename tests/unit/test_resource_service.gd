extends RefCounted

const RESOURCE_SERVICE := preload("res://scripts/world/resource_service.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


class TestResourceNode:
	extends Node2D

	var resource_kind := "grass_patch"
	var should_change := false
	var growth_calls: Array[float] = []
	var save_data := {}
	var restored_data := {}

	func advance_growth_days(days: float) -> bool:
		growth_calls.append(days)
		return should_change

	func get_save_data() -> Dictionary:
		return Dictionary(save_data).duplicate(true)

	func restore_from_data(data: Dictionary) -> void:
		restored_data = Dictionary(data).duplicate(true)


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_resource_service_counts_only_changed_growth_updates(failures)
	_test_resource_service_builds_save_data_from_valid_resources(failures)
	_test_resource_service_normalizes_restore_data(failures)
	_test_resource_service_builds_restore_plan_with_position_callback(failures)
	_test_resource_service_applies_restore_data_to_valid_resource_nodes(failures)
	_test_resource_service_applies_restore_plan_via_callbacks(failures)
	_test_resource_service_restores_resources_from_raw_data_end_to_end(failures)
	_test_resource_service_counts_resources_by_kind(failures)
	return failures


func _test_resource_service_counts_only_changed_growth_updates(failures: Array[String]) -> void:
	var service := RESOURCE_SERVICE.new()
	var grass := TestResourceNode.new()
	grass.resource_kind = "grass_patch"
	grass.should_change = true
	var bush := TestResourceNode.new()
	bush.resource_kind = "bush"
	bush.should_change = false
	var changed_count := service.advance_growth_days([grass, bush], 2.5)
	TEST_UTILS.expect_equal(changed_count, 1, failures, "ResourceService should count only resources whose growth state actually changed")
	TEST_UTILS.expect_equal(grass.growth_calls.size(), 1, failures, "ResourceService should call advance_growth_days on valid resources")
	TEST_UTILS.expect_equal(bush.growth_calls.size(), 1, failures, "ResourceService should still visit resources even when they do not change state")
	TEST_UTILS.expect_close(float(grass.growth_calls[0]), 2.5, failures, "ResourceService should pass the requested growth delta to resources")
	grass.queue_free()
	bush.queue_free()


func _test_resource_service_builds_save_data_from_valid_resources(failures: Array[String]) -> void:
	var service := RESOURCE_SERVICE.new()
	var grass := TestResourceNode.new()
	grass.resource_kind = "grass_patch"
	grass.save_data = {
		"resource_kind": "grass_patch",
		"position": {"x": 12.0, "y": -8.0},
		"regrowth_timer": 4.5
	}
	var bush := TestResourceNode.new()
	bush.resource_kind = "bush"
	bush.save_data = {
		"resource_kind": "bush",
		"position": {"x": 40.0, "y": 15.0},
		"harvested": false
	}
	var save_data := service.build_save_data([grass, bush])
	TEST_UTILS.expect_equal(save_data.size(), 2, failures, "ResourceService should export one save entry per valid resource")
	if save_data.size() == 2:
		var grass_data := Dictionary(save_data[0])
		var bush_data := Dictionary(save_data[1])
		TEST_UTILS.expect_equal(str(grass_data.get("resource_kind", "")), "grass_patch", failures, "ResourceService should preserve resource kind in exported save data")
		TEST_UTILS.expect_equal(str(bush_data.get("resource_kind", "")), "bush", failures, "ResourceService should preserve later resource kinds in exported save data")
		var grass_position := Dictionary(grass_data.get("position", {}))
		TEST_UTILS.expect_close(float(grass_position.get("x", 0.0)), 12.0, failures, "ResourceService should preserve nested position X in exported save data")
		TEST_UTILS.expect_close(float(grass_position.get("y", 0.0)), -8.0, failures, "ResourceService should preserve nested position Y in exported save data")
	grass.queue_free()
	bush.queue_free()


func _test_resource_service_normalizes_restore_data(failures: Array[String]) -> void:
	var service := RESOURCE_SERVICE.new()
	var normalized := service.normalize_restore_data([
		{
			"kind": "grass_patch",
			"position": {"x": 12.0, "y": -8.0},
			"harvested": false
		},
		{
			"resource_kind": "bush",
			"position": "bad_position"
		},
		"not_a_dictionary"
	])
	TEST_UTILS.expect_equal(normalized.size(), 2, failures, "ResourceService should keep only dictionary restore entries")
	if normalized.size() == 2:
		var first := Dictionary(normalized[0])
		var second := Dictionary(normalized[1])
		TEST_UTILS.expect_equal(str(first.get("resource_kind", "")), "grass_patch", failures, "ResourceService should normalize legacy kind into resource_kind")
		var first_position := Dictionary(first.get("position", {}))
		TEST_UTILS.expect_close(float(first_position.get("x", 0.0)), 12.0, failures, "ResourceService should preserve valid restore position X")
		TEST_UTILS.expect_close(float(first_position.get("y", 0.0)), -8.0, failures, "ResourceService should preserve valid restore position Y")
		TEST_UTILS.expect_equal(str(second.get("resource_kind", "")), "bush", failures, "ResourceService should preserve modern resource_kind fields")
		var second_position := Dictionary(second.get("position", {}))
		TEST_UTILS.expect_close(float(second_position.get("x", 0.0)), 0.0, failures, "ResourceService should repair invalid restore positions to zero X")
		TEST_UTILS.expect_close(float(second_position.get("y", 0.0)), 0.0, failures, "ResourceService should repair invalid restore positions to zero Y")


func _test_resource_service_builds_restore_plan_with_position_callback(failures: Array[String]) -> void:
	var service := RESOURCE_SERVICE.new()
	var callback_calls: Array[String] = []
	var restore_plan := service.build_restore_plan(
		[
			{
				"kind": "grass_patch",
				"position": {"x": 12.0, "y": -8.0},
				"harvested": false
			},
			{
				"resource_kind": "bush",
				"position": {"x": 40.0, "y": 15.0}
			}
		],
		func(resource_kind: String, position_data: Dictionary) -> Dictionary:
			callback_calls.append("%s:%s:%s" % [resource_kind, str(position_data.get("x", 0.0)), str(position_data.get("y", 0.0))])
			return {
				"x": float(position_data.get("x", 0.0)) + 5.0,
				"y": float(position_data.get("y", 0.0)) - 3.0
			}
	)
	TEST_UTILS.expect_equal(restore_plan.size(), 2, failures, "ResourceService should build one restore plan entry per normalized resource entry")
	TEST_UTILS.expect_equal(callback_calls.size(), 2, failures, "ResourceService should call the position normalizer for each restore entry")
	if restore_plan.size() == 2:
		var first := Dictionary(restore_plan[0])
		var second := Dictionary(restore_plan[1])
		var first_position := Dictionary(first.get("position", {}))
		var second_position := Dictionary(second.get("position", {}))
		TEST_UTILS.expect_equal(str(first.get("resource_kind", "")), "grass_patch", failures, "ResourceService should keep normalized resource_kind in the restore plan")
		TEST_UTILS.expect_close(float(first_position.get("x", 0.0)), 17.0, failures, "ResourceService should replace restore plan position X with normalized callback output")
		TEST_UTILS.expect_close(float(first_position.get("y", 0.0)), -11.0, failures, "ResourceService should replace restore plan position Y with normalized callback output")
		TEST_UTILS.expect_equal(str(second.get("resource_kind", "")), "bush", failures, "ResourceService should preserve resource kind for later restore entries")
		TEST_UTILS.expect_close(float(second_position.get("x", 0.0)), 45.0, failures, "ResourceService should normalize second restore position X through the callback")
		TEST_UTILS.expect_close(float(second_position.get("y", 0.0)), 12.0, failures, "ResourceService should normalize second restore position Y through the callback")


func _test_resource_service_applies_restore_data_to_valid_resource_nodes(failures: Array[String]) -> void:
	var service := RESOURCE_SERVICE.new()
	var resource := TestResourceNode.new()
	var restore_data := {
		"resource_kind": "grass_patch",
		"position": {"x": 12.0, "y": -8.0},
		"harvested": false
	}
	TEST_UTILS.expect(service.apply_restore_data(resource, restore_data), failures, "ResourceService should apply restore data to live resource nodes that support restore_from_data")
	TEST_UTILS.expect_equal(str(resource.restored_data.get("resource_kind", "")), "grass_patch", failures, "ResourceService should pass restore resource kind through to the node")
	var restored_position := Dictionary(resource.restored_data.get("position", {}))
	TEST_UTILS.expect_close(float(restored_position.get("x", 0.0)), 12.0, failures, "ResourceService should pass restore position X through to the node")
	TEST_UTILS.expect_close(float(restored_position.get("y", 0.0)), -8.0, failures, "ResourceService should pass restore position Y through to the node")
	resource.queue_free()


func _test_resource_service_applies_restore_plan_via_callbacks(failures: Array[String]) -> void:
	var service := RESOURCE_SERVICE.new()
	var spawned_kinds: Array[String] = []
	var restored_nodes: Array[TestResourceNode] = []
	var restored_count := service.apply_restore_plan(
		[
			{
				"resource_kind": "grass_patch",
				"position": {"x": 12.0, "y": -8.0},
				"harvested": false
			},
			{
				"resource_kind": "bush",
				"position": {"x": 40.0, "y": 15.0},
				"harvested": true
			}
		],
		func(resource_kind: String, position_data: Dictionary) -> Variant:
			spawned_kinds.append("%s:%s:%s" % [resource_kind, str(position_data.get("x", 0.0)), str(position_data.get("y", 0.0))])
			var resource := TestResourceNode.new()
			resource.resource_kind = resource_kind
			restored_nodes.append(resource)
			return resource,
		func(resource_node: Variant, restore_data: Dictionary) -> bool:
			return service.apply_restore_data(resource_node, restore_data)
	)
	TEST_UTILS.expect_equal(restored_count, 2, failures, "ResourceService should count restored resources when spawn and restore callbacks succeed")
	TEST_UTILS.expect_equal(spawned_kinds.size(), 2, failures, "ResourceService should invoke the spawn callback for each restore plan entry")
	if restored_nodes.size() == 2:
		var first_position := Dictionary(restored_nodes[0].restored_data.get("position", {}))
		var second_position := Dictionary(restored_nodes[1].restored_data.get("position", {}))
		TEST_UTILS.expect_equal(str(restored_nodes[0].restored_data.get("resource_kind", "")), "grass_patch", failures, "ResourceService should pass first restore kind through the restore plan pipeline")
		TEST_UTILS.expect_equal(str(restored_nodes[1].restored_data.get("resource_kind", "")), "bush", failures, "ResourceService should pass second restore kind through the restore plan pipeline")
		TEST_UTILS.expect_close(float(first_position.get("x", 0.0)), 12.0, failures, "ResourceService should preserve first restore position X through the restore plan pipeline")
		TEST_UTILS.expect_close(float(second_position.get("y", 0.0)), 15.0, failures, "ResourceService should preserve second restore position Y through the restore plan pipeline")
	for resource in restored_nodes:
		resource.queue_free()


func _test_resource_service_restores_resources_from_raw_data_end_to_end(failures: Array[String]) -> void:
	var service := RESOURCE_SERVICE.new()
	var restored_nodes: Array[TestResourceNode] = []
	var restored_count := service.restore_resources_from_data(
		[
			{
				"kind": "grass_patch",
				"position": {"x": 12.0, "y": -8.0},
				"harvested": false
			},
			{
				"resource_kind": "bush",
				"position": {"x": 40.0, "y": 15.0},
				"harvested": true
			}
		],
		func(_resource_kind: String, position_data: Dictionary) -> Dictionary:
			return {
				"x": float(position_data.get("x", 0.0)) + 2.0,
				"y": float(position_data.get("y", 0.0)) - 1.0
			},
		func(resource_kind: String, position_data: Dictionary) -> Variant:
			var resource := TestResourceNode.new()
			resource.resource_kind = resource_kind
			resource.save_data = {"spawn_position": Dictionary(position_data).duplicate(true)}
			restored_nodes.append(resource)
			return resource,
		func(resource_node: Variant, restore_data: Dictionary) -> bool:
			return service.apply_restore_data(resource_node, restore_data)
	)
	TEST_UTILS.expect_equal(restored_count, 2, failures, "ResourceService should restore all valid resources from raw restore data end to end")
	if restored_nodes.size() == 2:
		var first_position := Dictionary(restored_nodes[0].restored_data.get("position", {}))
		var second_position := Dictionary(restored_nodes[1].restored_data.get("position", {}))
		TEST_UTILS.expect_equal(str(restored_nodes[0].restored_data.get("resource_kind", "")), "grass_patch", failures, "ResourceService should normalize legacy kind and pass it through the end-to-end restore flow")
		TEST_UTILS.expect_equal(str(restored_nodes[1].restored_data.get("resource_kind", "")), "bush", failures, "ResourceService should preserve resource kind in the end-to-end restore flow")
		TEST_UTILS.expect_close(float(first_position.get("x", 0.0)), 14.0, failures, "ResourceService should use normalized position X in the end-to-end restore flow")
		TEST_UTILS.expect_close(float(first_position.get("y", 0.0)), -9.0, failures, "ResourceService should use normalized position Y in the end-to-end restore flow")
		TEST_UTILS.expect_close(float(second_position.get("x", 0.0)), 42.0, failures, "ResourceService should use normalized second position X in the end-to-end restore flow")
		TEST_UTILS.expect_close(float(second_position.get("y", 0.0)), 14.0, failures, "ResourceService should use normalized second position Y in the end-to-end restore flow")
	for resource in restored_nodes:
		resource.queue_free()


func _test_resource_service_counts_resources_by_kind(failures: Array[String]) -> void:
	var service := RESOURCE_SERVICE.new()
	var grass_a := TestResourceNode.new()
	grass_a.resource_kind = "grass_patch"
	var grass_b := TestResourceNode.new()
	grass_b.resource_kind = "grass_patch"
	var bush := TestResourceNode.new()
	bush.resource_kind = "bush"
	var counts := service.count_resources_by_kind([grass_a, grass_b, bush])
	TEST_UTILS.expect_equal(int(counts.get("grass_patch", 0)), 2, failures, "ResourceService should group resources by kind")
	TEST_UTILS.expect_equal(int(counts.get("bush", 0)), 1, failures, "ResourceService should count each different resource kind separately")
	grass_a.queue_free()
	grass_b.queue_free()
	bush.queue_free()
