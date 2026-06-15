class_name IslandWorldValidator
extends RefCounted

const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const PLAYABLE_ZONES := ["land", "highland"]
const WATER_ZONES := ["deep_ocean", "shallow_water"]
const BLOCKED_CREATURE_SPAWN_ZONES := ["deep_ocean", "shallow_water", "shore"]
const PLANT_RESOURCE_KINDS := [
	"conifer_tree",
	"leafy_tree",
	"dry_tree",
	"bush",
	"dry_bush",
	"small_bush",
	"berry_bush",
	"grass_patch",
	"dense_grass"
]
const DEFAULT_TEST_SEEDS := [1, 2, 3, 4, 5, 13, 21, 34, 55, 89]
const EDGE_SAMPLE_STEPS := 64
const CENTER_GRID_STEPS := 12
const CENTER_SAMPLE_RADIUS := 0.32
const ZONE_SCAN_STEPS := 32
const MIN_EDGE_WATER_RATIO := 0.72
const RECOMMENDED_EDGE_WATER_RATIO := 0.84
const MIN_CENTER_PLAYABLE_RATIO := 0.58
const PLAYER_DEEP_OCEAN_ERROR_DISTANCE := 56.0
const PLAYER_DEEP_OCEAN_WARNING_DISTANCE := 120.0
const POND_DOMINANCE_WARNING_RATIO := 0.26
const POND_DOMINANCE_ERROR_RATIO := 0.38


func run(world: Node = null) -> Dictionary:
	var report := _new_report()
	if world == null:
		_collect_error(report, "World node is missing.")
		report["passed"] = false
		return report
	var world_rect: Rect2 = world.get_world_rect() if world.has_method("get_world_rect") else Rect2(Vector2.ZERO, Vector2.ZERO)
	if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		_collect_error(report, "World rect is invalid.")
		report["passed"] = false
		return report
	var landmarks: Array[Dictionary] = Array(world.get_landmarks()) if world.has_method("get_landmarks") else []
	var player_position := _get_player_position(world)
	_check_player_start(report, world, player_position, landmarks, world_rect)
	_check_edge_water(report, world_rect)
	_check_center_playable(report, world_rect)
	_check_water_rules(report, world)
	_check_registered_nodes(report, world)
	_check_pond_dominance(report, landmarks, world_rect)
	report["passed"] = Array(report["errors"]).is_empty()
	return report


