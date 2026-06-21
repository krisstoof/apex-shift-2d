extends RefCounted
class_name ResourceState

var id: String = ""
var kind: String = ""
var resource_kind: String = ""
var position: Vector2 = Vector2.ZERO
var biome_id: String = ""
var amount: int = 1
var max_amount: int = 1
var growth_stage: int = 0
var max_growth_stage: int = 3
var depleted: bool = false
var regrowth_progress_days: float = 0.0
var days_per_growth_stage: float = 1.0
var item_id: String = ""
var mature_amount: int = 1
var growth_progress: float = 0.0
var days_to_next_stage: float = 1.0
var days_since_harvested: float = 0.0
var is_harvested: bool = false
var can_be_harvested: bool = true
var player_harvestable: bool = true
var render_only: bool = false
var is_inventory_drop: bool = false
var inventory_drop_item_id: String = ""
var pond_id: String = ""
var food_value: float = 0.0
var is_edible_by_herbivores: bool = false


func is_empty() -> bool:
	return id.is_empty() and kind.is_empty() and resource_kind.is_empty()


func is_fully_grown() -> bool:
	return growth_stage >= max_growth_stage


func can_regrow() -> bool:
	return max_growth_stage > 0 and growth_stage < max_growth_stage


func mark_depleted() -> void:
	depleted = true
	amount = 0
	growth_stage = 0
	regrowth_progress_days = 0.0


func to_dictionary() -> Dictionary:
	var effective_kind := kind if not kind.is_empty() else resource_kind
	return {
		"id": id,
		"kind": effective_kind,
		"resource_kind": effective_kind,
		"position": {"x": position.x, "y": position.y},
		"biome_id": biome_id,
		"amount": amount,
		"max_amount": max_amount,
		"growth_stage": growth_stage,
		"max_growth_stage": max_growth_stage,
		"depleted": depleted,
		"regrowth_progress_days": regrowth_progress_days,
		"days_per_growth_stage": days_per_growth_stage,
		"item_id": item_id,
		"mature_amount": mature_amount,
		"growth_progress": growth_progress,
		"days_to_next_stage": days_to_next_stage,
		"days_since_harvested": days_since_harvested,
		"is_harvested": is_harvested,
		"can_be_harvested": can_be_harvested,
		"player_harvestable": player_harvestable,
		"render_only": render_only,
		"is_inventory_drop": is_inventory_drop,
		"inventory_drop_item_id": inventory_drop_item_id,
		"pond_id": pond_id,
		"food_value": food_value,
		"is_edible_by_herbivores": is_edible_by_herbivores
	}


static func from_dictionary(data: Dictionary) -> ResourceState:
	var state := ResourceState.new()
	state.id = str(data.get("id", ""))
	state.kind = str(data.get("kind", data.get("resource_kind", "")))
	state.resource_kind = state.kind
	state.biome_id = str(data.get("biome_id", ""))
	var position_value: Variant = data.get("position", Vector2.ZERO)
	if position_value is Vector2:
		state.position = Vector2(position_value)
	elif typeof(position_value) == TYPE_DICTIONARY:
		var position_data := Dictionary(position_value)
		state.position = Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)))
	state.amount = int(data.get("amount", 1))
	state.max_amount = int(data.get("max_amount", max(state.amount, 1)))
	state.growth_stage = int(data.get("growth_stage", 0))
	state.max_growth_stage = int(data.get("max_growth_stage", 3))
	state.depleted = bool(data.get("depleted", false))
	state.regrowth_progress_days = float(data.get("regrowth_progress_days", 0.0))
	state.days_per_growth_stage = float(data.get("days_per_growth_stage", 1.0))
	state.item_id = str(data.get("item_id", ""))
	state.mature_amount = int(data.get("mature_amount", max(state.amount, 1)))
	state.growth_progress = float(data.get("growth_progress", 0.0))
	state.days_to_next_stage = float(data.get("days_to_next_stage", 1.0))
	state.days_since_harvested = float(data.get("days_since_harvested", 0.0))
	state.is_harvested = bool(data.get("is_harvested", false))
	state.can_be_harvested = bool(data.get("can_be_harvested", true))
	state.player_harvestable = bool(data.get("player_harvestable", true))
	state.render_only = bool(data.get("render_only", false))
	state.is_inventory_drop = bool(data.get("is_inventory_drop", false))
	state.inventory_drop_item_id = str(data.get("inventory_drop_item_id", ""))
	state.pond_id = str(data.get("pond_id", ""))
	state.food_value = float(data.get("food_value", 0.0))
	state.is_edible_by_herbivores = bool(data.get("is_edible_by_herbivores", false))
	return state


func to_save_data() -> Dictionary:
	return to_dictionary()


func load_from_save_data(data: Dictionary) -> void:
	var other := ResourceState.from_dictionary(data)
	id = other.id
	kind = other.kind
	resource_kind = other.resource_kind
	position = other.position
	biome_id = other.biome_id
	amount = other.amount
	max_amount = other.max_amount
	growth_stage = other.growth_stage
	max_growth_stage = other.max_growth_stage
	depleted = other.depleted
	regrowth_progress_days = other.regrowth_progress_days
	days_per_growth_stage = other.days_per_growth_stage
	item_id = other.item_id
	mature_amount = other.mature_amount
	growth_progress = other.growth_progress
	days_to_next_stage = other.days_to_next_stage
	days_since_harvested = other.days_since_harvested
	is_harvested = other.is_harvested
	can_be_harvested = other.can_be_harvested
	player_harvestable = other.player_harvestable
	render_only = other.render_only
	is_inventory_drop = other.is_inventory_drop
	inventory_drop_item_id = other.inventory_drop_item_id
	pond_id = other.pond_id
	food_value = other.food_value
	is_edible_by_herbivores = other.is_edible_by_herbivores


static func from_save_data(data: Dictionary) -> ResourceState:
	return from_dictionary(data)


func uses_regrowth() -> bool:
	return resource_kind == "grass_patch" or resource_kind == "dense_grass" or resource_kind == "small_bush" or resource_kind == "berry_bush"
