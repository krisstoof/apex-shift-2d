extends RefCounted
class_name VegetationSpawnPlanItem

var kind: String = ""
var position: Vector2 = Vector2.ZERO
var biome_id: String = ""
var terrain_zone: String = ""
var visual_only: bool = false
var resource_class: String = "interactive"


func _init(
	p_kind: String = "",
	p_position: Vector2 = Vector2.ZERO,
	p_biome_id: String = "",
	p_terrain_zone: String = "",
	p_visual_only: bool = false,
	p_resource_class: String = "interactive"
) -> void:
	kind = p_kind
	position = p_position
	biome_id = p_biome_id
	terrain_zone = p_terrain_zone
	visual_only = p_visual_only
	resource_class = p_resource_class


func to_dictionary() -> Dictionary:
	return {
		"kind": kind,
		"position": position,
		"biome_id": biome_id,
		"terrain_zone": terrain_zone,
		"visual_only": visual_only,
		"resource_class": resource_class
	}
