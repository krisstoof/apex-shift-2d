extends Node
class_name ChunkManager

const WORLD_CHUNK_SCRIPT := preload("res://scripts/world/world_chunk.gd")
const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")

var world: Node
var player: Node2D
var world_rect: Rect2 = Rect2()
var chunk_size := 1024.0
var active_radius_chunks := 1
var preload_radius_chunks := 2
var update_interval_seconds := 0.25
var debug_enabled := true

var chunk_map: Dictionary = {}
var entity_chunk_coords: Dictionary = {}
var active_chunk_coords: Dictionary = {}
var current_player_chunk := Vector2i(2147483647, 2147483647)
var update_timer := 0.0
var chunk_change_count := 0
var chunk_activation_count := 0
var chunk_deactivation_count := 0


func bind(p_world: Node, p_player: Node2D, p_world_rect: Rect2) -> void:
	world = p_world
	player = p_player
	world_rect = p_world_rect
	_load_config()
	_initialize_chunks()
	set_process(true)
	update_player_chunk(true)


func _process(delta: float) -> void:
	if world == null or player == null or not is_instance_valid(player):
		return
	update_timer += delta
	if update_timer < update_interval_seconds:
		return
	update_timer = 0.0
	update_player_chunk()


func _load_config() -> void:
	var chunks_config: Dictionary = Dictionary(GAME_BALANCE.WORLD_CHUNKS)
	chunk_size = float(chunks_config.get("chunk_size", 1024.0))
	active_radius_chunks = int(chunks_config.get("active_radius_chunks", 1))
	preload_radius_chunks = int(chunks_config.get("preload_radius_chunks", 2))
	update_interval_seconds = float(chunks_config.get("update_interval_seconds", 0.25))
	debug_enabled = chunks_config.get("debug_enabled", true) == true


func _initialize_chunks() -> void:
	chunk_map.clear()
	if world == null:
		return
	var min_coord := get_chunk_coord_for_position(world_rect.position)
	var max_coord := get_chunk_coord_for_position(world_rect.end)
	for chunk_x in range(min_coord.x, max_coord.x + 1):
		for chunk_y in range(min_coord.y, max_coord.y + 1):
			var coord := Vector2i(chunk_x, chunk_y)
			var chunk := WORLD_CHUNK_SCRIPT.new()
			var rect := Rect2(Vector2(coord) * chunk_size, Vector2(chunk_size, chunk_size))
			chunk.configure(coord, rect)
			chunk_map[coord] = chunk


func update_player_chunk(force_update: bool = false) -> void:
	if player == null or not is_instance_valid(player):
		return
	var next_chunk := get_chunk_coord_for_position(player.global_position)
	if not force_update and next_chunk == current_player_chunk:
		return
	var previous_chunk := current_player_chunk
	current_player_chunk = next_chunk
	chunk_change_count += 1
	_update_active_chunks(previous_chunk, next_chunk)


func get_chunk_coord_for_position(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / chunk_size), floori(world_position.y / chunk_size))


func get_chunk_for_position(world_position: Vector2):
	return chunk_map.get(get_chunk_coord_for_position(world_position), null)


func assign_entity(entity: Node, entity_type: String = "", chunk_coord: Vector2i = Vector2i(-2147483648, -2147483648)) -> void:
	if entity == null or not is_instance_valid(entity):
		return
	var target_coord := chunk_coord
	if target_coord == Vector2i(-2147483648, -2147483648):
		if entity is Node2D:
			target_coord = get_chunk_coord_for_position((entity as Node2D).global_position)
		else:
			return
	var chunk: Variant = chunk_map.get(target_coord, null)
	if chunk == null:
		return
	var group_name := _get_entity_chunk_group(entity, entity_type)
	_remove_entity_from_previous_chunk(entity)
	chunk.add_entity(entity, group_name)
	entity_chunk_coords[entity.get_instance_id()] = target_coord


func rebuild_entity_assignments() -> void:
	for chunk_value in chunk_map.values():
		var chunk: Variant = chunk_value
		if chunk != null:
			chunk.cleanup_invalid_refs()
	entity_chunk_coords.clear()
	if world == null:
		return
	for resource in world.get_all_registered_resources():
		assign_entity(resource, "resources")
	for creature in world.get_all_registered_creatures():
		assign_entity(creature, "creatures")
	for decoration in world.get_all_registered_decorations():
		assign_entity(decoration, "decorations")


func get_active_chunk_count() -> int:
	return active_chunk_coords.size()


func get_total_chunk_count() -> int:
	return chunk_map.size()


func get_active_chunk_coords() -> Array[Vector2i]:
	return Array(active_chunk_coords.keys())


func get_debug_data() -> Dictionary:
	var chunk_debug: Array[Dictionary] = []
	for chunk_coord in get_active_chunk_coords():
		var chunk: Variant = chunk_map.get(chunk_coord, null)
		if chunk != null:
			chunk_debug.append(chunk.get_debug_data())
	return {
		"current_player_chunk": current_player_chunk,
		"active_chunk_count": get_active_chunk_count(),
		"total_chunk_count": get_total_chunk_count(),
		"chunk_change_count": chunk_change_count,
		"chunk_activation_count": chunk_activation_count,
		"chunk_deactivation_count": chunk_deactivation_count,
		"active_chunk_coords": get_active_chunk_coords(),
		"active_chunks": chunk_debug,
		"debug_enabled": debug_enabled
	}


func _update_active_chunks(_previous_chunk: Vector2i, player_chunk: Vector2i) -> void:
	active_chunk_coords.clear()
	for chunk_coord in chunk_map.keys():
		var coord := Vector2i(chunk_coord)
		if _is_chunk_active(coord, player_chunk):
			active_chunk_coords[coord] = true
			_activate_chunk(coord)
		else:
			_deactivate_chunk(coord)
	_apply_entity_chunk_active_state()


func _activate_chunk(chunk_coord: Vector2i) -> void:
	var chunk: Variant = chunk_map.get(chunk_coord, null)
	if chunk == null:
		return
	if not chunk.is_active:
		chunk.set_active(true)
		chunk_activation_count += 1


func _deactivate_chunk(chunk_coord: Vector2i) -> void:
	var chunk: Variant = chunk_map.get(chunk_coord, null)
	if chunk == null:
		return
	if chunk.is_active:
		chunk.set_active(false)
		chunk_deactivation_count += 1


func _apply_entity_chunk_active_state() -> void:
	for chunk_coord in chunk_map.keys():
		var chunk: Variant = chunk_map.get(chunk_coord, null)
		if chunk != null:
			chunk.cleanup_invalid_refs()


func _is_chunk_active(chunk_coord: Vector2i, player_chunk: Vector2i) -> bool:
	var distance: int = int(max(abs(chunk_coord.x - player_chunk.x), abs(chunk_coord.y - player_chunk.y)))
	return distance <= active_radius_chunks


func _get_entity_chunk_group(entity: Node, entity_type: String) -> String:
	if entity_type == "resources" or entity.has_method("get") and str(entity.get("resource_kind")) != "":
		return "resources"
	if entity_type == "creatures":
		return "creatures"
	return "decorations"


func _remove_entity_from_previous_chunk(entity: Node) -> void:
	if entity == null or not is_instance_valid(entity):
		return
	var instance_id := entity.get_instance_id()
	if not entity_chunk_coords.has(instance_id):
		return
	var chunk_coord: Vector2i = Vector2i(entity_chunk_coords[instance_id])
	var chunk: Variant = chunk_map.get(chunk_coord, null)
	if chunk != null:
		chunk.remove_entity(entity)
	entity_chunk_coords.erase(instance_id)
