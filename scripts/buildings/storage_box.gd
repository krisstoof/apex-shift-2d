extends StaticBody2D

func _ready() -> void:
	add_to_group("storage_boxes")
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-18, -14, 36, 28), Color(0.5, 0.28, 0.12), true)
	draw_rect(Rect2(-18, -14, 36, 28), Color(0.18, 0.1, 0.05), false, 2.0)
	draw_line(Vector2(-18, -2), Vector2(18, -2), Color(0.18, 0.1, 0.05), 2.0)
