extends RefCounted
class_name ResourceDropTable

static func get_drop_item_id(state: ResourceState) -> String:
	if state == null:
		return ""
	match state.resource_kind:
		"tree", "conifer_tree", "leafy_tree", "dry_tree":
			return "wood"
		"rock":
			return "stone"
		"bush", "dry_bush", "small_bush":
			return "fiber"
		"berry_bush":
			return "berries"
		"meat_drop":
			return "meat"
		"bone_drop":
			return "bone"
		"item_drop":
			return state.inventory_drop_item_id if not state.inventory_drop_item_id.is_empty() else state.item_id
		_:
			return state.item_id

static func get_default_yield(resource_kind: String) -> int:
	match resource_kind:
		"tree", "conifer_tree", "leafy_tree":
			return 4
		"dry_tree":
			return 3
		"rock":
			return 2
		"bush":
			return 2
		"dry_bush":
			return 1
		"small_bush":
			return 1
		"berry_bush":
			return 1
		"grass_patch", "dense_grass":
			return 1
		_:
			return 1

static func get_default_regrowth_days(resource_kind: String) -> float:
	match resource_kind:
		"tree", "conifer_tree", "leafy_tree":
			return 3.0
		"dry_tree":
			return 15.0
		"bush", "small_bush", "berry_bush":
			return 2.0
		"dry_bush":
			return 3.0
		"grass_patch", "dense_grass":
			return 1.0
		_:
			return 0.0

static func uses_regrowth(resource_kind: String) -> bool:
	return resource_kind in ["tree", "conifer_tree", "leafy_tree", "dry_tree", "bush", "dry_bush", "small_bush", "berry_bush", "grass_patch", "dense_grass"]
