extends RefCounted
class_name ResourceNodeAdapter

const ITEM_DATABASE := preload("res://scripts/items/item_database.gd")
const RESOURCE_STATE_SCRIPT := preload("res://scripts/core/resources/resource_state.gd")
const RESOURCE_HARVEST_RULES := preload("res://scripts/core/resources/resource_harvest_rules.gd")
const RESOURCE_REGROWTH_SYSTEM := preload("res://scripts/core/resources/resource_regrowth_system.gd")

var node: Node
var state: ResourceState


func bind_resource_node(p_node: Node) -> void:
	node = p_node
	if node != null:
		var existing_state: Variant = node.get("resource_state")
		if existing_state != null and existing_state.has_method("to_save_data"):
			state = existing_state
	ensure_state()
	_push_state_reference_to_node()


func ensure_state() -> ResourceState:
	if state == null:
		state = RESOURCE_STATE_SCRIPT.new()
	return state


func set_state(p_state: ResourceState) -> void:
	state = p_state if p_state != null else RESOURCE_STATE_SCRIPT.new()
	_push_state_reference_to_node()


func sync_state_from_node() -> ResourceState:
	var resource_state := ensure_state()
	if node == null:
		return resource_state
	resource_state.resource_kind = str(node.get("resource_kind"))
	resource_state.item_id = str(node.get("item_id"))
	resource_state.amount = int(node.get("amount"))
	resource_state.mature_amount = int(node.get("mature_amount"))
	resource_state.growth_stage = int(node.get("growth_stage"))
	resource_state.max_growth_stage = int(node.get("max_growth_stage"))
	resource_state.growth_progress = float(node.get("growth_progress"))
	resource_state.days_to_next_stage = float(node.get("days_to_next_stage"))
	resource_state.days_since_harvested = float(node.get("days_since_harvested"))
	resource_state.is_harvested = bool(node.get("is_harvested"))
	resource_state.can_be_harvested = bool(node.get("can_be_harvested"))
	resource_state.player_harvestable = bool(node.get("player_harvestable"))
	resource_state.render_only = bool(node.get("render_only"))
	resource_state.is_inventory_drop = bool(node.get("is_inventory_drop"))
	resource_state.inventory_drop_item_id = ITEM_DATABASE.normalize_item_id(str(node.get("inventory_drop_item_id")))
	resource_state.biome_id = str(node.get("biome_id"))
	resource_state.pond_id = str(node.get("pond_id"))
	resource_state.food_value = float(node.get("food_value"))
	resource_state.is_edible_by_herbivores = bool(node.get("is_edible_by_herbivores"))
	_push_state_reference_to_node()
	return resource_state


func sync_node_from_state() -> void:
	if node == null or state == null:
		return
	node.set("resource_kind", state.resource_kind)
	node.set("item_id", state.item_id)
	node.set("amount", state.amount)
	node.set("mature_amount", state.mature_amount)
	node.set("growth_stage", state.growth_stage)
	node.set("max_growth_stage", state.max_growth_stage)
	node.set("growth_progress", state.growth_progress)
	node.set("days_to_next_stage", state.days_to_next_stage)
	node.set("days_since_harvested", state.days_since_harvested)
	node.set("is_harvested", state.is_harvested)
	node.set("can_be_harvested", state.can_be_harvested)
	node.set("player_harvestable", state.player_harvestable)
	node.set("render_only", state.render_only)
	node.set("is_inventory_drop", state.is_inventory_drop)
	node.set("inventory_drop_item_id", state.inventory_drop_item_id)
	node.set("biome_id", state.biome_id)
	node.set("pond_id", state.pond_id)
	node.set("food_value", state.food_value)
	node.set("is_edible_by_herbivores", state.is_edible_by_herbivores)
	_push_state_reference_to_node()


func get_prompt() -> String:
	return RESOURCE_HARVEST_RULES.get_prompt(sync_state_from_node())


func can_harvest(inventory_state: Variant = null, tool_id := "") -> bool:
	return RESOURCE_HARVEST_RULES.can_harvest(sync_state_from_node(), inventory_state, tool_id)


func get_block_reason(inventory_state: Variant = null, tool_id := "") -> String:
	return RESOURCE_HARVEST_RULES.get_block_reason(sync_state_from_node(), inventory_state, tool_id)


