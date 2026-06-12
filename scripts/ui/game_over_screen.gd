extends Control

signal restart_requested
signal load_save_requested
signal main_menu_requested
signal exit_requested

const PANEL_SIZE := Vector2(520.0, 382.0)
const BUTTON_HEIGHT := 42.0
const SIDE_MARGIN: int = 28

var game_session: Node
var restart_button: Button
var load_save_button: Button
var status_label: Label
var day_label: Label
var reason_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	game_session = get_node("/root/GameSession")
	_build_ui()
	hide()


func show_game_over(day_survived: int, reason: String) -> void:
	day_label.text = "Day survived: %d" % day_survived
	reason_label.text = "Cause of death: %s" % _format_reason(reason)
	_refresh_save_state()
	visible = true
	restart_button.grab_focus()


func hide_game_over() -> void:
	visible = false


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.03, 0.03, 0.88)
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
	title.text = "Game Over"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	stack.add_child(title)

	day_label = Label.new()
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_label.add_theme_font_size_override("font_size", 20)
	stack.add_child(day_label)

	reason_label = Label.new()
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason_label.custom_minimum_size = Vector2(0.0, 40.0)
	reason_label.add_theme_font_size_override("font_size", 16)
	stack.add_child(reason_label)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0.0, 36.0)
	status_label.add_theme_font_size_override("font_size", 14)
	stack.add_child(status_label)

	restart_button = _add_button(stack, "Restart", _on_restart_pressed)
	load_save_button = _add_button(stack, "Load Save", _on_load_save_pressed)
	_add_button(stack, "Main Menu", _on_main_menu_pressed)
	_add_button(stack, "Exit", _on_exit_pressed)


func _apply_panel_margins(container: MarginContainer) -> void:
	container.add_theme_constant_override("margin_left", int(28))
	container.add_theme_constant_override("margin_right", int(28))
	container.add_theme_constant_override("margin_top", int(28))
	container.add_theme_constant_override("margin_bottom", int(28))


func _add_button(stack: VBoxContainer, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	stack.add_child(button)
	return button


func _refresh_save_state() -> void:
	var has_save: bool = game_session.has_save_game()
	load_save_button.disabled = not has_save
	status_label.text = "A save file is available." if has_save else "No save file found yet."


func _format_reason(reason: String) -> String:
	if reason.is_empty():
		return "Unknown"
	return reason.capitalize()


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_load_save_pressed() -> void:
	if load_save_button.disabled:
		status_label.text = "No save file found yet."
		return
	load_save_requested.emit()


func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()


func _on_exit_pressed() -> void:
	exit_requested.emit()
