extends StaticBody2D

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")
const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const VEGETATION_CATALOG := preload("res://scripts/world/vegetation_catalog.gd")
const ITEM_DATABASE := preload("res://scripts/items/item_database.gd")
const RESOURCE_STATE_SCRIPT := preload("res://scripts/core/resources/resource_state.gd")
const RESOURCE_HARVEST_RULES := preload("res://scripts/core/resources/resource_harvest_rules.gd")
const RESOURCE_REGROWTH_SYSTEM := preload("res://scripts/core/resources/resource_regrowth_system.gd")
const RESOURCE_DROP_TABLE := preload("res://scripts/core/resources/resource_drop_table.gd")
const RESOURCE_NODE_ADAPTER_SCRIPT := preload("res://scripts/world/adapters/resource_node_adapter.gd")
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
var item_id := ""
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
var interaction_active := false
var is_pond_vegetation := false
var pond_id := ""
var food_bonus_multiplier := 1.0
var pond_visual_multiplier := 1.0
var biome_id := ""
var is_visibility_culled := false
var is_inventory_drop := false
var inventory_drop_item_id := ""
var resource_state: ResourceState
var resource_adapter: ResourceNodeAdapter
# Pool state stays set while the node lives in the pool so release/acquire can reuse it safely.
var is_pooled := false
var pool_key := ""
var pool_release_callback := Callable()


func _get_event_bus() -> Node:
	if not is_inside_tree():
		return null

	var tree := get_tree()
	if tree == null or tree.root == null:
		return null

	return tree.root.get_node_or_null("EventBus")


func _ensure_resource_state() -> ResourceState:
	return _ensure_resource_adapter().ensure_state()


func _ensure_resource_adapter() -> ResourceNodeAdapter:
	if resource_adapter == null:
		resource_adapter = RESOURCE_NODE_ADAPTER_SCRIPT.new()
		resource_adapter.bind_resource_node(self)
	return resource_adapter


func _sync_state_from_node() -> void:
	var state := _ensure_resource_adapter().sync_state_from_node()
	resource_state = state


func _sync_node_from_state() -> void:
	_ensure_resource_adapter().sync_node_from_state()