func report_to_text(report: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("Island world validation")
	lines.append("Status: %s" % ("PASS" if bool(report.get("passed", false)) else "FAIL"))
	var stats: Dictionary = Dictionary(report.get("stats", {}))
	if not stats.is_empty():
		lines.append("Stats: %s" % _join_stats(stats))
	var checks: Dictionary = Dictionary(report.get("checks", {}))
	for key in checks.keys():
		lines.append("%s: %s" % [str(key), str(checks.get(key))])
	var warnings: Array = Array(report.get("warnings", []))
	for warning_value in warnings:
		lines.append("Warning: %s" % str(warning_value))
	var errors: Array = Array(report.get("errors", []))
	for error_value in errors:
		lines.append("Error: %s" % str(error_value))
	return "\n".join(lines)


func _new_report() -> Dictionary:
	return {
		"passed": false,
		"errors": [],
		"warnings": [],
		"stats": {},
		"checks": {}
	}


func _check_player_start(report: Dictionary, world: Node, player_position: Vector2, _landmarks: Array[Dictionary], world_rect: Rect2) -> void:
	if player_position == Vector2.INF:
		_collect_error(report, "Player start position could not be read.")
		return
	if not world_rect.has_point(player_position):
		_collect_error(report, "Player start is outside the world rect: %s" % _format_position(player_position))
	var zone := str(world.get_water_zone(player_position)) if world.has_method("get_water_zone") else "unknown"
	if PLAYABLE_ZONES.has(zone):
		report["checks"]["player_start_zone"] = "%s %s" % [zone, _format_position(player_position)]
	else:
		_collect_error(report, "Player start is not on playable terrain: %s (%s)" % [_format_position(player_position), zone])
	var distance_to_deep_ocean := _distance_to_zone(player_position, "deep_ocean", world_rect)
	if distance_to_deep_ocean <= PLAYER_DEEP_OCEAN_ERROR_DISTANCE:
		_collect_error(report, "Player start is too close to deep ocean: %.1f px" % distance_to_deep_ocean)
	elif distance_to_deep_ocean <= PLAYER_DEEP_OCEAN_WARNING_DISTANCE:
		_collect_warning(report, "Player start is close to deep ocean: %.1f px" % distance_to_deep_ocean)
	for test_seed in DEFAULT_TEST_SEEDS:
		var generated_landmarks := _generate_landmarks_for_seed(test_seed)
		var safe_start: Vector2 = WORLD_CONFIG.get_safe_player_start_position(generated_landmarks)
		if not world_rect.has_point(safe_start):
			_collect_error(report, "Seed %d safe start is outside the world rect: %s" % [test_seed, _format_position(safe_start)])
		elif not PLAYABLE_ZONES.has(str(world.get_water_zone(safe_start))):
			_collect_error(report, "Seed %d safe start is not on playable terrain: %s" % [test_seed, _format_position(safe_start)])


func _check_edge_water(report: Dictionary, world_rect: Rect2) -> void:
	var samples := 0
	var water_samples := 0
	for i in range(EDGE_SAMPLE_STEPS):
		var t := float(i) / float(max(EDGE_SAMPLE_STEPS - 1, 1))
		var positions := [
			Vector2(lerpf(world_rect.position.x, world_rect.end.x, t), world_rect.position.y),
			Vector2(lerpf(world_rect.position.x, world_rect.end.x, t), world_rect.end.y),
			Vector2(world_rect.position.x, lerpf(world_rect.position.y, world_rect.end.y, t)),
			Vector2(world_rect.end.x, lerpf(world_rect.position.y, world_rect.end.y, t))
		]
		for position in positions:
			samples += 1
			if WATER_ZONES.has(WORLD_CONFIG.get_terrain_zone(position)):
				water_samples += 1
	var ratio := float(water_samples) / float(max(samples, 1))
	report["checks"]["edge_water_ratio"] = "%.2f" % ratio
	if ratio < MIN_EDGE_WATER_RATIO:
		_collect_error(report, "Edge water ratio is too low: %.2f" % ratio)
	elif ratio < RECOMMENDED_EDGE_WATER_RATIO:
		_collect_warning(report, "Edge water ratio is below recommendation: %.2f" % ratio)


func _check_center_playable(report: Dictionary, world_rect: Rect2) -> void:
	var center := world_rect.get_center()
	var radius: float = min(world_rect.size.x, world_rect.size.y) * CENTER_SAMPLE_RADIUS
	var playable_samples := 0
	var samples := 0
	for y in range(CENTER_GRID_STEPS):
		for x in range(CENTER_GRID_STEPS):
			var sample := center + Vector2(
				lerpf(-radius, radius, float(x) / float(max(CENTER_GRID_STEPS - 1, 1))),
				lerpf(-radius, radius, float(y) / float(max(CENTER_GRID_STEPS - 1, 1)))
			)
			if not world_rect.has_point(sample):
				continue
			samples += 1
			if PLAYABLE_ZONES.has(WORLD_CONFIG.get_terrain_zone(sample)):
				playable_samples += 1
	var ratio := float(playable_samples) / float(max(samples, 1))
	report["checks"]["center_playable_ratio"] = "%.2f" % ratio
	if ratio < MIN_CENTER_PLAYABLE_RATIO:
		_collect_error(report, "Center playable ratio is too low: %.2f" % ratio)


func _check_water_rules(report: Dictionary, world: Node) -> void:
	var blocked_positions: Array[String] = []
	var resource_count := 0
	var blocked_resource_count := 0
	var invalid_resource_terrain_count := 0
	var invalid_rock_terrain_count := 0
	if world.has_method("get_registered_resources"):
		for resource_value in Array(world.get_registered_resources()):
			var resource := resource_value as Node2D
			if resource == null:
				continue
			resource_count += 1
			var resource_kind := str(resource.get("resource_kind"))
			var terrain_zone := str(world.get_terrain_zone(resource.global_position)) if world.has_method("get_terrain_zone") else "unknown"
			if terrain_zone != "land" and terrain_zone != "highland":
				invalid_resource_terrain_count += 1
				if resource_kind == "rock":
					invalid_rock_terrain_count += 1
			if _is_blocked_zone(world, resource.global_position):
				blocked_resource_count += 1
				blocked_positions.append("resource:%s@%s" % [str(resource.name), _format_position(resource.global_position)])
	var creature_count := 0
	var blocked_creature_count := 0
	if world.has_method("get_registered_creatures_by_type"):
		for creature_type in ["small_prey", "grazer", "varnak"]:
			for creature_value in Array(world.get_registered_creatures_by_type(creature_type)):
				var creature := creature_value as Node2D
				if creature == null:
					continue
				creature_count += 1
				if _is_blocked_zone(world, creature.global_position):
					blocked_creature_count += 1
					blocked_positions.append("creature:%s@%s" % [creature_type, _format_position(creature.global_position)])
	var building_count := 0
	var blocked_building_count := 0
	if world.has_method("get_registered_buildings_by_type"):
		for building_type in ["campfire", "trap"]:
			for building_value in Array(world.get_registered_buildings_by_type(building_type)):
				var building := building_value as Node2D
				if building == null:
					continue
				building_count += 1
				if _is_blocked_zone(world, building.global_position):
					blocked_building_count += 1
					blocked_positions.append("building:%s@%s" % [building_type, _format_position(building.global_position)])
	report["stats"]["resources"] = resource_count
	report["stats"]["creatures"] = creature_count
	report["stats"]["buildings"] = building_count
	report["checks"]["blocked_resources"] = blocked_resource_count
	report["checks"]["resource_invalid_terrain"] = invalid_resource_terrain_count
	report["checks"]["rock_invalid_terrain"] = invalid_rock_terrain_count
	report["checks"]["blocked_creatures"] = blocked_creature_count
	report["checks"]["blocked_buildings"] = blocked_building_count
	if blocked_positions.size() > 0:
		for entry in blocked_positions:
			_collect_error(report, "Blocked spawn found in water or shore zone: %s" % entry)


func _check_registered_nodes(report: Dictionary, world: Node) -> void:
	if world.has_method("get_registered_resources_by_kind"):
		for resource_kind in PLANT_RESOURCE_KINDS:
			var count := Array(world.get_registered_resources_by_kind(resource_kind)).size()
			report["stats"]["resource_kind_%s" % resource_kind] = count
	var blocked_water_nodes := 0
	var invalid_resource_nodes := 0
	if world.has_method("get_registered_resources"):
		for resource_value in Array(world.get_registered_resources()):
			var resource := resource_value as Node2D
			if resource == null:
				continue
			var resource_kind := str(resource.get("resource_kind"))
			var terrain_zone := str(world.get_terrain_zone(resource.global_position)) if world.has_method("get_terrain_zone") else "unknown"
			if terrain_zone != "land" and terrain_zone != "highland":
				invalid_resource_nodes += 1
			if world.has_method("is_resource_position_blocked_by_water") and bool(world.is_resource_position_blocked_by_water(resource_kind, resource.global_position)):
				blocked_water_nodes += 1
	if blocked_water_nodes > 0:
		_collect_error(report, "Registered resources violate water blocking rules: %d" % blocked_water_nodes)
	if invalid_resource_nodes > 0:
		_collect_error(report, "Registered resources are outside valid terrain: %d" % invalid_resource_nodes)
	report["checks"]["resource_water_blocked"] = blocked_water_nodes
	report["checks"]["resource_invalid_terrain_nodes"] = invalid_resource_nodes
	_check_water_rule_sampling(report, world)


func _check_pond_dominance(report: Dictionary, landmarks: Array[Dictionary], world_rect: Rect2) -> void:
	var pond_count := 0
	var hill_count := 0
	for landmark_value in landmarks:
		var landmark := Dictionary(landmark_value)
		match str(landmark.get("type", "")):
			"pond":
				pond_count += 1
			"hill":
				hill_count += 1
	report["checks"]["pond_count"] = pond_count
	report["checks"]["hill_count"] = hill_count
	var dominance_ratio := float(pond_count) / float(max(pond_count + hill_count, 1))
	report["checks"]["pond_dominance_ratio"] = "%.2f" % dominance_ratio
	if dominance_ratio >= POND_DOMINANCE_WARNING_RATIO:
		_collect_warning(report, "Pond landmarks are unusually frequent: %.2f" % dominance_ratio)
	var water_points := 0
	var pond_points := 0
	var total_points := 0
	for y in range(ZONE_SCAN_STEPS + 1):
		for x in range(ZONE_SCAN_STEPS + 1):
			var sample := world_rect.position + Vector2(
				world_rect.size.x * float(x) / float(max(ZONE_SCAN_STEPS, 1)),
				world_rect.size.y * float(y) / float(max(ZONE_SCAN_STEPS, 1))
			)
			total_points += 1
			if WATER_ZONES.has(WORLD_CONFIG.get_terrain_zone(sample)):
				water_points += 1
			if _is_inside_landmark(sample, landmarks, "pond"):
				pond_points += 1
	report["checks"]["map_water_ratio"] = "%.2f" % (float(water_points) / float(max(total_points, 1)))
	var pond_surface_ratio := float(pond_points) / float(max(total_points, 1))
	report["checks"]["pond_surface_ratio"] = "%.2f" % pond_surface_ratio
	if pond_surface_ratio >= POND_DOMINANCE_ERROR_RATIO:
		_collect_error(report, "Pond coverage dominates the map sample: %.2f" % pond_surface_ratio)
	elif pond_surface_ratio >= POND_DOMINANCE_WARNING_RATIO:
		_collect_warning(report, "Pond coverage is high in the map sample: %.2f" % pond_surface_ratio)


func _generate_landmarks_for_seed(test_seed: int) -> Array[Dictionary]:
	return Array(WORLD_CONFIG.generate_landmarks(test_seed))


func _get_player_position(world: Node) -> Vector2:
	if world.has_method("_get_player_position"):
		return Vector2(world.call("_get_player_position"))
	var player := world.get_node_or_null("Player")
	if player is Node2D:
		return (player as Node2D).global_position
	return Vector2.INF


func _is_blocked_zone(world: Node, world_position: Vector2) -> bool:
	if not world.has_method("get_water_zone"):
		return false
	return BLOCKED_CREATURE_SPAWN_ZONES.has(str(world.get_water_zone(world_position)))


func _check_water_rule_sampling(report: Dictionary, world: Node) -> void:
	var sample_points := _build_water_rule_sample_points()
	var blocked_spawn_hits := 0
	var blocked_navigation_hits := 0
	var blocked_resource_hits := 0
	var resource_kind := "conifer_tree"
	for sample in sample_points:
		if world.has_method("is_creature_spawn_blocked_by_water") and bool(world.is_creature_spawn_blocked_by_water(sample)):
			blocked_spawn_hits += 1
		if world.has_method("is_creature_navigation_blocked") and bool(world.is_creature_navigation_blocked(sample)):
			blocked_navigation_hits += 1
		if world.has_method("is_resource_position_blocked_by_water") and bool(world.is_resource_position_blocked_by_water(resource_kind, sample)):
			blocked_resource_hits += 1
	report["checks"]["sample_spawn_blocked"] = blocked_spawn_hits
	report["checks"]["sample_navigation_blocked"] = blocked_navigation_hits
	report["checks"]["sample_resource_blocked"] = blocked_resource_hits
	if blocked_spawn_hits == 0:
		_collect_error(report, "No sampled positions were blocked for creature spawn in deep/shallow/shore water.")
	if blocked_navigation_hits == 0:
		_collect_error(report, "No sampled positions were blocked for creature navigation in deep/shallow/shore water.")
	if blocked_resource_hits == 0:
		_collect_error(report, "No sampled positions were blocked for resource placement in deep/shallow/shore water.")


func _build_water_rule_sample_points() -> Array[Vector2]:
	var sample_points: Array[Vector2] = []
	var zones := ["deep_ocean", "shallow_water", "shore"]
	for zone in zones:
		var point := _find_sample_point_for_zone(zone)
		if point != Vector2.INF:
			sample_points.append(point)
	return sample_points


func _find_sample_point_for_zone(target_zone: String) -> Vector2:
	var world_rect := WORLD_CONFIG.WORLD_RECT
	for y in range(ZONE_SCAN_STEPS + 1):
		for x in range(ZONE_SCAN_STEPS + 1):
			var sample := world_rect.position + Vector2(
				world_rect.size.x * float(x) / float(max(ZONE_SCAN_STEPS, 1)),
				world_rect.size.y * float(y) / float(max(ZONE_SCAN_STEPS, 1))
			)
			if WORLD_CONFIG.get_terrain_zone(sample) == target_zone:
				return sample
	return Vector2.INF


func _is_inside_landmark(sample: Vector2, landmarks: Array[Dictionary], landmark_type: String) -> bool:
	for landmark_value in landmarks:
		var landmark := Dictionary(landmark_value)
		if str(landmark.get("type", "")) != landmark_type:
			continue
		var landmark_position := Vector2(landmark.get("position", Vector2.ZERO))
		var radius := float(landmark.get("radius", 0.0))
		if sample.distance_to(landmark_position) <= radius:
			return true
	return false


func _distance_to_zone(world_position: Vector2, target_zone: String, world_rect: Rect2) -> float:
	var nearest_distance := INF
	for y in range(ZONE_SCAN_STEPS + 1):
		for x in range(ZONE_SCAN_STEPS + 1):
			var sample := world_rect.position + Vector2(
				world_rect.size.x * float(x) / float(max(ZONE_SCAN_STEPS, 1)),
				world_rect.size.y * float(y) / float(max(ZONE_SCAN_STEPS, 1))
			)
			if WORLD_CONFIG.get_terrain_zone(sample) == target_zone:
				nearest_distance = min(nearest_distance, world_position.distance_to(sample))
	return nearest_distance


func _collect_error(report: Dictionary, message: String) -> void:
	var errors: Array = report.get("errors", [])
	errors.append(message)


func _collect_warning(report: Dictionary, message: String) -> void:
	var warnings: Array = report.get("warnings", [])
	warnings.append(message)


func _format_position(position: Vector2) -> String:
	return "(%.0f, %.0f)" % [position.x, position.y]


func _join_stats(stats: Dictionary) -> String:
	var parts: Array[String] = []
	for key in stats.keys():
		parts.append("%s=%s" % [str(key), str(stats.get(key))])
	return ", ".join(parts)
