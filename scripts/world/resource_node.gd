extends StaticBody2D

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const RESOURCE_ATLAS_PATH := "res://assets/textures/resources/resource_atlas.svg"
const RESOURCE_ATLAS_CELL_SIZE := Vector2(80.0, 80.0)
const RESOURCE_ATLAS_COLUMNS := {
	"conifer_tree": 0,
	"leafy_tree": 1,
	"bush": 2,
	"dry_bush": 3,
	"small_bush": 4,
	"berry_bush": 5,
	"grass_patch": 6,
	"dense_grass": 7,
	"rock": 8,
	"meat_drop": 9,
	"bone_drop": 10,
	"dry_tree": 11
}
static var shared_resource_atlas: ImageTexture

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
var player_harvestable := true
var is_edible_by_herbivores := false
var food_value := 0.0
var render_only := false
var is_pond_vegetation := false
var pond_id := ""
var food_bonus_multiplier := 1.0
var pond_visual_multiplier := 1.0
var biome_id := ""


func _get_event_bus() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("EventBus")


func _post_event_message(message: String) -> void:
	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_method("post_message"):
		event_bus.post_message(message)


func _emit_game_event(event_name: String, payload: Dictionary = {}) -> void:
	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_method("emit_game_event"):
		event_bus.emit_game_event(event_name, payload)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual_sprite: Sprite2D = $VisualSprite

func _ready() -> void:
	add_to_group("resources")
	if biome_id.is_empty():
		biome_id = _get_biome_id_for_position(global_position)
	_apply_growth_stage()
	_sync_resource_groups()
	_sync_visual_sprite()
	queue_redraw()


func setup(kind: String) -> void:
	resource_kind = "conifer_tree" if kind == "tree" else kind
	biome_id = _get_biome_id_for_position(global_position)
	player_harvestable = true
	render_only = false
	food_value = 0.0
	match kind:
		"tree", "conifer_tree":
			item_name = "wood"
			mature_amount = 4
			mature_color = Color(0.08, 0.36, 0.16)
			mature_radius = 24.0
			food_value = float(GAME_BALANCE.ANIMAL_AI.get("tree_food_value", 0.10))
		"leafy_tree":
			item_name = "wood"
			mature_amount = 4
			mature_color = Color(0.16, 0.52, 0.18)
			mature_radius = 24.0
			food_value = float(GAME_BALANCE.ANIMAL_AI.get("tree_food_value", 0.10))
		"dry_tree":
			item_name = "wood"
			mature_amount = 3
			mature_color = Color(0.60, 0.44, 0.20)
			mature_radius = 22.0
			food_value = 0.0
		"rock":
			item_name = "stone"
			mature_amount = 2
			mature_color = Color(0.45, 0.45, 0.5)
			mature_radius = 15.0
		"meat_drop":
			item_name = "meat"
			mature_amount = 1
			mature_color = Color(0.72, 0.12, 0.10)
			mature_radius = 10.0
			food_value = float(GAME_BALANCE.ANIMAL_AI.get("meat_food_value", 0.65))
			z_index = 20
		"bone_drop":
			item_name = "bone"
			mature_amount = 1
			mature_color = Color(0.82, 0.78, 0.70)
			mature_radius = 9.0
			z_index = 20
		"bush":
			item_name = "fiber"
			mature_amount = 2
			mature_color = Color(0.45, 0.9, 0.28)
			mature_radius = 13.0
			food_value = float(GAME_BALANCE.ANIMAL_AI.get("bush_food_value", 0.45))
		"dry_bush":
			item_name = "fiber"
			mature_amount = 1
			mature_color = Color(0.68, 0.54, 0.26)
			mature_radius = 14.0
			food_value = float(GAME_BALANCE.ANIMAL_AI.get("bush_food_value", 0.45)) * 0.45
		"small_bush":
			item_name = "fiber"
			mature_amount = 1
			mature_color = Color(0.34, 0.74, 0.20)
			mature_radius = 10.0
			food_value = float(GAME_BALANCE.ANIMAL_AI.get("bush_food_value", 0.45)) * 0.65
		"berry_bush":
			item_name = "berries"
			mature_amount = 1
			player_harvestable = false
			mature_color = Color(0.25, 0.64, 0.23)
			mature_radius = 12.0
			food_value = float(GAME_BALANCE.ANIMAL_AI.get("bush_food_value", 0.45)) * 0.9
		"grass_patch":
			item_name = "grass"
			mature_amount = 1
			player_harvestable = false
			render_only = true
			mature_color = Color(0.34, 0.78, 0.27)
			mature_radius = 8.0
			food_value = float(GAME_BALANCE.ANIMAL_AI.get("grass_food_value", 0.2))
		"dense_grass":
			item_name = "grass"
			mature_amount = 1
			player_harvestable = false
			render_only = true
			mature_color = Color(0.25, 0.68, 0.20)
			mature_radius = 12.0
			food_value = float(GAME_BALANCE.ANIMAL_AI.get("grass_food_value", 0.2)) * 1.5
	days_to_next_stage = _get_days_to_next_stage()
	_apply_growth_stage()
	_sync_resource_groups()
	queue_redraw()


