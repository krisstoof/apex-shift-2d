extends Control

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const PADDING := 24.0
const PANEL_GAP := 20.0
const BIOME_BLEND_TEXTURE_SIZE := Vector2i(160, 98)
const BIOME_BLEND_RADIUS := 420.0
const BIOME_NEIGHBOR_BLEND_WEIGHT := 0.90

var player: Node2D
var evolution_director: Node
var day_night_system: Node
var world_rect := WORLD_CONFIG.WORLD_RECT
var biome_zones: Array[Dictionary] = []
var landmarks: Array[Dictionary] = []
var biome_blend_texture: ImageTexture
var biome_blend_colors_key := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visible = false


func bind(p_player: Node2D, p_evolution_director: Node, p_day_night_system: Node, p_world_rect: Rect2, p_biome_zones: Array[Dictionary], p_landmarks: Array[Dictionary] = []) -> void:
	player = p_player
	evolution_director = p_evolution_director
	day_night_system = p_day_night_system
	world_rect = p_world_rect
	biome_zones = p_biome_zones
	landmarks = p_landmarks
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	_refresh_landmarks_from_world()
	var screen_rect := Rect2(Vector2.ZERO, size)
	var inner_rect := screen_rect.grow(-PADDING)
	var info_width: float = min(360.0, inner_rect.size.x * 0.32)
	var map_rect := Rect2(inner_rect.position, Vector2(inner_rect.size.x - info_width - PANEL_GAP, inner_rect.size.y))
	var info_rect := Rect2(Vector2(map_rect.end.x + PANEL_GAP, inner_rect.position.y), Vector2(info_width, inner_rect.size.y))

	draw_rect(screen_rect, Color(0.015, 0.018, 0.018, 0.94), true)
	_draw_map_panel(map_rect)
	_draw_info_panel(info_rect)


func _draw_map_panel(rect: Rect2) -> void:
	draw_rect(rect, Color(0.04, 0.05, 0.05, 0.96), true)
	draw_rect(rect, Color(0.70, 0.74, 0.66, 0.78), false, 1.0)
	var map_rect := _fit_world_rect(rect.grow(-16.0))
	draw_rect(map_rect, Color(0.10, 0.14, 0.10), true)
	_draw_biomes(map_rect)
	_draw_grid(map_rect)
	_draw_landmarks(map_rect)
	_draw_resources(map_rect)
	_draw_varnaks(map_rect)
	_draw_player(map_rect)
	_draw_map_legend(map_rect)
	draw_rect(map_rect, Color(0.30, 0.36, 0.28, 0.85), false, 1.0)


func _draw_info_panel(rect: Rect2) -> void:
	draw_rect(rect, Color(0.04, 0.05, 0.05, 0.96), true)
	draw_rect(rect, Color(0.70, 0.74, 0.66, 0.78), false, 1.0)
	var profile: Dictionary = evolution_director.get_profile() if evolution_director else {}
	var live_varnaks := get_tree().get_nodes_in_group("varnak").size()
	var pond_count := _get_landmark_count("pond")
	var hill_count := _get_landmark_count("hill")
	var zone_name := _get_player_zone_name()
	var time_label := _get_time_label()
	var lines := [
		"Field Map",
		"",
		"Zone: %s" % zone_name,
		"Day: %d  Time: %s %s" % [day_night_system.get_day() if day_night_system else 1, _get_clock_time(), time_label],
		"Ponds: %d  Hills: %d" % [pond_count, hill_count],
		"Live Varnaks: %d" % live_varnaks,
		"",
		"Player",
		"Health: %3d" % player.stats.health,
		"Hunger: %3d" % player.stats.hunger,
		"Stamina: %3d" % player.stats.stamina,
		"Rest: %3d  %s" % [player.stats.rest, player.stats.get_condition_text()],
		"",
		"Inventory",
		"Wood %d  Stone %d  Fiber %d" % [player.inventory.get_amount("wood"), player.inventory.get_amount("stone"), player.inventory.get_amount("fiber")],
		"Meat %d  Hide %d  Bone %d" % [player.inventory.get_amount("meat"), player.inventory.get_amount("hide"), player.inventory.get_amount("bone")],
		"",
		"Varnak Profile",
		"Generation: %d" % int(profile.get("generation", 1)),
		"Aggression: %.2f" % float(profile.get("aggression", 0.0)),
		"Fire fear: %.2f" % float(profile.get("fire_fear", 0.0)),
		"Trap awareness: %.2f" % float(profile.get("trap_awareness", 0.0)),
		"Pack: %.2f" % float(profile.get("pack_coordination", 0.0))
	]
	_draw_lines(lines, rect.position + Vector2(16.0, 28.0), rect.size.x - 32.0)


