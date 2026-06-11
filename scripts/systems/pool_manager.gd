extends Node
class_name PoolManager

const OBJECT_POOL_SCRIPT := preload("res://scripts/systems/object_pool.gd")

var pools: Dictionary = {}


func configure_pool(pool_key: String, max_size: int) -> void:
	var pool := _get_or_create_pool(pool_key)
	pool.configure(pool_key, max_size)


func acquire(pool_key: String, scene: PackedScene, parent: Node, data: Dictionary = {}) -> Node:
	var pool := _get_or_create_pool(pool_key)
	return pool.acquire(scene, parent, data)


func release(pool_key: String, node: Node) -> bool:
	if not pools.has(pool_key):
		node.queue_free()
		return false
	var pool: ObjectPool = pools[pool_key]
	return pool.release(node)


func get_debug_snapshot() -> Dictionary:
	var snapshot := {}
	for pool_key in pools.keys():
		var pool: ObjectPool = pools[pool_key]
		snapshot[pool_key] = pool.get_debug_data()
	return snapshot


func get_debug_text() -> String:
	if pools.is_empty():
		return "no pools"
	var parts: Array[String] = []
	for pool_key in pools.keys():
		var data := Dictionary(pools[pool_key].get_debug_data())
		parts.append("%s inactive %d/%d created %d reused %d returned %d discarded %d" % [
			str(pool_key),
			int(data.get("inactive", 0)),
			int(data.get("max_size", 0)),
			int(data.get("created", 0)),
			int(data.get("reused", 0)),
			int(data.get("returned", 0)),
			int(data.get("discarded", 0))
		])
	return " | ".join(parts)


func _get_or_create_pool(pool_key: String) -> ObjectPool:
	if pools.has(pool_key):
		return pools[pool_key]
	var pool: ObjectPool = OBJECT_POOL_SCRIPT.new()
	pool.configure(pool_key, 32)
	pools[pool_key] = pool
	return pool
