extends Node

signal profile_changed(profile: Dictionary)

var species_profile: Dictionary = {}
var trap_kills := 0
var player_kills := 0
var fire_scares := 0
var wall_attacks := 0
var days_since_generation := 0
var days_until_next_generation := 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	days_until_next_generation = _roll_generation_interval()
	species_profile = _load_default_profile()
	get_node("/root/EventBus").game_event.connect(_on_game_event)
	print("[Evolution] Initial profile: %s" % species_profile)


func get_profile() -> Dictionary:
	return species_profile.duplicate(true)


func get_save_data() -> Dictionary:
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


func force_generation_change() -> void:
	_change_generation("manual")


func debug_increase_adaptation() -> void:
	for key in ["aggression", "trap_awareness", "pack_coordination", "night_activity", "base_curiosity", "stalk_tendency"]:
		species_profile[key] = _clamp_profile(key, 0.05)
	get_node("/root/EventBus").emit_game_event("debug_adaptation_increased", {"profile": get_profile()})
	get_node("/root/EventBus").post_message("Debug adaptation increased")
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
				_change_generation("natural_cycle")


func _change_generation(reason: String) -> void:
	species_profile["generation"] = int(species_profile.get("generation", 1)) + 1
	var adapted_to_traps := trap_kills >= 1
	var adapted_to_fire := fire_scares >= 1
	var adapted_to_player := player_kills >= 1
	if adapted_to_traps:
		species_profile["trap_awareness"] = _clamp_profile("trap_awareness", 0.15)
	if adapted_to_fire:
		species_profile["fire_fear"] = _clamp_profile("fire_fear", -0.10)
		species_profile["stalk_tendency"] = _clamp_profile("stalk_tendency", 0.10)
	if adapted_to_player:
		species_profile["aggression"] = _clamp_profile("aggression", 0.10)
		species_profile["pack_coordination"] = _clamp_profile("pack_coordination", 0.10)
	if wall_attacks >= 1:
		species_profile["base_curiosity"] = _clamp_profile("base_curiosity", 0.10)
	trap_kills = 0
	player_kills = 0
	fire_scares = 0
	wall_attacks = 0
	days_since_generation = 0
	days_until_next_generation = _roll_generation_interval()
	print("[Evolution] Generation changed (%s): %s" % [reason, species_profile])
	get_node("/root/EventBus").emit_game_event("generation_changed", {"profile": get_profile(), "reason": reason})
	get_node("/root/EventBus").emit_game_event("center_notification", {"text": "Generation %d evolved" % int(species_profile.get("generation", 1))})
	get_node("/root/EventBus").post_message("Generation changed")
	if adapted_to_traps:
		get_node("/root/EventBus").post_message("Varnaks adapted to traps")
	if adapted_to_fire:
		get_node("/root/EventBus").post_message("Varnaks are less afraid of fire")
	if adapted_to_player:
		get_node("/root/EventBus").post_message("Varnaks became more aggressive")
	profile_changed.emit(get_profile())


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
