extends RefCounted
class_name SurvivalRules

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")

var max_health: float = GAME_BALANCE.PLAYER_MAX_HEALTH
var max_hunger: float = GAME_BALANCE.PLAYER_MAX_HUNGER
var max_stamina: float = GAME_BALANCE.PLAYER_MAX_STAMINA
var max_rest: float = GAME_BALANCE.PLAYER_MAX_REST
var low_hunger: float = GAME_BALANCE.PLAYER_LOW_HUNGER
var exhausted_rest: float = GAME_BALANCE.PLAYER_EXHAUSTED_REST
var hunger_decay_rate: float = GAME_BALANCE.PLAYER_HUNGER_DECAY_RATE
var rest_decay_rate: float = GAME_BALANCE.PLAYER_REST_DECAY_RATE
var running_rest_decay_rate: float = GAME_BALANCE.PLAYER_RUNNING_REST_DECAY_RATE
var running_stamina_decay_rate: float = GAME_BALANCE.PLAYER_RUNNING_STAMINA_DECAY_RATE
var base_stamina_regen: float = GAME_BALANCE.PLAYER_BASE_STAMINA_REGEN
var low_hunger_stamina_regen_multiplier: float = GAME_BALANCE.PLAYER_LOW_HUNGER_STAMINA_REGEN_MULTIPLIER
var exhausted_rest_stamina_regen_multiplier: float = GAME_BALANCE.PLAYER_EXHAUSTED_REST_STAMINA_REGEN_MULTIPLIER
var campfire_stamina_regen_multiplier: float = GAME_BALANCE.PLAYER_CAMPFIRE_STAMINA_REGEN_MULTIPLIER
var health_regen_rate: float = GAME_BALANCE.PLAYER_HEALTH_REGEN_RATE
var campfire_health_regen_multiplier: float = GAME_BALANCE.PLAYER_CAMPFIRE_HEALTH_REGEN_MULTIPLIER
var starvation_damage_per_second: float = GAME_BALANCE.PLAYER_STARVATION_DAMAGE_PER_SECOND
var sleep_hunger_cost: float = GAME_BALANCE.PLAYER_SLEEP_HUNGER_COST
var sleep_health_restore: float = GAME_BALANCE.PLAYER_SLEEP_HEALTH_RESTORE
var low_hunger_speed_multiplier: float = GAME_BALANCE.PLAYER_LOW_HUNGER_SPEED_MULTIPLIER
var exhausted_rest_speed_multiplier: float = GAME_BALANCE.PLAYER_EXHAUSTED_REST_SPEED_MULTIPLIER
