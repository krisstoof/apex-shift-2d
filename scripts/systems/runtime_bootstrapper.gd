extends Node
class_name RuntimeBootstrapper

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const GodotRuntimeContextBuilder := preload("res://scripts/godot_runtime/runtime/godot_runtime_context_builder.gd")

var runtime_context
var builder := GodotRuntimeContextBuilder.new()


func _ready() -> void:
	if not WORLD_CONFIG.use_runtime_context():
		print("[RuntimeBootstrapper] Disabled by WorldConfig")
		return
	await get_tree().process_frame
	runtime_context = builder.build_from_scene_tree(get_tree())
	builder.inject_into_known_services(runtime_context)
	_bind_snapshot_service()
	_print_runtime_context_status()
	print("[RuntimeBootstrapper] Runtime context initialized")


func get_runtime_context() -> Variant:
	return runtime_context


func _bind_snapshot_service() -> void:
	if runtime_context == null:
		return
	var snapshot_service: Variant = runtime_context.get_snapshot_service()
	if snapshot_service != null and snapshot_service.has_method("bind_runtime_context"):
		snapshot_service.bind_runtime_context(runtime_context)


func _print_runtime_context_status() -> void:
	if runtime_context == null:
		push_warning("[RuntimeBootstrapper] Runtime context is null")
		return
	var status: Dictionary = runtime_context.get_debug_status()
	var parts: Array[String] = []
	for key in status.keys():
		parts.append("%s=%s" % [str(key), "ok" if bool(status[key]) else "missing"])
	print("[RuntimeBootstrapper] %s" % " ".join(parts))
