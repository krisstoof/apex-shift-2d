extends Node2D
class_name VegetationVisualLayer

const DEFAULT_GRASS_RADIUS := 5.0
const DEFAULT_DENSE_GRASS_RADIUS := 8.0
const DEFAULT_CHUNK_SIZE := 768.0
const DEFAULT_VISIBILITY_MARGIN := 512.0

var instances: Array[Dictionary] = []
var count_by_kind: Dictionary = {}
var instances_by_chunk: Dictionary = {}
var chunk_size := DEFAULT_CHUNK_SIZE
var visible_world_rect := Rect2()
var has_visible_world_rect := false
var drawn_instance_count := 0
var visible_chunk_count := 0
var last_visible_chunk_signature := ""
var total_chunk_count := 0
var dirty := false


func clear_instances() -> void:
	instances.clear()
	count_by_kind.clear()
	instances_by_chunk.clear()
	drawn_instance_count = 0
	visible_chunk_count = 0
	total_chunk_count = 0
	last_visible_chunk_signature = ""
	dirty = true
	queue_redraw()


func add_instance(kind: String, world_position: Vector2, radius: float = -1.0, biome_id: String = "", visual_scale: float = 1.0) -> void:
	var resolved_radius := radius
	if resolved_radius <= 0.0:
		resolved_radius = get_default_radius(kind)
	resolved_radius *= maxf(visual_scale, 0.1)
	var item := {
		"kind": kind,
		"position": world_position,
		"radius": resolved_radius,
		"biome_id": biome_id,
		"visual_scale": visual_scale,
		"seed": _make_seed(kind, world_position)
	}
	instances.append(item)
	count_by_kind[kind] = int(count_by_kind.get(kind, 0)) + 1
	var chunk_key := _get_chunk_key(world_position)
	if not instances_by_chunk.has(chunk_key):
		instances_by_chunk[chunk_key] = []
	var chunk_items: Array = Array(instances_by_chunk[chunk_key])
	chunk_items.append(item)
	instances_by_chunk[chunk_key] = chunk_items
	total_chunk_count = instances_by_chunk.size()
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


func set_visible_world_rect(world_rect: Rect2) -> void:
	var expanded_rect := world_rect.grow(DEFAULT_VISIBILITY_MARGIN)
	has_visible_world_rect = true
	visible_world_rect = expanded_rect
	var signature := _get_visible_chunk_signature(expanded_rect)
	if signature == last_visible_chunk_signature:
		return
	last_visible_chunk_signature = signature
	queue_redraw()


func clear_visible_world_rect() -> void:
	has_visible_world_rect = false
	last_visible_chunk_signature = ""
	queue_redraw()


func get_debug_stats() -> Dictionary:
	return {
		"visual_instance_count": instances.size(),
		"total_instance_count": instances.size(),
		"drawn_instance_count": drawn_instance_count,
		"visible_chunk_count": visible_chunk_count,
		"total_chunk_count": instances_by_chunk.size(),
		"count_by_kind": get_count_by_kind(),
		"has_visible_world_rect": has_visible_world_rect,
		"visible_world_rect": str(visible_world_rect)
	}


func get_default_radius(kind: String) -> float:
	match kind:
		"dense_grass":
			return DEFAULT_DENSE_GRASS_RADIUS
		"grass_patch":
			return DEFAULT_GRASS_RADIUS
	return DEFAULT_GRASS_RADIUS


func _draw() -> void:
	drawn_instance_count = 0
	visible_chunk_count = 0
	if not has_visible_world_rect:
		_draw_all_instances()
		return
	var visible_keys := _get_visible_chunk_keys(visible_world_rect)
	visible_chunk_count = visible_keys.size()
	for chunk_key in visible_keys:
		var chunk_items := Array(instances_by_chunk.get(chunk_key, []))
		for item in chunk_items:
			var position := Vector2(item.get("position", Vector2.ZERO))
			if not visible_world_rect.has_point(position):
				continue
			var kind := str(item.get("kind", "grass_patch"))
			var radius := float(item.get("radius", get_default_radius(kind)))
			var seed := int(item.get("seed", 0))
			_draw_vegetation_instance(kind, position, radius, seed)
			drawn_instance_count += 1


func _draw_all_instances() -> void:
	visible_chunk_count = instances_by_chunk.size()
	for item in instances:
		var kind := str(item.get("kind", "grass_patch"))
		var position := Vector2(item.get("position", Vector2.ZERO))
		var radius := float(item.get("radius", get_default_radius(kind)))
		var seed := int(item.get("seed", 0))
		_draw_vegetation_instance(kind, position, radius, seed)
		drawn_instance_count += 1


func _get_chunk_key(world_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_position.x / chunk_size),
		floori(world_position.y / chunk_size)
	)


