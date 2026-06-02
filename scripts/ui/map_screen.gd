extends Control

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const PADDING := 24.0
const PANEL_GAP := 20.0

var player: Node2D
var evolution_director: Node
var day_night_system: Node
var world_rect := WORLD_CONFIG.WORLD_RECT
var biome_zones: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func bind(p_player: Node2D, p_evolution_director: Node, p_day_night_system: Node, p_world_rect: Rect2, p_biome_zones: Array[Dictionary]) -> void:
	player = p_player
	evolution_director = p_evolution_director
	day_night_system = p_day_night_system
	world_rect = p_world_rect
	biome_zones = p_biome_zones
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
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
	_draw_resources(map_rect)
	_draw_varnaks(map_rect)
	_draw_player(map_rect)
	draw_rect(map_rect, Color(0.30, 0.36, 0.28, 0.85), false, 1.0)


func _draw_info_panel(rect: Rect2) -> void:
	draw_rect(rect, Color(0.04, 0.05, 0.05, 0.96), true)
	draw_rect(rect, Color(0.70, 0.74, 0.66, 0.78), false, 1.0)
	var profile: Dictionary = evolution_director.get_profile() if evolution_director else {}
	var live_varnaks := get_tree().get_nodes_in_group("varnak").size()
	var zone_name := _get_player_zone_name()
	var time_label := _get_time_label()
	var lines := [
		"Field Map",
		"",
		"Zone: %s" % zone_name,
		"Day: %d  Time: %s %s" % [day_night_system.get_day() if day_night_system else 1, _get_clock_time(), time_label],
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
	for biome in biome_zones:
		var map_points := PackedVector2Array()
		for point_value in biome["points"]:
			map_points.append(_world_to_map(Vector2(point_value), map_rect))
		draw_colored_polygon(map_points, Color(biome["color"]))
		_draw_polygon_outline(map_points, Color(0.04, 0.05, 0.04, 0.55), 2.0)


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


func _draw_polygon_outline(points: PackedVector2Array, color: Color, width: float) -> void:
	for i in points.size():
		draw_line(points[i], points[(i + 1) % points.size()], color, width)


func _world_to_map(world_position: Vector2, map_rect: Rect2) -> Vector2:
	var normalized := Vector2(
		inverse_lerp(world_rect.position.x, world_rect.end.x, world_position.x),
		inverse_lerp(world_rect.position.y, world_rect.end.y, world_position.y)
	)
	normalized.x = clamp(normalized.x, 0.0, 1.0)
	normalized.y = clamp(normalized.y, 0.0, 1.0)
	return map_rect.position + normalized * map_rect.size


func _get_player_zone_name() -> String:
	if not is_instance_valid(player):
		return "Unknown"
	for biome in biome_zones:
		if Geometry2D.is_point_in_polygon(player.global_position, PackedVector2Array(biome["points"])):
			return str(biome.get("name", "Unknown"))
	return "Wilderness"


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
		_:
			return Color(0.86, 0.78, 0.45)
