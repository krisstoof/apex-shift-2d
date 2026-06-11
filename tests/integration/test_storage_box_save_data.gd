extends RefCounted

const INTEGRATION := preload("res://tests/integration/integration_test_utils.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var context := await INTEGRATION.boot_main()
	if not bool(context.get("ok", false)):
		return [String(context.get("reason", "Integration bootstrap failed"))]
	var tree := context.get("tree") as SceneTree
	var main := context.get("main") as Node
	if tree == null or main == null:
		return ["Integration bootstrap returned invalid tree/main."]

	var world := main.get_node_or_null("World")
	var player := main.get_node_or_null("Player")
	var hud := main.get_node_or_null("HUD")
	TEST_UTILS.expect(world != null, failures, "World should exist")
	TEST_UTILS.expect(player != null, failures, "Player should exist")
	TEST_UTILS.expect(hud != null, failures, "HUD should exist")
	if world == null or player == null or hud == null:
		await INTEGRATION.shutdown_main(context)
		return failures

	var storage_box: Node = world.call("spawn_building_for_tests", "storage_box", player.global_position + Vector2(96.0, 0.0)) if world.has_method("spawn_building_for_tests") else null
	if storage_box == null:
		var boxes := tree.get_nodes_in_group("storage_boxes")
		if not boxes.is_empty():
			storage_box = boxes[0]
	TEST_UTILS.expect(storage_box != null, failures, "Storage box should exist for the test")
	if storage_box == null:
		await INTEGRATION.shutdown_main(context)
		return failures

	var box_inventory: Inventory = storage_box.get("inventory") as Inventory
	TEST_UTILS.expect(box_inventory != null, failures, "Storage box should expose inventory")
	if box_inventory == null:
		await INTEGRATION.shutdown_main(context)
		return failures
	box_inventory.clear()
	box_inventory.add_item("wood", 5)
	box_inventory.add_item("stone", 2)
	var save_data := box_inventory.get_save_data()
	var restored := Inventory.new(12)
	restored.restore_from_data(save_data)
	TEST_UTILS.expect_equal(restored.get_amount("wood"), 5, failures, "Storage box save data should restore wood")
	TEST_UTILS.expect_equal(restored.get_amount("stone"), 2, failures, "Storage box save data should restore stone")
	INTEGRATION.assert_tree_unpaused(failures, tree, "Storage box save data integration")
	await INTEGRATION.shutdown_main(context)
	return failures


