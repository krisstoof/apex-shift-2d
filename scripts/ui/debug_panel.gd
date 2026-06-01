extends Control

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const DEBUG_TABS := [
	"Overview",
	"Player",
	"World",
	"Ecosystem",
	"Creatures",
	"Evolution",
	"Combat",
	"Events",
	"Tools"
]

var player: Node
var evolution_director: Node
var day_night_system: Node
var ecosystem_director: Node
var active_tab := "Overview"
var tab_bar: TabBar
var tools_scroll: ScrollContainer
var tools_grid: GridContainer
var tool_buttons: Array[Button] = []

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


func bind(p_player: Node, p_evolution_director: Node, p_day_night_system: Node, p_ecosystem_director: Node = null) -> void:
	player = p_player
	evolution_director = p_evolution_director
	day_night_system = p_day_night_system
	ecosystem_director = p_ecosystem_director


func _process(_delta: float) -> void:
	if not visible:
		return
	_set_state_text(_build_state_text())


func toggle() -> void:
	set_open(not visible)


func set_open(open: bool) -> void:
	visible = open
	if visible:
		_update_active_tab_view()
		_set_state_text(_build_state_text())


func _set_state_text(text: String) -> void:
	state_label.text = text
	var line_count := text.split("\n").size()
	state_label.custom_minimum_size = Vector2(560.0, max(390.0, float(line_count) * 20.0))


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
	_add_tool_button_node(increase_adaptation_button, "Evolution")
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
	_update_active_tab_view()
	_set_state_text(_build_state_text())


func _update_active_tab_view() -> void:
	var has_tab_buttons := _update_tool_buttons_for_active_tab()
	state_scroll.visible = true
	state_scroll.offset_bottom = -194.0 if has_tab_buttons else -12.0
	if tools_scroll:
		tools_scroll.visible = has_tab_buttons


func _update_tool_buttons_for_active_tab() -> bool:
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
		"Evolution":
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
	var lines: Array[String] = []
	lines.append("Day %d | %s | night %.2f" % [_get_day(), _get_day_phase(), _get_night_amount()])
	lines.append("Player HP %d | H %d | Sta %d | Rest %d" % [int(player.stats.health), int(player.stats.hunger), int(player.stats.stamina), int(player.stats.rest)])
	lines.append("Biome %s" % _get_current_biome_name())
	lines.append("Live Varnaks %d | SmallPrey %d | Grazers %d" % [
		get_tree().get_nodes_in_group("varnak").size(),
		_get_ecosystem_population_total("small_prey_population"),
		_get_ecosystem_population_total("grazer_population")
	])
	lines.append("creatures_out_of_bounds_count = %d" % _get_creatures_out_of_bounds_count())
	lines.append("Ecosystem warnings: %s" % _get_ecosystem_warnings_text())
	lines.append("Generation %d" % int(profile.get("generation", 1)))
	return "\n".join(lines)


func _build_player_text() -> String:
	var lines: Array[String] = []
	lines.append("Player")
	lines.append("Health %d | Hunger %d | Stamina %d | Rest %d" % [
		int(player.stats.health),
		int(player.stats.hunger),
		int(player.stats.stamina),
		int(player.stats.rest)
	])
	lines.append("Inventory")
	lines.append("Wood %d | Stone %d | Fiber %d | Meat %d" % [
		_get_item_count("wood"),
		_get_item_count("stone"),
		_get_item_count("fiber"),
		_get_item_count("meat")
	])
	lines.append("Torch %d | %s" % [
		_get_item_count("torch"),
		_get_torch_state()
	])
	lines.append("Spear %s | Bow %s" % [_get_spear_state(), _get_bow_state()])
	lines.append("Campfire %s | Traps %d" % [_get_campfire_state(), get_tree().get_nodes_in_group("traps").size()])
	return "\n".join(lines)


func _build_world_text() -> String:
	var lines: Array[String] = []
	lines.append("World")
	lines.append("Current biome: %s" % _get_current_biome_name())
	lines.append("Player position: %s" % _get_position_text(player.global_position if player else Vector2.ZERO))
	lines.append("World bounds: %s" % str(WORLD_CONFIG.WORLD_RECT))
	lines.append("creatures_out_of_bounds_count = %d" % _get_creatures_out_of_bounds_count())
	lines.append("Campfires: %d | Traps: %d" % [
		get_tree().get_nodes_in_group("campfires").size(),
		get_tree().get_nodes_in_group("traps").size()
	])
	lines.append("Resources: trees %d | bushes %d | grass %d | rocks %d" % [
		get_tree().get_nodes_in_group("trees").size(),
		get_tree().get_nodes_in_group("bushes").size(),
		get_tree().get_nodes_in_group("grass").size(),
		get_tree().get_nodes_in_group("rocks").size()
	])
	lines.append("Growth: %s" % _get_resource_growth_text())
	return "\n".join(lines)


