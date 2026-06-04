extends Control

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const PADDING := 14.0
const BIOME_BLEND_TEXTURE_SIZE := Vector2i(192, 116)
const POND_MARKER_Y_SCALE := 0.62
const HILL_MARKER_Y_SCALE := 0.58
const MINIMAP_REDRAW_INTERVAL := 0.20
const MINIMAP_VIEW_MARGIN_FACTOR := 1.22
const MINIMAP_FALLBACK_VIEW_WORLD_SIZE := Vector2(1280.0, 760.0)

var player: Node2D
var world_rect := WORLD_CONFIG.WORLD_RECT
var biome_zones: Array[Dictionary] = []
var landmarks: Array[Dictionary] = []
var biome_blend_texture: ImageTexture
var biome_blend_colors_key := ""
var minimap_redraw_timer := 0.0
var cached_resources: Array[Node] = []
var resources_cache_timer := 0.0
var camera_world_size_override := Vector2.ZERO
const RESOURCES_CACHE_INTERVAL := 0.5


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_update_resources_cache()


func bind(p_player: Node2D, p_world_rect: Rect2, p_biome_zones: Array[Dictionary], p_landmarks: Array[Dictionary] = []) -> void:
	player = p_player
	world_rect = p_world_rect
	biome_zones = p_biome_zones
	landmarks = p_landmarks
	_update_resources_cache()
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	minimap_redraw_timer += delta
	if minimap_redraw_timer >= MINIMAP_REDRAW_INTERVAL:
		minimap_redraw_timer = 0.0
		queue_redraw()
	resources_cache_timer += delta
	if resources_cache_timer >= RESOURCES_CACHE_INTERVAL:
		resources_cache_timer = 0.0
		_update_resources_cache()


func _draw() -> void:
	_refresh_landmarks_from_world()
	var map_rect := Rect2(Vector2.ZERO, size)
	var content_rect := map_rect.grow(-PADDING)
	var view_world_rect := _get_minimap_view_world_rect(content_rect)

	draw_rect(map_rect, Color(0.04, 0.05, 0.05, 0.86), true)
	draw_rect(map_rect, Color(0.74, 0.78, 0.68, 0.9), false, 1.0)
	draw_rect(content_rect, Color(0.11, 0.18, 0.11, 0.94), true)
	draw_rect(content_rect, Color(0.35, 0.43, 0.32, 0.8), false, 1.0)
	_draw_biomes(content_rect, view_world_rect)
	_draw_landmarks(content_rect, view_world_rect)
	_draw_grid(content_rect, view_world_rect)
	_draw_resources(content_rect, view_world_rect)
	_draw_varnaks(content_rect, view_world_rect)
	_draw_player(content_rect, view_world_rect)
	_draw_zone_label(map_rect)


func _draw_biomes(content_rect: Rect2, view_world_rect: Rect2) -> void:
	if biome_zones.is_empty():
		return
	_ensure_biome_texture()
	if not biome_blend_texture:
		return
	var visible_world_rect := world_rect.intersection(view_world_rect)
	if visible_world_rect.size.x <= 0.0 or visible_world_rect.size.y <= 0.0:
		return
	var destination_rect := _world_rect_to_map_rect(visible_world_rect, content_rect, view_world_rect)
	var source_rect := _world_rect_to_texture_region(visible_world_rect)
	if destination_rect.size.x <= 0.0 or destination_rect.size.y <= 0.0:
		return
	draw_texture_rect_region(biome_blend_texture, destination_rect, source_rect)


func _ensure_biome_texture() -> void:
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
			image.set_pixel(x, y, _get_direct_biome_color_at(world_position, biome_zones, colors))
	biome_blend_texture = ImageTexture.create_from_image(image)
	biome_blend_colors_key = current_key


func _get_direct_biome_color_at(position: Vector2, zones: Array[Dictionary], colors: Array[Color]) -> Color:
	var nearest_index := -1
	var nearest_distance := INF
	for i in zones.size():
		var points := PackedVector2Array(zones[i]["points"])
		if Geometry2D.is_point_in_polygon(position, points):
			return colors[i]
		var edge_distance := _get_point_polygon_edge_distance(position, points)
		if edge_distance < nearest_distance:
			nearest_distance = edge_distance
			nearest_index = i
	if nearest_index >= 0:
		return colors[nearest_index]
	return Color.BLACK


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


