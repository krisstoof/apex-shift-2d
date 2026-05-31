extends Control

signal resume_requested
signal save_requested
signal load_requested
signal quit_requested

const PANEL_SIZE := Vector2(340, 300)

var panel: Panel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_menu()


func _build_menu() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.015, 0.018, 0.018, 0.82)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	add_child(panel)

	var title := Label.new()
	title.text = "Pause"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.offset_left = 20.0
	title.offset_top = 18.0
	title.offset_right = PANEL_SIZE.x - 20.0
	title.offset_bottom = 52.0
	panel.add_child(title)

	_add_button("Resume", 70.0, resume_requested.emit)
	_add_button("Save Game", 118.0, save_requested.emit)
	_add_button("Load Game", 166.0, load_requested.emit)
	_add_button("Quit", 224.0, quit_requested.emit)


func _add_button(label: String, top: float, pressed_callable: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.offset_left = 44.0
	button.offset_top = top
	button.offset_right = PANEL_SIZE.x - 44.0
	button.offset_bottom = top + 36.0
	button.pressed.connect(pressed_callable)
	panel.add_child(button)
