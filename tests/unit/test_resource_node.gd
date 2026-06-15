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
	_test_resource_node_visibility_culling_toggles_active_state(failures)
	_test_resource_node_restore_recreates_edible_food_value(failures)
	_test_resource_node_restore_defaults_render_only_for_legacy_saves(failures)
	_test_resource_node_syncs_collision_radius_with_growth(failures)
	_test_resource_node_uses_shared_atlas_and_depleted_region(failures)
	_test_resource_node_renders_and_regrows_dry_tree(failures)
	_test_resource_node_harvest_tree_marks_as_regrowing(failures)
	_test_resource_node_advance_growth_days_restores_harvestable_tree(failures)
	_test_resource_node_force_full_regrowth_restores_mature_state(failures)
	_test_resource_node_meat_drop_does_not_use_regrowth(failures)
	_test_resource_node_grass_patch_is_not_player_harvestable(failures)
	_test_resource_node_save_load_round_trip_preserves_growth_state(failures)
	_test_resource_node_renders_bone_drop_through_custom_draw(failures)
	_test_resource_node_emits_bone_collected_for_bone_drop(failures)
	_test_resource_node_reports_inventory_full_when_pickup_does_not_fit(failures)
	_test_resource_node_picks_up_generic_item_drop(failures)
	_test_resource_node_keeps_generic_item_drop_when_inventory_full(failures)
	_test_resource_node_rejects_partial_pickup_for_full_stack_drop(failures)
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


func _test_resource_node_visibility_culling_toggles_active_state(failures: Array[String]) -> void:
	var resource := RESOURCE_NODE_SCENE.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.current_scene.add_child(resource)
	var collision_shape := resource.get_node("CollisionShape2D") as CollisionShape2D
	TEST_UTILS.expect(resource.has_method("set_visibility_culled"), failures, "Resource nodes should expose visibility culling")
	resource.call("set_visibility_culled", false)
	TEST_UTILS.expect_equal(resource.visible, false, failures, "Culled resources should be hidden")
	TEST_UTILS.expect_equal(bool(resource.get("is_visibility_culled")), true, failures, "Culled resources should remember they are sleeping")
	if collision_shape != null:
		TEST_UTILS.expect_equal(collision_shape.disabled, true, failures, "Culled resources should disable collision")
	resource.call("set_visibility_culled", true)
	TEST_UTILS.expect_equal(resource.visible, true, failures, "Visible resources should be shown again")
	TEST_UTILS.expect_equal(bool(resource.get("is_visibility_culled")), false, failures, "Visible resources should clear the sleeping flag")
	if collision_shape != null:
		TEST_UTILS.expect_equal(collision_shape.disabled, false, failures, "Reactivated resources should restore collision")
	resource.queue_free()


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


func _test_resource_node_renders_and_regrows_dry_tree(failures: Array[String]) -> void:
	var resource := RESOURCE_NODE_SCENE.instantiate()
	resource.call("setup", "dry_tree")
	TEST_UTILS.expect_equal(str(resource.get("item_name")), "wood", failures, "Dry trees should still provide wood")
	TEST_UTILS.expect_equal(resource.get("is_edible_by_herbivores") == true, false, failures, "Dry trees should not be herbivore food")
	TEST_UTILS.expect_equal(float(resource.get("food_value")), 0.0, failures, "Dry trees should not expose a food value")
	TEST_UTILS.expect_equal(int(resource.call("_get_regrowth_time_days")), 15, failures, "Dry trees should inherit the slowed tree regrowth")
	resource.call("_sync_visual_sprite")
	var sprite := resource.get_node("VisualSprite") as Sprite2D
	var atlas_texture := sprite.texture as AtlasTexture
	TEST_UTILS.expect(atlas_texture != null, failures, "Dry trees should render through the shared resource atlas")
	if atlas_texture != null:
		TEST_UTILS.expect_equal(int(atlas_texture.region.position.x), 880, failures, "Dry trees should use the dry-tree atlas column")
		TEST_UTILS.expect_equal(int(atlas_texture.region.position.y), 0, failures, "Dry trees should use the mature atlas row before depletion")
	resource.free()


func _test_resource_node_harvest_tree_marks_as_regrowing(failures: Array[String]) -> void:
	var resource := RESOURCE_NODE_SCENE.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.current_scene.add_child(resource)
	resource.call("setup", "conifer_tree")
	var player := TestPlayer.new()
	tree.current_scene.add_child(player)
	resource.call("interact", player)
	TEST_UTILS.expect(resource.get("growth_stage") == 0, failures, "Harvested trees should drop to depleted growth")
	TEST_UTILS.expect_equal(resource.get("is_harvested"), true, failures, "Harvested trees should mark themselves as harvested")
	TEST_UTILS.expect_equal(resource.get("can_be_harvested"), false, failures, "Harvested trees should stop being harvestable")
	resource.queue_free()
	player.queue_free()


