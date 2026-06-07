extends Node
class_name GraphicsSettingsConfig

const SETTINGS_PATH := "user://settings.json"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]
const DISPLAY_MODE_WINDOWED := 0
const DISPLAY_MODE_FULLSCREEN := 1
const DISPLAY_MODE_BORDERLESS_FULLSCREEN := 2

var resolution_index := 0
var display_mode_index := 0
var _apply_serial := 0

var low_end_rendering: bool = true
var biome_textures_enabled: bool = true
var landmark_debug_overlay_enabled: bool = false
var biome_terrain_accents_enabled: bool = false

func is_low_end_rendering_enabled() -> bool:
	return low_end_rendering

func get_default_biome_textures_enabled() -> bool:
	return biome_textures_enabled

func get_default_landmark_debug_overlay_enabled() -> bool:
	return landmark_debug_overlay_enabled


func get_default_biome_terrain_accents_enabled() -> bool:
	return biome_terrain_accents_enabled


func apply_low_end_rendering_defaults() -> void:
	low_end_rendering = true
	biome_textures_enabled = true
	landmark_debug_overlay_enabled = false
	biome_terrain_accents_enabled = false


func _ready() -> void:
	load_settings()
	_apply_resolution_override_from_args()
	_apply_display_override_from_args()
	apply_settings()


func get_resolution_label(index: int) -> String:
	var safe_index: int = int(clamp(index, 0, RESOLUTIONS.size() - 1))
	var resolution: Vector2i = RESOLUTIONS[safe_index]
	return "%dx%d" % [resolution.x, resolution.y]


func get_display_mode_label(index: int) -> String:
	match clamp(index, 0, 2):
		DISPLAY_MODE_FULLSCREEN:
			return "Fullscreen"
		DISPLAY_MODE_BORDERLESS_FULLSCREEN:
			return "Borderless Fullscreen"
	return "Windowed"


func get_resolution_count() -> int:
	return RESOLUTIONS.size()


func get_display_mode_count() -> int:
	return 3


func load_settings() -> void:
	var config := ConfigFile.new()
	resolution_index = 0
	display_mode_index = DISPLAY_MODE_WINDOWED
	apply_low_end_rendering_defaults()
	if config.load(SETTINGS_PATH) == OK:
		resolution_index = int(clamp(int(config.get_value("graphics", "resolution_index", resolution_index)), 0, RESOLUTIONS.size() - 1))
		display_mode_index = int(clamp(int(config.get_value("graphics", "display_mode_index", display_mode_index)), 0, 2))
		low_end_rendering = bool(config.get_value("graphics", "low_end_rendering", low_end_rendering))
		biome_textures_enabled = bool(config.get_value("graphics", "biome_textures_enabled", biome_textures_enabled))
		landmark_debug_overlay_enabled = bool(config.get_value("graphics", "landmark_debug_overlay_enabled", landmark_debug_overlay_enabled))
		biome_terrain_accents_enabled = bool(config.get_value("graphics", "biome_terrain_accents_enabled", biome_terrain_accents_enabled))


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "resolution_index", resolution_index)
	config.set_value("graphics", "display_mode_index", display_mode_index)
	config.set_value("graphics", "low_end_rendering", low_end_rendering)
	config.set_value("graphics", "biome_textures_enabled", biome_textures_enabled)
	config.set_value("graphics", "landmark_debug_overlay_enabled", landmark_debug_overlay_enabled)
	config.set_value("graphics", "biome_terrain_accents_enabled", biome_terrain_accents_enabled)
	config.save(SETTINGS_PATH)


func _apply_resolution_override_from_args() -> void:
	var args := OS.get_cmdline_args()
	for arg in args:
		if not arg.begins_with("--resolution="):
			continue

		var value := arg.replace("--resolution=", "")
		var parts := value.split("x")
		if parts.size() != 2:
			push_warning("Invalid --resolution argument: %s" % value)
			return

		var width := int(parts[0])
		var height := int(parts[1])
		var requested := Vector2i(width, height)

		for i in RESOLUTIONS.size():
			if RESOLUTIONS[i] == requested:
				resolution_index = i
				print("[GRAPHICS_SETTINGS] resolution override applied: %s" % requested)
				return

		push_warning("Unsupported --resolution argument: %s" % value)
		return


func _apply_display_override_from_args() -> void:
	var args := OS.get_cmdline_args()
	for arg in args:
		if not arg.begins_with("--display="):
			continue

		var value := arg.replace("--display=", "").to_lower()
		match value:
			"windowed":
				display_mode_index = 0
				print("[GRAPHICS_SETTINGS] display override applied: windowed")
			"fullscreen":
				display_mode_index = 1
				print("[GRAPHICS_SETTINGS] display override applied: fullscreen")
			"borderless":
				display_mode_index = 2
				print("[GRAPHICS_SETTINGS] display override applied: borderless")
			_:
				push_warning("Unsupported --display argument: %s" % value)
		return


