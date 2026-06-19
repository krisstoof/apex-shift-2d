extends RefCounted
class_name CraftingCatalog

const CRAFTING_RECIPE := preload("res://scripts/core/crafting/crafting_recipe.gd")

var _recipes: Dictionary = {}


func add_recipe(recipe) -> void:
	if recipe == null or not recipe.is_valid():
		return
	_recipes[recipe.recipe_id] = recipe


func has_recipe(recipe_id: String) -> bool:
	return _recipes.has(recipe_id)


func get_recipe(recipe_id: String):
	return _recipes.get(recipe_id, null)


func get_recipe_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in _recipes.keys():
		ids.append(str(key))
	return ids


func get_all_recipes() -> Array:
	var recipes: Array = []
	for recipe in _recipes.values():
		recipes.append(recipe)
	return recipes


func load_from_costs(costs: Dictionary, output_rules: Dictionary = {}) -> void:
	_recipes.clear()
	for recipe_id_variant in costs.keys():
		var recipe_id := str(recipe_id_variant)
		var rule := Dictionary(output_rules.get(recipe_id, {}))
		var ingredients := Dictionary(costs.get(recipe_id_variant, {})).duplicate(true)
		var outputs := Dictionary(rule.get("outputs", {})).duplicate(true)
		var metadata := Dictionary(rule.get("metadata", {})).duplicate(true)
		add_recipe(CRAFTING_RECIPE.new(recipe_id, ingredients, outputs, metadata))


static func from_costs(costs: Dictionary, output_rules: Dictionary = {}):
	var catalog: Variant = load("res://scripts/core/crafting/crafting_catalog.gd").new()
	catalog.load_from_costs(costs, output_rules)
	return catalog
