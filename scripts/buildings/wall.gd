extends StaticBody2D

@export var health := 80.0

func _ready() -> void:
	add_to_group("walls")
	queue_redraw()


func take_damage(amount: float) -> void:
	health -= amount
	get_node("/root/EventBus").emit_game_event("varnak_attacked_wall", {"position": global_position, "damage": amount})
	if health <= 0.0:
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(-24, -18, 48, 36), Color(0.45, 0.32, 0.18), true)
	draw_rect(Rect2(-24, -18, 48, 36), Color(0.20, 0.13, 0.08), false, 2.0)
