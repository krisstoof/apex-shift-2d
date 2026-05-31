extends Node

signal day_changed(day: int)

@export var day_length_seconds := 120.0

var day := 1
var time_of_day := 0.0
var night_amount := 0.0

func _process(delta: float) -> void:
	time_of_day += delta
	var phase := time_of_day / day_length_seconds
	night_amount = clamp(sin(phase * TAU - PI * 0.5) * 0.5 + 0.5, 0.0, 1.0)
	if time_of_day >= day_length_seconds:
		time_of_day -= day_length_seconds
		_start_new_day("night_passed")


func sleep_until_morning() -> bool:
	if not is_night():
		get_node("/root/EventBus").post_message("You can sleep when night falls")
		return false
	time_of_day = 0.0
	night_amount = 0.0
	_start_new_day("slept_in_tent")
	get_node("/root/EventBus").post_message("Slept until morning")
	return true


func get_day() -> int:
	return day


func is_night() -> bool:
	return night_amount > 0.55


func _start_new_day(reason: String) -> void:
	day += 1
	get_node("/root/EventBus").emit_game_event("day_ended", {"day": day, "reason": reason})
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
	night_amount = float(data.get("night_amount", night_amount))
	day_changed.emit(day)
