extends RefCounted
class_name SaveSerializer

const GAME_SAVE_DATA := preload("res://scripts/core/save/game_save_data.gd")


static func serialize(game_save_data: Variant) -> Dictionary:
	var data: Variant = game_save_data
	if game_save_data is GameSaveData:
		data = (game_save_data as GameSaveData).to_save_data()
	return sanitize(data) if typeof(data) != TYPE_DICTIONARY else Dictionary(sanitize(data))


static func deserialize(raw_dictionary: Dictionary) -> GameSaveData:
	var save_data: GameSaveData = GAME_SAVE_DATA.new()
	save_data.load_from_save_data(Dictionary(raw_dictionary))
	return save_data


static func sanitize(value: Variant) -> Variant:
	return _sanitize(value)


static func _sanitize(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var sanitized: Dictionary = {}
			for key in Dictionary(value).keys():
				sanitized[key] = _sanitize(Dictionary(value)[key])
			return sanitized
		TYPE_ARRAY:
			var sanitized_array: Array = []
			for item in Array(value):
				sanitized_array.append(_sanitize(item))
			return sanitized_array
		TYPE_FLOAT:
			var float_value := float(value)
			if is_nan(float_value) or is_inf(float_value):
				return null
			return float_value
		TYPE_VECTOR2:
			var vector_value := Vector2(value)
			return {"x": _sanitize(vector_value.x), "y": _sanitize(vector_value.y)}
		TYPE_VECTOR2I:
			var vector2i_value := Vector2i(value)
			return {"x": vector2i_value.x, "y": vector2i_value.y}
		_:
			return value
