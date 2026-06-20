extends RefCounted
class_name WorldSaveData

var world_seed := 0
var landmarks: Array[Dictionary] = []
var layout: Dictionary = {}
var version := 0


func load_from_save_data(data: Dictionary) -> void:
	var source: Dictionary = Dictionary(data)
	world_seed = int(source.get("world_seed", source.get("seed", world_seed)))
	version = int(source.get("version", version))
	layout = Dictionary(source.get("layout", layout)).duplicate(true)
	landmarks = []
	for landmark_value in Array(source.get("landmarks", [])):
		if typeof(landmark_value) == TYPE_DICTIONARY:
			landmarks.append(Dictionary(landmark_value).duplicate(true))


func to_save_data() -> Dictionary:
	return {
		"world_seed": world_seed,
		"landmarks": landmarks.duplicate(true),
		"layout": layout.duplicate(true),
		"version": version
	}
