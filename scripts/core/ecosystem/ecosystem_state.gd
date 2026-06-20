extends RefCounted
class_name EcosystemState

const BIOME_STATE := preload("res://scripts/core/ecosystem/biome_ecosystem_state.gd")

var biome_states: Dictionary = {}
var source := "core"
var day := 1

func set_biome_state(state: BiomeEcosystemState) -> void:
	if state == null or state.biome_id.is_empty():
		return
	biome_states[state.biome_id] = state.duplicate_state()

func get_biome_state(biome_id: String) -> BiomeEcosystemState:
	if not biome_states.has(biome_id):
		return null
	return (biome_states[biome_id] as BiomeEcosystemState).duplicate_state()

func get_biome_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in biome_states.keys():
		ids.append(str(key))
	ids.sort()
	return ids

func to_biome_state_dictionary() -> Dictionary:
	var result: Dictionary = {}
	for biome_id in get_biome_ids():
		var state: BiomeEcosystemState = biome_states[biome_id] as BiomeEcosystemState
		if state != null:
			result[biome_id] = state.to_dictionary()
	return result

func to_dictionary() -> Dictionary:
	return {
		"biome_states": to_biome_state_dictionary(),
		"source": source,
		"day": day
	}

func load_from_dictionary(data: Dictionary) -> void:
	biome_states.clear()
	source = str(data.get("source", data.get("ecosystem_state_source", source)))
	day = maxi(int(data.get("day", day)), 1)
	var raw_states: Dictionary = Dictionary(data.get("biome_states", {}))
	if typeof(raw_states) != TYPE_DICTIONARY:
		return
	for key in Dictionary(raw_states).keys():
		var biome_id: String = str(key)
		var raw_state: Dictionary = Dictionary(Dictionary(raw_states).get(key, {})).duplicate(true)
		if not raw_state.has("biome_id"):
			raw_state["biome_id"] = biome_id
		set_biome_state(BIOME_STATE.from_dictionary(raw_state))

func duplicate_state() -> EcosystemState:
	var copy: EcosystemState = EcosystemState.new()
	copy.load_from_dictionary(to_dictionary())
	return copy

static func from_dictionary(data: Dictionary) -> EcosystemState:
	var state: EcosystemState = EcosystemState.new()
	state.load_from_dictionary(data)
	return state

static func from_biome_state_dictionary(states: Dictionary, p_source: String = "adapter", p_day: int = 1) -> EcosystemState:
	var ecosystem_state: EcosystemState = EcosystemState.new()
	ecosystem_state.source = p_source
	ecosystem_state.day = maxi(p_day, 1)
	for key in states.keys():
		var biome_id: String = str(key)
		var data: Dictionary = Dictionary(states.get(key, {})).duplicate(true)
		if not data.has("biome_id"):
			data["biome_id"] = biome_id
		ecosystem_state.set_biome_state(BIOME_STATE.from_dictionary(data))
	return ecosystem_state
