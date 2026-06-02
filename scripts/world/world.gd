extends Node2D

const RESOURCE_SCENE := preload("res://scenes/world/resource_node.tscn")
const VARNAK_SCENE := preload("res://scenes/creatures/varnak.tscn")
const SMALL_PREY_SCENE := preload("res://scenes/creatures/small_prey.tscn")
const GRAZER_SCENE := preload("res://scenes/creatures/grazer.tscn")
const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")

const SMALL_PREY_SPAWN_TICK_SECONDS := 4.0
const SMALL_PREY_MAX_VISIBLE_COUNT := 12
const SMALL_PREY_MAX_VISIBLE_PER_BIOME := 5
const SMALL_PREY_VISIBLE_SPAWN_RADIUS := 850.0
const SMALL_PREY_PLAYER_SAFE_DISTANCE := 240.0
const SMALL_PREY_MIN_DISTANCE := 190.0
const INITIAL_GRAZER_VISIBLE_COUNT := 3
const GRAZER_VISIBLE_SPAWN_RADIUS := 1000.0
const GRAZER_PLAYER_SAFE_DISTANCE := 340.0
const GRAZER_MIN_DISTANCE := 300.0
const DEBUG_SMALL_PREY_VISIBLE_COUNT := 3
const DEBUG_GRAZER_VISIBLE_COUNT := 2
const DEBUG_SMALL_PREY_SPAWN_RADIUS := 180.0
const DEBUG_GRAZER_SPAWN_RADIUS := 240.0
const BIOME_DEPLETED_TINT := Color(0.42, 0.33, 0.18)
const BIOME_BLEND_TEXTURE_SIZE := Vector2i(192, 118)
const BIOME_BLEND_RADIUS := 420.0
const BIOME_NEIGHBOR_BLEND_WEIGHT := 0.90
const PLANT_RESOURCE_KINDS := [
	"conifer_tree",
	"leafy_tree",
	"bush",
	"dry_bush",
	"small_bush",
	"berry_bush",
	"grass_patch",
	"dense_grass"
]
const CREATURE_BOUND_GROUPS := ["varnak", "small_prey", "grazer"]
const CREATURE_BOUND_TELEPORT_PADDING := 36.0
const HILL_RESOURCE_BLOCK_RADIUS_FACTOR := 0.72
const POND_SPEED_MULTIPLIER := 0.42
const POND_VISUAL_Y_SCALE := 0.62
const POND_VEGETATION_MIN_COUNT := 18
const POND_VEGETATION_RING_MIN_FACTOR := 0.82
const POND_VEGETATION_RING_MAX_FACTOR := 1.35
const POND_VEGETATION_RING_JITTER := 0.16
const POND_VEGETATION_ANGLE_JITTER_FACTOR := 0.38

var evolution_director: Node
var day_night_system: Node
var ecosystem_director: Node
var resource_rng := RandomNumberGenerator.new()
var varnak_rng := RandomNumberGenerator.new()
var small_prey_rng := RandomNumberGenerator.new()
var grazer_rng := RandomNumberGenerator.new()
var small_prey_spawn_timer := 0.0
var landmarks: Array[Dictionary] = []
var hill_landmarks: Array[Dictionary] = []
var pond_landmarks: Array[Dictionary] = []
var biome_blend_texture: ImageTexture
var biome_blend_colors_key := ""

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	await get_tree().process_frame
	resource_rng.randomize()
	varnak_rng.randomize()
	small_prey_rng.randomize()
	grazer_rng.randomize()
	evolution_director = get_parent().get_node("EvolutionDirector")
	day_night_system = get_parent().get_node("DayNightSystem")
	ecosystem_director = get_parent().get_node("EcosystemDirector")
	evolution_director.profile_changed.connect(_on_profile_changed)
	get_node("/root/EventBus").game_event.connect(_on_game_event)
	_create_landmarks()
	_spawn_resources()
	_sync_visible_small_prey()
	_spawn_initial_grazers()
	_spawn_varnaks()
	queue_redraw()


func _process(delta: float) -> void:
	small_prey_spawn_timer += delta
	if small_prey_spawn_timer >= SMALL_PREY_SPAWN_TICK_SECONDS:
		small_prey_spawn_timer = 0.0
		_sync_visible_small_prey()
	queue_redraw()


func get_world_rect() -> Rect2:
	return WORLD_CONFIG.WORLD_RECT


func get_biome_zones() -> Array[Dictionary]:
	return WORLD_CONFIG.get_biome_zones()


func get_landmarks() -> Array[Dictionary]:
	if landmarks.is_empty():
		return WORLD_CONFIG.get_landmarks()
	return landmarks.duplicate(true)


func get_terrain_speed_multiplier(position: Vector2) -> float:
	for pond in pond_landmarks:
		if _is_position_in_pond_water(position, pond):
			return POND_SPEED_MULTIPLIER
	return 1.0


func is_position_in_water(position: Vector2) -> bool:
	for pond in pond_landmarks:
		if _is_position_in_pond_water(position, pond):
			return true
	return false


func is_resource_position_blocked_by_water(resource_kind: String, position: Vector2) -> bool:
	if not _is_plant_resource_kind(resource_kind):
		return false
	var margin_multiplier := _get_resource_water_margin_multiplier(resource_kind)
	for pond in pond_landmarks:
		if _is_position_in_pond_water(position, pond, margin_multiplier):
			return true
	return false


func is_creature_navigation_blocked(position: Vector2) -> bool:
	if is_position_in_water(position):
		return true
	for hill in hill_landmarks:
		if _is_position_in_hill_obstacle(position, hill):
			return true
	return false


func get_creatures_out_of_bounds_count() -> int:
	return _get_out_of_bounds_creatures().size()


func debug_teleport_out_of_bounds_creatures() -> void:
	var creatures := _get_out_of_bounds_creatures()
	for creature in creatures:
		if not is_instance_valid(creature):
			continue
		if creature.has_method("debug_return_to_world"):
			creature.debug_return_to_world()
		else:
			creature.global_position = _clamp_position_to_world(creature.global_position)
	if creatures.size() > 0:
		get_node("/root/EventBus").post_message("Teleported %d out-of-bounds creature%s" % [
			creatures.size(),
			"" if creatures.size() == 1 else "s"
		])
	else:
		get_node("/root/EventBus").post_message("No out-of-bounds creatures")


