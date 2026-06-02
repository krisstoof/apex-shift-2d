extends Control

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const PADDING := 10.0
const BIOME_BLEND_TEXTURE_SIZE := Vector2i(96, 58)
const BIOME_BLEND_RADIUS := 420.0
const BIOME_NEIGHBOR_BLEND_WEIGHT := 0.90

var player: Node2D
var world_rect := WORLD_CONFIG.WORLD_RECT
var biome_zones: Array[Dictionary] = []
var biome_blend_texture: ImageTexture
var biome_blend_colors_key := ""


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


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
	if biome_zones.is_empty():
		return
	_ensure_biome_blend_texture()
	if biome_blend_texture:
		draw_texture_rect(biome_blend_texture, content_rect, false)


func _ensure_biome_blend_texture() -> void:
	if biome_zones.is_empty():
		return
	var current_key := _get_biome_colors_key()
	if biome_blend_texture and biome_blend_colors_key == current_key:
		return
	var image := Image.create(BIOME_BLEND_TEXTURE_SIZE.x, BIOME_BLEND_TEXTURE_SIZE.y, false, Image.FORMAT_RGBA8)
	var colors: Array[Color] = []
	for biome in biome_zones:
		colors.append(Color(biome["color"]).lerp(Color.BLACK, 0.15))
	for y in range(BIOME_BLEND_TEXTURE_SIZE.y):
		for x in range(BIOME_BLEND_TEXTURE_SIZE.x):
			var uv := Vector2(
				(float(x) + 0.5) / float(BIOME_BLEND_TEXTURE_SIZE.x),
				(float(y) + 0.5) / float(BIOME_BLEND_TEXTURE_SIZE.y)
			)
			var world_position := world_rect.position + uv * world_rect.size
			image.set_pixel(x, y, _get_blended_biome_color_at(world_position, biome_zones, colors, BIOME_BLEND_RADIUS))
	biome_blend_texture = ImageTexture.create_from_image(image)
	biome_blend_colors_key = current_key


func _get_blended_biome_color_at(position: Vector2, zones: Array[Dictionary], colors: Array[Color], blend_radius: float) -> Color:
	var containing_index := -1
	var containing_edge_distance := INF
	var edge_distances: Array[float] = []
	for i in zones.size():
		var points := PackedVector2Array(zones[i]["points"])
		var edge_distance := _get_point_polygon_edge_distance(position, points)
		edge_distances.append(edge_distance)
		if containing_index == -1 and Geometry2D.is_point_in_polygon(position, points):
			containing_index = i
			containing_edge_distance = edge_distance
	if containing_index == -1:
		return _get_nearest_biome_color(edge_distances, colors)
	var result := colors[containing_index]
	var total_weight := 1.0
	if containing_edge_distance >= blend_radius:
		return result
	for i in zones.size():
		if i == containing_index:
			continue
		var shared_edge_distance: float = max(containing_edge_distance, edge_distances[i])
		if shared_edge_distance > blend_radius:
			continue
		var neighbor_weight: float = pow(1.0 - shared_edge_distance / blend_radius, 2.0) * BIOME_NEIGHBOR_BLEND_WEIGHT
		result += colors[i] * neighbor_weight
		total_weight += neighbor_weight
	return result / total_weight


func _get_nearest_biome_color(edge_distances: Array[float], colors: Array[Color]) -> Color:
	var nearest_index := 0
	var nearest_distance := INF
	for i in edge_distances.size():
		if edge_distances[i] < nearest_distance:
			nearest_index = i
			nearest_distance = edge_distances[i]
	return colors[nearest_index]


func _get_point_polygon_edge_distance(point: Vector2, points: PackedVector2Array) -> float:
	var nearest_distance := INF
	for i in points.size():
		nearest_distance = min(nearest_distance, _get_distance_to_segment(point, points[i], points[(i + 1) % points.size()]))
	return nearest_distance


func _get_distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var t: float = clamp((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)


func _get_biome_colors_key() -> String:
	var parts: Array[String] = []
	for biome in biome_zones:
		var color := Color(biome["color"])
		parts.append("%.3f:%.3f:%.3f" % [color.r, color.g, color.b])
	return "|".join(parts)


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