func interact(player: Node) -> void:
	if not player_harvestable:
		return
	if not can_be_harvested:
		_post_event_message("%s is still regrowing" % _get_resource_label())
		return
	var collected_amount := amount
	var leftover: int = player.inventory.add_item(item_name, collected_amount)
	var added_amount: int = collected_amount - leftover
	if added_amount <= 0:
		_post_event_message("Inventory full")
		return
	_post_event_message("Collected %s x%d" % [item_name, added_amount])
	if resource_kind == "meat_drop" or resource_kind == "bone_drop":
		var event_name := "bone_collected" if resource_kind == "bone_drop" else "meat_collected"
		_emit_game_event(event_name, {
			"amount": added_amount,
			"position": global_position
		})
	if leftover > 0:
		amount = leftover
		queue_redraw()
		return
	_emit_plant_resource_harvested()
	if _uses_regrowth():
		_mark_harvested()
	else:
		queue_free()


func get_prompt() -> String:
	if not player_harvestable:
		return ""
	if not can_be_harvested:
		return "Regrowing: %s" % get_growth_debug_text()
	return "E: gather %s x%s" % [item_name, amount]


func get_save_data() -> Dictionary:
	return {
		"kind": resource_kind,
		"position": _vector_to_data(global_position),
		"biome_id": biome_id,
		"amount": amount,
		"mature_amount": mature_amount,
		"growth_stage": growth_stage,
		"max_growth_stage": max_growth_stage,
		"growth_progress": growth_progress,
		"days_to_next_stage": days_to_next_stage,
		"days_since_harvested": days_since_harvested,
		"is_harvested": is_harvested,
		"can_be_harvested": can_be_harvested,
		"player_harvestable": player_harvestable,
		"is_edible_by_herbivores": is_edible_by_herbivores,
		"food_value": food_value,
		"render_only": render_only,
		"is_pond_vegetation": is_pond_vegetation,
		"pond_id": pond_id,
		"food_bonus_multiplier": food_bonus_multiplier,
		"pond_visual_multiplier": pond_visual_multiplier
	}


