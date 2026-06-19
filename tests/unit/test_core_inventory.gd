extends RefCounted

const INVENTORY := preload("res://scripts/player/inventory.gd")
const INVENTORY_STATE := preload("res://scripts/core/inventory/inventory_state.gd")
const INVENTORY_SYSTEM := preload("res://scripts/core/inventory/inventory_system.gd")
const STORAGE_STATE := preload("res://scripts/core/inventory/storage_state.gd")
const HOTBAR_STATE := preload("res://scripts/core/inventory/hotbar_state.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_inventory_adapter_extends_core_state(failures)
	_test_transfer_item_moves_between_states(failures)
	_test_transfer_item_partially_moves_when_destination_is_nearly_full(failures)
	_test_transfer_slot_removes_from_exact_slot(failures)
	_test_storage_state_save_load_round_trip(failures)
	_test_hotbar_selection_and_save_load(failures)
	return failures


func _test_inventory_adapter_extends_core_state(failures: Array[String]) -> void:
	var inventory := INVENTORY.new()
	TEST_UTILS.expect(inventory is INVENTORY_STATE, failures, "Player inventory adapter should extend core InventoryState")
	TEST_UTILS.expect_equal(inventory.get_slots().size(), 9, failures, "Inventory adapter should preserve default slot count")


func _test_transfer_item_moves_between_states(failures: Array[String]) -> void:
	var source := INVENTORY_STATE.new(2)
	var destination := INVENTORY_STATE.new(2)
	source.add_item("wood", 7)
	var result := INVENTORY_SYSTEM.transfer_item(source, destination, "wood", 5)
	TEST_UTILS.expect_equal(int(result.get("moved", 0)), 5, failures, "Transfer should report moved amount")
	TEST_UTILS.expect_equal(source.get_amount("wood"), 2, failures, "Source should lose transferred items")
	TEST_UTILS.expect_equal(destination.get_amount("wood"), 5, failures, "Destination should gain transferred items")


func _test_transfer_item_partially_moves_when_destination_is_nearly_full(failures: Array[String]) -> void:
	var source := INVENTORY_STATE.new(2)
	var destination := INVENTORY_STATE.new(1)
	source.add_item("wood", 5)
	destination.add_item("wood", 18)
	var result := INVENTORY_SYSTEM.transfer_item(source, destination, "wood", 5)
	TEST_UTILS.expect_equal(int(result.get("moved", 0)), 2, failures, "Transfer should move only free capacity")
	TEST_UTILS.expect_equal(source.get_amount("wood"), 3, failures, "Partial transfer should leave the rest in source")
	TEST_UTILS.expect_equal(destination.get_amount("wood"), 20, failures, "Destination should be filled to max stack")


func _test_transfer_slot_removes_from_exact_slot(failures: Array[String]) -> void:
	var source := INVENTORY_STATE.new(3)
	var destination := INVENTORY_STATE.new(3)
	source.add_item("wood", 25)
	var result := INVENTORY_SYSTEM.transfer_slot(source, destination, 1, 3)
	var source_slots := source.get_slots()
	TEST_UTILS.expect_equal(int(result.get("moved", 0)), 3, failures, "Slot transfer should report moved amount")
	TEST_UTILS.expect_equal(destination.get_amount("wood"), 3, failures, "Destination should receive slot transfer")
	TEST_UTILS.expect_equal(int(Dictionary(source_slots[1]).get("amount", 0)), 2, failures, "Slot transfer should remove from the selected source slot")


func _test_storage_state_save_load_round_trip(failures: Array[String]) -> void:
	var storage := STORAGE_STATE.new()
	storage.get_inventory_state().add_item("stone", 6)
	var save_data := storage.to_save_data()
	var restored := STORAGE_STATE.new()
	restored.load_from_save_data(save_data)
	TEST_UTILS.expect_equal(restored.get_amount("stone"), 6, failures, "Storage state should restore inventory contents")
	TEST_UTILS.expect_equal(restored.get_slots().size(), 12, failures, "Storage state should keep 12 slots")


func _test_hotbar_selection_and_save_load(failures: Array[String]) -> void:
	var hotbar := HOTBAR_STATE.new(9)
	TEST_UTILS.expect_equal(hotbar.get_selected_index(), 0, failures, "Hotbar should start at slot 0")
	TEST_UTILS.expect(hotbar.select_slot(4), failures, "Hotbar should allow selecting a valid slot")
	TEST_UTILS.expect_equal(hotbar.get_selected_index(), 4, failures, "Hotbar should store selected slot")
	TEST_UTILS.expect(not hotbar.select_slot(99), failures, "Hotbar should reject invalid slot indexes")
	TEST_UTILS.expect_equal(hotbar.select_next(), 5, failures, "Hotbar next should advance")
	TEST_UTILS.expect_equal(hotbar.select_previous(), 4, failures, "Hotbar previous should go back")
	var restored := HOTBAR_STATE.new()
	restored.load_from_save_data(hotbar.to_save_data())
	TEST_UTILS.expect_equal(restored.get_selected_index(), 4, failures, "Hotbar save/load should restore selected slot")
