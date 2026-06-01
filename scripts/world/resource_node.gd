extends StaticBody2D

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")

@export var item_name := "wood"
@export var amount := 2
@export var color := Color.FOREST_GREEN
@export var radius := 15.0
var resource_kind := "conifer_tree"
var mature_amount := 2
var mature_radius := 15.0
var mature_color := Color.FOREST_GREEN
var growth_stage := 3
var max_growth_stage := 3
var growth_progress := 0.0
var days_to_next_stage := 1.0
var days_since_harvested := 0.0
var is_harvested := false
var can_be_harvested := true
var biome_id := ""

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("resources")
	if biome_id.is_empty():
		biome_id = _get_biome_id_for_position(global_position)
	_apply_growth_stage()
	queue_redraw()


func setup(kind: String) -> void:
	resource_kind = "conifer_tree" if kind == "tree" else kind
	biome_id = _get_biome_id_for_position(global_position)
	match kind:
		"tree", "conifer_tree":
			item_name = "wood"
			mature_amount = 4
			mature_color = Color(0.08, 0.36, 0.16)
			mature_radius = 24.0
		"leafy_tree":
			item_name = "wood"
			mature_amount = 4
			mature_color = Color(0.16, 0.52, 0.18)
			mature_radius = 24.0
		"rock":
			item_name = "stone"
			mature_amount = 2
			mature_color = Color(0.45, 0.45, 0.5)
			mature_radius = 15.0
		"bush":
			item_name = "fiber"
			mature_amount = 2
			mature_color = Color(0.45, 0.9, 0.28)
			mature_radius = 13.0
		"dry_bush":
			item_name = "fiber"
			mature_amount = 1
			mature_color = Color(0.68, 0.54, 0.26)
			mature_radius = 14.0
	days_to_next_stage = _get_days_to_next_stage()
	_apply_growth_stage()
	queue_redraw()


func interact(player: Node) -> void:
	if not can_be_harvested:
		get_node("/root/EventBus").post_message("%s is still regrowing" % _get_resource_label())
		return
	player.inventory.add_item(item_name, amount)
	get_node("/root/EventBus").post_message("Collected %s x%d" % [item_name, amount])
	_emit_plant_resource_harvested()
	if _uses_regrowth():
		_mark_harvested()
	else:
		queue_free()


func get_prompt() -> String:
	if not can_be_harvested:
		return "Regrowing: %s" % get_growth_debug_text()
	return "E: gather %s x%s" % [item_name, amount]


func get_save_data() -> Dictionary:
	return {
		"kind": resource_kind,
		"position": _vector_to_data(global_position),
		"biome_id": biome_id,
		"growth_stage": growth_stage,
		"max_growth_stage": max_growth_stage,
		"growth_progress": growth_progress,
		"days_to_next_stage": days_to_next_stage,
		"days_since_harvested": days_since_harvested,
		"is_harvested": is_harvested,
		"can_be_harvested": can_be_harvested
	}


func restore_from_data(data: Dictionary) -> void:
	biome_id = str(data.get("biome_id", _get_biome_id_for_position(global_position)))
	growth_stage = clamp(int(data.get("growth_stage", max_growth_stage)), 0, max_growth_stage)
	growth_progress = max(float(data.get("growth_progress", 0.0)), 0.0)
	days_to_next_stage = max(float(data.get("days_to_next_stage", _get_days_to_next_stage())), 0.1)
	days_since_harvested = max(float(data.get("days_since_harvested", 0.0)), 0.0)
	is_harvested = data.get("is_harvested", growth_stage <= 0) == true
	can_be_harvested = data.get("can_be_harvested", growth_stage > 0) == true
	_apply_growth_stage()


func advance_growth_days(days: float) -> bool:
	if not _uses_regrowth() or growth_stage >= max_growth_stage:
		return false
	var changed := false
	growth_progress += max(days, 0.0)
	days_since_harvested += max(days, 0.0)
	while growth_stage < max_growth_stage and growth_progress >= days_to_next_stage:
		growth_progress -= days_to_next_stage
		growth_stage += 1
		changed = true
		days_to_next_stage = _get_days_to_next_stage()
	is_harvested = growth_stage <= 0
	_apply_growth_stage()
	return changed


func force_full_regrowth() -> void:
	growth_stage = max_growth_stage
	growth_progress = 0.0
	days_since_harvested = 0.0
	is_harvested = false
	_apply_growth_stage()


func reset_growth_state() -> void:
	force_full_regrowth()


