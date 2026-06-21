extends StaticBody2D

const INVENTORY := preload("res://scripts/player/inventory.gd")
const STORAGE_STATE := preload("res://scripts/core/inventory/storage_state.gd")
const BUILDING_STATE := preload("res://scripts/core/buildings/building_state.gd")
const BUILDING_NODE_ADAPTER := preload("res://scripts/world/adapters/building_node_adapter.gd")

var storage_state := STORAGE_STATE.new(12, INVENTORY.new(12))
var inventory: Variant = storage_state.get_inventory_state()
var building_state := BUILDING_STATE.new()
var building_adapter: BuildingNodeAdapter


func _post_event_message(message: String) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	var event_bus := tree.root.get_node_or_null("EventBus")
	if event_bus and event_bus.has_method("post_message"):
		event_bus.post_message(message)


func _ready() -> void:
	_ensure_building_adapter()
	add_to_group("storage_boxes")
	_sync_state_from_node()
	queue_redraw()


func interact(player: Node) -> void:
	var hud := _get_hud()
	if hud == null or not hud.has_method("open_storage_box"):
		_post_event_message("Storage Box UI not implemented yet")
		return
	hud.open_storage_box(player.inventory, inventory, self)
	_post_event_message("Opened storage box")


func get_prompt() -> String:
	return "E: Open Storage Box"


func get_save_data() -> Dictionary:
	return _ensure_building_adapter().build_save_data({
		"position": _vector_to_data(global_position),
		"inventory": storage_state.get_inventory_save_data()
	})


func restore_from_data(data: Dictionary) -> void:
	if data.has("position"):
		global_position = _data_to_vector(Dictionary(data.get("position", {})), global_position)
	_ensure_building_adapter().restore_from_data(data)
	storage_state.load_from_save_data(data)
	inventory = storage_state.get_inventory_state()
	_sync_node_from_state()


func _vector_to_data(value: Vector2) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y
	}


func _data_to_vector(data: Dictionary, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if data.is_empty():
		return fallback
	return Vector2(
		float(data.get("x", fallback.x)),
		float(data.get("y", fallback.y))
	)


func _get_hud() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var hud := tree.root.get_node_or_null("HUD")
	if hud != null:
		return hud
	if tree.current_scene != null:
		return tree.current_scene.get_node_or_null("HUD")
	return null


func get_building_state() -> Dictionary:
	return get_save_data()


func apply_building_state(data: Dictionary) -> void:
	restore_from_data(data)


func _sync_state_from_node() -> void:
	building_adapter = _ensure_building_adapter()
	building_adapter.sync_state_from_node()
	building_state = building_adapter.state


func _sync_node_from_state() -> void:
	if building_state.position != Vector2.ZERO:
		global_position = building_state.position
	var data := Dictionary(building_state.custom_data)
	if data.has("inventory"):
		storage_state.load_from_save_data({"inventory": data.get("inventory")})
		inventory = storage_state.get_inventory_state()
	queue_redraw()


func _ensure_building_adapter() -> BuildingNodeAdapter:
	if building_adapter == null:
		building_adapter = BUILDING_NODE_ADAPTER.new()
		building_adapter.bind_building_node(self, "storage_box")
	return building_adapter


func _draw() -> void:
	draw_rect(Rect2(-18, -14, 36, 28), Color(0.5, 0.28, 0.12), true)
	draw_rect(Rect2(-18, -14, 36, 28), Color(0.18, 0.1, 0.05), false, 2.0)
	draw_line(Vector2(-18, -2), Vector2(18, -2), Color(0.18, 0.1, 0.05), 2.0)
