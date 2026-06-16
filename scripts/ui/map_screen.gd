extends Control

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const PADDING := 24.0
const PANEL_GAP := 20.0
const BIOME_BLEND_TEXTURE_SIZE := Vector2i(192, 118)
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
const MAP_STATE_REFRESH_INTERVAL := 0.25
const MAP_REDRAW_POSITION_THRESHOLD := 16.0

var player: Node2D
var world: Node
var snapshot_service
var evolution_director: Node
var day_night_system: Node
var world_rect := WORLD_CONFIG.WORLD_RECT
var biome_zones: Array[Dictionary] = []
var landmarks: Array[Dictionary] = []
var biome_blend_texture: ImageTexture
var biome_blend_colors_key := ""
var shoreline_segments: Array[Dictionary] = []
var shoreline_segments_key := ""
var shoreline_segments_build_count := 0
var shoreline_segments_last_build_ms := 0.0
var map_screen_redraw_count: int = 0
var map_screen_cache_rebuild_count: int = 0
var map_screen_skipped_update_hidden_count: int = 0
var map_screen_texture_build_count: int = 0
var map_screen_texture_last_build_ms: float = 0.0
var _is_drawing_biomes := false
var cached_resources: Array[Dictionary] = []
var cached_campfires: Array[Dictionary] = []
var cached_varnaks: Array[Dictionary] = []
var cached_small_prey: Array[Dictionary] = []
var cached_grazers: Array[Dictionary] = []
var resources_cache_timer := 0.0
var map_state_refresh_timer := 0.0
var cached_resources_signature := ""
var cached_campfires_signature := ""
var cached_varnaks_signature := ""
var cached_small_prey_signature := ""
var cached_grazers_signature := ""
var landmarks_signature := ""
var last_map_player_position := Vector2.INF
var last_map_zoom := -1.0
var map_cache_dirty := true
var last_visible_render_state_key := ""
var last_render_state_key := ""
const RESOURCES_CACHE_INTERVAL := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	mark_map_cache_dirty()
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
	evolution_director = null
	day_night_system = null


func invalidate_map_surface_cache() -> void:
	biome_blend_texture = null
	biome_blend_colors_key = ""
	shoreline_segments.clear()
	shoreline_segments_key = ""
	landmarks_signature = ""
	mark_map_cache_dirty()


func bind(p_player: Node2D, p_evolution_director: Node, p_day_night_system: Node, p_world_rect: Rect2, p_biome_zones: Array[Dictionary], p_landmarks: Array[Dictionary] = [], p_snapshot_service = null) -> void:
	player = p_player
	world = _get_world()
	snapshot_service = p_snapshot_service
	evolution_director = p_evolution_director
	day_night_system = p_day_night_system
	world_rect = p_world_rect
	biome_zones = p_biome_zones
	landmarks = p_landmarks
	_sync_biome_texture()
	_sync_shoreline_overlay_cache()
	if _update_marker_cache():
		map_screen_cache_rebuild_count += 1
	_update_landmarks_signature()
	mark_map_cache_dirty()


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		map_screen_skipped_update_hidden_count += 1
		return
	_log_hitch(_delta, "MapScreen", {
		"texture_cached": biome_blend_texture != null,
		"build_count": map_screen_texture_build_count,
		"last_build_ms": snappedf(map_screen_texture_last_build_ms, 0.01)
	})
	_sync_biome_texture()
	_sync_shoreline_overlay_cache()
	var cache_changed := false
	resources_cache_timer += _delta
	if resources_cache_timer >= RESOURCES_CACHE_INTERVAL:
		resources_cache_timer = 0.0
		if _update_marker_cache():
			map_screen_cache_rebuild_count += 1
			cache_changed = true
		if _refresh_landmarks_from_world():
			map_screen_cache_rebuild_count += 1
			cache_changed = true
		if cache_changed:
			mark_map_cache_dirty()
	var current_player_position := _get_current_player_map_position()
	var current_map_zoom := _get_current_map_zoom()
	if _should_redraw_map(current_player_position, current_map_zoom):
		last_map_player_position = current_player_position
		last_map_zoom = current_map_zoom
		last_visible_render_state_key = _build_visible_render_state_key(current_player_position, current_map_zoom)
		map_cache_dirty = false
		queue_redraw()