func restore_from_data(data: Dictionary) -> void:
	biome_id = str(data.get("biome_id", _get_biome_id_for_position(global_position)))
	mature_amount = max(int(data.get("mature_amount", mature_amount)), 0)
	amount = max(int(data.get("amount", mature_amount)), 0)
	growth_stage = clamp(int(data.get("growth_stage", max_growth_stage)), 0, max_growth_stage)
	growth_progress = max(float(data.get("growth_progress", 0.0)), 0.0)
	days_to_next_stage = max(float(data.get("days_to_next_stage", _get_days_to_next_stage())), 0.1)
	days_since_harvested = max(float(data.get("days_since_harvested", 0.0)), 0.0)
	is_harvested = data.get("is_harvested", growth_stage <= 0) == true
	can_be_harvested = data.get("can_be_harvested", growth_stage > 0) == true
	food_value = max(float(data.get("food_value", food_value)), 0.0)
	render_only = data.get("render_only", _is_render_only_kind()) == true
	if food_value <= 0.0:
		food_value = _get_default_herbivore_food_value()
	is_pond_vegetation = data.get("is_pond_vegetation", false) == true
	pond_id = str(data.get("pond_id", pond_id))
	food_bonus_multiplier = max(float(data.get("food_bonus_multiplier", food_bonus_multiplier)), 1.0)
	pond_visual_multiplier = max(float(data.get("pond_visual_multiplier", pond_visual_multiplier)), 1.0)
	_apply_pond_visual_bonus()
	_sync_resource_groups()
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


func set_pond_vegetation(source_pond_id: String, food_multiplier: float = 1.0, visual_multiplier: float = 1.0) -> void:
	if is_pond_vegetation:
		return
	is_pond_vegetation = true
	pond_id = source_pond_id
	food_bonus_multiplier = max(food_multiplier, 1.0)
	pond_visual_multiplier = max(visual_multiplier, 1.0)
	if food_value > 0.0:
		food_value *= food_bonus_multiplier
	_apply_pond_visual_bonus()
	_sync_resource_groups()
	_apply_growth_stage()


func set_loot_amount(loot_amount: int) -> void:
	mature_amount = max(loot_amount, 1)
	amount = mature_amount


func _apply_pond_visual_bonus() -> void:
	if not is_pond_vegetation:
		return
	if resource_kind in ["grass_patch", "dense_grass", "small_bush", "berry_bush"]:
		mature_radius *= pond_visual_multiplier
		mature_color = mature_color.lightened(0.08)


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
	can_be_harvested = player_harvestable and (not _uses_regrowth() or growth_stage > 0)
	is_edible_by_herbivores = resource_kind != "meat_drop" and food_value > 0.0 and (not _uses_regrowth() or growth_stage > 0)
	amount = _get_stage_yield()
	color = mature_color.darkened(0.45 if growth_stage <= 0 else 0.0).lerp(mature_color, _get_growth_ratio())
	radius = max(mature_radius * _get_visual_scale(), 5.0)
	_sync_collision_shape_radius()
	_sync_collision_state(true)
	_sync_resource_groups()
	_sync_visual_sprite()
	queue_redraw()


func _sync_visual_sprite() -> void:
	var sprite := _get_visual_sprite()
	if sprite == null:
		return
	if resource_kind == "bone_drop":
		sprite.visible = false
		sprite.texture = null
		return
	var column := int(RESOURCE_ATLAS_COLUMNS.get(resource_kind, RESOURCE_ATLAS_COLUMNS["bush"]))
	var row := 1 if _uses_regrowth() and growth_stage <= 0 else 0
	var atlas := _get_resource_atlas()
	if atlas == null:
		sprite.visible = false
		return
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = atlas
	atlas_texture.region = Rect2(
		Vector2(float(column), float(row)) * RESOURCE_ATLAS_CELL_SIZE,
		RESOURCE_ATLAS_CELL_SIZE
	)
	sprite.texture = atlas_texture
	sprite.scale = Vector2.ONE * _get_visual_scale()
	sprite.visible = true


func _get_resource_atlas() -> ImageTexture:
	if shared_resource_atlas != null:
		return shared_resource_atlas
	var image := Image.new()
	var load_error := image.load_svg_from_buffer(FileAccess.get_file_as_bytes(RESOURCE_ATLAS_PATH))
	if load_error != OK or image.is_empty():
		return null
	shared_resource_atlas = ImageTexture.create_from_image(image)
	return shared_resource_atlas


func _get_visual_sprite() -> Sprite2D:
	if visual_sprite != null:
		return visual_sprite
	visual_sprite = get_node_or_null("VisualSprite") as Sprite2D
	return visual_sprite


