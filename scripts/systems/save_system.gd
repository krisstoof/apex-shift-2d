extends Node

const SAVE_PATH := "user://savegame.json"
const BUILDING_SCENES := {
	"campfire": preload("res://scenes/buildings/campfire.tscn"),
	"trap": preload("res://scenes/buildings/trap.tscn"),
	"wall": preload("res://scenes/buildings/wall.tscn"),
	"storage_box": preload("res://scenes/buildings/storage_box.tscn"),
	"tent": preload("res://scenes/buildings/tent.tscn")
}
const BUILDING_GROUPS := {
	"campfire": "campfires",
	"trap": "traps",
	"wall": "walls",
	"storage_box": "storage_boxes",
	"tent": "tents"
}


func save_game() -> void:
	var data := _collect_save_data()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		get_node("/root/EventBus").post_message("Could not save game")
		return
	file.store_string(JSON.stringify(data, "\t"))
	get_node("/root/EventBus").post_message("Game saved")


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		get_node("/root/EventBus").post_message("No save file found")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		get_node("/root/EventBus").post_message("Save file is invalid")
		return
	await _restore_save_data(Dictionary(parsed))
	get_node("/root/EventBus").post_message("Game loaded")


func _collect_save_data() -> Dictionary:
	var scene := get_tree().current_scene
	var player := scene.get_node("Player")
	var world := scene.get_node("World")
	var day_night_system := scene.get_node("DayNightSystem")
	var evolution_director := scene.get_node("EvolutionDirector")
	var ecosystem_director := scene.get_node("EcosystemDirector")
	return {
		"version": 2,
		"player": _get_player_data(player),
		"resources": world.get_resource_save_data(),
		"varnaks": world.get_varnak_save_data(),
		"buildings": _get_buildings_data(),
		"day_night": day_night_system.get_save_data(),
		"evolution": evolution_director.get_save_data(),
		"ecosystem": ecosystem_director.get_save_data()
	}


func _get_player_data(player: Node) -> Dictionary:
	return {
		"position": _vector_to_data(player.global_position),
		"stats": player.stats.get_save_data(),
		"inventory": player.inventory.get_save_data(),
		"has_spear": player.has_spear,
		"has_bow": player.has_bow,
		"torch_active": player.torch_active,
		"torch_remaining_seconds": player.torch_remaining_seconds
	}


func _get_buildings_data() -> Array[Dictionary]:
	var buildings: Array[Dictionary] = []
	for building_kind in BUILDING_GROUPS.keys():
		var group_name := String(BUILDING_GROUPS[building_kind])
		for building in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(building):
				continue
			buildings.append(_get_building_data(String(building_kind), building))
	return buildings


func _get_building_data(building_kind: String, building: Node2D) -> Dictionary:
	var data := {
		"kind": building_kind,
		"position": _vector_to_data(building.global_position)
	}
	match building_kind:
		"campfire":
			data["active"] = building.active
			data["fear_radius"] = building.fear_radius
		"trap":
			data["armed"] = building.armed
			data["damage"] = building.damage
		"wall":
			data["health"] = building.health
	return data


func _restore_save_data(data: Dictionary) -> void:
	var scene := get_tree().current_scene
	var player := scene.get_node("Player")
	var world := scene.get_node("World")
	var day_night_system := scene.get_node("DayNightSystem")
	var evolution_director := scene.get_node("EvolutionDirector")
	var ecosystem_director := scene.get_node("EcosystemDirector")

	_restore_player_data(player, Dictionary(data.get("player", {})))
	evolution_director.restore_from_data(Dictionary(data.get("evolution", {})))
	ecosystem_director.load_save_data(Dictionary(data.get("ecosystem", {})))
	day_night_system.restore_from_data(Dictionary(data.get("day_night", {})))
	await world.restore_resources(Array(data.get("resources", [])))
	await _restore_buildings(Array(data.get("buildings", [])))
	await world.restore_varnaks(Array(data.get("varnaks", [])))


func _restore_player_data(player: Node, data: Dictionary) -> void:
	player.global_position = _data_to_vector(data.get("position", {}))
	player.stats.restore_from_data(Dictionary(data.get("stats", {})))
	player.inventory.restore_from_data(Dictionary(data.get("inventory", {})))
	player.has_spear = data.get("has_spear", player.has_spear) == true
	player.has_bow = data.get("has_bow", player.has_bow) == true
	player.torch_active = data.get("torch_active", player.torch_active) == true
	player.torch_remaining_seconds = float(data.get("torch_remaining_seconds", player.torch_remaining_seconds))
	if player.torch_active and player.torch_remaining_seconds <= 0.0:
		player.clear_inactive_torch_state()


func _restore_buildings(buildings: Array) -> void:
	for group_name in BUILDING_GROUPS.values():
		for building in get_tree().get_nodes_in_group(String(group_name)):
			if is_instance_valid(building):
				building.queue_free()
	await get_tree().process_frame

	var scene := get_tree().current_scene
	for building_data in buildings:
		if typeof(building_data) != TYPE_DICTIONARY:
			continue
		var data := Dictionary(building_data)
		var building_kind := str(data.get("kind", ""))
		if not BUILDING_SCENES.has(building_kind):
			continue
		var building: Node2D = BUILDING_SCENES[building_kind].instantiate()
		scene.add_child(building)
		building.global_position = _data_to_vector(data.get("position", {}))
		_restore_building_state(building_kind, building, data)


func _restore_building_state(building_kind: String, building: Node, data: Dictionary) -> void:
	match building_kind:
		"campfire":
			building.active = bool(data.get("active", building.active))
			building.fear_radius = float(data.get("fear_radius", building.fear_radius))
		"trap":
			building.armed = bool(data.get("armed", building.armed))
			building.damage = float(data.get("damage", building.damage))
		"wall":
			building.health = float(data.get("health", building.health))
	building.queue_redraw()


func _vector_to_data(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


func _data_to_vector(data: Variant) -> Vector2:
	if typeof(data) != TYPE_DICTIONARY:
		return Vector2.ZERO
	return Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