func _draw() -> void:
	map_screen_redraw_count += 1
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
	_is_drawing_biomes = true
	_draw_biomes(map_rect)
	_is_drawing_biomes = false
	_draw_shoreline_overlay(map_rect)
	_draw_grid(map_rect)
	_draw_landmarks(map_rect)
	if _should_show_resource_markers():
		_draw_resources(map_rect)
	_draw_small_prey(map_rect)
	_draw_grazers(map_rect)
	_draw_campfires(map_rect)
	_draw_varnaks(map_rect)
	_draw_player(map_rect)
	_draw_map_legend(map_rect)
	draw_rect(map_rect, Color(0.30, 0.36, 0.28, 0.85), false, 1.0)


func _draw_info_panel(rect: Rect2) -> void:
	draw_rect(rect, Color(0.04, 0.05, 0.05, 0.96), true)
	draw_rect(rect, Color(0.70, 0.74, 0.66, 0.78), false, 1.0)
	var lines := _build_info_lines()
	_draw_lines(lines, rect.position + Vector2(16.0, 28.0), rect.size.x - 32.0)


func _build_info_lines() -> Array[String]:
	var snapshot := _get_snapshot()
	var evolution_snapshot := Dictionary(snapshot.get("evolution", {}))
	var profile: Dictionary = Dictionary(evolution_snapshot.get("profile", evolution_director.get_profile() if evolution_director else {}))
	var live_varnaks := int(Dictionary(snapshot.get("debug", {})).get("live_varnaks", cached_varnaks.size()))
	var world_snapshot := Dictionary(snapshot.get("world", {}))
	var player_snapshot := Dictionary(snapshot.get("player", {}))
	var time_snapshot := Dictionary(snapshot.get("time", {}))
	var active_world := _get_world()
	var zone_name := _get_player_zone_name()
	var terrain_zone := str(world_snapshot.get("current_terrain_zone", _get_player_topography_name()))
	var topography_zone := terrain_zone
	var biome_lookup_debug := Dictionary()
	if active_world != null and is_instance_valid(player) and active_world.has_method("get_biome_lookup_debug"):
		biome_lookup_debug = Dictionary(active_world.get_biome_lookup_debug(player.global_position))
		if active_world.has_method("get_topography_zone_at"):
			topography_zone = str(active_world.get_topography_zone_at(player.global_position))
		var world_biome_name := str(active_world.get_biome_name_at(player.global_position)) if active_world.has_method("get_biome_name_at") else ""
		if not world_biome_name.is_empty():
			zone_name = world_biome_name
		elif bool(biome_lookup_debug.get("world_rect_has_point", false)) == true:
			zone_name = "unknown (lookup error)"
	var time_label := str(time_snapshot.get("time_label", _get_time_label()))
	var generation_debug := Dictionary(world_snapshot.get("world_generation_debug", {}))
	var terrain := Dictionary(generation_debug.get("terrain", {}))
	var terrain_coverage := Dictionary(generation_debug.get("terrain_coverage", {}))
	var player_stats: Variant = player_snapshot if not player_snapshot.is_empty() else _get_player_stats()
	var player_inventory: Variant = Dictionary(player_snapshot.get("inventory", {}))
	if player_inventory.is_empty():
		player_inventory = _get_player_inventory()
	return [
		"Field Map",
		"",
		"Biome: %s" % zone_name,
		"Day: %d  Time: %s %s" % [int(time_snapshot.get("day", day_night_system.get_day() if day_night_system else 1)), str(time_snapshot.get("clock_time", _get_clock_time())), time_label],
		"Topography: terrain %s | pond %.2f | ridge %.2f" % [
			topography_zone,
			float(terrain_coverage.get("pond", 0.0)),
			float(terrain_coverage.get("highland", 0.0))
		],
		"Terrain counts: ocean %d | shore %d | pond %d | highland %d | land %d" % [
			int(terrain.get("deep_ocean", 0)) + int(terrain.get("shallow_water", 0)),
			int(terrain.get("shore", 0)),
			int(terrain.get("pond", 0)),
			int(terrain.get("highland", 0)),
			int(terrain.get("land", 0))
		],
		"Live Varnaks: %d" % live_varnaks,
		"",
		"Player",
		"Health: %3d" % _read_int_property(player_stats, "health"),
		"Hunger: %3d" % _read_int_property(player_stats, "hunger"),
		"Stamina: %3d" % _read_int_property(player_stats, "stamina"),
		"Rest: %3d  %s" % [_read_int_property(player_stats, "rest"), _read_condition_text(player_stats)],
		"",
		"Inventory",
		"Wood %d  Stone %d  Fiber %d" % [_read_inventory_amount(player_inventory, "wood"), _read_inventory_amount(player_inventory, "stone"), _read_inventory_amount(player_inventory, "fiber")],
		"Meat %d  Hide %d  Bone %d" % [_read_inventory_amount(player_inventory, "meat"), _read_inventory_amount(player_inventory, "hide"), _read_inventory_amount(player_inventory, "bone")],
		"",
		"Varnak Profile",
		"Generation: %d" % int(profile.get("generation", 1)),
		"Aggression: %.2f" % float(profile.get("aggression", 0.0)),
		"Fire fear: %.2f" % float(profile.get("fire_fear", 0.0)),
		"Trap awareness: %.2f" % float(profile.get("trap_awareness", 0.0)),
		"Pack: %.2f" % float(profile.get("pack_coordination", 0.0))
	]


