extends RefCounted
class_name DependencyRegistry

var values: Dictionary = {}


func set_value(key: String, value: Variant) -> void:
	if key.is_empty():
		return
	values[key] = value


func get_value(key: String, default_value: Variant = null) -> Variant:
	if key.is_empty():
		return default_value
	return values.get(key, default_value)


func has_value(key: String) -> bool:
	if key.is_empty():
		return false
	return values.has(key)


func remove_value(key: String) -> void:
	if key.is_empty():
		return
	values.erase(key)


func clear() -> void:
	values.clear()


func duplicate_values() -> Dictionary:
	return values.duplicate()
