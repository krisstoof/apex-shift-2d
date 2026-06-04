extends Node

const OUTPUT_DIR := "res://assets/textures/biomes"
const TEXTURE_SIZE := 256
const CELL_SIZE := 16
const CELLS_PER_AXIS := TEXTURE_SIZE / CELL_SIZE

const BIOME_SPECS := {
	"westwood": {
		"file_name": "westwood_sample.png",
		"base": Color(0.12, 0.23, 0.12),
		"mid": Color(0.18, 0.30, 0.16),
		"accent": Color(0.28, 0.19, 0.12),
		"light": Color(0.34, 0.30, 0.18),
		"dark": Color(0.07, 0.11, 0.06),
		"mode": "forest_floor"
	},
	"stoneback_ridge": {
		"file_name": "stoneback_ridge_sample.png",
		"base": Color(0.22, 0.24, 0.22),
		"mid": Color(0.31, 0.30, 0.28),
		"accent": Color(0.42, 0.39, 0.36),
		"light": Color(0.55, 0.53, 0.49),
		"dark": Color(0.11, 0.12, 0.11),
		"mode": "rock"
	},
	"hearth_meadow": {
		"file_name": "hearth_meadow_sample.png",
		"base": Color(0.14, 0.28, 0.13),
		"mid": Color(0.18, 0.35, 0.16),
		"accent": Color(0.30, 0.51, 0.17),
		"light": Color(0.43, 0.66, 0.24),
		"dark": Color(0.07, 0.15, 0.06),
		"mode": "grass"
	},
	"south_thicket": {
		"file_name": "south_thicket_sample.png",
		"base": Color(0.12, 0.26, 0.10),
		"mid": Color(0.17, 0.35, 0.13),
		"accent": Color(0.26, 0.47, 0.17),
		"light": Color(0.39, 0.61, 0.22),
		"dark": Color(0.06, 0.13, 0.05),
		"mode": "thicket"
	},
	"redfang_wilds": {
		"file_name": "redfang_wilds_sample.png",
		"base": Color(0.26, 0.18, 0.13),
		"mid": Color(0.37, 0.24, 0.16),
		"accent": Color(0.48, 0.32, 0.21),
		"light": Color(0.60, 0.43, 0.29),
		"dark": Color(0.13, 0.08, 0.05),
		"mode": "cracked_earth"
	}
}


func _ready() -> void:
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_dir)
	for biome_id in BIOME_SPECS.keys():
		var spec: Dictionary = BIOME_SPECS[biome_id]
		var image := _generate_biome_texture(biome_id, spec)
		var file_path := output_dir.path_join(str(spec["file_name"]))
		var err := image.save_png(file_path)
		if err != OK:
			push_error("Failed to save %s: %s" % [file_path, error_string(err)])
		else:
			print("Generated %s" % file_path)
	get_tree().quit()


func _generate_biome_texture(biome_id: String, spec: Dictionary) -> Image:
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(spec["base"]))
	for cell_y in range(CELLS_PER_AXIS):
		for cell_x in range(CELLS_PER_AXIS):
			_draw_texture_cell(image, biome_id, spec, cell_x, cell_y)
	return image


func _draw_texture_cell(image: Image, biome_id: String, spec: Dictionary, cell_x: int, cell_y: int) -> void:
	var cell_seed := _get_cell_seed(biome_id, cell_x, cell_y)
	var rng := RandomNumberGenerator.new()
	rng.seed = cell_seed
	var cell_origin := Vector2i(cell_x * CELL_SIZE, cell_y * CELL_SIZE)
	var margin := 4
	var inner_min := cell_origin + Vector2i(margin, margin)
	var inner_max := cell_origin + Vector2i(CELL_SIZE - margin, CELL_SIZE - margin)
	_fill_rect(image, Rect2i(cell_origin, Vector2i(CELL_SIZE, CELL_SIZE)), _tint_color(Color(spec["base"]), rng.randf_range(-0.04, 0.04)))
	match str(spec["mode"]):
		"rock":
			_draw_rock_cell(image, spec, rng, inner_min, inner_max)
		"grass":
			_draw_grass_cell(image, spec, rng, inner_min, inner_max)
		"thicket":
			_draw_thicket_cell(image, spec, rng, inner_min, inner_max)
		"forest_floor":
			_draw_forest_cell(image, spec, rng, inner_min, inner_max)
		"cracked_earth":
			_draw_cracked_earth_cell(image, spec, rng, inner_min, inner_max)
		_:
			_draw_forest_cell(image, spec, rng, inner_min, inner_max)