func _get_player_topography_name() -> String:
	if not is_instance_valid(player):
		return "Unknown"
	var world := _get_world()
	if world and world.has_method("get_topography_zone_at"):
		return str(world.get_topography_zone_at(player.global_position))
	return "Unknown"


func _get_player_stats() -> Variant:
	if not is_instance_valid(player):
		return null
	return player.get("stats")


func _get_player_inventory() -> Variant:
	if not is_instance_valid(player):
		return null
	return player.get("inventory")


func _read_int_property(target: Variant, property_name: String) -> int:
	if target == null:
		return 0
	if typeof(target) == TYPE_DICTIONARY:
		return int(Dictionary(target).get(property_name, 0))
	return int(target.get(property_name))


func _read_condition_text(target: Variant) -> String:
	if target == null:
		return "unknown"
	if typeof(target) == TYPE_DICTIONARY:
		return str(Dictionary(target).get("condition_text", "unknown"))
	if not target.has_method("get_condition_text"):
		return "unknown"
	return str(target.get_condition_text())


func _read_inventory_amount(inventory: Variant, item_id: String) -> int:
	if inventory == null:
		return 0
	if typeof(inventory) == TYPE_DICTIONARY:
		return int(Dictionary(inventory).get(item_id, 0))
	if not inventory.has_method("get_amount"):
		return 0
	return int(inventory.get_amount(item_id))


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
	if not _is_drawing_biomes:
		return
	if biome_blend_texture:
		draw_texture_rect(biome_blend_texture, map_rect, false)


func _draw_shoreline_overlay(map_rect: Rect2) -> void:
	for segment_value in shoreline_segments:
		var segment := Dictionary(segment_value)
		draw_line(
			_world_to_map(Vector2(segment.get("from", Vector2.ZERO)), map_rect),
			_world_to_map(Vector2(segment.get("to", Vector2.ZERO)), map_rect),
			Color(0.90, 0.84, 0.58, 0.55),
			1.2
		)


func _draw_grid(map_rect: Rect2) -> void:
	var grid_color := Color(0.25, 0.30, 0.23, 0.48)
	for i in range(1, 6):
		var x := map_rect.position.x + map_rect.size.x * float(i) / 6.0
		var y := map_rect.position.y + map_rect.size.y * float(i) / 6.0
		draw_line(Vector2(x, map_rect.position.y), Vector2(x, map_rect.end.y), grid_color, 1.0)
		draw_line(Vector2(map_rect.position.x, y), Vector2(map_rect.end.x, y), grid_color, 1.0)


func _draw_resources(map_rect: Rect2) -> void:
	for resource_marker_value in cached_resources:
		var resource_marker := Dictionary(resource_marker_value)
		draw_circle(_world_to_map(Vector2(resource_marker.get("position", Vector2.ZERO)), map_rect), 3.0, _get_resource_color(resource_marker))


func _draw_small_prey(map_rect: Rect2) -> void:
	for marker_value in cached_small_prey:
		var marker := Dictionary(marker_value)
		draw_circle(_world_to_map(Vector2(marker.get("position", Vector2.ZERO)), map_rect), 2.2, Color(0.72, 0.86, 0.58, 0.78))


func _draw_campfires(map_rect: Rect2) -> void:
	for campfire_marker_value in cached_campfires:
		var campfire_marker := Dictionary(campfire_marker_value)
		var pos := _world_to_map(Vector2(campfire_marker.get("position", Vector2.ZERO)), map_rect)
		var active: bool = campfire_marker.get("active", true) == true
		var outer_color := Color(1.0, 0.46, 0.10) if active else Color(0.48, 0.36, 0.22)
		var inner_color := Color(1.0, 0.88, 0.28) if active else Color(0.68, 0.58, 0.42)
		draw_circle(pos, 5.5, outer_color)
		draw_circle(pos, 2.4, inner_color)


