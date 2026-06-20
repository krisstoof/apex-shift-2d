extends CanvasLayer

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const ITEM_DATABASE := preload("res://scripts/items/item_database.gd")
const WORLD_SNAPSHOT_SERVICE := preload("res://scripts/systems/world_snapshot_service.gd")
const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const RUNTIME_PROFILER := preload("res://scripts/debug/runtime_profiler.gd")
const ECOSYSTEM_MESSAGE_COOLDOWN_SECONDS := 30.0
const HUD_REFRESH_INTERVAL := 0.10
const CRITICAL_HEALTH_THRESHOLD := 0.20
const CRITICAL_HEALTH_WARNING_INTERVAL_SECONDS := 8.0
const LOW_STAT_WARNING_THRESHOLD := 0.20
const LOW_STAT_PULSE_SPEED := 4.5
const LOW_STAT_PULSE_MIN := 0.96
const LOW_STAT_PULSE_MAX := 1.0
const LOW_HUNGER_THRESHOLD := 25.0
const LOW_STAMINA_THRESHOLD := 20.0
const LOW_REST_THRESHOLD := 25.0
const LOW_HEALTH_CAMPFIRE_HINT_THRESHOLD := 50.0
const HUNGER_WARNING_COOLDOWN_SECONDS := 12.0
const STARVING_WARNING_COOLDOWN_SECONDS := 10.0
const EXHAUSTION_WARNING_COOLDOWN_SECONDS := 14.0
const CAMPFIRE_HINT_COOLDOWN_SECONDS := 18.0
const HUD_MESSAGE_LIFETIME_SECONDS := 10.0
const CAMPFIRE_HINT_RADIUS := 180.0
const NEARBY_THREAT_CHECK_INTERVAL_SECONDS := 0.5
const NEARBY_THREAT_WARNING_COOLDOWN_SECONDS := 8.0
const NEARBY_THREAT_RADIUS := 260.0

var player: Node
var evolution_director: Node
var day_night_system: Node
var ecosystem_director: Node
var message := ""
var message_history: Array[String] = []
var message_history_timestamps: Array[float] = []
var map_screen_open := false
var pause_menu_open := false
var center_notification_time := 0.0
var hud_refresh_timer := 0.0
var hud_snapshot_build_ms: float = 0.0
var ecosystem_message_cooldowns: Dictionary = {}
var critical_health_overlay: ColorRect
var critical_health_pulse_time := 0.0
var critical_health_warning_timer := 0.0
var critical_health_active := false
var low_stat_warning_active := false
var low_stat_pulse_time := 0.0
var last_stats_snapshot: Dictionary = {}
var hunger_warning_timer := 0.0
var starving_warning_timer := 0.0
var exhaustion_warning_timer := 0.0
var campfire_hint_timer := 0.0
var nearby_threat_check_timer := 0.0
var nearby_threat_warning_timer := 0.0
var distance_debug_label: Label
var snapshot_service = WORLD_SNAPSHOT_SERVICE.new()
var hitch_log_cooldowns: Dictionary = {}
var current_storage_box: Node = null
var current_storage_inventory: Variant = null
var current_storage_player_inventory: Variant = null

@onready var stats_label: RichTextLabel = $Panel/StatsLabel
@onready var prompt_label: Label = $Panel/PromptLabel
@onready var message_label: Label = $Panel/MessageLabel
@onready var resource_panel: Control = $ResourcePanel
@onready var wood_resource_icon: TextureRect = $ResourcePanel/ResourceHBox/WoodItem/Icon
@onready var wood_resource_count_label: Label = $ResourcePanel/ResourceHBox/WoodItem/CountLabel
@onready var stone_resource_icon: TextureRect = $ResourcePanel/ResourceHBox/StoneItem/Icon
@onready var stone_resource_count_label: Label = $ResourcePanel/ResourceHBox/StoneItem/CountLabel
@onready var fiber_resource_icon: TextureRect = $ResourcePanel/ResourceHBox/FiberItem/Icon
@onready var fiber_resource_count_label: Label = $ResourcePanel/ResourceHBox/FiberItem/CountLabel
@onready var meat_resource_icon: TextureRect = $ResourcePanel/ResourceHBox/MeatItem/Icon
@onready var meat_resource_count_label: Label = $ResourcePanel/ResourceHBox/MeatItem/CountLabel
@onready var bone_resource_icon: TextureRect = $ResourcePanel/ResourceHBox/BoneItem/Icon
@onready var bone_resource_count_label: Label = $ResourcePanel/ResourceHBox/BoneItem/CountLabel
@onready var panel: Control = $Panel
@onready var center_notification_label: Label = $CenterNotificationLabel
@onready var skill_icon_bar: Control = $SkillIconBar
@onready var minimap: Control = $Minimap
@onready var clock_label: Label = $ClockLabel
@onready var fps_label: Label = $FPSLabel
@onready var map_screen: Control = $MapScreen
@onready var pause_menu: Control = $PauseMenu
@onready var game_over_screen: Control = $GameOverScreen
@onready var debug_panel: Control = $DebugPanel
@onready var inventory_screen: Control = $InventoryScreen
@onready var storage_box_screen: Control = $StorageBoxScreen
@onready var game_session: Node = get_node("/root/GameSession")


