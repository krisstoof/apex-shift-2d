extends RefCounted
class_name GodotVegetationSpawnAdapter

var world: Node
var decorative_visual_layer: Node
var spawn_resource_callback := Callable()


func bind(p_world: Node, p_decorative_visual_layer: Node, p_spawn_resource_callback: Callable) -> void:
	world = p_world
	decorative_visual_layer = p_decorative_visual_layer
	spawn_resource_callback = p_spawn_resource_callback


func apply_spawn_plan(spawn_plan: Array) -> Dictionary:
	var spawned := 0
	var decorative := 0
	var failed := 0
	for item_value in spawn_plan:
		var data: Dictionary = item_value.to_dictionary() if item_value.has_method("to_dictionary") else Dictionary(item_value)
		var kind := str(data.get("kind", ""))
		var position := Vector2(data.get("position", Vector2.ZERO))
		var biome_id := str(data.get("biome_id", ""))
		var visual_only := bool(data.get("visual_only", false))
		if visual_only:
			if _spawn_decorative(kind, position, biome_id):
				decorative += 1
				spawned += 1
			else:
				failed += 1
			continue
		if _spawn_interactive(kind, position):
			spawned += 1
		else:
			failed += 1
	return {"spawned": spawned, "decorative": decorative, "failed": failed}


func _spawn_decorative(kind: String, position: Vector2, biome_id: String) -> bool:
	if decorative_visual_layer == null or not is_instance_valid(decorative_visual_layer):
		return false
	if not decorative_visual_layer.has_method("add_instance"):
		return false
	decorative_visual_layer.add_instance(kind, position, -1.0, biome_id, 1.0)
	return true


func _spawn_interactive(kind: String, position: Vector2) -> bool:
	if not spawn_resource_callback.is_valid():
		return false
	var node = spawn_resource_callback.call(kind, position)
	return node != null