func _test_resource_node_advance_growth_days_restores_harvestable_tree(failures: Array[String]) -> void:
	var resource := RESOURCE_NODE_SCENE.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.current_scene.add_child(resource)
	resource.call("setup", "bush")
	var player := TestPlayer.new()
	tree.current_scene.add_child(player)
	resource.call("interact", player)
	resource.call("advance_growth_days", 3.0)
	TEST_UTILS.expect_equal(resource.get("growth_stage"), resource.get("max_growth_stage"), failures, "Growth days should restore the mature growth stage")
	TEST_UTILS.expect_equal(resource.get("is_harvested"), false, failures, "Regrown trees should clear harvested state")
	TEST_UTILS.expect_equal(resource.get("can_be_harvested"), true, failures, "Regrown trees should be harvestable again")
	TEST_UTILS.expect(resource.get("amount") > 0, failures, "Regrown trees should regain a positive yield")
	TEST_UTILS.expect(resource.call("is_player_interactable"), failures, "Regrown trees should be interactable again")
	resource.queue_free()
	player.queue_free()


func _test_resource_node_force_full_regrowth_restores_mature_state(failures: Array[String]) -> void:
	var resource := RESOURCE_NODE_SCENE.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.current_scene.add_child(resource)
	resource.call("setup", "bush")
	var player := TestPlayer.new()
	tree.current_scene.add_child(player)
	resource.call("interact", player)
	resource.call("force_full_regrowth")
	TEST_UTILS.expect_equal(resource.get("growth_stage"), resource.get("max_growth_stage"), failures, "Force regrowth should restore the mature stage")
	TEST_UTILS.expect_equal(resource.get("growth_progress"), 0.0, failures, "Force regrowth should clear progress")
	TEST_UTILS.expect_equal(resource.get("days_since_harvested"), 0.0, failures, "Force regrowth should clear harvested days")
	TEST_UTILS.expect_equal(resource.get("is_harvested"), false, failures, "Force regrowth should clear harvested state")
	resource.queue_free()
	player.queue_free()


func _test_resource_node_meat_drop_does_not_use_regrowth(failures: Array[String]) -> void:
	var resource := RESOURCE_NODE_SCENE.instantiate()
	resource.call("setup", "meat_drop")
	TEST_UTILS.expect_equal(resource.call("advance_growth_days", 3.0), false, failures, "Meat drops should not use regrowth")
	TEST_UTILS.expect_equal(resource.get("can_be_harvested"), true, failures, "Meat drops should stay harvestable until empty")
	TEST_UTILS.expect_equal(resource.get("is_harvested"), false, failures, "Meat drops should not be treated as harvested plants")
	resource.free()


func _test_resource_node_grass_patch_is_not_player_harvestable(failures: Array[String]) -> void:
	var resource := RESOURCE_NODE_SCENE.instantiate()
	resource.call("setup", "grass_patch")
	TEST_UTILS.expect_equal(resource.get("player_harvestable"), false, failures, "Grass patches should not be player harvestable")
	TEST_UTILS.expect_equal(resource.is_player_interactable(), false, failures, "Grass patches should not be interactable by the player")
	resource.free()


func _test_resource_node_save_load_round_trip_preserves_growth_state(failures: Array[String]) -> void:
	var resource := RESOURCE_NODE_SCENE.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.current_scene.add_child(resource)
	resource.call("setup", "bush")
	var player := TestPlayer.new()
	tree.current_scene.add_child(player)
	resource.call("interact", player)
	resource.call("advance_growth_days", 0.5)
	var save_data: Dictionary = resource.call("get_save_data")
	var restored := RESOURCE_NODE_SCENE.instantiate()
	tree.current_scene.add_child(restored)
	restored.call("setup", "bush")
	restored.call("restore_from_data", save_data)
	TEST_UTILS.expect_equal(restored.get("growth_stage"), save_data.get("growth_stage"), failures, "Restore should keep the growth stage")
	TEST_UTILS.expect_equal(restored.get("is_harvested"), save_data.get("is_harvested"), failures, "Restore should keep harvested state")
	TEST_UTILS.expect_equal(restored.get("can_be_harvested"), save_data.get("can_be_harvested"), failures, "Restore should keep harvestable state")
	TEST_UTILS.expect_equal(restored.get("amount"), save_data.get("amount"), failures, "Restore should keep current amount")
	resource.queue_free()
	restored.queue_free()
	player.queue_free()


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


