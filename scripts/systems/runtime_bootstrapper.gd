extends Node
class_name RuntimeBootstrapper

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const GodotRuntimeContextBuilder := preload("res://scripts/godot_adapters/runtime/godot_runtime_context_builder.gd")

var runtime_context
var builder := GodotRuntimeContextBuilder.new()


func _ready() -> void:
	if not WORLD_CONFIG.use_runtime_context():
		return
	await get_tree().process_frame
	runtime_context = builder.build_from_scene_tree(get_tree())
	builder.inject_into_known_services(runtime_context)
	_bind_snapshot_service()
	print("[RuntimeBootstrapper] Runtime context initialized")


func get_runtime_context() -> Variant:
	return runtime_context


func _bind_snapshot_service() -> void:
	if runtime_context == null:
		return
	var snapshot_service: Variant = runtime_context.get_snapshot_service()
	if snapshot_service != null and snapshot_service.has_method("bind_runtime_context"):
		snapshot_service.bind_runtime_context(runtime_context)
