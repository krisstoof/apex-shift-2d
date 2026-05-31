extends StaticBody2D

@export var item_name := "wood"
@export var amount := 2
@export var color := Color.FOREST_GREEN
@export var radius := 15.0
var resource_kind := "tree"

func _ready() -> void:
	add_to_group("resources")
	queue_redraw()


func setup(kind: String) -> void:
	resource_kind = kind
	match kind:
		"tree":
			item_name = "wood"
			amount = 3
			color = Color(0.1, 0.55, 0.16)
			radius = 17.0
		"rock":
			item_name = "stone"
			amount = 2
			color = Color(0.45, 0.45, 0.5)
			radius = 15.0
		"bush":
			item_name = "fiber"
			amount = 2
			color = Color(0.45, 0.9, 0.28)
			radius = 13.0
	queue_redraw()


func interact(player: Node) -> void:
	player.inventory.add_item(item_name, amount)
	get_node("/root/EventBus").post_message("Collected %s" % item_name)
	queue_free()


func get_prompt() -> String:
	return "E: gather %s x%s" % [item_name, amount]


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	if item_name == "wood":
		draw_rect(Rect2(-4, 4, 8, 16), Color(0.42, 0.23, 0.08))
	elif item_name == "stone":
		draw_polygon([Vector2(-16, 8), Vector2(-8, -12), Vector2(12, -10), Vector2(17, 6), Vector2(0, 15)], [color])
