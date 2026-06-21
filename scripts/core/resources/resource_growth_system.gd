extends RefCounted
class_name ResourceGrowthSystem


func advance_growth_days(resource_states: Array, days: float) -> int:
	if days <= 0.0:
		return 0
	var changed_count := 0
	for state_value in resource_states:
		var state := state_value as ResourceState
		if state == null:
			continue
		if _advance_state_growth(state, days):
			changed_count += 1
	return changed_count


func force_full_regrowth(resource_states: Array) -> int:
	var changed_count := 0
	for state_value in resource_states:
		var state := state_value as ResourceState
		if state == null:
			continue
		var changed := false
		if state.growth_stage != state.max_growth_stage:
			state.growth_stage = state.max_growth_stage
			changed = true
		if state.depleted:
			state.depleted = false
			changed = true
		if state.amount <= 0:
			state.amount = max(state.max_amount, 1)
			changed = true
		state.regrowth_progress_days = 0.0
		if changed:
			changed_count += 1
	return changed_count


func reset_growth(resource_states: Array) -> int:
	var changed_count := 0
	for state_value in resource_states:
		var state := state_value as ResourceState
		if state == null:
			continue
		var changed := false
		if state.growth_stage != 0:
			state.growth_stage = 0
			changed = true
		if not state.depleted:
			state.depleted = true
			changed = true
		if state.amount != 0:
			state.amount = 0
			changed = true
		state.regrowth_progress_days = 0.0
		if changed:
			changed_count += 1
	return changed_count


func _advance_state_growth(state: ResourceState, days: float) -> bool:
	if state == null:
		return false
	if state.is_fully_grown():
		return false
	var previous_stage := state.growth_stage
	var previous_depleted := state.depleted
	var previous_amount := state.amount
	state.regrowth_progress_days += days
	var days_per_stage := maxf(state.days_per_growth_stage, 0.01)
	while state.regrowth_progress_days >= days_per_stage and state.growth_stage < state.max_growth_stage:
		state.regrowth_progress_days -= days_per_stage
		state.growth_stage += 1
	if state.growth_stage > 0:
		state.depleted = false
	if state.growth_stage >= state.max_growth_stage:
		state.amount = max(state.max_amount, 1)
	else:
		state.amount = max(state.amount, 0)
	return state.growth_stage != previous_stage or state.depleted != previous_depleted or state.amount != previous_amount
