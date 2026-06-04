extends Control

const START_MENU_PATH := "res://scenes/ui/start_menu.tscn"

const PANEL_SIZE := Vector2(520.0, 320.0)
const BUTTON_HEIGHT := 42.0
const SIDE_MARGIN := 28.0

var graphics_settings
var resolution_option: OptionButton
var display_mode_option: OptionButton
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
	display_row.add_child(display_mode_option)

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

	status_label.text = "Apply saves local settings to user://settings.json." if graphics_settings.can_apply_window_settings() else "Embedded preview cannot change window mode or resolution. Settings will still be saved."


func _on_apply_pressed() -> void:
	graphics_settings.set_from_indices(resolution_option.selected, display_mode_option.selected)
	graphics_settings.apply_and_save()
	status_label.text = "Settings applied." if graphics_settings.can_apply_window_settings() else "Settings saved for the next standalone run."


func _back_to_start_menu() -> void:
	get_tree().change_scene_to_file(START_MENU_PATH)
