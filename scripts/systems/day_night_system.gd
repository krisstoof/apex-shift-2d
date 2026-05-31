extends Node

signal day_changed(day: int)

@export var day_length_seconds := 120.0

const START_HOUR := 8.0
const MORNING_HOUR := 6.0
const NIGHT_HOUR := 20.0
const DAWN_START_HOUR := 5.0
const DUSK_END_HOUR := 21.0

var day := 1
var time_of_day := 0.0
var night_amount := 0.0


func _ready() -> void:
	time_of_day = _hour_to_time(START_HOUR)
	night_amount = _calculate_night_amount()


func _process(delta: float) -> void:
	time_of_day += delta
	if time_of_day >= day_length_seconds:
		time_of_day -= day_length_seconds
		_start_new_day("night_passed")
	night_amount = _calculate_night_amount()


func sleep_until_morning() -> bool:
	if not is_night():
		get_node("/root/EventBus").post_message("You can sleep when night falls")
		return false
	time_of_day = _hour_to_time(MORNING_HOUR)
	night_amount = _calculate_night_amount()
	_start_new_day("slept_in_tent")
	get_node("/root/EventBus").post_message("Slept until morning")
	return true


func get_day() -> int:
	return day


func get_clock_time() -> String:
	var total_minutes := int(get_hour_float() * 60.0)
	var hour := total_minutes / 60
	var minute := total_minutes % 60
	return "%02d:%02d" % [hour, minute]


func get_time_label() -> String:
	return "Night" if is_night() else "Day"


func is_night() -> bool:
	var hour := get_hour_float()
	return hour >= NIGHT_HOUR or hour < MORNING_HOUR


func get_hour_float() -> float:
	var phase := fposmod(time_of_day / day_length_seconds, 1.0)
	return phase * 24.0


func _hour_to_time(hour: float) -> float:
	return fposmod(hour, 24.0) / 24.0 * day_length_seconds


func _calculate_night_amount() -> float:
	var hour := get_hour_float()
	if hour >= NIGHT_HOUR:
		if hour >= DUSK_END_HOUR:
			return 1.0
		return clamp((hour - NIGHT_HOUR) / (DUSK_END_HOUR - NIGHT_HOUR), 0.0, 1.0)
	if hour < MORNING_HOUR:
		if hour < DAWN_START_HOUR:
			return 1.0
		return clamp((MORNING_HOUR - hour) / (MORNING_HOUR - DAWN_START_HOUR), 0.0, 1.0)
	return 0.0


func _start_new_day(reason: String) -> void:
	day += 1
	get_node("/root/EventBus").emit_game_event("day_ended", {"day": day, "reason": reason})
	get_node("/root/EventBus").emit_game_event("center_notification", {"text": "Day %s started" % day})
	get_node("/root/EventBus").post_message("Day %s started" % day)
	day_changed.emit(day)


func get_save_data() -> Dictionary:
	return {
		"day": day,
		"time_of_day": time_of_day,
		"night_amount": night_amount
	}


func restore_from_data(data: Dictionary) -> void:
	day = int(data.get("day", day))
	time_of_day = float(data.get("time_of_day", time_of_day))
	night_amount = _calculate_night_amount()
	day_changed.emit(day)
