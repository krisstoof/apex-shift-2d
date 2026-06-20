extends RefCounted
class_name InventorySaveData

var slots: Array[Dictionary] = []


func load_from_save_data(data: Dictionary) -> void:
	slots = []
	var source: Dictionary = Dictionary(data)
	if source.has("slots") and source.get("slots") is Array:
		for slot_value in Array(source.get("slots", [])):
			if typeof(slot_value) == TYPE_DICTIONARY:
				slots.append(Dictionary(slot_value).duplicate(true))
		return
	if source.has("items") and source.get("items") is Array:
		for slot_value in Array(source.get("items", [])):
			if typeof(slot_value) == TYPE_DICTIONARY:
				slots.append(Dictionary(slot_value).duplicate(true))
		return
	for key in ["wood", "stone", "fiber", "meat", "hide", "bone", "torch"]:
		var amount := int(source.get(key, 0))
		if amount > 0:
			slots.append({"item_id": key, "amount": amount})


func to_save_data() -> Dictionary:
	return {"slots": slots.duplicate(true)}