func get_growth_debug_text() -> String:
	return "%s %d/%d progress %.1f/%.1f days %.1f" % [
		_get_growth_stage_name(),
		growth_stage,
		max_growth_stage,
		growth_progress,
		days_to_next_stage,
		days_since_harvested
	]


func _mark_harvested() -> void:
	growth_stage = 0
	growth_progress = 0.0
	days_since_harvested = 0.0
	days_to_next_stage = _get_days_to_next_stage()
	is_harvested = true
	_apply_growth_stage()


func _apply_growth_stage() -> void:
	can_be_harvested = not _uses_regrowth() or growth_stage > 0
	amount = _get_stage_yield()
	color = mature_color.darkened(0.45 if growth_stage <= 0 else 0.0).lerp(mature_color, _get_growth_ratio())
	radius = max(mature_radius * _get_visual_scale(), 5.0)
	if collision_shape:
		collision_shape.disabled = not can_be_harvested
	queue_redraw()


func _get_stage_yield() -> int:
	if not _uses_regrowth():
		return mature_amount
	var multiplier := _get_stage_yield_multiplier()
	if multiplier <= 0.0:
		return 0
	return max(1, int(ceil(float(mature_amount) * multiplier)))


func _get_stage_yield_multiplier() -> float:
	var stage_name := _get_growth_stage_name()
	var yield_by_stage: Dictionary = GAME_BALANCE.RESOURCE_REGROWTH.get("yield_by_growth_stage", {})
	return float(yield_by_stage.get(stage_name, 1.0))


func _get_growth_stage_name() -> String:
	var stages: Array = GAME_BALANCE.RESOURCE_REGROWTH.get("stages", ["depleted", "sprout", "young", "mature"])
	return str(stages[clamp(growth_stage, 0, stages.size() - 1)])


func _get_days_to_next_stage() -> float:
	var total_days := _get_regrowth_time_days()
	return max(total_days / float(max_growth_stage), 0.1)


func _get_regrowth_time_days() -> float:
	match resource_kind:
		"conifer_tree", "leafy_tree":
			return float(GAME_BALANCE.RESOURCE_REGROWTH.get("tree_regrowth_time_days", 3))
		"bush":
			return float(GAME_BALANCE.RESOURCE_REGROWTH.get("bush_regrowth_time_days", 2))
		"dry_bush":
			return float(GAME_BALANCE.RESOURCE_REGROWTH.get("dry_bush_regrowth_time_days", 3))
	return 0.0


func _get_visual_scale() -> float:
	if not _uses_regrowth():
		return 1.0
	match growth_stage:
		0:
			return 0.55
		1:
			return 0.50
		2:
			return 0.75
		_:
			return 1.0


func _get_growth_ratio() -> float:
	return float(growth_stage) / float(max(max_growth_stage, 1))


func _uses_regrowth() -> bool:
	return resource_kind in ["conifer_tree", "leafy_tree", "bush", "dry_bush"]


func _get_resource_label() -> String:
	return str(resource_kind).replace("_", " ")


func _vector_to_data(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


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
			return float(GAME_BALANCE.ECOSYSTEM["tree_biomass_impact"])
		"bush":
			return float(GAME_BALANCE.ECOSYSTEM["bush_biomass_impact"])
		"dry_bush":
			return float(GAME_BALANCE.ECOSYSTEM["dry_bush_biomass_impact"])
	return 0.0


func _get_biome_id_for_position(position: Vector2) -> String:
	for biome in WORLD_CONFIG.get_biome_zones():
		if Geometry2D.is_point_in_polygon(position, PackedVector2Array(biome["points"])):
			return _get_biome_id(biome)
	return ""


func _get_biome_id(biome: Dictionary) -> String:
	return str(biome.get("name", "biome")).to_snake_case()


func _draw() -> void:
	if _uses_regrowth() and growth_stage <= 0:
		_draw_depleted_plant()
		return
	var visual_scale := _get_visual_scale()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(visual_scale, visual_scale))
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
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_depleted_plant() -> void:
	match resource_kind:
		"conifer_tree", "leafy_tree":
			draw_rect(Rect2(-5, -2, 10, 14), Color(0.34, 0.19, 0.09), true)
			draw_circle(Vector2.ZERO, 13.0, Color(0.17, 0.11, 0.06, 0.26))
		"bush", "dry_bush":
			draw_line(Vector2(-12, 8), Vector2(12, -6), Color(0.33, 0.24, 0.10), 2.0)
			draw_line(Vector2(12, 8), Vector2(-12, -5), Color(0.31, 0.22, 0.10), 2.0)
			draw_circle(Vector2.ZERO, 10.0, Color(0.14, 0.12, 0.08, 0.20))


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
