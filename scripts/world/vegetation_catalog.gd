extends RefCounted
class_name VegetationCatalog

const CLASS_DECORATIVE := "decorative"
const CLASS_EDIBLE_NODE := "edible_node"
const CLASS_INTERACTIVE := "interactive"

const DECORATIVE_KINDS := {
	"grass_patch": true,
	"dense_grass": true,
	"reed": true,
	"cattail": true,
	"water_lily": true,
	"pond_grass": true,
	"wetland_grass": true
}

const EDIBLE_NODE_KINDS := {
	"bush": true,
	"dry_bush": true,
	"small_bush": true,
	"berry_bush": true
}

const INTERACTIVE_KINDS := [
	"conifer_tree",
	"leafy_tree",
	"dry_tree",
	"rock",
	"bush",
	"dry_bush",
	"small_bush",
	"berry_bush",
	"meat_drop",
	"bone_drop"
]


static func is_decorative_kind(kind: String) -> bool:
	return DECORATIVE_KINDS.has(kind)


static func is_edible_node_kind(kind: String) -> bool:
	return EDIBLE_NODE_KINDS.has(kind)


static func is_food_target_kind(kind: String) -> bool:
	return is_edible_node_kind(kind)


static func is_visual_only_kind(kind: String) -> bool:
	return is_decorative_kind(kind)


static func is_interactive_kind(kind: String) -> bool:
	return kind in INTERACTIVE_KINDS


static func get_resource_class(kind: String) -> String:
	if is_decorative_kind(kind):
		return CLASS_DECORATIVE
	if is_interactive_kind(kind):
		return CLASS_INTERACTIVE
	if is_edible_node_kind(kind):
		return CLASS_EDIBLE_NODE
	return CLASS_INTERACTIVE