func set_from_indices(new_resolution_index: int, new_display_mode_index: int) -> void:
	resolution_index = int(clamp(new_resolution_index, 0, RESOLUTIONS.size() - 1))
	display_mode_index = int(clamp(new_display_mode_index, 0, 2))


func get_current_resolution() -> Vector2i:
	var safe_index: int = int(clamp(resolution_index, 0, RESOLUTIONS.size() - 1))
	return RESOLUTIONS[safe_index]


func get_effective_resolution() -> Vector2i:
	var requested_resolution := get_current_resolution()
	if display_mode_index == DISPLAY_MODE_BORDERLESS_FULLSCREEN:
		return _get_screen_size()
	if display_mode_index == DISPLAY_MODE_FULLSCREEN:
		return _get_fullscreen_size_for_screen(requested_resolution, _get_screen_size())
	return _get_windowed_size_for_screen(requested_resolution)


func apply_settings() -> void:
	var resolution := get_effective_resolution()
	_apply_content_resolution(resolution)
	_apply_display_mode()
	_apply_window_resolution(resolution)
	if is_embedded_window():
		return
	_apply_serial += 1
	var apply_serial := _apply_serial
	match display_mode_index:
		DISPLAY_MODE_FULLSCREEN:
			call_deferred("_finish_exclusive_fullscreen", apply_serial, resolution)
		DISPLAY_MODE_BORDERLESS_FULLSCREEN:
			pass
		_:
			call_deferred("_finish_windowed_mode", apply_serial, resolution)


func apply_and_save() -> void:
	apply_settings()
	save_settings()


func _apply_windowed_border(borderless: bool) -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, borderless)


func _apply_display_mode() -> void:
	match display_mode_index:
		DISPLAY_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			_apply_windowed_border(false)
		DISPLAY_MODE_BORDERLESS_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			_apply_windowed_border(false)


func _apply_window_resolution(resolution: Vector2i) -> void:
	if display_mode_index != DISPLAY_MODE_WINDOWED:
		return
	DisplayServer.window_set_size(resolution)
	var current_screen := DisplayServer.window_get_current_screen()
	var screen_position := DisplayServer.screen_get_position(current_screen)
	var screen_size := DisplayServer.screen_get_size(current_screen)
	DisplayServer.window_set_position(screen_position + (screen_size - resolution) / 2)
	print("[GRAPHICS_SETTINGS] windowed size applied: %s" % resolution)


func _apply_content_resolution(_resolution: Vector2i) -> void:
	# Keep gameplay world pixel scale independent from selected window resolution.
	# Window size may change, but CanvasItems must not be globally scaled.
	var root_window := get_tree().root
	root_window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root_window.content_scale_size = Vector2i.ZERO


func _finish_exclusive_fullscreen(apply_serial: int, resolution: Vector2i) -> void:
	if apply_serial != _apply_serial:
		return
	DisplayServer.window_set_size(resolution)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


func _finish_windowed_mode(apply_serial: int, resolution: Vector2i) -> void:
	if apply_serial != _apply_serial:
		return
	DisplayServer.window_set_size(resolution)
	_center_window(resolution)


func _center_window(resolution: Vector2i) -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable_rect := DisplayServer.screen_get_usable_rect(screen)
	var position := usable_rect.position + Vector2i(
		maxi((usable_rect.size.x - resolution.x) / 2, 0),
		maxi((usable_rect.size.y - resolution.y) / 2, 0)
	)
	DisplayServer.window_set_position(position)


func _get_windowed_size_for_screen(resolution: Vector2i) -> Vector2i:
	var screen := DisplayServer.window_get_current_screen()
	var usable_size := DisplayServer.screen_get_usable_rect(screen).size
	if usable_size.x <= 0 or usable_size.y <= 0:
		return resolution
	return Vector2i(mini(resolution.x, usable_size.x), mini(resolution.y, usable_size.y))


func _get_fullscreen_size_for_screen(resolution: Vector2i, screen_size: Vector2i) -> Vector2i:
	if screen_size.x <= 0 or screen_size.y <= 0:
		return resolution
	if resolution.x <= screen_size.x and resolution.y <= screen_size.y:
		return resolution
	for index in range(RESOLUTIONS.size() - 1, -1, -1):
		var candidate: Vector2i = RESOLUTIONS[index]
		if candidate.x <= screen_size.x and candidate.y <= screen_size.y:
			return candidate
	return Vector2i(mini(resolution.x, screen_size.x), mini(resolution.y, screen_size.y))


func _get_screen_size() -> Vector2i:
	var screen := DisplayServer.window_get_current_screen()
	return DisplayServer.screen_get_size(screen)


func is_resolution_selectable(display_mode: int = display_mode_index) -> bool:
	return display_mode != DISPLAY_MODE_BORDERLESS_FULLSCREEN


func can_apply_window_settings() -> bool:
	return not is_embedded_window()


func is_embedded_window() -> bool:
	return Engine.is_embedded_in_editor()
