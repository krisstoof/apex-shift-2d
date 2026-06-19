extends RefCounted
class_name GameRect

var x: float = 0.0
var y: float = 0.0
var width: float = 0.0
var height: float = 0.0


func _init(p_x: float = 0.0, p_y: float = 0.0, p_width: float = 0.0, p_height: float = 0.0) -> void:
	x = p_x
	y = p_y
	width = p_width
	height = p_height


func to_rect2() -> Rect2:
	return Rect2(Vector2(x, y), Vector2(width, height))


static func from_rect2(value: Rect2) -> GameRect:
	return GameRect.new(value.position.x, value.position.y, value.size.x, value.size.y)


func get_position() -> GamePosition:
	return GamePosition.new(x, y)


func get_size() -> GamePosition:
	return GamePosition.new(width, height)


func get_end_position() -> GamePosition:
	return GamePosition.new(x + width, y + height)


func has_positive_size() -> bool:
	return width > 0.0 and height > 0.0


func contains_position(position: GamePosition) -> bool:
	if position == null:
		return false
	if not has_positive_size():
		return false
	return position.x >= x \
		and position.y >= y \
		and position.x < x + width \
		and position.y < y + height


func intersects(other: GameRect) -> bool:
	if other == null:
		return false
	if not has_positive_size() or not other.has_positive_size():
		return false
	return x < other.x + other.width \
		and x + width > other.x \
		and y < other.y + other.height \
		and y + height > other.y


func equals(other: GameRect, epsilon: float = 0.001) -> bool:
	if other == null:
		return false
	return abs(x - other.x) <= epsilon \
		and abs(y - other.y) <= epsilon \
		and abs(width - other.width) <= epsilon \
		and abs(height - other.height) <= epsilon


func to_dict() -> Dictionary:
	return {
		"x": x,
		"y": y,
		"width": width,
		"height": height
	}


static func from_dict(data: Dictionary) -> GameRect:
	return GameRect.new(
		float(data.get("x", 0.0)),
		float(data.get("y", 0.0)),
		float(data.get("width", 0.0)),
		float(data.get("height", 0.0))
	)