func _test_resource_node_renders_bone_drop_through_custom_draw(failures: Array[String]) -> void:
	var resource := RESOURCE_NODE_SCENE.instantiate()
	resource.call("setup", "bone_drop")
	resource.call("_sync_visual_sprite")
	var sprite := resource.get_node("VisualSprite") as Sprite2D
	TEST_UTILS.expect(sprite != null, failures, "Bone drops should keep a visual sprite node")
	if sprite != null:
		TEST_UTILS.expect_equal(sprite.visible, false, failures, "Bone drops should bypass the atlas sprite and use custom drawing")
	TEST_UTILS.expect_equal(resource.call("is_render_only_resource"), false, failures, "Bone drops should stay interactive like meat drops")
	resource.free()


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


func _test_resource_node_picks_up_generic_item_drop(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var resource := RESOURCE_NODE_SCENE.instantiate()
	tree.current_scene.add_child(resource)
	resource.call("setup", "item_drop")
	resource.set("item_id", "wood")
	resource.set("amount", 3)
	var player := TestPlayer.new()
	tree.current_scene.add_child(player)
	resource.call("interact", player)
	TEST_UTILS.expect_equal(int(player.inventory.get_amount("wood")), 3, failures, "Generic item drops should add their item to the inventory")
	TEST_UTILS.expect_equal(resource.is_queued_for_deletion(), true, failures, "Generic item drops should disappear after a successful pickup")
	player.queue_free()


func _test_resource_node_keeps_generic_item_drop_when_inventory_full(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var previous_event_bus := tree.root.get_node_or_null("EventBus")
	if previous_event_bus != null:
		previous_event_bus.name = "LiveEventBus"
	var event_bus := TestEventBus.new()
	event_bus.name = "EventBus"
	tree.root.add_child(event_bus)
	var resource := RESOURCE_NODE_SCENE.instantiate()
	tree.current_scene.add_child(resource)
	resource.call("setup", "item_drop")
	resource.set("item_id", "stone")
	resource.set("amount", 2)
	var player := TestPlayer.new()
	tree.current_scene.add_child(player)
	for i in range(9):
		player.inventory.add_item("wood", 20)
	resource.call("interact", player)
	TEST_UTILS.expect_equal(event_bus.last_message, "Inventory full", failures, "Full inventory should report an inventory full message for generic item drops")
	TEST_UTILS.expect_equal(int(player.inventory.get_amount("stone")), 0, failures, "Full inventory should not add a generic item drop")
	TEST_UTILS.expect(resource.is_inside_tree(), failures, "Generic item drops should stay in the world when pickup fails")
	resource.queue_free()
	player.queue_free()
	event_bus.queue_free()
	if previous_event_bus != null:
		previous_event_bus.name = "EventBus"


func _test_resource_node_rejects_partial_pickup_for_full_stack_drop(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var previous_event_bus := tree.root.get_node_or_null("EventBus")
	if previous_event_bus != null:
		previous_event_bus.name = "LiveEventBus"
	var event_bus := TestEventBus.new()
	event_bus.name = "EventBus"
	tree.root.add_child(event_bus)
	var resource := RESOURCE_NODE_SCENE.instantiate()
	tree.current_scene.add_child(resource)
	resource.call("setup", "item_drop")
	resource.set("item_id", "wood")
	resource.set("amount", 2)
	var player := TestPlayer.new()
	tree.current_scene.add_child(player)
	for i in range(9):
		player.inventory.add_item("wood", 20)
	player.inventory.remove_item("wood", 1)
	resource.call("interact", player)
	TEST_UTILS.expect_equal(event_bus.last_message, "Inventory full", failures, "Partial space should still reject a full stack pickup")
	TEST_UTILS.expect_equal(int(player.inventory.get_amount("wood")), 179, failures, "Partial space should not modify inventory on a rejected stack pickup")
	TEST_UTILS.expect_equal(int(resource.get("amount")), 2, failures, "Rejected stack pickup should remain unchanged in the world")
	TEST_UTILS.expect(resource.is_inside_tree(), failures, "Rejected stack pickup should remain in the world")
	resource.queue_free()
	player.queue_free()
	event_bus.queue_free()
	if previous_event_bus != null:
		previous_event_bus.name = "EventBus"
