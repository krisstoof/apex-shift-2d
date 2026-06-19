extends RefCounted
class_name EntityId

var value: String = ""


func _init(p_value: String = "") -> void:
	value = p_value


static func from_string(p_value: String) -> EntityId:
	return EntityId.new(p_value)


static func empty() -> EntityId:
	return EntityId.new("")


func is_valid() -> bool:
	return not value.strip_edges().is_empty()


func equals(other: EntityId) -> bool:
	return other != null and value == other.value


func as_string() -> String:
	return value


func _to_string() -> String:
	return value


func to_dict() -> Dictionary:
	return {
		"value": value
	}


static func from_dict(data: Dictionary) -> EntityId:
	return EntityId.new(str(data.get("value", "")))
