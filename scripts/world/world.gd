extends Node2D

const RESOURCE_SCENE := preload("res://scenes/world/resource_node.tscn")
const VARNAK_SCENE := preload("res://scenes/creatures/varnak.tscn")
const SMALL_PREY_SCENE := preload("res://scenes/creatures/small_prey.tscn")
const GRAZER_SCENE := preload("res://scenes/creatures/grazer.tscn")
const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")

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
const PLANT_RESOURCE_KINDS := ["conifer_tree", "leafy_tree", "bush", "dry_bush"]
const CREATURE_BOUND_GROUPS := ["varnak", "small_prey", "grazer"]
const CREATURE_BOUND_TELEPORT_PADDING := 36.0

var evolution_director: Node
var day_night_system: Node
var ecosystem_director: Node
var resource_rng := RandomNumberGenerator.new()
var varnak_rng := RandomNumberGenerator.new()
var small_prey_rng := RandomNumberGenerator.new()
var grazer_rng := RandomNumberGenerator.new()
var small_prey_spawn_timer := 0.0
var landmarks: Array[Dictionary] = []

func _ready() -> void:
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
	return landmarks.duplicate(true)


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
	call_deferred("_sync_all_biome_vegetation")


func _spawn_resource_kind(resource_kind: String, count: int, used_positions: Array[Vector2], player_position: Vector2) -> void:
	for _i in count:
		if not _try_spawn_resource(resource_kind, used_positions, player_position):
			push_warning("Could not find a valid spawn position for %s" % resource_kind)


func _spawn_resource_at(resource_kind: String, pos: Vector2) -> Node:
	var node := RESOURCE_SCENE.instantiate()
	add_child(node)
	node.position = pos
	node.setup(resource_kind)
	return node


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
		var pos := _data_to_vector(data.get("position", {}))
		var resource := _spawn_resource_at(kind, pos)
		if resource.has_method("restore_from_data"):
			resource.restore_from_data(data)


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
	draw_rect(WORLD_CONFIG.WORLD_RECT, Color(0.14, 0.22, 0.13), true)
	for biome_value in WORLD_CONFIG.BIOME_ZONES:
		var biome := Dictionary(biome_value)
		var biome_points := PackedVector2Array(_get_biome_points(biome))
		draw_colored_polygon(biome_points, _get_biome_visual_color(biome))
		_draw_biome_outline(biome_points)
	_draw_landmarks()
	draw_rect(WORLD_CONFIG.WORLD_RECT, Color(0.07, 0.09, 0.07), false, 5.0)
	if day_night_system and day_night_system.night_amount > 0.0:
		draw_rect(WORLD_CONFIG.WORLD_RECT, Color(0.02, 0.03, 0.09, day_night_system.night_amount * 0.62), true)


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
	draw_arc(center, radius * 0.76, deg_to_rad(196.0), deg_to_rad(344.0), 28, ridge_color, 5.0)
	draw_arc(center + Vector2(radius * 0.10, -radius * 0.08), radius * 0.46, deg_to_rad(200.0), deg_to_rad(330.0), 24, ridge_color.darkened(0.15), 3.0)


func _draw_pond_landmark(landmark: Dictionary) -> void:
	var center := Vector2(landmark.get("position", Vector2.ZERO))
	var radius := float(landmark.get("radius", 100.0))
	_draw_filled_ellipse(Rect2(center - Vector2(radius, radius * 0.62), Vector2(radius * 2.0, radius * 1.24)), Color(0.08, 0.25, 0.33, 0.76))
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
