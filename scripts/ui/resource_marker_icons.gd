extends RefCounted
class_name ResourceMarkerIcons

static func get_marker_color(item_name: String) -> Color:
	match item_name:
		"wood":
			return Color(0.22, 0.64, 0.26, 0.78)
		"stone":
			return Color(0.56, 0.57, 0.61, 0.72)
		"fiber":
			return Color(0.50, 0.80, 0.28, 0.78)
		"grass":
			return Color(0.42, 0.68, 0.26, 0.72)
		"berries":
			return Color(0.80, 0.22, 0.25, 0.75)
		"meat":
			return Color(0.76, 0.68, 0.52, 0.72)
		_:
			return Color(0.72, 0.66, 0.42, 0.70)


static func get_render_spec(item_name: String) -> Dictionary:
	var fill_color := get_marker_color(item_name)
	var outline_color := Color(0.10, 0.12, 0.10, 0.52)
	var inner_color := Color(0.96, 0.94, 0.88, 0.62)
	var radius := 2.15
	var inner_radius := 0.8
	var cross_size := 0.0
	var cross_width := 1.0
	match item_name:
		"wood":
			inner_radius = 0.9
			inner_color = Color(0.96, 0.98, 0.95, 0.70)
		"stone":
			radius = 2.0
			inner_radius = 0.0
			cross_size = 1.15
			inner_color = Color(0.92, 0.93, 0.94, 0.62)
			outline_color = Color(0.16, 0.17, 0.18, 0.50)
		"berries", "meat":
			radius = 2.0
			inner_radius = 0.82
			inner_color = Color(1.0, 0.95, 0.84, 0.66)
		_:
			inner_radius = 0.0
			cross_size = 1.0
			inner_color = Color(0.96, 0.94, 0.80, 0.58)
	return {
		"radius": radius,
		"outline_color": outline_color,
		"fill_color": fill_color,
		"inner_color": inner_color,
		"inner_radius": inner_radius,
		"cross_size": cross_size,
		"cross_width": cross_width
	}
