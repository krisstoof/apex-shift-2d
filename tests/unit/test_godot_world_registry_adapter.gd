extends RefCounted

const WORLD_REGISTRY := preload("res://scripts/world/world_registry.gd")
const GODOT_WORLD_REGISTRY_ADAPTER := preload("res://scripts/godot_runtime/world/godot_world_registry_adapter.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_world_registry_shim_is_adapter(failures)
	_test_adapter_registers_resource_node_and_returns_node(failures)
	_test_adapter_updates_node_position_through_core_spatial_index(failures)
	_test_adapter_unregisters_node(failures)
	_test_adapter_maps_buildings_to_core_registry(failures)
	_test_world_to_registry_to_spatial_index_flow(failures)
	_test_spatial_debug_data_preserves_flat_shape(failures)
	_test_duplicate_registration_does_not_increment_versions(failures)
	return failures


func _test_world_registry_shim_is_adapter(failures: Array[String]) -> void:
	var registry := WORLD_REGISTRY.new()
	TEST_UTILS.expect(registry is RefCounted, failures, "WorldRegistry shim should remain RefCounted")
	TEST_UTILS.expect(registry.has_method("register_resource"), failures, "WorldRegistry shim should preserve register_resource")
	TEST_UTILS.expect(registry.has_method("get_resources_near"), failures, "WorldRegistry shim should preserve get_resources_near")
	TEST_UTILS.expect(registry.has_method("get_spatial_index_debug_data"), failures, "WorldRegistry shim should preserve spatial debug API")


func _test_adapter_registers_resource_node_and_returns_node(failures: Array[String]) -> void:
	var registry := WORLD_REGISTRY.new()
	var resource := _make_resource_node(Vector2(100.0, 100.0), "berry_bush")
	registry.register_resource(resource)
	var resources := registry.get_resources()
	var nearby := registry.get_resources_near(Vector2(100.0, 100.0), 64.0, "berry_bush")
	TEST_UTILS.expect(resources.has(resource), failures, "Adapter should return registered resource node")
	TEST_UTILS.expect(nearby.has(resource), failures, "Adapter should return resource node through spatial query")


func _test_adapter_updates_node_position_through_core_spatial_index(failures: Array[String]) -> void:
	var registry := WORLD_REGISTRY.new()
	var resource := _make_resource_node(Vector2(10.0, 10.0), "berry_bush")
	registry.register_resource(resource)
	resource.global_position = Vector2(600.0, 10.0)
	registry.update_entity_cell(resource)
	var old_query := registry.get_resources_near(Vector2(10.0, 10.0), 64.0, "berry_bush")
	var new_query := registry.get_resources_near(Vector2(600.0, 10.0), 64.0, "berry_bush")
	TEST_UTILS.expect_equal(old_query.has(resource), false, failures, "Adapter should remove resource from old spatial area")
	TEST_UTILS.expect(new_query.has(resource), failures, "Adapter should return resource in new spatial area")


func _test_adapter_unregisters_node(failures: Array[String]) -> void:
	var registry := WORLD_REGISTRY.new()
	var resource := _make_resource_node(Vector2(100.0, 100.0), "berry_bush")
	registry.register_resource(resource)
	registry.unregister_resource(resource)
	var nearby := registry.get_resources_near(Vector2(100.0, 100.0), 64.0, "berry_bush")
	TEST_UTILS.expect_equal(nearby.has(resource), false, failures, "Adapter should remove unregistered resource from spatial query")


func _test_adapter_maps_buildings_to_core_registry(failures: Array[String]) -> void:
	var registry := WORLD_REGISTRY.new()
	var campfire := _make_node(Vector2(200.0, 200.0))
	registry.register_building(campfire, "campfire")
	var buildings := registry.get_buildings()
	var nearby := registry.get_buildings_near(Vector2(200.0, 200.0), 64.0, "campfire")
	TEST_UTILS.expect(buildings.has(campfire), failures, "Adapter should return registered building")
	TEST_UTILS.expect(nearby.has(campfire), failures, "Adapter should query buildings through core registry and spatial index")


func _test_world_to_registry_to_spatial_index_flow(failures: Array[String]) -> void:
	var registry := WORLD_REGISTRY.new()
	var prey := _make_node(Vector2(300.0, 300.0))
	registry.register_creature(prey, "small_prey")
	var debug := registry.get_spatial_index_debug_data()
	var nearby := registry.get_creatures_near(Vector2(300.0, 300.0), 64.0, "small_prey")
	TEST_UTILS.expect(nearby.has(prey), failures, "World -> Registry -> SpatialIndex flow should return registered creature node")
	TEST_UTILS.expect(int(Dictionary(debug.get("spatial_index", debug)).get("tracked_entities", 0)) >= 1 or int(debug.get("tracked_entities", 0)) >= 1, failures, "Spatial index should track registered entity through registry")


func _test_spatial_debug_data_preserves_flat_shape(failures: Array[String]) -> void:
	var registry := WORLD_REGISTRY.new()
	var resource := _make_resource_node(Vector2(100.0, 100.0), "berry_bush")
	var prey := _make_node(Vector2(120.0, 100.0))
	registry.register_resource(resource)
	registry.register_creature(prey, "small_prey")
	var debug := registry.get_spatial_index_debug_data()
	TEST_UTILS.expect(debug.has("tracked_entities"), failures, "Spatial debug data should preserve flat tracked_entities key")
	TEST_UTILS.expect(debug.has("resource_cells"), failures, "Spatial debug data should preserve flat resource_cells key")
	TEST_UTILS.expect(debug.has("creature_cells"), failures, "Spatial debug data should preserve flat creature_cells key")
	TEST_UTILS.expect(debug.has("resources_total"), failures, "Spatial debug data should preserve flat resources_total key")
	TEST_UTILS.expect(debug.has("creatures_total"), failures, "Spatial debug data should preserve flat creatures_total key")
	TEST_UTILS.expect(debug.has("registry_tracked_entities"), failures, "Spatial debug data should include registry-prefixed diagnostics")
	TEST_UTILS.expect(int(debug.get("tracked_entities", 0)) >= 2, failures, "Spatial debug should count registered entities")


func _test_duplicate_registration_does_not_increment_versions(failures: Array[String]) -> void:
	var registry := WORLD_REGISTRY.new()
	var resource := _make_resource_node(Vector2(100.0, 100.0), "berry_bush")
	registry.register_resource(resource)
	var resource_version_after_first_register := registry.resource_version
	registry.register_resource(resource)
	var resource_version_after_duplicate_register := registry.resource_version
	var resources := registry.get_resources()
	var nearby := registry.get_resources_near(Vector2(100.0, 100.0), 64.0, "berry_bush")
	TEST_UTILS.expect_equal(resource_version_after_duplicate_register, resource_version_after_first_register, failures, "Duplicate resource registration should not increment resource_version")
	TEST_UTILS.expect_equal(resources.size(), 1, failures, "Duplicate resource registration should not duplicate registered resources")
	TEST_UTILS.expect_equal(nearby.size(), 1, failures, "Duplicate resource registration should not duplicate spatial query results")
	TEST_UTILS.expect(nearby.has(resource), failures, "Registered resource should still be returned after duplicate registration")


func _make_node(position: Vector2) -> Node2D:
	var node := Node2D.new()
	node.global_position = position
	return node


class MockResourceNode:
	extends Node2D

	var resource_kind := ""


func _make_resource_node(position: Vector2, resource_kind: String) -> Node2D:
	var node := MockResourceNode.new()
	node.global_position = position
	node.resource_kind = resource_kind
	return node
