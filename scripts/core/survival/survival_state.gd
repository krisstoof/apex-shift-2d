extends RefCounted
class_name SurvivalState

var health: float
var hunger: float
var stamina: float
var rest: float
var campfire_regen_active: bool
var campfire_regen_distance: float
var god_mode: bool

func _init() -> void:
	_reset_to_max()

func _reset_to_max() -> void:
	var rules := SurvivalRules.new()
	health = rules.max_health
	hunger = rules.max_hunger
	stamina = rules.max_stamina
	rest = rules.max_rest
	campfire_regen_active = false
	campfire_regen_distance = -1.0
	god_mode = false
