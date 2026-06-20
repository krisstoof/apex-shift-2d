extends RefCounted
class_name GameClockSystem

const GAME_CLOCK_STATE := preload("res://scripts/core/time/game_clock_state.gd")
const DAY_PROGRESSION_EVENT := preload("res://scripts/core/time/day_progression_event.gd")

var state: GameClockState = GAME_CLOCK_STATE.new()


func configure(day_length_seconds: float, start_hour: float = GameClockState.START_HOUR) -> void:
	state.day_length_seconds = maxf(day_length_seconds, 0.001)
	state.set_hour(start_hour)


func set_public_state(day: int, time_of_day: float, day_length_seconds: float, speed_multiplier: float = 1.0) -> void:
	state.day = maxi(day, 1)
	state.day_length_seconds = maxf(day_length_seconds, 0.001)
	state.time_of_day = fposmod(time_of_day, state.day_length_seconds)
	state.speed_multiplier = maxf(speed_multiplier, 0.0)
	state.refresh_derived_values()


func tick(delta_seconds: float) -> Array[DayProgressionEvent]:
	var events: Array[DayProgressionEvent] = []
	var effective_delta := maxf(delta_seconds, 0.0) * maxf(state.speed_multiplier, 0.0)
	if effective_delta <= 0.0:
		state.refresh_derived_values()
		return events
	state.time_of_day += effective_delta
	var safety := 0
	while state.time_of_day >= state.day_length_seconds and safety < 128:
		state.time_of_day -= state.day_length_seconds
		events.append(start_new_day("night_passed"))
		safety += 1
	state.refresh_derived_values()
	return events


func start_new_day(reason: String) -> DayProgressionEvent:
	var previous_day := state.day
	state.day += 1
	state.refresh_derived_values()
	return DAY_PROGRESSION_EVENT.new_with(previous_day, state.day, reason, state)


func sleep_until_morning(reason: String = "slept_in_tent") -> DayProgressionEvent:
	state.set_hour(GameClockState.MORNING_HOUR)
	return start_new_day(reason)


func advance_to_next_phase(phase_hours: Array, wrap_reason: String = "debug_next_phase") -> DayProgressionEvent:
	var current_hour := state.get_hour_float()
	for phase_value in phase_hours:
		var phase_hour := float(phase_value)
		if current_hour < phase_hour:
			state.set_hour(phase_hour)
			return null
	if phase_hours.is_empty():
		return null
	state.set_hour(float(phase_hours[0]))
	return start_new_day(wrap_reason)


func set_speed_multiplier(multiplier: float) -> void:
	state.speed_multiplier = maxf(multiplier, 0.0)
	state.refresh_derived_values()


func get_day() -> int:
	return state.day


func get_hour_float() -> float:
	return state.get_hour_float()


func get_clock_time() -> String:
	return state.get_clock_time()


func get_time_label() -> String:
	return state.get_time_label()


func get_phase_label() -> String:
	return state.get_phase_label()


func is_night() -> bool:
	return state.is_night()


func get_save_data() -> Dictionary:
	return state.to_dictionary()


func load_save_data(data: Dictionary) -> void:
	state.load_from_dictionary(data)