func _draw_lines(lines: Array, start: Vector2, width: float) -> void:
	var font := get_theme_default_font()
	var y := start.y
	for line_value in lines:
		var line := str(line_value)
		var font_size := 20 if line in ["Field Map", "Player", "Inventory", "Varnak Profile"] else 15
		var color := Color(0.95, 0.92, 0.78) if font_size == 20 else Color(0.86, 0.88, 0.82)
		draw_string(font, Vector2(start.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)
		y += 28.0 if font_size == 20 else 21.0


func _fit_world_rect(bounds: Rect2) -> Rect2:
	var world_aspect := world_rect.size.x / world_rect.size.y
	var bounds_aspect := bounds.size.x / bounds.size.y
	if bounds_aspect > world_aspect:
		var width := bounds.size.y * world_aspect
		return Rect2(Vector2(bounds.position.x + (bounds.size.x - width) * 0.5, bounds.position.y), Vector2(width, bounds.size.y))
	var height := bounds.size.x / world_aspect
	return Rect2(Vector2(bounds.position.x, bounds.position.y + (bounds.size.y - height) * 0.5), Vector2(bounds.size.x, height))


func _draw_biomes(map_rect: Rect2) -> void:
	if biome_zones.is_empty():
		return
	_ensure_biome_blend_texture()
	if biome_blend_texture:
		draw_texture_rect(biome_blend_texture, map_rect, false)


func _draw_grid(map_rect: Rect2) -> void:
	var grid_color := Color(0.25, 0.30, 0.23, 0.48)
	for i in range(1, 6):
		var x := map_rect.position.x + map_rect.size.x * float(i) / 6.0
		var y := map_rect.position.y + map_rect.size.y * float(i) / 6.0
		draw_line(Vector2(x, map_rect.position.y), Vector2(x, map_rect.end.y), grid_color, 1.0)
		draw_line(Vector2(map_rect.position.x, y), Vector2(map_rect.end.x, y), grid_color, 1.0)


func _draw_resources(map_rect: Rect2) -> void:
	for resource in get_tree().get_nodes_in_group("resources"):
		if is_instance_valid(resource):
			draw_circle(_world_to_map(resource.global_position, map_rect), 3.0, _get_resource_color(resource))


func _draw_landmarks(map_rect: Rect2) -> void:
	for landmark in landmarks:
		var center := _world_to_map(Vector2(landmark.get("position", Vector2.ZERO)), map_rect)
		var radius := _world_radius_to_map(float(landmark.get("radius", 80.0)), map_rect)
		match str(landmark.get("type", "")):
			"pond":
				_draw_pond_marker(center, radius)
				_draw_landmark_label(center, _get_landmark_label(landmark), Color(0.72, 0.92, 0.88))
			"hill":
				_draw_hill_marker(center, radius)
				_draw_landmark_label(center, _get_landmark_label(landmark), Color(0.86, 0.82, 0.56))


func _refresh_landmarks_from_world() -> void:
	if not landmarks.is_empty():
		return
	var world := get_tree().current_scene.get_node_or_null("World")
	if world and world.has_method("get_landmarks"):
		landmarks = world.get_landmarks()


func _draw_pond_marker(center: Vector2, radius: float) -> void:
	var marker_radius: float = clamp(radius, 8.0, 34.0)
	_draw_filled_ellipse(Rect2(center - Vector2(marker_radius, marker_radius * 0.62), Vector2(marker_radius * 2.0, marker_radius * 1.24)), Color(0.08, 0.31, 0.43, 0.92))
	_draw_filled_ellipse(Rect2(center - Vector2(marker_radius * 0.64, marker_radius * 0.34), Vector2(marker_radius * 1.28, marker_radius * 0.68)), Color(0.15, 0.48, 0.56, 0.62))
	draw_arc(center, marker_radius * 0.82, deg_to_rad(18.0), deg_to_rad(164.0), 18, Color(0.62, 0.88, 0.82, 0.55), 2.0, true)


func _draw_hill_marker(center: Vector2, radius: float) -> void:
	var marker_radius: float = clamp(radius, 9.0, 38.0)
	_draw_filled_ellipse(Rect2(center - Vector2(marker_radius, marker_radius * 0.58), Vector2(marker_radius * 2.0, marker_radius * 1.16)), Color(0.34, 0.33, 0.22, 0.86))
	_draw_filled_ellipse(Rect2(center - Vector2(marker_radius * 0.62, marker_radius * 0.34), Vector2(marker_radius * 1.24, marker_radius * 0.68)), Color(0.43, 0.42, 0.27, 0.48))
	draw_arc(center + Vector2(0.0, -marker_radius * 0.10), marker_radius * 0.66, deg_to_rad(198.0), deg_to_rad(342.0), 18, Color(0.64, 0.61, 0.38, 0.55), 2.0, true)


func _draw_filled_ellipse(rect: Rect2, ellipse_color: Color) -> void:
	var points := PackedVector2Array()
	var center := rect.get_center()
	var radii := rect.size * 0.5
	for i in range(28):
		var angle := TAU * float(i) / 28.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, ellipse_color)