func _get_event_bus() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("EventBus")


func _connect_event_bus() -> void:
	var event_bus := _get_event_bus()
	if event_bus == null:
		return
	if event_bus.has_signal("message_posted"):
		event_bus.message_posted.connect(_on_message)
	if event_bus.has_signal("game_event"):
		event_bus.game_event.connect(_on_game_event)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	center_notification_label.visible = false
	_ensure_critical_health_overlay()
	_configure_resource_panel_style()
	_connect_event_bus()
	pause_menu.resume_requested.connect(_on_pause_menu_resume)
	pause_menu.save_requested.connect(_on_pause_menu_save)
	pause_menu.load_requested.connect(_on_pause_menu_load)
	pause_menu.main_menu_requested.connect(_on_pause_menu_main_menu)
	pause_menu.quit_requested.connect(_on_pause_menu_quit)
	game_over_screen.restart_requested.connect(_on_game_over_restart)
	game_over_screen.load_save_requested.connect(_on_game_over_load_save)
	game_over_screen.main_menu_requested.connect(_on_game_over_main_menu)
	game_over_screen.exit_requested.connect(_on_game_over_quit)
	_fix_low_resolution_layout()


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
	if inventory_screen.has_method("setup"):
		inventory_screen.setup(_get_player_inventory(), player)
	if storage_box_screen != null and storage_box_screen.has_method("setup"):
		storage_box_screen.visible = false
	_connect_inventory_changed()
	_apply_snapshot(snapshot)
	_refresh_resource_panel()
	_fix_low_resolution_layout()


func _process(delta: float) -> void:
	RUNTIME_PROFILER.begin_scope("hud_total_ms")
	if not player or not evolution_director or not day_night_system:
		RUNTIME_PROFILER.end_scope("hud_total_ms")
		return
	if bool(GAME_BALANCE.BIOME_TEXTURES.get("benchmark_collect_render_attribution", true)):
		RUNTIME_PROFILER.begin_scope("hud_process_ms")
	if bool(GAME_BALANCE.BIOME_TEXTURES.get("benchmark_collect_render_attribution", true)):
		RUNTIME_PROFILER.begin_scope("hud_process_logic_ms")
	_update_critical_health_warning(delta)
	_update_low_stat_warning(delta)
	_update_survival_warning_messages(delta)
	_update_nearby_threat_warning(delta)
	_log_hitch(delta, "HUD", {
		"map_screen_open": map_screen_open,
		"pause_menu_open": pause_menu_open,
		"refresh_timer": hud_refresh_timer
	})
	if center_notification_time > 0.0:
		center_notification_time = max(center_notification_time - delta, 0.0)
		center_notification_label.visible = center_notification_time > 0.0
	_prune_message_history()
	hud_refresh_timer += delta
	if hud_refresh_timer < HUD_REFRESH_INTERVAL:
		if bool(GAME_BALANCE.BIOME_TEXTURES.get("benchmark_collect_render_attribution", true)):
			RUNTIME_PROFILER.end_scope("hud_process_ms")
			RUNTIME_PROFILER.end_scope("hud_process_logic_ms")
		RUNTIME_PROFILER.end_scope("hud_total_ms")
		return
	hud_refresh_timer = 0.0
	_refresh_hud_text()
	if bool(GAME_BALANCE.BIOME_TEXTURES.get("benchmark_collect_render_attribution", true)):
		RUNTIME_PROFILER.end_scope("hud_process_ms")
		RUNTIME_PROFILER.end_scope("hud_process_logic_ms")
	RUNTIME_PROFILER.end_scope("hud_total_ms")


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
	last_stats_snapshot = snapshot.duplicate(true)
	clock_label.text = _build_clock_text_from_snapshot(snapshot)
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	_render_player_stats_text_from_snapshot(snapshot, 1.0)
	_update_low_stat_warning_style_from_snapshot(snapshot)
	prompt_label.text = _get_prompt_text_from_snapshot(snapshot)
	_refresh_message_label()
	_refresh_resource_panel()


func _build_clock_text_from_snapshot(snapshot: Dictionary) -> String:
	var time_snapshot := Dictionary(snapshot.get("time", {}))
	return "%s\n%s" % [
		str(time_snapshot.get("clock_time", "--:--")),
		str(time_snapshot.get("time_label", ""))
	]


func _build_player_stats_text_from_snapshot(snapshot: Dictionary) -> String:
	return _build_player_stats_markup_from_snapshot(snapshot, 1.0)


