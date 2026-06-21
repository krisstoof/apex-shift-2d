extends RefCounted
class_name VegetationSpawnCandidate

var position: Vector2 = Vector2.ZERO
var biome_id: String = ""
var terrain_zone: String = ""
var terrain_class: String = ""
var source_id: String = ""


func _init(
	p_position: Vector2 = Vector2.ZERO,
	p_biome_id: String = "",
	p_terrain_zone: String = "",
	p_terrain_class: String = "",
	p_source_id: String = ""
) -> void:
	position = p_position
	biome_id = p_biome_id
	terrain_zone = p_terrain_zone
	terrain_class = p_terrain_class
	source_id = p_source_id


func to_dictionary() -> Dictionary:
	return {
		"position": position,
		"biome_id": biome_id,
		"terrain_zone": terrain_zone,
		"terrain_class": terrain_class,
		"source_id": source_id
	}
