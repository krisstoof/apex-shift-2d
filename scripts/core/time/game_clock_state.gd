extends RefCounted
class_name GameClockState

const DEFAULT_DAY_LENGTH_SECONDS := 180.0
const START_HOUR := 8.0
const MORNING_HOUR := 6.0
const NIGHT_HOUR := 20.0
const DAWN_START_HOUR := 5.0
const DUSK_END_HOUR := 21.0

var day := 1
var time_of_day := 0.0
var day_length_seconds := DEFAULT_DAY_LENGTH_SECONDS
var night_amount := 0.0
var speed_multiplier := 1.0


func _init() -> void:
	set_hour(START_HOUR)


func duplicate_state() -> GameClockState:
	var copy := GameClockState.new()
	copy.load_from_dictionary(to_dictionary())
	return copy


func to_dictionary() -> Dictionary:
	return {
		"day": day,
		"time_of_day": time_of_day,
		"day_length_seconds": day_length_seconds,
		"night_amount": night_amount,
		"speed_multiplier": speed_multiplier,
		"hour": get_hour_float(),
		"phase_label": get_phase_label(),
		"is_night": is_night()
	}


func load_from_dictionary(data: Dictionary) -> void:
	day = maxi(int(data.get("day", day)), 1)
	day_length_seconds = maxf(float(data.get("day_length_seconds", day_length_seconds)), 0.001)
	time_of_day = fposmod(float(data.get("time_of_day", time_of_day)), day_length_seconds)
	speed_multiplier = maxf(float(data.get("speed_multiplier", speed_multiplier)), 0.0)
	refresh_derived_values()


func refresh_derived_values() -> void:
	day = maxi(day, 1)
	day_length_seconds = maxf(day_length_seconds, 0.001)
	time_of_day = fposmod(time_of_day, day_length_seconds)
	speed_multiplier = maxf(speed_multiplier, 0.0)
	night_amount = calculate_night_amount()


func set_hour(hour: float) -> void:
	time_of_day = hour_to_time(hour)
	refresh_derived_values()


func hour_to_time(hour: float) -> float:
	return fposmod(hour, 24.0) / 24.0 * maxf(day_length_seconds, 0.001)


func get_hour_float() -> float:
	var phase := fposmod(time_of_day / maxf(day_length_seconds, 0.001), 1.0)
	return phase * 24.0


func get_clock_time() -> String:
	var total_minutes := int(floor(get_hour_float() * 60.0)) % (24 * 60)
	var hour := int(total_minutes / 60)
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


func calculate_night_amount() -> float:
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
