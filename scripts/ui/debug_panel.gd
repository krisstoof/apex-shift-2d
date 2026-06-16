extends Control

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const DEBUG_TABS := [
	"Overview",
	"Player",
	"World",
	"Ecosystem",
	"Creatures",
	"Adaptation",
	"Combat",
	"Events",
	"Tools"
]
const DEBUG_STATE_REFRESH_INTERVAL := 0.5
const STATE_LABEL_MIN_SIZE := Vector2(680.0, 430.0)
const STATE_LINE_HEIGHT := 20.0

var player: Node
var evolution_director: Node
var day_night_system: Node
var ecosystem_director: Node
var snapshot_service
var active_tab := "Overview"
var tab_bar: TabBar
var tools_scroll: ScrollContainer
var tools_grid: GridContainer
var tool_buttons: Array[Button] = []
var state_refresh_timer := 0.0
var last_state_text := ""
var state_label_min_height := STATE_LABEL_MIN_SIZE.y
var last_nearest_creature_text: Dictionary = {}
var selected_debug_creatures: Dictionary = {}
var debug_panel_refresh_count: int = 0
var debug_panel_overlay_refresh_count: int = 0
var debug_panel_hidden_skip_count: int = 0
var benchmark_runner: Node
var benchmark_runner_script: Script
var benchmark_button: Button
var god_mode_button: Button
var regenerate_landmarks_button: Button
var island_world_validation_button: Button
var pool_test_button: Button
var landmark_overlay_button: Button
var rebuild_biome_cache_button: Button
var biome_texture_toggle_button: Button

@onready var title_label: Label = $Panel/TitleLabel
@onready var state_scroll: ScrollContainer = $Panel/StateScroll
@onready var state_label: Label = $Panel/StateScroll/StateLabel
@onready var add_wood_button: Button = $Panel/AddWoodButton
@onready var add_stone_button: Button = $Panel/AddStoneButton
@onready var add_fiber_button: Button = $Panel/AddFiberButton
@onready var add_meat_button: Button = $Panel/AddMeatButton
@onready var add_torch_button: Button = $Panel/AddTorchButton
@onready var add_spear_button: Button = $Panel/AddSpearButton
@onready var next_phase_button: Button = $Panel/NextPhaseButton
@onready var next_day_button: Button = $Panel/NextDayButton
@onready var increase_adaptation_button: Button = $Panel/IncreaseAdaptationButton
@onready var spawn_aggressive_button: Button = $Panel/SpawnAggressiveButton
@onready var spawn_neutral_button: Button = $Panel/SpawnNeutralButton
@onready var damage_player_button: Button = $Panel/DamagePlayerButton
@onready var heal_player_button: Button = $Panel/HealPlayerButton
@onready var reduce_hunger_energy_button: Button = $Panel/ReduceHungerEnergyButton
@onready var restore_hunger_energy_button: Button = $Panel/RestoreHungerEnergyButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_process(false)
	title_label.text = "Debug"
	_create_debug_tabs()
	_create_tools_container()
	add_wood_button.pressed.connect(_on_add_wood_pressed)
	add_stone_button.pressed.connect(_on_add_stone_pressed)
	add_fiber_button.pressed.connect(_on_add_fiber_pressed)
	add_meat_button.pressed.connect(_on_add_meat_pressed)
	add_torch_button.pressed.connect(_on_add_torch_pressed)
	add_spear_button.pressed.connect(_on_add_spear_pressed)
	next_phase_button.pressed.connect(_on_next_phase_pressed)
	next_day_button.pressed.connect(_on_next_day_pressed)
	increase_adaptation_button.pressed.connect(_on_increase_adaptation_pressed)
	spawn_aggressive_button.pressed.connect(_on_spawn_aggressive_pressed)
	spawn_neutral_button.pressed.connect(_on_spawn_neutral_pressed)
	damage_player_button.pressed.connect(_on_damage_player_pressed)
	heal_player_button.pressed.connect(_on_heal_player_pressed)
	reduce_hunger_energy_button.pressed.connect(_on_reduce_hunger_energy_pressed)
	restore_hunger_energy_button.pressed.connect(_on_restore_hunger_energy_pressed)
	_register_existing_tool_buttons()
	_create_ecosystem_buttons()
	_create_future_tool_buttons()
	_update_active_tab_view()


func bind(p_player: Node, p_evolution_director: Node, p_day_night_system: Node, p_ecosystem_director: Node = null, p_snapshot_service = null) -> void:
	player = p_player
	evolution_director = p_evolution_director
	day_night_system = p_day_night_system
	ecosystem_director = p_ecosystem_director
	snapshot_service = p_snapshot_service


func _process(_delta: float) -> void:
	if not visible:
		debug_panel_hidden_skip_count += 1
		return
	state_refresh_timer += _delta
	if state_refresh_timer < DEBUG_STATE_REFRESH_INTERVAL:
		return
	state_refresh_timer = 0.0
	_set_state_text(_build_state_text())
	debug_panel_refresh_count += 1
	if active_tab == "Creatures":
		_refresh_creature_debug_overlays()


func toggle() -> void:
	set_open(not visible)


func set_open(open: bool) -> void:
	if visible == open:
		return
	visible = open
	set_process(open)
	state_refresh_timer = 0.0
	if state_label == null or state_scroll == null:
		return
	if visible:
		_update_active_tab_view()
		_set_state_text(_build_state_text(), true)
		if active_tab == "Creatures":
			_refresh_creature_debug_overlays()
	else:
		last_state_text = ""


func _refresh_creature_debug_overlays() -> void:
	if not is_inside_tree():
		return
	if not visible:
		return
	debug_panel_overlay_refresh_count += 1
	for group_name in ["small_prey", "grazer", "varnak"]:
		for creature in _get_cached_group_nodes(group_name):
			if is_instance_valid(creature) and creature is CanvasItem:
				(creature as CanvasItem).queue_redraw()


func _set_state_text(text: String, force_update := false) -> void:
	if not force_update and text == last_state_text:
		return
	if state_label == null:
		return
	last_state_text = text
	state_label.text = text
	var line_count := text.split("\n").size()
	state_label_min_height = max(state_label_min_height, max(STATE_LABEL_MIN_SIZE.y, float(line_count) * STATE_LINE_HEIGHT))
	state_label.custom_minimum_size = Vector2(STATE_LABEL_MIN_SIZE.x, state_label_min_height)


func _create_debug_tabs() -> void:
	tab_bar = TabBar.new()
	tab_bar.name = "TabBar"
	tab_bar.anchor_right = 1.0
	tab_bar.offset_left = 12.0
	tab_bar.offset_top = 44.0
	tab_bar.offset_right = -12.0
	tab_bar.offset_bottom = 76.0
	tab_bar.clip_tabs = true
	for tab_name in DEBUG_TABS:
		tab_bar.add_tab(tab_name)
	tab_bar.tab_changed.connect(_on_debug_tab_changed)
	$Panel.add_child(tab_bar)
	state_scroll.anchor_right = 1.0
	state_scroll.anchor_bottom = 1.0
	state_scroll.offset_top = 86.0
	state_scroll.offset_right = -12.0
	state_scroll.offset_bottom = -12.0


func _create_tools_container() -> void:
	tools_scroll = ScrollContainer.new()
	tools_scroll.name = "ToolsScroll"
	tools_scroll.anchor_right = 1.0
	tools_scroll.anchor_top = 1.0
	tools_scroll.anchor_bottom = 1.0
	tools_scroll.offset_left = 12.0
	tools_scroll.offset_top = -176.0
	tools_scroll.offset_right = -12.0
	tools_scroll.offset_bottom = -12.0
	tools_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tools_scroll.visible = false
	$Panel.add_child(tools_scroll)
	tools_grid = GridContainer.new()
	tools_grid.name = "ToolsGrid"
	tools_grid.columns = 2
	tools_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tools_scroll.add_child(tools_grid)


func _register_existing_tool_buttons() -> void:
	add_fiber_button.text = "Add fiber"
	add_spear_button.text = "Give spear"
	spawn_aggressive_button.text = "Spawn aggressive Varnak"
	spawn_neutral_button.text = "Spawn neutral Varnak"
	damage_player_button.text = "Damage player"
	reduce_hunger_energy_button.text = "Reduce hunger/stamina"
	restore_hunger_energy_button.text = "Restore hunger/stamina"
	_add_tool_button_node(add_wood_button, "Player")
	_add_tool_button_node(add_stone_button, "Player")
	_add_tool_button_node(add_fiber_button, "Player")
	_add_tool_button_node(add_meat_button, "Player")
	_add_tool_button_node(add_torch_button, "Player")
	_add_tool_button_node(damage_player_button, "Player")
	_add_tool_button_node(heal_player_button, "Player")
	_add_tool_button_node(reduce_hunger_energy_button, "Player")
	_add_tool_button_node(restore_hunger_energy_button, "Player")
	_add_tool_button_node(next_phase_button, "World")
	_add_tool_button_node(next_day_button, "World")
	_add_tool_button_node(spawn_aggressive_button, "Creatures")
	_add_tool_button_node(spawn_neutral_button, "Creatures")
	increase_adaptation_button.text = "Force adaptation step"
	_add_tool_button_node(increase_adaptation_button, "Adaptation")
	_add_tool_button_node(add_spear_button, "Combat")


