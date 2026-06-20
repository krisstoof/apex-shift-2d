extends RefCounted
class_name ResourceSaveData

var entries: Array[Dictionary] = []


func load_from_save_data(data: Dictionary) -> void:
	entries = []
	var source: Variant = data.get("resources", data)
	if source is Array:
		for entry in Array(source):
			if typeof(entry) == TYPE_DICTIONARY:
				entries.append(Dictionary(entry).duplicate(true))


func to_save_data() -> Array:
	return entries.duplicate(true)
