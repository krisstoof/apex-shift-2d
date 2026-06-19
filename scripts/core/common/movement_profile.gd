extends RefCounted
class_name MovementProfile

const DEFAULT_WALK_SPEED := 180.0
const DEFAULT_RUN_SPEED := 290.0
const DEFAULT_MIN_SPEED_MULTIPLIER := 0.0

var walk_speed: float = DEFAULT_WALK_SPEED
var run_speed: float = DEFAULT_RUN_SPEED
var min_speed_multiplier: float = DEFAULT_MIN_SPEED_MULTIPLIER

func _init(initial_walk_speed: float = DEFAULT_WALK_SPEED, initial_run_speed: float = DEFAULT_RUN_SPEED) -> void:
	walk_speed = maxf(initial_walk_speed, 0.0)
	run_speed = maxf(initial_run_speed, walk_speed)

func get_movement_speed(is_running: bool, speed_multiplier: float = 1.0, terrain_multiplier: float = 1.0) -> float:
	var base_speed := run_speed if is_running else walk_speed
	return base_speed * maxf(speed_multiplier, min_speed_multiplier) * maxf(terrain_multiplier, 0.0)
