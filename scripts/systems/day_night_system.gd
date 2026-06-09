extends Node

signal day_changed(day: int)

@export var day_length_seconds := 180.0

const START_HOUR := 8.0
const MORNING_HOUR := 6.0
const NIGHT_HOUR := 20.0
const DAWN_START_HOUR := 5.0
const DUSK_END_HOUR := 21.0
const DEBUG_PHASE_HOURS := [MORNING_HOUR, NIGHT_HOUR, DUSK_END_HOUR, DAWN_START_HOUR]

var day := 1
var time_of_day := 0.0
var night_amount := 0.0


func _get_event_bus() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("EventBus")


func _post_event_message(message: String) -> void:
	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_method("post_message"):
		event_bus.post_message(message)


func _emit_game_event(event_name: String, payload: Dictionary = {}) -> void:
	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_method("emit_game_event"):
		event_bus.emit_game_event(event_name, payload)


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
		_post_event_message("You can sleep when night falls")
		return false
	time_of_day = _hour_to_time(MORNING_HOUR)
	night_amount = _calculate_night_amount()
	_start_new_day("slept_in_tent")
	_post_event_message("Slept until morning")
	return true


func debug_next_phase() -> void:
	var current_hour := get_hour_float()
	for phase_hour in DEBUG_PHASE_HOURS:
		if current_hour < float(phase_hour):
			time_of_day = _hour_to_time(float(phase_hour))
			night_amount = _calculate_night_amount()
			_post_event_message("Debug phase: %s" % get_phase_label())
			return
	time_of_day = _hour_to_time(float(DEBUG_PHASE_HOURS[0]))
	night_amount = _calculate_night_amount()
	_start_new_day("debug_next_phase")


func debug_next_day() -> void:
	time_of_day = _hour_to_time(START_HOUR)
	night_amount = _calculate_night_amount()
	_start_new_day("debug_next_day")


func get_day() -> int:
	return day


func get_clock_time() -> String:
	var total_minutes := int(get_hour_float() * 60.0)
	var hour := float(total_minutes) / 60.0
	var minute := total_minutes % 60
	return "%02d:%02d" % [hour, minute]


func get_time_label() -> String:
	return "Night" if is_night() else "Day"


func get_phase_label() -> String:
	var hour := get_hour_float()
	if hour >= DUSK_END_HOUR or hour < DAWN_START_HOUR:
		return "Night"
	if hour >= NIGHT_HOUR:
		return "Dusk"
	if hour < MORNING_HOUR:
		return "Dawn"
	return "Day"


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
	_emit_game_event("day_ended", {"day": day, "reason": reason})
	_emit_game_event("center_notification", {"text": "Day %s started" % day})
	_post_event_message("Day %s started" % day)
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
