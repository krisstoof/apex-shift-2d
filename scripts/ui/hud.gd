extends CanvasLayer

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const WORLD_SNAPSHOT_SERVICE := preload("res://scripts/systems/world_snapshot_service.gd")
const ECOSYSTEM_MESSAGE_COOLDOWN_SECONDS := 30.0
const HUD_REFRESH_INTERVAL := 0.10

var player: Node
var evolution_director: Node
var day_night_system: Node
var ecosystem_director: Node
var message := ""
var message_history: Array[String] = []
var map_screen_open := false
var pause_menu_open := false
var center_notification_time := 0.0
var hud_refresh_timer := 0.0
var hud_snapshot_build_ms: float = 0.0
var ecosystem_message_cooldowns: Dictionary = {}
var snapshot_service = WORLD_SNAPSHOT_SERVICE.new()

@onready var stats_label: Label = $Panel/StatsLabel
@onready var prompt_label: Label = $Panel/PromptLabel
@onready var message_label: Label = $Panel/MessageLabel
@onready var center_notification_label: Label = $CenterNotificationLabel
@onready var skill_icon_bar: Control = $SkillIconBar
@onready var minimap: Control = $Minimap
@onready var clock_label: Label = $ClockLabel
@onready var fps_label: Label = $FPSLabel
@onready var map_screen: Control = $MapScreen
@onready var pause_menu: Control = $PauseMenu
@onready var game_over_screen: Control = $GameOverScreen
@onready var debug_panel: Control = $DebugPanel
@onready var game_session: Node = get_node("/root/GameSession")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	center_notification_label.visible = false
	get_node("/root/EventBus").message_posted.connect(_on_message)
	get_node("/root/EventBus").game_event.connect(_on_game_event)
	pause_menu.resume_requested.connect(_on_pause_menu_resume)
	pause_menu.save_requested.connect(_on_pause_menu_save)
	pause_menu.load_requested.connect(_on_pause_menu_load)
	pause_menu.main_menu_requested.connect(_on_pause_menu_main_menu)
	pause_menu.quit_requested.connect(_on_pause_menu_quit)
	game_over_screen.restart_requested.connect(_on_game_over_restart)
	game_over_screen.load_save_requested.connect(_on_game_over_load_save)
	game_over_screen.main_menu_requested.connect(_on_game_over_main_menu)
	game_over_screen.exit_requested.connect(_on_game_over_quit)


func bind(p_player: Node, p_evolution_director: Node, p_day_night_system: Node, p_ecosystem_director: Node = null) -> void:
	player = p_player
	evolution_director = p_evolution_director
	day_night_system = p_day_night_system
	ecosystem_director = p_ecosystem_director
	skill_icon_bar.bind(player)
	var world := get_tree().current_scene.get_node_or_null("World")
	snapshot_service = WORLD_SNAPSHOT_SERVICE.new()
	snapshot_service.bind(player, evolution_director, day_night_system, ecosystem_director, world)
	var bind_snapshot_start_ms: int = Time.get_ticks_msec()
	var snapshot := snapshot_service.refresh(true)
	hud_snapshot_build_ms = float(Time.get_ticks_msec() - bind_snapshot_start_ms)
	var world_snapshot := Dictionary(snapshot.get("world", {}))
	var world_rect: Rect2 = Rect2(world_snapshot.get("world_rect", WORLD_CONFIG.WORLD_RECT))
	var biome_zones: Array[Dictionary] = Array(world_snapshot.get("biome_zones", WORLD_CONFIG.get_biome_zones()))
	var landmarks: Array[Dictionary] = Array(world_snapshot.get("landmarks", WORLD_CONFIG.get_landmarks()))
	minimap.bind(player, world_rect, biome_zones, landmarks, snapshot_service)
	map_screen.bind(player, evolution_director, day_night_system, world_rect, biome_zones, landmarks, snapshot_service)
	debug_panel.bind(player, evolution_director, day_night_system, ecosystem_director, snapshot_service)
	_apply_snapshot(snapshot)


