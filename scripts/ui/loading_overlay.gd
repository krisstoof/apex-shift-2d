extends CanvasLayer

@onready var title_label: Label = $Root/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var status_label: Label = $Root/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatusLabel
@onready var progress_bar: ProgressBar = $Root/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ProgressBar


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	show_loading()


func show_loading(stage_message := "Preparing world...", progress := 0.0) -> void:
	visible = true
	if status_label:
		status_label.text = stage_message
	if progress_bar:
		progress_bar.value = clampf(progress, 0.0, 1.0) * 100.0


func hide_loading() -> void:
	visible = false


func get_status_text() -> String:
	return status_label.text if status_label else ""


func get_progress_ratio() -> float:
	if progress_bar == null:
		return 0.0
	return progress_bar.value / 100.0