func _configure_resource_state(kind: String) -> void:
	var state := _ensure_resource_state()
	resource_kind = "conifer_tree" if kind == "tree" else kind
	item_id = ""
	state.resource_kind = resource_kind
	state.amount = RESOURCE_DROP_TABLE.get_default_yield(resource_kind)
	amount = state.amount
	state.growth_stage = 3
	state.max_growth_stage = 3
	state.biome_id = biome_id
	growth_stage = state.growth_stage
	max_growth_stage = state.max_growth_stage
	days_to_next_stage = maxf(RESOURCE_DROP_TABLE.get_default_regrowth_days(resource_kind) / float(maxi(state.max_growth_stage, 1)), 0.1)
	days_since_harvested = 0.0
	is_harvested = false
	can_be_harvested = true
	player_harvestable = true
	render_only = false
	is_inventory_drop = false
	inventory_drop_item_id = ""
	food_value = 0.0
	is_edible_by_herbivores = false
	match kind:
		"tree", "conifer_tree":
			item_id = "wood"
			mature_amount = 4
			amount = mature_amount
			mature_color = Color(0.08, 0.36, 0.16)
			mature_radius = 24.0
			food_value = float(GAME_BALANCE.ANIMAL_AI.get("tree_food_value", 0.10))
		"leafy_tree":
			item_id = "wood"
			mature_amount = 4
			amount = mature_amount
			mature_color = Color(0.16, 0.52, 0.18)
			mature_radius = 24.0
			food_value = float(GAME_BALANCE.ANIMAL_AI.get("tree_food_value", 0.10))
		"dry_tree":
			item_id = "wood"
			mature_amount = 3
			amount = mature_amount
			mature_color = Color(0.60, 0.44, 0.20)
			mature_radius = 22.0
		"rock":
			item_id = "stone"
			mature_amount = 2
			amount = mature_amount
			mature_color = Color(0.45, 0.45, 0.5)
			mature_radius = 15.0
		"meat_drop":
			item_id = "meat"
			mature_amount = 1
			amount = 1
			mature_color = Color(0.72, 0.12, 0.10)
			mature_radius = 10.0
			food_value = float(GAME_BALANCE.ANIMAL_AI.get("meat_food_value", 0.65))
		"bone_drop":
			item_id = "bone"
			mature_amount = 1
			amount = 1
			mature_color = Color(0.82, 0.78, 0.70)
			mature_radius = 9.0
		"item_drop":
			is_inventory_drop = true
			mature_amount = 1
			amount = 1
			mature_color = Color(0.82, 0.76, 0.42)
			mature_radius = 10.0
		"bush":
			item_id = "fiber"
			mature_amount = 2
			amount = mature_amount
			mature_color = Color(0.45, 0.9, 0.28)
			mature_radius = 13.0
			food_value = float(GAME_BALANCE.ANIMAL_AI.get("bush_food_value", 0.45))
		"dry_bush":
			item_id = "fiber"
			mature_amount = 1
			amount = mature_amount
			mature_color = Color(0.68, 0.54, 0.26)
			mature_radius = 14.0
			food_value = float(GAME_BALANCE.ANIMAL_AI.get("bush_food_value", 0.45)) * 0.45
		"small_bush":
			item_id = "fiber"
			mature_amount = 1
			amount = mature_amount
			mature_color = Color(0.34, 0.74, 0.20)
			mature_radius = 10.0
			food_value = float(GAME_BALANCE.ANIMAL_AI.get("bush_food_value", 0.45)) * 0.65
		"berry_bush":
			item_id = "berries"
			mature_amount = 1
			amount = mature_amount
			player_harvestable = false
			mature_color = Color(0.25, 0.64, 0.23)
			mature_radius = 12.0
			food_value = float(GAME_BALANCE.ANIMAL_AI.get("bush_food_value", 0.45)) * 0.9
		"grass_patch":
			item_id = "grass"
			mature_amount = 1
			amount = mature_amount
			player_harvestable = false
			render_only = true
			mature_color = Color(0.34, 0.78, 0.27)
			mature_radius = 8.0
			food_value = float(GAME_BALANCE.ANIMAL_AI.get("grass_food_value", 0.2))
		"dense_grass":
			item_id = "grass"
			mature_amount = 1
			amount = mature_amount
			player_harvestable = false
			render_only = true
			mature_color = Color(0.25, 0.68, 0.20)
			mature_radius = 12.0
			food_value = float(GAME_BALANCE.ANIMAL_AI.get("grass_food_value", 0.2)) * 1.5
	is_edible_by_herbivores = resource_kind != "meat_drop" and food_value > 0.0
	can_be_harvested = player_harvestable


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
	is_visibility_culled = true
	interaction_active = false
	_apply_growth_stage()
	_sync_resource_groups()
	_sync_visual_sprite()
	_sync_collision_state()
	queue_redraw()


func setup(kind: String) -> void:
	resource_kind = "conifer_tree" if kind == "tree" else kind
	_configure_resource_state(kind)
	biome_id = _get_biome_id_for_position(global_position)
	_sync_node_from_state()
	_apply_growth_stage()
	_sync_resource_groups()
	queue_redraw()


func interact(player: Node) -> void:
	_sync_state_from_node()
	if not interaction_active and not is_visibility_culled and not render_only and player_harvestable and can_be_harvested:
		interaction_active = true
		_sync_collision_state()
		_sync_runtime_process_state()
	var player_inventory: Variant = player.get("inventory")
	var result := RESOURCE_HARVEST_RULES.harvest(resource_state, player_inventory)
	if not result.success:
		_post_event_message(result.message)
		return
	_sync_node_from_state()
	_post_event_message(result.message)
	if not result.emitted_event_name.is_empty():
		var payload := result.emitted_event_payload.duplicate(true)
		payload["position"] = global_position
		_emit_game_event(result.emitted_event_name, payload)
	if result.should_start_regrowth:
		_mark_harvested()
	elif result.should_remove_node:
		_release_or_free()
	else:
		queue_redraw()


