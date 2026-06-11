extends Node2D
class_name VegetationVisualLayer

const DEFAULT_GRASS_RADIUS := 5.0
const DEFAULT_DENSE_GRASS_RADIUS := 8.0

var instances: Array[Dictionary] = []
var count_by_kind: Dictionary = {}
var dirty := false


func clear_instances() -> void:
	instances.clear()
	count_by_kind.clear()
	dirty = true
	queue_redraw()


func add_instance(kind: String, world_position: Vector2, radius: float = -1.0, biome_id: String = "", visual_scale: float = 1.0) -> void:
	var resolved_radius := radius
	if resolved_radius <= 0.0:
		resolved_radius = get_default_radius(kind)
	resolved_radius *= maxf(visual_scale, 0.1)
	instances.append({
		"kind": kind,
		"position": world_position,
		"radius": resolved_radius,
		"biome_id": biome_id,
		"visual_scale": visual_scale,
		"seed": _make_seed(kind, world_position)
	})
	count_by_kind[kind] = int(count_by_kind.get(kind, 0)) + 1
	dirty = true
	queue_redraw()


func add_instances(items: Array) -> void:
	for item_value in items:
		var item := Dictionary(item_value)
		add_instance(
			str(item.get("kind", "grass_patch")),
			Vector2(item.get("position", Vector2.ZERO)),
			float(item.get("radius", -1.0)),
			str(item.get("biome_id", "")),
			float(item.get("visual_scale", 1.0))
		)


func get_instance_count() -> int:
	return instances.size()


func get_count_by_kind() -> Dictionary:
	return count_by_kind.duplicate()


func get_debug_stats() -> Dictionary:
	return {
		"visual_instance_count": instances.size(),
		"count_by_kind": get_count_by_kind()
	}


func get_default_radius(kind: String) -> float:
	match kind:
		"dense_grass":
			return DEFAULT_DENSE_GRASS_RADIUS
		"grass_patch":
			return DEFAULT_GRASS_RADIUS
	return DEFAULT_GRASS_RADIUS


func _draw() -> void:
	for item in instances:
		var kind := str(item.get("kind", "grass_patch"))
		var position := Vector2(item.get("position", Vector2.ZERO))
		var radius := float(item.get("radius", get_default_radius(kind)))
		var seed := int(item.get("seed", 0))
		_draw_vegetation_instance(kind, position, radius, seed)


func _draw_vegetation_instance(kind: String, position: Vector2, radius: float, seed: int) -> void:
	var color := _get_color_for_kind(kind, seed)
	match kind:
		"dense_grass":
			draw_circle(position, radius, color)
			draw_circle(position + Vector2(radius * 0.45, -radius * 0.18), radius * 0.65, color.darkened(0.08))
			draw_circle(position + Vector2(-radius * 0.35, radius * 0.22), radius * 0.55, color.lightened(0.06))
		"grass_patch":
			draw_circle(position, radius, color)
			draw_circle(position + Vector2(radius * 0.35, radius * 0.12), radius * 0.45, color.lightened(0.05))
		_:
			draw_circle(position, radius, color)


func _get_color_for_kind(kind: String, seed: int) -> Color:
	var variation := float(abs(seed % 17)) / 17.0
	match kind:
		"dense_grass":
			return Color(0.15 + variation * 0.04, 0.38 + variation * 0.08, 0.14, 0.58)
		"grass_patch":
			return Color(0.20 + variation * 0.05, 0.47 + variation * 0.08, 0.18, 0.48)
	return Color(0.20, 0.45, 0.18, 0.45)


func _make_seed(kind: String, world_position: Vector2) -> int:
	var hash_value := kind.hash()
	hash_value = int(hash_value + int(world_position.x * 17.0) + int(world_position.y * 31.0))
	return hash_value