func _draw_cracked_earth_cell(image: Image, spec: Dictionary, rng: RandomNumberGenerator, inner_min: Vector2i, inner_max: Vector2i) -> void:
	var center := Vector2(
		rng.randf_range(float(inner_min.x + 4), float(inner_max.x - 4)),
		rng.randf_range(float(inner_min.y + 4), float(inner_max.y - 4))
	)
	var plate := _make_jagged_polygon(center, rng, 0.42, 0.30, 7, 0.22)
	var plate_color := _tint_color(Color(spec["mid"]), rng.randf_range(-0.03, 0.05))
	_fill_polygon(image, plate, plate_color)
	_draw_polygon_outline(image, plate, Color(spec["dark"]), 1)
	var highlight := _offset_polygon(plate, Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0)))
	_fill_polygon(image, highlight, Color(spec["accent"]).lerp(Color(spec["light"]), 0.30).lerp(plate_color, 0.35))
	_draw_polygon_outline(image, highlight, Color(spec["dark"]).lerp(Color(spec["accent"]), 0.25), 1)
	var crack_count := 2 + rng.randi_range(0, 2)
	for i in range(crack_count):
		var start := center + Vector2(rng.randf_range(-7.0, 7.0), rng.randf_range(-4.0, 4.0))
		var end := center + Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-10.0, 10.0))
		_draw_line(image, start, end, Color(spec["dark"]).darkened(0.08), 2.0)
	var pebble_count := 1 + rng.randi_range(0, 2)
	for i in range(pebble_count):
		var pebble_center := center + Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-10.0, 10.0))
		_draw_disc(image, pebble_center, rng.randf_range(1.0, 2.4), Color(spec["dark"]).lightened(0.25))


func _draw_rock_cell(image: Image, spec: Dictionary, rng: RandomNumberGenerator, inner_min: Vector2i, inner_max: Vector2i) -> void:
	var cluster_center := Vector2(
		rng.randf_range(float(inner_min.x + 3), float(inner_max.x - 3)),
		rng.randf_range(float(inner_min.y + 3), float(inner_max.y - 3))
	)
	for i in range(2):
		var offset := Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(-5.0, 5.0))
		var shard := _make_jagged_polygon(cluster_center + offset, rng, rng.randf_range(0.24, 0.40), rng.randf_range(0.18, 0.30), 5 + rng.randi_range(0, 2), 0.18)
		var shard_color := Color(spec["mid"]).lerp(Color(spec["accent"]), rng.randf_range(0.15, 0.45))
		_fill_polygon(image, shard, shard_color)
		_draw_polygon_outline(image, shard, Color(spec["dark"]), 1)
		if rng.randf() < 0.8:
			var ridge := _offset_polygon(shard, Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5)))
			_fill_polygon(image, ridge, Color(spec["light"]).lerp(shard_color, 0.55))
	var seam_start := cluster_center + Vector2(rng.randf_range(-7.0, 7.0), rng.randf_range(-7.0, 7.0))
	var seam_end := cluster_center + Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-12.0, 12.0))
	_draw_line(image, seam_start, seam_end, Color(spec["dark"]), 1.8)


