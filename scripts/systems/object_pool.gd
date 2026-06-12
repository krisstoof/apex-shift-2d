extends RefCounted
class_name ObjectPool

var key := ""
var max_size := 32
var inactive_nodes: Array[Node] = []

var created_count := 0
var reused_count := 0
var returned_count := 0
var discarded_count := 0
var acquire_count := 0


func configure(pool_key: String, pool_max_size: int) -> ObjectPool:
	key = pool_key
	max_size = max(pool_max_size, 0)
	return self


func acquire(scene: PackedScene, parent: Node, data: Dictionary = {}) -> Node:
	acquire_count += 1

	var node: Node = null
	while not inactive_nodes.is_empty() and node == null:
		var candidate := inactive_nodes.pop_back() as Node
		if is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			node = candidate

	if node == null:
		if scene == null:
			return null
		node = scene.instantiate()
		created_count += 1
		if parent != null:
			parent.add_child(node)
	else:
		reused_count += 1
		if parent != null and node.get_parent() == null:
			parent.add_child(node)

	data["pool_key"] = key

	if node.has_method("activate_from_pool"):
		node.activate_from_pool(data)
	else:
		_apply_default_activate(node)

	return node


func release(node: Node) -> bool:
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return false

	if max_size <= 0 or inactive_nodes.size() >= max_size:
		discarded_count += 1
		node.queue_free()
		return false

	if node.has_method("reset_for_pool"):
		node.reset_for_pool()
	else:
		_apply_default_reset(node)

	inactive_nodes.append(node)
	returned_count += 1
	return true


func get_debug_data() -> Dictionary:
	return {
		"key": key,
		"max_size": max_size,
		"inactive": inactive_nodes.size(),
		"created": created_count,
		"reused": reused_count,
		"returned": returned_count,
		"discarded": discarded_count,
		"acquire_count": acquire_count
	}


func _apply_default_activate(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).visible = true
	node.set_process(true)
	node.set_physics_process(true)


func _apply_default_reset(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	node.set_process(false)
	node.set_physics_process(false)