func harvest(player: Node, tool_id := ""):
	var player_inventory: Variant = null
	if player != null:
		player_inventory = player.get("inventory")
	var result = RESOURCE_HARVEST_RULES.harvest(sync_state_from_node(), player_inventory, tool_id)
	sync_node_from_state()
	return result


func advance_growth_days(days: float) -> bool:
	var changed := RESOURCE_REGROWTH_SYSTEM.advance_days(sync_state_from_node(), days)
	sync_node_from_state()
	return changed


func mark_harvested() -> void:
	RESOURCE_REGROWTH_SYSTEM.mark_harvested(sync_state_from_node())
	sync_node_from_state()


func force_full_regrowth() -> void:
	RESOURCE_REGROWTH_SYSTEM.force_full_regrowth(sync_state_from_node())
	sync_node_from_state()


func restore_from_data(data: Dictionary) -> ResourceState:
	state = RESOURCE_STATE_SCRIPT.from_save_data(data)
	sync_node_from_state()
	return state


func build_save_data(position: Vector2, extra_data: Dictionary = {}) -> Dictionary:
	var data := sync_state_from_node().to_save_data()
	data["position"] = {"x": position.x, "y": position.y}
	for key in extra_data.keys():
		data[key] = extra_data[key]
	return data


func is_player_interactable(is_visible: bool) -> bool:
	var resource_state := sync_state_from_node()
	if resource_state.resource_kind in ["meat_drop", "bone_drop", "item_drop"] or resource_state.is_inventory_drop:
		return resource_state.amount > 0 and is_visible
	if not resource_state.player_harvestable:
		return false
	if not resource_state.can_be_harvested:
		return false
	if resource_state.amount <= 0:
		return false
	return is_visible


func is_depleted() -> bool:
	return sync_state_from_node().is_depleted()


func uses_regrowth() -> bool:
	return sync_state_from_node().uses_regrowth()


func consume_by_creature(consumption_rate: float = 1.0) -> Dictionary:
	var resource_state := sync_state_from_node()
	if resource_state.resource_kind == "meat_drop":
		return _consume_meat_by_creature_state(resource_state)
	if not resource_state.is_edible_by_herbivores:
		return _empty_consume_result()
	if resource_state.food_value <= 0.0:
		return _empty_consume_result()
	var growth_ratio: float = float(resource_state.growth_stage) / float(maxi(resource_state.max_growth_stage, 1))
	var consumed_value: float = resource_state.food_value * maxf(growth_ratio, 0.25) * maxf(consumption_rate, 0.0)
	if resource_state.uses_regrowth():
		resource_state.growth_stage = maxi(resource_state.growth_stage - 1, 0)
		resource_state.growth_progress = 0.0
		resource_state.days_since_harvested = 0.0
		resource_state.is_harvested = resource_state.growth_stage <= 0
		resource_state.can_be_harvested = resource_state.growth_stage > 0
	else:
		resource_state.amount = 0
	sync_node_from_state()
	return {
		"consumed_value": consumed_value,
		"remaining": resource_state.amount,
		"depleted": resource_state.is_depleted(),
		"event_name": "",
		"event_payload": {}
	}


func _consume_meat_by_creature_state(resource_state: ResourceState) -> Dictionary:
	if resource_state.amount <= 0:
		return _empty_consume_result()
	var consumed_value: float = maxf(resource_state.food_value, 0.65)
	resource_state.amount = maxi(resource_state.amount - 1, 0)
	sync_node_from_state()
	return {
		"consumed_value": consumed_value,
		"remaining": resource_state.amount,
		"depleted": resource_state.amount <= 0,
		"event_name": "meat_consumed_by_creature",
		"event_payload": {
			"amount": 1,
			"remaining": resource_state.amount
		}
	}


func _empty_consume_result() -> Dictionary:
	return {
		"consumed_value": 0.0,
		"remaining": ensure_state().amount,
		"depleted": false,
		"event_name": "",
		"event_payload": {}
	}


func get_state_data() -> Dictionary:
	return sync_state_from_node().to_save_data()


func _push_state_reference_to_node() -> void:
	if node != null:
		node.set("resource_state", state)
