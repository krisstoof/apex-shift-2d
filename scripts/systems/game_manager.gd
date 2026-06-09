extends Node

@onready var evolution_director: Node = get_parent().get_node("EvolutionDirector")
@onready var day_night_system: Node = get_parent().get_node("DayNightSystem")
@onready var ecosystem_director: Node = get_parent().get_node("EcosystemDirector")
@onready var hud: CanvasLayer = get_parent().get_node("HUD")
@onready var player: Node = get_parent().get_node("Player")
@onready var world: Node = get_parent().get_node("World")
@onready var save_system: Node = get_parent().get_node("SaveSystem")
@onready var loading_overlay: CanvasLayer = get_parent().get_node("LoadingOverlay")
@onready var game_session = get_node("/root/GameSession")

var game_over_active := false


func _post_event_message(message: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var event_bus := tree.root.get_node_or_null("EventBus")
	if event_bus and event_bus.has_method("post_message"):
		event_bus.post_message(message)

func _ready() -> void:
	_set_loading_overlay_state("Preparing world...", 0.0)
	if hud:
		hud.visible = false
	_connect_world_boot_progress()
	await _wait_for_world_boot()
	player.evolution_director = evolution_director
	hud.bind(player, evolution_director, day_night_system, ecosystem_director)
	if player.has_signal("died"):
		var died_callable := Callable(self, "_on_player_died")
		if not player.is_connected("died", died_callable):
			player.connect("died", died_callable)
	if player.has_method("set_default_camera_zoom"):
		player.set_default_camera_zoom()
	await _apply_boot_action()
	if hud:
		hud.visible = true
	_hide_loading_overlay()
	_post_event_message("Apex Shift 2D prototype ready")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		if hud != null and hud.has_node("DebugPanel"):
			var debug_panel := hud.get_node("DebugPanel") as Control
			if debug_panel != null and debug_panel.visible:
				world.respawn_varnaks()
	if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		save_system.save_game()
	if event is InputEventKey and event.pressed and event.keycode == KEY_F9:
		await save_system.load_game()
		if player and player.has_method("set_default_camera_zoom"):
			player.set_default_camera_zoom()


func _wait_for_world_boot() -> void:
	if world.has_method("is_boot_ready") and world.is_boot_ready():
		return
	if world.has_signal("world_initialized"):
		await world.world_initialized


func _apply_boot_action() -> void:
	if game_session.consume_load_save_request():
		_set_loading_overlay_state("Loading save data...", 1.0)
		await save_system.load_game()
		if player and player.has_method("set_default_camera_zoom"):
			player.set_default_camera_zoom()


func _connect_world_boot_progress() -> void:
	if world.has_signal("world_boot_stage_changed"):
		var stage_callable := Callable(self, "_on_world_boot_stage_changed")
		if not world.is_connected("world_boot_stage_changed", stage_callable):
			world.connect("world_boot_stage_changed", stage_callable)
	if world.has_method("get_boot_progress_state"):
		var boot_state := Dictionary(world.get_boot_progress_state())
		_set_loading_overlay_state(str(boot_state.get("message", "Preparing world...")), float(boot_state.get("progress", 0.0)))


func _on_world_boot_stage_changed(stage_message: String, progress: float) -> void:
	_set_loading_overlay_state(stage_message, progress)


func _set_loading_overlay_state(stage_message: String, progress: float) -> void:
	if loading_overlay and loading_overlay.has_method("show_loading"):
		loading_overlay.show_loading(stage_message, progress)


func _hide_loading_overlay() -> void:
	if loading_overlay and loading_overlay.has_method("hide_loading"):
		loading_overlay.hide_loading()


func _on_player_died(reason: String) -> void:
	if game_over_active:
		return
	game_over_active = true
	var day_survived: int = int(day_night_system.get_day()) if day_night_system.has_method("get_day") else 1
	if hud.has_method("show_game_over"):
		hud.show_game_over(day_survived, reason)
	get_tree().paused = true
