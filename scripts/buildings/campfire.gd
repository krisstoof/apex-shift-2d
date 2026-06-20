extends Area2D

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const BUILDING_STATE := preload("res://scripts/core/buildings/building_state.gd")

@export var fear_radius := GAME_BALANCE.CAMPFIRE_SAFE_RADIUS
@export var light_radius := GAME_BALANCE.CAMPFIRE_LIGHT_RADIUS
@export var stamina_regen_radius := GAME_BALANCE.CAMPFIRE_STAMINA_REGEN_RADIUS

var active := true
var building_state := BUILDING_STATE.new()
var day_night_system: Node
var campfire_light: PointLight2D
var campfire_flicker_time := 0.0
static var cached_light_texture: Texture2D

func _ready() -> void:
	add_to_group("campfires")
	_sync_state_from_node()
	var scene := get_tree().current_scene
	if scene:
		day_night_system = scene.get_node_or_null("DayNightSystem")
	_ensure_campfire_light()
	queue_redraw()


func _process(_delta: float) -> void:
	_update_campfire_light(_delta)
	if active:
		queue_redraw()


func _draw() -> void:
	if active:
		_draw_fire_light()
	draw_circle(Vector2.ZERO, 18.0, Color(0.28, 0.12, 0.05))
	draw_line(Vector2(-17, 8), Vector2(16, -8), Color(0.22, 0.11, 0.04), 6.0)
	draw_line(Vector2(-15, -7), Vector2(17, 7), Color(0.30, 0.15, 0.05), 6.0)
	if active:
		draw_circle(Vector2.ZERO, 11.0, Color(1.0, 0.42, 0.08))
		draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.9, 0.25))
		draw_arc(Vector2.ZERO, fear_radius, 0.0, TAU, 48, Color(1.0, 0.55, 0.1, 0.18), 2.0)
	else:
		draw_circle(Vector2.ZERO, 9.0, Color(0.08, 0.07, 0.06))


func get_building_state() -> Dictionary:
	_sync_state_from_node()
	return building_state.to_save_data()


func apply_building_state(data: Dictionary) -> void:
	building_state.load_from_save_data(data)
	_sync_node_from_state()


func _sync_state_from_node() -> void:
	building_state.kind = "campfire"
	building_state.position = global_position
	building_state.active = active
	building_state.fear_radius = fear_radius


func _sync_node_from_state() -> void:
	active = building_state.active
	fear_radius = building_state.fear_radius


func _draw_fire_light() -> void:
	var night_amount := _get_night_amount()
	var flicker := 0.92 + sin(Time.get_ticks_msec() * 0.014 + global_position.x * 0.021) * 0.08
	var strength := (0.22 + night_amount * 0.62) * flicker
	draw_circle(Vector2.ZERO, light_radius, Color(1.0, 0.46, 0.06, strength * 0.08))
	draw_circle(Vector2.ZERO, light_radius * 0.62, Color(1.0, 0.58, 0.10, strength * 0.13))
	draw_circle(Vector2.ZERO, light_radius * 0.34, Color(1.0, 0.78, 0.22, strength * 0.18))


func _ensure_campfire_light() -> void:
	if campfire_light != null:
		return
	campfire_light = PointLight2D.new()
	campfire_light.name = "CampfireLight"
	campfire_light.texture = _get_radial_light_texture()
	campfire_light.energy = 2.2
	campfire_light.texture_scale = 7.0
	campfire_light.color = Color(1.0, 0.68, 0.32)
	campfire_light.shadow_enabled = false
	campfire_light.enabled = true
	campfire_light.visible = active
	add_child(campfire_light)
	print("[LIGHTING] Campfire light created")


func _update_campfire_light(delta: float) -> void:
	_ensure_campfire_light()
	campfire_light.visible = active
	campfire_light.enabled = active
	if not active:
		return
	campfire_flicker_time += delta
	var flicker := 0.95 + sin(campfire_flicker_time * 7.0) * 0.06 + sin(campfire_flicker_time * 13.0) * 0.04
	campfire_light.energy = 2.2 * flicker * _get_light_visibility_multiplier()


func _get_light_visibility_multiplier() -> float:
	var night_amount := _get_night_amount()
	return lerpf(0.35, 1.0, clampf(night_amount, 0.0, 1.0))


static func _get_radial_light_texture() -> Texture2D:
	if cached_light_texture != null:
		return cached_light_texture
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var radius := float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var p := Vector2(x, y)
			var distance := p.distance_to(center)
			var t := clampf(1.0 - distance / radius, 0.0, 1.0)
			t *= t
			image.set_pixel(x, y, Color(1.0, 0.82, 0.45, t))
	cached_light_texture = ImageTexture.create_from_image(image)
	return cached_light_texture


func _get_night_amount() -> float:
	if day_night_system:
		return float(day_night_system.night_amount)
	return 0.0
