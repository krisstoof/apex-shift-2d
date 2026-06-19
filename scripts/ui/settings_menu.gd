extends Control

const START_MENU_PATH := "res://scenes/ui/start_menu.tscn"

const PANEL_SIZE := Vector2(520.0, 320.0)
const BUTTON_HEIGHT := 42.0
const SIDE_MARGIN := 28.0

var graphics_settings
var resolution_option: OptionButton
var display_mode_option: OptionButton
var graphics_preset_option: OptionButton
var show_resource_markers_toggle: CheckButton
var status_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	graphics_settings = get_node("/root/GraphicsSettings")
	_build_ui()
	_sync_from_settings()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_back_to_start_menu()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.04, 0.06, 0.05, 1.0)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_SIZE
	center.add_child(panel)

	var margin := MarginContainer.new()
	_apply_panel_margins(margin)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	stack.add_child(title)

	var resolution_row := HBoxContainer.new()
	resolution_row.add_theme_constant_override("separation", 12)
	stack.add_child(resolution_row)

	var resolution_label := Label.new()
	resolution_label.text = "Resolution"
	resolution_label.custom_minimum_size = Vector2(150.0, 0.0)
	resolution_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	resolution_row.add_child(resolution_label)

	resolution_option = OptionButton.new()
	resolution_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resolution_option.item_selected.connect(_on_resolution_selected)
	resolution_row.add_child(resolution_option)

	var display_row := HBoxContainer.new()
	display_row.add_theme_constant_override("separation", 12)
	stack.add_child(display_row)

	var display_label := Label.new()
	display_label.text = "Display mode"
	display_label.custom_minimum_size = Vector2(150.0, 0.0)
	display_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	display_row.add_child(display_label)

	display_mode_option = OptionButton.new()
	display_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_mode_option.item_selected.connect(_on_display_mode_selected)
	display_row.add_child(display_mode_option)

	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 12)
	stack.add_child(preset_row)

	var preset_label := Label.new()
	preset_label.text = "Graphics preset"
	preset_label.custom_minimum_size = Vector2(150.0, 0.0)
	preset_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preset_row.add_child(preset_label)

	graphics_preset_option = OptionButton.new()
	graphics_preset_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphics_preset_option.item_selected.connect(_on_graphics_preset_selected)
	preset_row.add_child(graphics_preset_option)

	var markers_row := HBoxContainer.new()
	markers_row.add_theme_constant_override("separation", 12)
	stack.add_child(markers_row)

	var markers_label := Label.new()
	markers_label.text = "Maps"
	markers_label.custom_minimum_size = Vector2(150.0, 0.0)
	markers_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	markers_row.add_child(markers_label)

	show_resource_markers_toggle = CheckButton.new()
	show_resource_markers_toggle.text = "Show resource markers on map"
	show_resource_markers_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	show_resource_markers_toggle.toggled.connect(_on_show_resource_markers_toggled)
	markers_row.add_child(show_resource_markers_toggle)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.custom_minimum_size = Vector2(0.0, 44.0)
	stack.add_child(status_label)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	stack.add_child(button_row)

	var apply_button := Button.new()
	apply_button.text = "Apply"
	apply_button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_button.pressed.connect(_on_apply_pressed)
	button_row.add_child(apply_button)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_button.pressed.connect(_back_to_start_menu)
	button_row.add_child(back_button)


func _apply_panel_margins(container: MarginContainer) -> void:
	container.add_theme_constant_override("margin_left", SIDE_MARGIN)
	container.add_theme_constant_override("margin_right", SIDE_MARGIN)
	container.add_theme_constant_override("margin_top", SIDE_MARGIN)
	container.add_theme_constant_override("margin_bottom", SIDE_MARGIN)


func _sync_from_settings() -> void:
	resolution_option.clear()
	for resolution in graphics_settings.RESOLUTIONS:
		resolution_option.add_item("%dx%d" % [resolution.x, resolution.y])
	resolution_option.select(clamp(int(graphics_settings.resolution_index), 0, graphics_settings.get_resolution_count() - 1))

	display_mode_option.clear()
	display_mode_option.add_item("Windowed")
	display_mode_option.add_item("Fullscreen")
	display_mode_option.add_item("Borderless Fullscreen")
	display_mode_option.select(clamp(int(graphics_settings.display_mode_index), 0, graphics_settings.get_display_mode_count() - 1))
	graphics_preset_option.clear()
	for preset_name in graphics_settings.get_available_graphics_presets():
		graphics_preset_option.add_item(preset_name.capitalize())
	graphics_preset_option.select(maxi(graphics_settings.get_available_graphics_presets().find(graphics_settings.get_graphics_preset_name()), 0))
	show_resource_markers_toggle.button_pressed = graphics_settings.should_show_resource_markers_on_maps()

	_refresh_resolution_availability()
	_refresh_status_text()


func _on_apply_pressed() -> void:
	graphics_settings.set_from_indices(resolution_option.selected, display_mode_option.selected)
	var preset_index := graphics_preset_option.selected
	var preset_names := PackedStringArray(graphics_settings.get_available_graphics_presets())
	if preset_index >= 0 and preset_index < preset_names.size():
		graphics_settings.set_graphics_preset(str(preset_names[preset_index]), false)
	graphics_settings.apply_and_save()
	if graphics_settings.can_apply_window_settings():
		var resolution: Vector2i = graphics_settings.get_effective_resolution()
		status_label.text = "Settings applied: %dx%d, %s." % [
			resolution.x,
			resolution.y,
			graphics_settings.get_display_mode_label(graphics_settings.display_mode_index)
		]
	else:
		var resolution: Vector2i = graphics_settings.get_effective_resolution()
		status_label.text = "Editor preview resolution applied: %dx%d. Window mode applies in standalone." % [
			resolution.x,
			resolution.y
		]


func _on_resolution_selected(_index: int) -> void:
	_refresh_status_text()


func _on_display_mode_selected(_index: int) -> void:
	_refresh_resolution_availability()
	_refresh_status_text()


func _on_graphics_preset_selected(_index: int) -> void:
	_refresh_status_text()


func _on_show_resource_markers_toggled(enabled: bool) -> void:
	graphics_settings.set_show_resource_markers_on_maps(enabled)


func _refresh_resolution_availability() -> void:
	var mode := display_mode_option.selected
	resolution_option.disabled = not graphics_settings.is_resolution_selectable(mode)


func _refresh_status_text() -> void:
	if not graphics_settings.can_apply_window_settings():
		status_label.text = "Resolution changes the editor preview canvas. Window mode applies in a standalone run."
		return
	if display_mode_option.selected == graphics_settings.DISPLAY_MODE_BORDERLESS_FULLSCREEN:
		status_label.text = "Borderless Fullscreen uses the current desktop resolution."
		return
	status_label.text = "Selected resolution and graphics preset will be applied and saved locally."


func _back_to_start_menu() -> void:
	get_tree().change_scene_to_file(START_MENU_PATH)
