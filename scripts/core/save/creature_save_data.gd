extends RefCounted
class_name CreatureSaveData

var entries: Array[Dictionary] = []


func load_from_save_data(data: Dictionary) -> void:
	entries = []
	if data.is_empty():
		return
	if data.has("creatures") and data.get("creatures") is Array:
		for entry in Array(data.get("creatures", [])):
			if typeof(entry) == TYPE_DICTIONARY:
				entries.append(Dictionary(entry).duplicate(true))
		return
	for key in ["varnaks", "small_prey", "grazers"]:
		if not data.has(key):
			continue
		for entry in Array(data.get(key, [])):
			if typeof(entry) == TYPE_DICTIONARY:
				var copy: Dictionary = Dictionary(entry).duplicate(true)
				copy["creature_type"] = key
				entries.append(copy)


func to_save_data() -> Array:
	return entries.duplicate(true)