func get_prompt() -> String:
	_sync_state_from_node()
	return RESOURCE_HARVEST_RULES.get_prompt(resource_state)


func is_player_interactable() -> bool:
	if resource_kind == "meat_drop" or resource_kind == "bone_drop" or resource_kind == "item_drop" or is_inventory_drop:
		if amount <= 0:
			return false
		if not visible:
			return false
		return true
	if not player_harvestable:
		return false
	if not can_be_harvested:
		return false
	if amount <= 0:
		return false
	if not visible:
		return false
	return true


func get_pickup_priority() -> int:
	match resource_kind:
		"meat_drop":
			return 100
		"bone_drop":
			return 90
		"item_drop":
			return 80
	return 10


func get_save_data() -> Dictionary:
	_sync_state_from_node()
	var data := resource_state.to_save_data()
	data["position"] = _vector_to_data(global_position)
	data["food_bonus_multiplier"] = food_bonus_multiplier
	data["pond_visual_multiplier"] = pond_visual_multiplier
	data["item_name"] = item_name
	data["kind"] = resource_kind
	data["render_only"] = render_only
	return data


func restore_from_data(data: Dictionary) -> void:
	resource_state = RESOURCE_STATE_SCRIPT.from_save_data(data)
	resource_kind = resource_state.resource_kind
	item_id = resource_state.item_id
	amount = resource_state.amount
	mature_amount = resource_state.mature_amount
	growth_stage = resource_state.growth_stage
	max_growth_stage = resource_state.max_growth_stage
	growth_progress = resource_state.growth_progress
	days_to_next_stage = resource_state.days_to_next_stage
	days_since_harvested = resource_state.days_since_harvested
	is_harvested = resource_state.is_harvested
	can_be_harvested = resource_state.can_be_harvested
	player_harvestable = resource_state.player_harvestable
	render_only = resource_state.render_only
	is_inventory_drop = resource_state.is_inventory_drop
	inventory_drop_item_id = resource_state.inventory_drop_item_id
	biome_id = resource_state.biome_id
	pond_id = resource_state.pond_id
	food_value = resource_state.food_value
	is_edible_by_herbivores = resource_state.is_edible_by_herbivores
	_apply_pond_visual_bonus()
	_sync_resource_groups()
	_apply_growth_stage()


func advance_growth_days(days: float) -> bool:
	_sync_state_from_node()
	var changed := RESOURCE_REGROWTH_SYSTEM.advance_days(resource_state, days)
	_sync_node_from_state()
	_apply_growth_stage()
	return changed


func force_full_regrowth() -> void:
	_sync_state_from_node()
	RESOURCE_REGROWTH_SYSTEM.force_full_regrowth(resource_state)
	_sync_node_from_state()
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
	_sync_state_from_node()
	return RESOURCE_REGROWTH_SYSTEM.get_growth_debug_text(resource_state)


func _mark_harvested() -> void:
	_sync_state_from_node()
	RESOURCE_REGROWTH_SYSTEM.mark_harvested(resource_state)
	_sync_node_from_state()
	_apply_growth_stage()


func _apply_growth_stage() -> void:
	_sync_state_from_node()
	if resource_state.uses_regrowth() and growth_stage <= 0:
		can_be_harvested = false
		is_edible_by_herbivores = false
		amount = 0
	else:
		var can_be_harvestable = player_harvestable
		can_be_harvested = can_be_harvestable
		is_edible_by_herbivores = resource_kind != "meat_drop" and food_value > 0.0
		amount = RESOURCE_DROP_TABLE.get_default_yield(resource_kind) if amount <= 0 else amount
	resource_state.can_be_harvested = can_be_harvested
	resource_state.is_edible_by_herbivores = is_edible_by_herbivores
	resource_state.amount = amount
	color = mature_color.darkened(0.45 if growth_stage <= 0 else 0.0).lerp(mature_color, _get_growth_ratio())
	radius = max(mature_radius * _get_visual_scale(), 5.0)
	_sync_collision_shape_radius()
	_sync_collision_state()
	_sync_resource_groups()
	_sync_visual_sprite()
	queue_redraw()


