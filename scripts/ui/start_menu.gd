extends Control

const GAME_SCENE_PATH := "res://scenes/main.tscn"
const SETTINGS_SCENE_PATH := "res://scenes/ui/settings_menu.tscn"
const APP_VERSION := preload("res://scripts/systems/app_version.gd")

const PANEL_SIZE := Vector2(620.0, 520.0)
const BUTTON_HEIGHT := 42.0
const SIDE_MARGIN := 28.0
const GAME_GOAL_TEXT := "Survive, gather resources, craft tools, store supplies,\nand observe how the ecosystem reacts."
const CONTROLS_TEXT := "Controls:\nWASD - Move\nE - Interact\nI - Inventory\nM - Map\nEsc - Pause\nF3 - Debug"
const STORAGE_HINT_TEXT := "Storage boxes can hold supplies."

var main_panel: PanelContainer
var new_game_button: Button
var continue_button: Button
var load_button: Button
var status_label: Label
var game_session


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_resume_tree_if_paused()
	print("[APP] %s" % APP_VERSION.get_display_name())
	game_session = get_node("/root/GameSession")
	_build_ui()
	_refresh_save_state()
	_show_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_tree().quit()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.04, 0.06, 0.05, 1.0)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	main_panel = PanelContainer.new()
	main_panel.custom_minimum_size = PANEL_SIZE
	center.add_child(main_panel)

	var main_margin := MarginContainer.new()
	_apply_panel_margins(main_margin)
	main_panel.add_child(main_margin)

	var main_stack := VBoxContainer.new()
	main_stack.add_theme_constant_override("separation", 9)
	main_margin.add_child(main_stack)

	var title := Label.new()
	title.text = "Apex Shift 2D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	main_stack.add_child(title)

	var subtitle := Label.new()
	subtitle.text = APP_VERSION.get_display_name()
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	main_stack.add_child(subtitle)

	var info_spacer := Control.new()
	info_spacer.custom_minimum_size = Vector2(0.0, 6.0)
	main_stack.add_child(info_spacer)

	_add_info_label(main_stack, GAME_GOAL_TEXT, 14)
	_add_info_label(main_stack, CONTROLS_TEXT, 13)
	_add_info_label(main_stack, STORAGE_HINT_TEXT, 13)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 8.0)
	main_stack.add_child(spacer)

	new_game_button = _add_main_button(main_stack, "New Game", _on_new_game_pressed)
	continue_button = _add_main_button(main_stack, "Continue", _on_continue_pressed)
	load_button = _add_main_button(main_stack, "Load Save", _on_load_save_pressed)
	_add_main_button(main_stack, "Settings", _on_settings_pressed)
	_add_main_button(main_stack, "Exit", _on_exit_pressed)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.custom_minimum_size = Vector2(0.0, 48.0)
	main_stack.add_child(status_label)


func _add_main_button(stack: VBoxContainer, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	stack.add_child(button)
	return button


func _add_info_label(stack: VBoxContainer, text: String, font_size: int = 14) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	stack.add_child(label)
	return label


func _apply_panel_margins(container: MarginContainer) -> void:
	container.add_theme_constant_override("margin_left", SIDE_MARGIN)
	container.add_theme_constant_override("margin_right", SIDE_MARGIN)
	container.add_theme_constant_override("margin_top", SIDE_MARGIN)
	container.add_theme_constant_override("margin_bottom", SIDE_MARGIN)


func _show_main_menu() -> void:
	main_panel.visible = true
	if continue_button.disabled:
		new_game_button.grab_focus()
	else:
		continue_button.grab_focus()


func _refresh_save_state() -> void:
	var has_save: bool = game_session.has_save_game()
	continue_button.disabled = not has_save
	load_button.disabled = not has_save
	status_label.text = "Save found. Continue and Load Save are available." if has_save else "No save file found yet. Start a new game to create one."


func _on_new_game_pressed() -> void:
	game_session.request_new_game()
	_change_to_game_scene()


func _on_continue_pressed() -> void:
	if not game_session.has_save_game():
		status_label.text = "No save file found yet."
		return
	game_session.request_continue()
	_change_to_game_scene()


func _on_load_save_pressed() -> void:
	_on_continue_pressed()


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file(SETTINGS_SCENE_PATH)


func _on_exit_pressed() -> void:
	get_tree().quit()


func _change_to_game_scene() -> void:
	_resume_tree_if_paused()
	var error := get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if error != OK:
		game_session.request_new_game()
		status_label.text = "Could not start the game."


func _resume_tree_if_paused(tree: SceneTree = get_tree()) -> void:
	if tree:
		tree.paused = false
