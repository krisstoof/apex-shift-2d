extends CanvasLayer

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")

var player: Node
var evolution_director: Node
var day_night_system: Node
var message := ""
var message_history: Array[String] = []
var map_screen_open := false
var pause_menu_open := false
var center_notification_time := 0.0

@onready var stats_label: Label = $Panel/StatsLabel
@onready var prompt_label: Label = $Panel/PromptLabel
@onready var message_label: Label = $Panel/MessageLabel
@onready var center_notification_label: Label = $CenterNotificationLabel
@onready var skill_icon_bar: Control = $SkillIconBar
@onready var minimap: Control = $Minimap
@onready var clock_label: Label = $ClockLabel
@onready var map_screen: Control = $MapScreen
@onready var pause_menu: Control = $PauseMenu
@onready var debug_panel: Control = $DebugPanel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	center_notification_label.visible = false
	get_node("/root/EventBus").message_posted.connect(_on_message)
	get_node("/root/EventBus").game_event.connect(_on_game_event)
	pause_menu.resume_requested.connect(_on_pause_menu_resume)
	pause_menu.save_requested.connect(_on_pause_menu_save)
	pause_menu.load_requested.connect(_on_pause_menu_load)
	pause_menu.quit_requested.connect(_on_pause_menu_quit)


func bind(p_player: Node, p_evolution_director: Node, p_day_night_system: Node) -> void:
	player = p_player
	evolution_director = p_evolution_director
	day_night_system = p_day_night_system
	skill_icon_bar.bind(player)
	var world := get_tree().current_scene.get_node_or_null("World")
	var world_rect: Rect2 = world.get_world_rect() if world and world.has_method("get_world_rect") else WORLD_CONFIG.WORLD_RECT
	var biome_zones: Array[Dictionary] = world.get_biome_zones() if world and world.has_method("get_biome_zones") else WORLD_CONFIG.get_biome_zones()
	minimap.bind(player, world_rect, biome_zones)
	map_screen.bind(player, evolution_director, day_night_system, world_rect, biome_zones)
	debug_panel.bind(player, evolution_director, day_night_system)


func _process(delta: float) -> void:
	if not player or not evolution_director or not day_night_system:
		return
	if center_notification_time > 0.0:
		center_notification_time = max(center_notification_time - delta, 0.0)
		center_notification_label.visible = center_notification_time > 0.0
	var clock_text: String = day_night_system.get_clock_time() if day_night_system.has_method("get_clock_time") else "--:--"
	var time_label: String = day_night_system.get_time_label() if day_night_system.has_method("get_time_label") else ""
	clock_label.text = "%s\n%s" % [clock_text, time_label]
	stats_label.text = "\n".join([
		"Health: %3d  Hunger: %3d  Stamina: %3d  Rest: %3d  %s" % [player.stats.health, player.stats.hunger, player.stats.stamina, player.stats.rest, player.stats.get_condition_text()],
		"Wood: %d  Stone: %d  Fiber: %d  Meat: %d  Torch: %d %s  Spear: %s" % [player.inventory.get_amount("wood"), player.inventory.get_amount("stone"), player.inventory.get_amount("fiber"), player.inventory.get_amount("meat"), player.inventory.get_amount("torch"), _get_torch_status_text(), "yes" if player.has_spear else "no"]
	])
	prompt_label.text = player.get_interaction_prompt() if player.has_method("get_interaction_prompt") else ""
	message_label.text = "\n".join(message_history)


func _on_message(new_message: String) -> void:
	message = new_message
	message_history.append(new_message)
	if message_history.size() > 4:
		message_history.pop_front()


func _on_game_event(event_name: String, payload: Dictionary) -> void:
	if event_name == "center_notification":
		_show_center_notification(str(payload.get("text", "")))


func _show_center_notification(text: String) -> void:
	if text.is_empty():
		return
	center_notification_label.text = text
	center_notification_label.visible = true
	center_notification_time = 2.0


func _get_torch_status_text() -> String:
	if not player.has_method("is_torch_active") or not player.is_torch_active():
		return "inactive"
	var remaining := int(ceil(player.get_torch_remaining_seconds())) if player.has_method("get_torch_remaining_seconds") else 0
	return "active %ds" % remaining


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		debug_panel.toggle()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		_set_pause_menu_open(false)
		_set_map_screen_open(not map_screen_open)
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_set_map_screen_open(false)
		_set_pause_menu_open(not pause_menu_open)
		get_viewport().set_input_as_handled()


func _set_map_screen_open(open: bool) -> void:
	map_screen_open = open
	map_screen.visible = open
	_update_tree_paused()
	map_screen.queue_redraw()


func _set_pause_menu_open(open: bool) -> void:
	pause_menu_open = open
	pause_menu.visible = open
	_update_tree_paused()


func _update_tree_paused() -> void:
	get_tree().paused = map_screen_open or pause_menu_open


func _on_pause_menu_resume() -> void:
	_set_pause_menu_open(false)


func _on_pause_menu_save() -> void:
	var save_system := get_tree().current_scene.get_node_or_null("SaveSystem")
	if save_system and save_system.has_method("save_game"):
		save_system.save_game()


func _on_pause_menu_load() -> void:
	var save_system := get_tree().current_scene.get_node_or_null("SaveSystem")
	if save_system and save_system.has_method("load_game"):
		save_system.load_game()


func _on_pause_menu_quit() -> void:
	get_tree().quit()
