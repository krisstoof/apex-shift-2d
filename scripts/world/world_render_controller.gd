extends RefCounted
class_name WorldRenderController

const BIOME_BLEND_TEXTURE_SIZE := Vector2i(480, 296)

var biome_blend_texture: ImageTexture
var biome_blend_colors_key := ""
var biome_texture_size := BIOME_BLEND_TEXTURE_SIZE
var world_rect := Rect2()
var biome_zones_getter: Callable
var biome_colors_key_getter: Callable
var biome_surface_color_getter: Callable
var world_redraw_interval := 0.20
var night_redraw_min_delta := 0.03
var world_background_redraw_timer := 0.0
var last_drawn_night_amount := -1.0
var freeze_blend_texture_after_first_build := true

# HITCH LOGGER COUNTERS
var biome_blend_texture_rebuild_count: int = 0
var biome_blend_texture_last_build_ms: float = 0.0
var biome_blend_texture_rebuild_blocked_count: int = 0
var biome_blend_texture_dirty_key := ""


func bind_world(
	assigned_world_rect: Rect2,
	assigned_biome_zones_getter: Callable,
	assigned_biome_colors_key_getter: Callable,
	assigned_biome_surface_color_getter: Callable,
	assigned_biome_texture_size: Vector2i = BIOME_BLEND_TEXTURE_SIZE,
	assigned_world_redraw_interval := 0.20,
	assigned_night_redraw_min_delta := 0.03
) -> void:
	world_rect = assigned_world_rect
	biome_zones_getter = assigned_biome_zones_getter
	biome_colors_key_getter = assigned_biome_colors_key_getter
	biome_surface_color_getter = assigned_biome_surface_color_getter
	biome_texture_size = assigned_biome_texture_size
	world_redraw_interval = assigned_world_redraw_interval
	night_redraw_min_delta = assigned_night_redraw_min_delta


func process(delta: float, current_night_amount: float) -> bool:
	if last_drawn_night_amount < 0.0:
		last_drawn_night_amount = current_night_amount
	world_background_redraw_timer += delta
	if world_background_redraw_timer >= world_redraw_interval or abs(current_night_amount - last_drawn_night_amount) >= night_redraw_min_delta:
		world_background_redraw_timer = 0.0
		last_drawn_night_amount = current_night_amount
		return true
	return false


func get_biome_texture_cache_status() -> Dictionary:
	return {
		"has_texture": biome_blend_texture != null,
		"colors_key": biome_blend_colors_key,
		"size": biome_texture_size,
		"rebuild_count": biome_blend_texture_rebuild_count,
		"last_build_ms": biome_blend_texture_last_build_ms,
		"rebuild_blocked_count": biome_blend_texture_rebuild_blocked_count,
		"dirty_key_pending": not biome_blend_texture_dirty_key.is_empty(),
		"freeze_after_first_build": freeze_blend_texture_after_first_build
	}


func ensure_biome_blend_texture() -> ImageTexture:
	var current_key := _get_biome_colors_key()
	if biome_blend_texture != null and biome_blend_colors_key == current_key:
		biome_blend_texture_dirty_key = ""
		return biome_blend_texture
	if biome_blend_texture != null and freeze_blend_texture_after_first_build:
		biome_blend_texture_dirty_key = current_key
		biome_blend_texture_rebuild_blocked_count += 1
		return biome_blend_texture
	return _rebuild_biome_blend_texture(current_key)

func force_rebuild_biome_blend_texture() -> ImageTexture:
	return _rebuild_biome_blend_texture(_get_biome_colors_key())


func _rebuild_biome_blend_texture(current_key: String) -> ImageTexture:
	# Track blend texture rebuild timing for hitch logging.
	var build_start_ms: int = Time.get_ticks_msec()
	var biome_zones: Array = []
	if biome_zones_getter.is_valid():
		biome_zones = Array(biome_zones_getter.call())

	var image := Image.create(biome_texture_size.x, biome_texture_size.y, false, Image.FORMAT_RGBA8)
	for y in range(biome_texture_size.y):
		for x in range(biome_texture_size.x):
			var sampled_position := world_rect.position + Vector2(
				(float(x) + 0.5) / float(biome_texture_size.x) * world_rect.size.x,
				(float(y) + 0.5) / float(biome_texture_size.y) * world_rect.size.y
			)
			image.set_pixel(x, y, _get_biome_surface_color_at(sampled_position, biome_zones))

	biome_blend_texture = ImageTexture.create_from_image(image)
	biome_blend_colors_key = current_key
	biome_blend_texture_dirty_key = ""
	biome_blend_texture_rebuild_count += 1
	biome_blend_texture_last_build_ms = float(Time.get_ticks_msec() - build_start_ms)
	return biome_blend_texture


func invalidate_biome_blend_texture() -> void:
	biome_blend_texture = null
	biome_blend_colors_key = ""
	biome_blend_texture_dirty_key = ""


func _get_biome_colors_key() -> String:
	if biome_colors_key_getter.is_valid():
		return str(biome_colors_key_getter.call())
	return ""


func _get_biome_surface_color_at(position: Vector2, biome_zones: Array) -> Color:
	if not biome_surface_color_getter.is_valid():
		return Color.BLACK
	return biome_surface_color_getter.call(position, biome_zones)
