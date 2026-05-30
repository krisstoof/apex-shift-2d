extends Node

@onready var evolution_director: Node = get_parent().get_node("EvolutionDirector")
@onready var day_night_system: Node = get_parent().get_node("DayNightSystem")
@onready var hud: CanvasLayer = get_parent().get_node("HUD")
@onready var player: Node = get_parent().get_node("Player")

func _ready() -> void:
	player.evolution_director = evolution_director
	hud.bind(player, evolution_director, day_night_system)
	get_node("/root/EventBus").post_message("Apex Shift 2D prototype ready")