func _process(delta: float) -> void:
	if not player or not evolution_director or not day_night_system:
		return
	_log_hitch(delta, "HUD", {
		"map_screen_open": map_screen_open,
		"pause_menu_open": pause_menu_open,
		"refresh_timer": hud_refresh_timer
	})
	if center_notification_time > 0.0:
		center_notification_time = max(center_notification_time - delta, 0.0)
		center_notification_label.visible = center_notification_time > 0.0
	hud_refresh_timer += delta
	if hud_refresh_timer < HUD_REFRESH_INTERVAL:
		return
	hud_refresh_timer = 0.0
	_refresh_hud_text()


func _refresh_hud_text() -> void:
	if not player or not evolution_director or not day_night_system:
		return
	var snapshot_start_ms: int = Time.get_ticks_msec()
	var snapshot: Dictionary
	if snapshot_service != null and snapshot_service.has_method("refresh_hud"):
		snapshot = snapshot_service.refresh_hud()
	elif snapshot_service != null and snapshot_service.has_method("refresh"):
		snapshot = snapshot_service.refresh()
	else:
		snapshot = {}
	hud_snapshot_build_ms = float(Time.get_ticks_msec() - snapshot_start_ms)
	_apply_snapshot(snapshot)


func _apply_snapshot(snapshot: Dictionary) -> void:
	clock_label.text = _build_clock_text_from_snapshot(snapshot)
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	stats_label.text = _build_stats_text_from_snapshot(snapshot)
	prompt_label.text = _get_prompt_text_from_snapshot(snapshot)
	message_label.text = "\n".join(message_history)


func _build_clock_text_from_snapshot(snapshot: Dictionary) -> String:
	var time_snapshot := Dictionary(snapshot.get("time", {}))
	return "%s\n%s" % [
		str(time_snapshot.get("clock_time", "--:--")),
		str(time_snapshot.get("time_label", ""))
	]


func _build_stats_text_from_snapshot(snapshot: Dictionary) -> String:
	var player_snapshot := Dictionary(snapshot.get("player", {}))
	var inventory := Dictionary(player_snapshot.get("inventory", {}))
	return "\n".join([
		"Health: %3d  Hunger: %3d  Stamina: %3d  Rest: %3d  %s%s" % [
			int(player_snapshot.get("health", 0)),
			int(player_snapshot.get("hunger", 0)),
			int(player_snapshot.get("stamina", 0)),
			int(player_snapshot.get("rest", 0)),
			str(player_snapshot.get("condition_text", "unknown")),
			" campfire_regen_active" if player_snapshot.get("campfire_regen_active", false) == true else ""
		],
		"Wood: %d  Stone: %d  Fiber: %d  Meat: %d  Torch: %d %s  Spear: %s  Bow: %s" % [
			int(inventory.get("wood", 0)),
			int(inventory.get("stone", 0)),
			int(inventory.get("fiber", 0)),
			int(inventory.get("meat", 0)),
			int(inventory.get("torch", 0)),
			_get_torch_status_text_from_snapshot(player_snapshot),
			"yes" if player_snapshot.get("has_spear", false) == true else "no",
			"yes" if player_snapshot.get("has_bow", false) == true else "no"
		]
	])


func _get_prompt_text_from_snapshot(snapshot: Dictionary) -> String:
	var player_snapshot := Dictionary(snapshot.get("player", {}))
	return str(player_snapshot.get("prompt_text", ""))


func _on_message(new_message: String) -> void:
	message = new_message
	message_history.append(new_message)
	if message_history.size() > 4:
		message_history.pop_front()


func _get_campfire_regen_status_text() -> String:
	if player and player.stats and player.stats.campfire_regen_active:
		return " campfire_regen_active"
	return ""


func _on_game_event(event_name: String, payload: Dictionary) -> void:
	if event_name == "center_notification":
		_show_center_notification(str(payload.get("text", "")))
		return
	_show_ecosystem_message(event_name, payload)


func _show_center_notification(text: String) -> void:
	if text.is_empty():
		return
	center_notification_label.text = text
	center_notification_label.visible = true
	center_notification_time = 2.0


