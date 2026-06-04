extends Node

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


func _ready() -> void:
	load_settings()
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
	if config.load(SETTINGS_PATH) == OK:
		resolution_index = int(clamp(int(config.get_value("graphics", "resolution_index", resolution_index)), 0, RESOLUTIONS.size() - 1))
		display_mode_index = int(clamp(int(config.get_value("graphics", "display_mode_index", display_mode_index)), 0, 2))


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "resolution_index", resolution_index)
	config.set_value("graphics", "display_mode_index", display_mode_index)
	config.save(SETTINGS_PATH)


func set_from_indices(new_resolution_index: int, new_display_mode_index: int) -> void:
	resolution_index = int(clamp(new_resolution_index, 0, RESOLUTIONS.size() - 1))
	display_mode_index = int(clamp(new_display_mode_index, 0, 2))


func get_current_resolution() -> Vector2i:
	var safe_index: int = int(clamp(resolution_index, 0, RESOLUTIONS.size() - 1))
	return RESOLUTIONS[safe_index]


func apply_settings() -> void:
	if is_embedded_window():
		return
	var resolution: Vector2i = get_current_resolution()
	match display_mode_index:
		DISPLAY_MODE_FULLSCREEN:
			_apply_windowed_border(false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		DISPLAY_MODE_BORDERLESS_FULLSCREEN:
			_apply_windowed_border(false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			_apply_windowed_border(false)
			DisplayServer.window_set_size(resolution)
			_center_window(resolution)


func apply_and_save() -> void:
	apply_settings()
	save_settings()


func _apply_windowed_border(borderless: bool) -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, borderless)


func _center_window(resolution: Vector2i) -> void:
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var position: Vector2i = Vector2i(max((screen_size.x - resolution.x) / 2, 0), max((screen_size.y - resolution.y) / 2, 0))
	DisplayServer.window_set_position(position)


func can_apply_window_settings() -> bool:
	return not is_embedded_window()


func is_embedded_window() -> bool:
	return ProjectSettings.get_setting("display/window/subwindows/embed_subwindows", false) == true
