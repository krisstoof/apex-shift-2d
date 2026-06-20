extends RefCounted
class_name ResourceState

const ITEM_DATABASE := preload("res://scripts/items/item_database.gd")
const RESOURCE_DROP_TABLE := preload("res://scripts/core/resources/resource_drop_table.gd")

var resource_kind := "conifer_tree"
var item_id := ""
var amount := 2
var mature_amount := 2
var growth_stage := 3
var max_growth_stage := 3
var growth_progress := 0.0
var days_to_next_stage := 1.0
var days_since_harvested := 0.0
var is_harvested := false
var can_be_harvested := true
var player_harvestable := true
var render_only := false
var is_inventory_drop := false
var inventory_drop_item_id := ""
var biome_id := ""
var pond_id := ""
var food_value := 0.0
var is_edible_by_herbivores := false

func to_save_data() -> Dictionary:
	return {
		"kind": resource_kind,
		"item_id": item_id,
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
		"render_only": render_only,
		"is_inventory_drop": is_inventory_drop,
		"inventory_drop_item_id": inventory_drop_item_id,
		"biome_id": biome_id,
		"pond_id": pond_id,
		"food_value": food_value,
		"is_edible_by_herbivores": is_edible_by_herbivores
	}

static func from_save_data(data: Dictionary) -> ResourceState:
	var state := ResourceState.new()
	state.resource_kind = str(data.get("kind", data.get("resource_kind", state.resource_kind)))
	state.item_id = str(data.get("item_id", state.item_id))
	state.amount = int(data.get("amount", state.amount))
	state.mature_amount = int(data.get("mature_amount", state.mature_amount))
	state.growth_stage = int(data.get("growth_stage", state.growth_stage))
	state.max_growth_stage = int(data.get("max_growth_stage", state.max_growth_stage))
	state.growth_progress = float(data.get("growth_progress", state.growth_progress))
	state.days_to_next_stage = float(data.get("days_to_next_stage", state.days_to_next_stage))
	state.days_since_harvested = float(data.get("days_since_harvested", state.days_since_harvested))
	state.is_harvested = bool(data.get("is_harvested", state.is_harvested))
	state.can_be_harvested = bool(data.get("can_be_harvested", state.can_be_harvested))
	state.player_harvestable = bool(data.get("player_harvestable", state.player_harvestable))
	state.render_only = bool(data.get("render_only", state.render_only))
	state.is_inventory_drop = bool(data.get("is_inventory_drop", state.is_inventory_drop))
	state.inventory_drop_item_id = ITEM_DATABASE.normalize_item_id(str(data.get("inventory_drop_item_id", state.inventory_drop_item_id)))
	state.biome_id = str(data.get("biome_id", state.biome_id))
	state.pond_id = str(data.get("pond_id", state.pond_id))
	state.food_value = float(data.get("food_value", state.food_value))
	state.is_edible_by_herbivores = bool(data.get("is_edible_by_herbivores", state.is_edible_by_herbivores))
	return state

func is_drop() -> bool:
	return is_inventory_drop or resource_kind in ["meat_drop", "bone_drop", "item_drop"]

func is_depleted() -> bool:
	return amount <= 0 or (uses_regrowth() and growth_stage <= 0)

func uses_regrowth() -> bool:
	return RESOURCE_DROP_TABLE.uses_regrowth(resource_kind)
