extends Area2D

@export var fear_radius := 150.0
var active := true

func _ready() -> void:
	add_to_group("campfires")
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 18.0, Color(0.28, 0.12, 0.05))
	draw_circle(Vector2.ZERO, 11.0, Color(1.0, 0.42, 0.08))
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.9, 0.25))
	draw_arc(Vector2.ZERO, fear_radius, 0.0, TAU, 48, Color(1.0, 0.55, 0.1, 0.18), 2.0)
