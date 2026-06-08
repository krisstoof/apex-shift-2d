extends RefCounted

const RESOURCE_NODE_SCENE := preload("res://scenes/world/resource_node.tscn")
const INVENTORY := preload("res://scripts/player/inventory.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


class TestEventBus:
	extends Node

	var last_event_name := ""
	var last_event_payload: Dictionary = {}
	var last_message := ""

	func emit_game_event(event_name: String, payload: Dictionary = {}) -> void:
		last_event_name = event_name
		last_event_payload = payload.duplicate(true)

	func post_message(_message: String) -> void:
		last_message = _message


class TestPlayer:
	extends Node2D

	var inventory := INVENTORY.new()


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_resource_node_setup_exposes_herbivore_food(failures)
	_test_resource_node_marks_grass_as_render_only_and_edible(failures)
	_test_resource_node_restore_recreates_edible_food_value(failures)
	_test_resource_node_restore_defaults_render_only_for_legacy_saves(failures)
	_test_resource_node_syncs_collision_radius_with_growth(failures)
	_test_resource_node_uses_shared_atlas_and_depleted_region(failures)
	_test_resource_node_emits_bone_collected_for_bone_drop(failures)
	_test_resource_node_reports_inventory_full_when_pickup_does_not_fit(failures)
	return failures


func _test_resource_node_setup_exposes_herbivore_food(failures: Array[String]) -> void:
	var resource := RESOURCE_NODE_SCENE.instantiate()
	resource.call("setup", "tree")
	TEST_UTILS.expect(resource.is_in_group("edible_vegetation"), failures, "Tree resources should belong to edible_vegetation")
	TEST_UTILS.expect(float(resource.get("food_value")) > 0.0, failures, "Tree resources should expose a positive food value")
	var eaten := float(resource.call("consume_by_creature", null, 1.0))
	TEST_UTILS.expect(eaten > 0.0, failures, "Tree resources should return nutrition when consumed")
	TEST_UTILS.expect_equal(int(resource.get("growth_stage")), 2, failures, "Tree consumption should reduce the growth stage by one")
	resource.free()


func _test_resource_node_restore_recreates_edible_food_value(failures: Array[String]) -> void:
	var resource := RESOURCE_NODE_SCENE.instantiate()
	resource.call("restore_from_data", {
		"biome_id": "hearth_meadow",
		"mature_amount": 4,
		"amount": 4,
		"growth_stage": 3,
		"max_growth_stage": 3,
		"growth_progress": 0.0,
		"days_to_next_stage": 1.0,
		"days_since_harvested": 0.0,
		"is_harvested": false,
		"can_be_harvested": true,
		"player_harvestable": true,
		"is_edible_by_herbivores": false,
		"food_value": 0.0,
		"is_pond_vegetation": false,
		"pond_id": "",
		"food_bonus_multiplier": 1.0,
		"pond_visual_multiplier": 1.0
	})
	TEST_UTILS.expect(float(resource.get("food_value")) > 0.0, failures, "Older saves should restore a herbivore food value for trees and bushes")
	TEST_UTILS.expect(bool(resource.get("is_edible_by_herbivores")), failures, "Older saves should rejoin edible_vegetation after restore")
	resource.free()


func _test_resource_node_marks_grass_as_render_only_and_edible(failures: Array[String]) -> void:
	for kind in ["grass_patch", "dense_grass"]:
		var resource := RESOURCE_NODE_SCENE.instantiate()
		resource.call("setup", kind)
		TEST_UTILS.expect_equal(resource.call("is_render_only_resource"), true, failures, "%s should be render-only" % kind)
		TEST_UTILS.expect_equal(resource.get("player_harvestable"), false, failures, "%s should not be player harvestable" % kind)
		TEST_UTILS.expect_equal(str(resource.call("get_prompt")), "", failures, "%s should not show a player prompt" % kind)
		TEST_UTILS.expect(resource.is_in_group("grass"), failures, "%s should remain in the grass group" % kind)
		TEST_UTILS.expect(resource.is_in_group("vegetation"), failures, "%s should remain in the vegetation group" % kind)
		TEST_UTILS.expect(resource.is_in_group("edible_vegetation"), failures, "%s should stay edible for herbivores" % kind)
		TEST_UTILS.expect(resource.get("is_edible_by_herbivores") == true, failures, "%s should stay edible for herbivores after setup" % kind)
		var collision_shape := resource.get_node("CollisionShape2D") as CollisionShape2D
		TEST_UTILS.expect(collision_shape != null, failures, "%s should have a collision shape" % kind)
		if collision_shape != null:
			TEST_UTILS.expect_equal(collision_shape.disabled, true, failures, "%s should disable collision in render-only mode" % kind)
		var eaten := float(resource.call("consume_by_creature", null, 1.0))
		TEST_UTILS.expect(eaten > 0.0, failures, "%s should still be edible by herbivores" % kind)
		TEST_UTILS.expect_equal(int(resource.get("growth_stage")), 2, failures, "%s should regrow after herbivore consumption" % kind)
		if collision_shape != null:
			TEST_UTILS.expect_equal(collision_shape.disabled, true, failures, "%s should keep collision disabled after consumption" % kind)
		resource.free()


func _test_resource_node_syncs_collision_radius_with_growth(failures: Array[String]) -> void:
	var resource := RESOURCE_NODE_SCENE.instantiate()
	resource.call("setup", "bush")
	var collision_shape: CollisionShape2D = resource.get_node("CollisionShape2D") as CollisionShape2D
	var circle := collision_shape.shape as CircleShape2D
	TEST_UTILS.expect(circle != null, failures, "ResourceNode should keep a circular collision shape for bushes")
	if circle != null:
		TEST_UTILS.expect_close(circle.radius, float(resource.get("radius")), failures, "Bush collision radius should match its current visible resource radius")
	resource.call("consume_by_creature", null, 1.0)
	circle = collision_shape.shape as CircleShape2D
	if circle != null:
		TEST_UTILS.expect_close(circle.radius, float(resource.get("radius")), failures, "Bush collision radius should stay synced after growth stage changes")
	resource.free()


func _test_resource_node_restore_defaults_render_only_for_legacy_saves(failures: Array[String]) -> void:
	var grass_resource := RESOURCE_NODE_SCENE.instantiate()
	grass_resource.call("setup", "grass_patch")
	grass_resource.call("restore_from_data", {
		"biome_id": "hearth_meadow",
		"mature_amount": 1,
		"amount": 1,
		"growth_stage": 3,
		"max_growth_stage": 3,
		"growth_progress": 0.0,
		"days_to_next_stage": 1.0,
		"days_since_harvested": 0.0,
		"is_harvested": false,
		"can_be_harvested": false,
		"player_harvestable": false,
		"is_edible_by_herbivores": true,
		"food_value": 0.2,
		"is_pond_vegetation": false,
		"pond_id": "",
		"food_bonus_multiplier": 1.0,
		"pond_visual_multiplier": 1.0
	})
	TEST_UTILS.expect_equal(grass_resource.get("render_only"), true, failures, "Legacy grass saves should restore render-only mode automatically")
	grass_resource.free()

	var bush_resource := RESOURCE_NODE_SCENE.instantiate()
	bush_resource.call("setup", "bush")
	bush_resource.call("restore_from_data", {
		"biome_id": "hearth_meadow",
		"mature_amount": 2,
		"amount": 2,
		"growth_stage": 3,
		"max_growth_stage": 3,
		"growth_progress": 0.0,
		"days_to_next_stage": 1.0,
		"days_since_harvested": 0.0,
		"is_harvested": false,
		"can_be_harvested": true,
		"player_harvestable": true,
		"is_edible_by_herbivores": true,
		"food_value": 0.45,
		"is_pond_vegetation": false,
		"pond_id": "",
		"food_bonus_multiplier": 1.0,
		"pond_visual_multiplier": 1.0
	})
	TEST_UTILS.expect_equal(bush_resource.get("render_only"), false, failures, "Legacy non-grass saves should stay interactive after restore")
	bush_resource.free()


func _test_resource_node_uses_shared_atlas_and_depleted_region(failures: Array[String]) -> void:
	var resource := RESOURCE_NODE_SCENE.instantiate()
	resource.call("setup", "bush")
	resource.call("_sync_visual_sprite")
	var sprite := resource.get_node("VisualSprite") as Sprite2D
	var mature_texture := sprite.texture as AtlasTexture
	TEST_UTILS.expect(mature_texture != null, failures, "ResourceNode should render through an atlas texture")
	if mature_texture != null:
		TEST_UTILS.expect_equal(int(mature_texture.region.position.y), 0, failures, "A mature resource should use the first atlas row")
	resource.call("consume_by_creature", null, 1.0)
	resource.call("consume_by_creature", null, 1.0)
	resource.call("consume_by_creature", null, 1.0)
	var depleted_texture := sprite.texture as AtlasTexture
	TEST_UTILS.expect(depleted_texture != null, failures, "A depleted resource should keep using the shared atlas")
	if depleted_texture != null:
		TEST_UTILS.expect_equal(int(depleted_texture.region.position.y), 80, failures, "A depleted resource should use the depleted atlas row")
	resource.free()


func _test_resource_node_emits_bone_collected_for_bone_drop(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var previous_event_bus := tree.root.get_node_or_null("EventBus")
	if previous_event_bus != null:
		previous_event_bus.name = "LiveEventBus"
	var event_bus := TestEventBus.new()
	event_bus.name = "EventBus"
	tree.root.add_child(event_bus)
	var resource := RESOURCE_NODE_SCENE.instantiate()
	tree.current_scene.add_child(resource)
	resource.call("setup", "bone_drop")
	var player := TestPlayer.new()
	tree.current_scene.add_child(player)
	resource.call("interact", player)
	TEST_UTILS.expect_equal(event_bus.last_event_name, "bone_collected", failures, "Bone drops should emit a bone_collected event")
	TEST_UTILS.expect_equal(int(player.inventory.get_amount("bone")), 1, failures, "Bone pickup should add bone to inventory")
	resource.queue_free()
	player.queue_free()
	event_bus.queue_free()
	if previous_event_bus != null:
		previous_event_bus.name = "EventBus"


func _test_resource_node_reports_inventory_full_when_pickup_does_not_fit(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var previous_event_bus := tree.root.get_node_or_null("EventBus")
	if previous_event_bus != null:
		previous_event_bus.name = "LiveEventBus"
	var event_bus := TestEventBus.new()
	event_bus.name = "EventBus"
	tree.root.add_child(event_bus)
	var player := TestPlayer.new()
	tree.current_scene.add_child(player)
	for i in range(9):
		player.inventory.add_item("wood", 20)
	var resource := RESOURCE_NODE_SCENE.instantiate()
	tree.current_scene.add_child(resource)
	resource.call("setup", "bone_drop")
	resource.set("amount", 1)
	resource.call("interact", player)
	TEST_UTILS.expect_equal(event_bus.last_message, "Inventory full", failures, "Full inventory should report an inventory full message")
	TEST_UTILS.expect_equal(int(player.inventory.get_amount("bone")), 0, failures, "Full inventory should not add a pickup when no space exists")
	TEST_UTILS.expect(resource.is_inside_tree(), failures, "Pickup should remain in the world when nothing was added")
	resource.queue_free()
	player.queue_free()
	event_bus.queue_free()
	if previous_event_bus != null:
		previous_event_bus.name = "EventBus"
