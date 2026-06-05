extends RefCounted
class_name LandmarkService

var landmarks: Array[Dictionary] = []
var hill_landmarks: Array[Dictionary] = []
var pond_landmarks: Array[Dictionary] = []
var pond_water_search_radius := 0.0


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


func get_landmarks() -> Array[Dictionary]:
	return landmarks.duplicate(true)


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
