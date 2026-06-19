extends RefCounted
class_name GameResult

var success: bool = true
var message: String = ""
var data: Variant = null


func _init(p_success: bool = true, p_message: String = "", p_data: Variant = null) -> void:
	success = p_success
	message = p_message
	data = p_data


static func ok(p_data: Variant = null, p_message: String = "") -> GameResult:
	return GameResult.new(true, p_message, p_data)


static func fail(p_message: String, p_data: Variant = null) -> GameResult:
	return GameResult.new(false, p_message, p_data)


func is_ok() -> bool:
	return success


func is_failed() -> bool:
	return not success


func to_dict() -> Dictionary:
	return {
		"success": success,
		"message": message,
		"data": data
	}


static func from_dict(value: Dictionary) -> GameResult:
	return GameResult.new(
		bool(value.get("success", true)),
		str(value.get("message", "")),
		value.get("data", null)
	)
