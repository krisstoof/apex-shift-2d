extends RefCounted
class_name ResourceService


func advance_growth_days(resources: Array, days: float) -> int:
	var changed_count := 0
	for resource_value in resources:
		if not is_instance_valid(resource_value) or not resource_value.has_method("advance_growth_days"):
			continue
		if resource_value.advance_growth_days(days):
			changed_count += 1
	return changed_count


func build_save_data(resources: Array) -> Array[Dictionary]:
	var save_data: Array[Dictionary] = []
	for resource_value in resources:
		if not is_instance_valid(resource_value) or not resource_value.has_method("get_save_data"):
			continue
		var data: Variant = resource_value.get_save_data()
		if typeof(data) != TYPE_DICTIONARY:
			continue
		save_data.append(Dictionary(data).duplicate(true))
	return save_data


func normalize_restore_data(resource_data: Array) -> Array[Dictionary]:
	var normalized_data: Array[Dictionary] = []
	for resource_value in resource_data:
		if typeof(resource_value) != TYPE_DICTIONARY:
			continue
		var data := Dictionary(resource_value).duplicate(true)
		data["resource_kind"] = str(data.get("resource_kind", data.get("kind", "")))
		if typeof(data.get("position", {})) != TYPE_DICTIONARY:
			data["position"] = {"x": 0.0, "y": 0.0}
		normalized_data.append(data)
	return normalized_data


func build_restore_plan(resource_data: Array, normalize_position: Callable) -> Array[Dictionary]:
	var restore_plan: Array[Dictionary] = []
	var normalized_entries: Array[Dictionary] = normalize_restore_data(resource_data)
	for data_value in normalized_entries:
		var resource_data_entry: Dictionary = Dictionary(data_value).duplicate(true)
		var resource_kind := str(resource_data_entry.get("resource_kind", ""))
		var saved_position := Vector2.ZERO
		var position_value: Variant = resource_data_entry.get("position", Vector2.ZERO)
		if typeof(position_value) == TYPE_VECTOR2:
			saved_position = position_value
		elif typeof(position_value) == TYPE_DICTIONARY:
			var position_data := Dictionary(position_value)
			saved_position = Vector2(
				float(position_data.get("x", 0.0)),
				float(position_data.get("y", 0.0))
			)
		if normalize_position.is_valid():
			resource_data_entry["position"] = normalize_position.call(resource_kind, saved_position)
		restore_plan.append(resource_data_entry)
	return restore_plan


func apply_restore_data(resource_node: Variant, resource_data: Dictionary) -> bool:
	if not is_instance_valid(resource_node):
		return false
	if not resource_node.has_method("restore_from_data"):
		return false
	resource_node.restore_from_data(Dictionary(resource_data).duplicate(true))
	return true


func apply_restore_plan(restore_plan: Array, spawn_resource: Callable, apply_restore_callback: Callable) -> int:
	if not spawn_resource.is_valid():
		return 0
	var restored_count := 0
	for restore_value in restore_plan:
		if typeof(restore_value) != TYPE_DICTIONARY:
			continue
		var restore_data: Dictionary = Dictionary(restore_value).duplicate(true)
		var resource_kind := str(restore_data.get("resource_kind", ""))
		var position_data: Variant = restore_data.get("position", Vector2.ZERO)
		var resource_node: Variant = spawn_resource.call(resource_kind, position_data)
		if resource_node == null:
			continue
		var applied := true
		if apply_restore_callback.is_valid():
			applied = apply_restore_callback.call(resource_node, restore_data) == true
		if applied:
			restored_count += 1
	return restored_count


func restore_resources_from_data(resource_data: Array, normalize_position: Callable, spawn_resource: Callable, apply_restore_callback: Callable) -> int:
	var restore_plan: Array[Dictionary] = build_restore_plan(resource_data, normalize_position)
	return apply_restore_plan(restore_plan, spawn_resource, apply_restore_callback)


func count_resources_by_kind(resources: Array) -> Dictionary:
	var counts := {}
	for resource_value in resources:
		if not is_instance_valid(resource_value):
			continue
		var resource_kind := str(resource_value.get("resource_kind"))
		if resource_kind.is_empty():
			resource_kind = "unknown"
		counts[resource_kind] = int(counts.get(resource_kind, 0)) + 1
	return counts
