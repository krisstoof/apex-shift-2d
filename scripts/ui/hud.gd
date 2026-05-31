extends CanvasLayer

var player: Node
var evolution_director: Node
var day_night_system: Node
var message := ""
var message_history: Array[String] = []

@onready var stats_label: Label = $Panel/StatsLabel
@onready var prompt_label: Label = $Panel/PromptLabel
@onready var message_label: Label = $Panel/MessageLabel
@onready var skill_icon_bar: Control = $SkillIconBar
@onready var minimap: Control = $Minimap

func _ready() -> void:
	get_node("/root/EventBus").message_posted.connect(_on_message)


func bind(p_player: Node, p_evolution_director: Node, p_day_night_system: Node) -> void:
	player = p_player
	evolution_director = p_evolution_director
	day_night_system = p_day_night_system
	skill_icon_bar.bind(player)
	var world := get_tree().current_scene.get_node_or_null("World")
	var world_rect: Rect2 = world.get_world_rect() if world and world.has_method("get_world_rect") else Rect2(-2160, -1320, 4320, 2640)
	var biome_zones: Array[Dictionary] = world.get_biome_zones() if world and world.has_method("get_biome_zones") else []
	minimap.bind(player, world_rect, biome_zones)


func _process(_delta: float) -> void:
	if not player or not evolution_director or not day_night_system:
		return
	var profile: Dictionary = evolution_director.get_profile()
	var live_varnaks := get_tree().get_nodes_in_group("varnak").size()
	stats_label.text = "\n".join([
		"Health: %3d  Hunger: %3d  Stamina: %3d  Rest: %3d  %s" % [player.stats.health, player.stats.hunger, player.stats.stamina, player.stats.rest, player.stats.get_condition_text()],
		"Wood: %d  Stone: %d  Fiber: %d  Meat: %d  Spear: %s" % [player.inventory.get_amount("wood"), player.inventory.get_amount("stone"), player.inventory.get_amount("fiber"), player.inventory.get_amount("meat"), "yes" if player.has_spear else "no"],
		"Day: %d  Generation: %d  Live Varnaks: %d" % [day_night_system.get_day(), profile.get("generation", 1), live_varnaks],
		"Events trap:%d player:%d fire:%d" % [evolution_director.trap_kills, evolution_director.player_kills, evolution_director.fire_scares],
		"Varnak aggression %.2f  fire_fear %.2f  trap_awareness %.2f  pack %.2f" % [profile.get("aggression", 0.0), profile.get("fire_fear", 0.0), profile.get("trap_awareness", 0.0), profile.get("pack_coordination", 0.0)]
	])
	prompt_label.text = player.get_interaction_prompt() if player.has_method("get_interaction_prompt") else ""
	message_label.text = "\n".join(message_history)


func _on_message(new_message: String) -> void:
	message = new_message
	message_history.append(new_message)
	if message_history.size() > 4:
		message_history.pop_front()