func _build_ecosystem_text() -> String:
	return "\n".join(_get_ecosystem_debug_lines())


func _build_creatures_text() -> String:
	var lines: Array[String] = []
	var varnaks := get_tree().get_nodes_in_group("varnak")
	lines.append("Creatures")
	lines.append("creatures_out_of_bounds_count = %d" % _get_creatures_out_of_bounds_count())
	lines.append("Varnaks %d | %s" % [varnaks.size(), _get_varnak_state_summary(varnaks)])
	lines.append("SmallPrey visible %d | %s" % [
		get_tree().get_nodes_in_group("small_prey").size(),
		_get_creature_state_summary("small_prey")
	])
	lines.append("Grazers visible %d | %s" % [
		get_tree().get_nodes_in_group("grazer").size(),
		_get_grazer_state_summary()
	])
	lines.append("Avg Varnak HP %s | nearest %s" % [
		_get_average_varnak_health_text(varnaks),
		_get_nearest_varnak_text(varnaks)
	])
	return "\n".join(lines)


func _build_evolution_text(profile: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("Evolution")
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
	var lines: Array[String] = []
	lines.append("Combat")
	lines.append("Player HP %d | Spear %s | Bow %s" % [
		int(player.stats.health),
		_get_spear_state(),
		_get_bow_state()
	])
	lines.append("Torch %s | Campfire %s" % [_get_torch_state(), _get_campfire_state()])
	lines.append("Varnaks %d | nearest %s" % [
		get_tree().get_nodes_in_group("varnak").size(),
		_get_nearest_varnak_text(get_tree().get_nodes_in_group("varnak"))
	])
	lines.append("Visible prey %d | grazers %d" % [
		get_tree().get_nodes_in_group("small_prey").size(),
		get_tree().get_nodes_in_group("grazer").size()
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


func _get_position_text(position: Vector2) -> String:
	return "(%d, %d)" % [int(round(position.x)), int(round(position.y))]


func _get_current_biome_name() -> String:
	if not player:
		return "unknown"
	for biome in WORLD_CONFIG.get_biome_zones():
		if Geometry2D.is_point_in_polygon(player.global_position, PackedVector2Array(biome.get("points", []))):
			return str(biome.get("name", "Biome"))
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
		for creature in get_tree().get_nodes_in_group(group_name):
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


func _get_adaptation_pressure(profile: Dictionary) -> float:
	var keys := ["aggression", "trap_awareness", "pack_coordination", "night_activity", "base_curiosity", "stalk_tendency"]
	var total := 0.0
	for key in keys:
		total += float(profile.get(key, 0.0))
	return total / float(keys.size())


func _get_varnak_debug_lines(profile: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var varnaks := get_tree().get_nodes_in_group("varnak")
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
		get_tree().get_nodes_in_group("grazer").size(),
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
		lines.append("  SmallPrey %d | Grazers %d | niche %s | stress %d" % [
			int(round(float(state.get("small_prey_population", 0.0)))),
			int(round(float(state.get("grazer_population", 0.0)))),
			str(state.get("current_niche", "HERBIVORE")).to_lower(),
			int(state.get("generations_under_food_stress", 0))
		])
		lines.append("  diet P %.2f M %.2f S %.2f | aggr %.2f" % [
			float(state.get("average_plant_diet", 0.85)),
			float(state.get("average_meat_diet", 0.05)),
			float(state.get("average_scavenger_diet", 0.10)),
			float(state.get("average_aggression", 0.15))
		])
		lines.append("  varnak %.2f | food stress %.2f | over %.2f" % [
			float(state.get("varnak_ecosystem_pressure", state.get("predator_pressure", 0.0))),
			float(state.get("food_stress", 0.0)),
			float(state.get("overgrazing_level", state.get("overgrazing_pressure", 0.0)))
		])
	return lines


func _get_grazer_state_summary() -> String:
	var grazers := get_tree().get_nodes_in_group("grazer")
	if grazers.is_empty():
		return "none"
	var counts := {}
	var hunger_total := 0.0
	var energy_total := 0.0
	var hunger_count := 0
	for grazer in grazers:
		if not is_instance_valid(grazer) or not grazer.has_method("get_debug_data"):
			continue
		var data: Dictionary = grazer.get_debug_data()
		var state_name := str(data.get("state", "unknown")).to_lower()
		counts[state_name] = int(counts.get(state_name, 0)) + 1
		hunger_total += float(data.get("hunger", 0.0))
		energy_total += float(data.get("energy", 0.0))
		hunger_count += 1
	var parts: Array[String] = []
	for key in counts.keys():
		parts.append("%s:%d" % [key, int(counts[key])])
	if hunger_count > 0:
		parts.append("hunger:%d%%" % int(round(hunger_total / float(hunger_count) * 100.0)))
		parts.append("energy:%d%%" % int(round(energy_total / float(hunger_count) * 100.0)))
	return ", ".join(parts)


func _get_creature_state_summary(group_name: String) -> String:
	var creatures := get_tree().get_nodes_in_group(group_name)
	if creatures.is_empty():
		return "none"
	var counts := {}
	var hunger_total := 0.0
	var energy_total := 0.0
	var hunger_count := 0
	for creature in creatures:
		if not is_instance_valid(creature) or not creature.has_method("get_debug_data"):
			continue
		var data: Dictionary = creature.get_debug_data()
		var state_name := str(data.get("state", "unknown")).to_lower()
		counts[state_name] = int(counts.get(state_name, 0)) + 1
		hunger_total += float(data.get("hunger", 0.0))
		energy_total += float(data.get("energy", 0.0))
		hunger_count += 1
	var parts: Array[String] = []
	for key in counts.keys():
		parts.append("%s:%d" % [key, int(counts[key])])
	if hunger_count > 0:
		parts.append("hunger:%d%%" % int(round(hunger_total / float(hunger_count) * 100.0)))
		parts.append("energy:%d%%" % int(round(energy_total / float(hunger_count) * 100.0)))
	return ", ".join(parts)


func _get_varnak_state_summary(varnaks: Array) -> String:
	if varnaks.is_empty():
		return "none"
	var counts := {}
	for varnak in varnaks:
		if not is_instance_valid(varnak):
			continue
		var state_name := "unknown"
		if varnak.has_method("get_debug_data"):
			var data: Dictionary = varnak.get_debug_data()
			state_name = str(data.get("state", state_name)).to_lower()
		counts[state_name] = int(counts.get(state_name, 0)) + 1
	var parts: Array[String] = []
	for key in counts.keys():
		parts.append("%s:%d" % [key, int(counts[key])])
	return ", ".join(parts)


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
		return "n/a"
	return "%s %.0fpx hp %d/%d" % [
		str(nearest_data.get("state", "unknown")).to_lower(),
		nearest_distance,
		int(nearest_data.get("health", 0.0)),
		int(nearest_data.get("max_health", 0.0))
	]


func _get_campfire_state() -> String:
	var active_count := 0
	var total_count := 0
	for campfire in get_tree().get_nodes_in_group("campfires"):
		if not is_instance_valid(campfire):
			continue
		total_count += 1
		if campfire.get("active") == true:
			active_count += 1
	return "%d active / %d total" % [active_count, total_count]


func _get_torch_state() -> String:
	if not player.has_method("is_torch_active") or not player.is_torch_active():
		return "inactive"
	var remaining: float = player.get_torch_remaining_seconds() if player.has_method("get_torch_remaining_seconds") else 0.0
	return "active %.1fs" % remaining


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


func _on_advance_resource_growth_pressed() -> void:
	_call_optional_world_debug_method("debug_advance_resource_growth_day", "Resource growth debug is not available yet")


func _on_force_full_vegetation_regrowth_pressed() -> void:
	_call_optional_world_debug_method("debug_force_full_vegetation_regrowth", "Vegetation regrowth debug is not available yet")


func _on_reset_resource_growth_pressed() -> void:
	_call_optional_world_debug_method("debug_reset_resource_growth", "Resource growth reset debug is not available yet")


func _on_teleport_out_of_bounds_pressed() -> void:
	_call_optional_world_debug_method("debug_teleport_out_of_bounds_creatures", "Creature bounds debug is not available yet")


func _call_optional_world_debug_method(method_name: String, missing_message: String) -> void:
	var world := _get_world_node()
	if world and world.has_method(method_name):
		world.call(method_name)
	else:
		_post_debug_message(missing_message)
	_set_state_text(_build_state_text())


func _get_world_node() -> Node:
	if not get_tree() or not get_tree().current_scene:
		return null
	return get_tree().current_scene.get_node_or_null("World")


func _post_debug_message(message: String) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_method("post_message"):
		event_bus.post_message(message)


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
