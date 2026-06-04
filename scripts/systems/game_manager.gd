extends Node

@onready var evolution_director: Node = get_parent().get_node("EvolutionDirector")
@onready var day_night_system: Node = get_parent().get_node("DayNightSystem")
@onready var ecosystem_director: Node = get_parent().get_node("EcosystemDirector")
@onready var hud: CanvasLayer = get_parent().get_node("HUD")
@onready var player: Node = get_parent().get_node("Player")
@onready var world: Node = get_parent().get_node("World")
@onready var save_system: Node = get_parent().get_node("SaveSystem")
@onready var game_session = get_node("/root/GameSession")

func _ready() -> void:
	await _wait_for_world_boot()
	player.evolution_director = evolution_director
	hud.bind(player, evolution_director, day_night_system, ecosystem_director)
	await _apply_boot_action()
	get_node("/root/EventBus").post_message("Apex Shift 2D prototype ready")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		world.respawn_varnaks()
	if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		save_system.save_game()
	if event is InputEventKey and event.pressed and event.keycode == KEY_F9:
		save_system.load_game()


func _wait_for_world_boot() -> void:
	if world.has_method("is_boot_ready") and world.is_boot_ready():
		return
	if world.has_signal("world_initialized"):
		await world.world_initialized


func _apply_boot_action() -> void:
	if game_session.consume_load_save_request():
		await save_system.load_game()
