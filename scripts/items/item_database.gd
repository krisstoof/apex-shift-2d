extends RefCounted
class_name ItemDatabase

const ITEMS := {
	"wood": {
		"display_name": "Wood",
		"icon": "res://assets/icons/items/wood.png",
		"max_stack": 20
	},
	"stone": {
		"display_name": "Stone",
		"icon": "res://assets/icons/items/stone.png",
		"max_stack": 20
	},
	"fiber": {
		"display_name": "Fiber",
		"icon": "res://assets/icons/items/fiber.png",
		"max_stack": 20
	},
	"meat": {
		"display_name": "Meat",
		"icon": "res://assets/icons/items/meat.png",
		"max_stack": 20
	},
	"bone": {
		"display_name": "Bone",
		"icon": "",
		"max_stack": 20
	},
	"torch": {
		"display_name": "Torch",
		"icon": "",
		"max_stack": 1
	},
	"spear": {
		"display_name": "Spear",
		"icon": "",
		"max_stack": 1
	},
	"bow": {
		"display_name": "Bow",
		"icon": "",
		"max_stack": 1
	}
}

static func has_item(item_id: String) -> bool:
	return ITEMS.has(item_id)


static func get_max_stack(item_id: String) -> int:
	if not ITEMS.has(item_id):
		return 0
	return int(ITEMS[item_id].get("max_stack", 1))


static func get_display_name(item_id: String) -> String:
	if not ITEMS.has(item_id):
		return item_id
	return str(ITEMS[item_id].get("display_name", item_id))


static func get_icon_path(item_id: String) -> String:
	if not ITEMS.has(item_id):
		return ""
	return str(ITEMS[item_id].get("icon", ""))