func _get_chunk_range_for_rect(rect: Rect2) -> Dictionary:
	var start_key := _get_chunk_key(rect.position)
	var end_key := _get_chunk_key(rect.position + rect.size)
	return {
		"start": start_key,
		"end": end_key
	}


func _get_visible_chunk_keys(rect: Rect2) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var chunk_range := _get_chunk_range_for_rect(rect)
	var start_key := Vector2i(chunk_range.get("start", Vector2i.ZERO))
	var end_key := Vector2i(chunk_range.get("end", Vector2i.ZERO))
	for chunk_x in range(start_key.x, end_key.x + 1):
		for chunk_y in range(start_key.y, end_key.y + 1):
			var key := Vector2i(chunk_x, chunk_y)
			if instances_by_chunk.has(key):
				result.append(key)
	return result


func _get_visible_chunk_signature(rect: Rect2) -> String:
	var keys := _get_visible_chunk_keys(rect)
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.x == b.x:
			return a.y < b.y
		return a.x < b.x
	)
	var parts: Array[String] = []
	for key in keys:
		parts.append("%d:%d" % [key.x, key.y])
	return "|".join(parts)


func _draw_vegetation_instance(kind: String, position: Vector2, radius: float, seed: int) -> void:
	var color := _get_color_for_kind(kind, seed)
	var blade_count := 0
	var blade_length_factor := 1.0
	var blade_spread := 1.0
	var blade_thickness := 1.0
	match kind:
		"dense_grass":
			blade_count = 9
			blade_length_factor = 1.25
			blade_spread = 0.95
			blade_thickness = 1.8
		"grass_patch":
			blade_count = 6
			blade_length_factor = 1.0
			blade_spread = 0.82
			blade_thickness = 1.35
		_:
			blade_count = 5
			blade_length_factor = 0.88
			blade_spread = 0.75
			blade_thickness = 1.2
	_draw_grass_tuft(position, radius, color, seed, blade_count, blade_length_factor, blade_spread, blade_thickness)


func _get_color_for_kind(kind: String, seed: int) -> Color:
	var variation := float(abs(seed % 17)) / 17.0
	match kind:
		"dense_grass":
			return Color(0.13 + variation * 0.05, 0.42 + variation * 0.08, 0.12 + variation * 0.03, 0.64)
		"grass_patch":
			return Color(0.18 + variation * 0.05, 0.50 + variation * 0.08, 0.16 + variation * 0.02, 0.56)
	return Color(0.18, 0.48, 0.16, 0.50)


func _draw_grass_tuft(position: Vector2, radius: float, color: Color, seed: int, blade_count: int, blade_length_factor: float, blade_spread: float, blade_thickness: float) -> void:
	var tuft_radius := maxf(radius, 2.0)
	var base_angle := float(abs(seed % 360)) / 360.0 * TAU
	for i in range(blade_count):
		var blade_index := float(i)
		var count := float(max(blade_count, 1))
		var fan_strength := 0.45 + blade_spread * 0.7
		var angle_variation := sin(float(seed) * 0.013 + blade_index * 1.91) * 0.28
		var angle := base_angle + TAU * blade_index / count + angle_variation
		var center_offset := float(blade_index) - (count - 1.0) * 0.5
		var width_offset := center_offset * tuft_radius * 0.16 * fan_strength
		var height_noise := 0.72 + float(abs((seed + i * 13) % 11)) / 11.0 * 0.42
		var blade_length := tuft_radius * blade_length_factor * height_noise
		var bend := Vector2(cos(angle + 0.75), sin(angle + 0.75)) * tuft_radius * (0.25 + fan_strength * 0.1)
		var blade_base := position + Vector2(cos(angle), sin(angle)) * tuft_radius * 0.18 * blade_spread + Vector2(cos(base_angle + PI * 0.5), sin(base_angle + PI * 0.5)) * width_offset
		var blade_tip := blade_base + Vector2(0.0, -blade_length) + bend
		var edge_color := color.darkened(0.10 + float(i % 3) * 0.03)
		draw_line(blade_base, blade_tip, edge_color, blade_thickness)
		draw_line(blade_base + Vector2(blade_thickness * 0.18, 0.0), blade_tip + Vector2(blade_thickness * 0.05, 0.0), color.lightened(0.05), maxf(1.0, blade_thickness * 0.52))
		if i % 3 == 0:
			var side_tip := blade_base + Vector2(cos(angle - 0.7), sin(angle - 0.7)) * tuft_radius * (0.46 + blade_spread * 0.16)
			draw_line(blade_base, side_tip, color.darkened(0.14), maxf(1.0, blade_thickness * 0.44))
	draw_circle(position + Vector2(0.0, tuft_radius * 0.08), tuft_radius * 0.18, color.darkened(0.08))


func _make_seed(kind: String, world_position: Vector2) -> int:
	var hash_value := kind.hash()
	hash_value = int(hash_value + int(world_position.x * 17.0) + int(world_position.y * 31.0))
	return hash_value
