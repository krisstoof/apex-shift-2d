extends RefCounted
class_name SaveDataCollector

const GAME_SAVE_DATA_SCRIPT := preload("res://scripts/core/save/game_save_data.gd")
const PLAYER_SAVE_DATA_SCRIPT := preload("res://scripts/core/save/player_save_data.gd")
const BUILDING_STATE_SCRIPT := preload("res://scripts/core/buildings/building_state.gd")

const BUILDING_GROUPS := {
	"campfire": "campfires",
	"trap": "traps",
	"wall": "walls",
	"storage_box": "storage_boxes",
	"tent": "tents"
}

var scene: Node
var world: Node
var player: Node
var day_night_system: Node
var evolution_director: Node
var ecosystem_director: Node


func collect() -> Dictionary:
	var save_data := GAME_SAVE_DATA_SCRIPT.new()
	save_data.version = 5
	save_data.world.load_from_save_data(world.get_save_data())
	save_data.world_generation = _build_world_generation_data()
	save_data.player.load_from_save_data(get_player_data())
	save_data.resources.load_from_save_data({"resources": world.get_resource_save_data()})
	save_data.varnaks.load_from_save_data({"varnaks": world.get_varnak_save_data()})
	save_data.small_prey.load_from_save_data({"small_prey": world.get_small_prey_save_data()})
	save_data.grazers.load_from_save_data({"grazers": world.get_grazer_save_data()})
	save_data.buildings = get_buildings_data()
	save_data.storage_boxes = get_storage_boxes_data()
	save_data.day_night = day_night_system.get_save_data()
	save_data.evolution = evolution_director.get_save_data()
	save_data.ecosystem = ecosystem_director.get_save_data()
	if day_night_system.has_method("get_clock_state"):
		save_data.clock = day_night_system.get_clock_state()
	return save_data.to_save_data()


func get_player_data() -> Dictionary:
	var player_save := PLAYER_SAVE_DATA_SCRIPT.new()
	player_save.position = player.global_position
	player_save.stats = player.stats.get_save_data()
	player_save.inventory.load_from_save_data(player.inventory.to_save_data())
	player_save.hotbar = player.hotbar_state.to_save_data() if player.get("hotbar_state") != null and player.hotbar_state.has_method("to_save_data") else {}
	player_save.has_spear = player.has_spear
	player_save.has_bow = player.has_bow
	player_save.torch_active = player.torch_active
	player_save.torch_remaining_seconds = player.torch_remaining_seconds
	return player_save.to_save_data()


func get_player_data_from_player(p_player: Node) -> Dictionary:
	player = p_player
	return get_player_data()


func get_buildings_data() -> Array[Dictionary]:
	var buildings: Array[Dictionary] = []
	var world_node := world if is_instance_valid(world) else null
	for building_kind in BUILDING_GROUPS.keys():
		var building_nodes: Array = []
		if world_node and world_node.has_method("get_registered_buildings_by_type"):
			building_nodes = world_node.get_registered_buildings_by_type(String(building_kind))
		else:
			building_nodes = scene.get_tree().get_nodes_in_group(String(BUILDING_GROUPS[building_kind]))
		for building in building_nodes:
			if not is_instance_valid(building):
				continue
			buildings.append(get_building_data(String(building_kind), building))
	return buildings


func get_storage_boxes_data() -> Array[Dictionary]:
	var storage_boxes: Array[Dictionary] = []
	for node in scene.get_tree().get_nodes_in_group("storage_boxes"):
		if not is_instance_valid(node):
			continue
		if node.has_method("get_save_data"):
			storage_boxes.append(Dictionary(node.call("get_save_data")))
	return storage_boxes


func get_building_data(building_kind: String, building: Node2D) -> Dictionary:
	var building_state := BUILDING_STATE_SCRIPT.new()
	building_state.kind = building_kind
	building_state.position = building.global_position
	if building.has_method("get_building_state"):
		building_state.load_from_save_data(Dictionary(building.call("get_building_state")))
	else:
		building_state.capture_from_building(building)
	return building_state.for_kind(building_kind)


func _build_world_generation_data() -> Dictionary:
	return {
		"version": int(world.get_world_generation_debug().get("version", 0)) if world.has_method("get_world_generation_debug") else 0,
		"seed": int(world.get_world_seed()) if world.has_method("get_world_seed") else 0,
		"layout": world.get_world_layout() if world.has_method("get_world_layout") else {},
		"save_has_world_generation_layout": world.has_method("get_world_layout") and not world.get_world_layout().is_empty(),
		"save_world_generation_version": int(world.get_world_generation_debug().get("world_generation_version", 0)) if world.has_method("get_world_generation_debug") else 0,
		"current_world_generation_version": int(world.get_world_generation_debug().get("world_generation_version", 0)) if world.has_method("get_world_generation_debug") else 0,
		"generator_rules_version": str(world.get_world_generation_debug().get("generator_rules_version", "")) if world.has_method("get_world_generation_debug") else "",
		"topography_rules_version": str(world.get_world_generation_debug().get("topography_rules_version", "")) if world.has_method("get_world_generation_debug") else ""
	}
