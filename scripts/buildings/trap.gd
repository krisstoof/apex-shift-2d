extends Area2D

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const BUILDING_STATE := preload("res://scripts/core/buildings/building_state.gd")


func _post_event_message(message: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var event_bus := tree.root.get_node_or_null("EventBus")
	if event_bus and event_bus.has_method("post_message"):
		event_bus.post_message(message)

@export var damage := GAME_BALANCE.TRAP_DAMAGE
var armed := true
var building_state := BUILDING_STATE.new()

func _ready() -> void:
	add_to_group("traps")
	_sync_state_from_node()
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if not armed:
		return
	if body.is_in_group("varnak") and body.has_method("take_damage"):
		armed = false
		body.take_damage(damage, "trap")
		_post_event_message("Trap triggered")
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(-16, -16, 32, 32), Color(0.48, 0.28, 0.1), false, 3.0)
	draw_line(Vector2(-15, -15), Vector2(15, 15), Color(0.88, 0.78, 0.45), 2.0)
	draw_line(Vector2(15, -15), Vector2(-15, 15), Color(0.88, 0.78, 0.45), 2.0)


func get_building_state() -> Dictionary:
	_sync_state_from_node()
	return building_state.to_save_data()


func apply_building_state(data: Dictionary) -> void:
	building_state.load_from_save_data(data)
	_sync_node_from_state()


func _sync_state_from_node() -> void:
	building_state.kind = "trap"
	building_state.position = global_position
	building_state.armed = armed
	building_state.damage = damage


func _sync_node_from_state() -> void:
	armed = building_state.armed
	damage = building_state.damage
