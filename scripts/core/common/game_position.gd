extends RefCounted
class_name GamePosition

var x: float = 0.0
var y: float = 0.0


func _init(p_x: float = 0.0, p_y: float = 0.0) -> void:
	x = p_x
	y = p_y


static func zero() -> GamePosition:
	return GamePosition.new(0.0, 0.0)


func copy() -> GamePosition:
	return GamePosition.new(x, y)


func to_vector2() -> Vector2:
	return Vector2(x, y)


static func from_vector2(value: Vector2) -> GamePosition:
	return GamePosition.new(value.x, value.y)


func distance_to(other: GamePosition) -> float:
	if other == null:
		return INF
	return sqrt(distance_squared_to(other))


func distance_squared_to(other: GamePosition) -> float:
	if other == null:
		return INF
	var dx := x - other.x
	var dy := y - other.y
	return dx * dx + dy * dy


func equals(other: GamePosition, epsilon: float = 0.001) -> bool:
	if other == null:
		return false
	return abs(x - other.x) <= epsilon and abs(y - other.y) <= epsilon


func to_dict() -> Dictionary:
	return {
		"x": x,
		"y": y
	}


static func from_dict(data: Dictionary) -> GamePosition:
	return GamePosition.new(
		float(data.get("x", 0.0)),
		float(data.get("y", 0.0))
	)
