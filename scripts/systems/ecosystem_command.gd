extends RefCounted
class_name EcosystemCommand

const PLANT_HARVESTED := "plant_harvested"
const PLANT_CONSUMED := "plant_consumed"
const SMALL_PREY_DEATH := "small_prey_death"
const GRAZER_DEATH := "grazer_death"
const VARNAK_DEATH := "varnak_death"
const GRAZER_NON_PLANT_FOOD := "grazer_non_plant_food"

var kind := ""
var biome_id := ""
var payload: Dictionary = {}


static func new_with(kind_value: String, biome_id_value: String, payload_value: Dictionary = {}):
	var command = new()
	command.kind = kind_value
	command.biome_id = biome_id_value
	command.payload = Dictionary(payload_value).duplicate(true)
	return command


static func from_payload(kind_value: String, payload_value: Dictionary):
	var biome_id_value := str(payload_value.get("biome_id", ""))
	var command = new_with(kind_value, biome_id_value, payload_value)
	return command


func to_dict() -> Dictionary:
	return {
		"kind": kind,
		"biome_id": biome_id,
		"payload": payload.duplicate(true)
	}