func _draw_landmark_label(center: Vector2, label: String, color: Color) -> void:
	if label.is_empty():
		return
	var font := get_theme_default_font()
	var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12)
	var label_position := center + Vector2(-label_size.x * 0.5, 22.0)
	draw_rect(Rect2(label_position + Vector2(-4.0, -12.0), label_size + Vector2(8.0, 16.0)), Color(0.02, 0.025, 0.02, 0.58), true)
	draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, color)


func _get_landmark_label(landmark: Dictionary) -> String:
	var landmark_id := str(landmark.get("id", ""))
	if landmark_id.is_empty():
		return ""
	var words := landmark_id.replace("_", " ").split(" ")
	var label_parts: Array[String] = []
	for word in words:
		if str(word).is_empty():
			continue
		label_parts.append(str(word).capitalize())
	return " ".join(label_parts)


func _draw_map_legend(map_rect: Rect2) -> void:
	var legend_rect := Rect2(map_rect.position + Vector2(14.0, 14.0), Vector2(154.0, 118.0))
	draw_rect(legend_rect, Color(0.025, 0.032, 0.028, 0.78), true)
	draw_rect(legend_rect, Color(0.70, 0.74, 0.66, 0.34), false, 1.0)
	var font := get_theme_default_font()
	draw_string(font, legend_rect.position + Vector2(10.0, 20.0), "Legend", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.95, 0.92, 0.78))
	_draw_legend_entry(legend_rect.position + Vector2(12.0, 40.0), "Pond", Color(0.12, 0.47, 0.56))
	_draw_legend_entry(legend_rect.position + Vector2(12.0, 60.0), "Hill", Color(0.48, 0.45, 0.28))
	_draw_legend_entry(legend_rect.position + Vector2(12.0, 80.0), "Resource", Color(0.67, 0.95, 0.34))
	_draw_legend_entry(legend_rect.position + Vector2(12.0, 100.0), "Varnak", Color(0.88, 0.22, 0.16))


func _draw_legend_entry(position: Vector2, label: String, color: Color) -> void:
	draw_circle(position + Vector2(5.0, -4.0), 4.5, color)
	draw_string(get_theme_default_font(), position + Vector2(16.0, 0.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.86, 0.88, 0.82))


func _draw_varnaks(map_rect: Rect2) -> void:
	for varnak in get_tree().get_nodes_in_group("varnak"):
		if is_instance_valid(varnak):
			var pos := _world_to_map(varnak.global_position, map_rect)
			draw_circle(pos, 5.0, Color(0.88, 0.22, 0.16))
			draw_circle(pos, 2.0, Color(1.0, 0.82, 0.42))


func _draw_player(map_rect: Rect2) -> void:
	if not is_instance_valid(player):
		return
	var pos := _world_to_map(player.global_position, map_rect)
	draw_circle(pos, 6.5, Color(0.17, 0.48, 1.0))
	draw_circle(pos, 3.0, Color.WHITE)


func _ensure_biome_blend_texture() -> void:
	if biome_zones.is_empty():
		return
	var current_key := _get_biome_colors_key()
	if biome_blend_texture and biome_blend_colors_key == current_key:
		return
	var image := Image.create(BIOME_BLEND_TEXTURE_SIZE.x, BIOME_BLEND_TEXTURE_SIZE.y, false, Image.FORMAT_RGBA8)
	var colors: Array[Color] = []
	for biome in biome_zones:
		colors.append(Color(biome["color"]))
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


func _world_to_map(world_position: Vector2, map_rect: Rect2) -> Vector2:
	var normalized := Vector2(
		inverse_lerp(world_rect.position.x, world_rect.end.x, world_position.x),
		inverse_lerp(world_rect.position.y, world_rect.end.y, world_position.y)
	)
	normalized.x = clamp(normalized.x, 0.0, 1.0)
	normalized.y = clamp(normalized.y, 0.0, 1.0)
	return map_rect.position + normalized * map_rect.size


func _world_radius_to_map(world_radius: float, map_rect: Rect2) -> float:
	var x_scale := map_rect.size.x / world_rect.size.x
	var y_scale := map_rect.size.y / world_rect.size.y
	return world_radius * min(x_scale, y_scale)


func _get_player_zone_name() -> String:
	if not is_instance_valid(player):
		return "Unknown"
	for biome in biome_zones:
		if Geometry2D.is_point_in_polygon(player.global_position, PackedVector2Array(biome["points"])):
			return str(biome.get("name", "Unknown"))
	return "Wilderness"


func _get_landmark_count(landmark_type: String) -> int:
	var count := 0
	for landmark in landmarks:
		if str(landmark.get("type", "")) == landmark_type:
			count += 1
	return count


func _get_time_label() -> String:
	if not day_night_system:
		return "Day"
	if day_night_system.has_method("get_time_label"):
		return day_night_system.get_time_label()
	return "Night" if day_night_system.is_night() else "Day"


func _get_clock_time() -> String:
	if day_night_system and day_night_system.has_method("get_clock_time"):
		return day_night_system.get_clock_time()
	return "--:--"


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
