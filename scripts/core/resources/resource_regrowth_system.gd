extends RefCounted
class_name ResourceRegrowthSystem

const RESOURCE_DROP_TABLE := preload("res://scripts/core/resources/resource_drop_table.gd")

static func mark_harvested(state: ResourceState) -> void:
	if state == null:
		return
	if not RESOURCE_DROP_TABLE.uses_regrowth(state.resource_kind):
		return
	state.growth_stage = 0
	state.growth_progress = 0.0
	state.days_since_harvested = 0.0
	state.days_to_next_stage = RESOURCE_DROP_TABLE.get_default_regrowth_days(state.resource_kind) / float(maxi(state.max_growth_stage, 1))
	state.is_harvested = true
	state.can_be_harvested = false
	state.amount = 0

static func advance_days(state: ResourceState, days: float) -> bool:
	if state == null or not RESOURCE_DROP_TABLE.uses_regrowth(state.resource_kind):
		return false
	if state.growth_stage >= state.max_growth_stage:
		return false
	state.growth_progress += maxf(days, 0.0)
	state.days_since_harvested += maxf(days, 0.0)
	var changed := false
	while state.growth_stage < state.max_growth_stage and state.growth_progress >= state.days_to_next_stage:
		state.growth_progress -= state.days_to_next_stage
		state.growth_stage += 1
		state.days_to_next_stage = RESOURCE_DROP_TABLE.get_default_regrowth_days(state.resource_kind) / float(maxi(state.max_growth_stage, 1))
		changed = true
	state.is_harvested = state.growth_stage <= 0
	state.can_be_harvested = state.growth_stage > 0
	state.amount = RESOURCE_DROP_TABLE.get_default_yield(state.resource_kind) if state.growth_stage >= state.max_growth_stage else max(state.amount, 0)
	return changed

static func force_full_regrowth(state: ResourceState) -> void:
	if state == null:
		return
	state.growth_stage = state.max_growth_stage
	state.growth_progress = 0.0
	state.days_since_harvested = 0.0
	state.is_harvested = false
	state.can_be_harvested = true
	state.amount = RESOURCE_DROP_TABLE.get_default_yield(state.resource_kind)

static func get_growth_debug_text(state: ResourceState) -> String:
	if state == null:
		return "unknown"
	return "%s %d/%d progress %.1f/%.1f days %.1f" % [
		["depleted", "sprout", "young", "mature"][clampi(state.growth_stage, 0, 3)],
		state.growth_stage,
		state.max_growth_stage,
		state.growth_progress,
		state.days_to_next_stage,
		state.days_since_harvested
	]
