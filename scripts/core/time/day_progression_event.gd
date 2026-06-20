extends RefCounted
class_name DayProgressionEvent

var previous_day := 1
var day := 1
var reason := ""
var hour := 0.0
var clock_state: Dictionary = {}


static func new_with(p_previous_day: int, p_day: int, p_reason: String, state: GameClockState) -> DayProgressionEvent:
	var event := DayProgressionEvent.new()
	event.previous_day = maxi(p_previous_day, 1)
	event.day = maxi(p_day, 1)
	event.reason = p_reason
	if state != null:
		event.hour = state.get_hour_float()
		event.clock_state = state.to_dictionary()
	return event


func to_dictionary() -> Dictionary:
	return {
		"previous_day": previous_day,
		"day": day,
		"reason": reason,
		"hour": hour,
		"time_of_day": float(clock_state.get("time_of_day", 0.0)),
		"night_amount": float(clock_state.get("night_amount", 0.0)),
		"clock_state": clock_state.duplicate(true)
	}
