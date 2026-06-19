extends RefCounted
class_name GameTime

var day: int = 1
var seconds_of_day: float = 0.0
var total_seconds: float = 0.0


func _init(p_day: int = 1, p_seconds_of_day: float = 0.0, p_total_seconds: float = 0.0) -> void:
	day = maxi(p_day, 1)
	seconds_of_day = maxf(p_seconds_of_day, 0.0)
	total_seconds = maxf(p_total_seconds, 0.0)


func copy() -> GameTime:
	return GameTime.new(day, seconds_of_day, total_seconds)


func advance(seconds: float, day_length_seconds: float) -> void:
	if seconds <= 0.0:
		return

	total_seconds += seconds

	if day_length_seconds <= 0.0:
		seconds_of_day += seconds
		return

	seconds_of_day += seconds

	while seconds_of_day >= day_length_seconds:
		seconds_of_day -= day_length_seconds
		day += 1


func to_dict() -> Dictionary:
	return {
		"day": day,
		"seconds_of_day": seconds_of_day,
		"total_seconds": total_seconds
	}


static func from_dict(data: Dictionary) -> GameTime:
	return GameTime.new(
		int(data.get("day", 1)),
		float(data.get("seconds_of_day", 0.0)),
		float(data.get("total_seconds", 0.0))
	)
