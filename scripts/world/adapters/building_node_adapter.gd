extends RefCounted
class_name BuildingNodeAdapter

const BUILDING_STATE := preload("res://scripts/core/buildings/building_state.gd")
const BUILDING_SYSTEM := preload("res://scripts/core/buildings/building_system.gd")

var node: Node
var building_kind := ""
var state: BuildingState

func bind_building_node(p_node: Node, p_building_kind := "") -> void:
	node = p_node
	building_kind = BUILDING_SYSTEM.resolve_building_kind(node, p_building_kind)
	if building_kind.is_empty():
		building_kind = p_building_kind
	var existing_state = node.get("building_state") if node != null else null
	if existing_state != null and existing_state.has_method("to_save_data"):
		state = existing_state
	else:
		state = BUILDING_SYSTEM.create_state(building_kind, _get_node_position(), {})
	_push_state_reference_to_node()

func ensure_state() -> BuildingState:
	if state == null:
		state = BUILDING_SYSTEM.create_state(building_kind, _get_node_position(), {})
	_push_state_reference_to_node()
	return state

func sync_state_from_node() -> BuildingState:
	state = BUILDING_SYSTEM.capture_node_state(node, building_kind)
	_push_state_reference_to_node()
	return state

func sync_node_from_state() -> void:
	if node == null or state == null:
		return
	BUILDING_SYSTEM.apply_state_to_node(state, node)
	_push_state_reference_to_node()

func get_state_data() -> Dictionary:
	return sync_state_from_node().to_save_data()

func build_save_data(extra_data: Dictionary = {}) -> Dictionary:
	var data := get_state_data()
	for key in extra_data.keys():
		data[key] = extra_data[key]
	return data

func restore_from_data(data: Dictionary) -> BuildingState:
	state = BUILDING_SYSTEM.load_state_from_data(data, building_kind)
	if state.position == Vector2.ZERO and node is Node2D:
		state.position = (node as Node2D).global_position
	sync_node_from_state()
	return state

func get_area_effect() -> Dictionary:
	return BUILDING_SYSTEM.get_area_effect(sync_state_from_node())

func is_position_inside_area_effect(position: Vector2, effect_key := "fear_radius") -> bool:
	return BUILDING_SYSTEM.is_position_inside_area_effect(sync_state_from_node(), position, effect_key)

func trigger_trap() -> Dictionary:
	sync_state_from_node()
	var result := BUILDING_SYSTEM.trigger_trap(state)
	sync_node_from_state()
	return result

func apply_wall_damage(amount: float) -> Dictionary:
	sync_state_from_node()
	var result := BUILDING_SYSTEM.apply_wall_damage(state, amount)
	sync_node_from_state()
	return result

func get_storage_inventory_save_data() -> Dictionary:
	return BUILDING_SYSTEM.get_storage_inventory_save_data(sync_state_from_node())

func get_metadata() -> Dictionary:
	var current_state := sync_state_from_node()
	return {
		"building_kind": building_kind,
		"building_state": current_state.to_save_data(),
		"area_effect": BUILDING_SYSTEM.get_area_effect(current_state)
	}

func _get_node_position() -> Vector2:
	if node is Node2D:
		return (node as Node2D).global_position
	return Vector2.ZERO

func _push_state_reference_to_node() -> void:
	if node != null:
		node.set("building_state", state)
