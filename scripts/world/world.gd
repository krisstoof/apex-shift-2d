extends Node2D

const RESOURCE_SCENE := preload("res://scenes/world/resource_node.tscn")
const VARNAK_SCENE := preload("res://scenes/creatures/varnak.tscn")
const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")

var evolution_director: Node
var day_night_system: Node
var resource_rng := RandomNumberGenerator.new()
var varnak_rng := RandomNumberGenerator.new()

func _ready() -> void:
	await get_tree().process_frame
	resource_rng.randomize()
	varnak_rng.randomize()
	evolution_director = get_parent().get_node("EvolutionDirector")
	day_night_system = get_parent().get_node("DayNightSystem")
	evolution_director.profile_changed.connect(_on_profile_changed)
	get_node("/root/EventBus").game_event.connect(_on_game_event)
	_spawn_resources()
	_spawn_varnaks()
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func get_world_rect() -> Rect2:
	return WORLD_CONFIG.WORLD_RECT


func get_biome_zones() -> Array[Dictionary]:
	return WORLD_CONFIG.get_biome_zones()


func _spawn_resources() -> void:
	var used_positions: Array[Vector2] = []
	var player_position := _get_player_position()
	var conifer_count := int(ceil(float(WORLD_CONFIG.TREE_COUNT) * 0.6))
	var leafy_count := WORLD_CONFIG.TREE_COUNT - conifer_count
	var dry_bush_count := int(ceil(float(WORLD_CONFIG.BUSH_COUNT) * 0.35))
	var green_bush_count := WORLD_CONFIG.BUSH_COUNT - dry_bush_count

	_spawn_resource_kind("conifer_tree", conifer_count, used_positions, player_position)
	_spawn_resource_kind("leafy_tree", leafy_count, used_positions, player_position)
	_spawn_resource_kind("rock", WORLD_CONFIG.ROCK_COUNT, used_positions, player_position)
	_spawn_resource_kind("bush", green_bush_count, used_positions, player_position)
	_spawn_resource_kind("dry_bush", dry_bush_count, used_positions, player_position)


func _spawn_resource_kind(resource_kind: String, count: int, used_positions: Array[Vector2], player_position: Vector2) -> void:
	for _i in count:
		if not _try_spawn_resource(resource_kind, used_positions, player_position):
			push_warning("Could not find a valid spawn position for %s" % resource_kind)


func _spawn_resource_at(resource_kind: String, pos: Vector2) -> void:
	var node := RESOURCE_SCENE.instantiate()
	add_child(node)
	node.position = pos
	node.setup(resource_kind)


func _try_spawn_resource(resource_kind: String, used_positions: Array[Vector2], player_position: Vector2) -> bool:
	for _attempt in WORLD_CONFIG.RESOURCE_SPAWN_ATTEMPTS:
		var biome := _pick_resource_biome(resource_kind)
		var spawn_area := _get_biome_bounds(biome).grow(-WORLD_CONFIG.RESOURCE_SPAWN_MARGIN)
		var candidate := Vector2(
			resource_rng.randf_range(spawn_area.position.x, spawn_area.end.x),
			resource_rng.randf_range(spawn_area.position.y, spawn_area.end.y)
		)
		if _is_point_in_biome(candidate, biome) and _is_valid_resource_position(candidate, used_positions, player_position):
			used_positions.append(candidate)
			_spawn_resource_at(resource_kind, candidate)
			return true
	return false


func _pick_resource_biome(resource_kind: String) -> Dictionary:
	var total_weight := 0.0
	for biome_value in WORLD_CONFIG.BIOME_ZONES:
		var biome := Dictionary(biome_value)
		total_weight += _get_biome_resource_weight(biome, resource_kind)
	if total_weight <= 0.0:
		return Dictionary(WORLD_CONFIG.BIOME_ZONES[0])

	var roll := resource_rng.randf_range(0.0, total_weight)
	var cursor := 0.0
	for biome_value in WORLD_CONFIG.BIOME_ZONES:
		var biome := Dictionary(biome_value)
		cursor += _get_biome_resource_weight(biome, resource_kind)
		if roll <= cursor:
			return biome
	return Dictionary(WORLD_CONFIG.BIOME_ZONES[0])