func _draw_grazers(map_rect: Rect2) -> void:
	for marker_value in cached_grazers:
		var marker := Dictionary(marker_value)
		draw_circle(_world_to_map(Vector2(marker.get("position", Vector2.ZERO)), map_rect), 3.2, Color(0.78, 0.70, 0.38, 0.86))


func _draw_landmarks(map_rect: Rect2) -> void:
	for landmark in landmarks:
		var landmark_type := str(landmark.get("type", ""))
		var center := _world_to_map(Vector2(landmark.get("position", Vector2.ZERO)), map_rect)
		var radius := _world_radius_to_map(float(landmark.get("radius", 80.0)), map_rect)
		match landmark_type:
			"pond":
				_draw_pond_marker(center, radius, landmark)
				_draw_landmark_label(center, _get_landmark_label(landmark), Color(0.68, 0.92, 1.0))
			"hill":
				_draw_hill_marker(center, radius, landmark)
				_draw_landmark_label(center, _get_landmark_label(landmark), Color(0.95, 0.86, 0.58))
			_:
				_draw_landmark_marker(center, radius, landmark)
				_draw_landmark_label(center, _get_landmark_label(landmark), Color(0.96, 0.86, 0.58))


func _draw_landmark_marker(center: Vector2, radius: float, _landmark: Dictionary) -> void:
	var marker_radius: float = clamp(radius, 6.0, 20.0)
	draw_circle(center, marker_radius * 0.72, Color(0.93, 0.84, 0.56, 0.92))
	draw_circle(center, marker_radius * 0.32, Color(0.20, 0.16, 0.10, 0.95))


func _refresh_landmarks_from_world() -> bool:
	var snapshot := _get_snapshot()
	var world_snapshot := Dictionary(snapshot.get("world", {}))
	var changed := false
	if not world_snapshot.is_empty():
		landmarks = Array(world_snapshot.get("landmarks", landmarks))
		changed = true
	var active_world := _get_world()
	if not changed and active_world and active_world.has_method("get_landmarks"):
		landmarks = active_world.get_landmarks()
		changed = true
	if changed:
		var signature := _build_landmarks_signature()
		changed = signature != landmarks_signature
		landmarks_signature = signature
	return changed


func mark_map_cache_dirty() -> void:
	map_cache_dirty = true
	last_visible_render_state_key = ""
	if is_visible_in_tree():
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		mark_map_cache_dirty()


func _draw_pond_marker(center: Vector2, radius: float, landmark: Dictionary) -> void:
	var marker_radius: float = clamp(radius, 8.0, 34.0)
	_draw_filled_pond_marker(center, marker_radius, landmark, 1.0, Color(0.08, 0.31, 0.43, 0.92))
	_draw_filled_pond_marker(center, marker_radius, landmark, 0.68, Color(0.15, 0.48, 0.56, 0.62))


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
	var pond_phase: float = _get_pond_shape_phase(landmark)
	var wave: float = (
		sin(angle * 2.0 + pond_phase) * 0.55
		+ sin(angle * 3.0 - pond_phase * 1.7) * 0.32
		+ sin(angle * 5.0 + pond_phase * 0.6) * 0.18
	) / 1.05
	return clamp(1.0 + wave * irregularity, 1.0 - irregularity * 1.25, 1.0 + irregularity * 1.25)


func _get_pond_shape_phase(landmark: Dictionary) -> float:
	var pond_id := str(landmark.get("id", "pond"))
	var phase_seed := 0
	for i in pond_id.length():
		phase_seed = (phase_seed + pond_id.unicode_at(i) * (i + 3)) % 997
	return float(phase_seed) / 997.0 * TAU


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


