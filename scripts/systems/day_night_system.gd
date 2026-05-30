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
		day += 1
		get_node("/root/EventBus").emit_game_event("day_ended", {"day": day})
		get_node("/root/EventBus").post_message("Day %s started" % day)
		day_changed.emit(day)


func get_day() -> int:
	return day


func is_night() -> bool:
	return night_amount > 0.55