func _build_player_stats_markup_from_snapshot(snapshot: Dictionary, pulse_strength: float = 1.0) -> String:
	var player_snapshot := Dictionary(snapshot.get("player", {}))
	var time_snapshot := Dictionary(snapshot.get("time", {}))
	var health := float(player_snapshot.get("health", 0.0))
	var max_health := float(_get_player_max_health_value_from_snapshot(player_snapshot))
	var hunger := float(_get_snapshot_stat_percent(player_snapshot, "hunger", 100.0))
	var stamina := float(_get_snapshot_stat_percent(player_snapshot, "stamina", 100.0))
	var rest := float(_get_snapshot_stat_percent(player_snapshot, "rest", 100.0))
	var day := int(time_snapshot.get("day", 1))
	var time_label := str(time_snapshot.get("time_label", ""))
	var rest_label := "Rest" if player_snapshot.has("rest") else "Fatigue"
	var health_text := _format_player_stat_segment("HP: %d/%d" % [int(round(health)), int(round(max_health))], health / max_health if max_health > 0.0 else 0.0, pulse_strength)
	var hunger_text := _format_player_stat_segment("Hunger: %d%%" % int(round(hunger)), hunger / 100.0, pulse_strength)
	var rest_text := _format_player_stat_segment("%s: %d%%" % [rest_label, int(round(rest))], rest / 100.0, pulse_strength)
	var stamina_text := _format_player_stat_segment("Stamina: %d%%" % int(round(stamina)), stamina / 100.0, pulse_strength)
	return "%s   |   %s   |   %s   |   %s   |   Day: %d   |   Time: %s" % [
		health_text,
		hunger_text,
		rest_text,
		stamina_text,
		day,
		time_label if not time_label.is_empty() else "--"
	]


func _render_player_stats_text_from_snapshot(snapshot: Dictionary, pulse_strength: float = 1.0) -> void:
	if stats_label == null:
		return
	stats_label.clear()
	stats_label.append_text(_build_player_stats_markup_from_snapshot(snapshot, pulse_strength))


func _format_player_stat_segment(segment_text: String, ratio: float, pulse_strength: float) -> String:
	if ratio >= 0.0 and ratio <= LOW_STAT_WARNING_THRESHOLD:
		var pulse_color := Color(1.0, lerpf(0.18, 0.42, pulse_strength), lerpf(0.18, 0.42, pulse_strength), 1.0)
		return "[color=#%s]%s[/color]" % [pulse_color.to_html(false), segment_text]
	return segment_text


func _update_low_stat_warning(delta: float) -> void:
	if stats_label == null:
		return
	var player_node := _get_player_for_hud()
	if player_node == null or _is_game_over_active():
		_set_low_stat_warning_active(false)
		low_stat_pulse_time = 0.0
		_render_player_stats_text_from_snapshot(last_stats_snapshot, 1.0)
		return
	var should_be_active := _has_low_player_stat(player_node)
	_set_low_stat_warning_active(should_be_active)
	if not should_be_active:
		low_stat_pulse_time = 0.0
		_render_player_stats_text_from_snapshot(last_stats_snapshot, 1.0)
		return
	low_stat_pulse_time += delta
	var pulse := 0.5 + sin(low_stat_pulse_time * LOW_STAT_PULSE_SPEED) * 0.5
	var pulse_strength := lerpf(LOW_STAT_PULSE_MIN, LOW_STAT_PULSE_MAX, pulse)
	_render_player_stats_text_from_snapshot(last_stats_snapshot, pulse_strength)


func _update_low_stat_warning_style_from_snapshot(snapshot: Dictionary) -> void:
	if stats_label == null:
		return
	var player_snapshot := Dictionary(snapshot.get("player", {}))
	_set_low_stat_warning_active(_has_low_player_stat_from_snapshot(player_snapshot))


func _has_low_player_stat(player_node: Node) -> bool:
	var health := _get_player_health_value(player_node)
	var max_health := _get_player_max_health_value(player_node)
	var hunger := _get_player_stat_value(player_node, "hunger", 100.0)
	var stamina := _get_player_stat_value(player_node, "stamina", 100.0)
	var rest := _get_player_stat_value(player_node, "rest", 100.0)
	return _has_low_player_stat_values(health, max_health, hunger, stamina, rest)


func _has_low_player_stat_from_snapshot(player_snapshot: Dictionary) -> bool:
	var health := float(player_snapshot.get("health", 0.0))
	var max_health := float(_get_player_max_health_value_from_snapshot(player_snapshot))
	var hunger := float(_get_snapshot_stat_percent(player_snapshot, "hunger", 100.0))
	var stamina := float(_get_snapshot_stat_percent(player_snapshot, "stamina", 100.0))
	var rest := float(_get_snapshot_stat_percent(player_snapshot, "rest", 100.0))
	return _has_low_player_stat_values(health, max_health, hunger, stamina, rest)


func _has_low_player_stat_values(health: float, max_health: float, hunger_percent: float, stamina_percent: float, rest_percent: float) -> bool:
	if max_health <= 0.0:
		return false
	var health_ratio := clampf(health / max_health, 0.0, 1.0)
	var hunger_ratio := clampf(hunger_percent / 100.0, 0.0, 1.0)
	var stamina_ratio := clampf(stamina_percent / 100.0, 0.0, 1.0)
	var rest_ratio := clampf(rest_percent / 100.0, 0.0, 1.0)
	return health_ratio <= LOW_STAT_WARNING_THRESHOLD or hunger_ratio <= LOW_STAT_WARNING_THRESHOLD or stamina_ratio <= LOW_STAT_WARNING_THRESHOLD or rest_ratio <= LOW_STAT_WARNING_THRESHOLD


