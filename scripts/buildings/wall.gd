extends StaticBody2D

const BUILDING_STATE := preload("res://scripts/core/buildings/building_state.gd")


func _emit_game_event(event_name: String, payload: Dictionary = {}) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var event_bus := tree.root.get_node_or_null("EventBus")
	if event_bus and event_bus.has_method("emit_game_event"):
		event_bus.emit_game_event(event_name, payload)

@export var health := 80.0
var building_state := BUILDING_STATE.new()

func _ready() -> void:
	add_to_group("walls")
	_sync_state_from_node()
	queue_redraw()


func take_damage(amount: float) -> void:
	health -= amount
	_emit_game_event("varnak_attacked_wall", {"position": global_position, "damage": amount})
	if health <= 0.0:
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(-24, -18, 48, 36), Color(0.45, 0.32, 0.18), true)
	draw_rect(Rect2(-24, -18, 48, 36), Color(0.20, 0.13, 0.08), false, 2.0)


func get_building_state() -> Dictionary:
	_sync_state_from_node()
	return building_state.to_save_data()


func apply_building_state(data: Dictionary) -> void:
	building_state.load_from_save_data(data)
	_sync_node_from_state()


func _sync_state_from_node() -> void:
	building_state.kind = "wall"
	building_state.position = global_position
	building_state.health = health


func _sync_node_from_state() -> void:
	health = building_state.health
