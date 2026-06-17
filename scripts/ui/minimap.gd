extends Control

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const PADDING := 14.0
const BIOME_BLEND_TEXTURE_SIZE := Vector2i(224, 136)
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
const MINIMAP_LABEL_HEIGHT := 30.0

var player: Node2D
var world: Node
var snapshot_service
var world_rect := WORLD_CONFIG.WORLD_RECT
var biome_zones: Array[Dictionary] = []
var landmarks: Array[Dictionary] = []
var biome_blend_texture: ImageTexture
var biome_blend_colors_key := ""
var biome_shape_map
var terrain_cell_map: TerrainCellMap
var shoreline_segments: Array[Dictionary] = []
var shoreline_segments_key := ""
var shoreline_segments_cache_valid := false
var shoreline_segments_build_count := 0
var shoreline_segments_last_build_ms := 0.0
var minimap_redraw_count: int = 0
var minimap_marker_cache_rebuild_count: int = 0
var minimap_landmark_cache_rebuild_count: int = 0
var minimap_texture_build_count: int = 0
var minimap_texture_last_build_ms: float = 0.0
var _is_drawing_biomes := false
var minimap_redraw_timer := 0.0
var minimap_static_redraw_timer := 0.0
var minimap_redraw_interval := 0.15
var minimap_marker_rebuild_interval := 0.25
var _marker_rebuild_timer := 0.0
var _redraw_timer := 0.0
var last_redraw_player_position := Vector2.INF
var last_redraw_player_biome_id := ""
var cached_resources: Array[Dictionary] = []
var cached_campfires: Array[Dictionary] = []
var cached_varnaks: Array[Dictionary] = []
var cached_grazers: Array[Dictionary] = []
var cached_resources_signature := ""
var cached_campfires_signature := ""
var cached_varnaks_signature := ""
var cached_grazers_signature := ""
var markers_cache_timer := 0.0
var landmarks_signature := ""
var _needs_redraw_due_to_data_change := true
var camera_world_size_override := Vector2.ZERO
var hitch_log_cooldowns: Dictionary = {}
var static_layer_control: Control
var dynamic_layer_control: Control
var static_layer_dirty := true
var static_layer_redraw_count := 0
var dynamic_layer_redraw_count := 0
var player_marker_redraw_count := 0
var static_cache_rebuild_count := 0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_minimap_layers()
	_update_marker_cache()


func _exit_tree() -> void:
	if is_instance_valid(static_layer_control):
		static_layer_control.queue_free()
	if is_instance_valid(dynamic_layer_control):
		dynamic_layer_control.queue_free()
	static_layer_control = null
	dynamic_layer_control = null
	biome_blend_texture = null
	cached_resources.clear()
	cached_campfires.clear()
	cached_varnaks.clear()
	landmarks.clear()
	biome_zones.clear()
	snapshot_service = null
	world = null
	player = null


func invalidate_map_surface_cache() -> void:
	biome_blend_texture = null
	biome_blend_colors_key = ""
	shoreline_segments.clear()
	shoreline_segments_key = ""
	shoreline_segments_cache_valid = false
	landmarks_signature = ""
	_mark_static_layer_dirty()


func bind(p_player: Node2D, p_world_rect: Rect2, p_biome_zones: Array[Dictionary], p_landmarks: Array[Dictionary] = [], p_snapshot_service = null) -> void:
	player = p_player
	world = _get_world()
	snapshot_service = p_snapshot_service
	world_rect = p_world_rect
	biome_zones = p_biome_zones
	landmarks = p_landmarks
	biome_shape_map = world.get_biome_shape_map() if world != null and world.has_method("get_biome_shape_map") else null
	terrain_cell_map = world.get_terrain_cell_map() if world != null and world.has_method("get_terrain_cell_map") else null
	_sync_biome_texture()
	_sync_shoreline_overlay_cache()
	if _update_marker_cache():
		minimap_marker_cache_rebuild_count += 1
	landmarks_signature = _build_landmarks_signature()
	shoreline_segments_cache_valid = false
	_needs_redraw_due_to_data_change = true
	last_redraw_player_position = Vector2.INF
	last_redraw_player_biome_id = ""
	minimap_redraw_timer = 0.0
	minimap_static_redraw_timer = 0.0
	_mark_static_layer_dirty()
	_request_dynamic_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_log_hitch(delta, "Minimap", {
		"texture_cached": biome_blend_texture != null,
		"build_count": minimap_texture_build_count,
		"last_build_ms": snappedf(minimap_texture_last_build_ms, 0.01)
	})
	_sync_biome_texture()
	_sync_shoreline_overlay_cache()
	var redraw_distance := maxf(float(GAME_BALANCE.BIOME_TEXTURES.get("minimap_redraw_on_player_move_distance", 24.0)), 0.0)
	var budget := Dictionary(_get_world_render_budget())
	minimap_redraw_interval = float(budget.get("minimap_redraw_interval", minimap_redraw_interval))
	minimap_marker_rebuild_interval = float(budget.get("minimap_marker_rebuild_interval", minimap_marker_rebuild_interval))
	var current_player_position := _get_player_position()
	var current_biome_id := _get_player_biome_id()
	var should_redraw := false
	if last_redraw_player_position == Vector2.INF:
		should_redraw = true
	elif current_player_position.distance_to(last_redraw_player_position) >= redraw_distance:
		should_redraw = true
	elif current_biome_id != last_redraw_player_biome_id:
		should_redraw = true
	if should_redraw:
		last_redraw_player_position = current_player_position
		last_redraw_player_biome_id = current_biome_id
		minimap_static_redraw_timer = 0.0
		minimap_redraw_timer = 0.0
		_needs_redraw_due_to_data_change = false
		_request_dynamic_redraw()
	else:
		minimap_static_redraw_timer += delta
		if minimap_static_redraw_timer >= maxf(minimap_redraw_interval, 0.1) and _needs_redraw_due_to_data_change:
			minimap_static_redraw_timer = 0.0
			minimap_redraw_timer = 0.0
			_needs_redraw_due_to_data_change = false
			_mark_static_layer_dirty()
			_request_dynamic_redraw()
	minimap_redraw_timer += delta
	_marker_rebuild_timer += delta
	if _marker_rebuild_timer >= minimap_marker_rebuild_interval:
		_marker_rebuild_timer = 0.0
		_refresh_static_caches()


