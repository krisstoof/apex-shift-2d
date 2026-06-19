class_name SpatialQueryResult
extends RefCounted

var entity_id: Variant = null
var position: Vector2 = Vector2.ZERO
var category: String = ""
var metadata: Dictionary = {}
var distance_squared: float = 0.0


static func from_record(record: Dictionary, query_position: Vector2 = Vector2.ZERO) -> SpatialQueryResult:
	var result := SpatialQueryResult.new()
	result.entity_id = record.get("entity_id", null)
	result.position = Vector2(record.get("position", Vector2.ZERO))
	result.category = str(record.get("category", ""))
	result.metadata = Dictionary(record.get("metadata", {})).duplicate(true)
	result.distance_squared = result.position.distance_squared_to(query_position)
	return result


func get_payload(default_value: Variant = null) -> Variant:
	return metadata.get("payload", default_value)


func get_type() -> String:
	return str(metadata.get("type", metadata.get("kind", "")))


func to_dict() -> Dictionary:
	return {
		"entity_id": entity_id,
		"position": position,
		"category": category,
		"metadata": metadata.duplicate(true),
		"distance_squared": distance_squared
	}
