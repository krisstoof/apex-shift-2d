extends RefCounted
class_name VegetationCatalog

const CLASS_DECORATIVE := "decorative"
const CLASS_EDIBLE_NODE := "edible_node"
const CLASS_INTERACTIVE := "interactive"

const DECORATIVE_KINDS := [
	"grass_patch",
	"dense_grass"
]

const EDIBLE_NODE_KINDS := [
	"bush",
	"dry_bush",
	"small_bush",
	"berry_bush",
	"grass_patch",
	"dense_grass"
]

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
	return kind in DECORATIVE_KINDS


static func is_edible_node_kind(kind: String) -> bool:
	return kind in EDIBLE_NODE_KINDS


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
