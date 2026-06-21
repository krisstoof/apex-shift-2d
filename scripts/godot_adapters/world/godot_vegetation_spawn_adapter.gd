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
	var applied_by_biome_and_kind: Dictionary = {}
	var failed_by_biome_and_kind: Dictionary = {}
	for item_value in spawn_plan:
		var data: Dictionary = item_value.to_dictionary() if item_value.has_method("to_dictionary") else Dictionary(item_value)
		var kind := str(data.get("kind", ""))
		var position := Vector2(data.get("position", Vector2.ZERO))
		var biome_id := str(data.get("biome_id", ""))
		var visual_only := bool(data.get("visual_only", false))
		if visual_only and not _is_decorative_kind(kind):
			push_warning("Non-decorative resource kind rendered as decorative visual: %s" % kind)
			visual_only = false
		if visual_only:
			if _spawn_decorative(kind, position, biome_id):
				decorative += 1
				spawned += 1
				_record_spawn_source(kind, biome_id)
				_count_biome_kind(applied_by_biome_and_kind, biome_id, kind)
			else:
				failed += 1
				_count_biome_kind(failed_by_biome_and_kind, biome_id, kind)
			continue
		if _spawn_interactive(kind, position):
			spawned += 1
			_record_spawn_source(kind, biome_id)
			_count_biome_kind(applied_by_biome_and_kind, biome_id, kind)
		else:
			failed += 1
			_count_biome_kind(failed_by_biome_and_kind, biome_id, kind)
	return {
		"spawned": spawned,
		"decorative": decorative,
		"failed": failed,
		"applied_by_biome_and_kind": applied_by_biome_and_kind,
		"failed_by_biome_and_kind": failed_by_biome_and_kind
	}


func _spawn_decorative(kind: String, position: Vector2, biome_id: String) -> bool:
	if decorative_visual_layer == null or not is_instance_valid(decorative_visual_layer):
		return false
	if not decorative_visual_layer.has_method("add_instance"):
		return false
	decorative_visual_layer.add_instance(kind, position, -1.0, biome_id, 1.0)
	return true


func _is_decorative_kind(kind: String) -> bool:
	return kind in ["grass_patch", "dense_grass", "reed", "cattail", "water_lily", "pond_grass", "wetland_grass"]


func _spawn_interactive(kind: String, position: Vector2) -> bool:
	if not spawn_resource_callback.is_valid():
		return false
	var node = spawn_resource_callback.call(kind, position)
	return node != null


func _record_spawn_source(kind: String, biome_id: String) -> void:
	if world != null and is_instance_valid(world) and world.has_method("_record_resource_spawn_source"):
		world.call("_record_resource_spawn_source", kind, biome_id, "core_plan")


func _count_biome_kind(container: Dictionary, biome_id: String, kind: String) -> void:
	if biome_id.is_empty() or kind.is_empty():
		return
	var biome_counts := Dictionary(container.get(biome_id, {}))
	biome_counts[kind] = int(biome_counts.get(kind, 0)) + 1
	container[biome_id] = biome_counts
