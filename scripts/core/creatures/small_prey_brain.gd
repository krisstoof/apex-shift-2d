extends RefCounted
class_name SmallPreyBrain

const DECISION := preload("res://scripts/core/creatures/creature_decision.gd")
const CONTEXT := preload("res://scripts/core/creatures/creature_context.gd")


func decide(_state, context) -> CreatureDecision:
	var ctx := _ensure_context(context)
	if ctx.has_water_hazard:
		return DECISION.for_action(DECISION.ACTION_AVOID_WATER, "water_hazard", ctx.water_avoid_position, 0, "water")
	if ctx.has_building_hazard:
		return DECISION.for_action(DECISION.ACTION_AVOID_BUILDING, "building_hazard_%s" % ctx.building_hazard_kind, ctx.building_hazard_position, ctx.building_hazard_entity_id, ctx.building_hazard_kind)
	if ctx.has_any_threat():
		return DECISION.for_action(DECISION.ACTION_FLEE, "threat_detected", ctx.get_primary_threat_position(), ctx.get_primary_threat_entity_id(), ctx.get_primary_threat_kind())
	if _should_return_to_biome(ctx):
		return DECISION.for_action(DECISION.ACTION_RETURN_TO_BIOME, "outside_home_biome", ctx.return_position, 0, ctx.home_biome)
	if ctx.is_hungry() and ctx.has_food_target and ctx.food_in_eat_range and ctx.eat_cooldown <= 0.0:
		return DECISION.for_action(DECISION.ACTION_EAT, "hungry_food_in_range", ctx.food_position, ctx.food_entity_id, ctx.food_kind, {"consume": true})
	if ctx.is_hungry() and ctx.has_food_target:
		return DECISION.for_action(DECISION.ACTION_SEEK_FOOD, "hungry_seek_food", ctx.food_position, ctx.food_entity_id, ctx.food_kind)
	if ctx.should_rest or ctx.energy <= 0.18:
		return DECISION.for_action(DECISION.ACTION_REST, "low_energy")
	return DECISION.for_action(DECISION.ACTION_WANDER, "default_wander")


func _should_return_to_biome(ctx: CreatureContext) -> bool:
	return not ctx.is_inside_home_biome and not ctx.home_biome.is_empty()


func _ensure_context(context) -> CreatureContext:
	if context is CreatureContext:
		return context
	if typeof(context) == TYPE_DICTIONARY:
		return CONTEXT.from_dictionary(Dictionary(context))
	return CONTEXT.new()
