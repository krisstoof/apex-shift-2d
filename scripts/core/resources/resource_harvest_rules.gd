extends RefCounted
class_name ResourceHarvestRules

const ITEM_DATABASE := preload("res://scripts/items/item_database.gd")
const RESOURCE_DROP_TABLE := preload("res://scripts/core/resources/resource_drop_table.gd")
const RESOURCE_REGROWTH_SYSTEM := preload("res://scripts/core/resources/resource_regrowth_system.gd")
const RESOURCE_HARVEST_RESULT := preload("res://scripts/core/resources/resource_harvest_result.gd")

static func can_harvest(state: ResourceState, inventory_state: Variant = null, tool_id := "") -> bool:
	return get_block_reason(state, inventory_state, tool_id).is_empty()

static func get_block_reason(state: ResourceState, inventory_state: Variant = null, tool_id := "") -> String:
	if state == null:
		return "No resource"
	if state.is_inventory_drop or state.resource_kind == "item_drop" or state.resource_kind == "meat_drop" or state.resource_kind == "bone_drop":
		if state.amount <= 0:
			return "Empty"
		if inventory_state != null and inventory_state.has_method("can_add_item") and not inventory_state.can_add_item(RESOURCE_DROP_TABLE.get_drop_item_id(state), state.amount):
			return "Inventory full"
		return ""
	if not state.player_harvestable:
		return "Cannot be gathered"
	if not state.can_be_harvested:
		return "Regrowing"
	if state.amount <= 0:
		return "Empty"
	return ""

static func get_prompt(state: ResourceState) -> String:
	if state == null:
		return ""
	if state.is_inventory_drop or state.resource_kind in ["item_drop", "meat_drop", "bone_drop"]:
		return "E: pick up %s x%d" % [ITEM_DATABASE.get_display_name(RESOURCE_DROP_TABLE.get_drop_item_id(state)), state.amount]
	if not state.player_harvestable:
		return ""
	if not state.can_be_harvested:
		return "Regrowing: %s" % RESOURCE_REGROWTH_SYSTEM.get_growth_debug_text(state)
	return "E: gather %s x%d" % [state.item_id if not state.item_id.is_empty() else RESOURCE_DROP_TABLE.get_drop_item_id(state), state.amount]

static func harvest(state: ResourceState, inventory_state: Variant, tool_id := "") -> ResourceHarvestResult:
	var result := RESOURCE_HARVEST_RESULT.new()
	if state == null:
		result.message = "No resource"
		return result
	result.requested_amount = state.amount
	var reason := get_block_reason(state, inventory_state, tool_id)
	if not reason.is_empty():
		result.message = reason
		return result
	var drop_item_id := RESOURCE_DROP_TABLE.get_drop_item_id(state)
	result.item_id = drop_item_id
	if inventory_state == null or not inventory_state.has_method("add_item"):
		result.message = "Inventory full"
		return result
	if state.is_inventory_drop or state.resource_kind in ["item_drop", "meat_drop", "bone_drop"]:
		if inventory_state.has_method("can_add_item") and not inventory_state.can_add_item(drop_item_id, state.amount):
			result.message = "Inventory full"
			return result
		if not inventory_state.has_method("can_add_item"):
			result.message = "Inventory full"
			return result
	var leftover := int(inventory_state.add_item(drop_item_id, state.amount))
	result.added_amount = state.amount - leftover
	result.leftover_amount = leftover
	if result.added_amount <= 0:
		result.message = "Inventory full"
		return result
	result.success = true
	result.message = "Collected %s x%d" % [drop_item_id, result.added_amount]
	result.should_start_regrowth = RESOURCE_DROP_TABLE.uses_regrowth(state.resource_kind)
	result.should_remove_node = not result.should_start_regrowth and leftover <= 0
	if state.resource_kind == "meat_drop":
		result.emitted_event_name = "meat_collected"
		result.emitted_event_payload = {"amount": result.added_amount, "position": Vector2.ZERO}
	elif state.resource_kind == "bone_drop":
		result.emitted_event_name = "bone_collected"
		result.emitted_event_payload = {"amount": result.added_amount, "position": Vector2.ZERO}
	if leftover > 0:
		if state.is_inventory_drop or state.resource_kind in ["item_drop", "meat_drop", "bone_drop"]:
			result.message = "Inventory full"
			return result
		state.amount = leftover
	else:
		if result.should_start_regrowth:
			RESOURCE_REGROWTH_SYSTEM.mark_harvested(state)
		else:
			state.amount = 0
	return result
