extends RefCounted
class_name CreatureContext

var position := Vector2.ZERO
var current_biome := ""
var home_biome := ""
var return_position := Vector2.ZERO
var is_inside_home_biome := true

var current_behavior := "wander"
var hunger_ratio := 0.0
var hunger_stage := ""
var energy := 1.0
var state_time := 0.0
var target_lock_time := 0.0
var eat_cooldown := 0.0
var should_rest := false

var has_player_threat := false
var player_threat_position := Vector2.ZERO
var player_threat_entity_id := 0

var has_predator_threat := false
var predator_threat_position := Vector2.ZERO
var predator_threat_entity_id := 0
var predator_threat_kind := ""

var has_fire_threat := false
var fire_threat_position := Vector2.ZERO
var fire_threat_entity_id := 0

var has_building_hazard := false
var building_hazard_kind := ""
var building_hazard_position := Vector2.ZERO
var building_hazard_entity_id := 0

var has_water_hazard := false
var water_avoid_position := Vector2.ZERO

var has_food_target := false
var food_position := Vector2.ZERO
var food_entity_id := 0
var food_kind := ""
var food_in_eat_range := false

var has_meat_target := false
var meat_position := Vector2.ZERO
var meat_entity_id := 0
var meat_in_eat_range := false

var has_prey_target := false
var prey_position := Vector2.ZERO
var prey_entity_id := 0
var prey_kind := ""
var prey_in_attack_range := false

var metadata: Dictionary = {}


func set_player_threat(threat_position: Vector2, entity_id: int = 0) -> void:
	has_player_threat = true
	player_threat_position = threat_position
	player_threat_entity_id = entity_id


func set_predator_threat(threat_position: Vector2, entity_id: int = 0, kind: String = "predator") -> void:
	has_predator_threat = true
	predator_threat_position = threat_position
	predator_threat_entity_id = entity_id
	predator_threat_kind = kind


func set_fire_threat(threat_position: Vector2, entity_id: int = 0) -> void:
	has_fire_threat = true
	fire_threat_position = threat_position
	fire_threat_entity_id = entity_id


func set_building_hazard(kind: String, hazard_position: Vector2, entity_id: int = 0) -> void:
	has_building_hazard = true
	building_hazard_kind = kind
	building_hazard_position = hazard_position
	building_hazard_entity_id = entity_id


func set_water_hazard(avoid_position: Vector2) -> void:
	has_water_hazard = true
	water_avoid_position = avoid_position


func set_food_target(kind: String, target_position: Vector2, entity_id: int = 0, in_eat_range: bool = false) -> void:
	has_food_target = true
	food_kind = kind
	food_position = target_position
	food_entity_id = entity_id
	food_in_eat_range = in_eat_range


func set_meat_target(target_position: Vector2, entity_id: int = 0, in_eat_range: bool = false) -> void:
	has_meat_target = true
	meat_position = target_position
	meat_entity_id = entity_id
	meat_in_eat_range = in_eat_range
	set_food_target("meat", target_position, entity_id, in_eat_range)


func set_prey_target(kind: String, target_position: Vector2, entity_id: int = 0, in_attack_range: bool = false) -> void:
	has_prey_target = true
	prey_kind = kind
	prey_position = target_position
	prey_entity_id = entity_id
	prey_in_attack_range = in_attack_range


func has_any_threat() -> bool:
	return has_player_threat or has_predator_threat


func get_primary_threat_position() -> Vector2:
	if has_predator_threat:
		return predator_threat_position
	if has_player_threat:
		return player_threat_position
	if has_fire_threat:
		return fire_threat_position
	return Vector2.INF


func get_primary_threat_entity_id() -> int:
	if has_predator_threat:
		return predator_threat_entity_id
	if has_player_threat:
		return player_threat_entity_id
	if has_fire_threat:
		return fire_threat_entity_id
	return 0


func get_primary_threat_kind() -> String:
	if has_predator_threat:
		return predator_threat_kind
	if has_player_threat:
		return "player"
	if has_fire_threat:
		return "campfire"
	return ""


func is_hungry() -> bool:
	return hunger_stage == "hungry" or hunger_stage == "starving" or hunger_stage == "desperate" or hunger_ratio >= 0.35


func is_starving() -> bool:
	return hunger_stage == "starving" or hunger_stage == "desperate" or hunger_ratio >= 0.60


func duplicate_context() -> CreatureContext:
	var copy := CreatureContext.new()
	copy.load_from_dictionary(to_dictionary())
	return copy


