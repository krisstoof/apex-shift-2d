extends Area2D

func _ready() -> void:
	add_to_group("tents")
	queue_redraw()


func interact(player: Node) -> void:
	var day_night_system := get_tree().current_scene.get_node_or_null("DayNightSystem")
	if not day_night_system or not day_night_system.has_method("sleep_until_morning"):
		get_node("/root/EventBus").post_message("No safe place to sleep")
		return
	if day_night_system.sleep_until_morning() and player and player.has_method("recover_from_sleep"):
		player.recover_from_sleep()
		get_node("/root/EventBus").post_message("Rested and recovered")


func get_prompt() -> String:
	return "E: sleep in tent"


func _draw() -> void:
	draw_polygon([Vector2(-26, 18), Vector2(0, -24), Vector2(26, 18)], [Color(0.18, 0.42, 0.38)])
	draw_line(Vector2(0, -24), Vector2(0, 18), Color(0.85, 0.78, 0.58), 2.0)
	draw_rect(Rect2(-30, 16, 60, 6), Color(0.12, 0.18, 0.14), true)
	draw_line(Vector2(-26, 18), Vector2(0, -24), Color(0.85, 0.78, 0.58), 2.0)
	draw_line(Vector2(26, 18), Vector2(0, -24), Color(0.85, 0.78, 0.58), 2.0)
