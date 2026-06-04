extends RefCounted

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const PLAYER_STATS := preload("res://scripts/player/player_stats.gd")
const INVENTORY := preload("res://scripts/player/inventory.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_player_stats_initial_state(failures)
	_test_player_stats_tick_and_heal_logic(failures)
	_test_player_stats_god_mode_blocks_decay_and_damage(failures)
	_test_player_stats_save_and_restore(failures)
	_test_inventory_add_remove_and_restore(failures)
	_test_player_defaults_are_valid(failures)
	_test_player_receive_damage_reduces_health(failures)
	_test_player_god_mode_syncs_to_stats_and_blocks_damage(failures)
	_test_player_torch_activation_and_deactivation(failures)
	_test_player_debug_item_helpers(failures)
	_test_player_visual_layout_looks_human_like(failures)
	_test_player_melee_attack_spends_stamina(failures)
	_test_player_bow_shooting_spends_stamina_and_sets_cooldown(failures)
	_test_player_eat_meat_consumes_inventory_and_restores_hunger(failures)
	return failures


func _test_player_stats_initial_state(failures: Array[String]) -> void:
	var stats := PLAYER_STATS.new()
	TEST_UTILS.expect_close(stats.health, stats.MAX_HEALTH, failures, "Player health should start at max")
	TEST_UTILS.expect_close(stats.hunger, stats.MAX_HUNGER, failures, "Player hunger should start at max")
	TEST_UTILS.expect_close(stats.stamina, stats.MAX_STAMINA, failures, "Player stamina should start at max")
	TEST_UTILS.expect_close(stats.rest, stats.MAX_REST, failures, "Player rest should start at max")
	TEST_UTILS.expect_equal(stats.get_condition_text(), "steady", failures, "Default player condition should be steady")


func _test_player_stats_tick_and_heal_logic(failures: Array[String]) -> void:
	var stats := PLAYER_STATS.new()
	stats.hunger = 80.0
	stats.rest = 80.0
	stats.health = 50.0
	stats.tick(10.0, false)
	TEST_UTILS.expect(stats.hunger < 80.0, failures, "Ticking should reduce hunger")
	TEST_UTILS.expect(stats.stamina > 0.0, failures, "Ticking while resting should regenerate stamina")
	TEST_UTILS.expect(stats.health >= 50.0, failures, "Healthy conditions should allow health to stay steady or regenerate")
	var after_tick_health: float = stats.health
	stats.damage(20.0)
	TEST_UTILS.expect_close(stats.health, after_tick_health - 20.0, failures, "Damage should reduce health")
	var after_damage_health: float = stats.health
	stats.heal(50.0)
	TEST_UTILS.expect_close(stats.health, min(after_damage_health + 50.0, stats.MAX_HEALTH), failures, "Healing should clamp to max health")


func _test_player_stats_save_and_restore(failures: Array[String]) -> void:
	var stats := PLAYER_STATS.new()
	stats.health = 75.0
	stats.hunger = 40.0
	stats.stamina = 55.0
	stats.rest = 65.0
	var saved := stats.get_save_data()
	stats.health = 1.0
	stats.hunger = 1.0
	stats.stamina = 1.0
	stats.rest = 1.0
	stats.restore_from_data(saved)
	TEST_UTILS.expect_close(stats.health, 75.0, failures, "Player stats should restore health")
	TEST_UTILS.expect_close(stats.hunger, 40.0, failures, "Player stats should restore hunger")
	TEST_UTILS.expect_close(stats.stamina, 55.0, failures, "Player stats should restore stamina")
	TEST_UTILS.expect_close(stats.rest, 65.0, failures, "Player stats should restore rest")


func _test_player_stats_god_mode_blocks_decay_and_damage(failures: Array[String]) -> void:
	var stats := PLAYER_STATS.new()
	stats.health = 50.0
	stats.hunger = 80.0
	stats.stamina = 45.0
	stats.rest = 60.0
	stats.set_god_mode(true)
	TEST_UTILS.expect(stats.is_god_mode_enabled(), failures, "Player stats should report god mode as enabled")
	var save_data := stats.get_save_data()
	TEST_UTILS.expect(not save_data.has("god_mode"), failures, "God mode should not be saved in normal player stat data")
	var before_health: float = stats.health
	var before_hunger: float = stats.hunger
	var before_stamina: float = stats.stamina
	var before_rest: float = stats.rest
	stats.tick(10.0, true)
	TEST_UTILS.expect(stats.health >= before_health, failures, "God mode should prevent player health from decreasing")
	TEST_UTILS.expect_close(stats.hunger, before_hunger, failures, "God mode should prevent hunger from decreasing")
	TEST_UTILS.expect_close(stats.rest, before_rest, failures, "God mode should prevent rest from decreasing")
	TEST_UTILS.expect(stats.stamina >= before_stamina, failures, "God mode should prevent stamina from decreasing")
	TEST_UTILS.expect(stats.spend_stamina(12.0), failures, "God mode should allow stamina spending without failure")
	TEST_UTILS.expect(stats.stamina >= before_stamina, failures, "God mode should keep stamina from dropping after spending")
	stats.damage(25.0)
	TEST_UTILS.expect(stats.health >= before_health, failures, "God mode should block direct damage")


func _test_inventory_add_remove_and_restore(failures: Array[String]) -> void:
	var inventory := INVENTORY.new()
	TEST_UTILS.expect_equal(inventory.get_amount("wood"), 0, failures, "Inventory should start empty")
	inventory.add_item("wood", 3)
	TEST_UTILS.expect_equal(inventory.get_amount("wood"), 3, failures, "Inventory should add items")
	TEST_UTILS.expect(inventory.remove_item("wood", 2), failures, "Inventory should remove available items")
	TEST_UTILS.expect_equal(inventory.get_amount("wood"), 1, failures, "Inventory should subtract removed items")
	TEST_UTILS.expect(not inventory.remove_item("wood", 5), failures, "Inventory should reject removals above stock")
	var saved := inventory.get_save_data()
	inventory.add_item("wood", 10)
	inventory.restore_from_data(saved)
	TEST_UTILS.expect_equal(inventory.get_amount("wood"), 1, failures, "Inventory should restore from save data")


func _test_player_defaults_are_valid(failures: Array[String]) -> void:
	var player := _make_player()
	TEST_UTILS.expect(player.world_limits.x > 0.0 and player.world_limits.y > 0.0, failures, "Player world limits should be positive")
	TEST_UTILS.expect(player.walk_speed > 0.0, failures, "Player walk speed should be positive")
	TEST_UTILS.expect(player.run_speed > 0.0, failures, "Player run speed should be positive")
	TEST_UTILS.expect_close(player.stats.health, player.stats.MAX_HEALTH, failures, "Player should spawn with full health")
	TEST_UTILS.expect_close(player.stats.hunger, player.stats.MAX_HUNGER, failures, "Player should spawn with full hunger")
	TEST_UTILS.expect_close(player.stats.stamina, player.stats.MAX_STAMINA, failures, "Player should spawn with full stamina")
	TEST_UTILS.expect_close(player.stats.rest, player.stats.MAX_REST, failures, "Player should spawn with full rest")
	TEST_UTILS.expect_close(player.rotation, 0.0, failures, "Player should not rotate as a whole body at spawn")
	player.queue_free()


func _test_player_receive_damage_reduces_health(failures: Array[String]) -> void:
	var player := _make_player()
	var before_health: float = player.stats.health
	TEST_UTILS.expect(player.receive_damage(17.0), failures, "Receiving damage should report success when god mode is off")
	TEST_UTILS.expect(player.stats.health < before_health, failures, "Receiving damage should reduce player health")
	TEST_UTILS.expect_close(player.stats.health, before_health - 17.0, failures, "Damage should reduce health by the requested amount")
	player.queue_free()


func _test_player_god_mode_syncs_to_stats_and_blocks_damage(failures: Array[String]) -> void:
	var player := _make_player()
	player.stats.health = 64.0
	player.stats.hunger = 70.0
	player.stats.stamina = 55.0
	player.stats.rest = 45.0
	player.set_god_mode(true)
	TEST_UTILS.expect(player.is_god_mode_enabled(), failures, "Player should report god mode as enabled")
	TEST_UTILS.expect(player.stats.is_god_mode_enabled(), failures, "Player stats should mirror player god mode")
	var before_health: float = player.stats.health
	var before_hunger: float = player.stats.hunger
	var before_stamina: float = player.stats.stamina
	var before_rest: float = player.stats.rest
	TEST_UTILS.expect(not player.receive_damage(19.0, "varnak"), failures, "God mode should block incoming damage")
	TEST_UTILS.expect_close(player.stats.health, before_health, failures, "God mode should keep player health unchanged after damage")
	TEST_UTILS.expect_close(player.stats.hunger, before_hunger, failures, "God mode should keep player hunger unchanged after damage")
	TEST_UTILS.expect_close(player.stats.stamina, before_stamina, failures, "God mode should keep player stamina unchanged after damage")
	TEST_UTILS.expect_close(player.stats.rest, before_rest, failures, "God mode should keep player rest unchanged after damage")
	player.debug_damage_player()
	TEST_UTILS.expect_close(player.stats.health, before_health, failures, "Debug damage should not reduce health in god mode")
	player.queue_free()


func _test_player_torch_activation_and_deactivation(failures: Array[String]) -> void:
	var player := _make_player()
	player.inventory.add_item("torch", 1)
	TEST_UTILS.expect(player.activate_torch(), failures, "Player should be able to activate a torch if one is present")
	TEST_UTILS.expect(player.is_torch_active(), failures, "Torch should become active after activation")
	TEST_UTILS.expect(player.get_torch_remaining_seconds() > 0.0, failures, "Active torch should report remaining time")
	player.deactivate_torch("manual")
	TEST_UTILS.expect(not player.is_torch_active(), failures, "Torch should deactivate cleanly")
	player.queue_free()


func _test_player_debug_item_helpers(failures: Array[String]) -> void:
	var player := _make_player()
	player.debug_add_item("spear")
	TEST_UTILS.expect(player.has_spear, failures, "Debug item helper should equip a spear")
	player.debug_add_item("bow")
	TEST_UTILS.expect(player.has_bow, failures, "Debug item helper should equip a bow")
	player.queue_free()


func _test_player_visual_layout_looks_human_like(failures: Array[String]) -> void:
	var player := _make_player()
	var layout: Dictionary = player.call("_get_player_visual_layout")
	TEST_UTILS.expect(not layout.is_empty(), failures, "Player should expose a visual layout for the drawn body")
	var head_center: Vector2 = Vector2(layout.get("head_center", Vector2.ZERO))
	var head_radius: float = float(layout.get("head_radius", 0.0))
	var torso: PackedVector2Array = layout.get("torso", PackedVector2Array())
	var back_arm: PackedVector2Array = layout.get("back_arm", PackedVector2Array())
	var front_arm: PackedVector2Array = layout.get("front_arm", PackedVector2Array())
	var back_leg: PackedVector2Array = layout.get("back_leg", PackedVector2Array())
	var front_leg: PackedVector2Array = layout.get("front_leg", PackedVector2Array())
	TEST_UTILS.expect(head_radius >= 5.0, failures, "Player head should be readable as a human head")
	TEST_UTILS.expect(torso.size() >= 6, failures, "Player torso should be built from a clear polygon")
	TEST_UTILS.expect(back_arm.size() >= 4 and front_arm.size() >= 4, failures, "Player arms should be separate visible limbs")
	TEST_UTILS.expect(back_leg.size() >= 4 and front_leg.size() >= 4, failures, "Player legs should be separate visible limbs")
	var torso_center := _get_polygon_center(torso)
	TEST_UTILS.expect(head_center.x > torso_center.x, failures, "Player head should sit in front of the torso in the facing direction")
	TEST_UTILS.expect(head_center.y < torso_center.y, failures, "Player head should sit above the torso")
	TEST_UTILS.expect(_get_polygon_max_y(back_leg) > torso_center.y, failures, "Player legs should extend below the torso")
	TEST_UTILS.expect(_get_polygon_max_y(front_leg) > torso_center.y, failures, "Player legs should extend below the torso")
	player.queue_free()


func _test_player_draw_pose_flips_and_tilts_without_spinning(failures: Array[String]) -> void:
	var player := _make_player()
	player.set("aim_direction", Vector2.LEFT)
	var left_pose: Dictionary = player.call("_get_player_draw_pose")
	TEST_UTILS.expect_equal(left_pose.get("flip_x", false), true, failures, "Player should mirror the drawn body when aiming left")
	TEST_UTILS.expect_close(float(left_pose.get("body_angle", 0.0)), 0.0, failures, "Player should keep the body level when aiming horizontally")
	TEST_UTILS.expect_close(player.rotation, 0.0, failures, "Player node should stay unrotated when aiming left")
	player.set("aim_direction", Vector2(0.0, -1.0))
	var up_pose: Dictionary = player.call("_get_player_draw_pose")
	TEST_UTILS.expect(float(up_pose.get("body_angle", 0.0)) < 0.0, failures, "Player should tilt slightly upward when aiming north")
	TEST_UTILS.expect(abs(float(up_pose.get("body_angle", 0.0))) <= deg_to_rad(16.0), failures, "Player tilt should stay subtle rather than spinning around")
	player.set("aim_direction", Vector2(0.0, 1.0))
	var down_pose: Dictionary = player.call("_get_player_draw_pose")
	TEST_UTILS.expect(float(down_pose.get("body_angle", 0.0)) > 0.0, failures, "Player should tilt slightly downward when aiming south")
	TEST_UTILS.expect_close(player.rotation, 0.0, failures, "Player node should stay unrotated when aiming vertically")
	player.queue_free()


func _test_player_melee_attack_spends_stamina(failures: Array[String]) -> void:
	var player := _make_player()
	var before_stamina: float = player.stats.stamina
	player.call("_melee_attack")
	TEST_UTILS.expect(player.stats.stamina < before_stamina, failures, "Melee attack should spend stamina")
	TEST_UTILS.expect(player.attack_visual_time > 0.0, failures, "Melee attack should trigger attack visuals")
	player.queue_free()


func _test_player_bow_shooting_spends_stamina_and_sets_cooldown(failures: Array[String]) -> void:
	var player := _make_player()
	player.has_bow = true
	var before_stamina: float = player.stats.stamina
	player.call("_shoot_bow")
	TEST_UTILS.expect(player.stats.stamina < before_stamina, failures, "Bow shot should spend stamina")
	TEST_UTILS.expect(player.bow_cooldown > 0.0, failures, "Bow shot should start cooldown")
	player.queue_free()


func _test_player_eat_meat_consumes_inventory_and_restores_hunger(failures: Array[String]) -> void:
	var player := _make_player()
	player.stats.hunger = 10.0
	player.inventory.add_item("meat", 1)
	player.call("_eat", "meat")
	TEST_UTILS.expect_equal(player.inventory.get_amount("meat"), 0, failures, "Eating meat should consume one meat")
	TEST_UTILS.expect(player.stats.hunger > 10.0, failures, "Eating meat should restore hunger")
	player.queue_free()


func _make_player() -> Node:
	var player := PLAYER_SCENE.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.current_scene.add_child(player)
	return player


func _get_polygon_center(points: PackedVector2Array) -> Vector2:
	var center := Vector2.ZERO
	if points.is_empty():
		return center
	for point in points:
		center += point
	return center / float(points.size())


func _get_polygon_max_y(points: PackedVector2Array) -> float:
	var max_y := -INF
	for point in points:
		max_y = max(max_y, point.y)
	return max_y
