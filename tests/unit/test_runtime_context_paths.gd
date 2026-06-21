extends RefCounted

const GodotRuntimeContext := preload("res://scripts/godot_runtime/runtime/godot_runtime_context.gd")


func run() -> Dictionary:
	var failures: Array[String] = []

	var context := GodotRuntimeContext.new()
	if context == null:
		failures.append("Expected GodotRuntimeContext to instantiate from godot_runtime path")
	if not context.has_method("set_service"):
		failures.append("Expected GodotRuntimeContext to have set_service")
	if not context.has_method("get_service"):
		failures.append("Expected GodotRuntimeContext to have get_service")
	if not context.has_method("get_debug_status"):
		failures.append("Expected GodotRuntimeContext to have get_debug_status")

	return {
		"passed": failures.is_empty(),
		"failures": failures
	}
