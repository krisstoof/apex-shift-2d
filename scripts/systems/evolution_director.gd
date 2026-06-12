extends Node

signal profile_changed(profile: Dictionary)

# Lightweight Varnak adaptation system.
#
# This node keeps the historical `EvolutionDirector` name for save/load and scene compatibility,
# but the current prototype does not implement a full species evolution model.
#
# The system adjusts a single Varnak profile in response to gameplay events:
# - trap kills increase trap awareness,
# - fire scares reduce fire fear and increase stalking,
# - player kills increase aggression and pack coordination,
# - wall attacks increase curiosity.
#
# Do not treat this as genetics, multi-species evolution, or a full population simulation.
# User-facing text should call this "animal adaptation" or "Varnak adaptation".

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")

var species_profile: Dictionary = {}
var trap_kills := 0
var player_kills := 0
var fire_scares := 0
var wall_attacks := 0
var days_since_generation := 0
var days_until_next_generation := 0
var rng := RandomNumberGenerator.new()


func _get_event_bus() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("EventBus")


func _post_event_message(message: String) -> void:
	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_method("post_message"):
		event_bus.post_message(message)


func _emit_game_event(event_name: String, payload: Dictionary = {}) -> void:
	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_method("emit_game_event"):
		event_bus.emit_game_event(event_name, payload)

func _ready() -> void:
	rng.randomize()
	days_until_next_generation = _roll_generation_interval()
	species_profile = _load_default_profile()
	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_signal("game_event"):
		event_bus.game_event.connect(_on_game_event)


func get_profile() -> Dictionary:
	return species_profile.duplicate(true)


func get_save_data() -> Dictionary:
	# Save keys keep historical generation naming for backward compatibility.
	# User-facing text should describe this as adaptation steps.
	return {
		"species_profile": species_profile.duplicate(true),
		"trap_kills": trap_kills,
		"player_kills": player_kills,
		"fire_scares": fire_scares,
		"wall_attacks": wall_attacks,
		"days_since_generation": days_since_generation,
		"days_until_next_generation": days_until_next_generation
	}


func restore_from_data(data: Dictionary) -> void:
	var profile = data.get("species_profile", species_profile)
	if typeof(profile) == TYPE_DICTIONARY:
		species_profile = Dictionary(profile).duplicate(true)
	trap_kills = int(data.get("trap_kills", trap_kills))
	player_kills = int(data.get("player_kills", player_kills))
	fire_scares = int(data.get("fire_scares", fire_scares))
	wall_attacks = int(data.get("wall_attacks", wall_attacks))
	days_since_generation = int(data.get("days_since_generation", days_since_generation))
	days_until_next_generation = int(data.get("days_until_next_generation", max(days_until_next_generation, 2)))
	profile_changed.emit(get_profile())


func force_adaptation_step() -> void:
	_apply_adaptation_step("manual")


func force_generation_change() -> void:
	force_adaptation_step()


func debug_increase_adaptation() -> void:
	for key in ["aggression", "trap_awareness", "pack_coordination", "night_activity", "base_curiosity", "stalk_tendency"]:
		species_profile[key] = _clamp_profile(key, GAME_BALANCE.ADAPTATION_DEBUG_GROWTH)
	_emit_game_event("debug_adaptation_increased", {"profile": get_profile()})
	_post_event_message("Debug: Varnak adaptation increased")
	profile_changed.emit(get_profile())


func _on_game_event(event_name: String, _payload: Dictionary) -> void:
	match event_name:
		"varnak_killed_by_trap":
			trap_kills += 1
		"varnak_killed_by_player":
			player_kills += 1
		"varnak_scared_by_fire":
			fire_scares += 1
		"varnak_attacked_wall":
			wall_attacks += 1
		"day_ended":
			days_since_generation += 1
			if days_since_generation >= days_until_next_generation:
				_apply_adaptation_step("natural_cycle")


func _apply_adaptation_step(reason: String) -> void:
	species_profile["generation"] = int(species_profile.get("generation", 1)) + 1
	var adapted_to_traps := trap_kills >= 1
	var adapted_to_fire := fire_scares >= 1
	var adapted_to_player := player_kills >= 1
	if adapted_to_traps:
		species_profile["trap_awareness"] = _clamp_profile("trap_awareness", GAME_BALANCE.ADAPTATION_TRAP_AWARENESS_GROWTH)
	if adapted_to_fire:
		species_profile["fire_fear"] = _clamp_profile("fire_fear", GAME_BALANCE.ADAPTATION_FIRE_FEAR_DELTA)
		species_profile["stalk_tendency"] = _clamp_profile("stalk_tendency", GAME_BALANCE.ADAPTATION_STALK_TENDENCY_GROWTH)
	if adapted_to_player:
		species_profile["aggression"] = _clamp_profile("aggression", GAME_BALANCE.ADAPTATION_PLAYER_AGGRESSION_GROWTH)
		species_profile["pack_coordination"] = _clamp_profile("pack_coordination", GAME_BALANCE.ADAPTATION_PACK_COORDINATION_GROWTH)
	if wall_attacks >= 1:
		species_profile["base_curiosity"] = _clamp_profile("base_curiosity", GAME_BALANCE.ADAPTATION_WALL_CURIOSITY_GROWTH)
	trap_kills = 0
	player_kills = 0
	fire_scares = 0
	wall_attacks = 0
	days_since_generation = 0
	days_until_next_generation = _roll_generation_interval()
	var adaptation_step := int(species_profile.get("generation", 1))
	_emit_game_event("generation_changed", {"profile": get_profile(), "reason": reason, "adaptation_step": adaptation_step})
	_emit_game_event("varnak_adaptation_changed", {"profile": get_profile(), "reason": reason, "adaptation_step": adaptation_step})
	_emit_game_event("center_notification", {"text": "Varnaks adapted"})
	_post_event_message("Varnaks adapted")
	if adapted_to_traps:
		_post_event_message("Varnaks adapted to traps")
	if adapted_to_fire:
		_post_event_message("Varnaks adapted to fire")
	if adapted_to_player:
		_post_event_message("Varnaks became more aggressive")
	if wall_attacks >= 1:
		_post_event_message("Varnaks became more curious")
	profile_changed.emit(get_profile())


func _change_generation(reason: String) -> void:
	_apply_adaptation_step(reason)


func _roll_generation_interval() -> int:
	return rng.randi_range(2, 5)


func _clamp_profile(key: String, delta: float) -> float:
	return clamp(float(species_profile.get(key, 0.0)) + delta, 0.0, 1.0)


func _load_default_profile() -> Dictionary:
	var path := "res://data/species_varnak.json"
	if FileAccess.file_exists(path):
		var text := FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(text)
		if typeof(parsed) == TYPE_DICTIONARY:
			return parsed
	return {
		"species_name": "Varnak",
		"generation": 1,
		"aggression": 0.45,
		"fire_fear": 0.85,
		"trap_awareness": 0.10,
		"pack_coordination": 0.20,
		"night_activity": 0.25,
		"base_curiosity": 0.10,
		"stalk_tendency": 0.15
	}