func _draw() -> void:
	pass


func _draw_static_layer(target: CanvasItem) -> void:
	static_layer_redraw_count += 1
	var map_rect := Rect2(Vector2.ZERO, size)
	var content_rect := _get_content_rect(map_rect)
	var view_world_rect := _get_minimap_view_world_rect(content_rect)
	target.draw_rect(map_rect, Color(0.04, 0.05, 0.05, 0.86), true)
	target.draw_rect(map_rect, Color(0.74, 0.78, 0.68, 0.9), false, 1.0)
	target.draw_rect(content_rect, Color(0.11, 0.18, 0.11, 0.94), true)
	target.draw_rect(content_rect, Color(0.35, 0.43, 0.32, 0.8), false, 1.0)
	_draw_static_contents(target, content_rect, view_world_rect)


func _draw_dynamic_layer(target: CanvasItem) -> void:
	dynamic_layer_redraw_count += 1
	var map_rect := Rect2(Vector2.ZERO, size)
	var content_rect := _get_content_rect(map_rect)
	var view_world_rect := _get_minimap_view_world_rect(content_rect)
	_draw_resources(target, content_rect, view_world_rect)
	_draw_campfires(target, content_rect, view_world_rect)
	_draw_grazers(target, content_rect, view_world_rect)
	_draw_varnaks(target, content_rect, view_world_rect)
	_draw_player(target, content_rect, view_world_rect)
	_draw_zone_label(target, map_rect)


func _get_content_rect(map_rect: Rect2) -> Rect2:
	return Rect2(
		map_rect.position + Vector2(PADDING, PADDING),
		Vector2(
			maxf(map_rect.size.x - PADDING * 2.0, 1.0),
			maxf(map_rect.size.y - PADDING * 2.0 - MINIMAP_LABEL_HEIGHT, 1.0)
		)
	)


func _draw_static_contents(target: CanvasItem, content_rect: Rect2, view_world_rect: Rect2) -> void:
	_is_drawing_biomes = true
	_draw_biomes(target, content_rect, view_world_rect)
	_is_drawing_biomes = false
	_draw_shoreline_overlay(target, content_rect, view_world_rect)
	_draw_landmarks(target, content_rect, view_world_rect)
	if bool(GAME_BALANCE.BIOME_TEXTURES.get("minimap_draw_grid_overlay", false)):
		_draw_grid(target, content_rect, view_world_rect)


func _draw_biomes(target: CanvasItem, content_rect: Rect2, view_world_rect: Rect2) -> void:
	if not _is_drawing_biomes:
		return
	if biome_blend_texture:
		var visible_world_rect := world_rect.intersection(view_world_rect)
		if visible_world_rect.size.x <= 0.0 or visible_world_rect.size.y <= 0.0:
			return
		var destination_rect := _world_rect_to_map_rect(visible_world_rect, content_rect, view_world_rect)
		var source_rect := _world_rect_to_texture_region(visible_world_rect)
		if destination_rect.size.x <= 0.0 or destination_rect.size.y <= 0.0:
			return
		target.draw_texture_rect_region(biome_blend_texture, destination_rect, source_rect)
		return
	if terrain_cell_map != null and bool(GAME_BALANCE.BIOME_TEXTURES.get("minimap_draw_cell_map_fallback", true)):
		_draw_cell_map(target, content_rect, view_world_rect)
		return
	if biome_shape_map != null and biome_shape_map.has_method("get_sample_grid_size") and bool(GAME_BALANCE.BIOME_TEXTURES.get("minimap_draw_sample_grid_underlay", false)):
		_draw_shape_map_sample_grid(target, content_rect, view_world_rect)


func _draw_shoreline_overlay(target: CanvasItem, content_rect: Rect2, view_world_rect: Rect2) -> void:
	for segment_value in shoreline_segments:
		var segment := Dictionary(segment_value)
		var from := Vector2(segment.get("from", Vector2.ZERO))
		var to := Vector2(segment.get("to", Vector2.ZERO))
		if not view_world_rect.has_point(from) and not view_world_rect.has_point(to):
			continue
		target.draw_line(
			_world_to_map(from, content_rect, view_world_rect),
			_world_to_map(to, content_rect, view_world_rect),
			Color(0.88, 0.82, 0.56, 0.42),
			1.0
		)


func _refresh_static_caches() -> void:
	var landmarks_changed := _refresh_landmarks_from_world()
	var marker_cache_changed := _update_marker_cache()
	var shoreline_changed := false
	var current_shoreline_key := _get_biome_texture_key()
	if not shoreline_segments_cache_valid or shoreline_segments_key != current_shoreline_key:
		shoreline_changed = true
	if landmarks_changed:
		minimap_landmark_cache_rebuild_count += 1
	if marker_cache_changed:
		minimap_marker_cache_rebuild_count += 1
	if landmarks_changed or marker_cache_changed or shoreline_changed:
		_needs_redraw_due_to_data_change = true
		_mark_static_layer_dirty()


func _sync_biome_texture() -> void:
	var active_world := _get_world()
	biome_shape_map = active_world.get_biome_shape_map() if active_world != null and active_world.has_method("get_biome_shape_map") else null
	terrain_cell_map = active_world.get_terrain_cell_map() if active_world != null and active_world.has_method("get_terrain_cell_map") else null
	if active_world == null or biome_zones.is_empty():
		biome_blend_texture = null
		biome_blend_colors_key = ""
		return
	if active_world.has_method("get_surface_texture") and active_world.has_method("get_surface_texture_key"):
		var shared_texture: ImageTexture = active_world.get_surface_texture()
		if shared_texture != null:
			biome_blend_texture = shared_texture
			biome_blend_colors_key = str(active_world.get_surface_texture_key())
			return
	_ensure_biome_texture()