func _create_landmarks() -> void:
	landmarks = WORLD_CONFIG.get_landmarks()
	hill_landmarks.clear()
	pond_landmarks.clear()
	for landmark in landmarks:
		match str(landmark.get("type", "")):
			"hill":
				hill_landmarks.append(landmark)
				_create_landmark_area(landmark, "hill_landmarks")
			"pond":
				pond_landmarks.append(landmark)
				_create_landmark_area(landmark, "pond_landmarks")


func _create_landmark_area(landmark: Dictionary, group_name: String) -> void:
	var area := Area2D.new()
	area.name = str(landmark.get("id", "landmark"))
	area.global_position = Vector2(landmark.get("position", Vector2.ZERO))
	area.collision_layer = 0
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = false
	area.set_meta("landmark_id", str(landmark.get("id", "")))
	area.set_meta("landmark_type", str(landmark.get("type", "")))
	area.set_meta("biome_id", str(landmark.get("biome_id", "")))
	area.set_meta("gameplay_tags", landmark.get("gameplay_tags", []))
	if str(landmark.get("type", "")) == "pond":
		area.set_meta("terrain_speed_multiplier", POND_SPEED_MULTIPLIER)
	area.add_to_group("landmarks")
	area.add_to_group(group_name)
	if str(landmark.get("type", "")) == "pond":
		area.add_to_group("water_sources")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = float(landmark.get("radius", 120.0))
	shape.shape = circle
	area.add_child(shape)
	add_child(area)


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
	_spawn_resource_kind("small_bush", WORLD_CONFIG.SMALL_BUSH_COUNT, used_positions, player_position)
	_spawn_resource_kind("berry_bush", WORLD_CONFIG.BERRY_BUSH_COUNT, used_positions, player_position)
	_spawn_resource_kind("grass_patch", WORLD_CONFIG.GRASS_PATCH_COUNT, used_positions, player_position)
	_spawn_resource_kind("dense_grass", WORLD_CONFIG.DENSE_GRASS_COUNT, used_positions, player_position)
	_spawn_pond_vegetation(used_positions, player_position)
	call_deferred("_sync_all_biome_vegetation")


func _spawn_resource_kind(resource_kind: String, count: int, used_positions: Array[Vector2], player_position: Vector2) -> void:
	for _i in count:
		if not _try_spawn_resource(resource_kind, used_positions, player_position):
			push_warning("Could not find a valid spawn position for %s" % resource_kind)


func _spawn_pond_vegetation(used_positions: Array[Vector2], player_position: Vector2) -> void:
	for pond in pond_landmarks:
		var biome := _get_biome_for_id(str(pond.get("biome_id", "")))
		if biome.is_empty():
			continue
		var pond_kinds := [
			"dense_grass",
			"grass_patch",
			"dense_grass",
			"grass_patch",
			"small_bush",
			"dense_grass",
			"grass_patch",
			"berry_bush",
			"dense_grass",
			"grass_patch",
			"small_bush",
			"grass_patch"
		]
		var vegetation_count := _get_pond_vegetation_count()
		var angle_phase := resource_rng.randf_range(0.0, TAU)
		for i in vegetation_count:
			var kind := str(pond_kinds[i % pond_kinds.size()])
			_try_spawn_resource_near_pond(kind, pond, biome, used_positions, player_position, i, vegetation_count, angle_phase)


func _try_spawn_resource_near_pond(resource_kind: String, pond: Dictionary, biome: Dictionary, used_positions: Array[Vector2], player_position: Vector2, slot_index: int, slot_count: int, angle_phase: float) -> bool:
	var center := Vector2(pond.get("position", Vector2.ZERO))
	var radius := float(pond.get("radius", 100.0))
	var slot_angle: float = TAU / float(max(slot_count, 1))
	var base_angle: float = angle_phase + slot_angle * float(slot_index)
	var ring_factor := _get_pond_vegetation_ring_factor(slot_index, slot_count)
	var min_ring_factor: float = max(ring_factor - POND_VEGETATION_RING_JITTER, 1.12)
	var max_ring_factor: float = ring_factor + POND_VEGETATION_RING_JITTER
	for _attempt in WORLD_CONFIG.RESOURCE_SPAWN_ATTEMPTS:
		var angle: float = base_angle + resource_rng.randf_range(-slot_angle, slot_angle) * POND_VEGETATION_ANGLE_JITTER_FACTOR
		var distance := resource_rng.randf_range(radius * min_ring_factor, radius * max_ring_factor)
		var candidate := center + Vector2.RIGHT.rotated(angle) * distance
		if is_resource_position_blocked_by_water(resource_kind, candidate):
			continue
		if not _is_point_in_biome(candidate, biome):
			continue
		if _is_resource_blocked_by_hill(resource_kind, candidate):
			continue
		if not _is_valid_resource_position_with_min_distance(candidate, used_positions, player_position, _get_pond_vegetation_min_distance(), _get_pond_vegetation_player_safe_distance()):
			continue
		used_positions.append(candidate)
		var node := _spawn_resource_at(resource_kind, candidate)
		if node.has_method("set_pond_vegetation"):
			node.set_pond_vegetation(
				str(pond.get("id", "pond")),
				float(GAME_BALANCE.LANDMARKS.get("pond_grass_food_bonus", 1.0)),
				float(GAME_BALANCE.LANDMARKS.get("pond_vegetation_visual_scale", 1.0))
			)
		return true
	return false


func _get_pond_vegetation_count() -> int:
	var base_count := int(GAME_BALANCE.LANDMARKS.get("pond_vegetation_base_count", 6))
	var bonus := float(GAME_BALANCE.LANDMARKS.get("pond_vegetation_bonus", 1.0))
	return max(POND_VEGETATION_MIN_COUNT, int(round(float(base_count) * bonus)))


func _get_pond_vegetation_ring_factor(index: int, count: int) -> float:
	var inner_factor := float(GAME_BALANCE.LANDMARKS.get("pond_vegetation_inner_ring_factor", POND_VEGETATION_RING_MIN_FACTOR))
	var outer_factor := float(GAME_BALANCE.LANDMARKS.get("pond_vegetation_outer_ring_factor", POND_VEGETATION_RING_MAX_FACTOR))
	var band_index := (index * 5) % 4
	match band_index:
		0:
			return inner_factor
		1:
			return lerp(inner_factor, outer_factor, 0.34)
		2:
			return lerp(inner_factor, outer_factor, 0.68)
		_:
			return outer_factor


