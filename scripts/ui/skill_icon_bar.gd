extends Control

var player: Node

var slots := [
	{"key": "Shift", "name": "Run", "kind": "run"},
	{"key": "E", "name": "Use", "kind": "use"},
	{"key": "Space", "name": "Attack", "kind": "attack"},
	{"key": "G", "name": "Gen", "kind": "generation"},
	{"key": "1", "name": "Fire", "kind": "fire"},
	{"key": "2", "name": "Spear", "kind": "spear"},
	{"key": "3", "name": "Trap", "kind": "trap"},
	{"key": "4", "name": "Wall", "kind": "wall"},
	{"key": "5", "name": "Box", "kind": "storage_box"},
	{"key": "6", "name": "Tent", "kind": "tent"},
	{"key": "7", "name": "Eat", "kind": "eat"},
	{"key": "8/T", "name": "Torch", "kind": "torch"}
]

func bind(p_player: Node) -> void:
	player = p_player
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var slot_size := Vector2(70, 58)
	for i in slots.size():
		var slot: Dictionary = slots[i]
		var rect := Rect2(Vector2(i * (slot_size.x + 8.0), 0.0), slot_size)
		var available := _is_available(slot["kind"])
		var fill := Color(0.09, 0.10, 0.11, 0.92) if available else Color(0.05, 0.05, 0.06, 0.68)
		draw_rect(rect, fill, true)
		draw_rect(rect, Color(0.70, 0.75, 0.68, 0.85), false, 1.0)
		_draw_icon(slot["kind"], rect, available)
		draw_string(get_theme_default_font(), rect.position + Vector2(6, 14), slot["key"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color.WHITE)
		draw_string(get_theme_default_font(), rect.position + Vector2(8, 52), slot["name"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.88, 0.88, 0.82))


func _is_available(kind: String) -> bool:
	if not player:
		return true
	match kind:
		"run":
			return player.stats.stamina > 1.0
		"spear":
			return player.has_spear or _has_recipe_items("spear")
		"fire":
			return _has_recipe_items("campfire")
		"trap":
			return _has_recipe_items("trap")
		"wall":
			return _has_recipe_items("wall")
		"storage_box":
			return _has_recipe_items("storage_box")
		"tent":
			return _has_recipe_items("tent")
		"eat":
			return player.inventory.has_item("meat", 1)
		"torch":
			return player.inventory.has_item("torch", 1) or player.is_torch_active() or _has_recipe_items("torch")
		_:
			return true


func _has_recipe_items(item_name: String) -> bool:
	if not player or not player.recipes.has(item_name):
		return false
	var recipe: Dictionary = player.recipes[item_name]
	for ingredient in recipe.keys():
		if not player.inventory.has_item(ingredient, int(recipe[ingredient])):
			return false
	return true


func _draw_icon(kind: String, rect: Rect2, available: bool) -> void:
	var color := Color(0.95, 0.78, 0.30) if available else Color(0.36, 0.36, 0.36)
	var center := rect.position + Vector2(rect.size.x * 0.5, 28.0)
	match kind:
		"run":
			draw_line(center + Vector2(-16, 10), center + Vector2(-2, -8), color, 3.0)
			draw_line(center + Vector2(-2, -8), center + Vector2(14, 8), color, 3.0)
			draw_circle(center + Vector2(-6, -14), 5.0, color)
		"use":
			draw_circle(center, 12.0, color)
			draw_circle(center, 5.0, Color(0.09, 0.10, 0.11))
		"attack":
			draw_line(center + Vector2(-14, 12), center + Vector2(14, -14), color, 4.0)
			draw_polygon([center + Vector2(14, -14), center + Vector2(10, -2), center + Vector2(2, -10)], [color])
		"generation":
			draw_circle(center, 13.0, color, false, 3.0)
			draw_line(center + Vector2(9, -9), center + Vector2(17, -9), color, 2.0)
			draw_line(center + Vector2(17, -9), center + Vector2(17, -1), color, 2.0)
			draw_line(center + Vector2(-9, 9), center + Vector2(-17, 9), color, 2.0)
			draw_line(center + Vector2(-17, 9), center + Vector2(-17, 1), color, 2.0)
		"fire":
			draw_circle(center + Vector2(0, 7), 9.0, Color(0.85, 0.26, 0.08) if available else color)
			draw_circle(center + Vector2(0, 3), 5.0, Color(1.0, 0.82, 0.18) if available else color)
		"spear":
			draw_line(center + Vector2(-16, 14), center + Vector2(14, -14), color, 3.0)
			draw_polygon([center + Vector2(14, -14), center + Vector2(11, -4), center + Vector2(5, -10)], [color])
		"trap":
			draw_rect(Rect2(center - Vector2(13, 13), Vector2(26, 26)), color, false, 2.0)
			draw_line(center + Vector2(-12, -12), center + Vector2(12, 12), color, 2.0)
			draw_line(center + Vector2(12, -12), center + Vector2(-12, 12), color, 2.0)
		"wall":
			draw_rect(Rect2(center - Vector2(18, 9), Vector2(36, 9)), color, true)
			draw_rect(Rect2(center - Vector2(18, 3), Vector2(36, 9)), color.darkened(0.18), true)
			draw_rect(Rect2(center - Vector2(18, 15), Vector2(36, 9)), color.lightened(0.12), true)
			draw_line(center + Vector2(-6, -15), center + Vector2(-6, 18), Color(0.09, 0.10, 0.11), 1.0)
			draw_line(center + Vector2(8, -15), center + Vector2(8, 18), Color(0.09, 0.10, 0.11), 1.0)
		"storage_box":
			draw_rect(Rect2(center - Vector2(16, 12), Vector2(32, 24)), color, true)
			draw_rect(Rect2(center - Vector2(16, 12), Vector2(32, 24)), Color(0.09, 0.10, 0.11), false, 2.0)
			draw_line(center + Vector2(-16, -3), center + Vector2(16, -3), Color(0.09, 0.10, 0.11), 2.0)
			draw_circle(center + Vector2(0, 4), 2.0, Color(0.09, 0.10, 0.11))
		"tent":
			draw_polygon([center + Vector2(-18, 14), center + Vector2(0, -16), center + Vector2(18, 14)], [color])
			draw_line(center + Vector2(0, -16), center + Vector2(0, 14), Color(0.09, 0.10, 0.11), 2.0)
		"eat":
			draw_circle(center, 13.0, color)
			draw_circle(center + Vector2(5, -4), 5.0, Color(0.09, 0.10, 0.11))
		"torch":
			draw_line(center + Vector2(-10, 15), center + Vector2(8, -13), color, 4.0)
			draw_circle(center + Vector2(9, -15), 8.0, Color(0.92, 0.28, 0.08) if available else color)
			draw_circle(center + Vector2(9, -17), 4.0, Color(1.0, 0.82, 0.22) if available else Color(0.09, 0.10, 0.11))
