extends RefCounted
class_name BuildingPlacementService

const CAMPFIRE_SCENE := preload("res://scenes/buildings/campfire.tscn")
const TRAP_SCENE := preload("res://scenes/buildings/trap.tscn")
const WALL_SCENE := preload("res://scenes/buildings/wall.tscn")
const STORAGE_BOX_SCENE := preload("res://scenes/buildings/storage_box.tscn")
const TENT_SCENE := preload("res://scenes/buildings/tent.tscn")

const BUILDING_SCENES := {
	"campfire": CAMPFIRE_SCENE,
	"trap": TRAP_SCENE,
	"wall": WALL_SCENE,
	"storage_box": STORAGE_BOX_SCENE,
	"tent": TENT_SCENE
}


func can_place(building_id: String) -> bool:
	return BUILDING_SCENES.has(building_id)


func place_building(building_id: String, position: Vector2, parent: Node, world: Node = null) -> Node:
	if parent == null or not can_place(building_id):
		return null
	var scene: PackedScene = BUILDING_SCENES[building_id]
	var building := scene.instantiate()
	if building == null:
		return null
	if building is Node2D:
		(building as Node2D).global_position = position
	parent.add_child(building)
	if world != null and world.has_method("register_building_node"):
		world.register_building_node(building, building_id)
	return building
