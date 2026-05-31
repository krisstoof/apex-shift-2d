extends Node2D

const RESOURCE_SCENE := preload("res://scenes/world/resource_node.tscn")
const VARNAK_SCENE := preload("res://scenes/creatures/varnak.tscn")
const WORLD_RECT := Rect2(-1440, -880, 2880, 1760)
const RESOURCE_SPAWN_MARGIN := 70.0
const RESOURCE_MIN_DISTANCE := 70.0
const RESOURCE_PLAYER_SAFE_DISTANCE := 180.0
const RESOURCE_SPAWN_ATTEMPTS := 80
const VARNAK_SPAWN_POINTS := [
	Vector2(220, 0),
	Vector2(-470, -300),
	Vector2(420, 330),
	Vector2(-980, -560),
	Vector2(1040, 520),
	Vector2(760, -680)
]

@export var tree_count := 24
@export var rock_count := 12
@export var bush_count := 16

var evolution_director: Node
var day_night_system: Node
var resource_rng := RandomNumberGenerator.new()

func _ready() -> void:
	await get_tree().process_frame
	resource_rng.randomize()
	evolution_director = get_parent().get_node("EvolutionDirector")
	day_night_system = get_parent().get_node("DayNightSystem")
	evolution_director.profile_changed.connect(_on_profile_changed)
	day_night_system.day_changed.connect(_on_day_changed)
	get_node("/root/EventBus").game_event.connect(_on_game_event)
	_spawn_resources()
	_spawn_varnaks()
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func get_world_rect() -> Rect2:
	return WORLD_RECT


func _spawn_resources() -> void:
	var resource_counts := {
		"tree": tree_count,
		"rock": rock_count,
		"bush": bush_count
	}
	var used_positions: Array[Vector2] = []
	var player_position := _get_player_position()

	for resource_key in resource_counts.keys():
		var resource_kind := String(resource_key)
		for _i in int(resource_counts[resource_key]):
			if not _try_spawn_resource(resource_kind, used_positions, player_position):
				push_warning("Could not find a valid spawn position for %s" % resource_kind)


func _spawn_resource_at(resource_kind: String, pos: Vector2) -> void:
	var node := RESOURCE_SCENE.instantiate()
	add_child(node)
	node.position = pos
	node.setup(resource_kind)


func _try_spawn_resource(resource_kind: String, used_positions: Array[Vector2], player_position: Vector2) -> bool:
	var spawn_area := WORLD_RECT.grow(-RESOURCE_SPAWN_MARGIN)
	for _attempt in RESOURCE_SPAWN_ATTEMPTS:
		var candidate := Vector2(
			resource_rng.randf_range(spawn_area.position.x, spawn_area.end.x),
			resource_rng.randf_range(spawn_area.position.y, spawn_area.end.y)
		)
		if _is_valid_resource_position(candidate, used_positions, player_position):
			used_positions.append(candidate)
			_spawn_resource_at(resource_kind, candidate)
			return true
	return false


func _is_valid_resource_position(candidate: Vector2, used_positions: Array[Vector2], player_position: Vector2) -> bool:
	if candidate.distance_to(player_position) < RESOURCE_PLAYER_SAFE_DISTANCE:
		return false
	for used_position in used_positions:
		if candidate.distance_to(used_position) < RESOURCE_MIN_DISTANCE:
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


func _spawn_varnaks() -> void:
	for pos in VARNAK_SPAWN_POINTS:
		_spawn_varnak_at(pos)


func respawn_varnaks() -> void:
	for varnak in get_tree().get_nodes_in_group("varnak"):
		if is_instance_valid(varnak):
			varnak.queue_free()
	await get_tree().process_frame
	_spawn_varnaks()
	get_node("/root/EventBus").post_message("Varnaks respawned with current profile")


func _spawn_varnak_at(pos: Vector2) -> void:
	var varnak := VARNAK_SCENE.instantiate()
	add_child(varnak)
	varnak.global_position = pos
	varnak.apply_profile(evolution_director.get_profile())
	varnak.day_night_system = day_night_system


func _on_profile_changed(profile: Dictionary) -> void:
	for varnak in get_tree().get_nodes_in_group("varnak"):
		varnak.apply_profile(profile)


func _on_day_changed(_day: int) -> void:
	var existing := get_tree().get_nodes_in_group("varnak").size()
	var spawned := 0
	while existing + spawned < VARNAK_SPAWN_POINTS.size():
		_spawn_varnak_at(VARNAK_SPAWN_POINTS[existing + spawned])
		spawned += 1
	if spawned > 0:
		get_node("/root/EventBus").post_message("Varnaks returned after the night")


func _on_game_event(event_name: String, _payload: Dictionary) -> void:
	if event_name == "generation_changed":
		call_deferred("respawn_varnaks")
	elif event_name == "day_ended" and _payload.get("reason", "") == "slept_in_tent":
		call_deferred("respawn_resources")


func _draw() -> void:
	draw_rect(WORLD_RECT, Color(0.14, 0.22, 0.13), true)
	draw_rect(WORLD_RECT, Color(0.07, 0.09, 0.07), false, 5.0)
	if day_night_system and day_night_system.night_amount > 0.0:
		draw_rect(WORLD_RECT, Color(0.02, 0.03, 0.09, day_night_system.night_amount * 0.45), true)