func _sync_visual_sprite() -> void:
	var sprite := _get_visual_sprite()
	if sprite == null:
		return
	if is_inventory_drop:
		sprite.visible = false
		sprite.texture = null
		return
	if resource_kind == "bone_drop":
		sprite.visible = false
		sprite.texture = null
		return
	if resource_kind == "item_drop":
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
	if not is_edible_vegetation():
		return 0.0
	if not is_edible_by_herbivores:
		return 0.0
	var consumed_value: float = food_value * max(_get_growth_ratio(), 0.25)
	if resource_state == null:
		_sync_state_from_node()
	if resource_state.uses_regrowth():
		resource_state.growth_stage = max(resource_state.growth_stage - 1, 0)
		resource_state.growth_progress = 0.0
		resource_state.days_since_harvested = 0.0
		resource_state.is_harvested = resource_state.growth_stage <= 0
		resource_state.can_be_harvested = resource_state.growth_stage > 0
		_sync_node_from_state()
		_apply_growth_stage()
	else:
		queue_free()
	return consumed_value


func _consume_meat_by_creature(consumer: Node) -> float:
	if amount <= 0:
		return 0.0
	var consumed_value: float = max(food_value, float(GAME_BALANCE.ANIMAL_AI.get("meat_food_value", 0.65)))
	amount = max(amount - 1, 0)
	if resource_state != null:
		resource_state.amount = amount
	_emit_game_event("meat_consumed_by_creature", {
		"consumer": str(consumer.name) if is_instance_valid(consumer) else "creature",
		"amount": 1,
		"remaining": amount,
		"position": global_position
	})
	if amount <= 0:
		_release_or_free()
	else:
		queue_redraw()
	return consumed_value


func activate_from_pool(data: Dictionary) -> void:
	is_pooled = true
	pool_key = str(data.get("pool_key", pool_key))
	pool_release_callback = data.get("release_callback", Callable())

	var spawn_position := Vector2(data.get("position", global_position))
	global_position = spawn_position

	var kind := str(data.get("resource_kind", data.get("kind", resource_kind)))
	setup(kind)

	if data.has("loot_amount"):
		set_loot_amount(int(data.get("loot_amount", 1)))

	if not is_in_group("resources"):
		add_to_group("resources")

	visible = true
	set_process(true)
	set_physics_process(true)
	is_visibility_culled = false
	_sync_collision_state()
	queue_redraw()


func reset_for_pool() -> void:
	visible = false
	set_process(false)
	set_physics_process(false)
	is_visibility_culled = true
	_sync_collision_state()
	_remove_resource_pool_groups()

	amount = 0
	mature_amount = 0
	growth_stage = max_growth_stage
	growth_progress = 0.0
	days_since_harvested = 0.0
	is_harvested = false
	can_be_harvested = false
	player_harvestable = false
	is_edible_by_herbivores = false
	food_value = 0.0
	render_only = false
	is_pond_vegetation = false
	pond_id = ""
	food_bonus_multiplier = 1.0
	pond_visual_multiplier = 1.0
	biome_id = ""
	is_visibility_culled = true
	pool_release_callback = Callable()
	queue_redraw()


func _remove_resource_pool_groups() -> void:
	for group_name in [
		"resources",
		"trees",
		"bushes",
		"grass",
		"rocks",
		"vegetation",
		"edible_vegetation",
		"pond_vegetation",
		"meat_drops"
	]:
		if is_in_group(group_name):
			remove_from_group(group_name)


