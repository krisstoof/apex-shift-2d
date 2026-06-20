extends RefCounted
class_name VarnakBrain

const DECISION := preload("res://scripts/core/creatures/creature_decision.gd")
const CONTEXT := preload("res://scripts/core/creatures/creature_context.gd")


func decide(_state, context) -> CreatureDecision:
	var ctx := _ensure_context(context)
	if ctx.has_water_hazard:
		return DECISION.for_action(DECISION.ACTION_AVOID_WATER, "water_hazard", ctx.water_avoid_position, 0, "water")
	if ctx.has_fire_threat:
		return DECISION.for_action(DECISION.ACTION_FLEE, "active_campfire_fear", ctx.fire_threat_position, ctx.fire_threat_entity_id, "campfire")
	if ctx.has_building_hazard and ctx.building_hazard_kind == "trap":
		return DECISION.for_action(DECISION.ACTION_AVOID_BUILDING, "avoid_trap", ctx.building_hazard_position, ctx.building_hazard_entity_id, "trap")
	if _should_return_to_biome(ctx):
		return DECISION.for_action(DECISION.ACTION_RETURN_TO_BIOME, "outside_hunting_biome", ctx.return_position, 0, ctx.home_biome)
	if ctx.is_hungry() and ctx.has_meat_target and ctx.meat_in_eat_range and ctx.eat_cooldown <= 0.0:
		return DECISION.for_action(DECISION.ACTION_EAT, "hungry_meat_in_range", ctx.meat_position, ctx.meat_entity_id, "meat", {"consume": true})
	if ctx.is_hungry() and ctx.has_meat_target:
		return DECISION.for_action(DECISION.ACTION_SEEK_FOOD, "hungry_scavenge_meat", ctx.meat_position, ctx.meat_entity_id, "meat")
	if ctx.has_prey_target:
		return DECISION.for_action(DECISION.ACTION_HUNT, "hunt_drive_prey", ctx.prey_position, ctx.prey_entity_id, ctx.prey_kind, {"attack": ctx.prey_in_attack_range})
	if ctx.should_rest or ctx.energy <= 0.12:
		return DECISION.for_action(DECISION.ACTION_REST, "low_energy")
	return DECISION.for_action(DECISION.ACTION_WANDER, "default_hunt_roam")


func _should_return_to_biome(ctx: CreatureContext) -> bool:
	return not ctx.is_inside_home_biome and not ctx.home_biome.is_empty()


func _ensure_context(context) -> CreatureContext:
	if context is CreatureContext:
		return context
	if typeof(context) == TYPE_DICTIONARY:
		return CONTEXT.from_dictionary(Dictionary(context))
	return CONTEXT.new()
