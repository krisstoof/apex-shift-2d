extends Node2D

const RESOURCE_SCENE := preload("res://scenes/world/resource_node.tscn")
const VARNAK_SCENE := preload("res://scenes/creatures/varnak.tscn")

var evolution_director: Node
var day_night_system: Node

func _ready() -> void:
	await get_tree().process_frame
	evolution_director = get_parent().get_node("EvolutionDirector")
	day_night_system = get_parent().get_node("DayNightSystem")
	evolution_director.profile_changed.connect(_on_profile_changed)
	_spawn_resources()
	_spawn_varnaks()
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _spawn_resources() -> void:
	var placements := [
		["tree", Vector2(-360, -210)], ["tree", Vector2(-270, 130)], ["tree", Vector2(360, -190)],
		["tree", Vector2(450, 180)], ["tree", Vector2(90, -330)], ["tree", Vector2(-520, 260)],
		["tree", Vector2(580, -50)], ["tree", Vector2(-120, 360)], ["tree", Vector2(240, 310)],
		["tree", Vector2(-610, -120)], ["rock", Vector2(-190, -150)], ["rock", Vector2(240, -240)],
		["rock", Vector2(520, 290)], ["rock", Vector2(-430, 70)], ["bush", Vector2(160, 140)],
		["bush", Vector2(-80, -260)], ["bush", Vector2(330, 70)], ["bush", Vector2(-330, 310)]
	]
	for placement in placements:
		var node := RESOURCE_SCENE.instantiate()
		add_child(node)
		node.position = placement[1]
		node.setup(placement[0])


func _spawn_varnaks() -> void:
	for pos in [Vector2(460, -260), Vector2(-470, -300), Vector2(420, 330)]:
		var varnak := VARNAK_SCENE.instantiate()
		add_child(varnak)
		varnak.global_position = pos
		varnak.apply_profile(evolution_director.get_profile())
		varnak.day_night_system = day_night_system


func _on_profile_changed(profile: Dictionary) -> void:
	for varnak in get_tree().get_nodes_in_group("varnak"):
		varnak.apply_profile(profile)


func _draw() -> void:
	draw_rect(Rect2(-720, -440, 1440, 880), Color(0.14, 0.22, 0.13), true)
	draw_rect(Rect2(-720, -440, 1440, 880), Color(0.07, 0.09, 0.07), false, 5.0)
	if day_night_system and day_night_system.night_amount > 0.0:
		draw_rect(Rect2(-720, -440, 1440, 880), Color(0.02, 0.03, 0.09, day_night_system.night_amount * 0.45), true)