func _release_or_free() -> void:
	if is_pooled and pool_release_callback.is_valid():
		pool_release_callback.call(self)
	else:
		queue_free()


func _get_stage_yield() -> int:
	return RESOURCE_DROP_TABLE.get_default_yield(resource_kind)


func _get_stage_yield_multiplier() -> float:
	return 1.0


func _get_growth_stage_name() -> String:
	var stages: Array = GAME_BALANCE.RESOURCE_REGROWTH.get("stages", ["depleted", "sprout", "young", "mature"])
	return str(stages[clamp(growth_stage, 0, stages.size() - 1)])


func _get_days_to_next_stage() -> float:
	var total_days := _get_regrowth_time_days()
	return max(total_days / float(max_growth_stage), 0.1)


func _get_regrowth_time_days() -> float:
	return RESOURCE_DROP_TABLE.get_default_regrowth_days(resource_kind)


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
	return RESOURCE_DROP_TABLE.uses_regrowth(resource_kind)


func _get_resource_label() -> String:
	return str(resource_kind).replace("_", " ")


func _interact_item_drop(player: Node) -> void:
	_interact_full_stack_drop(player)


func setup_dropped_item(p_item_id: String, p_amount: int) -> void:
	is_inventory_drop = true
	inventory_drop_item_id = ITEM_DATABASE.normalize_item_id(p_item_id)
	resource_kind = "inventory_drop"
	item_name = inventory_drop_item_id
	amount = max(1, p_amount)
	mature_amount = amount
	can_be_harvested = true
	player_harvestable = true
	render_only = false
	is_harvested = false
	growth_stage = max_growth_stage
	z_index = 20
	var accent := ITEM_DATABASE.get_accent_color(inventory_drop_item_id)
	color = accent
	mature_color = accent
	radius = 14.0
	mature_radius = 14.0
	_sync_resource_groups()
	_sync_visual_sprite()
	queue_redraw()


func _interact_inventory_drop(player: Node) -> void:
	if player == null:
		return
	var player_inventory: Variant = player.get("inventory")
	if player_inventory == null:
		return
	var normalized_item_id := ITEM_DATABASE.normalize_item_id(item_name)
	item_name = normalized_item_id
	inventory_drop_item_id = normalized_item_id
	if player_inventory.has_method("can_add_item") and not player_inventory.call("can_add_item", normalized_item_id, amount):
		_post_event_message("Inventory full")
		return
	var leftover: int = int(player_inventory.call("add_item", normalized_item_id, amount))
	if leftover > 0:
		_post_event_message("Inventory full")
		return
	_post_event_message("Picked up %s x%d" % [ITEM_DATABASE.get_display_name(normalized_item_id), amount])
	_release_or_free()


func _interact_full_stack_drop(player: Node) -> void:
	var drop_item_id := _get_drop_item_id()
	if drop_item_id.is_empty() or amount <= 0:
		queue_free()
		return
	var player_inventory: Variant = player.get("inventory")
	if player_inventory == null or not player_inventory.has_method("add_item_full_stack"):
		return
	print("[PICKUP] attempt item_id=%s amount=%d kind=%s" % [drop_item_id, amount, resource_kind])
	if player_inventory.call("add_item_full_stack", drop_item_id, amount) != true:
		_post_event_message("Inventory full")
		print("[PICKUP] success=false item_id=%s amount=%d reason=inventory_full" % [drop_item_id, amount])
		return
	_post_event_message("Collected %s x%d" % [_get_drop_item_label(), amount])
	print("[PICKUP] success=true item_id=%s amount=%d" % [drop_item_id, amount])
	queue_free()


func _get_drop_item_id() -> String:
	if not inventory_drop_item_id.is_empty():
		return inventory_drop_item_id
	if not item_id.is_empty():
		return ITEM_DATABASE.normalize_item_id(item_id)
	return ITEM_DATABASE.normalize_item_id(item_name)


