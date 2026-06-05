extends RefCounted
class_name LandmarkService

var landmarks: Array[Dictionary] = []
var hill_landmarks: Array[Dictionary] = []
var pond_landmarks: Array[Dictionary] = []
var pond_water_search_radius := 0.0


func resolve_initial_layout(
	current_world_seed: int,
	bootstrap_landmarks: Array,
	bootstrap_world_seed: int,
	generate_landmarks: Callable
) -> Dictionary:
	var resolved_world_seed := bootstrap_world_seed if bootstrap_world_seed != 0 else current_world_seed
	if resolved_world_seed == 0:
		resolved_world_seed = 1
	var resolved_landmarks: Array = []
	if bootstrap_landmarks.is_empty():
		resolved_landmarks = generate_landmarks.call(resolved_world_seed)
	else:
		resolved_landmarks = deserialize_landmark_save_data(bootstrap_landmarks)
	return {
		"world_seed": resolved_world_seed,
		"landmarks": resolved_landmarks
	}


func resolve_restored_layout(
	current_world_seed: int,
	landmark_data: Array,
	restored_world_seed: int,
	generate_landmarks: Callable
) -> Dictionary:
	var resolved_world_seed := restored_world_seed if restored_world_seed != 0 else current_world_seed
	var resolved_landmarks: Array = deserialize_landmark_save_data(landmark_data)
	if resolved_landmarks.is_empty():
		resolved_landmarks = generate_landmarks.call(resolved_world_seed)
	return {
		"world_seed": resolved_world_seed,
		"landmarks": resolved_landmarks
	}


func set_landmarks(landmark_layout: Array, max_pond_search_radius_factor := 1.2) -> void:
	landmarks.clear()
	hill_landmarks.clear()
	pond_landmarks.clear()
	pond_water_search_radius = 0.0
	var max_pond_radius := 0.0
	for landmark_value in landmark_layout:
		var landmark := Dictionary(landmark_value).duplicate(true)
		landmarks.append(landmark)
		match str(landmark.get("type", "")):
			"hill":
				hill_landmarks.append(landmark)
			"pond":
				pond_landmarks.append(landmark)
				max_pond_radius = max(max_pond_radius, float(landmark.get("radius", 0.0)))
	if not pond_landmarks.is_empty():
		pond_water_search_radius = max(max_pond_radius * max_pond_search_radius_factor, 1.0)


func sync_runtime_landmarks(landmark_layout: Array, create_landmark_area: Callable, max_pond_search_radius_factor := 1.2) -> void:
	set_landmarks(landmark_layout, max_pond_search_radius_factor)
	if not create_landmark_area.is_valid():
		return
	for landmark in hill_landmarks:
		create_landmark_area.call(landmark, "hill_landmarks")
	for landmark in pond_landmarks:
		create_landmark_area.call(landmark, "pond_landmarks")


func get_landmarks() -> Array[Dictionary]:
	return landmarks.duplicate(true)


func deserialize_landmark_save_data(landmark_data: Array) -> Array[Dictionary]:
	var restored_landmarks: Array[Dictionary] = []
	for landmark_value in landmark_data:
		if typeof(landmark_value) != TYPE_DICTIONARY:
			continue
		var landmark := Dictionary(landmark_value).duplicate(true)
		landmark["position"] = _data_to_vector(landmark.get("position", {}))
		landmark["radius"] = float(landmark.get("radius", 0.0))
		restored_landmarks.append(landmark)
	return restored_landmarks


func get_landmark_save_data() -> Array[Dictionary]:
	var landmark_data: Array[Dictionary] = []
	for landmark_value in landmarks:
		var landmark := Dictionary(landmark_value).duplicate(true)
		landmark["position"] = _vector_to_data(Vector2(landmark.get("position", Vector2.ZERO)))
		landmark["radius"] = float(landmark.get("radius", 0.0))
		landmark_data.append(landmark)
	return landmark_data


func get_hill_landmarks() -> Array[Dictionary]:
	return hill_landmarks.duplicate(true)


func get_pond_landmarks() -> Array[Dictionary]:
	return pond_landmarks.duplicate(true)


func get_landmark_counts() -> Dictionary:
	return {
		"generated": landmarks.size(),
		"hill": hill_landmarks.size(),
		"pond": pond_landmarks.size()
	}


func get_nearest_landmark_data(position: Vector2) -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_distance := INF
	for landmark_value in landmarks:
		var landmark := Dictionary(landmark_value)
		var landmark_position := Vector2(landmark.get("position", Vector2.ZERO))
		var distance := position.distance_to(landmark_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = landmark.duplicate(true)
	if nearest.is_empty():
		return {}
	nearest["distance_to_position"] = nearest_distance
	return nearest


func get_pond_water_search_radius() -> float:
	return pond_water_search_radius


func _vector_to_data(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


func _data_to_vector(data: Variant) -> Vector2:
	if typeof(data) != TYPE_DICTIONARY:
		return Vector2.ZERO
	return Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