func _draw_grass_cell(image: Image, spec: Dictionary, rng: RandomNumberGenerator, inner_min: Vector2i, inner_max: Vector2i) -> void:
	var tuft_center := Vector2(
		rng.randf_range(float(inner_min.x + 3), float(inner_max.x - 3)),
		rng.randf_range(float(inner_min.y + 3), float(inner_max.y - 3))
	)
	var blade_count := 4 + rng.randi_range(0, 4)
	for i in range(blade_count):
		var angle := -PI * 0.55 + rng.randf_range(-0.4, 0.4)
		var length := rng.randf_range(10.0, 18.0)
		var offset := Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-2.0, 2.0))
		var blade_base := tuft_center + offset
		var blade_tip := blade_base + Vector2(cos(angle), sin(angle)) * length
		var blade_color := Color(spec["accent"]).lerp(Color(spec["light"]), rng.randf_range(0.15, 0.75))
		_draw_line(image, blade_base, blade_tip, blade_color, 2.0)
		_draw_line(image, blade_base + Vector2(1.0, 0.0), blade_tip + Vector2(1.0, 0.0), Color(spec["dark"]).lerp(blade_color, 0.5), 1.0)
	_draw_disc(image, tuft_center, 3.0 + rng.randf_range(0.0, 1.5), Color(spec["dark"]).lerp(Color(spec["base"]), 0.2))
	if rng.randf() < 0.6:
		var patch := _make_jagged_polygon(tuft_center + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-1.0, 2.0)), rng, 0.26, 0.16, 6, 0.20)
		_fill_polygon(image, patch, Color(spec["mid"]).lerp(Color(spec["accent"]), 0.20))


func _draw_thicket_cell(image: Image, spec: Dictionary, rng: RandomNumberGenerator, inner_min: Vector2i, inner_max: Vector2i) -> void:
	var cluster_center := Vector2(
		rng.randf_range(float(inner_min.x + 2), float(inner_max.x - 2)),
		rng.randf_range(float(inner_min.y + 2), float(inner_max.y - 2))
	)
	var blob_count := 2 + rng.randi_range(0, 3)
	for i in range(blob_count):
		var blob_center := cluster_center + Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(-5.0, 5.0))
		var blob := _make_jagged_polygon(blob_center, rng, rng.randf_range(0.22, 0.34), rng.randf_range(0.16, 0.26), 6, 0.22)
		var blob_color := Color(spec["mid"]).lerp(Color(spec["accent"]), rng.randf_range(0.2, 0.55))
		_fill_polygon(image, blob, blob_color)
		_draw_polygon_outline(image, blob, Color(spec["dark"]), 1)
		if rng.randf() < 0.7:
			var highlight := _offset_polygon(blob, Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5)))
			_fill_polygon(image, highlight, Color(spec["light"]).lerp(blob_color, 0.45))
	var stem_count := 2 + rng.randi_range(0, 2)
	for i in range(stem_count):
		var stem_base := cluster_center + Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-2.0, 6.0))
		var stem_tip := stem_base + Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-14.0, -6.0))
		_draw_line(image, stem_base, stem_tip, Color(spec["dark"]).lerp(Color(spec["accent"]), 0.3), 2.0)


func _draw_forest_cell(image: Image, spec: Dictionary, rng: RandomNumberGenerator, inner_min: Vector2i, inner_max: Vector2i) -> void:
	var leaf_count := 2 + rng.randi_range(0, 2)
	for i in range(leaf_count):
		var center := Vector2(
			rng.randf_range(float(inner_min.x + 2), float(inner_max.x - 2)),
			rng.randf_range(float(inner_min.y + 2), float(inner_max.y - 2))
		)
		var leaf := _make_jagged_polygon(center, rng, rng.randf_range(0.20, 0.30), rng.randf_range(0.12, 0.20), 5, 0.24)
		var leaf_color := Color(spec["mid"]).lerp(Color(spec["accent"]), rng.randf_range(0.25, 0.65))
		_fill_polygon(image, leaf, leaf_color)
		_draw_polygon_outline(image, leaf, Color(spec["dark"]), 1)
		var vein_start := center + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
		var vein_end := vein_start + Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-10.0, -4.0))
		_draw_line(image, vein_start, vein_end, Color(spec["dark"]).lerp(leaf_color, 0.4), 1.5)
		if rng.randf() < 0.7:
			_draw_disc(image, center + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0)), rng.randf_range(1.0, 2.2), Color(spec["dark"]).lightened(0.22))
	var twig_start := Vector2(rng.randf_range(float(inner_min.x), float(inner_max.x)), rng.randf_range(float(inner_min.y), float(inner_max.y)))
	var twig_end := twig_start + Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-4.0, 4.0))
	_draw_line(image, twig_start, twig_end, Color(spec["dark"]).lightened(0.10), 1.2)