func _set_low_stat_warning_active(active: bool) -> void:
	low_stat_warning_active = active
	if stats_label == null:
		return
	if not active:
		stats_label.self_modulate = Color(1.0, 1.0, 1.0, 1.0)


func _get_player_max_health_value_from_snapshot(player_snapshot: Dictionary) -> float:
	var value := float(player_snapshot.get("max_health", 0.0))
	if value > 0.0:
		return value
	return float(PlayerStats.MAX_HEALTH)


func _get_hunger_status_label(hunger_percent: float) -> String:
	if hunger_percent <= 0.0:
		return "Starving"
	if hunger_percent <= LOW_HUNGER_THRESHOLD:
		return "Hungry"
	return ""


func _get_snapshot_stat_percent(player_snapshot: Dictionary, stat_name: String, max_value: float) -> float:
	var value := float(player_snapshot.get(stat_name, 0.0))
	if max_value <= 0.0:
		return 0.0
	return clampf(value / max_value * 100.0, 0.0, 100.0)


func _get_prompt_text_from_snapshot(snapshot: Dictionary) -> String:
	var player_snapshot := Dictionary(snapshot.get("player", {}))
	return str(player_snapshot.get("prompt_text", ""))


func _refresh_message_label() -> void:
	if message_label == null:
		return
	message_label.text = "\n".join(message_history)
	message_label.visible = message_history.size() > 0


func _prune_message_history() -> void:
	if message_history.is_empty():
		message_history_timestamps.clear()
		_refresh_message_label()
		return
	var now_seconds := Time.get_ticks_msec() / 1000.0
	var kept_messages: Array[String] = []
	var kept_timestamps: Array[float] = []
	for i in range(message_history.size()):
		var timestamp := float(message_history_timestamps[i]) if i < message_history_timestamps.size() else now_seconds
		if now_seconds - timestamp <= HUD_MESSAGE_LIFETIME_SECONDS:
			kept_messages.append(message_history[i])
			kept_timestamps.append(timestamp)
	message_history = kept_messages
	message_history_timestamps = kept_timestamps
	_refresh_message_label()


func _connect_inventory_changed() -> void:
	var inventory: Variant = _get_player_inventory()
	if inventory == null:
		return
	if inventory.has_signal("inventory_changed"):
		var changed_callable: Callable = Callable(self, "_on_inventory_changed")
		if not inventory.inventory_changed.is_connected(changed_callable):
			inventory.inventory_changed.connect(changed_callable)
	if inventory_screen != null and inventory_screen.has_method("refresh_from_inventory"):
		inventory_screen.refresh_from_inventory(inventory)


func _on_inventory_changed() -> void:
	_refresh_resource_panel()
	if inventory_screen != null and inventory_screen.visible and inventory_screen.has_method("refresh"):
		inventory_screen.refresh()
	if storage_box_screen != null and storage_box_screen.visible and storage_box_screen.has_method("refresh"):
		storage_box_screen.refresh()


func _refresh_resource_panel() -> void:
	if resource_panel == null:
		return
	var inventory: Variant = _get_player_inventory()
	if inventory == null:
		_set_resource_count(wood_resource_count_label, 0)
		_set_resource_count(stone_resource_count_label, 0)
		_set_resource_count(fiber_resource_count_label, 0)
		_set_resource_count(meat_resource_count_label, 0)
		_set_resource_count(bone_resource_count_label, 0)
		return
	_set_resource_icon(wood_resource_icon, "wood")
	_set_resource_icon(stone_resource_icon, "stone")
	_set_resource_icon(fiber_resource_icon, "fiber")
	_set_resource_icon(meat_resource_icon, "meat")
	_set_resource_icon(bone_resource_icon, "bone")
	_set_resource_count(wood_resource_count_label, _get_inventory_count(inventory, "wood"))
	_set_resource_count(stone_resource_count_label, _get_inventory_count(inventory, "stone"))
	_set_resource_count(fiber_resource_count_label, _get_inventory_count(inventory, "fiber"))
	_set_resource_count(meat_resource_count_label, _get_inventory_count(inventory, "meat"))
	_set_resource_count(bone_resource_count_label, _get_inventory_count(inventory, "bone"))
	_position_resource_panel()


func _get_player_inventory() -> Variant:
	if player == null:
		return null
	if player.has_method("get_inventory"):
		var method_inventory: Variant = player.call("get_inventory")
		if method_inventory != null:
			return method_inventory
	var fallback_inventory: Variant = player.get("inventory")
	if fallback_inventory != null:
		return fallback_inventory
	return null


func _get_inventory_count(inventory: Variant, item_id: String) -> int:
	if inventory == null:
		return 0
	if inventory.has_method("get_amount"):
		return int(inventory.call("get_amount", item_id))
	if inventory.has_method("get_item_count"):
		return int(inventory.call("get_item_count", item_id))
	if inventory.has_method("get_count"):
		return int(inventory.call("get_count", item_id))
	if inventory is Dictionary:
		return int(Dictionary(inventory).get(item_id, 0))
	return 0


