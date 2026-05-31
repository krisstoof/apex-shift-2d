extends Control

var player: Node
var evolution_director: Node
var day_night_system: Node

@onready var title_label: Label = $Panel/TitleLabel
@onready var state_label: Label = $Panel/StateLabel
@onready var add_wood_button: Button = $Panel/AddWoodButton
@onready var add_stone_button: Button = $Panel/AddStoneButton
@onready var add_fiber_button: Button = $Panel/AddFiberButton
@onready var add_meat_button: Button = $Panel/AddMeatButton
@onready var add_torch_button: Button = $Panel/AddTorchButton
@onready var add_spear_button: Button = $Panel/AddSpearButton

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


func bind(p_player: Node, p_evolution_director: Node, p_day_night_system: Node) -> void:
	player = p_player
	evolution_director = p_evolution_director
	day_night_system = p_day_night_system


func _process(_delta: float) -> void:
	if not visible:
		return
	state_label.text = _build_state_text()


func toggle() -> void:
	set_open(not visible)


func set_open(open: bool) -> void:
	visible = open
	if visible:
		state_label.text = _build_state_text()


func _build_state_text() -> String:
	if not player or not evolution_director or not day_night_system:
		return "Waiting for game state..."
	var profile: Dictionary = evolution_director.get_profile() if evolution_director.has_method("get_profile") else {}
	var lines: Array[String] = []
	lines.append("Day: %d  Phase: %s  Night: %.2f" % [_get_day(), _get_day_phase(), _get_night_amount()])
	lines.append("Adaptation: generation %d  pressure %.2f" % [int(profile.get("generation", 1)), _get_adaptation_pressure(profile)])
	lines.append("Health: %d  Hunger: %d  Stamina: %d  Rest: %d" % [int(player.stats.health), int(player.stats.hunger), int(player.stats.stamina), int(player.stats.rest)])
	lines.append("Resources: wood %d  stone %d  fiber %d  meat %d" % [_get_item_count("wood"), _get_item_count("stone"), _get_item_count("fiber"), _get_item_count("meat")])
	lines.append("Crafted: torch %d  spear %s  traps %d" % [_get_item_count("torch"), "yes" if player.has_spear else "no", get_tree().get_nodes_in_group("traps").size()])
	lines.append("Campfire: %s" % _get_campfire_state())
	lines.append("Torch: %s" % _get_torch_state())
	lines.append("Animals: Varnaks %d" % get_tree().get_nodes_in_group("varnak").size())
	return "\n".join(lines)


func _get_day() -> int:
	return day_night_system.get_day() if day_night_system.has_method("get_day") else 1


func _get_day_phase() -> String:
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
	state_label.text = _build_state_text()


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