func _sync_shoreline_overlay_cache() -> void:
	var active_world := _get_world()
	if active_world == null:
		shoreline_segments.clear()
		shoreline_segments_key = ""
		shoreline_segments_cache_valid = false
		_needs_redraw_due_to_data_change = true
		return
	var current_key := _get_biome_texture_key()
	if shoreline_segments_cache_valid and shoreline_segments_key == current_key:
		return
	var start_ms := Time.get_ticks_msec()
	shoreline_segments = _build_shoreline_segments(active_world)
	shoreline_segments_key = current_key
	shoreline_segments_cache_valid = true
	_needs_redraw_due_to_data_change = true
	shoreline_segments_build_count += 1
	shoreline_segments_last_build_ms = float(Time.get_ticks_msec() - start_ms)


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
		colors.append(_get_biome_base_color(Dictionary(biome)))
	for y in range(BIOME_BLEND_TEXTURE_SIZE.y):
		for x in range(BIOME_BLEND_TEXTURE_SIZE.x):
			var uv := Vector2(
				(float(x) + 0.5) / float(BIOME_BLEND_TEXTURE_SIZE.x),
				(float(y) + 0.5) / float(BIOME_BLEND_TEXTURE_SIZE.y)
			)
			var world_position := world_rect.position + uv * world_rect.size
			image.set_pixel(x, y, _get_world_surface_color_at(world_position))
	biome_blend_texture = ImageTexture.create_from_image(image)
	biome_blend_colors_key = current_key
	minimap_texture_build_count += 1
	minimap_texture_last_build_ms = float(Time.get_ticks_msec() - build_start_ms)
	print("[MINIMAP] surface texture build count=%d last_build_ms=%.2f key=%s" % [minimap_texture_build_count, minimap_texture_last_build_ms, current_key])


func _get_world_surface_color_at(world_position: Vector2) -> Color:
	var active_world := _get_world()
	if active_world != null and active_world.has_method("get_map_surface_color_at"):
		return Color(active_world.get_map_surface_color_at(world_position))
	return Color.MAGENTA


func _get_biome_zone_points(zone: Dictionary) -> PackedVector2Array:
	if zone.has("points"):
		return PackedVector2Array(zone.get("points", []))
	return PackedVector2Array()


func _get_biome_zone_edge_distance(world_position: Vector2, zone: Dictionary, points: PackedVector2Array) -> float:
	if not points.is_empty():
		return _get_point_polygon_edge_distance(world_position, points)
	return INF


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
	var parts: Array[String] = []
	parts.append("map_surface_v5")
	parts.append("world_rect=%s" % str(world_rect))
	var active_world := _get_world()
	if active_world != null:
		if active_world.has_method("get_world_seed"):
			parts.append("seed=%d" % int(active_world.get_world_seed()))
		if active_world.has_method("get_map_surface_debug_key"):
			parts.append(str(active_world.get_map_surface_debug_key()))
	return "|".join(parts)


func _get_biome_base_color(biome: Dictionary) -> Color:
	if biome.has("color"):
		return Color(biome.get("color"))
	var biome_id := str(biome.get("id", ""))
	match biome_id:
		"westwood":
			return Color(0.26, 0.46, 0.22)
		"stoneback_ridge":
			return Color(0.48, 0.44, 0.36)
		"hearth_meadow":
			return Color(0.37, 0.55, 0.28)
		"south_thicket":
			return Color(0.25, 0.42, 0.24)
		"redfang_wilds":
			return Color(0.45, 0.28, 0.22)
		"shore":
			return Color(0.75, 0.70, 0.46)
		_:
			return Color(0.35, 0.48, 0.30)


func _draw_cell_map(target: CanvasItem, content_rect: Rect2, view_world_rect: Rect2) -> void:
	if terrain_cell_map == null:
		return
	var grid := terrain_cell_map.get_grid_size()
	if grid == Vector2i.ZERO:
		return
	for y in range(grid.y):
		for x in range(grid.x):
			var cell := terrain_cell_map.get_cell(x, y)
			if cell.is_empty():
				continue
			var cell_rect := terrain_cell_map.get_cell_world_rect(x, y)
			if not view_world_rect.intersects(cell_rect):
				continue
			var destination_rect := _world_rect_to_map_rect(cell_rect.intersection(view_world_rect), content_rect, view_world_rect)
			if destination_rect.size.x <= 0.0 or destination_rect.size.y <= 0.0:
				continue
			target.draw_rect(destination_rect, _get_cell_map_color(cell), true)


func _draw_shape_map(target: CanvasItem, content_rect: Rect2, view_world_rect: Rect2) -> void:
	if biome_shape_map == null:
		return
	var has_renderable_polygons: bool = biome_shape_map.has_method("has_renderable_polygons") and biome_shape_map.has_renderable_polygons()
	if has_renderable_polygons:
		target.draw_rect(content_rect, Color(0.06, 0.18, 0.36), true)
	else:
		if terrain_cell_map != null and terrain_cell_map.get_grid_size() != Vector2i.ZERO and bool(GAME_BALANCE.BIOME_TEXTURES.get("minimap_draw_cell_map_fallback", true)):
			_draw_cell_map(target, content_rect, view_world_rect)
		elif biome_shape_map.has_method("get_sample_grid_size") and bool(GAME_BALANCE.BIOME_TEXTURES.get("minimap_draw_sample_grid_underlay", false)):
			_draw_shape_map_sample_grid(target, content_rect, view_world_rect)
		else:
			target.draw_rect(content_rect, Color(0.06, 0.18, 0.36), true)
	var polygons_by_layer: Dictionary = biome_shape_map.get_polygons_by_layer()
	for layer_id in _get_shape_map_draw_order(polygons_by_layer):
		for polygon_value in Array(polygons_by_layer.get(layer_id, [])):
			var polygon := Dictionary(polygon_value)
			if str(polygon.get("terrain_id", "")) == "deep_ocean":
				continue
			var points := PackedVector2Array(polygon.get("points", PackedVector2Array()))
			if points.size() < 3:
				continue
			var bounds := _get_polygon_bounds(points)
			if not bounds.intersects(view_world_rect):
				continue
			var clipped := _clip_polygon_to_rect(points, view_world_rect)
			if clipped.size() < 3:
				continue
			var clipped_bounds := _get_polygon_bounds(clipped)
			var world_area := maxf(view_world_rect.size.x * view_world_rect.size.y, 1.0)
			var bounds_area := clipped_bounds.size.x * clipped_bounds.size.y
			if str(polygon.get("terrain_id", "land")) not in ["deep_ocean", "shallow_water"] and bounds_area / world_area > 0.85:
				continue
			var mapped := PackedVector2Array()
			for p in clipped:
				mapped.append(_world_to_map(p, content_rect, view_world_rect))
			mapped = _sanitize_polygon_points(mapped)
			if mapped.size() < 3 or not _is_polygon_triangulatable(mapped):
				continue
			target.draw_colored_polygon(mapped, _get_shape_map_color(str(polygon.get("biome_id", "")), str(polygon.get("terrain_id", "land"))))


