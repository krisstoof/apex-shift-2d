extends RefCounted
class_name CraftingSystem

const CRAFTING_CATALOG := preload("res://scripts/core/crafting/crafting_catalog.gd")
const CRAFTING_RESULT := preload("res://scripts/core/crafting/crafting_result.gd")

var catalog


func _init(p_catalog = null) -> void:
	catalog = p_catalog


func set_catalog(p_catalog) -> void:
	catalog = p_catalog


func can_craft(recipe_id: String, inventory_state: Variant) -> bool:
	if catalog == null or not catalog.has_recipe(recipe_id):
		return false
	var recipe = catalog.get_recipe(recipe_id)
	return _get_missing_ingredients(recipe, inventory_state).is_empty() and _can_fit_outputs(recipe, inventory_state)


func get_missing_ingredients(recipe_id: String, inventory_state: Variant) -> Dictionary:
	if catalog == null or not catalog.has_recipe(recipe_id):
		return {}
	var recipe = catalog.get_recipe(recipe_id)
	return _get_missing_ingredients(recipe, inventory_state)


func craft(recipe_id: String, inventory_state: Variant):
	if catalog == null or not catalog.has_recipe(recipe_id):
		return CRAFTING_RESULT.failure_result(recipe_id, {}, "Unknown recipe")
	var recipe = catalog.get_recipe(recipe_id)
	var missing := _get_missing_ingredients(recipe, inventory_state)
	if not missing.is_empty():
		return CRAFTING_RESULT.failure_result(recipe_id, missing, "Missing resources")
	if not _can_fit_outputs(recipe, inventory_state):
		return CRAFTING_RESULT.failure_result(recipe_id, {}, "Inventory full")
	if not _consume_ingredients(recipe, inventory_state):
		return CRAFTING_RESULT.failure_result(recipe_id, {}, "Could not consume ingredients")
	if not _produce_outputs(recipe, inventory_state):
		_refund_ingredients(recipe, inventory_state)
		return CRAFTING_RESULT.failure_result(recipe_id, {}, "Inventory full")
	return CRAFTING_RESULT.success_result(recipe_id, recipe.get_ingredients(), recipe.get_outputs(), recipe.metadata)


func _get_missing_ingredients(recipe, inventory_state: Variant) -> Dictionary:
	var missing: Dictionary = {}
	if recipe == null or inventory_state == null:
		return missing
	for item_id_variant in recipe.ingredients.keys():
		var item_id := str(item_id_variant)
		var required := int(recipe.ingredients[item_id_variant])
		var available := _get_inventory_amount(inventory_state, item_id)
		if available < required:
			missing[item_id] = required - available
	return missing


func _can_fit_outputs(recipe, inventory_state: Variant) -> bool:
	if recipe == null:
		return false
	for item_id_variant in recipe.outputs.keys():
		var item_id := str(item_id_variant)
		var amount := int(recipe.outputs[item_id_variant])
		if amount > 0 and not _can_add_item(inventory_state, item_id, amount):
			return false
	return true


func _consume_ingredients(recipe, inventory_state: Variant) -> bool:
	for item_id_variant in recipe.ingredients.keys():
		var item_id := str(item_id_variant)
		var amount := int(recipe.ingredients[item_id_variant])
		if amount > 0 and not _remove_item(inventory_state, item_id, amount):
			return false
	return true


func _produce_outputs(recipe, inventory_state: Variant) -> bool:
	for item_id_variant in recipe.outputs.keys():
		var item_id := str(item_id_variant)
		var amount := int(recipe.outputs[item_id_variant])
		if amount <= 0:
			continue
		var leftover := _add_item(inventory_state, item_id, amount)
		if leftover > 0:
			return false
	return true


func _refund_ingredients(recipe, inventory_state: Variant) -> void:
	for item_id_variant in recipe.ingredients.keys():
		var item_id := str(item_id_variant)
		var amount := int(recipe.ingredients[item_id_variant])
		if amount > 0:
			_add_item(inventory_state, item_id, amount)


func _get_inventory_amount(inventory_state: Variant, item_id: String) -> int:
	if inventory_state != null and inventory_state.has_method("get_amount"):
		return int(inventory_state.call("get_amount", item_id))
	return 0


func _can_add_item(inventory_state: Variant, item_id: String, amount: int) -> bool:
	if inventory_state != null and inventory_state.has_method("can_add_item"):
		return bool(inventory_state.call("can_add_item", item_id, amount))
	if inventory_state != null and inventory_state.has_method("get_amount") and inventory_state.has_method("add_item"):
		return int(inventory_state.call("add_item", item_id, amount)) == 0
	return false


func _add_item(inventory_state: Variant, item_id: String, amount: int) -> int:
	if inventory_state != null and inventory_state.has_method("add_item"):
		return int(inventory_state.call("add_item", item_id, amount))
	return amount


func _remove_item(inventory_state: Variant, item_id: String, amount: int) -> bool:
	if inventory_state != null and inventory_state.has_method("remove_item"):
		return bool(inventory_state.call("remove_item", item_id, amount))
	return false
