extends RefCounted
class_name CraftingRecipe

const CRAFTING_RECIPE := preload("res://scripts/core/crafting/crafting_recipe.gd")

var recipe_id := ""
var ingredients: Dictionary = {}
var outputs: Dictionary = {}
var metadata: Dictionary = {}


func _init(p_recipe_id := "", p_ingredients := {}, p_outputs := {}, p_metadata := {}) -> void:
	recipe_id = str(p_recipe_id)
	ingredients = Dictionary(p_ingredients).duplicate(true)
	outputs = Dictionary(p_outputs).duplicate(true)
	metadata = Dictionary(p_metadata).duplicate(true)


func is_valid() -> bool:
	return not recipe_id.is_empty() and ingredients is Dictionary


func get_ingredients() -> Dictionary:
	return ingredients.duplicate(true)


func get_outputs() -> Dictionary:
	return outputs.duplicate(true)


func to_data() -> Dictionary:
	return {
		"recipe_id": recipe_id,
		"ingredients": ingredients.duplicate(true),
		"outputs": outputs.duplicate(true),
		"metadata": metadata.duplicate(true)
	}


static func from_data(data: Dictionary):
	return CRAFTING_RECIPE.new(
		str(data.get("recipe_id", "")),
		Dictionary(data.get("ingredients", {})),
		Dictionary(data.get("outputs", {})),
		Dictionary(data.get("metadata", {}))
	)
