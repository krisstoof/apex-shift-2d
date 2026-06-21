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
		"days_per_growth_stage": days_per_growth_stage
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


static func from_save_data(data: Dictionary) -> ResourceState:
	return from_dictionary(data)
