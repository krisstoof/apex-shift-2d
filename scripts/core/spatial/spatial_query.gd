class_name SpatialQuery
extends RefCounted

var position: Vector2 = Vector2.ZERO
var radius: float = 0.0
var rect: Rect2 = Rect2()
var category_filter: Variant = null
var type_filter: Variant = null


static func circle(p_position: Vector2, p_radius: float, p_category_filter: Variant = null, p_type_filter: Variant = null) -> SpatialQuery:
	var query := SpatialQuery.new()
	query.position = p_position
	query.radius = p_radius
	query.category_filter = p_category_filter
	query.type_filter = p_type_filter
	return query


static func rectangle(p_rect: Rect2, p_category_filter: Variant = null, p_type_filter: Variant = null) -> SpatialQuery:
	var query := SpatialQuery.new()
	query.rect = p_rect
	query.category_filter = p_category_filter
	query.type_filter = p_type_filter
	return query
