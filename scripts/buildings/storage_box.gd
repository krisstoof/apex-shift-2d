extends StaticBody2D

const Inventory := preload("res://scripts/player/inventory.gd")

var inventory := Inventory.new(12)


func _post_event_message(message: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var event_bus := tree.root.get_node_or_null("EventBus")
	if event_bus and event_bus.has_method("post_message"):
		event_bus.post_message(message)


func _ready() -> void:
	add_to_group("storage_boxes")
	print("[STORAGE_BOX_DEBUG] ready: ", name, " layer=", collision_layer, " mask=", collision_mask, " global_position=", global_position)
	queue_redraw()


func interact(player: Node) -> void:
	var hud := _get_hud()
	print("[STORAGE_BOX_DEBUG] interact called")
	print("[STORAGE_BOX_DEBUG] hud=", hud)
	print("[STORAGE_BOX_DEBUG] hud has open_storage_box=", hud != null and hud.has_method("open_storage_box"))
	if hud == null or not hud.has_method("open_storage_box"):
		_post_event_message("Storage Box UI not implemented yet")
		return
	hud.open_storage_box(player.inventory, inventory, self)
	_post_event_message("Storage Box opened")


func get_prompt() -> String:
	return "E: Open Storage Box"


func get_save_data() -> Dictionary:
	return {
		"inventory": inventory.to_save_data()
	}


func restore_from_data(data: Dictionary) -> void:
	inventory.load_from_save_data(Dictionary(data.get("inventory", {})))


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


func _draw() -> void:
	draw_rect(Rect2(-18, -14, 36, 28), Color(0.5, 0.28, 0.12), true)
	draw_rect(Rect2(-18, -14, 36, 28), Color(0.18, 0.1, 0.05), false, 2.0)
	draw_line(Vector2(-18, -2), Vector2(18, -2), Color(0.18, 0.1, 0.05), 2.0)