func _draw_hill_marker(center: Vector2, radius: float, landmark: Dictionary) -> void:
	var marker_radius: float = clamp(radius, 9.0, 38.0)
	_draw_filled_hill_marker(center + Vector2(marker_radius * 0.08, marker_radius * 0.10), marker_radius, landmark, 1.0, Color(0.12, 0.13, 0.08, 0.38))
	_draw_filled_hill_marker(center, marker_radius, landmark, 1.0, Color(0.36, 0.35, 0.22, 0.92))
	_draw_filled_hill_marker(center, marker_radius, landmark, 0.70, Color(0.47, 0.45, 0.27, 0.62))
	_draw_filled_hill_marker(center + Vector2(-marker_radius * 0.08, -marker_radius * 0.08), marker_radius, landmark, 0.38, Color(0.63, 0.60, 0.36, 0.56))
	draw_line(center + Vector2(-marker_radius * 0.44, -marker_radius * 0.08), center + Vector2(marker_radius * 0.24, -marker_radius * 0.18), Color(0.75, 0.72, 0.45, 0.62), 2.0)
	draw_line(center + Vector2(-marker_radius * 0.18, marker_radius * 0.20), center + Vector2(marker_radius * 0.46, marker_radius * 0.06), Color(0.14, 0.15, 0.09, 0.44), 2.0)


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
	var hill_phase: float = _get_hill_shape_phase(landmark)
	var wave: float = (
		sin(angle * 2.0 + hill_phase) * 0.50
		+ sin(angle * 4.0 - hill_phase * 1.35) * 0.28
		+ sin(angle * 6.0 + hill_phase * 0.4) * 0.16
	) / 0.94
	return clamp(1.0 + wave * irregularity, 1.0 - irregularity * 1.15, 1.0 + irregularity * 1.15)


func _get_hill_shape_phase(landmark: Dictionary) -> float:
	var hill_id := str(landmark.get("id", "hill"))
	var phase_seed := 0
	for i in hill_id.length():
		phase_seed = (phase_seed + hill_id.unicode_at(i) * (i + 5)) % 997
	return float(phase_seed) / 997.0 * TAU


func _get_hill_shape_sample_count() -> int:
	return max(16, int(GAME_BALANCE.LANDMARKS.get("hill_shape_sample_count", 40)))


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
	var legend_rect := Rect2(map_rect.position + Vector2(14.0, 14.0), Vector2(190.0, 236.0))
	draw_rect(legend_rect, Color(0.025, 0.032, 0.028, 0.78), true)
	draw_rect(legend_rect, Color(0.70, 0.74, 0.66, 0.34), false, 1.0)
	var font := get_theme_default_font()
	draw_string(font, legend_rect.position + Vector2(10.0, 20.0), "Legend", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.95, 0.92, 0.78))
	_draw_legend_entry(legend_rect.position + Vector2(12.0, 40.0), "Deep ocean", TERRAIN_ZONE_COLORS["deep_ocean"])
	_draw_legend_entry(legend_rect.position + Vector2(12.0, 60.0), "Shallow water", TERRAIN_ZONE_COLORS["shallow_water"])
	_draw_legend_entry(legend_rect.position + Vector2(12.0, 80.0), "Shore", TERRAIN_ZONE_COLORS["shore"])
	_draw_legend_entry(legend_rect.position + Vector2(12.0, 100.0), "Land", TERRAIN_ZONE_COLORS["land"])
	_draw_legend_entry(legend_rect.position + Vector2(12.0, 120.0), "Highland", TERRAIN_ZONE_COLORS["highland"])
	_draw_legend_entry(legend_rect.position + Vector2(12.0, 140.0), "Pond / wetland", Color(0.12, 0.47, 0.56))
	_draw_legend_entry(legend_rect.position + Vector2(12.0, 158.0), "Ridge / rocky", Color(0.48, 0.45, 0.28))
	_draw_legend_entry(legend_rect.position + Vector2(12.0, 176.0), "Pond landmark", Color(0.12, 0.47, 0.56))
	_draw_legend_entry(legend_rect.position + Vector2(12.0, 194.0), "Hill landmark", Color(0.58, 0.55, 0.32))
	_draw_legend_entry(legend_rect.position + Vector2(92.0, 176.0), "Varnak", Color(0.88, 0.22, 0.16))
	_draw_legend_entry(legend_rect.position + Vector2(92.0, 194.0), "Campfire", Color(1.0, 0.46, 0.10))
	if _should_show_resource_markers():
		_draw_legend_entry(legend_rect.position + Vector2(92.0, 158.0), "Resource", Color(0.67, 0.95, 0.34))


func _draw_legend_entry(legend_position: Vector2, label: String, color: Color) -> void:
	draw_circle(legend_position + Vector2(5.0, -4.0), 4.5, color)
	draw_string(get_theme_default_font(), legend_position + Vector2(16.0, 0.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.86, 0.88, 0.82))