func _get_pond_vegetation_min_distance() -> float:
	return float(GAME_BALANCE.LANDMARKS.get("pond_vegetation_min_distance", 46.0))


func _get_pond_vegetation_player_safe_distance() -> float:
	return float(GAME_BALANCE.LANDMARKS.get("pond_vegetation_player_safe_distance", 36.0))


func _is_position_in_pond_water(position: Vector2, pond: Dictionary, margin_multiplier: float = 1.0) -> bool:
	var center := Vector2(pond.get("position", Vector2.ZERO))
	var radius := float(pond.get("radius", 0.0)) * margin_multiplier
	if radius <= 0.0:
		return false
	var offset := position - center
	var normalized := Vector2(offset.x / radius, offset.y / (radius * POND_VISUAL_Y_SCALE))
	return normalized.length_squared() <= 1.0


func _get_resource_water_margin_multiplier(resource_kind: String) -> float:
	match resource_kind:
		"conifer_tree", "leafy_tree", "tree":
			return float(GAME_BALANCE.LANDMARKS.get("pond_tree_water_margin", 1.22))
		"bush", "dry_bush", "small_bush", "berry_bush":
			return float(GAME_BALANCE.LANDMARKS.get("pond_bush_water_margin", 1.12))
		"grass_patch", "dense_grass":
			return float(GAME_BALANCE.LANDMARKS.get("pond_grass_water_margin", 1.04))
	return 1.0


func _is_position_in_hill_obstacle(position: Vector2, hill: Dictionary) -> bool:
	var center := Vector2(hill.get("position", Vector2.ZERO))
	var radius := float(hill.get("radius", 0.0)) * HILL_RESOURCE_BLOCK_RADIUS_FACTOR
	return radius > 0.0 and position.distance_to(center) <= radius


func _spawn_resource_at(resource_kind: String, pos: Vector2) -> Node:
	var node := RESOURCE_SCENE.instantiate()
	add_child(node)
	node.position = pos
	node.setup(resource_kind)
	return node


func spawn_meat_drop_for_animal(animal_kind: String, drop_position: Vector2) -> Node:
	var amount := _get_meat_drop_amount(animal_kind)
	if amount <= 0:
		return null
	var node := _spawn_resource_at("meat_drop", _clamp_position_to_world(drop_position))
	if node.has_method("set_loot_amount"):
		node.set_loot_amount(amount)
	get_node("/root/EventBus").emit_game_event("animal_dropped_meat", {
		"animal_kind": animal_kind,
		"amount": amount,
		"position": node.global_position
	})
	return node


func _get_meat_drop_amount(animal_kind: String) -> int:
	var loot: Dictionary = GAME_BALANCE.ANIMAL_LOOT.get(animal_kind, {})
	if loot.is_empty():
		return 0
	var min_amount := int(loot.get("meat_min", 0))
	var max_amount := int(loot.get("meat_max", min_amount))
	if max_amount < min_amount:
		max_amount = min_amount
	return resource_rng.randi_range(min_amount, max_amount)


func _try_spawn_resource(resource_kind: String, used_positions: Array[Vector2], player_position: Vector2) -> bool:
	for _attempt in WORLD_CONFIG.RESOURCE_SPAWN_ATTEMPTS:
		var biome := _pick_resource_biome(resource_kind)
		var spawn_area := _get_biome_bounds(biome).grow(-WORLD_CONFIG.RESOURCE_SPAWN_MARGIN)
		var candidate := Vector2(
			resource_rng.randf_range(spawn_area.position.x, spawn_area.end.x),
			resource_rng.randf_range(spawn_area.position.y, spawn_area.end.y)
		)
		if is_resource_position_blocked_by_water(resource_kind, candidate):
			continue
		if _is_resource_blocked_by_hill(resource_kind, candidate):
			continue
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
		"bush", "dry_bush", "small_bush", "berry_bush":
			return float(biome.get("bush_weight", 0.0))
		"grass_patch", "dense_grass":
			return float(biome.get("grass_weight", 0.0))
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


func _is_valid_resource_position(candidate: Vector2, used_positions: Array[Vector2], player_position: Vector2) -> bool:
	return _is_valid_resource_position_with_min_distance(candidate, used_positions, player_position, WORLD_CONFIG.RESOURCE_MIN_DISTANCE)


func _is_valid_resource_position_with_min_distance(candidate: Vector2, used_positions: Array[Vector2], player_position: Vector2, min_distance: float, player_safe_distance: float = WORLD_CONFIG.RESOURCE_PLAYER_SAFE_DISTANCE) -> bool:
	if candidate.distance_to(player_position) < player_safe_distance:
		return false
	for used_position in used_positions:
		if candidate.distance_to(used_position) < min_distance:
			return false
	return true


func _is_resource_blocked_by_hill(resource_kind: String, candidate: Vector2) -> bool:
	if not _is_plant_resource_kind(resource_kind):
		return false
	for hill in hill_landmarks:
		var center := Vector2(hill.get("position", Vector2.ZERO))
		var blocked_radius := float(hill.get("radius", 0.0)) * HILL_RESOURCE_BLOCK_RADIUS_FACTOR
		if candidate.distance_to(center) < blocked_radius:
			return true
	return false


func _is_plant_resource_kind(resource_kind: String) -> bool:
	return resource_kind in PLANT_RESOURCE_KINDS


func _get_player_position() -> Vector2:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		return player.global_position
	return Vector2.ZERO


func advance_resource_growth_days(days: float) -> void:
	var changed_count := 0
	for resource in get_tree().get_nodes_in_group("resources"):
		if not is_instance_valid(resource) or not resource.has_method("advance_growth_days"):
			continue
		if resource.advance_growth_days(days):
			changed_count += 1
	if changed_count > 0:
		get_node("/root/EventBus").post_message("%d resources advanced growth" % changed_count)


func debug_advance_resource_growth_day() -> void:
	advance_resource_growth_days(1.0)


