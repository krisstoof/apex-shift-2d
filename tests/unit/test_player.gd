extends RefCounted

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const PLAYER_STATS := preload("res://scripts/player/player_stats.gd")
const INVENTORY := preload("res://scripts/player/inventory.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_player_stats_initial_state(failures)
	_test_player_stats_tick_and_heal_logic(failures)
	_test_player_stats_save_and_restore(failures)
	_test_inventory_add_remove_and_restore(failures)
	_test_player_defaults_are_valid(failures)
	_test_player_receive_damage_reduces_health(failures)
	_test_player_torch_activation_and_deactivation(failures)
	_test_player_debug_item_helpers(failures)
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
	player.queue_free()


func _test_player_receive_damage_reduces_health(failures: Array[String]) -> void:
	var player := _make_player()
	var before_health: float = player.stats.health
	player.receive_damage(17.0)
	TEST_UTILS.expect(player.stats.health < before_health, failures, "Receiving damage should reduce player health")
	TEST_UTILS.expect_close(player.stats.health, before_health - 17.0, failures, "Damage should reduce health by the requested amount")
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
