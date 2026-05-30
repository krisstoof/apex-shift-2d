extends CanvasLayer

var player: Node
var evolution_director: Node
var day_night_system: Node
var message := ""

@onready var stats_label: Label = $Panel/StatsLabel
@onready var prompt_label: Label = $Panel/PromptLabel
@onready var message_label: Label = $Panel/MessageLabel

func _ready() -> void:
	get_node("/root/EventBus").message_posted.connect(_on_message)


func bind(p_player: Node, p_evolution_director: Node, p_day_night_system: Node) -> void:
	player = p_player
	evolution_director = p_evolution_director
	day_night_system = p_day_night_system


func _process(_delta: float) -> void:
	if not player or not evolution_director or not day_night_system:
		return
	var profile: Dictionary = evolution_director.get_profile()
	stats_label.text = "\n".join([
		"Health: %3d  Hunger: %3d  Stamina: %3d" % [player.stats.health, player.stats.hunger, player.stats.stamina],
		"Wood: %d  Stone: %d  Fiber: %d  Spear: %s" % [player.inventory.get_amount("wood"), player.inventory.get_amount("stone"), player.inventory.get_amount("fiber"), "yes" if player.has_spear else "no"],
		"Day: %d  Generation: %d" % [day_night_system.get_day(), profile.get("generation", 1)],
		"Varnak aggression %.2f  fire_fear %.2f  trap_awareness %.2f  pack %.2f" % [profile.get("aggression", 0.0), profile.get("fire_fear", 0.0), profile.get("trap_awareness", 0.0), profile.get("pack_coordination", 0.0)]
	])
	prompt_label.text = player.get_interaction_prompt() if player.has_method("get_interaction_prompt") else ""
	message_label.text = message


func _on_message(new_message: String) -> void:
	message = new_message
