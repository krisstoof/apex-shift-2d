extends Node2D

const RESOURCE_SCENE := preload("res://scenes/world/resource_node.tscn")
const VARNAK_SCENE := preload("res://scenes/creatures/varnak.tscn")
const WORLD_RECT := Rect2(-1440, -880, 2880, 1760)
const RESOURCE_PLACEMENTS := [
	["tree", Vector2(-40, -20)], ["rock", Vector2(42, -16)], ["bush", Vector2(0, 50)],
	["tree", Vector2(-360, -210)], ["tree", Vector2(-270, 130)], ["tree", Vector2(360, -190)],
	["tree", Vector2(450, 180)], ["tree", Vector2(90, -330)], ["tree", Vector2(-520, 260)],
	["tree", Vector2(580, -50)], ["tree", Vector2(-120, 360)], ["tree", Vector2(240, 310)],
	["tree", Vector2(-610, -120)], ["rock", Vector2(-190, -150)], ["rock", Vector2(240, -240)],
	["rock", Vector2(520, 290)], ["rock", Vector2(-430, 70)], ["bush", Vector2(160, 140)],
	["bush", Vector2(-80, -260)], ["bush", Vector2(330, 70)], ["bush", Vector2(-330, 310)],
	["tree", Vector2(-1180, -620)], ["tree", Vector2(-1040, 380)], ["tree", Vector2(-820, 700)],
	["tree", Vector2(-760, -520)], ["tree", Vector2(850, -540)], ["tree", Vector2(960, 690)],
	["tree", Vector2(1210, -260)], ["tree", Vector2(1320, 430)], ["tree", Vector2(680, 610)],
	["rock", Vector2(-1290, 120)], ["rock", Vector2(-930, -760)], ["rock", Vector2(-700, 540)],
	["rock", Vector2(720, -770)], ["rock", Vector2(1120, -610)], ["rock", Vector2(1260, 120)],
	["bush", Vector2(-1320, -260)], ["bush", Vector2(-980, 650)], ["bush", Vector2(-650, -680)],
	["bush", Vector2(760, 430)], ["bush", Vector2(1040, -80)], ["bush", Vector2(1340, 720)]
]
const VARNAK_SPAWN_POINTS := [
	Vector2(220, 0),
	Vector2(-470, -300),
	Vector2(420, 330),
	Vector2(-980, -560),
	Vector2(1040, 520),
	Vector2(760, -680)
]

var evolution_director: Node
var day_night_system: Node

func _ready() -> void:
	await get_tree().process_frame
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


func _spawn_resources() -> void:
	for placement in RESOURCE_PLACEMENTS:
		var node := RESOURCE_SCENE.instantiate()
		add_child(node)
		node.position = placement[1]
		node.setup(placement[0])


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
