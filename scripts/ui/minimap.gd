extends Control

const PADDING := 10.0

var player: Node2D
var world_rect := Rect2(-1440, -880, 2880, 1760)


func bind(p_player: Node2D, p_world_rect: Rect2) -> void:
	player = p_player
	world_rect = p_world_rect
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var map_rect := Rect2(Vector2.ZERO, size)
	var content_rect := map_rect.grow(-PADDING)

	draw_rect(map_rect, Color(0.04, 0.05, 0.05, 0.86), true)
	draw_rect(map_rect, Color(0.74, 0.78, 0.68, 0.9), false, 1.0)
	draw_rect(content_rect, Color(0.11, 0.18, 0.11, 0.94), true)
	draw_rect(content_rect, Color(0.35, 0.43, 0.32, 0.8), false, 1.0)
	_draw_grid(content_rect)
	_draw_resources(content_rect)
	_draw_varnaks(content_rect)
	_draw_player(content_rect)


func _draw_grid(content_rect: Rect2) -> void:
	var grid_color := Color(0.23, 0.31, 0.22, 0.55)
	for i in range(1, 4):
		var x := content_rect.position.x + content_rect.size.x * float(i) / 4.0
		var y := content_rect.position.y + content_rect.size.y * float(i) / 4.0
		draw_line(Vector2(x, content_rect.position.y), Vector2(x, content_rect.end.y), grid_color, 1.0)
		draw_line(Vector2(content_rect.position.x, y), Vector2(content_rect.end.x, y), grid_color, 1.0)


func _draw_resources(content_rect: Rect2) -> void:
	for resource in get_tree().get_nodes_in_group("resources"):
		if not is_instance_valid(resource):
			continue
		var color := _get_resource_color(resource)
		draw_circle(_world_to_map(resource.global_position, content_rect), 2.2, color)


func _draw_varnaks(content_rect: Rect2) -> void:
	for varnak in get_tree().get_nodes_in_group("varnak"):
		if not is_instance_valid(varnak):
			continue
		var pos := _world_to_map(varnak.global_position, content_rect)
		draw_circle(pos, 3.3, Color(0.88, 0.22, 0.16))
		draw_circle(pos, 1.4, Color(1.0, 0.82, 0.42))


func _draw_player(content_rect: Rect2) -> void:
	if not is_instance_valid(player):
		return
	var pos := _world_to_map(player.global_position, content_rect)
	draw_circle(pos, 4.2, Color(0.17, 0.48, 1.0))
	draw_circle(pos, 2.0, Color.WHITE)


func _world_to_map(world_position: Vector2, content_rect: Rect2) -> Vector2:
	var normalized := Vector2(
		inverse_lerp(world_rect.position.x, world_rect.end.x, world_position.x),
		inverse_lerp(world_rect.position.y, world_rect.end.y, world_position.y)
	)
	normalized.x = clamp(normalized.x, 0.0, 1.0)
	normalized.y = clamp(normalized.y, 0.0, 1.0)
	return content_rect.position + normalized * content_rect.size


func _get_resource_color(resource: Node) -> Color:
	match str(resource.get("item_name")):
		"wood":
			return Color(0.18, 0.72, 0.24)
		"stone":
			return Color(0.62, 0.63, 0.68)
		"fiber":
			return Color(0.67, 0.95, 0.34)
		_:
			return Color(0.86, 0.78, 0.45)