func _set_resource_icon(icon_node: TextureRect, item_id: String) -> void:
	if icon_node == null:
		return
	icon_node.custom_minimum_size = Vector2(36, 36)
	icon_node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_node.modulate = ITEM_DATABASE.get_accent_color(item_id)
	var icon_path := ITEM_DATABASE.get_icon_path(item_id)
	if icon_path.is_empty():
		icon_node.texture = null
		return
	icon_node.texture = load(icon_path)


func _set_resource_count(label: Label, amount: int) -> void:
	if label == null:
		return
	label.text = str(amount)


func _configure_resource_panel_style() -> void:
	if resource_panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	resource_panel.add_theme_stylebox_override("panel", style)


func _position_resource_panel() -> void:
	if resource_panel == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var low_resolution: bool = viewport_size.x <= 1366.0 or viewport_size.y <= 768.0
	resource_panel.anchor_left = 0.0
	resource_panel.anchor_right = 0.0
	resource_panel.anchor_top = 1.0
	resource_panel.anchor_bottom = 1.0
	resource_panel.offset_left = 16.0
	resource_panel.offset_right = 420.0 if not low_resolution else 388.0
	resource_panel.offset_top = -88.0 if not low_resolution else -82.0
	resource_panel.offset_bottom = -20.0 if not low_resolution else -18.0




func _on_message(new_message: String) -> void:
	if new_message.is_empty():
		return
	if _is_world_or_ecosystem_message(new_message):
		return
	message = new_message
	message_history.append(new_message)
	message_history_timestamps.append(Time.get_ticks_msec() / 1000.0)
	if message_history.size() > 4:
		message_history.pop_front()
		if not message_history_timestamps.is_empty():
			message_history_timestamps.pop_front()
	_refresh_message_label()


func _ensure_critical_health_overlay() -> void:
	if critical_health_overlay != null:
		return
	critical_health_overlay = ColorRect.new()
	critical_health_overlay.name = "CriticalHealthOverlay"
	critical_health_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	critical_health_overlay.color = Color(1.0, 0.0, 0.0, 0.0)
	critical_health_overlay.visible = false
	critical_health_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	critical_health_overlay.offset_left = 0
	critical_health_overlay.offset_top = 0
	critical_health_overlay.offset_right = 0
	critical_health_overlay.offset_bottom = 0
	add_child(critical_health_overlay)
	critical_health_overlay.move_to_front()


func _update_critical_health_warning(delta: float) -> void:
	_ensure_critical_health_overlay()
	if game_over_screen != null and game_over_screen.visible:
		_set_critical_health_active(false)
		critical_health_pulse_time = 0.0
		critical_health_warning_timer = 0.0
		return
	var player_node := _get_player_for_hud()
	if player_node == null:
		_set_critical_health_active(false)
		return
	var health := _get_player_health_value(player_node)
	var max_health := _get_player_max_health_value(player_node)
	if max_health <= 0.0:
		_set_critical_health_active(false)
		return
	var health_ratio := health / max_health
	var should_be_active := health_ratio <= CRITICAL_HEALTH_THRESHOLD
	_set_critical_health_active(should_be_active)
	if not should_be_active:
		critical_health_pulse_time = 0.0
		critical_health_warning_timer = 0.0
		return
	critical_health_pulse_time += delta
	critical_health_warning_timer -= delta
	var pulse := 0.5 + sin(critical_health_pulse_time * 4.5) * 0.5
	var alpha := lerpf(0.06, 0.18, pulse)
	critical_health_overlay.color = Color(1.0, 0.0, 0.0, alpha)
	if critical_health_warning_timer <= 0.0:
		critical_health_warning_timer = CRITICAL_HEALTH_WARNING_INTERVAL_SECONDS
		_show_critical_health_message()


func _set_critical_health_active(active: bool) -> void:
	critical_health_active = active
	if critical_health_overlay == null:
		return
	critical_health_overlay.visible = active
	if not active:
		critical_health_overlay.color = Color(1.0, 0.0, 0.0, 0.0)


func _get_player_for_hud() -> Node:
	if player != null:
		return player
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node != null:
		return player_node
	var main := get_tree().current_scene
	if main != null:
		return main.get_node_or_null("Player")
	return null


func _get_player_health_value(player_node: Node) -> float:
	if player_node.has_method("get_health"):
		return float(player_node.get_health())
	var stats: Variant = player_node.get("stats")
	if stats != null and stats is Dictionary and stats.get("health") != null:
		return float(stats.get("health"))
	var value: Variant = player_node.get("health")
	if value != null:
		return float(value)
	value = player_node.get("current_health")
	if value != null:
		return float(value)
	return 0.0


func _get_player_max_health_value(player_node: Node) -> float:
	if player_node.has_method("get_max_health"):
		return float(player_node.get_max_health())
	var stats: Variant = player_node.get("stats")
	if stats != null and stats is Dictionary and stats.get("MAX_HEALTH") != null:
		return float(stats.get("MAX_HEALTH"))
	var value: Variant = player_node.get("max_health")
	if value != null:
		return float(value)
	return 100.0


func _show_critical_health_message() -> void:
	var message_text := "You are badly wounded. Heal yourself."
	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_method("post_message"):
		event_bus.post_message(message_text)