func _get_biome_resource_weight(biome: Dictionary, resource_kind: String) -> float:
	match resource_kind:
		"tree", "conifer_tree", "leafy_tree":
			return float(biome.get("tree_weight", 0.0))
		"rock":
			return float(biome.get("rock_weight", 0.0))
		"bush", "dry_bush":
			return float(biome.get("bush_weight", 0.0))
		_:
			return 0.0


func _get_biome_bounds(biome: Dictionary) -> Rect2:
	var points := _get_biome_points(biome)
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


func _is_point_in_biome(point: Vector2, biome: Dictionary) -> bool:
	return Geometry2D.is_point_in_polygon(point, PackedVector2Array(_get_biome_points(biome)))


func _get_biome_points(biome: Dictionary) -> Array[Vector2]:
	return WORLD_CONFIG.get_biome_points(biome)


func _draw_biome_outline(points: PackedVector2Array) -> void:
	for i in points.size():
		var start := points[i]
		var end := points[(i + 1) % points.size()]
		draw_line(start, end, Color(0.05, 0.06, 0.05, 0.45), 2.0)


func _is_valid_resource_position(candidate: Vector2, used_positions: Array[Vector2], player_position: Vector2) -> bool:
	if candidate.distance_to(player_position) < WORLD_CONFIG.RESOURCE_PLAYER_SAFE_DISTANCE:
		return false
	for used_position in used_positions:
		if candidate.distance_to(used_position) < WORLD_CONFIG.RESOURCE_MIN_DISTANCE:
			return false
	return true


func _get_player_position() -> Vector2:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		return player.global_position
	return Vector2.ZERO


func respawn_resources() -> void:
	for resource in get_tree().get_nodes_in_group("resources"):
		if is_instance_valid(resource):
			resource.queue_free()
	await get_tree().process_frame
	_spawn_resources()
	get_node("/root/EventBus").post_message("Resources regrew after sleep")


func get_resource_save_data() -> Array[Dictionary]:
	var resources: Array[Dictionary] = []
	for resource in get_tree().get_nodes_in_group("resources"):
		if not is_instance_valid(resource):
			continue
		resources.append({
			"kind": str(resource.get("resource_kind")),
			"position": _vector_to_data(resource.global_position)
		})
	return resources


func restore_resources(resources: Array) -> void:
	for resource in get_tree().get_nodes_in_group("resources"):
		if is_instance_valid(resource):
			resource.queue_free()
	await get_tree().process_frame
	for resource_data in resources:
		if typeof(resource_data) != TYPE_DICTIONARY:
			continue
		var kind := str(resource_data.get("kind", "tree"))
		var pos := _data_to_vector(resource_data.get("position", {}))
		_spawn_resource_at(kind, pos)


func _spawn_varnaks() -> void:
	for _i in WORLD_CONFIG.VARNAK_TARGET_COUNT:
		if not _try_spawn_missing_varnak():
			push_warning("Could not find a safe initial Varnak spawn point")


func respawn_missing_varnaks() -> void:
	var missing_count := WORLD_CONFIG.VARNAK_TARGET_COUNT - get_tree().get_nodes_in_group("varnak").size()
	if missing_count <= 0:
		return
	var spawned := 0
	for _i in missing_count:
		if not _try_spawn_missing_varnak():
			push_warning("Could not find a safe Varnak spawn point")
			continue
		spawned += 1
	if spawned > 0:
		get_node("/root/EventBus").post_message("%d Varnak%s returned after sleep" % [spawned, "" if spawned == 1 else "s"])


func respawn_varnaks() -> void:
	for varnak in get_tree().get_nodes_in_group("varnak"):
		if is_instance_valid(varnak):
			varnak.queue_free()
	await get_tree().process_frame
	_spawn_varnaks()
	get_node("/root/EventBus").post_message("Varnaks respawned with current profile")


func get_varnak_save_data() -> Array[Dictionary]:
	var varnaks: Array[Dictionary] = []
	for varnak in get_tree().get_nodes_in_group("varnak"):
		if not is_instance_valid(varnak):
			continue
		if varnak.has_method("get_save_data"):
			varnaks.append(varnak.get_save_data())
	return varnaks


func restore_varnaks(varnaks: Array) -> void:
	for varnak in get_tree().get_nodes_in_group("varnak"):
		if is_instance_valid(varnak):
			varnak.queue_free()
	await get_tree().process_frame
	for varnak_data in varnaks:
		if typeof(varnak_data) != TYPE_DICTIONARY:
			continue
		_restore_varnak_from_data(Dictionary(varnak_data))