func _draw_varnaks(map_rect: Rect2) -> void:
	for varnak_marker_value in cached_varnaks:
		var varnak_marker := Dictionary(varnak_marker_value)
		var pos := _world_to_map(Vector2(varnak_marker.get("position", Vector2.ZERO)), map_rect)
		draw_circle(pos, 5.0, Color(0.88, 0.22, 0.16))
		draw_circle(pos, 2.0, Color(1.0, 0.82, 0.42))


func _draw_player(map_rect: Rect2) -> void:
	if not is_instance_valid(player):
		return
	var pos := _world_to_map(player.global_position, map_rect)
	draw_circle(pos, 6.5, Color(0.17, 0.48, 1.0))
	draw_circle(pos, 3.0, Color.WHITE)


func _sync_biome_texture() -> void:
	var active_world := _get_world()
	if active_world != null and active_world.has_method("get_surface_texture"):
		biome_blend_texture = active_world.get_surface_texture()
		biome_blend_colors_key = str(active_world.get_surface_texture_key()) if active_world.has_method("get_surface_texture_key") else ""
		return
	if biome_zones.is_empty():
		biome_blend_texture = null
		biome_blend_colors_key = ""
		return
	_ensure_biome_texture()


func _sync_shoreline_overlay_cache() -> void:
	var active_world := _get_world()
	if active_world == null:
		shoreline_segments.clear()
		shoreline_segments_key = ""
		return
	var current_key := _get_biome_texture_key()
	if shoreline_segments_key == current_key and not shoreline_segments.is_empty():
		return
	var start_ms := Time.get_ticks_msec()
	shoreline_segments = _build_shoreline_segments(active_world)
	shoreline_segments_key = current_key
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
	map_screen_texture_build_count += 1
	map_screen_texture_last_build_ms = float(Time.get_ticks_msec() - build_start_ms)
	print("[MAP_SCREEN] surface texture build count=%d last_build_ms=%.2f key=%s" % [map_screen_texture_build_count, map_screen_texture_last_build_ms, current_key])


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
			return biome_color.lerp(terrain_color, 0.18)
		"land":
			return biome_color.lerp(terrain_color, 0.10)
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
	parts.append("map_surface_v4")
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


func _should_show_resource_markers() -> bool:
	var graphics_settings := get_node_or_null("/root/GraphicsSettings")
	if graphics_settings != null and graphics_settings.has_method("should_show_resource_markers_on_maps"):
		return graphics_settings.should_show_resource_markers_on_maps() == true
	return false


func _log_hitch(delta: float, system_name: String, flags: Dictionary = {}) -> void:
	if delta <= 0.1:
		return
	var flag_text := ""
	for key in flags.keys():
		if not flag_text.is_empty():
			flag_text += " "
		flag_text += "%s=%s" % [str(key), str(flags.get(key))]
	print("[HITCH] %s delta=%.3f %s" % [system_name, delta, flag_text])


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
	var active_world := _get_world()
	if active_world != null and active_world.has_method("get_biome_name_at"):
		var biome_name := str(active_world.get_biome_name_at(player.global_position))
		if not biome_name.is_empty():
			return biome_name
		if active_world.has_method("get_biome_lookup_debug") and bool(Dictionary(active_world.get_biome_lookup_debug(player.global_position)).get("world_rect_has_point", false)) == true:
			return "unknown (lookup error)"
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


func _get_resource_color(resource_marker: Dictionary) -> Color:
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
		cached_small_prey = _to_dictionary_array(Array(markers.get("small_prey", [])))
		cached_grazers = _to_dictionary_array(Array(markers.get("grazers", [])))
	else:
		cached_resources = _build_resource_markers_from_world()
		cached_campfires = _build_campfire_markers_from_world()
		cached_varnaks = _build_varnak_markers_from_world()
		cached_small_prey = _build_creature_markers_from_world("small_prey")
		cached_grazers = _build_creature_markers_from_world("grazer")
	var resource_signature := _build_resources_signature()
	var campfire_signature := _build_campfires_signature()
	var varnak_signature := _build_varnaks_signature()
	var small_prey_signature := _build_creature_signature(cached_small_prey)
	var grazer_signature := _build_creature_signature(cached_grazers)
	var changed := resource_signature != cached_resources_signature or campfire_signature != cached_campfires_signature or varnak_signature != cached_varnaks_signature or small_prey_signature != cached_small_prey_signature or grazer_signature != cached_grazers_signature
	cached_resources_signature = resource_signature
	cached_campfires_signature = campfire_signature
	cached_varnaks_signature = varnak_signature
	cached_small_prey_signature = small_prey_signature
	cached_grazers_signature = grazer_signature
	return changed


