extends Control

var player: Node
var evolution_director: Node
var day_night_system: Node
var ecosystem_director: Node

@onready var title_label: Label = $Panel/TitleLabel
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
		_set_state_text(_build_state_text())


func _set_state_text(text: String) -> void:
	state_label.text = text
	var line_count := text.split("\n").size()
	state_label.custom_minimum_size = Vector2(560.0, max(390.0, float(line_count) * 20.0))


func _build_state_text() -> String:
	if not player or not evolution_director or not day_night_system:
		return "Waiting for game state..."
	var profile: Dictionary = evolution_director.get_profile() if evolution_director.has_method("get_profile") else {}
	var lines: Array[String] = []
	lines.append("Day %d | %s | night %.2f" % [_get_day(), _get_day_phase(), _get_night_amount()])
	lines.append("Player HP %d | H %d | Sta %d | Rest %d" % [int(player.stats.health), int(player.stats.hunger), int(player.stats.stamina), int(player.stats.rest)])
	lines.append("Inv W%d S%d F%d M%d | Torch %d %s | Spear %s" % [
		_get_item_count("wood"),
		_get_item_count("stone"),
		_get_item_count("fiber"),
		_get_item_count("meat"),
		_get_item_count("torch"),
		_get_torch_state(),
		"yes" if player.has_spear else "no"
	])
	lines.append("Campfire %s | Traps %d" % [_get_campfire_state(), get_tree().get_nodes_in_group("traps").size()])
	lines.append_array(_get_ecosystem_debug_lines())
	lines.append_array(_get_varnak_debug_lines(profile))
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
		if bool(campfire.active):
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
	var world := get_tree().current_scene.get_node_or_null("World")
	if world and world.has_method("debug_spawn_animal"):
		world.debug_spawn_animal(aggressive)
	_set_state_text(_build_state_text())


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
