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
	var player := main.get_node_or_null("Player") as Node2D
	var minimap := main.get_node_or_null("HUD/Minimap") as Control
	TEST_UTILS.expect(world != null, failures, "Main scene should include World")
	TEST_UTILS.expect(player != null, failures, "Main scene should include Player")
	TEST_UTILS.expect(minimap != null, failures, "Main scene should include Minimap")
	if world == null or player == null or minimap == null:
		await INTEGRATION.shutdown_main(context)
		return failures

	var landmarks: Array = world.call("get_landmarks")
	TEST_UTILS.expect(landmarks.size() > 0, failures, "World should expose landmarks for the minimap")
	var pond_count := 0
	var hill_count := 0
	for landmark_value in landmarks:
		if typeof(landmark_value) != TYPE_DICTIONARY:
			continue
		var landmark := Dictionary(landmark_value)
		match str(landmark.get("type", "")):
			"pond":
				pond_count += 1
			"hill":
				hill_count += 1
	TEST_UTILS.expect(pond_count > 0, failures, "Minimap test needs at least one pond landmark")
	TEST_UTILS.expect(hill_count > 0, failures, "Minimap test needs at least one hill landmark")
	TEST_UTILS.expect_equal((minimap.get("landmarks") as Array).size(), landmarks.size(), failures, "Minimap should receive the full landmark list from the HUD")
	var hud := main.get_node_or_null("HUD")
	if hud != null:
		if hud.has_method("_set_map_screen_open"):
			hud.call("_set_map_screen_open", true)
			await tree.process_frame
			await tree.process_frame
			TEST_UTILS.expect(tree.paused, failures, "Tree should be paused while map is open")
			var map_screen := hud.get_node_or_null("MapScreen")
			TEST_UTILS.expect(map_screen != null, failures, "MapScreen should exist when opening minimap")
			hud.call("_set_map_screen_open", false)
			await tree.process_frame
			await tree.process_frame
			TEST_UTILS.expect(not tree.paused, failures, "Tree should unpause after closing map")
		else:
			failures.append("HUD missing _set_map_screen_open; cannot verify modal map behavior.")

	minimap.queue_redraw()
	await tree.process_frame
	TEST_UTILS.expect(minimap.get("biome_blend_texture") != null, failures, "Minimap should build a biome blend texture when drawn")
	if minimap.get("biome_blend_texture") != null:
		var texture_size: Vector2i = (minimap.get("biome_blend_texture") as ImageTexture).get_size()
		TEST_UTILS.expect(texture_size.x > 0 and texture_size.y > 0, failures, "Biome blend texture should have a visible size")

	await INTEGRATION.shutdown_main(context)
	return failures


