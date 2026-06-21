extends RefCounted
class_name BuildingSystem

const BUILDING_STATE := preload("res://scripts/core/buildings/building_state.gd")

const DEFAULTS := {
	"campfire": {
		"active": true,
		"fear_radius": 260.0,
		"light_radius": 180.0,
		"stamina_regen_radius": 180.0
	},
	"trap": {
		"armed": true,
		"damage": 35.0
	},
	"wall": {
		"health": 80.0
	},
	"storage_box": {
		"inventory": {}
	},
	"tent": {
		"can_sleep": true
	}
}

static func create_state(building_kind: String, position: Vector2 = Vector2.ZERO, custom_data: Dictionary = {}) -> BuildingState:
	var state: BuildingState = BUILDING_STATE.new()
	state.kind = building_kind
	state.position = position
	state.custom_data = get_default_custom_data(building_kind)
	state.custom_data.merge(custom_data.duplicate(true), true)
	return state

static func load_state_from_data(data: Dictionary, fallback_kind := "") -> BuildingState:
	var state: BuildingState = BUILDING_STATE.new()
	state.kind = fallback_kind
	state.load_from_save_data(data)
	if state.kind.is_empty():
		state.kind = fallback_kind
	state.custom_data = get_default_custom_data(state.kind).merged(state.custom_data, true)
	return state

static func capture_node_state(node: Node, fallback_kind := "") -> BuildingState:
	var kind := resolve_building_kind(node, fallback_kind)
	var position := (node as Node2D).global_position if node is Node2D else Vector2.ZERO
	return create_state(kind, position, _capture_node_custom_data(node, kind))

static func apply_state_to_node(state: BuildingState, node: Node) -> void:
	if state == null or node == null:
		return
	if node is Node2D and state.position != Vector2.ZERO:
		(node as Node2D).global_position = state.position
	var data := get_default_custom_data(state.kind).merged(state.custom_data, true)
	match state.kind:
		"campfire":
			node.set("active", bool(data.get("active", true)))
			node.set("fear_radius", float(data.get("fear_radius", node.get("fear_radius"))))
			if node.get("light_radius") != null:
				node.set("light_radius", float(data.get("light_radius", node.get("light_radius"))))
			if node.get("stamina_regen_radius") != null:
				node.set("stamina_regen_radius", float(data.get("stamina_regen_radius", node.get("stamina_regen_radius"))))
		"trap":
			node.set("armed", bool(data.get("armed", true)))
			node.set("damage", float(data.get("damage", node.get("damage"))))
		"wall":
			node.set("health", float(data.get("health", node.get("health"))))
		"storage_box":
			var storage_state = node.get("storage_state")
			if storage_state != null and storage_state.has_method("load_from_save_data") and data.has("inventory"):
				storage_state.load_from_save_data({"inventory": data.get("inventory")})
				if storage_state.has_method("get_inventory_state"):
					node.set("inventory", storage_state.get_inventory_state())

static func get_default_custom_data(building_kind: String) -> Dictionary:
	return Dictionary(DEFAULTS.get(building_kind, {})).duplicate(true)

static func get_area_effect(state: BuildingState) -> Dictionary:
	if state == null:
		return {}
	match state.kind:
		"campfire":
			var data := get_default_custom_data("campfire").merged(state.custom_data, true)
			if not bool(data.get("active", true)):
				return {}
			return {
				"kind": "campfire",
				"active": true,
				"position": state.position,
				"fear_radius": float(data.get("fear_radius", 0.0)),
				"light_radius": float(data.get("light_radius", 0.0)),
				"stamina_regen_radius": float(data.get("stamina_regen_radius", 0.0))
			}
	return {}

static func is_position_inside_area_effect(state: BuildingState, position: Vector2, effect_key := "fear_radius") -> bool:
	var effect := get_area_effect(state)
	if effect.is_empty():
		return false
	var radius := float(effect.get(effect_key, 0.0))
	return radius > 0.0 and Vector2(effect.get("position", Vector2.ZERO)).distance_to(position) <= radius

static func trigger_trap(state: BuildingState) -> Dictionary:
	if state == null or state.kind != "trap":
		return {"triggered": false, "damage": 0.0}
	var data := get_default_custom_data("trap").merged(state.custom_data, true)
	if not bool(data.get("armed", true)):
		return {"triggered": false, "damage": 0.0}
	data["armed"] = false
	state.custom_data = data
	return {"triggered": true, "damage": float(data.get("damage", 0.0))}

static func apply_wall_damage(state: BuildingState, amount: float) -> Dictionary:
	if state == null or state.kind != "wall":
		return {"destroyed": false, "health": 0.0}
	var data := get_default_custom_data("wall").merged(state.custom_data, true)
	var health := float(data.get("health", 0.0)) - maxf(amount, 0.0)
	data["health"] = health
	state.custom_data = data
	return {"destroyed": health <= 0.0, "health": health}

static func get_storage_inventory_save_data(state: BuildingState) -> Dictionary:
	if state == null:
		return {}
	var data := Dictionary(state.custom_data)
	return Dictionary(data.get("inventory", {})).duplicate(true)

static func resolve_building_kind(node: Node, fallback_kind := "") -> String:
	if node == null:
		return fallback_kind
	var explicit_kind = node.get("building_kind")
	if explicit_kind != null and not str(explicit_kind).is_empty():
		return str(explicit_kind)
	for group_name in ["campfires", "traps", "walls", "storage_boxes", "tents"]:
		if node.is_in_group(group_name):
			match group_name:
				"campfires": return "campfire"
				"traps": return "trap"
				"walls": return "wall"
				"storage_boxes": return "storage_box"
				"tents": return "tent"
	return fallback_kind

static func _capture_node_custom_data(node: Node, building_kind: String) -> Dictionary:
	var data := get_default_custom_data(building_kind)
	match building_kind:
		"campfire":
			data["active"] = _get_bool(node, "active", true)
			data["fear_radius"] = _get_float(node, "fear_radius", float(data.get("fear_radius", 0.0)))
			data["light_radius"] = _get_float(node, "light_radius", float(data.get("light_radius", 0.0)))
			data["stamina_regen_radius"] = _get_float(node, "stamina_regen_radius", float(data.get("stamina_regen_radius", 0.0)))
		"trap":
			data["armed"] = _get_bool(node, "armed", true)
			data["damage"] = _get_float(node, "damage", float(data.get("damage", 0.0)))
		"wall":
			data["health"] = _get_float(node, "health", float(data.get("health", 0.0)))
		"storage_box":
			var storage_state = node.get("storage_state")
			if storage_state != null and storage_state.has_method("get_inventory_save_data"):
				data["inventory"] = storage_state.get_inventory_save_data()
		"tent":
			data["can_sleep"] = true
	return data

static func _get_bool(node: Node, property_name: String, fallback: bool) -> bool:
	var value = node.get(property_name)
	return fallback if value == null else bool(value)

static func _get_float(node: Node, property_name: String, fallback: float) -> float:
	var value = node.get(property_name)
	return fallback if value == null else float(value)