func _show_ecosystem_message(event_name: String, payload: Dictionary) -> void:
	var message_text := _get_ecosystem_message(event_name, payload)
	if message_text.is_empty():
		return
	var biome_id := str(payload.get("biome_id", "global"))
	var cooldown_key := "%s:%s" % [event_name, biome_id]
	var now_seconds := Time.get_ticks_msec() / 1000.0
	var next_allowed := float(ecosystem_message_cooldowns.get(cooldown_key, 0.0))
	if now_seconds < next_allowed:
		return
	ecosystem_message_cooldowns[cooldown_key] = now_seconds + ECOSYSTEM_MESSAGE_COOLDOWN_SECONDS
	get_node("/root/EventBus").post_message(message_text)


func _get_ecosystem_message(event_name: String, payload: Dictionary) -> String:
	var biome_name := _get_ecosystem_biome_name(payload)
	match event_name:
		"ecosystem_biome_stressed":
			return "Vegetation in %s is thinning." % biome_name
		"ecosystem_biome_depleted":
			return "Animals in %s have less food." % biome_name
		"ecosystem_biome_collapsing":
			return "Vegetation in %s is close to collapse." % biome_name
		"grazer_niche_shifted":
			return "Grazers in %s are starting to hunt smaller animals." % biome_name
		"small_prey_population_declining":
			return "Small prey population in %s is declining." % biome_name
		"grazer_population_declining":
			return "Grazer population in %s is declining." % biome_name
	return ""


func _get_ecosystem_biome_name(payload: Dictionary) -> String:
	var biome_name := str(payload.get("name", ""))
	if not biome_name.is_empty():
		return biome_name
	var biome_id := str(payload.get("biome_id", ""))
	if ecosystem_director and ecosystem_director.has_method("get_biome_state"):
		var state: Dictionary = ecosystem_director.get_biome_state(biome_id)
		if not state.is_empty():
			return str(state.get("name", biome_id))
	return biome_id.capitalize() if not biome_id.is_empty() else "the wilds"


func _get_torch_status_text() -> String:
	if not player.has_method("is_torch_active") or not player.is_torch_active():
		return "inactive"
	var remaining := int(ceil(player.get_torch_remaining_seconds())) if player.has_method("get_torch_remaining_seconds") else 0
	return "active %ds" % remaining


func _get_torch_status_text_from_snapshot(player_snapshot: Dictionary) -> String:
	if player_snapshot.get("torch_active", false) != true:
		return "inactive"
	return "active %ds" % int(ceil(float(player_snapshot.get("torch_remaining_seconds", 0.0))))


func _log_hitch(delta: float, system_name: String, flags: Dictionary = {}) -> void:
	if delta <= 0.1:
		return
	var flag_text := ""
	for key in flags.keys():
		if not flag_text.is_empty():
			flag_text += " "
		flag_text += "%s=%s" % [str(key), str(flags.get(key))]
	print("[HITCH] %s delta=%.3f %s" % [system_name, delta, flag_text])


func show_game_over(day_survived: int, reason: String) -> void:
	_set_pause_menu_open(false)
	_set_map_screen_open(false)
	if game_over_screen.has_method("show_game_over"):
		game_over_screen.show_game_over(day_survived, reason)


func _close_game_over_screen() -> void:
	if game_over_screen.has_method("hide_game_over"):
		game_over_screen.hide_game_over()


func _unhandled_input(event: InputEvent) -> void:
	if game_over_screen.visible:
		return
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
	if open and map_screen.has_method("mark_map_cache_dirty"):
		map_screen.mark_map_cache_dirty()


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


func _on_pause_menu_main_menu() -> void:
	_set_pause_menu_open(false)
	_set_map_screen_open(false)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/start_menu.tscn")


func _on_pause_menu_quit() -> void:
	get_tree().quit()


func _on_game_over_restart() -> void:
	_close_game_over_screen()
	get_tree().paused = false
	game_session.request_new_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_game_over_load_save() -> void:
	_close_game_over_screen()
	get_tree().paused = false
	game_session.request_continue()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_game_over_main_menu() -> void:
	_close_game_over_screen()
	get_tree().paused = false
	game_session.request_new_game()
	get_tree().change_scene_to_file("res://scenes/ui/start_menu.tscn")


func _on_game_over_quit() -> void:
	get_tree().paused = false
	get_tree().quit()
