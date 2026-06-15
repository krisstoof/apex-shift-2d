extends Control

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const PADDING := 14.0
const BIOME_BLEND_TEXTURE_SIZE := Vector2i(192, 116)
const POND_MARKER_Y_SCALE := 0.62
const HILL_MARKER_Y_SCALE := 0.58
const TERRAIN_PALETTE_VERSION := "terrain_palette_v2"
const TERRAIN_ZONE_COLORS := {
	"deep_ocean": Color(0.07, 0.22, 0.42),
	"shallow_water": Color(0.12, 0.34, 0.56),
	"shore": Color(0.64, 0.61, 0.38),
	"land": Color(0.31, 0.40, 0.22),
	"highland": Color(0.28, 0.25, 0.16)
}
const MINIMAP_REDRAW_INTERVAL := 0.5
const MINIMAP_VIEW_MARGIN_FACTOR := 1.22
const MINIMAP_FALLBACK_VIEW_WORLD_SIZE := Vector2(1280.0, 760.0)
const MINIMAP_MARKER_CACHE_INTERVAL := 1.0

var player: Node2D
var world: Node
var snapshot_service
var world_rect := WORLD_CONFIG.WORLD_RECT
var biome_zones: Array[Dictionary] = []
var landmarks: Array[Dictionary] = []
var biome_blend_texture: ImageTexture
var biome_blend_colors_key := ""
var minimap_redraw_count: int = 0
var minimap_marker_cache_rebuild_count: int = 0
var minimap_landmark_cache_rebuild_count: int = 0
var minimap_texture_build_count: int = 0
var minimap_texture_last_build_ms: float = 0.0
var _is_drawing_biomes := false
var minimap_redraw_timer := 0.0
var cached_resources: Array[Dictionary] = []
var cached_campfires: Array[Dictionary] = []
var cached_varnaks: Array[Dictionary] = []
var cached_resources_signature := ""
var cached_campfires_signature := ""
var cached_varnaks_signature := ""
var markers_cache_timer := 0.0
var landmarks_signature := ""
var camera_world_size_override := Vector2.ZERO
var hitch_log_cooldowns: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_update_marker_cache()


func _exit_tree() -> void:
	biome_blend_texture = null
	cached_resources.clear()
	cached_campfires.clear()
	cached_varnaks.clear()
	landmarks.clear()
	biome_zones.clear()
	snapshot_service = null
	world = null
	player = null


func bind(p_player: Node2D, p_world_rect: Rect2, p_biome_zones: Array[Dictionary], p_landmarks: Array[Dictionary] = [], p_snapshot_service = null) -> void:
	player = p_player
	world = _get_world()
	snapshot_service = p_snapshot_service
	world_rect = p_world_rect
	biome_zones = p_biome_zones
	landmarks = p_landmarks
	_sync_biome_texture()
	if _update_marker_cache():
		minimap_marker_cache_rebuild_count += 1
	landmarks_signature = _build_landmarks_signature()
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_log_hitch(delta, "Minimap", {
		"texture_cached": biome_blend_texture != null,
		"build_count": minimap_texture_build_count
	})
	_sync_biome_texture()
	minimap_redraw_timer += delta
	if minimap_redraw_timer >= MINIMAP_REDRAW_INTERVAL:
		minimap_redraw_timer = 0.0
		queue_redraw()
	markers_cache_timer += delta
	if markers_cache_timer >= MINIMAP_MARKER_CACHE_INTERVAL:
		markers_cache_timer = 0.0
		_refresh_static_caches()