func debug_force_full_vegetation_regrowth() -> void:
	var changed_count := 0
	for resource in get_tree().get_nodes_in_group("resources"):
		if not is_instance_valid(resource) or not resource.has_method("force_full_regrowth"):
			continue
		resource.force_full_regrowth()
		changed_count += 1
	get_node("/root/EventBus").post_message("Forced full regrowth on %d resources" % changed_count)


func debug_reset_resource_growth() -> void:
	var changed_count := 0
	for resource in get_tree().get_nodes_in_group("resources"):
		if not is_instance_valid(resource) or not resource.has_method("reset_growth_state"):
			continue
		resource.reset_growth_state()
		changed_count += 1
	get_node("/root/EventBus").post_message("Reset growth state on %d resources" % changed_count)


func get_resource_growth_debug_summary() -> Dictionary:
	var summary := {
		"depleted": 0,
		"sprout": 0,
		"young": 0,
		"mature": 0
	}
	for resource in get_tree().get_nodes_in_group("resources"):
		if not is_instance_valid(resource) or not resource.has_method("get_growth_debug_text"):
			continue
		var stage := int(resource.get("growth_stage"))
		match stage:
			0:
				summary["depleted"] += 1
			1:
				summary["sprout"] += 1
			2:
				summary["young"] += 1
			_:
				summary["mature"] += 1
	return summary


func get_resource_save_data() -> Array[Dictionary]:
	var resources: Array[Dictionary] = []
	for resource in get_tree().get_nodes_in_group("resources"):
		if not is_instance_valid(resource):
			continue
		if resource.has_method("get_save_data"):
			resources.append(resource.get_save_data())
		else:
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
		var data := Dictionary(resource_data)
		var kind := str(data.get("kind", "tree"))
		var pos := _get_safe_restored_resource_position(kind, _data_to_vector(data.get("position", {})))
		data["position"] = _vector_to_data(pos)
		data["biome_id"] = _get_biome_id_for_position(pos)
		var resource := _spawn_resource_at(kind, pos)
		if resource.has_method("restore_from_data"):
			resource.restore_from_data(data)


func _get_safe_restored_resource_position(resource_kind: String, requested_position: Vector2) -> Vector2:
	var position := _clamp_position_to_world(requested_position)
	if not is_resource_position_blocked_by_water(resource_kind, position) and not _is_resource_blocked_by_hill(resource_kind, position):
		return position
	var pond := _get_nearest_pond_landmark(position)
	if pond.is_empty():
		return position
	var center := Vector2(pond.get("position", Vector2.ZERO))
	var radius := float(pond.get("radius", 0.0))
	if radius <= 0.0:
		return position
	var direction := position - center
	var base_angle := direction.angle() if direction.length_squared() > 0.001 else 0.0
	var base_distance: float = radius * max(_get_resource_water_margin_multiplier(resource_kind) + 0.08, 1.16)
	var used_positions := _get_existing_resource_positions()
	var player_position := _get_player_position()
	for attempt in 48:
		var angle := base_angle + float(attempt) * 0.83
		var distance: float = base_distance + floor(float(attempt) / 8.0) * WORLD_CONFIG.RESOURCE_MIN_DISTANCE
		var candidate := _clamp_position_to_world(center + Vector2.RIGHT.rotated(angle) * distance)
		if is_resource_position_blocked_by_water(resource_kind, candidate):
			continue
		if _is_resource_blocked_by_hill(resource_kind, candidate):
			continue
		if _get_biome_for_position(candidate).is_empty():
			continue
		if _is_valid_resource_position(candidate, used_positions, player_position):
			return candidate
	for attempt in 48:
		var angle := base_angle - float(attempt) * 0.83
		var distance: float = base_distance + floor(float(attempt) / 8.0) * WORLD_CONFIG.RESOURCE_MIN_DISTANCE
		var candidate := _clamp_position_to_world(center + Vector2.RIGHT.rotated(angle) * distance)
		if not is_resource_position_blocked_by_water(resource_kind, candidate) and not _is_resource_blocked_by_hill(resource_kind, candidate) and not _get_biome_for_position(candidate).is_empty():
			return candidate
	return position


func _get_nearest_pond_landmark(position: Vector2) -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_distance := INF
	for pond in pond_landmarks:
		var center := Vector2(pond.get("position", Vector2.ZERO))
		var distance := position.distance_squared_to(center)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = pond
	return nearest


func _sync_visible_small_prey() -> void:
	if not ecosystem_director or not ecosystem_director.has_method("get_biome_state"):
		return
	var player_position := _get_player_position()
	var player_biome := _get_biome_for_position(player_position)
	if player_biome.is_empty():
		return
	var biome_id := _get_biome_id(player_biome)
	var biome_state: Dictionary = ecosystem_director.get_biome_state(biome_id)
	if biome_state.is_empty():
		return
	var desired_count := _get_desired_small_prey_count(player_biome, biome_state)
	var current_biome_count := _get_visible_small_prey_count(biome_id)
	var global_count := get_tree().get_nodes_in_group("small_prey").size()
	var spawn_budget: int = min(desired_count - current_biome_count, SMALL_PREY_MAX_VISIBLE_COUNT - global_count)
	if spawn_budget <= 0:
		return
	var spawned := 0
	var used_positions := _get_existing_small_prey_positions()
	for _i in spawn_budget:
		if _try_spawn_small_prey_near_player(player_biome, player_position, used_positions):
			spawned += 1
	if spawned > 0:
		get_node("/root/EventBus").post_message("%d SmallPrey entered the ecosystem" % spawned)


func _get_desired_small_prey_count(biome: Dictionary, biome_state: Dictionary) -> int:
	var population := float(biome_state.get("small_prey_population", 0.0))
	var biomass_percent := float(biome_state.get("plant_biomass_percent", 0.0))
	var population_factor: float = clamp(population / 12.0, 0.0, 1.0)
	var biomass_factor: float = clamp(biomass_percent / 100.0, 0.0, 1.0)
	var danger_factor := 0.45 if biome.get("dangerous", false) == true else 1.0
	var desired := int(round(float(SMALL_PREY_MAX_VISIBLE_PER_BIOME) * population_factor * biomass_factor * danger_factor))
	if population > 0.0 and biomass_percent >= 30.0:
		desired = max(desired, 1)
	return clamp(desired, 0, SMALL_PREY_MAX_VISIBLE_PER_BIOME)