func _draw_inventory_drop_visual() -> void:
	var normalized_item_id := ITEM_DATABASE.normalize_item_id(item_name if not item_name.is_empty() else inventory_drop_item_id)
	var accent := ITEM_DATABASE.get_accent_color(normalized_item_id)
	var shape := ITEM_DATABASE.get_ground_shape(normalized_item_id)
	draw_circle(Vector2(3, 5), radius * 0.85, Color(0.0, 0.0, 0.0, 0.22))
	match shape:
		"log":
			_draw_log_drop(accent)
		"rock":
			_draw_rock_drop(accent)
		"grass_bundle":
			_draw_fiber_drop(accent)
		"meat_chunk":
			_draw_inventory_meat_drop(accent)
		"bone":
			_draw_inventory_bone_drop(accent)
		_:
			_draw_generic_drop(accent)


func _draw_log_drop(accent: Color) -> void:
	var dark := accent.darkened(0.35)
	draw_rect(Rect2(Vector2(-13, -5), Vector2(26, 10)), dark, true)
	draw_rect(Rect2(Vector2(-11, -7), Vector2(22, 10)), accent, true)
	draw_line(Vector2(-7, -5), Vector2(-7, 3), dark.darkened(0.2), 2.0)
	draw_line(Vector2(2, -5), Vector2(2, 3), dark.darkened(0.2), 2.0)


func _draw_rock_drop(accent: Color) -> void:
	var points := PackedVector2Array([
		Vector2(-12, 2),
		Vector2(-7, -9),
		Vector2(6, -11),
		Vector2(14, -2),
		Vector2(9, 9),
		Vector2(-5, 11)
	])
	draw_colored_polygon(points, accent)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[4], points[5], points[0]]), accent.darkened(0.4), 2.0)


func _draw_fiber_drop(accent: Color) -> void:
	var dark := accent.darkened(0.35)
	for offset in [-9, -4, 0, 5, 9]:
		draw_line(Vector2(offset, 10), Vector2(offset * 0.4, -11), accent, 3.0)
		draw_line(Vector2(offset, 10), Vector2(offset * 0.4 + 4, -5), dark, 1.6)


func _draw_inventory_meat_drop(accent: Color) -> void:
	var dark := accent.darkened(0.35)
	draw_circle(Vector2(-4, 0), 10.0, accent)
	draw_circle(Vector2(5, 2), 8.0, accent.lightened(0.08))
	draw_circle(Vector2(2, -1), 3.0, Color(0.95, 0.70, 0.62))
	draw_arc(Vector2(0, 1), 11.0, 0.2, 5.8, 20, dark, 2.0)


func _draw_inventory_bone_drop(accent: Color) -> void:
	var dark := accent.darkened(0.35)
	draw_line(Vector2(-9, 0), Vector2(9, 0), accent, 7.0)
	draw_circle(Vector2(-12, -4), 5.0, accent)
	draw_circle(Vector2(-12, 4), 5.0, accent)
	draw_circle(Vector2(12, -4), 5.0, accent)
	draw_circle(Vector2(12, 4), 5.0, accent)
	draw_line(Vector2(-9, 0), Vector2(9, 0), dark, 1.5)


func _draw_generic_drop(accent: Color) -> void:
	draw_circle(Vector2.ZERO, 11.0, accent)
	draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 24, accent.darkened(0.35), 2.0)


func _get_drop_item_label() -> String:
	return _get_drop_item_id().replace("_", " ")


func is_render_only_resource() -> bool:
	return render_only


func set_visibility_culled(should_be_visible: bool) -> void:
	var culled_state := not should_be_visible
	# Early return if state already matches
	if is_visibility_culled == culled_state:
		return
	
	is_visibility_culled = culled_state
	visible = should_be_visible
	_sync_collision_state()
	_sync_runtime_process_state()
	
	queue_redraw()


func set_interaction_active(active: bool) -> void:
	if interaction_active == active:
		return
	interaction_active = active
	_sync_collision_state()
	_sync_runtime_process_state()


func is_interaction_active() -> bool:
	return interaction_active