func _draw() -> void:
	minimap_redraw_count += 1
	var map_rect := Rect2(Vector2.ZERO, size)
	var content_rect := map_rect.grow(-PADDING)
	var view_world_rect := _get_minimap_view_world_rect(content_rect)

	draw_rect(map_rect, Color(0.04, 0.05, 0.05, 0.86), true)
	draw_rect(map_rect, Color(0.74, 0.78, 0.68, 0.9), false, 1.0)
	draw_rect(content_rect, Color(0.11, 0.18, 0.11, 0.94), true)
	draw_rect(content_rect, Color(0.35, 0.43, 0.32, 0.8), false, 1.0)
	_is_drawing_biomes = true
	_draw_biomes(content_rect, view_world_rect)
	_is_drawing_biomes = false
	_draw_landmarks(content_rect, view_world_rect)
	_draw_grid(content_rect, view_world_rect)
	if _should_show_resource_markers():
		_draw_resources(content_rect, view_world_rect)
	_draw_campfires(content_rect, view_world_rect)
	_draw_varnaks(content_rect, view_world_rect)
	_draw_player(content_rect, view_world_rect)
	_draw_zone_label(map_rect)


func _draw_biomes(content_rect: Rect2, view_world_rect: Rect2) -> void:
	if biome_zones.is_empty():
		return
	if not _is_drawing_biomes:
		return
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


func _refresh_static_caches() -> void:
	var landmarks_changed := _refresh_landmarks_from_world()
	var marker_cache_changed := _update_marker_cache()
	if landmarks_changed:
		minimap_landmark_cache_rebuild_count += 1
	if marker_cache_changed:
		minimap_marker_cache_rebuild_count += 1
	if landmarks_changed or marker_cache_changed:
		queue_redraw()


func _sync_biome_texture() -> void:
	if biome_zones.is_empty():
		biome_blend_texture = null
		biome_blend_colors_key = ""
		return
	_ensure_biome_texture()


func _ensure_biome_texture() -> void:
	if biome_zones.is_empty():
		return
	var current_key := _get_biome_texture_key()
	if biome_blend_texture and biome_blend_colors_key == current_key:
		return
	var build_start_ms: int = Time.get_ticks_msec()
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
			image.set_pixel(x, y, _get_direct_biome_color_at(world_position, biome_zones, colors))
	biome_blend_texture = ImageTexture.create_from_image(image)
	biome_blend_colors_key = current_key
	minimap_texture_build_count += 1
	minimap_texture_last_build_ms = float(Time.get_ticks_msec() - build_start_ms)


func _get_direct_biome_color_at(world_position: Vector2, zones: Array[Dictionary], colors: Array[Color]) -> Color:
	var terrain_zone := WORLD_CONFIG.get_terrain_zone(world_position)
	match terrain_zone:
		"deep_ocean":
			return TERRAIN_ZONE_COLORS["deep_ocean"]
		"shallow_water":
			return TERRAIN_ZONE_COLORS["shallow_water"]
		"shore":
			return TERRAIN_ZONE_COLORS["shore"]
	var terrain_color := Color(TERRAIN_ZONE_COLORS.get(terrain_zone, TERRAIN_ZONE_COLORS["land"]))
	var nearest_index := -1
	var nearest_distance := INF
	for i in range(zones.size()):
		var points := PackedVector2Array(zones[i]["points"])
		if Geometry2D.is_point_in_polygon(world_position, points):
			return _get_land_biome_map_color(colors[i], terrain_color, terrain_zone)
		var edge_distance := _get_point_polygon_edge_distance(world_position, points)
		if edge_distance < nearest_distance:
			nearest_distance = edge_distance
			nearest_index = i
	if nearest_index >= 0:
		return _get_land_biome_map_color(colors[nearest_index], terrain_color, terrain_zone)
	return terrain_color


func _get_land_biome_map_color(biome_color: Color, terrain_color: Color, terrain_zone: String) -> Color:
	match terrain_zone:
		"highland":
			return biome_color.darkened(0.28).lerp(terrain_color, 0.45)
		"land":
			return biome_color.darkened(0.10).lerp(terrain_color, 0.30)
		_:
			return terrain_color


func _get_point_polygon_edge_distance(point: Vector2, points: PackedVector2Array) -> float:
	var nearest_distance := INF
	for i in range(points.size()):
		nearest_distance = min(nearest_distance, _get_distance_to_segment(point, points[i], points[(i + 1) % points.size()]))
	return nearest_distance


