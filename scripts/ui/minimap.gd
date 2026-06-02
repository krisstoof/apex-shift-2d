extends Control

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const PADDING := 10.0

var player: Node2D
var world_rect := WORLD_CONFIG.WORLD_RECT
var biome_zones: Array[Dictionary] = []


func bind(p_player: Node2D, p_world_rect: Rect2, p_biome_zones: Array[Dictionary]) -> void:
	player = p_player
	world_rect = p_world_rect
	biome_zones = p_biome_zones
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
	_draw_biomes(content_rect)
	_draw_grid(content_rect)
	_draw_resources(content_rect)
	_draw_varnaks(content_rect)
	_draw_player(content_rect)
	_draw_zone_label(map_rect)


func _draw_biomes(content_rect: Rect2) -> void:
	for biome in biome_zones:
		var map_points := PackedVector2Array()
		for point_value in biome["points"]:
			map_points.append(_world_to_map(Vector2(point_value), content_rect))
		draw_colored_polygon(map_points, Color(biome["color"]).lerp(Color.BLACK, 0.15))
		_draw_biome_outline(map_points)


func _draw_biome_outline(points: PackedVector2Array) -> void:
	for i in points.size():
		draw_line(points[i], points[(i + 1) % points.size()], Color(0.03, 0.04, 0.03, 0.55), 1.0)


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


func _draw_zone_label(map_rect: Rect2) -> void:
	var label_rect := Rect2(0.0, map_rect.size.y - 24.0, map_rect.size.x, 24.0)
	draw_rect(label_rect, Color(0.03, 0.04, 0.04, 0.88), true)
	draw_line(label_rect.position, label_rect.position + Vector2(label_rect.size.x, 0.0), Color(0.74, 0.78, 0.68, 0.55), 1.0)
	draw_string(get_theme_default_font(), label_rect.position + Vector2(8.0, 17.0), "Zone: %s" % _get_player_zone_name(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.90, 0.92, 0.84))


func _get_player_zone_name() -> String:
	if not is_instance_valid(player):
		return "Unknown"
	for biome in biome_zones:
		if Geometry2D.is_point_in_polygon(player.global_position, PackedVector2Array(biome["points"])):
			return str(biome.get("name", "Unknown"))
	return "Wilderness"


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
		"grass":
			return Color(0.36, 0.78, 0.24)
		"berries":
			return Color(0.88, 0.18, 0.24)
		"meat":
			return Color(0.88, 0.20, 0.16)
		_:
			return Color(0.86, 0.78, 0.45)
