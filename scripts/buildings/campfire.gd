extends Area2D

@export var fear_radius := 150.0
@export var light_radius := 165.0

var active := true
var day_night_system: Node

func _ready() -> void:
	add_to_group("campfires")
	var scene := get_tree().current_scene
	if scene:
		day_night_system = scene.get_node_or_null("DayNightSystem")
	queue_redraw()


func _process(_delta: float) -> void:
	if active:
		queue_redraw()


func _draw() -> void:
	if active:
		_draw_fire_light()
	draw_circle(Vector2.ZERO, 18.0, Color(0.28, 0.12, 0.05))
	draw_line(Vector2(-17, 8), Vector2(16, -8), Color(0.22, 0.11, 0.04), 6.0)
	draw_line(Vector2(-15, -7), Vector2(17, 7), Color(0.30, 0.15, 0.05), 6.0)
	if active:
		draw_circle(Vector2.ZERO, 11.0, Color(1.0, 0.42, 0.08))
		draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.9, 0.25))
		draw_arc(Vector2.ZERO, fear_radius, 0.0, TAU, 48, Color(1.0, 0.55, 0.1, 0.18), 2.0)
	else:
		draw_circle(Vector2.ZERO, 9.0, Color(0.08, 0.07, 0.06))


func _draw_fire_light() -> void:
	var night_amount := _get_night_amount()
	var flicker := 0.92 + sin(Time.get_ticks_msec() * 0.014 + global_position.x * 0.021) * 0.08
	var strength := (0.22 + night_amount * 0.62) * flicker
	draw_circle(Vector2.ZERO, light_radius, Color(1.0, 0.46, 0.06, strength * 0.08))
	draw_circle(Vector2.ZERO, light_radius * 0.62, Color(1.0, 0.58, 0.10, strength * 0.13))
	draw_circle(Vector2.ZERO, light_radius * 0.34, Color(1.0, 0.78, 0.22, strength * 0.18))


func _get_night_amount() -> float:
	if day_night_system:
		return float(day_night_system.night_amount)
	return 0.0
