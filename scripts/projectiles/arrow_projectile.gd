extends Area2D

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")


func _emit_game_event(event_name: String, payload: Dictionary = {}) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var event_bus := tree.root.get_node_or_null("EventBus")
	if event_bus and event_bus.has_method("emit_game_event"):
		event_bus.emit_game_event(event_name, payload)

var direction := Vector2.RIGHT
var speed := float(GAME_BALANCE.RANGED_COMBAT.get("arrow_speed", 780.0))
var damage := float(GAME_BALANCE.RANGED_COMBAT.get("bow_damage", 28.0))
var lifetime := float(GAME_BALANCE.RANGED_COMBAT.get("arrow_lifetime_seconds", 1.25))
var max_range := float(GAME_BALANCE.RANGED_COMBAT.get("arrow_max_range", 900.0))
var traveled_distance := 0.0
var owner_node: Node
var source_name := "player"


func _ready() -> void:
	add_to_group("projectiles")
	body_entered.connect(_on_body_entered)
	queue_redraw()


func setup(p_direction: Vector2, p_owner: Node, p_damage: float, p_source_name := "player") -> void:
	if p_direction.length_squared() > 0.0:
		direction = p_direction.normalized()
	owner_node = p_owner
	damage = p_damage
	source_name = p_source_name
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	var step := direction * speed * delta
	global_position += step
	traveled_distance += step.length()
	lifetime = max(lifetime - delta, 0.0)
	if lifetime <= 0.0 or traveled_distance >= max_range:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body == owner_node:
		return
	if source_name == "player" and body.is_in_group("player"):
		return
	if _is_damage_target(body):
		body.take_damage(damage, source_name)
		_emit_game_event("arrow_hit_target", {
			"target": _get_target_label(body),
			"damage": damage,
			"position": global_position
		})
		queue_free()
		return
	if body is PhysicsBody2D:
		queue_free()


func _is_damage_target(body: Node) -> bool:
	if not body.has_method("take_damage"):
		return false
	return body.is_in_group("varnak") or body.is_in_group("small_prey") or body.is_in_group("grazer")


func _get_target_label(body: Node) -> String:
	if body.is_in_group("grazer"):
		return "grazer"
	if body.is_in_group("small_prey"):
		return "small_prey"
	if body.is_in_group("varnak"):
		return "varnak"
	return "unknown"


func _draw() -> void:
	draw_line(Vector2(-12.0, 0.0), Vector2(10.0, 0.0), Color(0.72, 0.46, 0.22), 3.0)
	draw_polygon(
		[Vector2(14.0, 0.0), Vector2(5.0, -5.0), Vector2(5.0, 5.0)],
		[Color(0.92, 0.88, 0.72)]
	)