func _update_survival_warning_messages(delta: float) -> void:
	hunger_warning_timer = maxf(0.0, hunger_warning_timer - delta)
	starving_warning_timer = maxf(0.0, starving_warning_timer - delta)
	exhaustion_warning_timer = maxf(0.0, exhaustion_warning_timer - delta)
	campfire_hint_timer = maxf(0.0, campfire_hint_timer - delta)
	if _is_game_over_active():
		return
	var player_node := _get_player_for_hud()
	if player_node == null:
		return
	var hunger := _get_player_stat_value(player_node, "hunger", 100.0)
	var stamina := _get_player_stat_value(player_node, "stamina", 100.0)
	var rest := _get_player_stat_value(player_node, "rest", 100.0)
	var health := _get_player_stat_value(player_node, "health", 100.0)
	if hunger <= 0.0 and starving_warning_timer <= 0.0:
		_push_survival_message("You are starving and losing health. Eat food.")
		starving_warning_timer = STARVING_WARNING_COOLDOWN_SECONDS
		hunger_warning_timer = HUNGER_WARNING_COOLDOWN_SECONDS
	elif hunger <= LOW_HUNGER_THRESHOLD and hunger_warning_timer <= 0.0:
		_push_survival_message("You are hungry. Find food soon.")
		hunger_warning_timer = HUNGER_WARNING_COOLDOWN_SECONDS
	if (stamina <= LOW_STAMINA_THRESHOLD or rest <= LOW_REST_THRESHOLD) and exhaustion_warning_timer <= 0.0:
		_push_survival_message("You are exhausted. Rest near a campfire to recover faster.")
		exhaustion_warning_timer = EXHAUSTION_WARNING_COOLDOWN_SECONDS
	if health <= LOW_HEALTH_CAMPFIRE_HINT_THRESHOLD and _is_player_near_campfire(player_node) and campfire_hint_timer <= 0.0:
		_push_survival_message("Campfire speeds up rest and health regeneration.")
		campfire_hint_timer = CAMPFIRE_HINT_COOLDOWN_SECONDS


func _update_nearby_threat_warning(delta: float) -> void:
	nearby_threat_check_timer = maxf(0.0, nearby_threat_check_timer - delta)
	nearby_threat_warning_timer = maxf(0.0, nearby_threat_warning_timer - delta)
	if nearby_threat_check_timer > 0.0:
		return
	nearby_threat_check_timer = NEARBY_THREAT_CHECK_INTERVAL_SECONDS
	if nearby_threat_warning_timer > 0.0:
		return
	if _is_game_over_active():
		return
	var player_node := _get_player_for_hud()
	var player_2d := player_node as Node2D
	if player_2d == null:
		return
	if _has_nearby_varnak_threat(player_2d.global_position):
		_push_survival_message("Danger nearby. Move away or prepare to fight.")
		nearby_threat_warning_timer = NEARBY_THREAT_WARNING_COOLDOWN_SECONDS


func _has_nearby_varnak_threat(player_position: Vector2) -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var varnaks := tree.get_nodes_in_group("varnak")
	for node in varnaks:
		if not is_instance_valid(node):
			continue
		var varnak := node as Node2D
		if varnak == null:
			continue
		if varnak.global_position.distance_to(player_position) <= NEARBY_THREAT_RADIUS:
			return true
	return false


func _push_survival_message(message_text: String) -> void:
	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_method("post_message"):
		event_bus.post_message(message_text)


func _is_game_over_active() -> bool:
	if game_over_screen != null and game_over_screen.visible:
		return true
	if has_node("GameOverOverlay"):
		var overlay := get_node("GameOverOverlay") as CanvasItem
		if overlay != null:
			return overlay.visible
	if has_node("GameOverPanel"):
		var panel_overlay := get_node("GameOverPanel") as CanvasItem
		if panel_overlay != null:
			return panel_overlay.visible
	return false


func _get_player_stat_value(player_node: Node, stat_name: String, default_value: float) -> float:
	var value: Variant = player_node.get(stat_name)
	if value != null:
		return float(value)
	var getter_name := "get_%s" % stat_name
	if player_node.has_method(getter_name):
		return float(player_node.call(getter_name))
	var stats: Variant = player_node.get("stats")
	if stats != null:
		if stats is Dictionary:
			var stats_value: Variant = stats.get(stat_name)
			if stats_value != null:
				return float(stats_value)
			var uppercase_name := stat_name.to_upper()
			stats_value = stats.get(uppercase_name)
			if stats_value != null:
				return float(stats_value)
		else:
			var stats_value: Variant = stats.get(stat_name)
			if stats_value != null:
				return float(stats_value)
			var stats_getter_name := "get_%s" % stat_name
			if stats.has_method(stats_getter_name):
				return float(stats.call(stats_getter_name))
	return default_value


func _is_player_near_campfire(player_node: Node) -> bool:
	if player_node.has_method("is_near_campfire"):
		return player_node.call("is_near_campfire") == true
	var player_2d := player_node as Node2D
	if player_2d == null:
		return false
	var campfires := get_tree().get_nodes_in_group("campfires")
	for campfire in campfires:
		if not is_instance_valid(campfire):
			continue
		var campfire_2d := campfire as Node2D
		if campfire_2d == null:
			continue
		if player_2d.global_position.distance_to(campfire_2d.global_position) <= CAMPFIRE_HINT_RADIUS:
			return true
	return false


