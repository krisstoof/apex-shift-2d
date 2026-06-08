extends RefCounted

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const HUD_SCRIPT := preload("res://scripts/ui/hud.gd")
const PLAYER_STATS := preload("res://scripts/player/player_stats.gd")
const INVENTORY := preload("res://scripts/player/inventory.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


class TestPlayer:
	extends Node
	var stats := {
		"health": 100.0,
		"MAX_HEALTH": 100.0
	}


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_hud_builds_compact_player_stats_from_snapshot(failures)
	_test_hud_shows_resource_counts_from_player_inventory(failures)
	_test_hud_filters_world_messages_from_message_history(failures)
	_test_hud_reads_hunger_from_player_stats_object(failures)
	_test_hud_reads_stamina_from_player_stats_object(failures)
	_test_hud_reads_rest_from_player_stats_object(failures)
	_test_hud_creates_critical_health_overlay(failures)
	_test_hud_activates_warning_when_health_is_low(failures)
	_test_game_over_scene_is_root_full_rect(failures)
	_test_hud_survival_warning_debug_exists(failures)
	return failures


func _test_hud_builds_compact_player_stats_from_snapshot(failures: Array[String]) -> void:
	var hud := HUD_SCRIPT.new()
	var snapshot := {
		"time": {
			"clock_time": "13:48",
			"day": 3,
			"time_label": "Day"
		},
		"player": {
			"health": 91,
			"max_health": 100,
			"hunger": 62,
			"stamina": 48,
			"rest": 77,
			"prompt_text": "E: interact",
			"condition_text": "steady",
			"campfire_regen_active": true,
			"torch_active": true,
			"torch_remaining_seconds": 17.2,
			"has_spear": true,
			"has_bow": true,
			"inventory": {
				"wood": 4,
				"stone": 3,
				"fiber": 2,
				"meat": 1,
				"torch": 2
			}
		}
	}
	var player_stats_text: String = hud.call("_build_player_stats_text_from_snapshot", snapshot)
	TEST_UTILS.expect(player_stats_text.contains("HP: 91 / 100"), failures, "HUD should show player health in the compact stats section")
	TEST_UTILS.expect(player_stats_text.contains("Hunger: 62%"), failures, "HUD should show player hunger in the compact stats section")
	TEST_UTILS.expect(player_stats_text.contains("Stamina: 48%"), failures, "HUD should show player stamina in the compact stats section")
	TEST_UTILS.expect(player_stats_text.contains("Rest: 77%"), failures, "HUD should show player rest in the compact stats section")
	TEST_UTILS.expect(player_stats_text.contains("Day: 3"), failures, "HUD should show the current day in the compact stats section")
	TEST_UTILS.expect(player_stats_text.contains("Time: Day"), failures, "HUD should show the time label in the compact stats section")
	TEST_UTILS.expect(player_stats_text.contains("Torch: active 18s"), failures, "HUD should show the torch status in the compact stats section")
	TEST_UTILS.expect(player_stats_text.contains("Bow: Yes"), failures, "HUD should show bow ownership in the compact stats section")
	TEST_UTILS.expect(player_stats_text.contains("Spear: Yes"), failures, "HUD should keep spear ownership visible in the compact stats section")
	TEST_UTILS.expect(player_stats_text.contains("Wood: 4"), failures, "HUD should keep the basic inventory snapshot visible in the compact stats section")
	TEST_UTILS.expect_equal(hud.call("_get_prompt_text_from_snapshot", snapshot), "E: interact", failures, "HUD should still read the interaction prompt from snapshot data")
	hud.free()


func _test_hud_filters_world_messages_from_message_history(failures: Array[String]) -> void:
	var hud := _make_hud()
	hud.call("_on_message", "Apex Shift 2D prototype ready")
	hud.call("_on_message", "SmallPrey entered the ecosystem")
	hud.call("_on_message", "Crafted torch")
	hud.call("_on_message", "Collected wood x1")
	hud.call("_on_message", "Ate meat")
	hud.call("_on_game_event", "ecosystem_biome_stressed", {"biome_id": "westwood"})
	var message_history: Array[String] = Array(hud.get("message_history"))
	TEST_UTILS.expect_equal(message_history.size(), 3, failures, "HUD should keep only player-relevant messages in the history")
	TEST_UTILS.expect_equal(message_history[0], "Crafted torch", failures, "HUD should preserve player action messages")
	TEST_UTILS.expect_equal(message_history[1], "Collected wood x1", failures, "HUD should preserve collection messages")
	TEST_UTILS.expect_equal(message_history[2], "Ate meat", failures, "HUD should preserve eating messages")
	hud.queue_free()


class ResourcePlayer:
	extends Node2D

	var inventory := INVENTORY.new()
	var stats := PLAYER_STATS.new()
	var has_spear := false
	var has_bow := false
	var recipes := {}

	func is_torch_active() -> bool:
		return false


func _test_hud_shows_resource_counts_from_player_inventory(failures: Array[String]) -> void:
	var hud := _make_hud()
	var player := ResourcePlayer.new()
	hud.bind(player, Node.new(), Node.new(), null)
	var wood_icon: TextureRect = hud.get_node("ResourcePanel/ResourceHBox/WoodItem/Icon")
	var stone_icon: TextureRect = hud.get_node("ResourcePanel/ResourceHBox/StoneItem/Icon")
	var fiber_icon: TextureRect = hud.get_node("ResourcePanel/ResourceHBox/FiberItem/Icon")
	var meat_icon: TextureRect = hud.get_node("ResourcePanel/ResourceHBox/MeatItem/Icon")
	var bone_icon: TextureRect = hud.get_node("ResourcePanel/ResourceHBox/BoneItem/Icon")
	var wood_label: Label = hud.get_node("ResourcePanel/ResourceHBox/WoodItem/CountLabel")
	var stone_label: Label = hud.get_node("ResourcePanel/ResourceHBox/StoneItem/CountLabel")
	var fiber_label: Label = hud.get_node("ResourcePanel/ResourceHBox/FiberItem/CountLabel")
	var meat_label: Label = hud.get_node("ResourcePanel/ResourceHBox/MeatItem/CountLabel")
	var bone_label: Label = hud.get_node("ResourcePanel/ResourceHBox/BoneItem/CountLabel")
	TEST_UTILS.expect_equal(wood_icon.custom_minimum_size, Vector2(36, 36), failures, "HUD should clamp wood icon size to 36x36")
	TEST_UTILS.expect_equal(stone_icon.custom_minimum_size, Vector2(36, 36), failures, "HUD should clamp stone icon size to 36x36")
	TEST_UTILS.expect_equal(fiber_icon.custom_minimum_size, Vector2(36, 36), failures, "HUD should clamp fiber icon size to 36x36")
	TEST_UTILS.expect_equal(meat_icon.custom_minimum_size, Vector2(36, 36), failures, "HUD should clamp meat icon size to 36x36")
	TEST_UTILS.expect_equal(bone_icon.custom_minimum_size, Vector2(36, 36), failures, "HUD should clamp bone icon size to 36x36")
	TEST_UTILS.expect_equal(int(wood_icon.stretch_mode), int(TextureRect.STRETCH_KEEP_ASPECT_CENTERED), failures, "HUD should keep wood icon aspect centered")
	TEST_UTILS.expect_equal(int(wood_icon.expand_mode), int(TextureRect.EXPAND_IGNORE_SIZE), failures, "HUD should ignore wood icon source size")
	TEST_UTILS.expect_equal(int(hud.get_node("ResourcePanel").anchor_left), 0, failures, "HUD resource panel should anchor to left")
	TEST_UTILS.expect_equal(int(hud.get_node("ResourcePanel").anchor_bottom), 1, failures, "HUD resource panel should anchor to bottom")
	var resource_panel: Control = hud.get_node("ResourcePanel")
	var panel_style := resource_panel.get_theme_stylebox("panel")
	TEST_UTILS.expect(panel_style is StyleBoxFlat, failures, "HUD resource panel should use a flat stylebox")
	if panel_style is StyleBoxFlat:
		TEST_UTILS.expect_equal((panel_style as StyleBoxFlat).bg_color, Color(0.0, 0.0, 0.0, 0.45), failures, "HUD resource panel should use a translucent dark background")
	TEST_UTILS.expect_equal(wood_label.text, "0", failures, "HUD should start with zero wood")
	TEST_UTILS.expect_equal(stone_label.text, "0", failures, "HUD should start with zero stone")
	TEST_UTILS.expect_equal(fiber_label.text, "0", failures, "HUD should start with zero fiber")
	TEST_UTILS.expect_equal(meat_label.text, "0", failures, "HUD should start with zero meat")
	TEST_UTILS.expect_equal(bone_label.text, "0", failures, "HUD should start with zero bone")
	player.inventory.add_item("wood", 4)
	player.inventory.add_item("stone", 2)
	player.inventory.add_item("fiber", 3)
	player.inventory.add_item("meat", 1)
	player.inventory.add_item("bone", 5)
	TEST_UTILS.expect_equal(wood_label.text, "4", failures, "HUD should update wood after inventory changes")
	TEST_UTILS.expect_equal(stone_label.text, "2", failures, "HUD should update stone after inventory changes")
	TEST_UTILS.expect_equal(fiber_label.text, "3", failures, "HUD should update fiber after inventory changes")
	TEST_UTILS.expect_equal(meat_label.text, "1", failures, "HUD should update meat after inventory changes")
	TEST_UTILS.expect_equal(bone_label.text, "5", failures, "HUD should update bone after inventory changes")
	player.inventory.remove_item("wood", 1)
	TEST_UTILS.expect_equal(wood_label.text, "3", failures, "HUD should refresh wood after removals")
	TEST_UTILS.expect(wood_label.visible, failures, "HUD resource labels should remain visible when inventory is populated")
	hud.queue_free()


class PlayerStatsPlayer:
	extends Node

	var stats := PLAYER_STATS.new()


func _test_hud_reads_hunger_from_player_stats_object(failures: Array[String]) -> void:
	var hud := _make_hud()
	var player := PlayerStatsPlayer.new()
	player.stats.hunger = 20.0
	player.stats.stamina = 100.0
	player.stats.rest = 100.0
	hud.player = player
	hud.evolution_director = Node.new()
	hud.day_night_system = Node.new()
	var before_history_size := Array(hud.get("message_history")).size()
	hud.call("_update_survival_warning_messages", 0.5)
	var message_history: Array[String] = Array(hud.get("message_history"))
	TEST_UTILS.expect_equal(message_history.size(), before_history_size + 1, failures, "HUD should append a hunger warning for low hunger")
	if not message_history.is_empty():
		TEST_UTILS.expect_equal(message_history[message_history.size() - 1], "You are hungry. Find food soon.", failures, "HUD should read hunger from PlayerStats object")
	hud.queue_free()


func _test_hud_reads_stamina_from_player_stats_object(failures: Array[String]) -> void:
	var hud := _make_hud()
	var player := PlayerStatsPlayer.new()
	player.stats.hunger = 100.0
	player.stats.stamina = 15.0
	player.stats.rest = 100.0
	hud.player = player
	hud.evolution_director = Node.new()
	hud.day_night_system = Node.new()
	var before_history_size := Array(hud.get("message_history")).size()
	hud.call("_update_survival_warning_messages", 0.5)
	var message_history: Array[String] = Array(hud.get("message_history"))
	TEST_UTILS.expect_equal(message_history.size(), before_history_size + 1, failures, "HUD should append an exhaustion warning for low stamina")
	if not message_history.is_empty():
		TEST_UTILS.expect_equal(message_history[message_history.size() - 1], "You are exhausted. Rest near a campfire to recover faster.", failures, "HUD should read stamina from PlayerStats object")
	hud.queue_free()


func _test_hud_reads_rest_from_player_stats_object(failures: Array[String]) -> void:
	var hud := _make_hud()
	var player := PlayerStatsPlayer.new()
	player.stats.hunger = 100.0
	player.stats.stamina = 100.0
	player.stats.rest = 15.0
	hud.player = player
	hud.evolution_director = Node.new()
	hud.day_night_system = Node.new()
	var before_history_size := Array(hud.get("message_history")).size()
	hud.call("_update_survival_warning_messages", 0.5)
	var message_history: Array[String] = Array(hud.get("message_history"))
	TEST_UTILS.expect_equal(message_history.size(), before_history_size + 1, failures, "HUD should append an exhaustion warning for low rest")
	if not message_history.is_empty():
		TEST_UTILS.expect_equal(message_history[message_history.size() - 1], "You are exhausted. Rest near a campfire to recover faster.", failures, "HUD should read rest from PlayerStats object")
	hud.queue_free()


func _test_hud_creates_critical_health_overlay(failures: Array[String]) -> void:
	var hud := _make_hud()
	var debug_state: Dictionary = hud.call("get_critical_health_debug")
	TEST_UTILS.expect_equal(debug_state.get("overlay_visible", false), false, failures, "Critical health overlay should start hidden")
	TEST_UTILS.expect_equal(debug_state.get("overlay_alpha", 1.0), 0.0, failures, "Critical health overlay should start transparent")
	hud.queue_free()


func _test_hud_activates_warning_when_health_is_low(failures: Array[String]) -> void:
	var hud := _make_hud()
	var player := TestPlayer.new()
	player.stats.health = 15.0
	player.stats.MAX_HEALTH = 100.0
	hud.player = player
	hud.evolution_director = Node.new()
	hud.day_night_system = Node.new()
	hud.call("_update_critical_health_warning", 0.5)
	var debug_state: Dictionary = hud.call("get_critical_health_debug")
	TEST_UTILS.expect_equal(debug_state.get("active", false), true, failures, "Critical health warning should activate when health drops below the threshold")
	TEST_UTILS.expect_equal(debug_state.get("overlay_visible", false), true, failures, "Critical health overlay should become visible at low health")
	TEST_UTILS.expect(float(debug_state.get("overlay_alpha", 0.0)) > 0.0, failures, "Critical health overlay should gain a visible alpha when active")
	player.stats.health = 80.0
	hud.call("_update_critical_health_warning", 0.5)
	debug_state = hud.call("get_critical_health_debug")
	TEST_UTILS.expect_equal(debug_state.get("active", true), false, failures, "Critical health warning should deactivate when health recovers")
	TEST_UTILS.expect_equal(debug_state.get("overlay_visible", true), false, failures, "Critical health overlay should hide when health recovers")
	TEST_UTILS.expect_equal(debug_state.get("overlay_alpha", 1.0), 0.0, failures, "Critical health overlay should become transparent when inactive")
	hud.queue_free()


func _test_game_over_scene_is_root_full_rect(failures: Array[String]) -> void:
	var scene_text := FileAccess.get_file_as_string("res://scenes/ui/game_over_screen.tscn")
	TEST_UTILS.expect(scene_text.contains("anchors_preset = 15"), failures, "Game Over root should fill the full screen so the internal center container can center the panel")
	TEST_UTILS.expect(scene_text.contains("GameOverScreen"), failures, "Game Over scene should still define the expected root node")


func _test_hud_survival_warning_debug_exists(failures: Array[String]) -> void:
	var hud := _make_hud()
	var debug_state: Dictionary = hud.call("get_survival_warning_debug")
	TEST_UTILS.expect(debug_state.has("hunger_warning_timer"), failures, "HUD should expose survival warning debug timers")
	TEST_UTILS.expect(debug_state.has("exhaustion_warning_timer"), failures, "HUD should expose exhaustion warning debug timers")
	TEST_UTILS.expect(debug_state.has("campfire_hint_timer"), failures, "HUD should expose campfire hint debug timers")
	hud.queue_free()


func _make_hud() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	var hud := HUD_SCENE.instantiate()
	tree.current_scene.add_child(hud)
	return hud
