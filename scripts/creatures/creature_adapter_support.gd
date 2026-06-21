extends RefCounted
class_name CreatureAdapterSupport


static func get_debug_data(creature: Node, fallback: Dictionary = {}) -> Dictionary:
	if creature == null:
		return fallback
	var adapter := _get_adapter(creature)
	if adapter != null and adapter.has_method("get_debug_data"):
		return Dictionary(adapter.call("get_debug_data"))
	if creature.has_method("get_debug_data"):
		return Dictionary(creature.get_debug_data())
	return fallback


static func get_snapshot_summary(creature: Node, fallback: Dictionary = {}) -> Dictionary:
	if creature == null:
		return fallback
	var adapter := _get_adapter(creature)
	if adapter != null and adapter.has_method("get_snapshot_summary"):
		return Dictionary(adapter.call("get_snapshot_summary"))
	return fallback


static func _get_adapter(creature: Node) -> RefCounted:
	if creature == null or not creature.has_method("get"):
		return null
	var adapter_value: Variant = creature.get("creature_adapter")
	if adapter_value == null:
		return null
	return adapter_value as RefCounted