func _make_jagged_polygon(center: Vector2, rng: RandomNumberGenerator, radius_x_factor: float, radius_y_factor: float, vertex_count: int, jitter: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var radius_x := CELL_SIZE * radius_x_factor
	var radius_y := CELL_SIZE * radius_y_factor
	var rotation := rng.randf_range(0.0, TAU)
	for i in range(vertex_count):
		var progress := float(i) / float(max(vertex_count, 1))
		var angle := rotation + progress * TAU + rng.randf_range(-0.22, 0.22)
		var radius_variation := 1.0 + rng.randf_range(-jitter, jitter)
		points.append(center + Vector2(cos(angle) * radius_x * radius_variation, sin(angle) * radius_y * radius_variation))
	return points


func _offset_polygon(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var shifted := PackedVector2Array()
	for point in points:
		shifted.append(point + offset)
	return shifted


func _fill_polygon(image: Image, points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	var min_x := int(floor(points[0].x))
	var max_x := int(ceil(points[0].x))
	var min_y := int(floor(points[0].y))
	var max_y := int(ceil(points[0].y))
	for point in points:
		min_x = min(min_x, int(floor(point.x)))
		max_x = max(max_x, int(ceil(point.x)))
		min_y = min(min_y, int(floor(point.y)))
		max_y = max(max_y, int(ceil(point.y)))
	min_x = clamp(min_x, 0, TEXTURE_SIZE - 1)
	max_x = clamp(max_x, 0, TEXTURE_SIZE - 1)
	min_y = clamp(min_y, 0, TEXTURE_SIZE - 1)
	max_y = clamp(max_y, 0, TEXTURE_SIZE - 1)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if Geometry2D.is_point_in_polygon(Vector2(float(x) + 0.5, float(y) + 0.5), points):
				image.set_pixel(x, y, color)


func _draw_polygon_outline(image: Image, points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() < 2:
		return
	for i in range(points.size()):
		_draw_line(image, points[i], points[(i + 1) % points.size()], color, width)


func _draw_line(image: Image, start: Vector2, end: Vector2, color: Color, width: float) -> void:
	var distance: float = maxf(start.distance_to(end), 1.0)
	var steps: int = int(ceil(distance * 1.4))
	var radius: float = maxf(width * 0.5, 0.5)
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		_draw_disc(image, start.lerp(end, t), radius, color)


func _draw_disc(image: Image, center: Vector2, radius: float, color: Color) -> void:
	var min_x: int = clampi(int(floor(center.x - radius)), 0, TEXTURE_SIZE - 1)
	var max_x: int = clampi(int(ceil(center.x + radius)), 0, TEXTURE_SIZE - 1)
	var min_y: int = clampi(int(floor(center.y - radius)), 0, TEXTURE_SIZE - 1)
	var max_y: int = clampi(int(ceil(center.y + radius)), 0, TEXTURE_SIZE - 1)
	var radius_squared: float = radius * radius
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var delta := Vector2(float(x) + 0.5, float(y) + 0.5) - center
			if delta.length_squared() <= radius_squared:
				image.set_pixel(x, y, color)


func _fill_rect(image: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			image.set_pixel(x, y, color)


func _tint_color(color: Color, delta: float) -> Color:
	if delta >= 0.0:
		return color.lerp(Color.WHITE, clamp(delta, 0.0, 0.3))
	return color.darkened(clamp(abs(delta), 0.0, 0.3))


func _get_cell_seed(biome_id: String, cell_x: int, cell_y: int) -> int:
	return hash("%s:%d:%d" % [biome_id, cell_x, cell_y])
