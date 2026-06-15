extends RefCounted
class_name ItemDatabase

const ITEMS := {
	"wood": {
		"display_name": "Wood",
		"icon": "res://assets/icons/items/wood.png",
		"max_stack": 20,
		"accent_color": "#A86A32",
		"symbol": "W"
	},
	"stone": {
		"display_name": "Stone",
		"icon": "res://assets/icons/items/stone.png",
		"max_stack": 20,
		"accent_color": "#8D9097",
		"symbol": "S"
	},
	"fiber": {
		"display_name": "Fiber",
		"icon": "res://assets/icons/items/fiber.png",
		"max_stack": 20,
		"accent_color": "#4CAF50",
		"symbol": "F"
	},
	"meat": {
		"display_name": "Meat",
		"icon": "res://assets/icons/items/meat.png",
		"max_stack": 20,
		"accent_color": "#C7443E",
		"symbol": "M"
	},
	"bone": {
		"display_name": "Bone",
		"icon": "res://assets/icons/items/bone.png",
		"max_stack": 20,
		"accent_color": "#D8D0B0",
		"symbol": "B"
	},
	"torch": {
		"display_name": "Torch",
		"icon": "",
		"max_stack": 1,
		"accent_color": "#E0B04A",
		"symbol": "T"
	},
	"spear": {
		"display_name": "Spear",
		"icon": "",
		"max_stack": 1,
		"accent_color": "#C9A26A",
		"symbol": "P"
	},
	"bow": {
		"display_name": "Bow",
		"icon": "",
		"max_stack": 1,
		"accent_color": "#B87A5A",
		"symbol": "O"
	},
	"berries": {
		"display_name": "Berries",
		"icon": "",
		"max_stack": 20,
		"accent_color": "#CC4A7A",
		"symbol": "R"
	},
	"grass": {
		"display_name": "Grass",
		"icon": "",
		"max_stack": 20,
		"accent_color": "#5BBF61",
		"symbol": "G"
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


static func get_accent_color(item_id: String) -> Color:
	if not ITEMS.has(item_id):
		return Color(0.75, 0.75, 0.75, 1.0)
	var value := str(ITEMS[item_id].get("accent_color", "#BFBFBF"))
	return Color.html(value)


static func get_symbol(item_id: String) -> String:
	if not ITEMS.has(item_id):
		return "?"
	return str(ITEMS[item_id].get("symbol", "?"))