func _get_distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var t: float = clamp((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)


func _get_biome_texture_key() -> String:
	var parts: Array[String] = [TERRAIN_PALETTE_VERSION]
	parts.append("rect=%d,%d,%d,%d" % [
		int(world_rect.position.x),
		int(world_rect.position.y),
		int(world_rect.size.x),
		int(world_rect.size.y)
	])
	parts.append("scale=%.2f" % WORLD_CONFIG.WORLD_SCALE)
	parts.append("island=%.3f:%.3f" % [WORLD_CONFIG.ISLAND_RADIUS_X_RATIO, WORLD_CONFIG.ISLAND_RADIUS_Y_RATIO])
	parts.append("noise=%.5f:%.3f" % [WORLD_CONFIG.ISLAND_NOISE_SCALE, WORLD_CONFIG.ISLAND_NOISE_STRENGTH])
	parts.append("thresholds=%.3f:%.3f:%.3f:%.3f" % [
		WORLD_CONFIG.DEEP_OCEAN_THRESHOLD,
		WORLD_CONFIG.SHALLOW_WATER_THRESHOLD,
		WORLD_CONFIG.SHORE_THRESHOLD,
		WORLD_CONFIG.HIGHLAND_THRESHOLD
	])
	for zone_name in TERRAIN_ZONE_COLORS.keys():
		var color := Color(TERRAIN_ZONE_COLORS[zone_name])
		parts.append("%s=%.3f:%.3f:%.3f" % [str(zone_name), color.r, color.g, color.b])
	for biome in biome_zones:
		var color := Color(biome["color"])
		parts.append("%.3f:%.3f:%.3f" % [color.r, color.g, color.b])
	return "|".join(parts)


func _should_show_resource_markers() -> bool:
	var graphics_settings := get_node_or_null("/root/GraphicsSettings")
	if graphics_settings != null and graphics_settings.has_method("should_show_resource_markers_on_maps"):
		return graphics_settings.should_show_resource_markers_on_maps() == true
	return false


func _log_hitch(delta: float, system_name: String, flags: Dictionary = {}) -> void:
	if delta <= 0.1:
		return
	var now_ms := Time.get_ticks_msec()
	var last_log_ms := int(hitch_log_cooldowns.get(system_name, 0))
	if now_ms - last_log_ms < 5000:
		return
	hitch_log_cooldowns[system_name] = now_ms
	var flag_text := ""
	for key in flags.keys():
		if not flag_text.is_empty():
			flag_text += " "
		flag_text += "%s=%s" % [str(key), str(flags.get(key))]
	print("[HITCH] %s delta=%.3f %s" % [system_name, delta, flag_text])


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
		var center := _get_landmark_marker_center(world_position, content_rect, view_world_rect)
		var desired_radius := _world_radius_to_map(float(landmark.get("radius", 80.0)), content_rect)
		var radius := _get_landmark_marker_radius(center, desired_radius, content_rect, landmark)
		if radius < 2.0:
			continue
		match str(landmark.get("type", "")):
			"pond":
				_draw_pond_marker(center, radius, landmark)
			"hill":
				_draw_hill_marker(center, radius, landmark)


func _refresh_landmarks_from_world() -> bool:
	var snapshot := _get_snapshot()
	var world_snapshot := Dictionary(snapshot.get("world", {}))
	var changed := false
	if not world_snapshot.is_empty():
		landmarks = Array(world_snapshot.get("landmarks", landmarks))
		changed = true
	else:
		var active_world := _get_world()
		if active_world and active_world.has_method("get_landmarks"):
			landmarks = active_world.get_landmarks()
			changed = true
	if changed:
		var signature := _build_landmarks_signature()
		changed = signature != landmarks_signature
		landmarks_signature = signature
	return changed


func _build_landmarks_signature() -> String:
	var parts: Array[String] = []
	for landmark in landmarks:
		parts.append("%s:%s:%d:%d:%d" % [
			str(landmark.get("id", "")),
			str(landmark.get("type", "")),
			int(round(Vector2(landmark.get("position", Vector2.ZERO)).x)),
			int(round(Vector2(landmark.get("position", Vector2.ZERO)).y)),
			int(round(float(landmark.get("radius", 0.0))))
		])
	return "|".join(parts)


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
	var pond_shape_seed: float = _get_pond_shape_seed(landmark)
	var wave: float = (
		sin(angle * 2.0 + pond_shape_seed) * 0.55
		+ sin(angle * 3.0 - pond_shape_seed * 1.7) * 0.32
		+ sin(angle * 5.0 + pond_shape_seed * 0.6) * 0.18
	) / 1.05
	return clamp(1.0 + wave * irregularity, 1.0 - irregularity * 1.25, 1.0 + irregularity * 1.25)


func _get_pond_shape_seed(landmark: Dictionary) -> float:
	var pond_id := str(landmark.get("id", "pond"))
	var raw_seed: int = 0
	for i in pond_id.length():
		raw_seed = (raw_seed + pond_id.unicode_at(i) * (i + 3)) % 997
	return float(raw_seed) / 997.0 * TAU


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
	var hill_seed: float = _get_hill_shape_seed(landmark)
	var wave: float = (
		sin(angle * 2.0 + hill_seed) * 0.50
		+ sin(angle * 4.0 - hill_seed * 1.35) * 0.28
		+ sin(angle * 6.0 + hill_seed * 0.4) * 0.16
	) / 0.94
	return clamp(1.0 + wave * irregularity, 1.0 - irregularity * 1.15, 1.0 + irregularity * 1.15)


func _get_hill_shape_seed(landmark: Dictionary) -> float:
	var hill_id := str(landmark.get("id", "hill"))
	var hash_value := 0
	for i in hill_id.length():
		hash_value = (hash_value + hill_id.unicode_at(i) * (i + 5)) % 997
	return float(hash_value) / 997.0 * TAU


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
	for resource_marker_value in cached_resources:
		var resource_marker := Dictionary(resource_marker_value)
		var marker_position := Vector2(resource_marker.get("position", Vector2.ZERO))
		if not view_world_rect.has_point(marker_position):
			continue
		var color := _get_resource_marker_color(resource_marker)
		draw_circle(_world_to_map(marker_position, content_rect, view_world_rect), 3.3, color)


func _draw_campfires(content_rect: Rect2, view_world_rect: Rect2) -> void:
	for campfire_marker_value in cached_campfires:
		var campfire_marker := Dictionary(campfire_marker_value)
		var marker_position := Vector2(campfire_marker.get("position", Vector2.ZERO))
		if not view_world_rect.has_point(marker_position):
			continue
		var pos := _world_to_map(marker_position, content_rect, view_world_rect)
		var active: bool = campfire_marker.get("active", true) == true
		var outer_color := Color(1.0, 0.46, 0.10) if active else Color(0.48, 0.36, 0.22)
		var inner_color := Color(1.0, 0.88, 0.28) if active else Color(0.68, 0.58, 0.42)
		draw_circle(pos, 5.0, outer_color)
		draw_circle(pos, 2.2, inner_color)


func _draw_varnaks(content_rect: Rect2, view_world_rect: Rect2) -> void:
	for varnak_marker_value in cached_varnaks:
		var varnak_marker := Dictionary(varnak_marker_value)
		var marker_position := Vector2(varnak_marker.get("position", Vector2.ZERO))
		if not view_world_rect.has_point(marker_position):
			continue
		var pos := _world_to_map(marker_position, content_rect, view_world_rect)
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


func _get_landmark_marker_center(world_position: Vector2, content_rect: Rect2, view_world_rect: Rect2) -> Vector2:
	var center := _world_to_map(world_position, content_rect, view_world_rect)
	return Vector2(
		clamp(center.x, content_rect.position.x, content_rect.end.x),
		clamp(center.y, content_rect.position.y, content_rect.end.y)
	)


func _world_radius_to_map(world_radius: float, content_rect: Rect2) -> float:
	var view_world_rect: Rect2 = _get_minimap_view_world_rect(content_rect)
	var x_scale: float = content_rect.size.x / maxf(view_world_rect.size.x, 1.0)
	var y_scale: float = content_rect.size.y / maxf(view_world_rect.size.y, 1.0)
	return world_radius * min(x_scale, y_scale)


func _get_landmark_marker_radius(center: Vector2, desired_radius: float, content_rect: Rect2, landmark: Dictionary) -> float:
	var left_space := maxf(center.x - content_rect.position.x, 0.0)
	var right_space := maxf(content_rect.end.x - center.x, 0.0)
	var top_space := maxf(center.y - content_rect.position.y, 0.0)
	var bottom_space := maxf(content_rect.end.y - center.y, 0.0)
	match str(landmark.get("type", "")):
		"pond":
			var max_shape_scale := _get_max_shape_scale(landmark, true)
			var horizontal_limit := minf(left_space, right_space) / maxf(max_shape_scale, 0.001)
			var vertical_limit := minf(top_space, bottom_space) / maxf(max_shape_scale * POND_MARKER_Y_SCALE, 0.001)
			return minf(desired_radius, minf(horizontal_limit, vertical_limit))
		"hill":
			var max_shape_scale := _get_max_shape_scale(landmark, false)
			var left_limit := left_space / maxf(max_shape_scale, 0.001)
			var right_limit := right_space / maxf(max_shape_scale * 1.08, 0.001)
			var top_limit := top_space / maxf(max_shape_scale * 0.66, 0.001)
			var bottom_limit := bottom_space / maxf(max_shape_scale * 0.68, 0.001)
			var edge_limit := minf(minf(left_limit, right_limit), minf(top_limit, bottom_limit))
			return minf(desired_radius, edge_limit)
	return desired_radius


func _get_max_shape_scale(landmark: Dictionary, is_pond: bool) -> float:
	var max_scale := 1.0
	var sample_count := _get_pond_shape_sample_count() if is_pond else _get_hill_shape_sample_count()
	for i in range(sample_count):
		var angle := TAU * float(i) / float(sample_count)
		var shape_scale := _get_pond_shape_scale(landmark, angle) if is_pond else _get_hill_shape_scale(landmark, angle)
		max_scale = maxf(max_scale, shape_scale)
	return max_scale


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


func _get_resource_marker_color(resource_marker: Dictionary) -> Color:
	match str(resource_marker.get("item_name", "")):
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


func _update_marker_cache() -> bool:
	var snapshot := _get_snapshot(true)
	var markers := Dictionary(snapshot.get("markers", {}))
	if not markers.is_empty():
		cached_resources = _to_dictionary_array(Array(markers.get("resources", [])))
		cached_campfires = _to_dictionary_array(Array(markers.get("campfires", [])))
		cached_varnaks = _to_dictionary_array(Array(markers.get("varnaks", [])))
	else:
		cached_resources = _build_resource_markers_from_world()
		cached_campfires = _build_campfire_markers_from_world()
		cached_varnaks = _build_varnak_markers_from_world()
	var resource_signature := _build_resources_signature()
	var campfire_signature := _build_campfires_signature()
	var varnak_signature := _build_varnaks_signature()
	var changed := resource_signature != cached_resources_signature or campfire_signature != cached_campfires_signature or varnak_signature != cached_varnaks_signature
	cached_resources_signature = resource_signature
	cached_campfires_signature = campfire_signature
	cached_varnaks_signature = varnak_signature
	return changed


func _update_resources_cache() -> void:
	if _update_marker_cache():
		minimap_marker_cache_rebuild_count += 1


func get_minimap_performance_debug() -> Dictionary:
	return {
		"redraw_count": minimap_redraw_count,
		"marker_cache_rebuild_count": minimap_marker_cache_rebuild_count,
		"landmark_cache_rebuild_count": minimap_landmark_cache_rebuild_count
	}


func _build_resources_signature() -> String:
	var parts: Array[String] = []
	for resource_value in cached_resources:
		var resource := Dictionary(resource_value)
		parts.append("%s:%d:%d:%s:%s" % [
			str(resource.get("resource_kind", resource.get("item_name", "resource"))),
			int(round(Vector2(resource.get("position", Vector2.ZERO)).x)),
			int(round(Vector2(resource.get("position", Vector2.ZERO)).y)),
			str(resource.get("resource_kind")),
			"1" if resource.get("player_harvestable", true) != false else "0"
	])
	return "|".join(parts)


func _build_campfire_markers_from_world() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	var active_world := _get_world()
	if active_world == null or not active_world.has_method("get_cached_group_nodes"):
		return markers
	for campfire_value in active_world.get_cached_group_nodes("campfires"):
		var campfire := campfire_value as Node2D
		if campfire == null or not is_instance_valid(campfire):
			continue
		if campfire.is_queued_for_deletion():
			continue
		markers.append({
			"position": campfire.global_position,
			"type": "campfire",
			"active": true
		})
	return markers


func _build_campfires_signature() -> String:
	var parts: Array[String] = []
	for campfire_value in cached_campfires:
		var campfire_marker := Dictionary(campfire_value)
		parts.append("%d:%d:%s" % [
			int(round(Vector2(campfire_marker.get("position", Vector2.ZERO)).x)),
			int(round(Vector2(campfire_marker.get("position", Vector2.ZERO)).y)),
			"1" if campfire_marker.get("active", true) == true else "0"
		])
	return "|".join(parts)


func _build_varnaks_signature() -> String:
	var parts: Array[String] = []
	for varnak_value in cached_varnaks:
		var varnak_marker := Dictionary(varnak_value)
		parts.append("%d:%d" % [
			int(round(Vector2(varnak_marker.get("position", Vector2.ZERO)).x)),
			int(round(Vector2(varnak_marker.get("position", Vector2.ZERO)).y))
		])
	return "|".join(parts)


func _get_safe_tree() -> SceneTree:
	if not is_inside_tree():
		return null
	return get_tree()


func _get_world() -> Node:
	if is_instance_valid(world):
		return world
	var tree := _get_safe_tree()
	if tree == null or tree.current_scene == null:
		return null
	world = tree.current_scene.get_node_or_null("World")
	return world


func _get_snapshot(force_refresh := false) -> Dictionary:
	if snapshot_service != null:
		if force_refresh and snapshot_service.has_method("refresh"):
			return snapshot_service.refresh(true)
		if snapshot_service.has_method("get_snapshot"):
			var snapshot: Dictionary = snapshot_service.get_snapshot()
			if snapshot.is_empty() and snapshot_service.has_method("refresh"):
				return snapshot_service.refresh(true)
			return snapshot
	return {}


func _build_resource_markers_from_world() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	var active_world := _get_world()
	if active_world == null or not active_world.has_method("get_registered_resources"):
		return markers
	for resource_value in active_world.get_registered_resources():
		var resource := resource_value as Node2D
		if resource == null or not is_instance_valid(resource):
			continue
		var resource_kind := str(resource.get("resource_kind"))
		if resource_kind in ["grass_patch", "dense_grass", "berry_bush"]:
			continue
		if resource.get("player_harvestable") == false:
			continue
		markers.append({
			"position": resource.global_position,
			"resource_kind": resource_kind,
			"item_name": str(resource.get("item_name"))
		})
	return markers


func _build_varnak_markers_from_world() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	var active_world := _get_world()
	if active_world == null or not active_world.has_method("get_registered_creatures_by_type"):
		return markers
	for varnak_value in active_world.get_registered_creatures_by_type("varnak"):
		var varnak := varnak_value as Node2D
		if varnak == null or not is_instance_valid(varnak):
			continue
		markers.append({"position": varnak.global_position, "type": "varnak"})
	return markers


func _get_registered_varnaks() -> Array:
	return cached_varnaks


func _to_dictionary_array(values: Array) -> Array[Dictionary]:
	var typed_values: Array[Dictionary] = []
	for value in values:
		if typeof(value) == TYPE_DICTIONARY:
			typed_values.append(Dictionary(value))
	return typed_values
