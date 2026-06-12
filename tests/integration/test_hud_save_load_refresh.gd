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
	var save_system := main.get_node_or_null("SaveSystem")
	TEST_UTILS.expect(world != null, failures, "World should exist")
	TEST_UTILS.expect(player != null, failures, "Player should exist")
	TEST_UTILS.expect(hud != null, failures, "HUD should exist")
	TEST_UTILS.expect(save_system != null, failures, "SaveSystem should exist")
	if world == null or player == null or hud == null or save_system == null:
		await INTEGRATION.shutdown_main(context)
		return failures

	player.stats.health = 64.0
	player.stats.hunger = 41.0
	player.inventory.clear()
	player.inventory.add_item("wood", 7)
	player.inventory.add_item("stone", 3)
	save_system.call("save_game")
	await tree.process_frame
	await tree.process_frame

	player.stats.health = 1.0
	player.stats.hunger = 1.0
	player.inventory.clear()
	save_system.call("load_game")
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame

	if hud.has_method("_refresh_resource_panel"):
		hud.call("_refresh_resource_panel")
	if hud.has_method("_refresh_hud_text"):
		hud.call("_refresh_hud_text")
	await tree.process_frame
	await tree.process_frame

	var stats_label := hud.get_node_or_null("Panel/StatsLabel") as Label
	if stats_label == null:
		failures.append("HUD StatsLabel missing after save/load.")
	else:
		var text := stats_label.text
		if text.find("HP: 64") < 0:
			failures.append("HUD did not show restored HP after load. text=%s" % text)
		if text.find("Wood: 7") < 0:
			failures.append("HUD did not show restored wood after load. text=%s" % text)
		if text.find("Stone: 3") < 0:
			failures.append("HUD did not show restored stone after load. text=%s" % text)

	INTEGRATION.assert_tree_unpaused(failures, tree, "HUD save/load refresh integration")
	await INTEGRATION.shutdown_main(context)
	return failures


