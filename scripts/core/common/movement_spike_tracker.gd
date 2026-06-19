extends RefCounted
class_name MovementSpikeTracker

var spike_count := 0
var max_spike_distance := 0.0

func record_movement_spike(previous_position: Vector2, current_position: Vector2, warning_distance: float) -> bool:
	var moved_distance := current_position.distance_to(previous_position)
	if moved_distance <= warning_distance:
		return false
	spike_count += 1
	max_spike_distance = maxf(max_spike_distance, moved_distance)
	return true
