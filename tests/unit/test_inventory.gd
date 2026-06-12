extends RefCounted

const INVENTORY := preload("res://scripts/player/inventory.gd")
const STORAGE_BOX := preload("res://scripts/buildings/storage_box.gd")
const STORAGE_BOX_SCREEN := preload("res://scripts/ui/storage_box_screen.gd")
const ITEM_DATABASE := preload("res://scripts/items/item_database.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


class TestEventBus:
	extends Node

	var last_message := ""

	func post_message(message: String) -> void:
		last_message = message


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_starts_empty(failures)
	_test_add_item_adds_to_empty_slot(failures)
	_test_add_item_unknown_does_not_mutate(failures)
	_test_add_item_zero_or_negative_does_not_mutate(failures)
	_test_add_item_stacks_existing_stack(failures)
	_test_add_item_splits_over_multiple_slots(failures)
	_test_add_item_returns_leftover_when_full(failures)
	_test_remove_item_removes_across_stacks(failures)
	_test_remove_item_fails_when_not_enough_items(failures)
	_test_remove_item_unknown_does_not_mutate(failures)
	_test_remove_item_zero_or_negative_is_noop(failures)
	_test_has_item_sums_all_stacks(failures)
	_test_get_amount_sums_all_stacks(failures)
	_test_inventory_never_goes_below_zero(failures)
	_test_unknown_item_is_safe(failures)
	_test_torch_respects_max_stack_one(failures)
	_test_inventory_accepts_bone(failures)
	_test_storage_box_inventory_uses_twelve_slots(failures)
	_test_storage_box_prompt_mentions_open(failures)
	_test_storage_boxes_keep_independent_inventories(failures)
	_test_storage_box_exposes_interaction_methods(failures)
	_test_storage_box_screen_transfers_items_between_inventories(failures)
	_test_storage_box_screen_posts_transfer_messages_to_hud(failures)
	_test_save_load_restores_slots(failures)
	_test_save_load_round_trip(failures)
	_test_save_load_accepts_items_alias(failures)
	_test_save_load_ignores_empty_and_unknown_items(failures)
	_test_legacy_inventory_migration(failures)
	_test_save_load_ignores_invalid_items(failures)
	_test_clear_removes_all_slots(failures)
	return failures


func _test_starts_empty(failures: Array[String]) -> void:
	var inventory := INVENTORY.new()
	TEST_UTILS.expect_equal(inventory.get_slots().size(), 9, failures, "Inventory should expose 9 slots")
	TEST_UTILS.expect_equal(inventory.get_all_items().is_empty(), true, failures, "New inventory should start empty")


func _test_add_item_adds_to_empty_slot(failures: Array[String]) -> void:
	var inventory := INVENTORY.new()
	var leftover := inventory.add_item("wood", 7)
	TEST_UTILS.expect_equal(leftover, 0, failures, "Adding to an empty slot should not leave leftovers")
	TEST_UTILS.expect_equal(inventory.get_amount("wood"), 7, failures, "Inventory should store added items")
	TEST_UTILS.expect_equal(int(inventory.get_slots()[0].get("amount", 0)), 7, failures, "First slot should receive the items")


func _test_add_item_unknown_does_not_mutate(failures: Array[String]) -> void:
	var inventory := INVENTORY.new(2)
	inventory.add_item("wood", 3)
	var before := inventory.to_save_data().duplicate(true)
	var leftover := inventory.add_item("unknown_item", 4)
	TEST_UTILS.expect_equal(leftover, 4, failures, "Unknown items should be returned as leftover")
	TEST_UTILS.expect_equal(inventory.to_save_data(), before, failures, "Unknown items should not mutate inventory state")


func _test_add_item_zero_or_negative_does_not_mutate(failures: Array[String]) -> void:
	var inventory := INVENTORY.new(2)
	inventory.add_item("wood", 3)
	var before := inventory.to_save_data().duplicate(true)
	TEST_UTILS.expect_equal(inventory.add_item("wood", 0), 0, failures, "Adding zero items should do nothing")
	TEST_UTILS.expect_equal(inventory.add_item("wood", -5), 0, failures, "Adding negative items should do nothing")
	TEST_UTILS.expect_equal(inventory.to_save_data(), before, failures, "Zero or negative additions should not mutate inventory")


func _test_add_item_stacks_existing_stack(failures: Array[String]) -> void:
	var inventory := INVENTORY.new()
	inventory.add_item("wood", 12)
	var leftover := inventory.add_item("wood", 5)
	TEST_UTILS.expect_equal(leftover, 0, failures, "Stacking onto an existing stack should keep all items")
	TEST_UTILS.expect_equal(inventory.get_amount("wood"), 17, failures, "Inventory should sum stacked items")
	TEST_UTILS.expect_equal(int(inventory.get_slots()[0].get("amount", 0)), 17, failures, "Existing stack should be filled first")


func _test_add_item_splits_over_multiple_slots(failures: Array[String]) -> void:
	var inventory := INVENTORY.new()
	var leftover := inventory.add_item("wood", 25)
	TEST_UTILS.expect_equal(leftover, 0, failures, "Inventory should split stackable items across slots")
	var slots := inventory.get_slots()
	TEST_UTILS.expect_equal(int(slots[0].get("amount", 0)), 20, failures, "First slot should clamp to max stack")
	TEST_UTILS.expect_equal(int(slots[1].get("amount", 0)), 5, failures, "Second slot should hold the remainder")


func _test_add_item_returns_leftover_when_full(failures: Array[String]) -> void:
	var inventory := INVENTORY.new()
	for i in range(9):
		inventory.add_item("wood", 20)
	var leftover := inventory.add_item("wood", 5)
	TEST_UTILS.expect_equal(leftover, 5, failures, "Full inventory should return the leftover amount")
	TEST_UTILS.expect_equal(inventory.get_amount("wood"), 180, failures, "Full inventory should keep existing items intact")


func _test_remove_item_removes_across_stacks(failures: Array[String]) -> void:
	var inventory := INVENTORY.new()
	inventory.add_item("wood", 25)
	TEST_UTILS.expect(inventory.remove_item("wood", 23), failures, "Inventory should remove across stacks")
	TEST_UTILS.expect_equal(inventory.get_amount("wood"), 2, failures, "Removal should reduce the total amount")
	var slots := inventory.get_slots()
	TEST_UTILS.expect_equal(str(slots[1].get("item_id", "")), "wood", failures, "Remaining item should stay in the later slot")
	TEST_UTILS.expect_equal(int(slots[1].get("amount", 0)), 2, failures, "Remaining stack should reflect the remainder")


func _test_remove_item_fails_when_not_enough_items(failures: Array[String]) -> void:
	var inventory := INVENTORY.new()
	inventory.add_item("wood", 3)
	TEST_UTILS.expect(not inventory.remove_item("wood", 4), failures, "Removal should fail when inventory is short")
	TEST_UTILS.expect_equal(inventory.get_amount("wood"), 3, failures, "Failed removal should not change inventory")


func _test_remove_item_unknown_does_not_mutate(failures: Array[String]) -> void:
	var inventory := INVENTORY.new(2)
	inventory.add_item("wood", 3)
	inventory.add_item("stone", 2)
	var before := inventory.to_save_data().duplicate(true)
	TEST_UTILS.expect(not inventory.remove_item("unknown_item", 1), failures, "Unknown item removal should fail safely")
	TEST_UTILS.expect_equal(inventory.to_save_data(), before, failures, "Unknown item removal should not mutate inventory")


func _test_remove_item_zero_or_negative_is_noop(failures: Array[String]) -> void:
	var inventory := INVENTORY.new(2)
	inventory.add_item("wood", 3)
	var before := inventory.to_save_data().duplicate(true)
	TEST_UTILS.expect(inventory.remove_item("wood", 0), failures, "Removing zero items should succeed")
	TEST_UTILS.expect(inventory.remove_item("wood", -2), failures, "Removing negative items should be a no-op")
	TEST_UTILS.expect_equal(inventory.to_save_data(), before, failures, "No-op removals should not mutate inventory")


func _test_has_item_sums_all_stacks(failures: Array[String]) -> void:
	var inventory := INVENTORY.new()
	inventory.add_item("wood", 20)
	inventory.add_item("wood", 5)
	TEST_UTILS.expect(inventory.has_item("wood", 25), failures, "has_item should check all stacks")
	TEST_UTILS.expect(not inventory.has_item("wood", 26), failures, "has_item should return false above total stock")


func _test_get_amount_sums_all_stacks(failures: Array[String]) -> void:
	var inventory := INVENTORY.new()
	inventory.add_item("wood", 20)
	inventory.add_item("wood", 5)
	inventory.add_item("stone", 3)
	TEST_UTILS.expect_equal(inventory.get_amount("wood"), 25, failures, "get_amount should sum all stacks for a single item")
	TEST_UTILS.expect_equal(inventory.get_amount("stone"), 3, failures, "get_amount should return other item totals")


func _test_inventory_never_goes_below_zero(failures: Array[String]) -> void:
	var inventory := INVENTORY.new()
	TEST_UTILS.expect(inventory.remove_item("wood", 0), failures, "Removing zero items should succeed")
	TEST_UTILS.expect_equal(inventory.get_amount("wood"), 0, failures, "Zero removals should not change inventory")
	TEST_UTILS.expect_equal(inventory.add_item("wood", 0), 0, failures, "Adding zero items should do nothing")


func _test_unknown_item_is_safe(failures: Array[String]) -> void:
	var inventory := INVENTORY.new()
	TEST_UTILS.expect_equal(inventory.add_item("unknown", 4), 4, failures, "Unknown items should be rejected as leftovers")
	TEST_UTILS.expect(not inventory.remove_item("unknown", 1), failures, "Unknown item removal should fail safely")
	TEST_UTILS.expect_equal(inventory.get_amount("unknown"), 0, failures, "Unknown items should not be stored")


func _test_torch_respects_max_stack_one(failures: Array[String]) -> void:
	var inventory := INVENTORY.new(2)
	var leftover := inventory.add_item("torch", 3)
	TEST_UTILS.expect_equal(leftover, 1, failures, "Torches should stop at one per slot")
	TEST_UTILS.expect_equal(inventory.get_amount("torch"), 2, failures, "Two slots should hold at most two torches")


func _test_inventory_accepts_bone(failures: Array[String]) -> void:
	var inventory := INVENTORY.new()
	TEST_UTILS.expect(ITEM_DATABASE.has_item("bone"), failures, "Bone should exist in the item database")
	TEST_UTILS.expect_equal(inventory.add_item("bone", 25), 0, failures, "Bone should stack like other normal items")
	TEST_UTILS.expect_equal(inventory.get_amount("bone"), 25, failures, "Bone should be stored in inventory")
	TEST_UTILS.expect_equal(int(inventory.get_slots()[0].get("amount", 0)), 20, failures, "Bone should respect the max stack size")


func _test_storage_box_inventory_uses_twelve_slots(failures: Array[String]) -> void:
	var storage_box := STORAGE_BOX.new()
	var box_inventory: Variant = storage_box.get("inventory")
	TEST_UTILS.expect(box_inventory is INVENTORY, failures, "Storage box should create an Inventory instance")
	TEST_UTILS.expect_equal(box_inventory.get_slots().size(), 12, failures, "Storage box should expose 12 slots")


func _test_storage_box_prompt_mentions_open(failures: Array[String]) -> void:
	var storage_box := STORAGE_BOX.new()
	TEST_UTILS.expect_equal(storage_box.call("get_prompt"), "E: Open Storage Box", failures, "Storage box prompt should mention opening the box")


func _test_storage_boxes_keep_independent_inventories(failures: Array[String]) -> void:
	var storage_box_a := STORAGE_BOX.new()
	var storage_box_b := STORAGE_BOX.new()
	var inventory_a: Inventory = storage_box_a.get("inventory")
	var inventory_b: Inventory = storage_box_b.get("inventory")
	inventory_a.add_item("wood", 5)
	inventory_b.add_item("stone", 3)
	TEST_UTILS.expect_equal(inventory_a.get_amount("wood"), 5, failures, "First storage box should keep its own wood")
	TEST_UTILS.expect_equal(inventory_a.get_amount("stone"), 0, failures, "First storage box should not inherit second box items")
	TEST_UTILS.expect_equal(inventory_b.get_amount("stone"), 3, failures, "Second storage box should keep its own stone")
	TEST_UTILS.expect_equal(inventory_b.get_amount("wood"), 0, failures, "Second storage box should not inherit first box items")


func _test_storage_box_exposes_interaction_methods(failures: Array[String]) -> void:
	var storage_box := STORAGE_BOX.new()
	TEST_UTILS.expect(storage_box.has_method("interact"), failures, "Storage box should expose an interact method")
	TEST_UTILS.expect(storage_box.has_method("get_prompt"), failures, "Storage box should expose a prompt method")


func _test_storage_box_screen_transfers_items_between_inventories(failures: Array[String]) -> void:
	var screen := STORAGE_BOX_SCREEN.new()
	screen.call("_ready")
	var player_inventory := INVENTORY.new()
	var storage_inventory := INVENTORY.new(12)
	player_inventory.add_item("wood", 5)
	screen.call("setup", player_inventory, storage_inventory, null)
	screen.call("_transfer_item", player_inventory, storage_inventory, "wood", 5, "Storage box full", "Stored")
	TEST_UTILS.expect_equal(player_inventory.get_amount("wood"), 0, failures, "Player inventory should lose transferred wood")
	TEST_UTILS.expect_equal(storage_inventory.get_amount("wood"), 5, failures, "Storage inventory should gain transferred wood")
	screen.call("_transfer_item", storage_inventory, player_inventory, "wood", 5, "Inventory full", "Took")
	TEST_UTILS.expect_equal(player_inventory.get_amount("wood"), 5, failures, "Player inventory should get wood back from storage")
	TEST_UTILS.expect_equal(storage_inventory.get_amount("wood"), 0, failures, "Storage inventory should lose transferred wood")


func _test_storage_box_screen_posts_transfer_messages_to_hud(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var previous_event_bus := tree.root.get_node_or_null("EventBus")
	if previous_event_bus != null:
		previous_event_bus.name = "LiveEventBus"
	var event_bus := TestEventBus.new()
	event_bus.name = "EventBus"
	tree.root.add_child(event_bus)
	var screen := STORAGE_BOX_SCREEN.new()
	tree.root.add_child(screen)
	var player_inventory := INVENTORY.new()
	var storage_inventory := INVENTORY.new(12)
	player_inventory.add_item("storage_box", 1)
	screen.call("setup", player_inventory, storage_inventory, null)
	screen.call("_transfer_item", player_inventory, storage_inventory, "storage_box", 1, "Storage box full", "Stored")
	TEST_UTILS.expect_equal(event_bus.last_message, "Stored storage box x1", failures, "Storage transfers should post readable HUD messages")
	screen.queue_free()
	event_bus.queue_free()
	if previous_event_bus != null:
		previous_event_bus.name = "EventBus"


func _test_save_load_restores_slots(failures: Array[String]) -> void:
	var inventory := INVENTORY.new()
	inventory.add_item("wood", 25)
	inventory.add_item("stone", 3)
	var save_data := inventory.to_save_data()
	var restored := INVENTORY.new()
	restored.load_from_save_data(save_data)
	TEST_UTILS.expect_equal(restored.get_amount("wood"), 25, failures, "Save/load should restore stacked wood")
	TEST_UTILS.expect_equal(restored.get_amount("stone"), 3, failures, "Save/load should restore stone")
	TEST_UTILS.expect_equal(restored.get_slots().size(), 9, failures, "Save/load should preserve slot count")


func _test_save_load_round_trip(failures: Array[String]) -> void:
	var inventory := INVENTORY.new(4)
	inventory.add_item("wood", 7)
	inventory.add_item("stone", 3)
	inventory.add_item("torch", 1)
	var save_data := inventory.to_save_data()
	var restored := INVENTORY.new(4)
	restored.load_from_save_data(save_data)
	TEST_UTILS.expect_equal(restored.to_save_data(), save_data, failures, "Inventory save/load should round-trip cleanly")
	TEST_UTILS.expect_equal(restored.get_amount("wood"), 7, failures, "Inventory save/load should restore wood")
	TEST_UTILS.expect_equal(restored.get_amount("stone"), 3, failures, "Inventory save/load should restore stone")
	TEST_UTILS.expect_equal(restored.get_amount("torch"), 1, failures, "Inventory save/load should restore torches")


func _test_save_load_ignores_invalid_items(failures: Array[String]) -> void:
	var inventory := INVENTORY.new()
	inventory.load_from_save_data({
		"slots": [
			{"item_id": "wood", "amount": 21},
			{"item_id": "invalid", "amount": 7},
			{"item_id": "meat", "amount": 3}
		]
	})
	TEST_UTILS.expect_equal(inventory.get_amount("wood"), ITEM_DATABASE.get_max_stack("wood"), failures, "Load should clamp stacked amounts to the item max")
	TEST_UTILS.expect_equal(inventory.get_amount("meat"), 3, failures, "Load should restore valid items")
	TEST_UTILS.expect_equal(inventory.get_amount("invalid"), 0, failures, "Load should ignore invalid items")


func _test_save_load_accepts_items_alias(failures: Array[String]) -> void:
	var inventory := INVENTORY.new()
	inventory.load_from_save_data({
		"items": [
			{"item_id": "fiber", "amount": 8}
		]
	})
	TEST_UTILS.expect_equal(inventory.get_amount("fiber"), 8, failures, "Load should accept legacy items arrays")


func _test_save_load_ignores_empty_and_unknown_items(failures: Array[String]) -> void:
	var inventory := INVENTORY.new()
	inventory.load_from_save_data({
		"slots": [
			{"item_id": "", "amount": 12},
			{"item_id": "unknown", "amount": 4},
			{"item_id": "meat", "amount": 0},
			{"item_id": "bone", "amount": 2}
		]
	})
	TEST_UTILS.expect_equal(inventory.get_amount("bone"), 2, failures, "Load should keep valid items")
	TEST_UTILS.expect_equal(inventory.get_amount("unknown"), 0, failures, "Load should ignore unknown items")


func _test_legacy_inventory_migration(failures: Array[String]) -> void:
	var inventory := INVENTORY.new()
	inventory.load_from_save_data({
		"wood": 5,
		"stone": 2,
		"torch": 1
	})
	TEST_UTILS.expect_equal(inventory.get_amount("wood"), 5, failures, "Legacy inventory data should migrate wood")
	TEST_UTILS.expect_equal(inventory.get_amount("stone"), 2, failures, "Legacy inventory data should migrate stone")
	TEST_UTILS.expect_equal(inventory.get_amount("torch"), 1, failures, "Legacy inventory data should migrate torches")


func _test_clear_removes_all_slots(failures: Array[String]) -> void:
	var inventory := INVENTORY.new()
	inventory.add_item("wood", 7)
	inventory.add_item("stone", 3)
	inventory.clear()
	TEST_UTILS.expect_equal(inventory.get_all_items().is_empty(), true, failures, "Clear should remove all items")
	TEST_UTILS.expect_equal(inventory.get_slots().size(), 9, failures, "Clear should preserve the slot count")
