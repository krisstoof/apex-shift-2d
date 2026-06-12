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

	var world_boot := main.get_node_or_null("World")
	if world_boot != null and world_boot.has_method("is_boot_ready") and not bool(world_boot.call("is_boot_ready")):
		if world_boot.has_signal("world_initialized"):
			await world_boot.world_initialized
	await tree.process_frame

	var world := main.get_node_or_null("World")
	var ecosystem := main.get_node_or_null("EcosystemDirector")
	var player := main.get_node_or_null("Player") as Node2D

	TEST_UTILS.expect(world != null, failures, "Main scene should include World")
	TEST_UTILS.expect(ecosystem != null, failures, "Main scene should include EcosystemDirector")
	TEST_UTILS.expect(player != null, failures, "Main scene should include Player")

	if world != null and ecosystem != null and player != null:
		var biome_zones: Array = world.call("get_biome_zones")
		var biome_states: Dictionary = Dictionary(ecosystem.call("get_biome_states"))
		var resources: Array = world.call("get_resource_save_data")
		var small_prey: Array = world.call("get_small_prey_save_data")
		var grazers: Array = world.call("get_grazer_save_data")
		TEST_UTILS.expect(ecosystem.get("initialized") == true, failures, "EcosystemDirector should be initialized on a fresh game")
		TEST_UTILS.expect(biome_states.size() > 0, failures, "EcosystemDirector should populate biome states on startup")
		TEST_UTILS.expect_equal(biome_states.size(), biome_zones.size(), failures, "EcosystemDirector should create one biome state per biome zone")
		TEST_UTILS.expect(resources.size() > 0, failures, "World should spawn resources on startup")
		TEST_UTILS.expect_equal(small_prey.size(), 5, failures, "Fresh game should spawn the expected visible small prey count")
		TEST_UTILS.expect_equal(grazers.size(), 3, failures, "Fresh game should spawn the expected visible grazer count")
		TEST_UTILS.expect(world.call("get_world_rect").has_point(player.global_position), failures, "Player should spawn inside the world bounds")

	await INTEGRATION.shutdown_main(context)

	return failures