func _spawn_varnak_at(pos: Vector2) -> void:
	var varnak := VARNAK_SCENE.instantiate()
	add_child(varnak)
	varnak.global_position = pos
	varnak.apply_profile(evolution_director.get_profile())
	varnak.day_night_system = day_night_system


func _restore_varnak_from_data(data: Dictionary) -> void:
	var varnak := VARNAK_SCENE.instantiate()
	add_child(varnak)
	varnak.apply_profile(evolution_director.get_profile())
	varnak.day_night_system = day_night_system
	if varnak.has_method("restore_from_data"):
		varnak.restore_from_data(data)


func _try_spawn_missing_varnak() -> bool:
	var player_position := _get_player_position()
	for _attempt in WORLD_CONFIG.VARNAK_SPAWN_ATTEMPTS:
		var point := _pick_varnak_spawn_point()
		if _is_valid_varnak_spawn_position(point, player_position):
			_spawn_varnak_at(point)
			return true
	return false


func _pick_varnak_spawn_point() -> Vector2:
	var total_weight := 0.0
	for point_value in WORLD_CONFIG.VARNAK_SPAWN_POINTS:
		total_weight += _get_varnak_spawn_weight(_scale_world_point(Vector2(point_value)))
	var roll := varnak_rng.randf_range(0.0, total_weight)
	var cursor := 0.0
	for point_value in WORLD_CONFIG.VARNAK_SPAWN_POINTS:
		var point := _scale_world_point(Vector2(point_value))
		cursor += _get_varnak_spawn_weight(point)
		if roll <= cursor:
			return point
	return _scale_world_point(Vector2(WORLD_CONFIG.VARNAK_SPAWN_POINTS[0]))


func _scale_world_point(point: Vector2) -> Vector2:
	return WORLD_CONFIG.scale_world_point(point)


func _get_varnak_spawn_weight(point: Vector2) -> float:
	return 4.0 if _is_point_in_dangerous_biome(point) else 1.0


func _is_point_in_dangerous_biome(point: Vector2) -> bool:
	for biome_value in WORLD_CONFIG.BIOME_ZONES:
		var biome := Dictionary(biome_value)
		if bool(biome.get("dangerous", false)) and _is_point_in_biome(point, biome):
			return true
	return false


func _is_valid_varnak_spawn_position(point: Vector2, player_position: Vector2) -> bool:
	if point.distance_to(player_position) < WORLD_CONFIG.VARNAK_PLAYER_SAFE_DISTANCE:
		return false
	for varnak in get_tree().get_nodes_in_group("varnak"):
		if is_instance_valid(varnak) and varnak.global_position.distance_to(point) < 80.0:
			return false
	return true


func _on_profile_changed(profile: Dictionary) -> void:
	for varnak in get_tree().get_nodes_in_group("varnak"):
		varnak.apply_profile(profile)


func _on_game_event(event_name: String, _payload: Dictionary) -> void:
	if event_name == "generation_changed":
		call_deferred("respawn_varnaks")
	elif event_name == "day_ended" and _payload.get("reason", "") == "slept_in_tent":
		call_deferred("respawn_resources")
		call_deferred("respawn_missing_varnaks")


func _vector_to_data(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


func _data_to_vector(data: Variant) -> Vector2:
	if typeof(data) != TYPE_DICTIONARY:
		return Vector2.ZERO
	return Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))


func _draw() -> void:
	draw_rect(WORLD_CONFIG.WORLD_RECT, Color(0.14, 0.22, 0.13), true)
	for biome_value in WORLD_CONFIG.BIOME_ZONES:
		var biome := Dictionary(biome_value)
		var biome_points := PackedVector2Array(_get_biome_points(biome))
		draw_colored_polygon(biome_points, Color(biome["color"]))
		_draw_biome_outline(biome_points)
	draw_rect(WORLD_CONFIG.WORLD_RECT, Color(0.07, 0.09, 0.07), false, 5.0)
	if day_night_system and day_night_system.night_amount > 0.0:
		draw_rect(WORLD_CONFIG.WORLD_RECT, Color(0.02, 0.03, 0.09, day_night_system.night_amount * 0.45), true)