func _draw_grid(content_rect: Rect2, view_world_rect: Rect2) -> void:
	var grid_color := Color(0.23, 0.31, 0.22, 0.55)
	var grid_step := 320.0
	var start_x: float = floorf(view_world_rect.position.x / grid_step) * grid_step
	while start_x <= view_world_rect.end.x:
		var from := _world_to_map(Vector2(start_x, view_world_rect.position.y), content_rect, view_world_rect)
		var to := _world_to_map(Vector2(start_x, view_world_rect.end.y), content_rect, view_world_rect)
		draw_line(from, to, grid_color, 1.0)
		start_x += grid_step
	var start_y: float = floorf(view_world_rect.position.y / grid_step) * grid_step
	while start_y <= view_world_rect.end.y:
		var from := _world_to_map(Vector2(view_world_rect.position.x, start_y), content_rect, view_world_rect)
		var to := _world_to_map(Vector2(view_world_rect.end.x, start_y), content_rect, view_world_rect)
		draw_line(from, to, grid_color, 1.0)
		start_y += grid_step


func _draw_landmarks(content_rect: Rect2, view_world_rect: Rect2) -> void:
	for landmark in landmarks:
		var world_position := Vector2(landmark.get("position", Vector2.ZERO))
		var radius_world := float(landmark.get("radius", 80.0))
		if not _intersects_view_circle(world_position, radius_world, view_world_rect):
			continue
		var center := _world_to_map(world_position, content_rect, view_world_rect)
		var radius := _world_radius_to_map(float(landmark.get("radius", 80.0)), content_rect)
		match str(landmark.get("type", "")):
			"pond":
				_draw_pond_marker(center, radius, landmark)
			"hill":
				_draw_hill_marker(center, radius, landmark)


func _refresh_landmarks_from_world() -> void:
	var world := get_tree().current_scene.get_node_or_null("World")
	if world and world.has_method("get_landmarks"):
		landmarks = world.get_landmarks()


func _draw_pond_marker(center: Vector2, radius: float, landmark: Dictionary) -> void:
	var marker_radius: float = clamp(radius, 7.0, 24.0)
	_draw_filled_pond_marker(center, marker_radius, landmark, 1.0, Color(0.10, 0.36, 0.48, 0.90))
	_draw_filled_pond_marker(center, marker_radius, landmark, 0.68, Color(0.16, 0.50, 0.58, 0.58))


func _draw_filled_pond_marker(center: Vector2, radius: float, landmark: Dictionary, radius_factor: float, marker_color: Color) -> void:
	var points := PackedVector2Array()
	var sample_count := _get_pond_shape_sample_count()
	for i in range(sample_count):
		var angle := TAU * float(i) / float(sample_count)
		var shape_scale := _get_pond_shape_scale(landmark, angle)
		points.append(center + Vector2(
			cos(angle) * radius * radius_factor * shape_scale,
			sin(angle) * radius * POND_MARKER_Y_SCALE * radius_factor * shape_scale
		))
	draw_colored_polygon(points, marker_color)


func _get_pond_shape_scale(landmark: Dictionary, angle: float) -> float:
	var irregularity: float = float(clamp(float(GAME_BALANCE.LANDMARKS.get("pond_shape_irregularity", 0.16)), 0.0, 0.45))
	if irregularity <= 0.0:
		return 1.0
	var seed: float = _get_pond_shape_seed(landmark)
	var wave: float = (
		sin(angle * 2.0 + seed) * 0.55
		+ sin(angle * 3.0 - seed * 1.7) * 0.32
		+ sin(angle * 5.0 + seed * 0.6) * 0.18
	) / 1.05
	return clamp(1.0 + wave * irregularity, 1.0 - irregularity * 1.25, 1.0 + irregularity * 1.25)


func _get_pond_shape_seed(landmark: Dictionary) -> float:
	var pond_id := str(landmark.get("id", "pond"))
	var seed := 0
	for i in pond_id.length():
		seed = (seed + pond_id.unicode_at(i) * (i + 3)) % 997
	return float(seed) / 997.0 * TAU


func _get_pond_shape_sample_count() -> int:
	return max(16, int(GAME_BALANCE.LANDMARKS.get("pond_shape_sample_count", 48)))


func _draw_hill_marker(center: Vector2, radius: float, landmark: Dictionary) -> void:
	var marker_radius: float = clamp(radius, 8.0, 25.0)
	_draw_filled_hill_marker(center + Vector2(marker_radius * 0.08, marker_radius * 0.10), marker_radius, landmark, 1.0, Color(0.12, 0.13, 0.08, 0.38))
	_draw_filled_hill_marker(center, marker_radius, landmark, 1.0, Color(0.38, 0.36, 0.22, 0.90))
	_draw_filled_hill_marker(center + Vector2(-marker_radius * 0.08, -marker_radius * 0.08), marker_radius, landmark, 0.56, Color(0.58, 0.55, 0.32, 0.58))
	draw_line(center + Vector2(-marker_radius * 0.42, -marker_radius * 0.08), center + Vector2(marker_radius * 0.22, -marker_radius * 0.16), Color(0.72, 0.69, 0.43, 0.58), 1.2)
	draw_line(center + Vector2(-marker_radius * 0.18, marker_radius * 0.18), center + Vector2(marker_radius * 0.42, marker_radius * 0.06), Color(0.15, 0.16, 0.09, 0.42), 1.2)


