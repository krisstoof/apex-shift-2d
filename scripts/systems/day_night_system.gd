extends Node

const RUNTIME_PROFILER := preload("res://scripts/debug/runtime_profiler.gd")
const GAME_CLOCK_SYSTEM := preload("res://scripts/core/time/game_clock_system.gd")

signal day_changed(day: int)

@export var day_length_seconds := 180.0
@export var speed_multiplier := 1.0

const START_HOUR := 8.0
const MORNING_HOUR := 6.0
const NIGHT_HOUR := 20.0
const DAWN_START_HOUR := 5.0
const DUSK_END_HOUR := 21.0
const DEBUG_PHASE_HOURS := [MORNING_HOUR, NIGHT_HOUR, DUSK_END_HOUR, DAWN_START_HOUR]

var day := 1
var time_of_day := 0.0
var night_amount := 0.0
var clock_system: GameClockSystem = GAME_CLOCK_SYSTEM.new()


func _get_event_bus() -> Node:
	if not is_inside_tree():
		return null

	var tree := get_tree()
	if tree == null or tree.root == null:
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
	clock_system.configure(day_length_seconds, START_HOUR)
	clock_system.set_speed_multiplier(speed_multiplier)
	_sync_public_state_from_clock()


func _process(delta: float) -> void:
	RuntimeProfiler.begin_scope("day_night_system_process_ms")
	_sync_public_state_to_clock()
	var events := clock_system.tick(delta)
	_sync_public_state_from_clock()
	for event in events:
		_publish_day_progression_event(event)
	RuntimeProfiler.end_scope("day_night_system_process_ms")


func sleep_until_morning() -> bool:
	_sync_public_state_to_clock()
	if not clock_system.is_night():
		_post_event_message("You can sleep when night falls")
		return false
	var event := clock_system.sleep_until_morning("slept_in_tent")
	_sync_public_state_from_clock()
	_publish_day_progression_event(event)
	_post_event_message("Slept until morning")
	return true


func debug_next_phase() -> void:
	_sync_public_state_to_clock()
	var event := clock_system.advance_to_next_phase(DEBUG_PHASE_HOURS, "debug_next_phase")
	_sync_public_state_from_clock()
	if event != null:
		_publish_day_progression_event(event)
	_post_event_message("Debug phase: %s" % get_phase_label())


func debug_next_day() -> void:
	_sync_public_state_to_clock()
	clock_system.state.set_hour(START_HOUR)
	var event := clock_system.start_new_day("debug_next_day")
	_sync_public_state_from_clock()
	_publish_day_progression_event(event)


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
	_sync_public_state_to_clock()
	var event := clock_system.start_new_day(reason)
	_sync_public_state_from_clock()
	_publish_day_progression_event(event)


func _publish_day_progression_event(event: DayProgressionEvent) -> void:
	if event == null:
		return
	var payload := event.to_dictionary()
	_emit_game_event("day_ended", payload)
	_emit_game_event("center_notification", {"text": "Day %s started" % day})
	_post_event_message("Day %s started" % day)
	day_changed.emit(day)


func _sync_public_state_to_clock() -> void:
	if clock_system == null:
		clock_system = GAME_CLOCK_SYSTEM.new()
	clock_system.set_public_state(day, time_of_day, day_length_seconds, speed_multiplier)


func _sync_public_state_from_clock() -> void:
	var state := clock_system.state
	day = state.day
	time_of_day = state.time_of_day
	day_length_seconds = state.day_length_seconds
	night_amount = state.night_amount
	speed_multiplier = state.speed_multiplier


func get_clock_state() -> Dictionary:
	_sync_public_state_to_clock()
	return clock_system.get_save_data()


func get_save_data() -> Dictionary:
	_sync_public_state_to_clock()
	_sync_public_state_from_clock()
	var clock_state := clock_system.get_save_data()
	return {
		"day": day,
		"time_of_day": time_of_day,
		"night_amount": night_amount,
		"day_length_seconds": day_length_seconds,
		"speed_multiplier": speed_multiplier,
		"clock_state": clock_state
	}


func restore_from_data(data: Dictionary) -> void:
	var clock_state := Dictionary(data.get("clock_state", {}))
	if clock_state.is_empty():
		clock_state = data.duplicate(true)
	if not clock_state.has("day_length_seconds"):
		clock_state["day_length_seconds"] = day_length_seconds
	if not clock_state.has("speed_multiplier"):
		clock_state["speed_multiplier"] = speed_multiplier
	clock_system.load_save_data(clock_state)
	_sync_public_state_from_clock()
	day_changed.emit(day)