func consume_by_creature(_consumer: Node, _consumption_rate: float = 1.0) -> float:
	if resource_kind == "meat_drop":
		return _consume_meat_by_creature(_consumer)
	if not is_edible_by_herbivores:
		return 0.0
	var consumed_value: float = food_value * max(_get_growth_ratio(), 0.25)
	if _uses_regrowth():
		growth_stage = max(growth_stage - 1, 0)
		growth_progress = 0.0
		days_since_harvested = 0.0
		days_to_next_stage = _get_days_to_next_stage()
		is_harvested = growth_stage <= 0
		_apply_growth_stage()
	else:
		queue_free()
	return consumed_value


func _consume_meat_by_creature(consumer: Node) -> float:
	if amount <= 0:
		return 0.0
	var consumed_value: float = max(food_value, float(GAME_BALANCE.ANIMAL_AI.get("meat_food_value", 0.65)))
	amount = max(amount - 1, 0)
	_emit_game_event("meat_consumed_by_creature", {
		"consumer": str(consumer.name) if is_instance_valid(consumer) else "creature",
		"amount": 1,
		"remaining": amount,
		"position": global_position
	})
	if amount <= 0:
		queue_free()
	else:
		queue_redraw()
	return consumed_value


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
		"conifer_tree", "leafy_tree", "dry_tree":
			return float(GAME_BALANCE.RESOURCE_REGROWTH.get("tree_regrowth_time_days", 3))
		"bush", "small_bush", "berry_bush":
			return float(GAME_BALANCE.RESOURCE_REGROWTH.get("bush_regrowth_time_days", 2))
		"dry_bush":
			return float(GAME_BALANCE.RESOURCE_REGROWTH.get("dry_bush_regrowth_time_days", 3))
		"grass_patch", "dense_grass":
			return float(GAME_BALANCE.RESOURCE_REGROWTH.get("grass_regrowth_time_days", 1))
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
	return resource_kind in [
		"conifer_tree",
		"leafy_tree",
		"dry_tree",
		"bush",
		"dry_bush",
		"small_bush",
		"berry_bush",
		"grass_patch",
		"dense_grass"
	]


func _get_resource_label() -> String:
	return str(resource_kind).replace("_", " ")


func is_render_only_resource() -> bool:
	return render_only


func set_visibility_culled(is_visible: bool) -> void:
	visible = is_visible
	_sync_collision_state(is_visible)


func _is_render_only_kind() -> bool:
	return resource_kind in ["grass_patch", "dense_grass"]


func _sync_resource_groups() -> void:
	for group_name in ["trees", "bushes", "grass", "rocks", "vegetation", "edible_vegetation", "pond_vegetation", "meat_drops"]:
		if is_in_group(group_name):
			remove_from_group(group_name)
	match resource_kind:
		"conifer_tree", "leafy_tree", "dry_tree":
			add_to_group("trees")
			add_to_group("vegetation")
		"bush", "dry_bush", "small_bush", "berry_bush":
			add_to_group("bushes")
			add_to_group("vegetation")
		"grass_patch", "dense_grass":
			add_to_group("grass")
			add_to_group("vegetation")
		"rock":
			add_to_group("rocks")
		"meat_drop":
			add_to_group("meat_drops")
	if is_edible_by_herbivores:
		add_to_group("edible_vegetation")
	if is_pond_vegetation:
		add_to_group("pond_vegetation")


