extends RefCounted
class_name GameSaveData

const WORLD_SAVE_DATA := preload("res://scripts/core/save/world_save_data.gd")
const PLAYER_SAVE_DATA := preload("res://scripts/core/save/player_save_data.gd")
const INVENTORY_SAVE_DATA := preload("res://scripts/core/save/inventory_save_data.gd")
const CREATURE_SAVE_DATA := preload("res://scripts/core/save/creature_save_data.gd")
const RESOURCE_SAVE_DATA := preload("res://scripts/core/save/resource_save_data.gd")

var version := 5
var world: WorldSaveData = WORLD_SAVE_DATA.new()
var world_generation: Dictionary = {}
var player: PlayerSaveData = PLAYER_SAVE_DATA.new()
var resources: ResourceSaveData = RESOURCE_SAVE_DATA.new()
var varnaks: CreatureSaveData = CREATURE_SAVE_DATA.new()
var small_prey: CreatureSaveData = CREATURE_SAVE_DATA.new()
var grazers: CreatureSaveData = CREATURE_SAVE_DATA.new()
var buildings: Array[Dictionary] = []
var storage_boxes: Array[Dictionary] = []
var day_night: Dictionary = {}
var evolution: Dictionary = {}
var ecosystem: Dictionary = {}
var clock: Dictionary = {}


func load_from_save_data(data: Dictionary) -> void:
	var source: Dictionary = Dictionary(data)
	version = int(source.get("version", version))
	world.load_from_save_data(Dictionary(source.get("world", {})))
	world_generation = Dictionary(source.get("world_generation", world_generation)).duplicate(true)
	player.load_from_save_data(Dictionary(source.get("player", {})))
	resources.load_from_save_data(source)
	varnaks.load_from_save_data({"varnaks": Array(source.get("varnaks", []))})
	small_prey.load_from_save_data({"small_prey": Array(source.get("small_prey", []))})
	grazers.load_from_save_data({"grazers": Array(source.get("grazers", []))})
	buildings = _copy_dictionary_array(Array(source.get("buildings", [])))
	storage_boxes = _copy_dictionary_array(Array(source.get("storage_boxes", [])))
	day_night = Dictionary(source.get("day_night", {})).duplicate(true)
	evolution = Dictionary(source.get("evolution", {})).duplicate(true)
	ecosystem = Dictionary(source.get("ecosystem", {})).duplicate(true)
	clock = Dictionary(source.get("clock", {})).duplicate(true)


func to_save_data() -> Dictionary:
	var result := {
		"version": version,
		"world": world.to_save_data(),
		"world_generation": world_generation.duplicate(true),
		"player": player.to_save_data(),
		"resources": resources.to_save_data(),
		"varnaks": varnaks.to_save_data(),
		"small_prey": small_prey.to_save_data(),
		"grazers": grazers.to_save_data(),
		"buildings": _copy_dictionary_array(buildings),
		"storage_boxes": _copy_dictionary_array(storage_boxes),
		"day_night": day_night.duplicate(true),
		"evolution": evolution.duplicate(true),
		"ecosystem": ecosystem.duplicate(true)
	}
	if not clock.is_empty():
		result["clock"] = clock.duplicate(true)
	return result


static func _copy_dictionary_array(source: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in source:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append(Dictionary(entry).duplicate(true))
	return result