func _is_render_only_kind() -> bool:
	return VEGETATION_CATALOG.is_visual_only_kind(resource_kind)


func get_resource_kind() -> String:
	return str(resource_kind)


func get_biome_id() -> String:
	return str(biome_id)


func is_depleted() -> bool:
	return float(amount) <= 0.0


func is_edible_vegetation() -> bool:
	if VEGETATION_CATALOG.is_visual_only_kind(resource_kind):
		return false
	if VEGETATION_CATALOG.is_edible_node_kind(resource_kind):
		return true
	return is_in_group("edible_vegetation")


func _sync_resource_groups() -> void:
	for group_name in ["trees", "bushes", "grass", "rocks", "vegetation", "edible_vegetation", "pond_vegetation", "meat_drops", "item_drops"]:
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
		"item_drop":
			add_to_group("item_drops")
	if is_edible_by_herbivores:
		add_to_group("edible_vegetation")
	if is_pond_vegetation:
		add_to_group("pond_vegetation")


func _vector_to_data(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


func _data_to_vector(data: Variant) -> Vector2:
	if data is Dictionary:
		var position_data := data as Dictionary
		return Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)))
	return Vector2.ZERO


func _emit_plant_resource_harvested() -> void:
	var biomass_impact := _get_biomass_impact()
	if biomass_impact <= 0.0:
		return
	var target_biome_id := _get_biome_id_for_position(global_position)
	if target_biome_id.is_empty():
		return
	_emit_game_event("plant_resource_harvested", {
		"resource_type": resource_kind,
		"biome_id": target_biome_id,
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


func _sync_collision_state() -> void:
	_set_collision_state_safe(interaction_active and not is_visibility_culled)


func _sync_runtime_process_state() -> void:
	var should_process := interaction_active and visible and not render_only and player_harvestable and can_be_harvested
	if is_processing() != should_process:
		set_process(should_process)
	if is_physics_processing() != should_process:
		set_physics_process(should_process)


func _set_collision_state_safe(should_be_enabled: bool) -> void:
	var shape := _get_collision_shape()
	if shape == null:
		return
	var should_disable := (not should_be_enabled) or render_only or not player_harvestable or not can_be_harvested
	shape.set_deferred("disabled", should_disable)


func _get_biome_id_for_position(world_position: Vector2) -> String:
	var world := _get_world()
	if world != null and world.has_method("get_biome_id_at"):
		return str(world.get_biome_id_at(world_position))
	for biome in WORLD_CONFIG.get_biome_zones():
		if Geometry2D.is_point_in_polygon(world_position, PackedVector2Array(biome["points"])):
			return _get_biome_id(biome)
	return ""


func _get_biome_id(biome: Dictionary) -> String:
	var biome_id := str(biome.get("id", ""))
	if not biome_id.is_empty():
		return biome_id
	return str(biome.get("name", "biome")).to_snake_case()


func _get_world() -> Node:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.get_node_or_null("World")


func _draw() -> void:
	if is_inventory_drop:
		_draw_inventory_drop_visual()
		return
	var sprite := _get_visual_sprite()
	if sprite != null and sprite.texture != null:
		return
	if _uses_regrowth() and growth_stage <= 0:
		_draw_depleted_plant()
		return
	var visual_scale := _get_visual_scale()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(visual_scale, visual_scale))
	match resource_kind:
		"conifer_tree", "dry_tree":
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
		"item_drop":
			_draw_item_drop()
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


func _draw_item_drop() -> void:
	draw_circle(Vector2.ZERO, 9.0, Color(0.16, 0.12, 0.05, 0.24))
	draw_circle(Vector2.ZERO, 8.0, Color(0.90, 0.78, 0.34))
	draw_circle(Vector2(-2.5, -2.5), 3.0, Color(1.0, 0.93, 0.62))
	draw_line(Vector2(-6, 5), Vector2(6, -5), Color(0.32, 0.22, 0.06, 0.55), 2.0)
