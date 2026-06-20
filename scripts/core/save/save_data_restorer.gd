extends RefCounted
class_name SaveDataRestorer

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

var scene: Node
var world: Node
var player: Node
var day_night_system: Node
var evolution_director: Node
var ecosystem_director: Node
var game_session: Node


func restore(save_data: GameSaveData) -> void:
	var world_data: Dictionary = save_data.world.to_save_data()
	if world and world.has_method("begin_save_restore"):
		world.begin_save_restore()
	if not world_data.is_empty():
		await world.restore_landmarks(Array(world_data.get("landmarks", [])), int(world_data.get("world_seed", 0)))
		if game_session and game_session.has_method("set_bootstrap_world_state"):
			game_session.set_bootstrap_world_state(int(world_data.get("world_seed", 0)), Array(world_data.get("landmarks", [])))
	var world_generation_data: Dictionary = Dictionary(save_data.world_generation)
	var save_has_world_generation_layout: bool = world_generation_data.has("layout") and not Dictionary(world_generation_data.get("layout", {})).is_empty()
	var restore_mode := "legacy"
	if save_has_world_generation_layout:
		restore_mode = "full_layout"
	elif world_generation_data.has("version") or world_generation_data.has("seed"):
		restore_mode = "seed_fallback"
	if world.has_method("set_procedural_world_restore_mode"):
		world.call("set_procedural_world_restore_mode", restore_mode)
	if save_has_world_generation_layout and world.has_method("generate_new_world"):
		var layout: Dictionary = Dictionary(world_generation_data.get("layout", {}))
		if not layout.is_empty() and world.has_method("_apply_world_layout"):
			world.call("_apply_world_layout", layout)
	elif world.has_method("set_procedural_world_restore_mode") and restore_mode == "legacy":
		world.call("set_procedural_world_restore_mode", "legacy")
	restore_player_data(save_data.player.to_save_data())
	evolution_director.restore_from_data(Dictionary(save_data.evolution))
	ecosystem_director.load_save_data(Dictionary(save_data.ecosystem))
	day_night_system.restore_from_data(Dictionary(save_data.day_night))
	await world.restore_resources(save_data.resources.to_save_data())
	var has_storage_boxes := not save_data.storage_boxes.is_empty()
	await restore_buildings(save_data.buildings, has_storage_boxes)
	await restore_storage_boxes(save_data.to_save_data())
	await world.restore_varnaks(save_data.varnaks.to_save_data())
	if save_data.small_prey.to_save_data().size() > 0:
		await world.restore_small_prey(save_data.small_prey.to_save_data())
	if save_data.grazers.to_save_data().size() > 0:
		await world.restore_grazers(save_data.grazers.to_save_data())
	if world and world.has_method("end_save_restore"):
		world.end_save_restore()
	if world and world.has_method("rebuild_runtime_indexes_after_load"):
		world.rebuild_runtime_indexes_after_load()


func restore_player_data(data: Dictionary) -> void:
	player.global_position = _data_to_vector(data.get("position", {}))
	player.stats.restore_from_data(Dictionary(data.get("stats", {})))
	if data.has("inventory"):
		player.inventory.load_from_save_data(Dictionary(data.get("inventory", {})))
	else:
		player.inventory.clear()
		player.inventory.add_item("wood", int(data.get("wood", 0)))
		player.inventory.add_item("stone", int(data.get("stone", 0)))
		player.inventory.add_item("fiber", int(data.get("fiber", 0)))
		player.inventory.add_item("meat", int(data.get("meat", 0)))
		player.inventory.add_item("bone", int(data.get("bone", 0)))
	if data.has("hotbar") and player.get("hotbar_state") != null and player.hotbar_state.has_method("load_from_save_data"):
		player.hotbar_state.load_from_save_data(Dictionary(data.get("hotbar", {})))
	player.has_spear = data.get("has_spear", player.has_spear) == true
	player.has_bow = data.get("has_bow", player.has_bow) == true
	player.torch_active = data.get("torch_active", player.torch_active) == true
	player.torch_remaining_seconds = float(data.get("torch_remaining_seconds", player.torch_remaining_seconds))
	if player.torch_active and player.torch_remaining_seconds <= 0.0:
		player.clear_inactive_torch_state()


func restore_buildings(buildings: Array, skip_storage_boxes: bool = false) -> void:
	if world and world.has_method("get_registered_buildings"):
		for building in world.get_registered_buildings():
			if is_instance_valid(building):
				building.queue_free()
	else:
		for group_name in BUILDING_GROUPS.values():
			for building in scene.get_tree().get_nodes_in_group(String(group_name)):
				if is_instance_valid(building):
					building.queue_free()
	await scene.get_tree().process_frame
	for building_data in buildings:
		if typeof(building_data) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = Dictionary(building_data)
		var building_kind: String = str(data.get("kind", ""))
		if skip_storage_boxes and building_kind == "storage_box":
			continue
		if not BUILDING_SCENES.has(building_kind):
			continue
		var building: Node2D = BUILDING_SCENES[building_kind].instantiate()
		scene.add_child(building)
		building.global_position = _data_to_vector(data.get("position", {}))
		if world and world.has_method("register_building_node"):
			world.register_building_node(building, building_kind)
		_restore_building_state(building, data)


func restore_storage_boxes(save_data: Dictionary) -> void:
	var storage_boxes_data: Array = []
	if save_data.has("storage_boxes"):
		storage_boxes_data = Array(save_data.get("storage_boxes", []))
	elif save_data.has("buildings"):
		for building_data in Array(save_data.get("buildings", [])):
			if typeof(building_data) != TYPE_DICTIONARY:
				continue
			var building_dict: Dictionary = Dictionary(building_data)
			if str(building_dict.get("kind", "")) == "storage_box":
				storage_boxes_data.append(building_dict)
	if storage_boxes_data.is_empty():
		return
	clear_existing_storage_boxes()
	await scene.get_tree().process_frame
	for box_data_variant in storage_boxes_data:
		if typeof(box_data_variant) != TYPE_DICTIONARY:
			continue
		var box_data: Dictionary = Dictionary(box_data_variant)
		var box: Node2D = BUILDING_SCENES["storage_box"].instantiate()
		scene.add_child(box)
		if box.has_method("restore_from_data"):
			box.restore_from_data(box_data)
		else:
			box.global_position = _data_to_vector(box_data.get("position", {}))
		if world and world.has_method("register_building_node"):
			world.register_building_node(box, "storage_box")


func clear_existing_storage_boxes() -> void:
	for node in scene.get_tree().get_nodes_in_group("storage_boxes"):
		if is_instance_valid(node):
			node.queue_free()
	await scene.get_tree().process_frame


func _restore_building_state(building: Node, data: Dictionary) -> void:
	if building.has_method("apply_building_state"):
		building.call("apply_building_state", data)
		building.queue_redraw()
		return
	if building.has_method("restore_from_data"):
		building.call("restore_from_data", data)
		return
	building.queue_redraw()


func _data_to_vector(data: Variant) -> Vector2:
	if typeof(data) != TYPE_DICTIONARY:
		return Vector2.ZERO
	return Vector2(float(Dictionary(data).get("x", 0.0)), float(Dictionary(data).get("y", 0.0)))
