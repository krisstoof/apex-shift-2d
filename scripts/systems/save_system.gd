extends Node

const SAVE_PATH := "user://savegame.json"
const SAVE_SERIALIZER_SCRIPT := preload("res://scripts/core/save/save_serializer.gd")
const SAVE_DATA_COLLECTOR_SCRIPT := preload("res://scripts/core/save/save_data_collector.gd")
const SAVE_DATA_RESTORER_SCRIPT := preload("res://scripts/core/save/save_data_restorer.gd")
var _collector: SaveDataCollector
var _restorer: SaveDataRestorer


func _post_event_message(message: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var event_bus := tree.root.get_node_or_null("EventBus")
	if event_bus and event_bus.has_method("post_message"):
		event_bus.post_message(message)


func save_game() -> void:
	var data: Dictionary = SAVE_SERIALIZER_SCRIPT.serialize(_collect_save_data())
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		_post_event_message("Could not save game")
		return
	file.store_string(JSON.stringify(data, "\t"))
	_post_event_message("Game saved")


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_post_event_message("No save file found")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		_post_event_message("Save file is invalid")
		return
	await _restore_save_data(Dictionary(parsed))
	_post_event_message("Game loaded")


func _collect_save_data() -> Dictionary:
	return _get_collector().collect()


func _get_player_data(player: Node) -> Dictionary:
	return _get_collector().get_player_data_from_player(player)


func _get_buildings_data() -> Array[Dictionary]:
	return _get_collector().get_buildings_data()


func _get_storage_boxes_data() -> Array[Dictionary]:
	return _get_collector().get_storage_boxes_data()


func _get_building_data(building_kind: String, building: Node2D) -> Dictionary:
	return _get_collector().get_building_data(building_kind, building)


func _restore_save_data(data: Dictionary) -> void:
	await _get_restorer().restore(SAVE_SERIALIZER_SCRIPT.deserialize(data))


func _restore_player_data(player: Node, data: Dictionary) -> void:
	_get_restorer().player = player
	_get_restorer().restore_player_data(data)


func _restore_buildings(buildings: Array, skip_storage_boxes: bool = false) -> void:
	_get_restorer().restore_buildings(buildings, skip_storage_boxes)


func _restore_storage_boxes(save_data: Dictionary) -> void:
	_get_restorer().restore_storage_boxes(save_data)


func _clear_existing_storage_boxes() -> void:
	_get_restorer().clear_existing_storage_boxes()


func _vector_to_data(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


func _data_to_vector(data: Variant) -> Vector2:
	if typeof(data) != TYPE_DICTIONARY:
		return Vector2.ZERO
	return Vector2(float(Dictionary(data).get("x", 0.0)), float(Dictionary(data).get("y", 0.0)))


func _sanitize_save_data(value: Variant) -> Variant:
	return SAVE_SERIALIZER_SCRIPT.sanitize(value)


func _get_collector() -> SaveDataCollector:
	if _collector == null:
		_collector = SAVE_DATA_COLLECTOR_SCRIPT.new()
	_update_collector_context()
	return _collector


func _get_restorer() -> SaveDataRestorer:
	if _restorer == null:
		_restorer = SAVE_DATA_RESTORER_SCRIPT.new()
	_update_restorer_context()
	return _restorer


func _update_collector_context() -> void:
	if _collector == null:
		return
	var tree := get_tree()
	_collector.scene = tree.current_scene if tree != null else null
	_collector.world = _collector.scene.get_node_or_null("World") if _collector.scene else null
	_collector.player = _collector.scene.get_node_or_null("Player") if _collector.scene else null
	_collector.day_night_system = _collector.scene.get_node_or_null("DayNightSystem") if _collector.scene else null
	_collector.evolution_director = _collector.scene.get_node_or_null("EvolutionDirector") if _collector.scene else null
	_collector.ecosystem_director = _collector.scene.get_node_or_null("EcosystemDirector") if _collector.scene else null


func _update_restorer_context() -> void:
	if _restorer == null:
		return
	var tree := get_tree()
	_restorer.scene = tree.current_scene if tree != null else null
	_restorer.world = _restorer.scene.get_node_or_null("World") if _restorer.scene else null
	_restorer.day_night_system = _restorer.scene.get_node_or_null("DayNightSystem") if _restorer.scene else null
	_restorer.evolution_director = _restorer.scene.get_node_or_null("EvolutionDirector") if _restorer.scene else null
	_restorer.ecosystem_director = _restorer.scene.get_node_or_null("EcosystemDirector") if _restorer.scene else null
	_restorer.game_session = get_node_or_null("/root/GameSession") if tree != null else null