func _get_visible_small_prey_count(biome_id: String) -> int:
	var count := 0
	for small_prey in get_tree().get_nodes_in_group("small_prey"):
		if not is_instance_valid(small_prey):
			continue
		if _get_biome_id_for_position(small_prey.global_position) == biome_id:
			count += 1
	return count


func _get_existing_small_prey_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for small_prey in get_tree().get_nodes_in_group("small_prey"):
		if is_instance_valid(small_prey):
			positions.append(small_prey.global_position)
	return positions


func _try_spawn_small_prey_near_player(biome: Dictionary, player_position: Vector2, used_positions: Array[Vector2]) -> bool:
	for _attempt in WORLD_CONFIG.RESOURCE_SPAWN_ATTEMPTS:
		var offset := Vector2.RIGHT.rotated(small_prey_rng.randf_range(0.0, TAU)) * small_prey_rng.randf_range(SMALL_PREY_PLAYER_SAFE_DISTANCE, SMALL_PREY_VISIBLE_SPAWN_RADIUS)
		var candidate := player_position + offset
		if candidate.distance_to(player_position) < SMALL_PREY_PLAYER_SAFE_DISTANCE:
			continue
		if not _is_point_in_biome(candidate, biome):
			continue
		if not _is_valid_small_prey_position(candidate, used_positions):
			continue
		used_positions.append(candidate)
		_spawn_small_prey_at(candidate, _get_biome_id(biome))
		return true
	return false


func _is_valid_small_prey_position(candidate: Vector2, used_positions: Array[Vector2]) -> bool:
	for used_position in used_positions:
		if candidate.distance_to(used_position) < SMALL_PREY_MIN_DISTANCE:
			return false
	return true


func _get_biome_for_position(position: Vector2) -> Dictionary:
	for biome in WORLD_CONFIG.get_biome_zones():
		if Geometry2D.is_point_in_polygon(position, PackedVector2Array(biome["points"])):
			return biome
	return {}


func _get_biome_id(biome: Dictionary) -> String:
	return str(biome.get("name", "biome")).to_snake_case()


func _get_biome_id_for_position(position: Vector2) -> String:
	var biome := _get_biome_for_position(position)
	if biome.is_empty():
		return ""
	return _get_biome_id(biome)


func _sync_all_biome_vegetation() -> void:
	for biome in WORLD_CONFIG.get_biome_zones():
		_sync_biome_vegetation(_get_biome_id(biome))


func _sync_biome_vegetation(biome_id: String) -> void:
	var biome := _get_biome_for_id(biome_id)
	if biome.is_empty():
		return
	var used_positions := _get_existing_resource_positions()
	var changed := false
	for resource_kind in PLANT_RESOURCE_KINDS:
		var kind := str(resource_kind)
		var target_count := _get_biome_resource_target_count(biome, kind)
		var current_resources := _get_plant_resources_in_biome(biome_id, kind)
		var current_count := current_resources.size()
		if current_count < target_count:
			for _i in target_count - current_count:
				if _try_spawn_resource_in_biome(kind, biome, used_positions, _get_player_position()):
					changed = true
	if changed:
		queue_redraw()


func _get_biome_for_id(biome_id: String) -> Dictionary:
	for biome in WORLD_CONFIG.get_biome_zones():
		if _get_biome_id(biome) == biome_id:
			return biome
	return {}


func _get_biome_resource_target_count(biome: Dictionary, resource_kind: String) -> int:
	var base_count := _get_base_resource_count(resource_kind)
	if base_count <= 0:
		return 0
	var total_weight := 0.0
	for biome_value in WORLD_CONFIG.get_biome_zones():
		total_weight += _get_biome_resource_weight(Dictionary(biome_value), resource_kind)
	if total_weight <= 0.0:
		return 0
	var biome_id := _get_biome_id(biome)
	var weight := _get_biome_resource_weight(biome, resource_kind)
	var full_biomass_count := int(round(float(base_count) * weight / total_weight))
	var biomass_factor := _get_biome_biomass_factor(biome_id)
	return int(round(float(full_biomass_count) * biomass_factor))


func _get_base_resource_count(resource_kind: String) -> int:
	match resource_kind:
		"conifer_tree":
			return int(ceil(float(WORLD_CONFIG.TREE_COUNT) * 0.6))
		"leafy_tree":
			return WORLD_CONFIG.TREE_COUNT - int(ceil(float(WORLD_CONFIG.TREE_COUNT) * 0.6))
		"bush":
			return WORLD_CONFIG.BUSH_COUNT - int(ceil(float(WORLD_CONFIG.BUSH_COUNT) * 0.35))
		"dry_bush":
			return int(ceil(float(WORLD_CONFIG.BUSH_COUNT) * 0.35))
		"small_bush":
			return WORLD_CONFIG.SMALL_BUSH_COUNT
		"berry_bush":
			return WORLD_CONFIG.BERRY_BUSH_COUNT
		"grass_patch":
			return WORLD_CONFIG.GRASS_PATCH_COUNT
		"dense_grass":
			return WORLD_CONFIG.DENSE_GRASS_COUNT
	return 0


func _get_biome_biomass_factor(biome_id: String) -> float:
	if not ecosystem_director or not ecosystem_director.has_method("get_biome_state"):
		return 1.0
	var biome_state: Dictionary = ecosystem_director.get_biome_state(biome_id)
	if biome_state.is_empty():
		return 1.0
	return clamp(float(biome_state.get("plant_biomass_percent", 100.0)) / 100.0, 0.0, 1.0)


func _get_plant_resources_in_biome(biome_id: String, resource_kind: String) -> Array[Node2D]:
	var resources: Array[Node2D] = []
	for resource in get_tree().get_nodes_in_group("resources"):
		if not is_instance_valid(resource) or resource.is_queued_for_deletion():
			continue
		if str(resource.get("resource_kind")) != resource_kind:
			continue
		if _get_biome_id_for_position(resource.global_position) == biome_id:
			resources.append(resource)
	return resources


func _get_existing_resource_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for resource in get_tree().get_nodes_in_group("resources"):
		if is_instance_valid(resource) and not resource.is_queued_for_deletion():
			positions.append(resource.global_position)
	return positions