func _update_resources_cache() -> bool:
	return _update_marker_cache()


func _should_redraw_map(current_player_position: Vector2, current_zoom: float) -> bool:
	if map_cache_dirty:
		return true
	if last_visible_render_state_key.is_empty():
		return true
	if last_map_player_position == Vector2.INF:
		return true
	if not is_equal_approx(current_zoom, last_map_zoom):
		return true
	if current_player_position.distance_to(last_map_player_position) >= MAP_REDRAW_POSITION_THRESHOLD:
		return true
	var current_key := _build_visible_render_state_key(current_player_position, current_zoom)
	return current_key != last_visible_render_state_key


func _build_visible_render_state_key(current_player_position: Vector2, current_zoom: float) -> String:
	var quantized_player_position := Vector2(
		int(round(current_player_position.x / MAP_REDRAW_POSITION_THRESHOLD)),
		int(round(current_player_position.y / MAP_REDRAW_POSITION_THRESHOLD))
	)
	var profile: Dictionary = evolution_director.get_profile() if evolution_director and evolution_director.has_method("get_profile") else {}
	var live_varnaks := _get_registered_varnaks().size()
	var player_stats: Variant = _get_player_stats()
	var player_inventory: Variant = _get_player_inventory()
	var player_position_text := "%d:%d" % [int(quantized_player_position.x), int(quantized_player_position.y)]
	if not is_instance_valid(player):
		player_position_text = "none"
	return "|".join([
		"%d:%d" % [int(round(size.x)), int(round(size.y))],
		player_position_text,
		"%.2f" % current_zoom,
		"%d" % _read_int_property(player_stats, "health"),
		"%d" % _read_int_property(player_stats, "hunger"),
		"%d" % _read_int_property(player_stats, "stamina"),
		"%d" % _read_int_property(player_stats, "rest"),
		"%d" % _read_inventory_amount(player_inventory, "wood"),
		"%d" % _read_inventory_amount(player_inventory, "stone"),
		"%d" % _read_inventory_amount(player_inventory, "fiber"),
		"%d" % _read_inventory_amount(player_inventory, "meat"),
		"%d" % _read_inventory_amount(player_inventory, "hide"),
		"%d" % _read_inventory_amount(player_inventory, "bone"),
		_get_clock_time(),
		_get_time_label(),
		"%d" % (day_night_system.get_day() if day_night_system and day_night_system.has_method("get_day") else 1),
		"%d" % live_varnaks,
		"%d" % int(profile.get("generation", 1)),
		"%.2f" % float(profile.get("aggression", 0.0)),
		"%.2f" % float(profile.get("fire_fear", 0.0)),
		"%.2f" % float(profile.get("trap_awareness", 0.0)),
		"%.2f" % float(profile.get("pack_coordination", 0.0)),
		cached_resources_signature,
		cached_campfires_signature,
		cached_varnaks_signature,
		landmarks_signature
	])


func _get_current_player_map_position() -> Vector2:
	if is_instance_valid(player):
		return player.global_position
	return Vector2.ZERO


func _get_current_map_zoom() -> float:
	return 1.0


func _request_map_redraw(force := false) -> bool:
	var current_key := _build_render_state_key()
	if not force and current_key == last_render_state_key:
		return false
	last_render_state_key = current_key
	queue_redraw()
	return true


func _build_render_state_key() -> String:
	var profile: Dictionary = evolution_director.get_profile() if evolution_director and evolution_director.has_method("get_profile") else {}
	var live_varnaks := _get_registered_varnaks().size()
	var player_stats: Variant = _get_player_stats()
	var player_inventory: Variant = _get_player_inventory()
	var player_position_text := "none"
	if is_instance_valid(player):
		player_position_text = "%d:%d" % [int(round(player.global_position.x)), int(round(player.global_position.y))]
	return "|".join([
		"%d:%d" % [int(round(size.x)), int(round(size.y))],
		player_position_text,
		"%d" % _read_int_property(player_stats, "health"),
		"%d" % _read_int_property(player_stats, "hunger"),
		"%d" % _read_int_property(player_stats, "stamina"),
		"%d" % _read_int_property(player_stats, "rest"),
		"%d" % _read_inventory_amount(player_inventory, "wood"),
		"%d" % _read_inventory_amount(player_inventory, "stone"),
		"%d" % _read_inventory_amount(player_inventory, "fiber"),
		"%d" % _read_inventory_amount(player_inventory, "meat"),
		"%d" % _read_inventory_amount(player_inventory, "hide"),
		"%d" % _read_inventory_amount(player_inventory, "bone"),
		_get_clock_time(),
		_get_time_label(),
		"%d" % (day_night_system.get_day() if day_night_system and day_night_system.has_method("get_day") else 1),
		"%d" % live_varnaks,
		"%d" % int(profile.get("generation", 1)),
		"%.2f" % float(profile.get("aggression", 0.0)),
		"%.2f" % float(profile.get("fire_fear", 0.0)),
		"%.2f" % float(profile.get("trap_awareness", 0.0)),
		"%.2f" % float(profile.get("pack_coordination", 0.0)),
		cached_resources_signature,
		cached_campfires_signature,
		cached_varnaks_signature,
		landmarks_signature
	])


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