func _add_tool_button_node(button: Button, tab_name := "Tools") -> void:
	if not button or not tools_grid:
		return
	if button.get_parent():
		button.get_parent().remove_child(button)
	tools_grid.add_child(button)
	button.set_meta("debug_tab", tab_name)
	button.custom_minimum_size = Vector2(270.0, 34.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tool_buttons.append(button)


func _add_tool_button(label: String, callback: Callable, tab_name := "Tools") -> Button:
	var button := Button.new()
	button.text = label
	button.pressed.connect(callback)
	_add_tool_button_node(button, tab_name)
	return button


func _on_debug_tab_changed(tab: int) -> void:
	active_tab = tab_bar.get_tab_title(tab)
	last_state_text = ""
	state_refresh_timer = 0.0
	state_label_min_height = STATE_LABEL_MIN_SIZE.y
	_update_active_tab_view()
	_set_state_text(_build_state_text(), true)


func _update_active_tab_view() -> void:
	if state_scroll == null:
		return
	var has_tab_buttons := _update_tool_buttons_for_active_tab()
	_refresh_world_debug_buttons()
	state_scroll.visible = true
	state_scroll.offset_bottom = -194.0 if has_tab_buttons else -12.0
	if tools_scroll:
		tools_scroll.visible = has_tab_buttons


func _update_tool_buttons_for_active_tab() -> bool:
	if tool_buttons.is_empty():
		return false
	var visible_count := 0
	for button in tool_buttons:
		var is_tab_button := str(button.get_meta("debug_tab", "")) == active_tab
		button.visible = is_tab_button
		if is_tab_button:
			visible_count += 1
	return visible_count > 0


func _create_ecosystem_buttons() -> void:
	_add_tool_button("Reduce plant biomass", _on_reduce_plants_pressed, "Ecosystem")
	_add_tool_button("Restore plant biomass", _on_restore_plants_pressed, "Ecosystem")
	_add_tool_button("Force ecosystem tick", _on_advance_ecosystem_tick_pressed, "Ecosystem")
	_add_tool_button("Force grazer food stress", _on_force_food_stress_pressed, "Ecosystem")
	_add_tool_button("Force niche shift check", _on_force_niche_check_pressed, "Ecosystem")
	_add_tool_button("Spawn SmallPrey", _on_add_small_prey_pressed, "Creatures")
	_add_tool_button("Remove SmallPrey", _on_remove_small_prey_pressed, "Creatures")
	_add_tool_button("Spawn Grazer", _on_add_grazers_pressed, "Creatures")
	_add_tool_button("Remove Grazer", _on_remove_grazers_pressed, "Creatures")


func _create_future_tool_buttons() -> void:
	_add_tool_button("Give bow", _on_give_bow_pressed, "Combat")
	_add_tool_button("Advance growth 1 day", _on_advance_resource_growth_pressed, "World")
	_add_tool_button("Force vegetation regrowth", _on_force_full_vegetation_regrowth_pressed, "Ecosystem")
	_add_tool_button("Reset resource growth", _on_reset_resource_growth_pressed, "World")
	_add_tool_button("Teleport OOB creatures", _on_teleport_out_of_bounds_pressed, "Creatures")
	regenerate_landmarks_button = _add_tool_button("Regenerate landmarks", _on_regenerate_landmarks_pressed, "World")
	island_world_validation_button = _add_tool_button("Validate island world", _on_validate_island_world_pressed, "World")
	pool_test_button = _add_tool_button("Test object pool", _on_test_object_pool_pressed, "Tools")
	landmark_overlay_button = _add_tool_button("Landmark overlay: OFF", _on_toggle_landmark_overlay_pressed, "World")
	rebuild_biome_cache_button = _add_tool_button("Rebuild biome texture cache", _on_rebuild_biome_texture_cache_pressed, "World")
	biome_texture_toggle_button = _add_tool_button("Biome textures: ON", _on_toggle_biome_textures_pressed, "World")
	god_mode_button = _add_tool_button("God Mode: OFF", _on_toggle_god_mode_pressed, "Tools")
	benchmark_button = _add_tool_button("Run 60s benchmark", _on_run_benchmark_pressed, "Tools")


func _build_state_text() -> String:
	if not player or not evolution_director or not day_night_system:
		return "Waiting for game state..."
	var profile: Dictionary = evolution_director.get_profile() if evolution_director.has_method("get_profile") else {}
	match active_tab:
		"Player":
			return _build_player_text()
		"World":
			return _build_world_text()
		"Ecosystem":
			return _build_ecosystem_text()
		"Creatures":
			return _build_creatures_text()
		"Adaptation":
			return _build_evolution_text(profile)
		"Combat":
			return _build_combat_text()
		"Events":
			return _build_events_text(profile)
		"Tools":
			return _build_tools_text()
		_:
			return _build_overview_text(profile)


func _build_overview_text(profile: Dictionary) -> String:
	var snapshot := _get_snapshot()
	var player_snapshot := Dictionary(snapshot.get("player", {}))
	var time_snapshot := Dictionary(snapshot.get("time", {}))
	var debug_snapshot := Dictionary(snapshot.get("debug", {}))
	var ecosystem_snapshot := Dictionary(snapshot.get("ecosystem", {}))
	var world_snapshot := Dictionary(snapshot.get("world", {}))
	var varnak_population := Dictionary(world_snapshot.get("varnak_population", {}))
	var ai_state_counts := Dictionary(world_snapshot.get("creature_ai_state_counts", {}))
	var lines: Array[String] = []
	lines.append("Day %d | %s | night %.2f" % [
		int(time_snapshot.get("day", _get_day())),
		str(time_snapshot.get("phase_label", _get_day_phase())),
		float(time_snapshot.get("night_amount", _get_night_amount()))
	])
	lines.append("Player HP %d | H %d | Sta %d | Rest %d | campfire_regen_active %s" % [
		int(player_snapshot.get("health", int(player.stats.health))),
		int(player_snapshot.get("hunger", int(player.stats.hunger))),
		int(player_snapshot.get("stamina", int(player.stats.stamina))),
		int(player_snapshot.get("rest", int(player.stats.rest))),
		"yes" if player_snapshot.get("campfire_regen_active", false) == true else _get_campfire_regen_active_text()
	])
	lines.append("God mode %s" % _get_god_mode_state_text())
	lines.append("Biome %s" % str(debug_snapshot.get("current_biome_name", _get_current_biome_name())))
	lines.append("Live Varnaks %d | SmallPrey %d | Grazers %d" % [
		int(debug_snapshot.get("live_varnaks", _get_cached_group_nodes("varnak").size())),
		int(Dictionary(ecosystem_snapshot.get("population_totals", {})).get("small_prey_population", _get_ecosystem_population_total("small_prey_population"))),
		int(Dictionary(ecosystem_snapshot.get("population_totals", {})).get("grazer_population", _get_ecosystem_population_total("grazer_population")))
	])
	lines.append("Varnak pressure: day %d | target %d | live %d | max %d" % [
		int(varnak_population.get("day", time_snapshot.get("day", _get_day()))),
		int(varnak_population.get("target", 0)),
		int(varnak_population.get("live", debug_snapshot.get("live_varnaks", 0))),
		int(varnak_population.get("max", 0))
	])
	lines.append("AI states: prey %s | grazers %s | varnaks %s" % [
		_get_ai_state_summary_text(Dictionary(ai_state_counts.get("small_prey", {})), ["wandering", "hungry", "eating", "fleeing"]),
		_get_ai_state_summary_text(Dictionary(ai_state_counts.get("grazer", {})), ["wandering", "hungry", "eating", "fleeing"]),
		_get_ai_state_summary_text(Dictionary(ai_state_counts.get("varnak", {})), ["wandering", "hungry", "hunting", "fleeing"])
	])
	lines.append("creatures_out_of_bounds_count = %d" % int(Dictionary(snapshot.get("world", {})).get("out_of_bounds_count", _get_creatures_out_of_bounds_count())))
	lines.append("Ecosystem warnings: %s" % str(ecosystem_snapshot.get("warnings_text", _get_ecosystem_warnings_text())))
	lines.append("Generation %d" % int(Dictionary(snapshot.get("evolution", {})).get("generation", int(profile.get("generation", 1)))))
	return "\n".join(lines)


func _build_player_text() -> String:
	var snapshot := _get_snapshot()
	var player_snapshot := Dictionary(snapshot.get("player", {}))
	var inventory_snapshot := Dictionary(player_snapshot.get("inventory", {}))
	var world_snapshot := Dictionary(snapshot.get("world", {}))
	var lines: Array[String] = []
	lines.append("Player")
	lines.append("Health %d | Hunger %d | Stamina %d | Rest %d" % [
		int(player_snapshot.get("health", int(player.stats.health))),
		int(player_snapshot.get("hunger", int(player.stats.hunger))),
		int(player_snapshot.get("stamina", int(player.stats.stamina))),
		int(player_snapshot.get("rest", int(player.stats.rest)))
	])
	lines.append("God mode %s" % _get_god_mode_state_text())
	lines.append("campfire_regen_active %s | stamina_regen %.1f/s | distance %s" % [
		"yes" if player_snapshot.get("campfire_regen_active", false) == true else _get_campfire_regen_active_text(),
		player.stats.get_stamina_regen_rate(),
		("%.0fpx" % float(player_snapshot.get("campfire_regen_distance", -1.0))) if float(player_snapshot.get("campfire_regen_distance", -1.0)) >= 0.0 else _get_campfire_regen_distance_text()
	])
	lines.append("Inventory")
	lines.append("Wood %d | Stone %d | Fiber %d | Meat %d | Bone %d" % [
		int(inventory_snapshot.get("wood", _get_item_count("wood"))),
		int(inventory_snapshot.get("stone", _get_item_count("stone"))),
		int(inventory_snapshot.get("fiber", _get_item_count("fiber"))),
		int(inventory_snapshot.get("meat", _get_item_count("meat"))),
		int(inventory_snapshot.get("bone", _get_item_count("bone")))
	])
	lines.append("Torch %d | %s" % [
		int(inventory_snapshot.get("torch", _get_item_count("torch"))),
		_get_torch_state()
	])
	lines.append("Spear %s | Bow %s" % [
		"yes" if player_snapshot.get("has_spear", player and player.get("has_spear")) == true else "no",
		"yes" if player_snapshot.get("has_bow", player and player.get("has_bow")) == true else "no"
	])
	lines.append("Campfire %s | Traps %d" % [
		_get_campfire_state(),
		int(Dictionary(world_snapshot.get("building_counts", {})).get("traps", _get_cached_group_nodes("traps").size()))
	])
	return "\n".join(lines)


func _build_world_text() -> String:
	var snapshot := _get_snapshot()
	var world_snapshot := Dictionary(snapshot.get("world", {}))
	var landmark_counts := Dictionary(world_snapshot.get("landmark_counts", _get_world_landmark_counts()))
	var resource_counts := Dictionary(world_snapshot.get("resource_counts", {}))
	var building_counts := Dictionary(world_snapshot.get("building_counts", {}))
	var lines: Array[String] = []
	lines.append("World")
	lines.append("Current biome: %s" % str(world_snapshot.get("current_biome_name", _get_current_biome_name())))
	lines.append("World seed: %s | biome texture: %s" % [
		str(world_snapshot.get("world_seed", _get_world_seed_text())),
		str(world_snapshot.get("current_biome_texture_id", _get_current_biome_texture_id_text()))
	])
	lines.append("Generation: %s" % _get_world_generation_summary_text())
	var generation_debug := Dictionary(world_snapshot.get("world_generation_debug", {}))
	if not generation_debug.is_empty():
		var terrain := Dictionary(generation_debug.get("terrain", {}))
		var coverage := Dictionary(generation_debug.get("terrain_coverage", {}))
		lines.append("Terrain: ocean %.2f | land %.2f | pond %.2f | highland %.2f | moisture %.2f | danger %.2f" % [
			float(coverage.get("ocean", 0.0)),
			float(coverage.get("land", 0.0)),
			float(coverage.get("pond", 0.0)),
			float(coverage.get("highland", 0.0)),
			float(generation_debug.get("moisture_average", 0.0)),
			float(generation_debug.get("danger_average", 0.0))
		])
		lines.append("Terrain counts: ocean %d | shore %d | pond %d | highland %d | land %d" % [
			int(terrain.get("deep_ocean", 0)) + int(terrain.get("shallow_water", 0)),
			int(terrain.get("shore", 0)),
			int(terrain.get("pond", 0)),
			int(terrain.get("highland", 0)),
			int(terrain.get("land", 0))
		])
	lines.append("Player position: %s" % _get_position_text(Vector2(Dictionary(snapshot.get("player", {})).get("position", player.global_position if player else Vector2.ZERO))))
	lines.append("World bounds: %s" % str(WORLD_CONFIG.WORLD_RECT))
	lines.append("creatures_out_of_bounds_count = %d" % int(world_snapshot.get("out_of_bounds_count", _get_creatures_out_of_bounds_count())))
	lines.append("Chunks: %s" % _get_chunk_debug_text())
	lines.append("Spatial index: %s" % _get_spatial_index_debug_text())
	lines.append("Campfires: %d | Traps: %d" % [
		int(building_counts.get("campfires", _get_cached_group_nodes("campfires").size())),
		int(building_counts.get("traps", _get_cached_group_nodes("traps").size()))
	])
	lines.append("Resources: trees %d | bushes %d | grass %d | rocks %d" % [
		int(resource_counts.get("trees", _get_cached_group_nodes("trees").size())),
		int(resource_counts.get("bushes", _get_cached_group_nodes("bushes").size())),
		int(resource_counts.get("grass", _get_cached_group_nodes("grass").size())),
		int(resource_counts.get("rocks", _get_cached_group_nodes("rocks").size()))
	])
	var resource_distribution := Dictionary(world_snapshot.get("resource_distribution_by_biome", {}))
	if not resource_distribution.is_empty():
		lines.append("Resource distribution by biome:")
		for biome_id in resource_distribution.keys():
			var biome_counts := Dictionary(resource_distribution.get(biome_id, {}))
			lines.append("%s trees %d bushes %d grass %d rocks %d ponds %d" % [
				str(biome_id),
				int(biome_counts.get("trees", 0)),
				int(biome_counts.get("bushes", 0)),
				int(biome_counts.get("grass", 0)),
				int(biome_counts.get("rocks", 0)),
				int(biome_counts.get("pond_vegetation", 0))
			])
	lines.append("Landmarks: %s | generated %d" % [_get_landmark_summary_text(), int(landmark_counts.get("generated", 0))])
	lines.append("Ponds %d | Hills %d | nearest %s" % [
		int(landmark_counts.get("pond", 0)),
		int(landmark_counts.get("hill", 0)),
		_get_nearest_landmark_text()
	])
	lines.append("Island validation: %s" % _get_island_world_validation_summary_text())
	lines.append("Hill markers: %d" % _get_cached_group_nodes("hill_landmarks").size())
	lines.append("Pond markers: %d | Water sources: %d" % [
		_get_cached_group_nodes("pond_landmarks").size(),
		_get_cached_group_nodes("water_sources").size()
	])
	lines.append("Topography: %s" % _get_topography_debug_text())
	lines.append("Biome debug: %s" % _get_biome_debug_text())
	lines.append("Transition: %s" % _get_biome_transition_text())
	lines.append("Pond vegetation: %d" % _get_cached_group_nodes("pond_vegetation").size())
	lines.append("Decorative vegetation: %s" % _get_decorative_vegetation_text())
	lines.append("Biome detail overlay: %s" % _get_biome_detail_overlay_text())
	lines.append("Biome texture cache: %s" % _get_biome_texture_cache_status_text())
	lines.append("Landmark overlay %s | Biome textures %s" % [
		_get_landmark_overlay_state_text(),
		_get_biome_texture_state_text()
	])
	lines.append("Growth: %s" % _get_resource_growth_text())
	return "\n".join(lines)


func _build_ecosystem_text() -> String:
	var snapshot := _get_snapshot()
	var ecosystem_snapshot := Dictionary(snapshot.get("ecosystem", {}))
	if not ecosystem_snapshot.is_empty():
		return "\n".join(_get_ecosystem_debug_lines_from_snapshot(ecosystem_snapshot))
	return "\n".join(_get_ecosystem_debug_lines())


func _build_creatures_text() -> String:
	var snapshot := _get_snapshot()
	var varnak_population := Dictionary(Dictionary(snapshot.get("world", {})).get("varnak_population", {}))
	var lines: Array[String] = []
	var varnaks := _get_cached_group_nodes("varnak")
	lines.append("Creatures")
	lines.append("creatures_out_of_bounds_count = %d" % _get_creatures_out_of_bounds_count())
	lines.append_array(_get_population_aggregate_lines())
	lines.append("Varnak population: day %d | target %d | live %d | max %d" % [
		int(varnak_population.get("day", _get_day())),
		int(varnak_population.get("target", 0)),
		int(varnak_population.get("live", varnaks.size())),
		int(varnak_population.get("max", 0))
	])
	lines.append("Varnaks %d | %s" % [varnaks.size(), _get_varnak_state_summary(varnaks)])
	lines.append("SmallPrey visible %d | %s" % [
		_get_cached_group_nodes("small_prey").size(),
		_get_creature_state_summary("small_prey")
	])
	lines.append("SmallPrey LOD %s" % _get_simulation_level_counts_text("small_prey"))
	lines.append("Grazers visible %d | %s" % [
		_get_cached_group_nodes("grazer").size(),
		_get_grazer_state_summary()
	])
	lines.append("Grazer LOD %s" % _get_simulation_level_counts_text("grazer"))
	lines.append("Avg Varnak HP %s" % _get_average_varnak_health_text(varnaks))
	lines.append("Varnak LOD %s" % _get_simulation_level_counts_text("varnak"))
	lines.append_array(_get_creature_debug_stat_lines("varnak", "Varnak stats"))
	lines.append_array(_get_creature_debug_stat_lines("small_prey", "SmallPrey stats"))
	lines.append_array(_get_creature_debug_stat_lines("grazer", "Grazer stats"))
	return "\n".join(lines)


func _build_evolution_text(profile: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("Adaptation")
	lines.append("Generation %d | pressure %.2f" % [
		int(profile.get("generation", 1)),
		_get_adaptation_pressure(profile)
	])
	lines.append("Days %d/%d" % [
		int(evolution_director.get("days_since_generation")) if evolution_director.get("days_since_generation") != null else 0,
		int(evolution_director.get("days_until_next_generation")) if evolution_director.get("days_until_next_generation") != null else 0
	])
	lines.append("Aggression %.2f | fire fear %.2f | trap awareness %.2f" % [
		float(profile.get("aggression", 0.0)),
		float(profile.get("fire_fear", 0.0)),
		float(profile.get("trap_awareness", 0.0))
	])
	lines.append("Pack %.2f | night %.2f | curiosity %.2f | stalk %.2f" % [
		float(profile.get("pack_coordination", 0.0)),
		float(profile.get("night_activity", 0.0)),
		float(profile.get("base_curiosity", 0.0)),
		float(profile.get("stalk_tendency", 0.0))
	])
	return "\n".join(lines)


func _build_combat_text() -> String:
	var snapshot := _get_snapshot()
	var player_snapshot := Dictionary(snapshot.get("player", {}))
	var debug_snapshot := Dictionary(snapshot.get("debug", {}))
	var lines: Array[String] = []
	lines.append("Combat")
	lines.append("Player HP %d | Spear %s | Bow %s" % [
		int(player_snapshot.get("health", int(player.stats.health))),
		"yes" if player_snapshot.get("has_spear", player and player.get("has_spear")) == true else "no",
		"yes" if player_snapshot.get("has_bow", player and player.get("has_bow")) == true else "no"
	])
	lines.append("Torch %s | Campfire %s" % [_get_torch_state(), _get_campfire_state()])
	lines.append("Varnaks %d | nearest %s" % [
		int(debug_snapshot.get("live_varnaks", _get_cached_group_nodes("varnak").size())),
		_get_nearest_varnak_text(_get_cached_group_nodes("varnak"))
	])
	lines.append("Visible prey %d | grazers %d" % [
		_get_cached_group_nodes("small_prey").size(),
		_get_cached_group_nodes("grazer").size()
	])
	return "\n".join(lines)


func _build_events_text(profile: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("Events")
	lines.append("Trap kills %d | Player kills %d" % [
		int(evolution_director.get("trap_kills")) if evolution_director.get("trap_kills") != null else 0,
		int(evolution_director.get("player_kills")) if evolution_director.get("player_kills") != null else 0
	])
	lines.append("Fire scares %d | Wall attacks %d" % [
		int(evolution_director.get("fire_scares")) if evolution_director.get("fire_scares") != null else 0,
		int(evolution_director.get("wall_attacks")) if evolution_director.get("wall_attacks") != null else 0
	])
	lines.append("Generation %d | warnings %s" % [
		int(profile.get("generation", 1)),
		_get_ecosystem_warnings_text()
	])
	return "\n".join(lines)


func _build_tools_text() -> String:
	var lines: Array[String] = []
	lines.append("Tools")
	lines.append("God mode %s" % _get_god_mode_state_text())
	lines.append("Object pools: %s" % _get_pool_debug_text())
	lines.append("Player actions: Player tab")
	lines.append("Time and regrowth: World tab")
	lines.append("Biomass and ecosystem ticks: Ecosystem tab")
	lines.append("Spawn and creature cleanup: Creatures tab")
	lines.append("Weapons: Combat tab")
	return "\n".join(lines)


func _get_day() -> int:
	return day_night_system.get_day() if day_night_system.has_method("get_day") else 1


func _get_day_phase() -> String:
	if day_night_system.has_method("get_phase_label"):
		return day_night_system.get_phase_label()
	if day_night_system.has_method("get_time_label"):
		return day_night_system.get_time_label()
	return "Night" if day_night_system.has_method("is_night") and day_night_system.is_night() else "Day"


func _get_night_amount() -> float:
	return float(day_night_system.get("night_amount")) if day_night_system.get("night_amount") != null else 0.0


func _get_item_count(item_name: String) -> int:
	return player.inventory.get_amount(item_name) if player and player.inventory else 0


func _get_spear_state() -> String:
	return "yes" if player and player.get("has_spear") else "no"


func _get_bow_state() -> String:
	if not player:
		return "no"
	var has_bow: Variant = player.get("has_bow")
	return "yes" if has_bow == true else "no"


func _get_position_text(world_position: Vector2) -> String:
	return "(%d, %d)" % [int(round(world_position.x)), int(round(world_position.y))]


func _get_current_biome_name() -> String:
	if not player:
		return "unknown"
	var world: Node = _get_world_node()
	if world != null and world.has_method("get_biome_lookup_debug") and world.has_method("get_biome_name_at"):
		var lookup_debug := Dictionary(world.get_biome_lookup_debug(player.global_position))
		var biome_name := str(world.get_biome_name_at(player.global_position))
		if world.has_method("get_visual_biome_name_at"):
			biome_name = str(world.get_visual_biome_name_at(player.global_position))
		if biome_name.is_empty():
			if bool(lookup_debug.get("world_rect_has_point", false)) == true:
				return "unknown (lookup error)"
			return "outside world"
		return biome_name
	return "outside world"


func _get_ecosystem_population_total(population_key: String) -> int:
	if not ecosystem_director or not ecosystem_director.has_method("get_biome_states"):
		return 0
	var total := 0
	var biome_states: Dictionary = ecosystem_director.get_biome_states()
	for biome_id in biome_states.keys():
		var state: Dictionary = Dictionary(biome_states[biome_id])
		total += int(round(float(state.get(population_key, 0.0))))
	return total


func _get_ecosystem_warnings_text() -> String:
	if not ecosystem_director or not ecosystem_director.has_method("get_biome_states"):
		return "unavailable"
	var warnings: Array[String] = []
	var biome_states: Dictionary = ecosystem_director.get_biome_states()
	for biome_id in biome_states.keys():
		var state: Dictionary = Dictionary(biome_states[biome_id])
		var status := str(state.get("status", "unknown")).to_lower()
		if status != "healthy" and status != "stable" and status != "ok":
			warnings.append("%s:%s" % [str(state.get("name", biome_id)), status])
	return "none" if warnings.is_empty() else ", ".join(warnings)


func _get_creatures_out_of_bounds_count() -> int:
	var world := _get_world_node()
	if world and world.has_method("get_creatures_out_of_bounds_count"):
		return int(world.get_creatures_out_of_bounds_count())
	var count := 0
	for group_name in ["varnak", "small_prey", "grazer"]:
		for creature in _get_cached_group_nodes(group_name):
			if not is_instance_valid(creature) or not (creature is Node2D):
				continue
			if not WORLD_CONFIG.WORLD_RECT.has_point(creature.global_position):
				count += 1
	return count


func _get_resource_growth_text() -> String:
	var world := _get_world_node()
	if not world or not world.has_method("get_resource_growth_debug_summary"):
		return "unavailable"
	var summary: Dictionary = world.get_resource_growth_debug_summary()
	return "depleted %d | sprout %d | young %d | mature %d" % [
		int(summary.get("depleted", 0)),
		int(summary.get("sprout", 0)),
		int(summary.get("young", 0)),
		int(summary.get("mature", 0))
	]


func _get_topography_debug_text() -> String:
	var world := _get_world_node()
	if not world or not world.has_method("get_topography_debug_summary"):
		return "unavailable"
	var summary: Dictionary = world.get_topography_debug_summary()
	var feature_counts: Dictionary = Dictionary(summary.get("feature_counts", {}))
	var sample: Dictionary = Dictionary(summary.get("sample", {}))
	var band := str(sample.get("elevation_band", sample.get("terrain_zone", "unknown")))
	return "pond %d | highland %d | rocky %d | sample %s=%s" % [
		int(feature_counts.get("pond", 0)),
		int(feature_counts.get("highland", 0)),
		int(feature_counts.get("rocky_patch", 0)),
		_get_position_text(Vector2(summary.get("sample_position", Vector2.ZERO))),
		band
	]


func _get_biome_transition_text() -> String:
	var world := _get_world_node()
	if not world or not world.has_method("get_biome_transition_debug_at"):
		return "unavailable"
	if not is_instance_valid(player):
		return "no player"
	var transition: Dictionary = Dictionary(world.get_biome_transition_debug_at(player.global_position))
	if transition.is_empty():
		return "inactive"
	return "%s blend %.2f pattern %s" % [
		str(transition.get("pair_key", "unknown")),
		float(transition.get("blend", 0.0)),
		str(transition.get("pattern", "mixed"))
	]


func _get_biome_debug_text() -> String:
	var world := _get_world_node()
	if not world or not world.has_method("get_biome_lookup_debug"):
		return "unavailable"
	if not is_instance_valid(player):
		return "no player"
	var lookup_debug := Dictionary(world.get_biome_lookup_debug(player.global_position))
	return "biome=%s generator=%s query=%s terrain=%s surface=%s" % [
		str(lookup_debug.get("biome_id", "")),
		str(lookup_debug.get("generator_biome_id", "")),
		str(lookup_debug.get("query_service_biome_id", "")),
		str(lookup_debug.get("topography_zone", "")),
		str(lookup_debug.get("surface_terrain", ""))
	]


func _get_landmark_summary_text() -> String:
	var snapshot := _get_snapshot()
	var world_snapshot := Dictionary(snapshot.get("world", {}))
	var counts := {}
	var landmarks: Array = Array(world_snapshot.get("landmarks", []))
	if landmarks.is_empty():
		var world := _get_world_node()
		if not world or not world.has_method("get_landmarks"):
			return "unavailable"
		landmarks = world.get_landmarks()
	for landmark in landmarks:
		var landmark_type := str(Dictionary(landmark).get("type", "unknown"))
		counts[landmark_type] = int(counts.get(landmark_type, 0)) + 1
	var parts: Array[String] = []
	for landmark_type in counts.keys():
		parts.append("%s:%d" % [landmark_type, int(counts[landmark_type])])
	return "none" if parts.is_empty() else ", ".join(parts)


func _get_world_landmark_counts() -> Dictionary:
	var snapshot := _get_snapshot()
	var world_snapshot := Dictionary(snapshot.get("world", {}))
	if world_snapshot.has("landmark_counts"):
		return Dictionary(world_snapshot.get("landmark_counts", {}))
	var world := _get_world_node()
	if world and world.has_method("get_landmark_counts"):
		return Dictionary(world.get_landmark_counts())
	var counts := {
		"generated": 0,
		"hill": 0,
		"pond": 0
	}
	if not world or not world.has_method("get_landmarks"):
		return counts
	for landmark in world.get_landmarks():
		var landmark_data := Dictionary(landmark)
		var landmark_type := str(landmark_data.get("type", "unknown"))
		counts["generated"] = int(counts.get("generated", 0)) + 1
		if counts.has(landmark_type):
			counts[landmark_type] = int(counts.get(landmark_type, 0)) + 1
	return counts


func _get_world_seed_text() -> String:
	var snapshot := _get_snapshot()
	var world_snapshot := Dictionary(snapshot.get("world", {}))
	if world_snapshot.has("world_seed"):
		return str(int(world_snapshot.get("world_seed", 0)))
	var world := _get_world_node()
	if world and world.has_method("get_world_seed"):
		return str(int(world.get_world_seed()))
	return "unavailable"


func _get_nearest_landmark_text() -> String:
	if not player:
		return "none"
	var snapshot := _get_snapshot()
	var world_snapshot := Dictionary(snapshot.get("world", {}))
	var landmark: Dictionary = Dictionary(world_snapshot.get("nearest_landmark", {}))
	if not landmark.is_empty():
		return "%s %.0fpx" % [
			str(landmark.get("id", str(landmark.get("type", "landmark")))),
			float(landmark.get("distance_to_position", 0.0))
		]
	var world := _get_world_node()
	if not world or not world.has_method("get_nearest_landmark_data"):
		return "unavailable"
	landmark = world.get_nearest_landmark_data(player.global_position)
	if landmark.is_empty():
		return "none"
	return "%s %.0fpx" % [
		str(landmark.get("id", str(landmark.get("type", "landmark")))),
		float(landmark.get("distance_to_position", 0.0))
	]


func _get_current_biome_texture_id_text() -> String:
	if not player:
		return "none"
	var snapshot := _get_snapshot()
	var world_snapshot := Dictionary(snapshot.get("world", {}))
	if world_snapshot.has("current_biome_texture_id"):
		return str(world_snapshot.get("current_biome_texture_id", "none"))
	var world := _get_world_node()
	if world and world.has_method("get_current_biome_texture_id"):
		return str(world.get_current_biome_texture_id(player.global_position))
	return "unavailable"


func _get_biome_texture_cache_status_text() -> String:
	var snapshot := _get_snapshot()
	var world_snapshot := Dictionary(snapshot.get("world", {}))
	var status: Dictionary = Dictionary(world_snapshot.get("biome_texture_cache", {}))
	if status.is_empty():
		var world := _get_world_node()
		if not world or not world.has_method("get_biome_texture_cache_status"):
			return "unavailable"
		status = world.get_biome_texture_cache_status()
	return "images %d | accents %d | pending %d | building %s" % [
		int(status.get("sample_image_cache_count", 0)),
		int(status.get("accent_cache_count", 0)),
		int(status.get("pending_biomes", 0)),
		"yes" if status.get("build_running", false) == true else "no"
	]


func _get_biome_detail_overlay_text() -> String:
	var snapshot := _get_snapshot()
	var world_snapshot := Dictionary(snapshot.get("world", {}))
	var cache: Dictionary = Dictionary(world_snapshot.get("biome_texture_cache", {}))
	return "enabled=%s low_end_disabled=%s visible=%d pending=%d cached=%d built/frame=%d/%d last=%.2fms max=%.2fms" % [
		"yes" if bool(cache.get("biome_detail_overlay_enabled", false)) else "no",
		"yes" if bool(cache.get("biome_detail_overlay_low_end_disabled", false)) else "no",
		int(cache.get("biome_detail_overlay_visible_chunk_count", 0)),
		int(cache.get("biome_detail_overlay_pending_chunk_count", 0)),
		int(cache.get("biome_detail_overlay_cached_chunk_count", 0)),
		int(cache.get("biome_detail_overlay_chunks_built_last_frame", 0)),
		int(cache.get("biome_detail_overlay_build_budget_per_frame", 0)),
		float(cache.get("biome_detail_overlay_last_build_ms", 0.0)),
		float(cache.get("biome_detail_overlay_max_build_ms", 0.0))
	]


func _get_landmark_overlay_state_text() -> String:
	var snapshot := _get_snapshot()
	var world_snapshot := Dictionary(snapshot.get("world", {}))
	if world_snapshot.has("landmark_overlay_enabled"):
		return "ON" if world_snapshot.get("landmark_overlay_enabled", false) == true else "OFF"
	var world := _get_world_node()
	if world and world.has_method("is_landmark_debug_overlay_enabled"):
		return "ON" if world.is_landmark_debug_overlay_enabled() else "OFF"
	return "unknown"


func _get_biome_texture_state_text() -> String:
	var snapshot := _get_snapshot()
	var world_snapshot := Dictionary(snapshot.get("world", {}))
	if world_snapshot.has("biome_textures_enabled"):
		return "ON" if world_snapshot.get("biome_textures_enabled", true) == true else "OFF"
	var world := _get_world_node()
	if world and world.has_method("are_biome_textures_enabled"):
		return "ON" if world.are_biome_textures_enabled() else "OFF"
	return "unknown"


func _get_decorative_vegetation_text() -> String:
	var world := _get_world_node()
	if not world or not world.has_method("get_decorative_vegetation_debug"):
		return "unavailable"
	var decorative_debug: Dictionary = world.get_decorative_vegetation_debug()
	var visual_debug: Dictionary = Dictionary(decorative_debug.get("visual_layer", {}))
	var count_by_kind: Dictionary = Dictionary(visual_debug.get("count_by_kind", {}))
	return "visuals %d | grass_patch nodes %d | dense_grass nodes %d | edible nodes %d" % [
		int(decorative_debug.get("visual_instance_count", 0)),
		int(count_by_kind.get("grass_patch", 0)),
		int(count_by_kind.get("dense_grass", 0)),
		int(decorative_debug.get("edible_grass_node_spawn_count", 0))
	]


func _get_adaptation_pressure(profile: Dictionary) -> float:
	var keys := ["aggression", "trap_awareness", "pack_coordination", "night_activity", "base_curiosity", "stalk_tendency"]
	var total := 0.0
	for key in keys:
		total += float(profile.get(key, 0.0))
	return total / float(keys.size())


func _get_varnak_debug_lines(profile: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var varnaks := _get_cached_group_nodes("varnak")
	lines.append("")
	lines.append("Varnaks %d | %s" % [varnaks.size(), _get_varnak_state_summary(varnaks)])
	lines.append("Gen %d | pressure %.2f | days %d/%d" % [
		int(profile.get("generation", 1)),
		_get_adaptation_pressure(profile),
		evolution_director.days_since_generation,
		evolution_director.days_until_next_generation
	])
	lines.append("Adapt aggr %.2f fire %.2f trap %.2f pack %.2f" % [
		float(profile.get("aggression", 0.0)),
		float(profile.get("fire_fear", 0.0)),
		float(profile.get("trap_awareness", 0.0)),
		float(profile.get("pack_coordination", 0.0))
	])
	lines.append("Traits night %.2f curious %.2f stalk %.2f" % [
		float(profile.get("night_activity", 0.0)),
		float(profile.get("base_curiosity", 0.0)),
		float(profile.get("stalk_tendency", 0.0))
	])
	lines.append("Events trap %d player %d fire %d wall %d" % [
		evolution_director.trap_kills,
		evolution_director.player_kills,
		evolution_director.fire_scares,
		evolution_director.wall_attacks
	])
	lines.append("Avg HP %s | nearest %s" % [
		_get_average_varnak_health_text(varnaks),
		_get_nearest_varnak_text(varnaks)
	])
	return lines


func _get_ecosystem_debug_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append("")
	lines.append("Ecosystem")
	lines.append("Visible Grazers %d | %s" % [
		_get_cached_group_nodes("grazer").size(),
		_get_grazer_state_summary()
	])
	if not ecosystem_director or not ecosystem_director.has_method("get_biome_states"):
		lines.append("Waiting for ecosystem state...")
		return lines
	var biome_states: Dictionary = ecosystem_director.get_biome_states()
	if biome_states.is_empty():
		lines.append("No biome states")
		return lines
	var biome_ids := biome_states.keys()
	biome_ids.sort()
	for biome_id in biome_ids:
		var state: Dictionary = Dictionary(biome_states[biome_id])
		lines.append("%s | plants %d%% | %s" % [
			str(state.get("name", biome_id)),
			int(round(float(state.get("plant_biomass_percent", 0.0)))),
			str(state.get("status", "unknown"))
		])
		lines.append("  SmallPrey %d | Grazers %d | Varnaks %d | niche %s | stress %d" % [
			int(round(float(state.get("small_prey_population", 0.0)))),
			int(round(float(state.get("grazer_population", 0.0)))),
			int(round(float(state.get("varnak_population", 0.0)))),
			str(state.get("current_niche", "HERBIVORE")).to_lower(),
			int(state.get("generations_under_food_stress", 0))
		])
		lines.append_array(_get_population_recovery_debug_lines(state))
		lines.append("  aggregate pop %.1f | hunger %d%% | energy %d%% | birth %.2f death %.2f" % [
			float(state.get("population_count", 0.0)),
			int(round(float(state.get("average_hunger", 0.0)) * 100.0)),
			int(round(float(state.get("average_energy", 1.0)) * 100.0)),
			float(state.get("birth_rate", 0.0)),
			float(state.get("death_rate", 0.0))
		])
		lines.append("  diet P %.2f M %.2f S %.2f | aggr %.2f" % [
			float(state.get("average_plant_diet", 0.85)),
			float(state.get("average_meat_diet", 0.05)),
			float(state.get("average_scavenger_diet", 0.10)),
			float(state.get("average_aggression", 0.15))
		])
		lines.append("  prey gen %d | fear %.2f | speed %d | repro %.2f | fit %d%%" % [
			int(state.get("small_prey_generation", 1)),
			float(state.get("average_small_prey_fear", 0.90)),
			int(round(float(state.get("average_small_prey_speed", 90.0)))),
			float(state.get("average_small_prey_reproduction", 0.60)),
			int(round(float(state.get("average_small_prey_fitness", 0.0)) * 100.0))
		])
		lines.append("  grazer gen %d | repro %.2f | fit %d%% | pressure G%d P%d" % [
			int(state.get("grazer_generation", 1)),
			float(state.get("average_grazer_reproduction", 0.35)),
			int(round(float(state.get("average_grazer_fitness", 0.0)) * 100.0)),
			int(state.get("grazer_pressure_ticks", 0)),
			int(state.get("small_prey_pressure_ticks", 0))
		])
		lines.append("  varnak %.2f | food stress %.2f | over %.2f" % [
			float(state.get("varnak_ecosystem_pressure", state.get("predator_pressure", 0.0))),
			float(state.get("food_stress", 0.0)),
			float(state.get("overgrazing_level", state.get("overgrazing_pressure", 0.0)))
		])
		lines.append("  varnak gen %d | hunger %d%% | energy %d%% | fit %d%% | hunt %.2f" % [
			int(state.get("varnak_generation", 1)),
			int(round(float(state.get("average_varnak_hunger", 0.0)) * 100.0)),
			int(round(float(state.get("average_varnak_energy", 1.0)) * 100.0)),
			int(round(float(state.get("average_varnak_fitness", 0.0)) * 100.0)),
			float(state.get("average_varnak_hunt_drive", 0.0))
		])
	return lines


func _get_ecosystem_debug_lines_from_snapshot(ecosystem_snapshot: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	lines.append("")
	lines.append("Ecosystem")
	lines.append("Visible Grazers %d | %s" % [
		Array(Dictionary(_get_snapshot().get("markers", {})).get("grazers", [])).size(),
		_get_grazer_state_summary()
	])
	var biome_states: Dictionary = Dictionary(ecosystem_snapshot.get("biome_states", {}))
	if biome_states.is_empty():
		lines.append("No biome states")
		return lines
	var biome_ids := biome_states.keys()
	biome_ids.sort()
	for biome_id in biome_ids:
		var state: Dictionary = Dictionary(biome_states[biome_id])
		lines.append("%s | plants %d%% | %s" % [
			str(state.get("name", biome_id)),
			int(round(float(state.get("plant_biomass_percent", 0.0)))),
			str(state.get("status", "unknown"))
		])
		lines.append("  SmallPrey %d | Grazers %d | Varnaks %d | niche %s | stress %d" % [
			int(round(float(state.get("small_prey_population", 0.0)))),
			int(round(float(state.get("grazer_population", 0.0)))),
			int(round(float(state.get("varnak_population", 0.0)))),
			str(state.get("current_niche", "HERBIVORE")).to_lower(),
			int(state.get("generations_under_food_stress", 0))
		])
		lines.append_array(_get_population_recovery_debug_lines(state))
		lines.append("  aggregate pop %.1f | hunger %d%% | energy %d%% | birth %.2f death %.2f" % [
			float(state.get("population_count", 0.0)),
			int(round(float(state.get("average_hunger", 0.0)) * 100.0)),
			int(round(float(state.get("average_energy", 1.0)) * 100.0)),
			float(state.get("birth_rate", 0.0)),
			float(state.get("death_rate", 0.0))
		])
	return lines


func _get_population_recovery_debug_lines(state: Dictionary) -> Array[String]:
	var recovery: Dictionary = GAME_BALANCE.POPULATION_RECOVERY
	return [
		"  SmallPrey min/target/max %d/%d/%d | daily +%.2f | pred %.2f | %s" % [
			int(recovery["small_prey_min_population"]),
			int(recovery["small_prey_target_population"]),
			int(recovery["small_prey_max_population"]),
			float(state.get("small_prey_daily_recovery", 0.0)),
			float(state.get("small_prey_predation_pressure", 0.0)),
			str(state.get("small_prey_population_trend", "stable"))
		],
		"  Grazer min/target/max %d/%d/%d | daily +%.2f | pred %.2f starve %.2f | %s" % [
			int(recovery["grazer_min_population"]),
			int(recovery["grazer_target_population"]),
			int(recovery["grazer_max_population"]),
			float(state.get("grazer_daily_recovery", 0.0)),
			float(state.get("grazer_predation_pressure", 0.0)),
			float(state.get("grazer_starvation_pressure", 0.0)),
			str(state.get("grazer_population_trend", "stable"))
		]
	]


func get_debug_panel_performance_debug() -> Dictionary:
	return {
		"refresh_count": debug_panel_refresh_count,
		"overlay_refresh_count": debug_panel_overlay_refresh_count,
		"hidden_skip_count": debug_panel_hidden_skip_count
	}


func _get_snapshot() -> Dictionary:
	if snapshot_service != null:
		if snapshot_service.has_method("refresh"):
			var refreshed_snapshot: Dictionary = snapshot_service.refresh()
			if not refreshed_snapshot.is_empty():
				return refreshed_snapshot
		if snapshot_service.has_method("get_snapshot"):
			var snapshot: Dictionary = snapshot_service.get_snapshot()
			if snapshot.is_empty() and snapshot_service.has_method("refresh"):
				return snapshot_service.refresh(true)
			return snapshot
	return {}


func _get_grazer_state_summary() -> String:
	return _get_fixed_creature_state_summary("grazer", [
		"idle",
		"wander",
		"eat_plants",
		"seek_food",
		"flee",
		"scavenge",
		"hunt_small_prey",
		"dead"
	])


func _get_population_aggregate_lines() -> Array[String]:
	return [
		"Population model: prey %d | grazers %d | varnaks %d" % [
			_get_ecosystem_population_total("small_prey_population"),
			_get_ecosystem_population_total("grazer_population"),
			_get_ecosystem_population_total("varnak_population")
		],
		"Visible SmallPrey: %s" % _get_visible_creature_aggregate_text("small_prey"),
		"Visible Grazers: %s" % _get_visible_creature_aggregate_text("grazer"),
		"Visible Varnaks: %s" % _get_visible_creature_aggregate_text("varnak")
	]


func _get_visible_creature_aggregate_text(group_name: String) -> String:
	var creatures := _get_cached_group_nodes(group_name)
	if creatures.is_empty():
		return "0"
	var health_total := 0.0
	var satiety_total := 0.0
	var energy_total := 0.0
	var fitness_total := 0.0
	var count := 0
	for creature in creatures:
		if not is_instance_valid(creature) or not creature.has_method("get_debug_data"):
			continue
		var data: Dictionary = creature.get_debug_data()
		health_total += float(data.get("health", 0.0)) / max(float(data.get("max_health", 1.0)), 1.0)
		satiety_total += _get_debug_satiety_ratio(data)
		energy_total += float(data.get("energy", 0.0))
		fitness_total += float(data.get("fitness_score", 0.0))
		count += 1
	if count <= 0:
		return "0"
	return "%d avg HP:%d%% Sat:%d%% E:%d%% Fit:%d%%" % [
		count,
		int(round(health_total / float(count) * 100.0)),
		int(round(satiety_total / float(count) * 100.0)),
		int(round(energy_total / float(count) * 100.0)),
		int(round(fitness_total / float(count) * 100.0))
	]


func _get_creature_state_summary(group_name: String) -> String:
	return _get_fixed_creature_state_summary(group_name, [
		"idle",
		"wander",
		"seek_food",
		"eat",
		"flee",
		"dead"
	])


func _get_varnak_state_summary(_varnaks: Array) -> String:
	return _get_fixed_creature_state_summary("varnak", [
		"idle",
		"wander",
		"stalk",
		"chase",
		"attack",
		"flee",
		"hunt_ecosystem",
		"eat_meat"
	])


func _get_fixed_creature_state_summary(group_name: String, state_names: Array[String]) -> String:
	var creatures := _get_cached_group_nodes(group_name)
	var counts := {}
	var satiety_total := 0.0
	var energy_total := 0.0
	var count := 0
	for creature in creatures:
		if not is_instance_valid(creature) or not creature.has_method("get_debug_data"):
			continue
		var data: Dictionary = creature.get_debug_data()
		var state_name := str(data.get("state", "unknown")).to_lower()
		counts[state_name] = int(counts.get(state_name, 0)) + 1
		satiety_total += _get_debug_satiety_ratio(data)
		energy_total += float(data.get("energy", 0.0))
		count += 1
	var parts: Array[String] = []
	for state_name in state_names:
		parts.append("%s:%d" % [state_name, int(counts.get(state_name, 0))])
	parts.append("satiety:%d%%" % _get_average_percent(satiety_total, count))
	parts.append("energy:%d%%" % _get_average_percent(energy_total, count))
	return ", ".join(parts)


func _get_ai_state_summary_text(state_counts: Dictionary, state_names: Array[String]) -> String:
	if state_counts.is_empty():
		return "none"
	var parts: Array[String] = []
	for state_name in state_names:
		parts.append("%s:%d" % [state_name, int(state_counts.get(state_name, 0))])
	return ", ".join(parts)


func _get_average_percent(total: float, count: int) -> int:
	if count <= 0:
		return 0
	return int(round(total / float(count) * 100.0))


func _get_average_varnak_health_text(varnaks: Array) -> String:
	var total := 0.0
	var count := 0
	for varnak in varnaks:
		if not is_instance_valid(varnak) or not varnak.has_method("get_debug_data"):
			continue
		var data: Dictionary = varnak.get_debug_data()
		total += float(data.get("health", 0.0)) / max(float(data.get("max_health", 1.0)), 1.0)
		count += 1
	if count <= 0:
		return "n/a"
	return "%d%%" % int(round(total / float(count) * 100.0))


func _get_nearest_varnak_text(varnaks: Array) -> String:
	if varnaks.is_empty():
		last_nearest_creature_text.erase("varnak")
		return "none"
	var nearest_data: Dictionary = {}
	var nearest_distance := INF
	for varnak in varnaks:
		if not is_instance_valid(varnak) or not varnak.has_method("get_debug_data"):
			continue
		var data: Dictionary = varnak.get_debug_data()
		var distance := float(data.get("distance_to_player", INF))
		if distance >= 0.0 and distance < nearest_distance:
			nearest_distance = distance
			nearest_data = data
	if nearest_data.is_empty():
		return str(last_nearest_creature_text.get("varnak", "none"))
	var text := "%s %.0fpx hp %d/%d" % [
		str(nearest_data.get("state", "unknown")).to_lower(),
		nearest_distance,
		int(nearest_data.get("health", 0.0)),
		int(nearest_data.get("max_health", 0.0))
	]
	last_nearest_creature_text["varnak"] = text
	return text


func _get_creature_debug_stat_lines(group_name: String, label: String) -> Array[String]:
	var creature := _get_selected_debug_creature(group_name)
	var data: Dictionary = creature.get_debug_data() if is_instance_valid(creature) and creature.has_method("get_debug_data") else {}
	return [
		"%s: %s | gen %d | distance %.0fpx" % [
			label,
			str(data.get("species", group_name)),
			int(data.get("generation", 0)),
			_get_debug_float(data, "distance_to_player")
		],
		"  state %s | target %s | last_food %s" % [
			_get_debug_text(data, "state"),
			_get_debug_text(data, "current_target"),
			_get_debug_text(data, "last_food_source")
		],
		"  decision %s" % _get_debug_text(data, "decision_reason"),
		"  health %.0f/%.0f | speed %.0f | age %.1fs" % [
			_get_debug_float(data, "health"),
			_get_debug_float(data, "max_health"),
			_get_debug_float(data, "speed"),
			_get_debug_float(data, "age_seconds")
		],
		"  satiety %.0f%% | hunger_need %.0f%% | max_hunger %.2f | growth %.3f | stage %s" % [
			_get_debug_satiety_percent(data),
			_get_debug_hunger_percent(data),
			_get_debug_float(data, "max_hunger"),
			_get_debug_float(data, "hunger_growth_rate"),
			_get_debug_text(data, "hunger_stage")
		],
		"  energy %.0f%% | fatigue %.0f%% | rest %.0f%% | fitness %.0f%%" % [
			_get_debug_percent(data, "energy"),
			_get_debug_percent(data, "fatigue"),
			_get_debug_percent(data, "rest"),
			_get_debug_percent(data, "fitness_score")
		],
		"  sim %s | dist %.0f | lod changes %d | culled %s" % [
			_get_debug_text(data, "simulation_level"),
			_get_debug_float(data, "simulation_distance_to_player"),
			int(data.get("simulation_lod_change_count", 0)),
			_get_debug_text(data, "is_visibility_culled")
		],
		"  diet plant %.2f | meat %.2f | scav %.2f" % [
			_get_debug_float(data, "plant_diet"),
			_get_debug_float(data, "meat_diet"),
			_get_debug_float(data, "scavenger_diet")
		],
		"  aggression %.2f | fear %.2f | niche %s" % [
			_get_debug_float(data, "aggression"),
			_get_debug_float(data, "fear"),
			_get_debug_text(data, "current_niche")
		],
		"  biome %s | home %s | reproduction %.2f | consumption %.2f" % [
			_get_debug_text(data, "biome_id"),
			_get_debug_text(data, "home_biome_id"),
			_get_debug_float(data, "reproduction_value", _get_debug_float(data, "reproduction_rate")),
			_get_debug_float(data, "plant_consumption_rate")
		]
	]


func _get_debug_float(data: Dictionary, key: String, fallback := 0.0) -> float:
	return float(data.get(key, fallback))


func _get_debug_percent(data: Dictionary, key: String) -> float:
	return _get_debug_float(data, key) * 100.0


func _get_debug_hunger_percent(data: Dictionary) -> float:
	if data.has("hunger_ratio"):
		return _get_debug_percent(data, "hunger_ratio")
	return _get_debug_percent(data, "hunger")


func _get_simulation_level_counts_text(group_name: String) -> String:
	var counts := _get_simulation_level_counts(group_name)
	return "near %d | medium %d | far %d | unknown %d" % [
		int(counts.get("near", 0)),
		int(counts.get("medium", 0)),
		int(counts.get("far", 0)),
		int(counts.get("unknown", 0))
	]


func _get_simulation_level_counts(group_name: String) -> Dictionary:
	var counts := {
		"near": 0,
		"medium": 0,
		"far": 0,
		"unknown": 0
	}
	for creature in _get_cached_group_nodes(group_name):
		if not is_instance_valid(creature) or not creature.has_method("get_debug_data"):
			continue
		var data: Dictionary = creature.get_debug_data()
		var level := str(data.get("simulation_level", "unknown"))
		if not counts.has(level):
			level = "unknown"
		counts[level] = int(counts.get(level, 0)) + 1
	return counts


func _get_debug_satiety_ratio(data: Dictionary) -> float:
	if data.has("hunger_ratio"):
		return clamp(1.0 - float(data.get("hunger_ratio", 0.0)), 0.0, 1.0)
	return clamp(1.0 - float(data.get("hunger", 0.0)), 0.0, 1.0)


func _get_debug_satiety_percent(data: Dictionary) -> float:
	return _get_debug_satiety_ratio(data) * 100.0


func _get_debug_text(data: Dictionary, key: String) -> String:
	if not data.has(key):
		return "0"
	var value: Variant = data.get(key, "0")
	if str(value).is_empty():
		return "0"
	return str(value).to_lower()


func _get_selected_debug_creature(group_name: String) -> Node:
	var selected_value: Variant = selected_debug_creatures.get(group_name, null)
	if is_instance_valid(selected_value):
		var selected := selected_value as Node
		if selected and selected.is_in_group(group_name) and selected.has_method("get_debug_data"):
			return selected
	selected_debug_creatures.erase(group_name)
	var nearest := _find_nearest_debug_creature(group_name)
	if is_instance_valid(nearest):
		selected_debug_creatures[group_name] = nearest
	else:
		selected_debug_creatures.erase(group_name)
	return nearest


func _find_nearest_debug_creature(group_name: String) -> Node:
	var nearest: Node
	var nearest_distance := INF
	for creature in _get_cached_group_nodes(group_name):
		if not is_instance_valid(creature) or not creature.has_method("get_debug_data"):
			continue
		var data: Dictionary = creature.get_debug_data()
		var distance := float(data.get("distance_to_player", INF))
		if distance >= 0.0 and distance < nearest_distance:
			nearest_distance = distance
			nearest = creature
	return nearest


func _get_campfire_state() -> String:
	var active_count := 0
	var total_count := 0
	for campfire in _get_cached_group_nodes("campfires"):
		if not is_instance_valid(campfire):
			continue
		total_count += 1
		if campfire.get("active") == true:
			active_count += 1
	return "%d active / %d total" % [active_count, total_count]


func _get_campfire_regen_active_text() -> String:
	if not player or not player.stats:
		return "false"
	return "true" if player.stats.campfire_regen_active else "false"


func _get_campfire_regen_distance_text() -> String:
	if not player or not player.stats or not player.stats.campfire_regen_active:
		return "none"
	return "%.0f" % player.stats.campfire_regen_distance


func _get_torch_state() -> String:
	if not player.has_method("is_torch_active") or not player.is_torch_active():
		return "inactive"
	var remaining: float = player.get_torch_remaining_seconds() if player.has_method("get_torch_remaining_seconds") else 0.0
	return "active %.1fs" % remaining


func _get_god_mode_state_text() -> String:
	if not player:
		return "unknown"
	if player.has_method("is_god_mode_enabled"):
		return "ON" if player.is_god_mode_enabled() else "OFF"
	var value: Variant = player.get("god_mode")
	return "ON" if value == true else "OFF"


func _add_debug_item(item_name: String) -> void:
	if not player or not player.has_method("debug_add_item"):
		return
	player.debug_add_item(item_name, 1)
	_set_state_text(_build_state_text())


func _on_add_wood_pressed() -> void:
	_add_debug_item("wood")


func _on_add_stone_pressed() -> void:
	_add_debug_item("stone")


func _on_add_fiber_pressed() -> void:
	_add_debug_item("fiber")


func _on_add_meat_pressed() -> void:
	_add_debug_item("meat")


func _on_add_torch_pressed() -> void:
	_add_debug_item("torch")


func _on_add_spear_pressed() -> void:
	_add_debug_item("spear")


func _on_next_phase_pressed() -> void:
	if day_night_system and day_night_system.has_method("debug_next_phase"):
		day_night_system.debug_next_phase()
	_set_state_text(_build_state_text())


func _on_next_day_pressed() -> void:
	if day_night_system and day_night_system.has_method("debug_next_day"):
		day_night_system.debug_next_day()
	_set_state_text(_build_state_text())


func _on_increase_adaptation_pressed() -> void:
	if evolution_director and evolution_director.has_method("debug_increase_adaptation"):
		evolution_director.debug_increase_adaptation()
	_set_state_text(_build_state_text())


func _on_spawn_aggressive_pressed() -> void:
	_debug_spawn_animal(true)


func _on_spawn_neutral_pressed() -> void:
	_debug_spawn_animal(false)


func _debug_spawn_animal(aggressive: bool) -> void:
	var world := _get_world_node()
	if world and world.has_method("debug_spawn_animal"):
		world.debug_spawn_animal(aggressive)
	_set_state_text(_build_state_text())


func _on_reduce_plants_pressed() -> void:
	_call_ecosystem_debug_method("debug_reduce_plant_biomass")


func _on_restore_plants_pressed() -> void:
	_call_ecosystem_debug_method("debug_restore_plant_biomass")


func _on_add_small_prey_pressed() -> void:
	_call_ecosystem_debug_method("debug_add_small_prey")
	_call_world_debug_method("debug_spawn_small_prey_near_player")


func _on_remove_small_prey_pressed() -> void:
	_call_ecosystem_debug_method("debug_remove_small_prey")
	_call_world_debug_method("debug_remove_small_prey_near_player")


func _on_add_grazers_pressed() -> void:
	_call_ecosystem_debug_method("debug_add_grazers")
	_call_world_debug_method("debug_spawn_grazers_near_player")


func _on_remove_grazers_pressed() -> void:
	_call_ecosystem_debug_method("debug_remove_grazers")
	_call_world_debug_method("debug_remove_grazers_near_player")


func _on_force_food_stress_pressed() -> void:
	_call_ecosystem_debug_method("debug_force_grazer_food_stress")


func _on_force_niche_check_pressed() -> void:
	_call_ecosystem_debug_method("debug_force_grazer_niche_shift_check")


func _on_advance_ecosystem_tick_pressed() -> void:
	if ecosystem_director and ecosystem_director.has_method("debug_advance_ecosystem_tick"):
		ecosystem_director.debug_advance_ecosystem_tick()
	_set_state_text(_build_state_text())


func _call_ecosystem_debug_method(method_name: String) -> void:
	if ecosystem_director and ecosystem_director.has_method(method_name) and player:
		ecosystem_director.call(method_name, player.global_position)
	_set_state_text(_build_state_text())


func _call_world_debug_method(method_name: String) -> void:
	var world := _get_world_node()
	if world and world.has_method(method_name):
		world.call(method_name)
	_set_state_text(_build_state_text())


func _on_give_bow_pressed() -> void:
	if not player:
		return
	if player.has_method("debug_add_bow"):
		player.debug_add_bow()
	elif player.get("has_bow") != null:
		player.set("has_bow", true)
		_post_debug_message("Debug gave bow")
	else:
		_post_debug_message("Bow debug is not available yet")
	_set_state_text(_build_state_text())


func _on_toggle_god_mode_pressed() -> void:
	if not player:
		return
	if player.has_method("toggle_god_mode"):
		player.toggle_god_mode()
	elif player.get("god_mode") != null:
		player.set("god_mode", not (player.get("god_mode") == true))
		_post_debug_message("God mode %s" % ("enabled" if player.get("god_mode") == true else "disabled"))
	_refresh_god_mode_button()
	_set_state_text(_build_state_text(), true)


func _refresh_god_mode_button() -> void:
	if god_mode_button:
		god_mode_button.text = "God Mode: %s" % _get_god_mode_state_text()


func _refresh_world_debug_buttons() -> void:
	var world := _get_world_node()
	var can_regenerate: bool = world != null and world.has_method("debug_regenerate_landmarks")
	var can_toggle_overlay: bool = world != null and world.has_method("debug_toggle_landmark_overlay")
	var can_rebuild_cache: bool = world != null and world.has_method("debug_rebuild_biome_texture_cache")
	var can_toggle_textures: bool = world != null and world.has_method("debug_toggle_biome_textures")
	if regenerate_landmarks_button:
		regenerate_landmarks_button.disabled = not can_regenerate
	if landmark_overlay_button:
		landmark_overlay_button.text = "Landmark overlay: %s" % _get_landmark_overlay_state_text()
		landmark_overlay_button.disabled = not can_toggle_overlay
	if rebuild_biome_cache_button:
		rebuild_biome_cache_button.disabled = not can_rebuild_cache
	if biome_texture_toggle_button:
		biome_texture_toggle_button.text = "Biome textures: %s" % _get_biome_texture_state_text()
		biome_texture_toggle_button.disabled = not can_toggle_textures


func _on_advance_resource_growth_pressed() -> void:
	_call_optional_world_debug_method("debug_advance_resource_growth_day", "Resource growth debug is not available yet")


func _on_force_full_vegetation_regrowth_pressed() -> void:
	_call_optional_world_debug_method("debug_force_full_vegetation_regrowth", "Vegetation regrowth debug is not available yet")


func _on_reset_resource_growth_pressed() -> void:
	_call_optional_world_debug_method("debug_reset_resource_growth", "Resource growth reset debug is not available yet")


func _on_teleport_out_of_bounds_pressed() -> void:
	_call_optional_world_debug_method("debug_teleport_out_of_bounds_creatures", "Creature bounds debug is not available yet")


func _on_regenerate_landmarks_pressed() -> void:
	var world := _get_world_node()
	if not world or not world.has_method("debug_regenerate_landmarks"):
		_post_debug_message("Landmark regeneration debug is not available yet")
		return
	_post_debug_message("Regenerating landmarks...")
	await world.debug_regenerate_landmarks()
	_refresh_world_debug_buttons()
	_set_state_text(_build_state_text(), true)


func _on_validate_island_world_pressed() -> void:
	var world := _get_world_node()
	if not world or not world.has_method("run_island_world_validation"):
		_post_debug_message("Island world validation is not available yet")
		return
	var report: Dictionary = world.run_island_world_validation()
	_post_debug_message(_get_island_world_validation_summary_text(report))
	if not bool(report.get("passed", false)) and world.has_method("get_island_world_validation_text"):
		print(world.get_island_world_validation_text())
	_refresh_world_debug_buttons()
	_set_state_text(_build_state_text(), true)


func _on_toggle_landmark_overlay_pressed() -> void:
	var world := _get_world_node()
	if not world or not world.has_method("debug_toggle_landmark_overlay"):
		_post_debug_message("Landmark overlay debug is not available yet")
		return
	var enabled: bool = world.debug_toggle_landmark_overlay()
	_post_debug_message("Landmark overlay %s" % ("enabled" if enabled else "disabled"))
	_refresh_world_debug_buttons()
	_set_state_text(_build_state_text(), true)


func _on_rebuild_biome_texture_cache_pressed() -> void:
	var world := _get_world_node()
	if not world or not world.has_method("debug_rebuild_biome_texture_cache"):
		_post_debug_message("Biome texture cache debug is not available yet")
		return
	world.debug_rebuild_biome_texture_cache()
	_post_debug_message("Rebuilding biome texture cache...")
	_refresh_world_debug_buttons()
	_set_state_text(_build_state_text(), true)


func _on_toggle_biome_textures_pressed() -> void:
	var world := _get_world_node()
	if not world or not world.has_method("debug_toggle_biome_textures"):
		_post_debug_message("Biome texture toggle debug is not available yet")
		return
	var enabled: bool = world.debug_toggle_biome_textures()
	_post_debug_message("Biome textures %s" % ("enabled" if enabled else "disabled"))
	_refresh_world_debug_buttons()
	_set_state_text(_build_state_text(), true)


func _on_test_object_pool_pressed() -> void:
	var world := _get_world_node()
	if not world or not world.has_method("debug_test_resource_drop_pool"):
		_post_debug_message("Object pool test is not available yet")
		return
	var result: Dictionary = world.debug_test_resource_drop_pool()
	_post_debug_message("Object pool test: %s" % str(result.get("summary", "done")))
	_refresh_world_debug_buttons()
	_set_state_text(_build_state_text(), true)


func _on_run_benchmark_pressed() -> void:
	_start_benchmark()


func _start_benchmark() -> void:
	if is_instance_valid(benchmark_runner):
		_post_debug_message("Benchmark is already running")
		return
	var scene := get_tree().current_scene
	if not scene:
		_post_debug_message("Benchmark could not start: no active scene")
		return
	if benchmark_runner_script == null:
		benchmark_runner_script = load("res://scripts/systems/benchmark_runner.gd")
	if benchmark_runner_script == null:
		_post_debug_message("Benchmark could not start: runner script unavailable")
		return
	benchmark_runner = benchmark_runner_script.new()
	scene.add_child(benchmark_runner)
	if benchmark_button:
		benchmark_button.text = "Benchmark 60s / starting..."
	if benchmark_runner.has_signal("finished"):
		benchmark_runner.finished.connect(_on_benchmark_finished)
	if benchmark_runner.has_signal("benchmark_progress"):
		benchmark_runner.benchmark_progress.connect(_on_benchmark_progress)
	if benchmark_runner.has_method("start"):
		var started: bool = benchmark_runner.call("start") == true
		if started:
			_post_debug_message("Benchmark started for 60 seconds")
		else:
			_reset_benchmark_button()
			benchmark_runner.queue_free()
			benchmark_runner = null
			_post_debug_message("Benchmark could not start")


func _on_benchmark_progress(elapsed_seconds: float, remaining_seconds: float) -> void:
	if benchmark_button:
		benchmark_button.text = "Benchmark %.0fs left" % ceil(remaining_seconds)
	_post_debug_message("Benchmark running: %.0fs elapsed, %.0fs left" % [floor(elapsed_seconds), ceil(remaining_seconds)])


func _on_benchmark_finished(log_path: String, json_path: String) -> void:
	if is_instance_valid(benchmark_runner):
		benchmark_runner.queue_free()
	benchmark_runner = null
	_reset_benchmark_button()
	if log_path.is_empty() and json_path.is_empty():
		_post_debug_message("Benchmark finished")
	else:
		_post_debug_message("Benchmark finished. Logs saved to %s and %s" % [log_path, json_path])


func _reset_benchmark_button() -> void:
	if benchmark_button:
		benchmark_button.text = "Run 60s benchmark"


func _call_optional_world_debug_method(method_name: String, missing_message: String) -> void:
	var world := _get_world_node()
	if world and world.has_method(method_name):
		world.call(method_name)
	else:
		_post_debug_message(missing_message)
	_set_state_text(_build_state_text())


func _get_world_node() -> Node:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	if tree.current_scene != null:
		var current_world := tree.current_scene.get_node_or_null("World")
		if current_world != null:
			return current_world
	return tree.root.find_child("World", true, false)


func _get_cached_group_nodes(group_name: String) -> Array:
	var world := _get_world_node()
	if world and world.has_method("get_cached_group_nodes"):
		return world.get_cached_group_nodes(group_name)
	var tree := get_tree()
	if tree == null:
		return []
	return tree.get_nodes_in_group(group_name)


func _post_debug_message(message: String) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_method("post_message"):
		event_bus.post_message(message)
	else:
		print(message)


func _get_pool_debug_text() -> String:
	var world := _get_world_node()
	if not world or not world.has_method("get_pool_debug_text"):
		return "unavailable"
	return str(world.get_pool_debug_text())


func _get_chunk_debug_text() -> String:
	var world := _get_world_node()
	if not world or not world.has_method("get_chunk_debug_data"):
		return "unavailable"
	var chunk_data: Dictionary = world.get_chunk_debug_data()
	if chunk_data.is_empty():
		return "unavailable"
	return "current %s | active %d / %d | changes %d | activations %d | deactivations %d" % [
		str(chunk_data.get("current_player_chunk", "n/a")),
		int(chunk_data.get("active_chunk_count", 0)),
		int(chunk_data.get("total_chunk_count", 0)),
		int(chunk_data.get("chunk_change_count", 0)),
		int(chunk_data.get("chunk_activation_count", 0)),
		int(chunk_data.get("chunk_deactivation_count", 0))
	]


func _get_spatial_index_debug_text() -> String:
	var world := _get_world_node()
	if not world or not world.has_method("get_spatial_index_debug_data"):
		return "unavailable"
	var spatial_data: Dictionary = world.get_spatial_index_debug_data()
	if spatial_data.is_empty():
		return "unavailable"
	return "tracked %d | cells R/C/M %d/%d/%d | total R/C/M %d/%d/%d | avg/cell %.1f | max/cell %d | stale removed %d" % [
		int(spatial_data.get("tracked_entities", 0)),
		int(spatial_data.get("resource_cells", 0)),
		int(spatial_data.get("creature_cells", 0)),
		int(spatial_data.get("meat_cells", 0)),
		int(spatial_data.get("resources_total", 0)),
		int(spatial_data.get("creatures_total", 0)),
		int(spatial_data.get("meat_total", 0)),
		float(spatial_data.get("average_entities_per_cell", 0.0)),
		int(spatial_data.get("max_entities_in_cell", 0)),
		int(spatial_data.get("stale_entries_removed_last_cleanup", 0))
	]


func _get_island_world_validation_summary_text(report: Dictionary = {}) -> String:
	var validation_report: Dictionary = report
	if validation_report.is_empty():
		var world := _get_world_node()
		if world and world.has_method("get_island_world_validation_report"):
			validation_report = world.get_island_world_validation_report()
	if validation_report.is_empty():
		var fallback_world := _get_world_node()
		if fallback_world == null or not fallback_world.has_method("get_island_world_validation_summary"):
			return "unavailable"
		return str(fallback_world.get_island_world_validation_summary())
	var passed := bool(validation_report.get("passed", false))
	var errors := Array(validation_report.get("errors", []))
	var warnings := Array(validation_report.get("warnings", []))
	return "%s | errors %d | warnings %d" % [
		"PASS" if passed else "FAIL",
		errors.size(),
		warnings.size()
	]


func _get_world_generation_summary_text() -> String:
	var world := _get_world_node()
	if world and world.has_method("get_world_generation_summary"):
		return str(world.get_world_generation_summary())
	return "unavailable"


func _on_damage_player_pressed() -> void:
	_call_player_debug_method("debug_damage_player")


func _on_heal_player_pressed() -> void:
	_call_player_debug_method("debug_heal_player")


func _on_reduce_hunger_energy_pressed() -> void:
	_call_player_debug_method("debug_reduce_hunger_energy")


func _on_restore_hunger_energy_pressed() -> void:
	_call_player_debug_method("debug_restore_hunger_energy")


func _call_player_debug_method(method_name: String) -> void:
	if player and player.has_method(method_name):
		player.call(method_name)
	_set_state_text(_build_state_text())
