extends RefCounted

const DependencyRegistry := preload("res://scripts/core/runtime/dependency_registry.gd")
const GodotRuntimeContext := preload("res://scripts/godot_runtime/runtime/godot_runtime_context.gd")
const GodotRuntimeContextShim := preload("res://scripts/godot_adapters/runtime/godot_runtime_context.gd")
const GodotRuntimeContextBuilder := preload("res://scripts/godot_runtime/runtime/godot_runtime_context_builder.gd")
const RuntimeBootstrapper := preload("res://scripts/systems/runtime_bootstrapper.gd")
const WorldConfig := preload("res://scripts/world/world_config.gd")


func run() -> Dictionary:
	var failures: Array[String] = []

	_test_dependency_registry(failures)
	_test_runtime_context_from_source_path(failures)
	_test_runtime_context_from_compatibility_shim(failures)
	_test_runtime_context_builder_preloads(failures)
	_test_runtime_bootstrapper_preloads(failures)
	_test_world_config_runtime_flag(failures)

	return {
		"passed": failures.is_empty(),
		"failures": failures
	}


func _test_dependency_registry(failures: Array[String]) -> void:
	var registry := DependencyRegistry.new()
	registry.set_value("x", 123)
	if int(registry.get_value("x", 0)) != 123:
		failures.append("DependencyRegistry did not return stored value")
	if not registry.has_value("x"):
		failures.append("DependencyRegistry expected to have key x")
	registry.remove_value("x")
	if registry.has_value("x"):
		failures.append("DependencyRegistry expected key x to be removed")


func _test_runtime_context_from_source_path(failures: Array[String]) -> void:
	var context := GodotRuntimeContext.new()
	if context == null:
		failures.append("GodotRuntimeContext source path did not instantiate")
		return
	if not context.has_method("set_service"):
		failures.append("GodotRuntimeContext missing set_service")
	if not context.has_method("get_service"):
		failures.append("GodotRuntimeContext missing get_service")
	if not context.has_method("get_debug_status"):
		failures.append("GodotRuntimeContext missing get_debug_status")
	context.set_service(GodotRuntimeContext.KEY_GAME_SESSION, "test-session")
	if str(context.get_service(GodotRuntimeContext.KEY_GAME_SESSION, "")) != "test-session":
		failures.append("GodotRuntimeContext did not return stored service")


func _test_runtime_context_from_compatibility_shim(failures: Array[String]) -> void:
	var context := GodotRuntimeContextShim.new()
	if context == null:
		failures.append("GodotRuntimeContext compatibility shim did not instantiate")
		return
	if not context.has_method("get_debug_status"):
		failures.append("Compatibility shim does not expose get_debug_status")


func _test_runtime_context_builder_preloads(failures: Array[String]) -> void:
	var builder := GodotRuntimeContextBuilder.new()
	if builder == null:
		failures.append("GodotRuntimeContextBuilder did not instantiate")
		return
	if not builder.has_method("build_from_scene_tree"):
		failures.append("GodotRuntimeContextBuilder missing build_from_scene_tree")
	if not builder.has_method("inject_into_known_services"):
		failures.append("GodotRuntimeContextBuilder missing inject_into_known_services")


func _test_runtime_bootstrapper_preloads(failures: Array[String]) -> void:
	var bootstrapper := RuntimeBootstrapper.new()
	if bootstrapper == null:
		failures.append("RuntimeBootstrapper did not instantiate")
		return
	if not bootstrapper.has_method("get_runtime_context"):
		failures.append("RuntimeBootstrapper missing get_runtime_context")


func _test_world_config_runtime_flag(failures: Array[String]) -> void:
	var enabled := bool(WorldConfig.use_runtime_context())
	if enabled != bool(WorldConfig.USE_RUNTIME_CONTEXT):
		failures.append("WorldConfig.use_runtime_context() does not match USE_RUNTIME_CONTEXT")