func _draw_shape_map_sample_grid(target: CanvasItem, content_rect: Rect2, view_world_rect: Rect2) -> void:
	var grid_size: Vector2i = biome_shape_map.get_sample_grid_size()
	if grid_size == Vector2i.ZERO:
		target.draw_rect(content_rect, Color(0.06, 0.18, 0.36), true)
		return
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell_rect: Rect2 = biome_shape_map.get_sample_grid_cell_world_rect(x, y)
			if not view_world_rect.intersects(cell_rect):
				continue
			var clipped_rect := cell_rect.intersection(view_world_rect)
			var destination_rect := _world_rect_to_map_rect(clipped_rect, content_rect, view_world_rect)
			if destination_rect.size.x <= 0.0 or destination_rect.size.y <= 0.0:
				continue
			var cell := _get_world_surface_cell(cell_rect.get_center())
			if cell.is_empty():
				cell = Dictionary(biome_shape_map.get_sample_grid_cell(x, y))
			target.draw_rect(destination_rect, _get_shape_map_color(str(cell.get("biome_id", "")), str(cell.get("terrain_id", "deep_ocean"))), true)


func _get_world_surface_cell(world_position: Vector2) -> Dictionary:
	var active_world := _get_world()
	if active_world == null:
		return {}
	var terrain_id := ""
	var biome_id := ""
	if active_world.has_method("get_surface_terrain_zone_at"):
		terrain_id = str(active_world.get_surface_terrain_zone_at(world_position))
	elif active_world.has_method("get_topography_zone_at"):
		terrain_id = str(active_world.get_topography_zone_at(world_position))
	if active_world.has_method("get_visual_biome_id_at"):
		biome_id = str(active_world.get_visual_biome_id_at(world_position))
	elif active_world.has_method("get_biome_id_at"):
		biome_id = str(active_world.get_biome_id_at(world_position))
	if terrain_id.is_empty() and biome_id.is_empty():
		return {}
	return {
		"terrain_id": terrain_id if not terrain_id.is_empty() else "land",
		"biome_id": biome_id if not biome_id.is_empty() else "hearth_meadow"
	}


func _get_shape_map_draw_order(polygons_by_layer: Dictionary) -> Array[String]:
	var ordered: Array[String] = [
		"terrain:deep_ocean",
		"terrain:shallow_water",
		"terrain:shore"
	]
	var biome_layers: Array[String] = []
	var other_layers: Array[String] = []
	for layer_id in polygons_by_layer.keys():
		var layer := str(layer_id)
		if ordered.has(layer):
			continue
		if layer.begins_with("biome:") and layer.ends_with("|terrain:land"):
			biome_layers.append(layer)
		else:
			other_layers.append(layer)
	biome_layers.sort()
	var wetland_layers: Array[String] = []
	var rocky_layers: Array[String] = []
	var highland_layers: Array[String] = []
	var pond_layers: Array[String] = []
	var remaining_other: Array[String] = []
	for layer in other_layers:
		if layer.ends_with("|terrain:wetland"):
			wetland_layers.append(layer)
		elif layer.ends_with("|terrain:rocky_patch"):
			rocky_layers.append(layer)
		elif layer.ends_with("|terrain:highland"):
			highland_layers.append(layer)
		elif layer.ends_with("|terrain:pond") or layer == "terrain:pond":
			pond_layers.append(layer)
		else:
			remaining_other.append(layer)
	ordered.append_array(biome_layers)
	ordered.append_array(wetland_layers)
	ordered.append_array(rocky_layers)
	ordered.append_array(highland_layers)
	ordered.append_array(pond_layers)
	remaining_other.sort()
	ordered.append_array(remaining_other)
	return ordered


func _clip_polygon_to_rect(points: PackedVector2Array, clip_rect: Rect2) -> PackedVector2Array:
	var result := points
	result = _clip_polygon_against_edge(result, "left", clip_rect.position.x)
	result = _clip_polygon_against_edge(result, "right", clip_rect.end.x)
	result = _clip_polygon_against_edge(result, "top", clip_rect.position.y)
	result = _clip_polygon_against_edge(result, "bottom", clip_rect.end.y)
	return result


func _clip_polygon_against_edge(points: PackedVector2Array, edge: String, value: float) -> PackedVector2Array:
	if points.size() < 3:
		return PackedVector2Array()
	var output := PackedVector2Array()
	var previous := points[points.size() - 1]
	var previous_inside := _is_point_inside_clip_edge(previous, edge, value)
	for current in points:
		var current_inside := _is_point_inside_clip_edge(current, edge, value)
		if current_inside:
			if not previous_inside:
				output.append(_line_clip_intersection(previous, current, edge, value))
			output.append(current)
		elif previous_inside:
			output.append(_line_clip_intersection(previous, current, edge, value))
		previous = current
		previous_inside = current_inside
	return output


