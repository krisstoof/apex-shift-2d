extends Node2D
class_name BiomeShapeRenderer

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")

var shape_map: RefCounted
var player: Node2D
var camera: Camera2D
var visible_rect := Rect2()
var redraw_count := 0
var drawn_polygon_count := 0
var drawn_detail_count := 0
var last_visible_signature := ""

func bind(assigned_shape_map: RefCounted, assigned_player: Node2D, assigned_camera: Camera2D) -> void:
	shape_map = assigned_shape_map
	player = assigned_player
	camera = assigned_camera
	visible_rect = _get_visible_world_rect()
	last_visible_signature = _rect_signature(visible_rect)
	queue_redraw()

func process_visibility(_delta: float) -> void:
	var rect := _get_visible_world_rect()
	var signature := _rect_signature(rect)
	if signature == last_visible_signature:
		return
	visible_rect = rect
	last_visible_signature = signature
	queue_redraw()

func get_debug_data() -> Dictionary:
	return {
		"biome_shape_renderer_enabled": visible,
		"biome_shape_renderer_redraw_count": redraw_count,
		"biome_shape_renderer_drawn_polygon_count": drawn_polygon_count,
		"biome_shape_renderer_drawn_detail_count": drawn_detail_count,
		"biome_shape_renderer_visible_rect": visible_rect,
		"biome_shape_renderer_last_visible_signature": last_visible_signature
	}

func clear_cache() -> void:
	queue_redraw()

func _draw() -> void:
	redraw_count += 1
	drawn_polygon_count = 0
	drawn_detail_count = 0
	if shape_map == null:
		return
	var polygons_by_layer: Dictionary = shape_map.get_polygons_by_layer()
	for layer_id in _get_layer_draw_order(polygons_by_layer):
		if not polygons_by_layer.has(layer_id):
			continue
		for polygon_value in Array(polygons_by_layer[layer_id]):
			var polygon := Dictionary(polygon_value)
			var points := PackedVector2Array(polygon.get("points", PackedVector2Array()))
			if points.size() < 3:
				continue
			if not _polygon_intersects_rect(points, visible_rect):
				continue
			draw_colored_polygon(points, _get_layer_color(str(polygon.get("biome_id", "")), str(polygon.get("terrain_id", "land"))))
			drawn_polygon_count += 1
	for detail_value in shape_map.get_details():
		var detail := Dictionary(detail_value)
		var pos := Vector2(detail.get("position", Vector2.ZERO))
		if not visible_rect.grow(float(GAME_BALANCE.BIOME_TEXTURES.get("biome_shape_detail_world_margin", 320.0))).has_point(pos):
			continue
		draw_circle(pos, 3.0, _get_detail_color(str(detail.get("biome_id", "")), str(detail.get("terrain_id", "land"))))
		drawn_detail_count += 1

func _get_layer_draw_order(polygons_by_layer: Dictionary) -> Array[String]:
	var ordered: Array[String] = [
		"terrain:deep_ocean",
		"terrain:shallow_water",
		"terrain:shore",
		"terrain:pond"
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
	other_layers.sort()
	ordered.append_array(biome_layers)
	ordered.append_array(other_layers)
	return ordered

func _polygon_intersects_rect(points: PackedVector2Array, rect: Rect2) -> bool:
	if points.is_empty():
		return false
	var bounds := _get_polygon_bounds(points)
	return bounds.intersects(rect)

func _get_polygon_bounds(points: PackedVector2Array) -> Rect2:
	var rect := Rect2(points[0], Vector2.ZERO)
	for point in points:
		rect = rect.expand(point)
	return rect

func _get_visible_world_rect() -> Rect2:
	if camera != null and is_instance_valid(camera):
		var viewport_size := get_viewport_rect().size
		var zoom := camera.zoom if camera.zoom != Vector2.ZERO else Vector2.ONE
		var safe_zoom := Vector2(maxf(absf(zoom.x), 0.01), maxf(absf(zoom.y), 0.01))
		var half_size := Vector2(viewport_size.x / safe_zoom.x, viewport_size.y / safe_zoom.y) * 0.5
		return Rect2(camera.global_position - half_size, half_size * 2.0).grow(float(GAME_BALANCE.BIOME_TEXTURES.get("biome_shape_detail_world_margin", 320.0)))
	if player != null and is_instance_valid(player):
		return Rect2(player.global_position - Vector2(640.0, 360.0), Vector2(1280.0, 720.0)).grow(320.0)
	if shape_map != null:
		return shape_map.world_rect
	return Rect2(Vector2.ZERO, Vector2.ONE)

func _rect_signature(rect: Rect2) -> String:
	return "%d,%d,%d,%d" % [
		int(floor(rect.position.x / 256.0)),
		int(floor(rect.position.y / 256.0)),
		int(ceil(rect.end.x / 256.0)),
		int(ceil(rect.end.y / 256.0))
	]

func _get_layer_color(biome_id: String, terrain_id: String) -> Color:
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
			return _get_biome_base_color(biome_id).lerp(Color(0.52, 0.47, 0.32), 0.38)
		"rocky_patch":
			return _get_biome_base_color(biome_id).lerp(Color(0.43, 0.41, 0.35), 0.42)
		"wetland":
			return _get_biome_base_color(biome_id).lerp(Color(0.16, 0.30, 0.18), 0.32)
		_:
			return _get_biome_base_color(biome_id)

func _get_detail_color(biome_id: String, terrain_id: String) -> Color:
	match terrain_id:
		"highland":
			return Color(0.64, 0.58, 0.36, 0.44)
		"rocky_patch":
			return Color(0.70, 0.66, 0.54, 0.50)
		"wetland":
			return Color(0.22, 0.42, 0.24, 0.46)
		_:
			return _get_biome_base_color(biome_id).lightened(0.18)

func _get_biome_base_color(biome_id: String) -> Color:
	match biome_id:
		"westwood":
			return Color(0.14, 0.32, 0.16)
		"stoneback_ridge":
			return Color(0.49, 0.45, 0.36)
		"hearth_meadow":
			return Color(0.39, 0.58, 0.25)
		"south_thicket":
			return Color(0.23, 0.42, 0.17)
		"redfang_wilds":
			return Color(0.48, 0.26, 0.18)
		_:
			return Color(0.32, 0.50, 0.24)
