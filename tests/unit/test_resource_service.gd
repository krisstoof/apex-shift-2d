extends RefCounted

const RESOURCE_SERVICE := preload("res://scripts/world/resource_service.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


class TestResourceNode:
	extends Node2D

	var resource_kind := "grass_patch"
	var should_change := false
	var growth_calls: Array[float] = []

	func advance_growth_days(days: float) -> bool:
		growth_calls.append(days)
		return should_change


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_resource_service_counts_only_changed_growth_updates(failures)
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