func get_survival_warning_debug() -> Dictionary:
	return {
		"hunger_warning_timer": hunger_warning_timer,
		"starving_warning_timer": starving_warning_timer,
		"exhaustion_warning_timer": exhaustion_warning_timer,
		"campfire_hint_timer": campfire_hint_timer,
		"nearby_threat_check_timer": nearby_threat_check_timer,
		"nearby_threat_warning_timer": nearby_threat_warning_timer
	}


func get_critical_health_debug() -> Dictionary:
	return {
		"active": critical_health_active,
		"threshold": CRITICAL_HEALTH_THRESHOLD,
		"warning_timer": critical_health_warning_timer,
		"overlay_visible": critical_health_overlay != null and critical_health_overlay.visible,
		"overlay_alpha": critical_health_overlay.color.a if critical_health_overlay != null else 0.0
	}


func _get_campfire_regen_status_text() -> String:
	if player and player.stats and player.stats.campfire_regen_active:
		return " campfire_regen_active"
	return ""


func _on_game_event(event_name: String, payload: Dictionary) -> void:
	if event_name == "center_notification":
		_show_center_notification(str(payload.get("text", "")))
		return
	return


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
	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_method("post_message"):
		event_bus.post_message(message_text)


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


func _is_world_or_ecosystem_message(message_text: String) -> bool:
	var blocked_fragments := [
		"Apex Shift 2D prototype ready",
		"entered the ecosystem",
		"dispersed into the ecosystem",
		"population in",
		"population declining",
		"is declining",
		"Vegetation in",
		"Animals in",
		"has less food",
		"close to collapse",
		"are starting to hunt",
		"biome",
		"ecosystem"
	]

	for fragment in blocked_fragments:
		if message_text.findn(fragment) >= 0:
			return true
	return false


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
	var now_ms := Time.get_ticks_msec()
	var last_log_ms := int(hitch_log_cooldowns.get(system_name, 0))
	if now_ms - last_log_ms < 5000:
		return
	hitch_log_cooldowns[system_name] = now_ms
	var flag_text := ""
	for key in flags.keys():
		if not flag_text.is_empty():
			flag_text += " "
		flag_text += "%s=%s" % [str(key), str(flags.get(key))]
	if bool(GAME_BALANCE.DEBUG_HITCH_VERBOSE_LOGGING):
		print("[HITCH] %s delta=%.3f %s" % [system_name, delta, flag_text])


