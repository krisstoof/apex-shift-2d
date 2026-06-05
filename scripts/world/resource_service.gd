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