func _vector_to_data(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


func _emit_plant_resource_harvested() -> void:
	var biomass_impact := _get_biomass_impact()
	if biomass_impact <= 0.0:
		return
	var biome_id := _get_biome_id_for_position(global_position)
	if biome_id.is_empty():
		return
	_emit_game_event("plant_resource_harvested", {
		"resource_type": resource_kind,
		"biome_id": biome_id,
		"position": global_position,
		"biomass_impact": biomass_impact
	})


func _get_biomass_impact() -> float:
	match resource_kind:
		"conifer_tree", "leafy_tree", "dry_tree":
			return float(GAME_BALANCE.ECOSYSTEM["tree_biomass_impact"])
		"bush":
			return float(GAME_BALANCE.ECOSYSTEM["bush_biomass_impact"])
		"small_bush":
			return float(GAME_BALANCE.ECOSYSTEM["small_bush_biomass_impact"])
		"berry_bush":
			return float(GAME_BALANCE.ECOSYSTEM["berry_bush_biomass_impact"])
		"dry_bush":
			return float(GAME_BALANCE.ECOSYSTEM["dry_bush_biomass_impact"])
		"grass_patch", "dense_grass":
			return float(GAME_BALANCE.ECOSYSTEM["grass_biomass_impact"])
	return 0.0


func _get_default_herbivore_food_value() -> float:
	match resource_kind:
		"conifer_tree", "leafy_tree":
			return float(GAME_BALANCE.ANIMAL_AI.get("tree_food_value", 0.10))
		"dry_tree":
			return 0.0
		"bush":
			return float(GAME_BALANCE.ANIMAL_AI.get("bush_food_value", 0.45))
		"dry_bush":
			return float(GAME_BALANCE.ANIMAL_AI.get("bush_food_value", 0.45)) * 0.45
		"small_bush":
			return float(GAME_BALANCE.ANIMAL_AI.get("bush_food_value", 0.45)) * 0.65
		"berry_bush":
			return float(GAME_BALANCE.ANIMAL_AI.get("bush_food_value", 0.45)) * 0.9
		"grass_patch":
			return float(GAME_BALANCE.ANIMAL_AI.get("grass_food_value", 0.2))
		"dense_grass":
			return float(GAME_BALANCE.ANIMAL_AI.get("grass_food_value", 0.2)) * 1.5
	return 0.0


func _sync_collision_shape_radius() -> void:
	var shape := _get_collision_shape()
	if shape == null:
		return
	var circle := shape.shape as CircleShape2D
	if circle == null:
		return
	circle.radius = max(radius, 5.0)


func _get_collision_shape() -> CollisionShape2D:
	if collision_shape != null:
		return collision_shape
	collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	return collision_shape


func _sync_collision_state(is_visible: bool) -> void:
	var shape := _get_collision_shape()
	if shape == null:
		return
	shape.disabled = (not is_visible) or render_only or not player_harvestable or not can_be_harvested


func _get_biome_id_for_position(position: Vector2) -> String:
	for biome in WORLD_CONFIG.get_biome_zones():
		if Geometry2D.is_point_in_polygon(position, PackedVector2Array(biome["points"])):
			return _get_biome_id(biome)
	return ""


func _get_biome_id(biome: Dictionary) -> String:
	return str(biome.get("name", "biome")).to_snake_case()


func _draw() -> void:
	var sprite := _get_visual_sprite()
	if sprite != null and sprite.texture != null:
		return
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
		"small_bush":
			_draw_small_bush()
		"berry_bush":
			_draw_berry_bush()
		"grass_patch":
			_draw_grass_patch()
		"dense_grass":
			_draw_dense_grass()
		"rock":
			_draw_rock()
		"meat_drop":
			_draw_meat_drop()
		"bone_drop":
			_draw_bone_drop()
		_:
			_draw_bush()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_depleted_plant() -> void:
	match resource_kind:
		"conifer_tree", "leafy_tree", "dry_tree":
			draw_rect(Rect2(-5, -2, 10, 14), Color(0.34, 0.19, 0.09), true)
			draw_circle(Vector2.ZERO, 13.0, Color(0.17, 0.11, 0.06, 0.26))
		"bush", "dry_bush", "small_bush", "berry_bush":
			draw_line(Vector2(-12, 8), Vector2(12, -6), Color(0.33, 0.24, 0.10), 2.0)
			draw_line(Vector2(12, 8), Vector2(-12, -5), Color(0.31, 0.22, 0.10), 2.0)
			draw_circle(Vector2.ZERO, 10.0, Color(0.14, 0.12, 0.08, 0.20))
		"grass_patch", "dense_grass":
			for i in 7:
				var angle := -PI * 0.82 + float(i) * PI * 0.27
				var tip := Vector2(cos(angle) * 8.0, sin(angle) * 8.0)
				draw_line(Vector2(0, 7), tip, Color(0.18, 0.32, 0.10, 0.45), 1.5)


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


func _draw_small_bush() -> void:
	draw_circle(Vector2(-6, 3), 8.0, Color(0.26, 0.58, 0.16))
	draw_circle(Vector2(3, -3), 9.0, Color(0.36, 0.76, 0.20))
	draw_circle(Vector2(8, 5), 7.0, Color(0.22, 0.50, 0.14))
	draw_line(Vector2(-10, 7), Vector2(10, 7), Color(0.11, 0.24, 0.09), 1.5)


func _draw_berry_bush() -> void:
	_draw_small_bush()
	var berry_color := Color(0.77, 0.12, 0.18)
	draw_circle(Vector2(-4, -3), 2.0, berry_color)
	draw_circle(Vector2(5, 1), 2.0, berry_color.darkened(0.08))
	draw_circle(Vector2(1, 6), 1.7, berry_color.lightened(0.06))


func _draw_grass_patch() -> void:
	for i in 6:
		var offset := -6.0 + float(i) * 2.4
		var height := 8.0 + float(i % 3) * 2.0
		draw_line(Vector2(offset, 7), Vector2(offset + sin(float(i)) * 3.0, 7 - height), Color(0.28, 0.70, 0.22), 1.6)
	draw_circle(Vector2.ZERO, 8.0, Color(0.12, 0.30, 0.09, 0.12))


func _draw_dense_grass() -> void:
	for i in 12:
		var offset := -10.0 + float(i) * 1.8
		var height := 9.0 + float((i * 2) % 5) * 2.0
		var sway := sin(float(i) * 1.7) * 4.0
		draw_line(Vector2(offset, 10), Vector2(offset + sway, 10 - height), Color(0.22, 0.62, 0.18), 1.8)
	draw_circle(Vector2.ZERO, 12.0, Color(0.10, 0.24, 0.08, 0.16))


func _draw_rock() -> void:
	draw_polygon([Vector2(-17, 8), Vector2(-9, -13), Vector2(10, -12), Vector2(18, 5), Vector2(3, 16)], [Color(0.38, 0.39, 0.42)])
	draw_polygon([Vector2(-9, -13), Vector2(10, -12), Vector2(3, 1), Vector2(-14, 4)], [Color(0.55, 0.56, 0.60)])
	draw_line(Vector2(-5, -8), Vector2(4, 10), Color(0.22, 0.23, 0.25), 2.0)


func _draw_meat_drop() -> void:
	draw_circle(Vector2(-4, 2), 8.0, Color(0.58, 0.06, 0.05))
	draw_circle(Vector2(5, -2), 7.0, Color(0.78, 0.15, 0.12))
	draw_circle(Vector2(1, 5), 5.0, Color(0.45, 0.03, 0.03))
	draw_line(Vector2(-7, -3), Vector2(7, 6), Color(0.95, 0.62, 0.48, 0.55), 2.0)


func _draw_bone_drop() -> void:
	draw_circle(Vector2(-6, 0), 5.0, Color(0.88, 0.84, 0.76))
	draw_circle(Vector2(6, 0), 5.0, Color(0.88, 0.84, 0.76))
	draw_rect(Rect2(-6, -4, 12, 8), Color(0.94, 0.92, 0.88), true)
	draw_rect(Rect2(-3, -7, 6, 14), Color(0.80, 0.76, 0.68), true)
	draw_line(Vector2(-7, -1), Vector2(7, 1), Color(0.98, 0.98, 0.94, 0.45), 1.6)
