extends StaticBody2D


func _emit_game_event(event_name: String, payload: Dictionary = {}) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var event_bus := tree.root.get_node_or_null("EventBus")
	if event_bus and event_bus.has_method("emit_game_event"):
		event_bus.emit_game_event(event_name, payload)

@export var health := 80.0

func _ready() -> void:
	add_to_group("walls")
	queue_redraw()


func take_damage(amount: float) -> void:
	health -= amount
	_emit_game_event("varnak_attacked_wall", {"position": global_position, "damage": amount})
	if health <= 0.0:
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(-24, -18, 48, 36), Color(0.45, 0.32, 0.18), true)
	draw_rect(Rect2(-24, -18, 48, 36), Color(0.20, 0.13, 0.08), false, 2.0)