func _draw_filled_hill_marker(center: Vector2, radius: float, landmark: Dictionary, radius_factor: float, marker_color: Color) -> void:
	var points := PackedVector2Array()
	var sample_count := _get_hill_shape_sample_count()
	for i in range(sample_count):
		var angle := TAU * float(i) / float(sample_count)
		var shape_scale := _get_hill_shape_scale(landmark, angle)
		points.append(center + Vector2(
			cos(angle) * radius * radius_factor * shape_scale,
			sin(angle) * radius * HILL_MARKER_Y_SCALE * radius_factor * shape_scale
		))
	draw_colored_polygon(points, marker_color)


func _get_hill_shape_scale(landmark: Dictionary, angle: float) -> float:
	var irregularity: float = float(clamp(float(GAME_BALANCE.LANDMARKS.get("hill_shape_irregularity", 0.10)), 0.0, 0.35))
	if irregularity <= 0.0:
		return 1.0
	var seed: float = _get_hill_shape_seed(landmark)
	var wave: float = (
		sin(angle * 2.0 + seed) * 0.50
		+ sin(angle * 4.0 - seed * 1.35) * 0.28
		+ sin(angle * 6.0 + seed * 0.4) * 0.16
	) / 0.94
	return clamp(1.0 + wave * irregularity, 1.0 - irregularity * 1.15, 1.0 + irregularity * 1.15)


func _get_hill_shape_seed(landmark: Dictionary) -> float:
	var hill_id := str(landmark.get("id", "hill"))
	var seed := 0
	for i in hill_id.length():
		seed = (seed + hill_id.unicode_at(i) * (i + 5)) % 997
	return float(seed) / 997.0 * TAU


func _get_hill_shape_sample_count() -> int:
	return max(16, int(GAME_BALANCE.LANDMARKS.get("hill_shape_sample_count", 40)))


func _draw_filled_ellipse(rect: Rect2, ellipse_color: Color) -> void:
	var points := PackedVector2Array()
	var center := rect.get_center()
	var radii := rect.size * 0.5
	for i in range(20):
		var angle := TAU * float(i) / 20.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, ellipse_color)


func _draw_resources(content_rect: Rect2, view_world_rect: Rect2) -> void:
	for resource in cached_resources:
		if not is_instance_valid(resource):
			continue
		if not _should_draw_resource_on_minimap(resource):
			continue
		if not view_world_rect.has_point(resource.global_position):
			continue
		var color := _get_resource_color(resource)
		draw_circle(_world_to_map(resource.global_position, content_rect, view_world_rect), 3.3, color)


func _should_draw_resource_on_minimap(resource: Node) -> bool:
	var resource_kind := str(resource.get("resource_kind"))
	if resource_kind in ["grass_patch", "dense_grass", "berry_bush"]:
		return false
	if resource.get("player_harvestable") == false:
		return false
	return true


func _draw_varnaks(content_rect: Rect2, view_world_rect: Rect2) -> void:
	for varnak in get_tree().get_nodes_in_group("varnak"):
		if not is_instance_valid(varnak):
			continue
		if not view_world_rect.has_point(varnak.global_position):
			continue
		var pos := _world_to_map(varnak.global_position, content_rect, view_world_rect)
		draw_circle(pos, 5.2, Color(0.88, 0.22, 0.16))
		draw_circle(pos, 2.2, Color(1.0, 0.82, 0.42))


func _draw_player(content_rect: Rect2, view_world_rect: Rect2) -> void:
	if not is_instance_valid(player):
		return
	var pos := _world_to_map(player.global_position, content_rect, view_world_rect)
	draw_circle(pos, 6.4, Color(0.17, 0.48, 1.0))
	draw_circle(pos, 3.0, Color.WHITE)


func _draw_zone_label(map_rect: Rect2) -> void:
	var label_rect := Rect2(0.0, map_rect.size.y - 30.0, map_rect.size.x, 30.0)
	draw_rect(label_rect, Color(0.03, 0.04, 0.04, 0.88), true)
	draw_line(label_rect.position, label_rect.position + Vector2(label_rect.size.x, 0.0), Color(0.74, 0.78, 0.68, 0.55), 1.0)
	draw_string(get_theme_default_font(), label_rect.position + Vector2(10.0, 21.0), "Zone: %s" % _get_player_zone_name(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.90, 0.92, 0.84))


func _get_player_zone_name() -> String:
	if not is_instance_valid(player):
		return "Unknown"
	for biome in biome_zones:
		if Geometry2D.is_point_in_polygon(player.global_position, PackedVector2Array(biome["points"])):
			return str(biome.get("name", "Unknown"))
	return "Wilderness"