func _remove_plant_resources(resources: Array[Node2D], count: int) -> void:
	var player_position := _get_player_position()
	resources.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(player_position) < b.global_position.distance_squared_to(player_position)
	)
	var removed := 0
	for resource in resources:
		if removed >= count:
			break
		if not is_instance_valid(resource):
			continue
		resource.queue_free()
		removed += 1


func _try_spawn_resource_in_biome(resource_kind: String, biome: Dictionary, used_positions: Array[Vector2], player_position: Vector2) -> bool:
	var spawn_area := _get_scaled_biome_bounds(biome).grow(-WORLD_CONFIG.RESOURCE_SPAWN_MARGIN)
	for _attempt in WORLD_CONFIG.RESOURCE_SPAWN_ATTEMPTS:
		var candidate := Vector2(
			resource_rng.randf_range(spawn_area.position.x, spawn_area.end.x),
			resource_rng.randf_range(spawn_area.position.y, spawn_area.end.y)
		)
		if is_resource_position_blocked_by_water(resource_kind, candidate):
			continue
		if _is_resource_blocked_by_hill(resource_kind, candidate):
			continue
		if _is_point_in_scaled_biome(candidate, biome) and _is_valid_resource_position(candidate, used_positions, player_position):
			used_positions.append(candidate)
			_spawn_resource_at(resource_kind, candidate)
			return true
	return false


func _get_scaled_biome_bounds(biome: Dictionary) -> Rect2:
	var points := PackedVector2Array(biome["points"])
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


func _is_point_in_scaled_biome(point: Vector2, biome: Dictionary) -> bool:
	return Geometry2D.is_point_in_polygon(point, PackedVector2Array(biome["points"]))


func _spawn_small_prey_at(pos: Vector2, biome_id: String) -> Node:
	var small_prey := SMALL_PREY_SCENE.instantiate()
	add_child(small_prey)
	small_prey.global_position = pos
	if small_prey.has_method("setup"):
		small_prey.setup(biome_id)
	return small_prey


func _spawn_initial_grazers() -> void:
	var player_position := _get_player_position()
	var player_biome := _get_biome_for_position(player_position)
	if player_biome.is_empty():
		return
	var spawned := 0
	var used_positions := _get_existing_grazer_positions()
	for _i in INITIAL_GRAZER_VISIBLE_COUNT:
		if _try_spawn_grazer_near_player(player_biome, player_position, used_positions):
			spawned += 1
	if spawned > 0:
		get_node("/root/EventBus").post_message("%d Grazer%s entered the ecosystem" % [spawned, "" if spawned == 1 else "s"])


func _try_spawn_grazer_near_player(biome: Dictionary, player_position: Vector2, used_positions: Array[Vector2]) -> bool:
	for _attempt in WORLD_CONFIG.RESOURCE_SPAWN_ATTEMPTS:
		var offset := Vector2.RIGHT.rotated(grazer_rng.randf_range(0.0, TAU)) * grazer_rng.randf_range(GRAZER_PLAYER_SAFE_DISTANCE, GRAZER_VISIBLE_SPAWN_RADIUS)
		var candidate := player_position + offset
		if not _is_point_in_biome(candidate, biome):
			continue
		if not _is_valid_grazer_position(candidate, used_positions):
			continue
		used_positions.append(candidate)
		_spawn_grazer_at(candidate, _get_biome_id(biome))
		return true
	return false


func _get_existing_grazer_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for grazer in get_tree().get_nodes_in_group("grazer"):
		if is_instance_valid(grazer):
			positions.append(grazer.global_position)
	return positions


func _is_valid_grazer_position(candidate: Vector2, used_positions: Array[Vector2]) -> bool:
	for used_position in used_positions:
		if candidate.distance_to(used_position) < GRAZER_MIN_DISTANCE:
			return false
	return true


func _spawn_grazer_at(pos: Vector2, biome_id: String) -> Node:
	var grazer := GRAZER_SCENE.instantiate()
	add_child(grazer)
	grazer.global_position = pos
	if grazer.has_method("setup"):
		grazer.setup(biome_id)
	return grazer


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


func debug_spawn_animal(aggressive: bool) -> void:
	var spawn_position := _get_debug_animal_spawn_position()
	var varnak := _spawn_varnak_at(spawn_position)
	if aggressive:
		varnak.apply_profile(_get_debug_aggressive_profile())
		get_node("/root/EventBus").post_message("Debug spawned aggressive animal")
	else:
		varnak.apply_profile(_get_debug_neutral_profile())
		get_node("/root/EventBus").post_message("Debug spawned neutral animal")


func debug_spawn_small_prey_near_player() -> void:
	var biome := _get_biome_for_position(_get_player_position())
	if biome.is_empty():
		return
	var biome_id := _get_biome_id(biome)
	var spawned := 0
	for i in DEBUG_SMALL_PREY_VISIBLE_COUNT:
		var spawn_position := _get_debug_creature_spawn_position(biome, DEBUG_SMALL_PREY_SPAWN_RADIUS, i, DEBUG_SMALL_PREY_VISIBLE_COUNT)
		_spawn_small_prey_at(spawn_position, biome_id)
		spawned += 1
	if spawned > 0:
		get_node("/root/EventBus").post_message("Debug spawned %d SmallPrey" % spawned)


func debug_remove_small_prey_near_player() -> void:
	var removed := _debug_remove_nearest_creatures("small_prey", DEBUG_SMALL_PREY_VISIBLE_COUNT)
	if removed > 0:
		get_node("/root/EventBus").post_message("Debug removed %d SmallPrey" % removed)


func debug_spawn_grazers_near_player() -> void:
	var biome := _get_biome_for_position(_get_player_position())
	if biome.is_empty():
		return
	var biome_id := _get_biome_id(biome)
	var spawned := 0
	for i in DEBUG_GRAZER_VISIBLE_COUNT:
		var spawn_position := _get_debug_creature_spawn_position(biome, DEBUG_GRAZER_SPAWN_RADIUS, i, DEBUG_GRAZER_VISIBLE_COUNT)
		_spawn_grazer_at(spawn_position, biome_id)
		spawned += 1
	if spawned > 0:
		get_node("/root/EventBus").post_message("Debug spawned %d Grazers" % spawned)