func to_dictionary() -> Dictionary:
	return {
		"position": _vector_to_data(position),
		"current_biome": current_biome,
		"home_biome": home_biome,
		"return_position": _vector_to_data(return_position),
		"is_inside_home_biome": is_inside_home_biome,
		"current_behavior": current_behavior,
		"hunger_ratio": hunger_ratio,
		"hunger_stage": hunger_stage,
		"energy": energy,
		"state_time": state_time,
		"target_lock_time": target_lock_time,
		"eat_cooldown": eat_cooldown,
		"should_rest": should_rest,
		"has_player_threat": has_player_threat,
		"player_threat_position": _vector_to_data(player_threat_position),
		"player_threat_entity_id": player_threat_entity_id,
		"has_predator_threat": has_predator_threat,
		"predator_threat_position": _vector_to_data(predator_threat_position),
		"predator_threat_entity_id": predator_threat_entity_id,
		"predator_threat_kind": predator_threat_kind,
		"has_fire_threat": has_fire_threat,
		"fire_threat_position": _vector_to_data(fire_threat_position),
		"fire_threat_entity_id": fire_threat_entity_id,
		"has_building_hazard": has_building_hazard,
		"building_hazard_kind": building_hazard_kind,
		"building_hazard_position": _vector_to_data(building_hazard_position),
		"building_hazard_entity_id": building_hazard_entity_id,
		"has_water_hazard": has_water_hazard,
		"water_avoid_position": _vector_to_data(water_avoid_position),
		"has_food_target": has_food_target,
		"food_position": _vector_to_data(food_position),
		"food_entity_id": food_entity_id,
		"food_kind": food_kind,
		"food_in_eat_range": food_in_eat_range,
		"has_meat_target": has_meat_target,
		"meat_position": _vector_to_data(meat_position),
		"meat_entity_id": meat_entity_id,
		"meat_in_eat_range": meat_in_eat_range,
		"has_prey_target": has_prey_target,
		"prey_position": _vector_to_data(prey_position),
		"prey_entity_id": prey_entity_id,
		"prey_kind": prey_kind,
		"prey_in_attack_range": prey_in_attack_range,
		"metadata": metadata.duplicate(true)
	}


func load_from_dictionary(data: Dictionary) -> void:
	position = _data_to_vector(data.get("position", _vector_to_data(position)), position)
	current_biome = str(data.get("current_biome", current_biome))
	home_biome = str(data.get("home_biome", home_biome))
	return_position = _data_to_vector(data.get("return_position", _vector_to_data(return_position)), return_position)
	is_inside_home_biome = bool(data.get("is_inside_home_biome", is_inside_home_biome))
	current_behavior = str(data.get("current_behavior", current_behavior))
	hunger_ratio = float(data.get("hunger_ratio", hunger_ratio))
	hunger_stage = str(data.get("hunger_stage", hunger_stage))
	energy = float(data.get("energy", energy))
	state_time = float(data.get("state_time", state_time))
	target_lock_time = float(data.get("target_lock_time", target_lock_time))
	eat_cooldown = float(data.get("eat_cooldown", eat_cooldown))
	should_rest = bool(data.get("should_rest", should_rest))
	has_player_threat = bool(data.get("has_player_threat", has_player_threat))
	player_threat_position = _data_to_vector(data.get("player_threat_position", _vector_to_data(player_threat_position)), player_threat_position)
	player_threat_entity_id = int(data.get("player_threat_entity_id", player_threat_entity_id))
	has_predator_threat = bool(data.get("has_predator_threat", has_predator_threat))
	predator_threat_position = _data_to_vector(data.get("predator_threat_position", _vector_to_data(predator_threat_position)), predator_threat_position)
	predator_threat_entity_id = int(data.get("predator_threat_entity_id", predator_threat_entity_id))
	predator_threat_kind = str(data.get("predator_threat_kind", predator_threat_kind))
	has_fire_threat = bool(data.get("has_fire_threat", has_fire_threat))
	fire_threat_position = _data_to_vector(data.get("fire_threat_position", _vector_to_data(fire_threat_position)), fire_threat_position)
	fire_threat_entity_id = int(data.get("fire_threat_entity_id", fire_threat_entity_id))
	has_building_hazard = bool(data.get("has_building_hazard", has_building_hazard))
	building_hazard_kind = str(data.get("building_hazard_kind", building_hazard_kind))
	building_hazard_position = _data_to_vector(data.get("building_hazard_position", _vector_to_data(building_hazard_position)), building_hazard_position)
	building_hazard_entity_id = int(data.get("building_hazard_entity_id", building_hazard_entity_id))
	has_water_hazard = bool(data.get("has_water_hazard", has_water_hazard))
	water_avoid_position = _data_to_vector(data.get("water_avoid_position", _vector_to_data(water_avoid_position)), water_avoid_position)
	has_food_target = bool(data.get("has_food_target", has_food_target))
	food_position = _data_to_vector(data.get("food_position", _vector_to_data(food_position)), food_position)
	food_entity_id = int(data.get("food_entity_id", food_entity_id))
	food_kind = str(data.get("food_kind", food_kind))
	food_in_eat_range = bool(data.get("food_in_eat_range", food_in_eat_range))
	has_meat_target = bool(data.get("has_meat_target", has_meat_target))
	meat_position = _data_to_vector(data.get("meat_position", _vector_to_data(meat_position)), meat_position)
	meat_entity_id = int(data.get("meat_entity_id", meat_entity_id))
	meat_in_eat_range = bool(data.get("meat_in_eat_range", meat_in_eat_range))
	has_prey_target = bool(data.get("has_prey_target", has_prey_target))
	prey_position = _data_to_vector(data.get("prey_position", _vector_to_data(prey_position)), prey_position)
	prey_entity_id = int(data.get("prey_entity_id", prey_entity_id))
	prey_kind = str(data.get("prey_kind", prey_kind))
	prey_in_attack_range = bool(data.get("prey_in_attack_range", prey_in_attack_range))
	metadata = Dictionary(data.get("metadata", metadata)).duplicate(true)


static func from_dictionary(data: Dictionary) -> CreatureContext:
	var context := CreatureContext.new()
	context.load_from_dictionary(data)
	return context


static func _vector_to_data(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


static func _data_to_vector(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if typeof(value) != TYPE_DICTIONARY:
		return fallback
	var data := Dictionary(value)
	return Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y)))
