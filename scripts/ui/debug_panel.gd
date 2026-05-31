extends Control

var player: Node
var evolution_director: Node
var day_night_system: Node

@onready var title_label: Label = $Panel/TitleLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	title_label.text = "Debug"


func bind(p_player: Node, p_evolution_director: Node, p_day_night_system: Node) -> void:
	player = p_player
	evolution_director = p_evolution_director
	day_night_system = p_day_night_system


func toggle() -> void:
	set_open(not visible)


func set_open(open: bool) -> void:
	visible = open