func debug_remove_grazers_near_player() -> void:
	var removed := _debug_remove_nearest_creatures("grazer", DEBUG_GRAZER_VISIBLE_COUNT)
	if removed > 0:
		get_node("/root/EventBus").post_message("Debug removed %d Grazers" % removed)


func _get_out_of_bounds_creatures() -> Array[Node2D]:
	var creatures: Array[Node2D] = []
	for group_name in CREATURE_BOUND_GROUPS:
		for node in get_tree().get_nodes_in_group(group_name):
			var creature := node as Node2D
			if not is_instance_valid(creature):
				continue
			if not WORLD_CONFIG.WORLD_RECT.has_point(creature.global_position):
				creatures.append(creature)
	return creatures


func _clamp_position_to_world(position: Vector2) -> Vector2:
	var rect := WORLD_CONFIG.WORLD_RECT.grow(-CREATURE_BOUND_TELEPORT_PADDING)
	return Vector2(
		clamp(position.x, rect.position.x, rect.end.x),
		clamp(position.y, rect.position.y, rect.end.y)
	)


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


func _spawn_varnak_at(pos: Vector2) -> Node:
	var varnak := VARNAK_SCENE.instantiate()
	add_child(varnak)
	varnak.global_position = pos
	varnak.apply_profile(evolution_director.get_profile())
	varnak.day_night_system = day_night_system
	return varnak


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


func _get_debug_animal_spawn_position() -> Vector2:
	var player_position := _get_player_position()
	var offset := Vector2(180.0, 0.0)
	var candidate := player_position + offset
	var player_limits := WORLD_CONFIG.get_player_limits()
	candidate.x = clamp(candidate.x, -player_limits.x, player_limits.x)
	candidate.y = clamp(candidate.y, -player_limits.y, player_limits.y)
	return candidate


func _get_debug_creature_spawn_position(biome: Dictionary, radius: float, index: int, total: int) -> Vector2:
	var player_position := _get_player_position()
	var player_limits := WORLD_CONFIG.get_player_limits()
	for attempt in 12:
		var angle := TAU * float(index + attempt) / float(max(total, 1)) + float(attempt) * 0.35
		var candidate := player_position + Vector2.RIGHT.rotated(angle) * (radius + float(attempt) * 18.0)
		candidate.x = clamp(candidate.x, -player_limits.x, player_limits.x)
		candidate.y = clamp(candidate.y, -player_limits.y, player_limits.y)
		if _is_point_in_biome(candidate, biome):
			return candidate
	return player_position


func _debug_remove_nearest_creatures(group_name: String, count: int) -> int:
	var player_position := _get_player_position()
	var nodes := get_tree().get_nodes_in_group(group_name)
	nodes.sort_custom(func(a: Node, b: Node) -> bool:
		if not is_instance_valid(a):
			return false
		if not is_instance_valid(b):
			return true
		return a.global_position.distance_squared_to(player_position) < b.global_position.distance_squared_to(player_position)
	)
	var removed := 0
	for creature in nodes:
		if removed >= count:
			break
		if not is_instance_valid(creature):
			continue
		creature.queue_free()
		removed += 1
	return removed


func _get_debug_aggressive_profile() -> Dictionary:
	var profile: Dictionary = evolution_director.get_profile()
	profile["aggression"] = 1.0
	profile["base_curiosity"] = 0.8
	profile["night_activity"] = 0.8
	return profile


func _get_debug_neutral_profile() -> Dictionary:
	var profile: Dictionary = evolution_director.get_profile()
	profile["aggression"] = 0.0
	profile["base_curiosity"] = 0.0
	profile["night_activity"] = 0.0
	profile["pack_coordination"] = 0.0
	profile["stalk_tendency"] = 0.0
	return profile


func _scale_world_point(point: Vector2) -> Vector2:
	return WORLD_CONFIG.scale_world_point(point)


func _get_varnak_spawn_weight(point: Vector2) -> float:
	return 4.0 if _is_point_in_dangerous_biome(point) else 1.0


func _is_point_in_dangerous_biome(point: Vector2) -> bool:
	for biome_value in WORLD_CONFIG.BIOME_ZONES:
		var biome := Dictionary(biome_value)
		if biome.get("dangerous", false) == true and _is_point_in_biome(point, biome):
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
	elif event_name == "day_ended":
		call_deferred("advance_resource_growth_days", 1.0)
		if _payload.get("reason", "") == "slept_in_tent":
			call_deferred("respawn_missing_varnaks")
	elif event_name == "ecosystem_vegetation_changed":
		var biome_id := str(_payload.get("biome_id", ""))
		if not biome_id.is_empty():
			call_deferred("_sync_biome_vegetation", biome_id)


func _vector_to_data(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


func _data_to_vector(data: Variant) -> Vector2:
	if typeof(data) != TYPE_DICTIONARY:
		return Vector2.ZERO
	return Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))


func _draw() -> void:
	_draw_biome_blend_texture()
	_draw_landmarks()
	draw_rect(WORLD_CONFIG.WORLD_RECT, Color(0.07, 0.09, 0.07), false, 5.0)
	if day_night_system and day_night_system.night_amount > 0.0:
		draw_rect(WORLD_CONFIG.WORLD_RECT, Color(0.02, 0.03, 0.09, day_night_system.night_amount * 0.62), true)


func _draw_biome_blend_texture() -> void:
	_ensure_biome_blend_texture()
	if biome_blend_texture:
		draw_texture_rect(biome_blend_texture, WORLD_CONFIG.WORLD_RECT, false)