func _build_grazers_signature() -> String:
	return _build_creature_signature(cached_grazers)


func _build_small_prey_signature() -> String:
	return _build_creature_signature(cached_small_prey)


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


func _build_creature_markers_from_world(creature_type: String) -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	var active_world := _get_world()
	if active_world == null or not active_world.has_method("get_registered_creatures_by_type"):
		return markers
	for creature_value in active_world.get_registered_creatures_by_type(creature_type):
		var creature := creature_value as Node2D
		if creature == null or not is_instance_valid(creature) or creature.is_queued_for_deletion():
			continue
		markers.append({"position": creature.global_position, "type": creature_type})
	return markers


func _build_creature_signature(markers: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for marker_value in markers:
		var marker := Dictionary(marker_value)
		parts.append("%d:%d" % [
			int(round(Vector2(marker.get("position", Vector2.ZERO)).x)),
			int(round(Vector2(marker.get("position", Vector2.ZERO)).y))
		])
	return "|".join(parts)


func _should_show_resource_on_full_map(resource: Node, resource_kind: String) -> bool:
	if resource_kind in ["grass_patch", "dense_grass"]:
		return false
	if resource != null and resource.get("render_only") == true:
		return false
	if resource_kind == "berry_bush":
		return true
	if resource != null and resource.get("player_harvestable") == false:
		return false
	return true


func _update_landmarks_signature() -> bool:
	var parts: Array[String] = []
	for landmark in landmarks:
		parts.append("%s:%s:%d:%d:%d" % [
			str(landmark.get("id", "")),
			str(landmark.get("type", "")),
			int(round(Vector2(landmark.get("position", Vector2.ZERO)).x)),
			int(round(Vector2(landmark.get("position", Vector2.ZERO)).y)),
			int(round(float(landmark.get("radius", 0.0))))
		])
	var signature := "|".join(parts)
	var changed := signature != landmarks_signature
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


func _build_shoreline_segments(active_world: Node) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	if active_world == null:
		return segments
	var source_ponds: Array = []
	if active_world.has_method("get"):
		source_ponds = Array(active_world.get("pond_landmarks"))
	if source_ponds.is_empty() and active_world.has_method("get_pond_landmarks"):
		source_ponds = Array(active_world.get_pond_landmarks())
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
		var sample_count := max(16, int(GAME_BALANCE.LANDMARKS.get("pond_shore_detail_count", 18)))
		var last_point := Vector2.INF
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


func get_map_screen_performance_debug() -> Dictionary:
	return {
		"redraw_count": map_screen_redraw_count,
		"cache_rebuild_count": map_screen_cache_rebuild_count,
		"skipped_update_hidden_count": map_screen_skipped_update_hidden_count,
		"texture_build_count": map_screen_texture_build_count,
		"texture_last_build_ms": map_screen_texture_last_build_ms,
		"shoreline_build_count": shoreline_segments_build_count,
		"shoreline_last_build_ms": shoreline_segments_last_build_ms,
		"shoreline_segment_count": shoreline_segments.size()
	}


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


func _to_dictionary_array(values: Array) -> Array[Dictionary]:
	var typed_values: Array[Dictionary] = []
	for value in values:
		typed_values.append(Dictionary(value))
	return typed_values


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
		if not _should_show_resource_on_full_map(resource, resource_kind):
			continue
		markers.append({
			"position": resource.global_position,
			"resource_kind": resource_kind,
			"item_name": str(resource.get("item_name")),
			"player_harvestable": resource.get("player_harvestable") != false
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
