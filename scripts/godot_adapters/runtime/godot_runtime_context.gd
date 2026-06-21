extends RefCounted
class_name GodotRuntimeContext

const DependencyRegistry := preload("res://scripts/core/runtime/dependency_registry.gd")

const KEY_WORLD := "world"
const KEY_PLAYER := "player"
const KEY_DAY_NIGHT_SYSTEM := "day_night_system"
const KEY_ECOSYSTEM_DIRECTOR := "ecosystem_director"
const KEY_EVOLUTION_DIRECTOR := "evolution_director"
const KEY_SAVE_SYSTEM := "save_system"
const KEY_EVENT_BUS := "event_bus"
const KEY_GAME_SESSION := "game_session"
const KEY_UI_ROOT := "ui_root"
const KEY_SNAPSHOT_SERVICE := "snapshot_service"

var registry := DependencyRegistry.new()


func set_service(key: String, service: Variant) -> void:
	registry.set_value(key, service)


func get_service(key: String, default_value: Variant = null) -> Variant:
	return registry.get_value(key, default_value)


func has_service(key: String) -> bool:
	return registry.has_value(key)


func clear() -> void:
	registry.clear()


func get_world() -> Node:
	return _get_node_service(KEY_WORLD)


func get_player() -> Node:
	return _get_node_service(KEY_PLAYER)


func get_day_night_system() -> Node:
	return _get_node_service(KEY_DAY_NIGHT_SYSTEM)


func get_ecosystem_director() -> Node:
	return _get_node_service(KEY_ECOSYSTEM_DIRECTOR)


func get_evolution_director() -> Node:
	return _get_node_service(KEY_EVOLUTION_DIRECTOR)


func get_save_system() -> Node:
	return _get_node_service(KEY_SAVE_SYSTEM)


func get_event_bus() -> Node:
	return _get_node_service(KEY_EVENT_BUS)


func get_game_session() -> Node:
	return _get_node_service(KEY_GAME_SESSION)


func get_ui_root() -> Node:
	return _get_node_service(KEY_UI_ROOT)


func get_snapshot_service() -> Variant:
	return get_service(KEY_SNAPSHOT_SERVICE, null)


func _get_node_service(key: String) -> Node:
	var value: Variant = get_service(key, null)
	if value == null:
		return null
	if not is_instance_valid(value):
		return null
	return value as Node