func _ensure_biome_blend_texture() -> void:
	var current_key := _get_biome_colors_key()
	if biome_blend_texture and biome_blend_colors_key == current_key:
		return
	var image := Image.create(BIOME_BLEND_TEXTURE_SIZE.x, BIOME_BLEND_TEXTURE_SIZE.y, false, Image.FORMAT_RGBA8)
	var biome_zones := WORLD_CONFIG.get_biome_zones()
	var colors: Array[Color] = []
	for biome in biome_zones:
		colors.append(Color(biome["color"]))
	for y in range(BIOME_BLEND_TEXTURE_SIZE.y):
		for x in range(BIOME_BLEND_TEXTURE_SIZE.x):
			var uv := Vector2(
				(float(x) + 0.5) / float(BIOME_BLEND_TEXTURE_SIZE.x),
				(float(y) + 0.5) / float(BIOME_BLEND_TEXTURE_SIZE.y)
			)
			var world_position := WORLD_CONFIG.WORLD_RECT.position + uv * WORLD_CONFIG.WORLD_RECT.size
			image.set_pixel(x, y, _get_blended_biome_color_at(world_position, biome_zones, colors, BIOME_BLEND_RADIUS))
	biome_blend_texture = ImageTexture.create_from_image(image)
	biome_blend_colors_key = current_key


func _get_blended_biome_color_at(position: Vector2, biome_zones: Array[Dictionary], colors: Array[Color], blend_radius: float) -> Color:
	var containing_index := -1
	var containing_edge_distance := INF
	var edge_distances: Array[float] = []
	for i in biome_zones.size():
		var points := PackedVector2Array(biome_zones[i]["points"])
		var edge_distance := _get_point_polygon_edge_distance(position, points)
		edge_distances.append(edge_distance)
		if containing_index == -1 and Geometry2D.is_point_in_polygon(position, points):
			containing_index = i
			containing_edge_distance = edge_distance
	if containing_index == -1:
		return _get_nearest_biome_color(edge_distances, colors)
	var result := colors[containing_index]
	var total_weight := 1.0
	if containing_edge_distance >= blend_radius:
		return result
	for i in biome_zones.size():
		if i == containing_index:
			continue
		var shared_edge_distance: float = max(containing_edge_distance, edge_distances[i])
		if shared_edge_distance > blend_radius:
			continue
		var neighbor_weight: float = pow(1.0 - shared_edge_distance / blend_radius, 2.0) * BIOME_NEIGHBOR_BLEND_WEIGHT
		result += colors[i] * neighbor_weight
		total_weight += neighbor_weight
	return result / total_weight


func _get_nearest_biome_color(edge_distances: Array[float], colors: Array[Color]) -> Color:
	var nearest_index := 0
	var nearest_distance := INF
	for i in edge_distances.size():
		if edge_distances[i] < nearest_distance:
			nearest_index = i
			nearest_distance = edge_distances[i]
	return colors[nearest_index]


func _get_point_polygon_edge_distance(point: Vector2, points: PackedVector2Array) -> float:
	var nearest_distance := INF
	for i in points.size():
		var start := points[i]
		var end := points[(i + 1) % points.size()]
		nearest_distance = min(nearest_distance, _get_distance_to_segment(point, start, end))
	return nearest_distance


func _get_distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var t: float = clamp((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)


func _get_biome_colors_key() -> String:
	var parts: Array[String] = []
	for biome in WORLD_CONFIG.get_biome_zones():
		var color := Color(biome["color"])
		parts.append("%.3f:%.3f:%.3f" % [color.r, color.g, color.b])
	return "|".join(parts)


func _get_biome_visual_color(biome: Dictionary) -> Color:
	var base_color := Color(biome["color"])
	if not ecosystem_director or not ecosystem_director.has_method("get_biome_state"):
		return base_color
	var biome_state: Dictionary = ecosystem_director.get_biome_state(_get_biome_id(biome))
	if biome_state.is_empty():
		return base_color
	var biomass_percent: float = clamp(float(biome_state.get("plant_biomass_percent", 100.0)), 0.0, 100.0)
	var stress := 1.0 - biomass_percent / 100.0
	return base_color.lerp(BIOME_DEPLETED_TINT, stress * 0.75).darkened(stress * 0.18)


func _draw_landmarks() -> void:
	for landmark in landmarks:
		match str(landmark.get("type", "")):
			"hill":
				_draw_hill_landmark(landmark)
			"pond":
				_draw_pond_landmark(landmark)


func _draw_hill_landmark(landmark: Dictionary) -> void:
	var center := Vector2(landmark.get("position", Vector2.ZERO))
	var radius := float(landmark.get("radius", 120.0))
	var base_color := Color(0.28, 0.31, 0.20, 0.72)
	var ridge_color := Color(0.43, 0.43, 0.29, 0.58)
	_draw_filled_ellipse(Rect2(center - Vector2(radius, radius * 0.55), Vector2(radius * 2.0, radius * 1.1)), base_color)
	_draw_filled_ellipse(Rect2(center - Vector2(radius * 0.62, radius * 0.34), Vector2(radius * 1.24, radius * 0.68)), Color(0.35, 0.37, 0.24, 0.38))
	draw_arc(center, radius * 0.76, deg_to_rad(196.0), deg_to_rad(344.0), 28, ridge_color, 5.0)
	draw_arc(center + Vector2(radius * 0.10, -radius * 0.08), radius * 0.46, deg_to_rad(200.0), deg_to_rad(330.0), 24, ridge_color.darkened(0.15), 3.0)
	draw_line(center + Vector2(-radius * 0.44, radius * 0.12), center + Vector2(radius * 0.38, -radius * 0.10), Color(0.18, 0.20, 0.13, 0.28), 3.0)


func _draw_pond_landmark(landmark: Dictionary) -> void:
	var center := Vector2(landmark.get("position", Vector2.ZERO))
	var radius := float(landmark.get("radius", 100.0))
	_draw_filled_ellipse(Rect2(center - Vector2(radius, radius * POND_VISUAL_Y_SCALE), Vector2(radius * 2.0, radius * POND_VISUAL_Y_SCALE * 2.0)), Color(0.08, 0.25, 0.33, 0.76))
	_draw_filled_ellipse(Rect2(center - Vector2(radius * 0.72, radius * 0.40), Vector2(radius * 1.44, radius * 0.80)), Color(0.12, 0.39, 0.47, 0.52))
	draw_arc(center, radius * 0.78, deg_to_rad(12.0), deg_to_rad(168.0), 28, Color(0.52, 0.78, 0.75, 0.34), 4.0)


func _draw_filled_ellipse(rect: Rect2, ellipse_color: Color) -> void:
	var points := PackedVector2Array()
	var center := rect.get_center()
	var radii := rect.size * 0.5
	for i in range(32):
		var angle := TAU * float(i) / 32.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, ellipse_color)