func _fix_low_resolution_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var low_resolution: bool = viewport_size.x <= 1366.0 or viewport_size.y <= 768.0
	var compact_resolution: bool = viewport_size.x <= 1280.0 or viewport_size.y <= 720.0
	if panel:
		panel.offset_left = 8.0
		panel.offset_top = 8.0
		panel.offset_right = 720.0 if not low_resolution else 640.0
		panel.offset_bottom = 236.0 if not low_resolution else 220.0
		panel.custom_minimum_size = Vector2(0.0, 236.0 if not low_resolution else 220.0)
	if stats_label:
		stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats_label.custom_minimum_size = Vector2(520.0 if not low_resolution else 500.0, 0.0)
		stats_label.offset_right = 612.0 if not low_resolution else 540.0
		stats_label.offset_bottom = 90.0 if not low_resolution else 84.0
		stats_label.add_theme_font_size_override("font_size", 16 if not low_resolution else 14)
	if prompt_label:
		prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		prompt_label.custom_minimum_size = Vector2(520.0 if not low_resolution else 500.0, 0.0)
		prompt_label.offset_top = 98.0 if not low_resolution else 92.0
		prompt_label.offset_bottom = 124.0 if not low_resolution else 118.0
		prompt_label.add_theme_font_size_override("font_size", 16 if not low_resolution else 14)
	if message_label:
		message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		message_label.custom_minimum_size = Vector2(420.0 if not low_resolution else 360.0, 0.0)
		message_label.offset_top = 128.0 if not low_resolution else 122.0
		message_label.offset_bottom = 224.0 if not low_resolution else 210.0
		message_label.add_theme_font_size_override("font_size", 16 if not low_resolution else 13)
	_position_resource_panel()
	if wood_resource_count_label:
		wood_resource_count_label.add_theme_font_size_override("font_size", 16 if not low_resolution else 14)
	if stone_resource_count_label:
		stone_resource_count_label.add_theme_font_size_override("font_size", 16 if not low_resolution else 14)
	if fiber_resource_count_label:
		fiber_resource_count_label.add_theme_font_size_override("font_size", 16 if not low_resolution else 14)
	if meat_resource_count_label:
		meat_resource_count_label.add_theme_font_size_override("font_size", 16 if not low_resolution else 14)
	if bone_resource_count_label:
		bone_resource_count_label.add_theme_font_size_override("font_size", 16 if not low_resolution else 14)
	if skill_icon_bar:
		skill_icon_bar.anchor_left = 0.5
		skill_icon_bar.anchor_right = 0.5
		skill_icon_bar.anchor_top = 1.0
		skill_icon_bar.anchor_bottom = 1.0
		skill_icon_bar.offset_left = -507.0
		skill_icon_bar.offset_top = -92.0 if low_resolution else -104.0
		skill_icon_bar.offset_right = 507.0
		skill_icon_bar.offset_bottom = -32.0
	if minimap:
		minimap.anchor_left = 1.0
		minimap.anchor_right = 1.0
		minimap.offset_left = -436.0 if low_resolution else -476.0
		minimap.offset_top = 12.0
		minimap.offset_right = -16.0
		minimap.offset_bottom = 232.0 if low_resolution else 280.0
	if clock_label:
		clock_label.anchor_left = 1.0
		clock_label.anchor_right = 1.0
		clock_label.offset_left = -436.0 if low_resolution else -476.0
		clock_label.offset_top = 238.0 if low_resolution else 300.0
		clock_label.offset_right = -16.0
		clock_label.offset_bottom = 294.0 if low_resolution else 356.0
		clock_label.add_theme_font_size_override("font_size", 18 if low_resolution else 20)
	_refresh_message_label()
	if center_notification_label:
		center_notification_label.offset_left = -230.0 if compact_resolution else -260.0
		center_notification_label.offset_right = 230.0 if compact_resolution else 260.0
	if debug_panel:
		debug_panel.visible = debug_panel.visible and not low_resolution
		debug_panel.offset_left = -560.0 if not low_resolution else -520.0
		debug_panel.offset_right = -8.0
		debug_panel.offset_top = 12.0
		debug_panel.offset_bottom = -12.0
	if fps_label:
		fps_label.anchor_left = 1.0
		fps_label.anchor_right = 1.0
		fps_label.offset_left = -126.0 if low_resolution else -92.0
		fps_label.offset_top = 12.0
		fps_label.offset_right = -16.0
		fps_label.offset_bottom = 40.0
		fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


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
	if event.is_action_pressed("ui_cancel"):
		if storage_box_screen != null and storage_box_screen.visible:
			close_storage_box()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("toggle_inventory"):
		_set_inventory_screen_open(not inventory_screen.visible)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		debug_panel.toggle()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		_set_inventory_screen_open(false)
		_set_pause_menu_open(false)
		_set_map_screen_open(not map_screen_open)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if storage_box_screen != null and storage_box_screen.visible:
			close_storage_box()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if storage_box_screen != null and storage_box_screen.visible:
			close_storage_box()
			get_viewport().set_input_as_handled()
			return
		if inventory_screen.visible:
			_set_inventory_screen_open(false)
			get_viewport().set_input_as_handled()
			return
		_set_map_screen_open(false)
		_set_pause_menu_open(not pause_menu_open)
		get_viewport().set_input_as_handled()
		return


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


func _set_inventory_screen_open(open: bool) -> void:
	if inventory_screen == null:
		return
	if storage_box_screen != null and storage_box_screen.visible:
		_close_storage_box_screen()
	if inventory_screen.has_method("open_inventory") and open:
		inventory_screen.open_inventory()
	elif inventory_screen.has_method("close_inventory") and not open:
		inventory_screen.close_inventory()
	else:
		inventory_screen.visible = open
	if open:
		_set_map_screen_open(false)
		_set_pause_menu_open(false)
		if inventory_screen.has_method("refresh"):
			inventory_screen.refresh()
	_update_tree_paused()


func open_storage_box(p_player_inventory: Variant, p_storage_inventory: Variant, p_storage_box: Node) -> void:
	if storage_box_screen == null:
		_push_survival_message("Storage Box screen missing")
		return
	current_storage_box = p_storage_box
	current_storage_player_inventory = p_player_inventory
	current_storage_inventory = p_storage_inventory

	if inventory_screen != null and inventory_screen.visible:
		if inventory_screen.has_method("close_inventory"):
			inventory_screen.close_inventory()
		else:
			inventory_screen.visible = false

	_set_map_screen_open(false)
	_set_pause_menu_open(false)

	if storage_box_screen.has_method("setup"):
		storage_box_screen.setup(current_storage_player_inventory, current_storage_inventory, current_storage_box)
	if storage_box_screen.has_method("open_storage_box"):
		storage_box_screen.open_storage_box()
	else:
		storage_box_screen.visible = true
		storage_box_screen.show()
	storage_box_screen.move_to_front()

	_update_tree_paused()


func close_storage_box() -> void:
	current_storage_box = null
	current_storage_inventory = null
	current_storage_player_inventory = null
	if storage_box_screen == null:
		return
	if storage_box_screen.has_method("close_storage_box"):
		storage_box_screen.close_storage_box()
	else:
		storage_box_screen.visible = false
	_update_tree_paused()


func _close_storage_box_screen() -> void:
	close_storage_box()


func _update_tree_paused() -> void:
	var storage_box_open := storage_box_screen != null and storage_box_screen.visible
	get_tree().paused = map_screen_open or pause_menu_open or (inventory_screen != null and inventory_screen.visible) or storage_box_open


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
