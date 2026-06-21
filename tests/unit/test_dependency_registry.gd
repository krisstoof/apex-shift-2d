extends RefCounted

const DependencyRegistry := preload("res://scripts/core/runtime/dependency_registry.gd")


func run() -> Dictionary:
	var failures: Array[String] = []
	_test_set_and_get_value(failures)
	_test_has_value(failures)
	_test_remove_value(failures)
	_test_clear(failures)
	return {"passed": failures.is_empty(), "failures": failures}


func _test_set_and_get_value(failures: Array[String]) -> void:
	var registry := DependencyRegistry.new()
	registry.set_value("world_seed", 123)
	var value := int(registry.get_value("world_seed", 0))
	if value != 123:
		failures.append("Expected world_seed 123")


func _test_has_value(failures: Array[String]) -> void:
	var registry := DependencyRegistry.new()
	registry.set_value("x", "value")
	if not registry.has_value("x"):
		failures.append("Expected registry to have key x")
	if registry.has_value("missing"):
		failures.append("Expected registry not to have missing key")


func _test_remove_value(failures: Array[String]) -> void:
	var registry := DependencyRegistry.new()
	registry.set_value("x", 1)
	registry.remove_value("x")
	if registry.has_value("x"):
		failures.append("Expected key x to be removed")


func _test_clear(failures: Array[String]) -> void:
	var registry := DependencyRegistry.new()
	registry.set_value("a", 1)
	registry.set_value("b", 2)
	registry.clear()
	if registry.has_value("a") or registry.has_value("b"):
		failures.append("Expected registry to be empty after clear")
