extends Node

const SAVE_PATH := "user://savegame.json"

var load_save_requested := false
var pending_world_seed := 0
var pending_landmarks: Array[Dictionary] = []


func request_new_game() -> void:
	load_save_requested = false
	pending_landmarks.clear()
	pending_world_seed = _generate_world_seed()


func request_continue() -> void:
	load_save_requested = true
	_load_bootstrap_from_save()


func consume_load_save_request() -> bool:
	var requested := load_save_requested
	load_save_requested = false
	return requested


func has_save_game() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func get_bootstrap_world_seed() -> int:
	if pending_world_seed == 0:
		pending_world_seed = _generate_world_seed()
	return pending_world_seed


func get_bootstrap_landmarks() -> Array[Dictionary]:
	return pending_landmarks.duplicate(true)


func set_bootstrap_world_state(world_seed: int, landmarks: Array) -> void:
	pending_world_seed = world_seed if world_seed != 0 else _generate_world_seed()
	pending_landmarks = _sanitize_landmarks(landmarks)


func _load_bootstrap_from_save() -> void:
	if not has_save_game():
		pending_landmarks.clear()
		pending_world_seed = _generate_world_seed()
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		pending_landmarks.clear()
		pending_world_seed = _generate_world_seed()
		return
	var bootstrap := _extract_bootstrap_world_data(Dictionary(parsed))
	pending_world_seed = int(bootstrap.get("world_seed", _generate_world_seed()))
	pending_landmarks = Array(bootstrap.get("landmarks", [])).duplicate(true)


func _extract_bootstrap_world_data(save_data: Dictionary) -> Dictionary:
	var world_data := Dictionary(save_data.get("world", {}))
	return {
		"world_seed": int(world_data.get("world_seed", _generate_world_seed())),
		"landmarks": _sanitize_landmarks(Array(world_data.get("landmarks", [])))
	}


func _sanitize_landmarks(landmarks: Array) -> Array[Dictionary]:
	var sanitized: Array[Dictionary] = []
	for landmark_value in landmarks:
		if typeof(landmark_value) != TYPE_DICTIONARY:
			continue
		sanitized.append(Dictionary(landmark_value).duplicate(true))
	return sanitized


func _generate_world_seed() -> int:
	var time_seed := int(Time.get_unix_time_from_system())
	var tick_seed := int(Time.get_ticks_usec() % 2147483647)
	return abs(time_seed * 1103515245 + tick_seed * 12345) % 2147483647 + 1
