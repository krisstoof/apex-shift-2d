extends RefCounted
class_name CraftingResult

const CRAFTING_RESULT := preload("res://scripts/core/crafting/crafting_result.gd")

var recipe_id: String = ""
var success: bool = false
var missing_ingredients: Dictionary = {}
var consumed_ingredients: Dictionary = {}
var produced_items: Dictionary = {}
var message: String = ""
var metadata: Dictionary = {}


static func success_result(recipe_id: String, consumed := {}, produced := {}, metadata := {}):
	var result := CRAFTING_RESULT.new()
	result.recipe_id = recipe_id
	result.success = true
	result.consumed_ingredients = Dictionary(consumed).duplicate(true)
	result.produced_items = Dictionary(produced).duplicate(true)
	result.metadata = Dictionary(metadata).duplicate(true)
	result.message = "Crafted %s" % recipe_id
	return result


static func failure_result(recipe_id: String, missing := {}, message := "Missing ingredients"):
	var result := CRAFTING_RESULT.new()
	result.recipe_id = recipe_id
	result.success = false
	result.missing_ingredients = Dictionary(missing).duplicate(true)
	result.message = message
	return result


func is_success() -> bool:
	return success


func to_data() -> Dictionary:
	return {
		"recipe_id": recipe_id,
		"success": success,
		"missing_ingredients": missing_ingredients.duplicate(true),
		"consumed_ingredients": consumed_ingredients.duplicate(true),
		"produced_items": produced_items.duplicate(true),
		"message": message,
		"metadata": metadata.duplicate(true)
	}
