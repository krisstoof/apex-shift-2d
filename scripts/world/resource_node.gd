extends StaticBody2D

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")

@export var item_name := "wood"
@export var amount := 2
@export var color := Color.FOREST_GREEN
@export var radius := 15.0
var resource_kind := "conifer_tree"

func _ready() -> void:
	add_to_group("resources")
	queue_redraw()


func setup(kind: String) -> void:
	resource_kind = "conifer_tree" if kind == "tree" else kind
	match kind:
		"tree", "conifer_tree":
			item_name = "wood"
			amount = 3
			color = Color(0.08, 0.36, 0.16)
			radius = 24.0
		"leafy_tree":
			item_name = "wood"
			amount = 3
			color = Color(0.16, 0.52, 0.18)
			radius = 24.0
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
		"dry_bush":
			item_name = "fiber"
			amount = 1
			color = Color(0.68, 0.54, 0.26)
			radius = 14.0
	queue_redraw()


func interact(player: Node) -> void:
	player.inventory.add_item(item_name, amount)
	get_node("/root/EventBus").post_message("Collected %s" % item_name)
	_emit_plant_resource_harvested()
	queue_free()


func get_prompt() -> String:
	return "E: gather %s x%s" % [item_name, amount]


func _emit_plant_resource_harvested() -> void:
	var biomass_impact := _get_biomass_impact()
	if biomass_impact <= 0.0:
		return
	var biome_id := _get_biome_id_for_position(global_position)
	if biome_id.is_empty():
		return
	get_node("/root/EventBus").emit_game_event("plant_resource_harvested", {
		"resource_type": resource_kind,
		"biome_id": biome_id,
		"position": global_position,
		"biomass_impact": biomass_impact
	})


func _get_biomass_impact() -> float:
	match resource_kind:
		"conifer_tree", "leafy_tree":
			return GAME_BALANCE.ECOSYSTEM_TREE_BIOMASS_IMPACT
		"bush":
			return GAME_BALANCE.ECOSYSTEM_BUSH_BIOMASS_IMPACT
		"dry_bush":
			return GAME_BALANCE.ECOSYSTEM_DRY_BUSH_BIOMASS_IMPACT
	return 0.0


func _get_biome_id_for_position(position: Vector2) -> String:
	for biome in WORLD_CONFIG.get_biome_zones():
		if Geometry2D.is_point_in_polygon(position, PackedVector2Array(biome["points"])):
			return _get_biome_id(biome)
	return ""


func _get_biome_id(biome: Dictionary) -> String:
	return str(biome.get("name", "biome")).to_snake_case()


func _draw() -> void:
	match resource_kind:
		"conifer_tree":
			_draw_conifer_tree()
		"leafy_tree":
			_draw_leafy_tree()
		"bush":
			_draw_bush()
		"dry_bush":
			_draw_dry_bush()
		"rock":
			_draw_rock()
		_:
			_draw_bush()


func _draw_conifer_tree() -> void:
	draw_rect(Rect2(-4, 6, 8, 20), Color(0.38, 0.22, 0.10), true)
	draw_polygon([Vector2(0, -30), Vector2(-24, 4), Vector2(24, 4)], [Color(0.06, 0.28, 0.14)])
	draw_polygon([Vector2(0, -18), Vector2(-28, 16), Vector2(28, 16)], [Color(0.07, 0.36, 0.17)])
	draw_polygon([Vector2(0, -6), Vector2(-23, 25), Vector2(23, 25)], [Color(0.10, 0.44, 0.20)])
	draw_line(Vector2(0, -30), Vector2(0, 23), Color(0.12, 0.18, 0.10, 0.45), 2.0)


func _draw_leafy_tree() -> void:
	draw_rect(Rect2(-5, 2, 10, 24), Color(0.42, 0.23, 0.08), true)
	draw_circle(Vector2(-10, -8), 17.0, Color(0.13, 0.45, 0.16))
	draw_circle(Vector2(10, -9), 17.0, Color(0.12, 0.50, 0.17))
	draw_circle(Vector2(0, -20), 18.0, Color(0.18, 0.58, 0.20))
	draw_circle(Vector2(0, -7), 19.0, Color(0.16, 0.52, 0.18))
	draw_arc(Vector2.ZERO, 26.0, -PI, 0.0, 16, Color(0.06, 0.18, 0.08, 0.45), 2.0)


func _draw_bush() -> void:
	draw_circle(Vector2(-10, 4), 12.0, Color(0.31, 0.70, 0.22))
	draw_circle(Vector2(2, -4), 14.0, Color(0.43, 0.86, 0.25))
	draw_circle(Vector2(13, 5), 11.0, Color(0.24, 0.60, 0.18))
	draw_circle(Vector2(2, 9), 11.0, Color(0.35, 0.75, 0.20))
	draw_line(Vector2(-16, 8), Vector2(16, 8), Color(0.12, 0.26, 0.10), 2.0)


func _draw_dry_bush() -> void:
	var branch_color := Color(0.66, 0.49, 0.22)
	draw_line(Vector2(0, 12), Vector2(-18, -8), branch_color, 3.0)
	draw_line(Vector2(0, 12), Vector2(18, -9), branch_color, 3.0)
	draw_line(Vector2(0, 12), Vector2(0, -16), branch_color.lightened(0.12), 3.0)
	draw_line(Vector2(-8, 1), Vector2(-19, 3), branch_color.darkened(0.12), 2.0)
	draw_line(Vector2(-4, -4), Vector2(-10, -15), branch_color, 2.0)
	draw_line(Vector2(7, 1), Vector2(19, 5), branch_color.darkened(0.12), 2.0)
	draw_line(Vector2(5, -4), Vector2(12, -16), branch_color, 2.0)
	draw_circle(Vector2.ZERO, 15.0, Color(0.50, 0.38, 0.17, 0.12))


func _draw_rock() -> void:
	draw_polygon([Vector2(-17, 8), Vector2(-9, -13), Vector2(10, -12), Vector2(18, 5), Vector2(3, 16)], [Color(0.38, 0.39, 0.42)])
	draw_polygon([Vector2(-9, -13), Vector2(10, -12), Vector2(3, 1), Vector2(-14, 4)], [Color(0.55, 0.56, 0.60)])
	draw_line(Vector2(-5, -8), Vector2(4, 10), Color(0.22, 0.23, 0.25), 2.0)