func _is_point_inside_clip_edge(point: Vector2, edge: String, value: float) -> bool:
	match edge:
		"left":
			return point.x >= value
		"right":
			return point.x <= value
		"top":
			return point.y >= value
		"bottom":
			return point.y <= value
	return true


func _line_clip_intersection(a: Vector2, b: Vector2, edge: String, value: float) -> Vector2:
	var delta := b - a
	match edge:
		"left", "right":
			var t := 0.0 if absf(delta.x) < 0.0001 else (value - a.x) / delta.x
			return a + delta * clampf(t, 0.0, 1.0)
		"top", "bottom":
			var t := 0.0 if absf(delta.y) < 0.0001 else (value - a.y) / delta.y
			return a + delta * clampf(t, 0.0, 1.0)
	return a


func _get_polygon_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var rect := Rect2(points[0], Vector2.ZERO)
	for p in points:
		rect = rect.expand(p)
	return rect


func _sanitize_polygon_points(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3:
		return PackedVector2Array()
	var sanitized := PackedVector2Array()
	var last := Vector2.INF
	for point in points:
		if last != Vector2.INF and point.distance_to(last) < 0.5:
			continue
		sanitized.append(point)
		last = point
	if sanitized.size() >= 3 and sanitized[0].distance_to(sanitized[sanitized.size() - 1]) < 0.5:
		sanitized.remove_at(sanitized.size() - 1)
	if sanitized.size() < 3:
		return PackedVector2Array()
	if absf(_polygon_area(sanitized)) < 1.0:
		return PackedVector2Array()
	return sanitized


func _polygon_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		area += a.x * b.y - b.x * a.y
	return absf(area) * 0.5


func _is_polygon_triangulatable(points: PackedVector2Array) -> bool:
	if points.size() < 3:
		return false
	var indices := Geometry2D.triangulate_polygon(points)
	return not indices.is_empty()


func _get_shape_map_color(biome_id: String, terrain_id: String) -> Color:
	match terrain_id:
		"deep_ocean":
			return Color(0.06, 0.18, 0.36)
		"shallow_water":
			return Color(0.10, 0.32, 0.52)
		"shore":
			return Color(0.70, 0.66, 0.43)
		"pond":
			return Color(0.07, 0.31, 0.43)
		"highland":
			return _get_biome_base_color({"id": biome_id}).lerp(Color(0.52, 0.47, 0.32), 0.38)
		"rocky_patch":
			return _get_biome_base_color({"id": biome_id}).lerp(Color(0.43, 0.41, 0.35), 0.42)
		"wetland":
			return _get_biome_base_color({"id": biome_id}).lerp(Color(0.16, 0.30, 0.18), 0.32)
		_:
			return _get_biome_base_color({"id": biome_id})


func _get_cell_map_color(cell: Dictionary) -> Color:
	var biome_id := str(cell.get("biome_id", "hearth_meadow"))
	var terrain_id := str(cell.get("terrain_id", "land"))
	var variant := int(cell.get("variant", 0))
	var color := _get_biome_base_color({"id": biome_id})
	match terrain_id:
		"highland":
			color = color.lerp(Color(0.52, 0.48, 0.34), 0.22)
		"pond":
			color = Color(0.12, 0.40, 0.52)
		"rocky_patch":
			color = color.lerp(Color(0.42, 0.40, 0.34), 0.30)
		"wetland":
			color = color.lerp(Color(0.18, 0.32, 0.18), 0.25)
	if variant % 2 == 0:
		color = color.lightened(0.03)
	return color


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


func _draw_grid(target: CanvasItem, content_rect: Rect2, view_world_rect: Rect2) -> void:
	var grid_color := Color(0.23, 0.31, 0.22, 0.55)
	var grid_step := 320.0
	var start_x: float = floorf(view_world_rect.position.x / grid_step) * grid_step
	while start_x <= view_world_rect.end.x:
		var from := _world_to_map(Vector2(start_x, view_world_rect.position.y), content_rect, view_world_rect)
		var to := _world_to_map(Vector2(start_x, view_world_rect.end.y), content_rect, view_world_rect)
		target.draw_line(from, to, grid_color, 1.0)
		start_x += grid_step
	var start_y: float = floorf(view_world_rect.position.y / grid_step) * grid_step
	while start_y <= view_world_rect.end.y:
		var from := _world_to_map(Vector2(view_world_rect.position.x, start_y), content_rect, view_world_rect)
		var to := _world_to_map(Vector2(view_world_rect.end.x, start_y), content_rect, view_world_rect)
		target.draw_line(from, to, grid_color, 1.0)
		start_y += grid_step


func _draw_landmarks(target: CanvasItem, content_rect: Rect2, view_world_rect: Rect2) -> void:
	for landmark in landmarks:
		var landmark_type := str(landmark.get("type", ""))
		if landmark_type in ["pond", "hill"] and not bool(GAME_BALANCE.BIOME_TEXTURES.get("draw_pond_hill_landmarks", false)):
			continue
		var world_position := Vector2(landmark.get("position", Vector2.ZERO))
		var radius_world := float(landmark.get("radius", 80.0))
		if not _intersects_view_circle(world_position, radius_world, view_world_rect):
			continue
		var center := _get_landmark_marker_center(world_position, content_rect, view_world_rect)
		var desired_radius := _world_radius_to_map(float(landmark.get("radius", 80.0)), content_rect)
		var radius := _get_landmark_marker_radius(center, desired_radius, content_rect, landmark)
		if radius < 2.0:
			continue
		match landmark_type:
			"pond":
				_draw_pond_marker(target, center, radius, landmark)
			"hill":
				_draw_hill_marker(target, center, radius, landmark)
			_:
				_draw_landmark_marker(target, center, radius, landmark)


func _draw_landmark_marker(target: CanvasItem, center: Vector2, radius: float, _landmark: Dictionary) -> void:
	var marker_radius: float = clamp(radius, 5.0, 14.0)
	target.draw_circle(center, marker_radius * 0.72, Color(0.93, 0.84, 0.56, 0.92))
	target.draw_circle(center, marker_radius * 0.32, Color(0.20, 0.16, 0.10, 0.95))


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


func _get_player_position() -> Vector2:
	if is_instance_valid(player):
		return player.global_position
	return world_rect.get_center()


func _get_player_biome_id() -> String:
	if not is_instance_valid(player):
		return ""
	var active_world := _get_world()
	if active_world == null:
		return ""
	if active_world.has_method("get_visual_biome_id_at"):
		return str(active_world.get_visual_biome_id_at(player.global_position))
	if active_world.has_method("get_biome_id_at"):
		return str(active_world.get_biome_id_at(player.global_position))
	return ""


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


func _build_shoreline_segments(active_world: Node) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	if active_world == null:
		return segments
	if not bool(GAME_BALANCE.BIOME_TEXTURES.get("draw_pond_hill_landmarks", false)):
		return segments
	var source_ponds: Array[Dictionary] = []
	if active_world.has_method("get"):
		source_ponds = _to_dictionary_array(Array(active_world.get("pond_landmarks")))
	if source_ponds.is_empty() and active_world.has_method("get_pond_landmarks"):
		source_ponds = _to_dictionary_array(Array(active_world.get_pond_landmarks()))
	for pond_value in source_ponds:
		var pond := Dictionary(pond_value)
		if pond.is_empty():
			continue
		if not _is_shoreline_pond(pond):
			continue
		var center := Vector2(pond.get("position", Vector2.ZERO))
		var radius := float(pond.get("radius", 0.0))
		if radius <= 0.0:
			continue
		var sample_count: int = max(16, int(GAME_BALANCE.LANDMARKS.get("pond_shore_detail_count", 18)))
		var last_point: Vector2 = Vector2.INF
		for i in range(sample_count + 1):
			var angle := TAU * float(i) / float(sample_count)
			var point := _get_pond_shape_position(pond, angle, _get_pond_shore_radius_factor())
			if last_point != Vector2.INF:
				segments.append({
					"from": last_point,
					"to": point
				})
			last_point = point
	return segments


func _is_shoreline_pond(pond: Dictionary) -> bool:
	return str(pond.get("type", "pond")) == "pond" or pond.has("radius")


func _get_pond_shore_radius_factor() -> float:
	return float(GAME_BALANCE.LANDMARKS.get("pond_shore_radius_factor", 1.12))


func _draw_pond_marker(target: CanvasItem, center: Vector2, radius: float, landmark: Dictionary) -> void:
	var marker_radius: float = clamp(radius, 7.0, 24.0)
	_draw_filled_pond_marker(target, center, marker_radius, landmark, 1.0, Color(0.10, 0.36, 0.48, 0.90))
	_draw_filled_pond_marker(target, center, marker_radius, landmark, 0.68, Color(0.16, 0.50, 0.58, 0.58))


func _draw_filled_pond_marker(target: CanvasItem, center: Vector2, radius: float, landmark: Dictionary, radius_factor: float, marker_color: Color) -> void:
	var points := PackedVector2Array()
	var sample_count := _get_pond_shape_sample_count()
	for i in range(sample_count):
		var angle := TAU * float(i) / float(sample_count)
		var shape_scale := _get_pond_shape_scale(landmark, angle)
		points.append(center + Vector2(
			cos(angle) * radius * radius_factor * shape_scale,
			sin(angle) * radius * POND_MARKER_Y_SCALE * radius_factor * shape_scale
		))
	target.draw_colored_polygon(points, marker_color)


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


func _get_pond_shape_position(landmark: Dictionary, angle: float, radius_factor: float) -> Vector2:
	var center := Vector2(landmark.get("position", Vector2.ZERO))
	var radius := float(landmark.get("radius", 0.0))
	var shape_scale := _get_pond_shape_scale(landmark, angle)
	return center + Vector2(
		cos(angle) * radius * radius_factor * shape_scale,
		sin(angle) * radius * POND_MARKER_Y_SCALE * radius_factor * shape_scale
	)


func _get_pond_shape_sample_count() -> int:
	return max(16, int(GAME_BALANCE.LANDMARKS.get("pond_shape_sample_count", 48)))


func _draw_hill_marker(target: CanvasItem, center: Vector2, radius: float, landmark: Dictionary) -> void:
	var marker_radius: float = clamp(radius, 8.0, 25.0)
	_draw_filled_hill_marker(target, center + Vector2(marker_radius * 0.08, marker_radius * 0.10), marker_radius, landmark, 1.0, Color(0.12, 0.13, 0.08, 0.38))
	_draw_filled_hill_marker(target, center, marker_radius, landmark, 1.0, Color(0.38, 0.36, 0.22, 0.90))
	_draw_filled_hill_marker(target, center + Vector2(-marker_radius * 0.08, -marker_radius * 0.08), marker_radius, landmark, 0.56, Color(0.58, 0.55, 0.32, 0.58))
	target.draw_line(center + Vector2(-marker_radius * 0.42, -marker_radius * 0.08), center + Vector2(marker_radius * 0.22, -marker_radius * 0.16), Color(0.72, 0.69, 0.43, 0.58), 1.2)
	target.draw_line(center + Vector2(-marker_radius * 0.18, marker_radius * 0.18), center + Vector2(marker_radius * 0.42, marker_radius * 0.06), Color(0.15, 0.16, 0.09, 0.42), 1.2)


func _draw_filled_hill_marker(target: CanvasItem, center: Vector2, radius: float, landmark: Dictionary, radius_factor: float, marker_color: Color) -> void:
	var points := PackedVector2Array()
	var sample_count := _get_hill_shape_sample_count()
	for i in range(sample_count):
		var angle := TAU * float(i) / float(sample_count)
		var shape_scale := _get_hill_shape_scale(landmark, angle)
		points.append(center + Vector2(
			cos(angle) * radius * radius_factor * shape_scale,
			sin(angle) * radius * HILL_MARKER_Y_SCALE * radius_factor * shape_scale
		))
	target.draw_colored_polygon(points, marker_color)


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


func _draw_filled_ellipse(target: CanvasItem, rect: Rect2, ellipse_color: Color) -> void:
	var points := PackedVector2Array()
	var center := rect.get_center()
	var radii := rect.size * 0.5
	for i in range(20):
		var angle := TAU * float(i) / 20.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	target.draw_colored_polygon(points, ellipse_color)


func _draw_resources(target: CanvasItem, content_rect: Rect2, view_world_rect: Rect2) -> void:
	for resource_marker_value in cached_resources:
		var resource_marker := Dictionary(resource_marker_value)
		var marker_position := Vector2(resource_marker.get("position", Vector2.ZERO))
		if not view_world_rect.has_point(marker_position):
			continue
		var color := _get_resource_marker_color(resource_marker)
		target.draw_circle(_world_to_map(marker_position, content_rect, view_world_rect), 3.3, color)


func _draw_campfires(target: CanvasItem, content_rect: Rect2, view_world_rect: Rect2) -> void:
	for campfire_marker_value in cached_campfires:
		var campfire_marker := Dictionary(campfire_marker_value)
		var marker_position := Vector2(campfire_marker.get("position", Vector2.ZERO))
		if not view_world_rect.has_point(marker_position):
			continue
		var pos := _world_to_map(marker_position, content_rect, view_world_rect)
		var active: bool = campfire_marker.get("active", true) == true
		var outer_color := Color(1.0, 0.46, 0.10) if active else Color(0.48, 0.36, 0.22)
		var inner_color := Color(1.0, 0.88, 0.28) if active else Color(0.68, 0.58, 0.42)
		target.draw_circle(pos, 5.0, outer_color)
		target.draw_circle(pos, 2.2, inner_color)


func _draw_varnaks(target: CanvasItem, content_rect: Rect2, view_world_rect: Rect2) -> void:
	for varnak_marker_value in cached_varnaks:
		var varnak_marker := Dictionary(varnak_marker_value)
		var marker_position := Vector2(varnak_marker.get("position", Vector2.ZERO))
		if not view_world_rect.has_point(marker_position):
			continue
		var pos := _world_to_map(marker_position, content_rect, view_world_rect)
		target.draw_circle(pos, 5.2, Color(0.88, 0.22, 0.16))
		target.draw_circle(pos, 2.2, Color(1.0, 0.82, 0.42))


func _draw_grazers(target: CanvasItem, content_rect: Rect2, view_world_rect: Rect2) -> void:
	for grazer_marker_value in cached_grazers:
		var grazer_marker := Dictionary(grazer_marker_value)
		var marker_position := Vector2(grazer_marker.get("position", Vector2.ZERO))
		if not view_world_rect.has_point(marker_position):
			continue
		target.draw_circle(_world_to_map(marker_position, content_rect, view_world_rect), 2.8, Color(0.78, 0.72, 0.42, 0.85))


func _draw_player(target: CanvasItem, content_rect: Rect2, view_world_rect: Rect2) -> void:
	if not is_instance_valid(player):
		return
	player_marker_redraw_count += 1
	var pos := _world_to_map(player.global_position, content_rect, view_world_rect)
	target.draw_circle(pos, 6.4, Color(0.17, 0.48, 1.0))
	target.draw_circle(pos, 3.0, Color.WHITE)


func _draw_zone_label(target: CanvasItem, map_rect: Rect2) -> void:
	var label_rect := Rect2(
		map_rect.position.x + PADDING,
		map_rect.end.y - PADDING - MINIMAP_LABEL_HEIGHT,
		map_rect.size.x - PADDING * 2.0,
		MINIMAP_LABEL_HEIGHT
	)
	target.draw_rect(label_rect, Color(0.03, 0.04, 0.04, 0.88), true)
	target.draw_line(label_rect.position, label_rect.position + Vector2(label_rect.size.x, 0.0), Color(0.74, 0.78, 0.68, 0.55), 1.0)
	target.draw_string(get_theme_default_font(), label_rect.position + Vector2(10.0, 21.0), "Zone: %s" % _get_player_zone_name(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.90, 0.92, 0.84))


func _get_player_zone_name() -> String:
	if not is_instance_valid(player):
		return "Unknown"
	var active_world := _get_world()
	if active_world != null:
		var biome_name := ""
		if active_world.has_method("get_display_biome_name_at"):
			biome_name = str(active_world.get_display_biome_name_at(player.global_position))
		elif active_world.has_method("get_visual_biome_name_at"):
			biome_name = str(active_world.get_visual_biome_name_at(player.global_position))
		elif active_world.has_method("get_biome_name_at"):
			biome_name = str(active_world.get_biome_name_at(player.global_position))
		if not biome_name.is_empty():
			return biome_name
		if active_world.has_method("get_biome_lookup_debug") and bool(Dictionary(active_world.get_biome_lookup_debug(player.global_position)).get("world_rect_has_point", false)) == true:
			return "unknown (lookup error)"
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
	var safe_zoom := Vector2(
		maxf(absf(zoom.x), 0.01),
		maxf(absf(zoom.y), 0.01)
	)
	return Vector2(
		maxf(viewport_size.x / safe_zoom.x, 1.0),
		maxf(viewport_size.y / safe_zoom.y, 1.0)
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
	var texture_size := _get_active_biome_texture_size()
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


func _get_active_biome_texture_size() -> Vector2:
	if biome_blend_texture != null:
		var actual_size: Vector2i = biome_blend_texture.get_size()
		if actual_size.x > 0 and actual_size.y > 0:
			return Vector2(actual_size)
	return Vector2(float(BIOME_BLEND_TEXTURE_SIZE.x), float(BIOME_BLEND_TEXTURE_SIZE.y))


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
		cached_grazers = _to_dictionary_array(Array(markers.get("grazers", [])))
	else:
		cached_resources = _build_resource_markers_from_world()
		cached_campfires = _build_campfire_markers_from_world()
		cached_varnaks = _build_varnak_markers_from_world()
		cached_grazers = _build_grazer_markers_from_world()
	var resource_signature := _build_resources_signature()
	var campfire_signature := _build_campfires_signature()
	var varnak_signature := _build_varnaks_signature()
	var grazer_signature := _build_grazers_signature()
	var changed := resource_signature != cached_resources_signature or campfire_signature != cached_campfires_signature or varnak_signature != cached_varnaks_signature or grazer_signature != cached_grazers_signature
	cached_resources_signature = resource_signature
	cached_campfires_signature = campfire_signature
	cached_varnaks_signature = varnak_signature
	cached_grazers_signature = grazer_signature
	return changed


func _ensure_minimap_layers() -> void:
	if not is_instance_valid(static_layer_control):
		static_layer_control = _MinimapStaticLayer.new()
		static_layer_control.name = "MinimapStaticLayer"
		add_child(static_layer_control)
	if not is_instance_valid(dynamic_layer_control):
		dynamic_layer_control = _MinimapDynamicLayer.new()
		dynamic_layer_control.name = "MinimapDynamicLayer"
		add_child(dynamic_layer_control)
	_mark_static_layer_dirty()
	_request_dynamic_redraw()


func _mark_static_layer_dirty() -> void:
	static_layer_dirty = true
	if is_instance_valid(static_layer_control):
		static_layer_control.queue_redraw()


func _request_dynamic_redraw() -> void:
	if is_instance_valid(dynamic_layer_control):
		dynamic_layer_control.queue_redraw()


class _MinimapStaticLayer:
	extends Control

	var minimap: Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		minimap = get_parent() as Control

	func _draw() -> void:
		if minimap == null or not is_instance_valid(minimap):
			return
		minimap.static_layer_redraw_count += 1
		var map_rect: Rect2 = Rect2(Vector2.ZERO, minimap.size)
		var content_rect: Rect2 = minimap._get_content_rect(map_rect)
		var view_world_rect: Rect2 = minimap._get_minimap_view_world_rect(content_rect)
		draw_rect(map_rect, Color(0.04, 0.05, 0.05, 0.86), true)
		draw_rect(map_rect, Color(0.74, 0.78, 0.68, 0.9), false, 1.0)
		draw_rect(content_rect, Color(0.11, 0.18, 0.11, 0.94), true)
		draw_rect(content_rect, Color(0.35, 0.43, 0.32, 0.8), false, 1.0)
		minimap._draw_static_contents(self, content_rect, view_world_rect)
		minimap.static_layer_dirty = false


class _MinimapDynamicLayer:
	extends Control

	var minimap: Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		minimap = get_parent() as Control

	func _draw() -> void:
		if minimap == null or not is_instance_valid(minimap):
			return
		minimap.dynamic_layer_redraw_count += 1
		var map_rect: Rect2 = Rect2(Vector2.ZERO, minimap.size)
		var content_rect: Rect2 = minimap._get_content_rect(map_rect)
		var view_world_rect: Rect2 = minimap._get_minimap_view_world_rect(content_rect)
		minimap._draw_resources(self, content_rect, view_world_rect)
		minimap._draw_campfires(self, content_rect, view_world_rect)
		minimap._draw_grazers(self, content_rect, view_world_rect)
		minimap._draw_varnaks(self, content_rect, view_world_rect)
		minimap._draw_player(self, content_rect, view_world_rect)
		minimap._draw_zone_label(self, map_rect)



func get_minimap_performance_debug() -> Dictionary:
	return {
		"redraw_count": minimap_redraw_count,
		"marker_cache_rebuild_count": minimap_marker_cache_rebuild_count,
		"landmark_cache_rebuild_count": minimap_landmark_cache_rebuild_count,
		"texture_build_count": minimap_texture_build_count,
		"texture_last_build_ms": minimap_texture_last_build_ms,
		"shoreline_build_count": shoreline_segments_build_count,
		"shoreline_last_build_ms": shoreline_segments_last_build_ms,
		"shoreline_segment_count": shoreline_segments.size(),
		"minimap_redraw_interval": minimap_redraw_interval,
		"minimap_marker_rebuild_interval": minimap_marker_rebuild_interval,
		"minimap_shape_polygons_clipped": true
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


func _build_grazers_signature() -> String:
	var parts: Array[String] = []
	for grazer_value in cached_grazers:
		var grazer_marker := Dictionary(grazer_value)
		parts.append("%d:%d" % [
			int(round(Vector2(grazer_marker.get("position", Vector2.ZERO)).x)),
			int(round(Vector2(grazer_marker.get("position", Vector2.ZERO)).y))
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
		if not _should_show_resource_on_minimap(resource, resource_kind):
			continue
		markers.append({
			"position": resource.global_position,
			"resource_kind": resource_kind,
			"item_name": str(resource.get("item_name"))
		})
	return markers


func _should_show_resource_on_minimap(resource: Node, resource_kind: String) -> bool:
	if resource_kind in ["grass_patch", "dense_grass", "berry_bush"]:
		return false
	if resource != null and resource.get("player_harvestable") == false:
		return false
	return true


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


func _build_grazer_markers_from_world() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	var active_world := _get_world()
	if active_world == null or not active_world.has_method("get_registered_creatures_by_type"):
		return markers
	for grazer_value in active_world.get_registered_creatures_by_type("grazer"):
		var grazer := grazer_value as Node2D
		if grazer == null or not is_instance_valid(grazer) or grazer.is_queued_for_deletion():
			continue
		markers.append({"position": grazer.global_position, "type": "grazer"})
	return markers


func _get_registered_varnaks() -> Array:
	return cached_varnaks


func _to_dictionary_array(values: Array) -> Array[Dictionary]:
	var typed_values: Array[Dictionary] = []
	for value in values:
		if typeof(value) == TYPE_DICTIONARY:
			typed_values.append(Dictionary(value))
	return typed_values


func _get_world_render_budget() -> Dictionary:
	var active_world := _get_world()
	if active_world != null and active_world.has_method("get_render_budget_debug"):
		return Dictionary(active_world.get_render_budget_debug())
	return Dictionary(GAME_BALANCE.RENDER_PERFORMANCE.get("normal", {}))
