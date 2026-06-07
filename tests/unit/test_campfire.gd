extends RefCounted

const CAMPFIRE_SCENE := preload("res://scenes/buildings/campfire.tscn")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_campfire_creates_light_node_and_keeps_it_enabled_while_active(failures)
	return failures


func _test_campfire_creates_light_node_and_keeps_it_enabled_while_active(failures: Array[String]) -> void:
	var campfire := CAMPFIRE_SCENE.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.current_scene.add_child(campfire)
	var light := campfire.get_node_or_null("CampfireLight") as PointLight2D
	TEST_UTILS.expect(light != null, failures, "Campfire should create a CampfireLight node during setup")
	if light != null:
		TEST_UTILS.expect_equal(light.shadow_enabled, false, failures, "Campfire light should not use shadows")
		TEST_UTILS.expect_equal(light.enabled, true, failures, "Campfire light should start enabled while the campfire is active")
		TEST_UTILS.expect_equal(light.visible, true, failures, "Campfire light should start visible while the campfire is active")
		TEST_UTILS.expect(light.texture != null, failures, "Campfire light should use a texture")
	campfire.queue_free()