func _world_to_map(world_position: Vector2, content_rect: Rect2, view_world_rect: Rect2) -> Vector2:
	var normalized := Vector2(
		inverse_lerp(view_world_rect.position.x, view_world_rect.end.x, world_position.x),
		inverse_lerp(view_world_rect.position.y, view_world_rect.end.y, world_position.y)
	)
	return content_rect.position + normalized * content_rect.size


func _world_radius_to_map(world_radius: float, content_rect: Rect2) -> float:
	var view_world_rect: Rect2 = _get_minimap_view_world_rect(content_rect)
	var x_scale: float = content_rect.size.x / maxf(view_world_rect.size.x, 1.0)
	var y_scale: float = content_rect.size.y / maxf(view_world_rect.size.y, 1.0)
	return world_radius * min(x_scale, y_scale)


func _get_minimap_view_world_rect(content_rect: Rect2) -> Rect2:
	var center: Vector2 = player.global_position if is_instance_valid(player) else world_rect.get_center()
	var view_size: Vector2 = _get_minimap_view_world_size(content_rect)
	return Rect2(center - view_size * 0.5, view_size)


func _get_minimap_view_world_size(content_rect: Rect2) -> Vector2:
	var camera_world_size: Vector2 = _get_player_camera_world_size()
	var padded_size: Vector2 = camera_world_size * MINIMAP_VIEW_MARGIN_FACTOR
	return _fit_world_size_to_content_aspect(padded_size, content_rect)


func _get_player_camera_world_size() -> Vector2:
	if camera_world_size_override != Vector2.ZERO:
		return camera_world_size_override
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return MINIMAP_FALLBACK_VIEW_WORLD_SIZE
	var camera: Camera2D = _get_player_camera()
	if camera == null:
		return MINIMAP_FALLBACK_VIEW_WORLD_SIZE
	var zoom: Vector2 = camera.zoom
	return Vector2(
		maxf(viewport_size.x * absf(zoom.x), 1.0),
		maxf(viewport_size.y * absf(zoom.y), 1.0)
	)


func _get_player_camera() -> Camera2D:
	if not is_instance_valid(player):
		return null
	return player.get_node_or_null("Camera2D") as Camera2D


func _fit_world_size_to_content_aspect(size_world: Vector2, content_rect: Rect2) -> Vector2:
	var aspect: float = content_rect.size.x / maxf(content_rect.size.y, 1.0)
	var fitted: Vector2 = size_world
	if fitted.x / maxf(fitted.y, 1.0) < aspect:
		fitted.x = fitted.y * aspect
	else:
		fitted.y = fitted.x / aspect
	fitted.x = min(fitted.x, world_rect.size.x)
	fitted.y = min(fitted.y, world_rect.size.y)
	return fitted


func _world_rect_to_map_rect(target_world_rect: Rect2, content_rect: Rect2, view_world_rect: Rect2) -> Rect2:
	var top_left := _world_to_map(target_world_rect.position, content_rect, view_world_rect)
	var bottom_right := _world_to_map(target_world_rect.end, content_rect, view_world_rect)
	return Rect2(top_left, bottom_right - top_left)


func _world_rect_to_texture_region(target_world_rect: Rect2) -> Rect2:
	var texture_size := Vector2(float(BIOME_BLEND_TEXTURE_SIZE.x), float(BIOME_BLEND_TEXTURE_SIZE.y))
	var start_uv := Vector2(
		inverse_lerp(world_rect.position.x, world_rect.end.x, target_world_rect.position.x),
		inverse_lerp(world_rect.position.y, world_rect.end.y, target_world_rect.position.y)
	)
	var end_uv := Vector2(
		inverse_lerp(world_rect.position.x, world_rect.end.x, target_world_rect.end.x),
		inverse_lerp(world_rect.position.y, world_rect.end.y, target_world_rect.end.y)
	)
	start_uv.x = clamp(start_uv.x, 0.0, 1.0)
	start_uv.y = clamp(start_uv.y, 0.0, 1.0)
	end_uv.x = clamp(end_uv.x, 0.0, 1.0)
	end_uv.y = clamp(end_uv.y, 0.0, 1.0)
	return Rect2(start_uv * texture_size, (end_uv - start_uv) * texture_size)


func _intersects_view_circle(center: Vector2, radius: float, view_world_rect: Rect2) -> bool:
	var closest_point := Vector2(
		clamp(center.x, view_world_rect.position.x, view_world_rect.end.x),
		clamp(center.y, view_world_rect.position.y, view_world_rect.end.y)
	)
	return center.distance_squared_to(closest_point) <= radius * radius


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


func _update_resources_cache() -> void:
	cached_resources = get_tree().get_nodes_in_group("resources")
	# Clean up dead references
	for i in range(cached_resources.size() - 1, -1, -1):
		if not is_instance_valid(cached_resources[i]):
			cached_resources.remove_at(i)
