extends RefCounted
class_name ItemDatabase

const ITEMS := {
	"wood": {
		"display_name": "Wood",
		"icon": "res://assets/icons/items/wood.png",
		"max_stack": 20,
		"accent_color": "#A86832",
		"ground_shape": "log"
	},
	"stone": {
		"display_name": "Stone",
		"icon": "res://assets/icons/items/stone.png",
		"max_stack": 20,
		"accent_color": "#8E9299",
		"ground_shape": "rock"
	},
	"fiber": {
		"display_name": "Fiber",
		"icon": "res://assets/icons/items/fiber.png",
		"max_stack": 20,
		"accent_color": "#4DAA3F",
		"ground_shape": "grass_bundle"
	},
	"meat": {
		"display_name": "Meat",
		"icon": "res://assets/icons/items/meat.png",
		"max_stack": 20,
		"accent_color": "#C8463C",
		"ground_shape": "meat_chunk"
	},
	"bone": {
		"display_name": "Bone",
		"icon": "res://assets/icons/items/bone.png",
		"max_stack": 20,
		"accent_color": "#D8D0B2",
		"ground_shape": "bone"
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
	return ITEMS.has(normalize_item_id(item_id))


static func get_max_stack(item_id: String) -> int:
	var normalized := normalize_item_id(item_id)
	if not ITEMS.has(normalized):
		return 0
	return int(ITEMS[normalized].get("max_stack", 1))


static func get_display_name(item_id: String) -> String:
	var normalized := normalize_item_id(item_id)
	if not ITEMS.has(normalized):
		return item_id
	return str(ITEMS[normalized].get("display_name", normalized))


static func get_icon_path(item_id: String) -> String:
	var normalized := normalize_item_id(item_id)
	if not ITEMS.has(normalized):
		return ""
	return str(ITEMS[normalized].get("icon", ""))


static func get_accent_color(item_id: String) -> Color:
	var normalized := normalize_item_id(item_id)
	if not ITEMS.has(normalized):
		return Color(0.75, 0.75, 0.75, 1.0)
	var value := str(ITEMS[normalized].get("accent_color", "#BFBFBF"))
	return Color.html(value)


static func get_symbol(item_id: String) -> String:
	var normalized := normalize_item_id(item_id)
	if not ITEMS.has(normalized):
		return "?"
	return str(ITEMS[normalized].get("symbol", "?"))


static func get_ground_shape(item_id: String) -> String:
	var normalized := normalize_item_id(item_id)
	if not ITEMS.has(normalized):
		return "generic"
	return str(ITEMS[normalized].get("ground_shape", "generic"))


static func normalize_item_id(value: String) -> String:
	var item_id := str(value).strip_edges()
	if ITEMS.has(item_id):
		return item_id
	var lower_id := item_id.to_lower()
	if ITEMS.has(lower_id):
		return lower_id
	for key in ITEMS.keys():
		var display_name := str(ITEMS[key].get("display_name", key))
		if display_name.to_lower() == lower_id:
			return str(key)
	return lower_id
