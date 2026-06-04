extends RefCounted

const SAVE_SYSTEM_SCRIPT := preload("res://scripts/systems/save_system.gd")
const PLAYER_STATS := preload("res://scripts/player/player_stats.gd")
const INVENTORY := preload("res://scripts/player/inventory.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


class TestPlayer:
	extends Node2D

	var stats := PLAYER_STATS.new()
	var inventory := INVENTORY.new()
	var has_spear := false
	var has_bow := false
	var torch_active := false
	var torch_remaining_seconds := 0.0

	func clear_inactive_torch_state() -> void:
		torch_active = false
		torch_remaining_seconds = 0.0


class TestCampfire:
	extends Node2D

	var active := true
	var fear_radius := 180.0


class TestTrap:
	extends Node2D

	var armed := true
	var damage := 12.0


class TestWall:
	extends Node2D

	var health := 100.0


class TestWorldSaveData:
	extends Node

	var restored_landmarks: Array = []
	var restored_world_seed := 0
	var restore_landmarks_call_count := 0

	func get_save_data() -> Dictionary:
		return {
			"world_seed": 9182,
			"landmarks": [{
				"id": "save_pond",
				"type": "pond",
				"position": {"x": 120.0, "y": -44.0},
				"radius": 164.0,
				"biome_id": "westwood",
				"gameplay_tags": ["water_source", "vegetation_bonus"]
			}]
		}

	func get_resource_save_data() -> Array:
		return []

	func get_varnak_save_data() -> Array:
		return []

	func get_small_prey_save_data() -> Array:
		return []

	func get_grazer_save_data() -> Array:
		return []

	func restore_landmarks(landmark_data: Array, world_seed: int) -> void:
		restore_landmarks_call_count += 1
		restored_landmarks = landmark_data.duplicate(true)
		restored_world_seed = world_seed

	func restore_resources(_data: Array) -> void:
		pass

	func restore_varnaks(_data: Array) -> void:
		pass

	func restore_small_prey(_data: Array) -> void:
		pass

	func restore_grazers(_data: Array) -> void:
		pass


class TestDayNightSystem:
	extends Node

	func get_save_data() -> Dictionary:
		return {"day": 3, "time_of_day": 0.45}

	func restore_from_data(_data: Dictionary) -> void:
		pass


class TestEvolutionDirector:
	extends Node

	func get_save_data() -> Dictionary:
		return {"generation": 4}

	func restore_from_data(_data: Dictionary) -> void:
		pass


class TestEcosystemDirector:
	extends Node

	func get_save_data() -> Dictionary:
		return {"biomass": 72.0}

	func load_save_data(_data: Dictionary) -> void:
		pass


class TestGameSessionNode:
	extends Node

	var last_world_seed := 0
	var last_landmarks: Array = []
	var set_bootstrap_call_count := 0

	func set_bootstrap_world_state(world_seed: int, landmarks: Array) -> void:
		set_bootstrap_call_count += 1
		last_world_seed = world_seed
		last_landmarks = landmarks.duplicate(true)


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_save_system_initializes(failures)
	_test_vector_helpers_round_trip(failures)
	_test_get_player_data_contains_expected_fields(failures)
	_test_collect_save_data_includes_world_layout(failures)
	_test_restore_player_data_restores_player_state(failures)
	_test_restore_save_data_restores_world_layout_and_bootstrap(failures)
	_test_restore_save_data_skips_missing_world_layout(failures)
	_test_get_building_data_contains_expected_fields(failures)
	_test_restore_building_state_restores_building_fields(failures)
	return failures


func _test_save_system_initializes(failures: Array[String]) -> void:
	var save_system := SAVE_SYSTEM_SCRIPT.new()
	TEST_UTILS.expect(save_system != null, failures, "SaveSystem should instantiate")


func _test_vector_helpers_round_trip(failures: Array[String]) -> void:
	var save_system := SAVE_SYSTEM_SCRIPT.new()
	var original := Vector2(42.0, -12.5)
	var data: Dictionary = Dictionary(save_system.call("_vector_to_data", original))
	var restored := save_system.call("_data_to_vector", data) as Vector2
	TEST_UTILS.expect_close(restored.x, original.x, failures, "Vector helper should preserve X")
	TEST_UTILS.expect_close(restored.y, original.y, failures, "Vector helper should preserve Y")


func _test_get_player_data_contains_expected_fields(failures: Array[String]) -> void:
	var save_system := SAVE_SYSTEM_SCRIPT.new()
	var player := _make_player()
	player.stats.health = 88.0
	player.stats.hunger = 64.0
	player.stats.stamina = 55.0
	player.stats.rest = 72.0
	player.inventory.add_item("wood", 2)
	player.has_spear = true
	player.torch_active = true
	player.torch_remaining_seconds = 12.5
	var data: Dictionary = Dictionary(save_system.call("_get_player_data", player))
	TEST_UTILS.expect(data.has("position"), failures, "Player save data should contain position")
	TEST_UTILS.expect(data.has("stats"), failures, "Player save data should contain stats")
	TEST_UTILS.expect(data.has("inventory"), failures, "Player save data should contain inventory")
	TEST_UTILS.expect(data.get("has_spear", false) == true, failures, "Player save data should contain spear state")
	TEST_UTILS.expect(data.get("torch_active", false) == true, failures, "Player save data should contain torch state")
	var stats: Dictionary = Dictionary(data.get("stats", {}))
	var inventory: Dictionary = Dictionary(data.get("inventory", {}))
	TEST_UTILS.expect_close(float(stats.get("health", 0.0)), 88.0, failures, "Player save data should capture health")
	TEST_UTILS.expect_close(float(stats.get("hunger", 0.0)), 64.0, failures, "Player save data should capture hunger")
	TEST_UTILS.expect_close(float(stats.get("stamina", 0.0)), 55.0, failures, "Player save data should capture stamina")
	TEST_UTILS.expect_close(float(stats.get("rest", 0.0)), 72.0, failures, "Player save data should capture rest")
	TEST_UTILS.expect_equal(int(inventory.get("wood", 0)), 2, failures, "Player save data should capture inventory items")


func _test_collect_save_data_includes_world_layout(failures: Array[String]) -> void:
	var context := _setup_save_scene()
	var save_system: Node = context.get("save_system")
	var data: Dictionary = save_system.call("_collect_save_data")
	var world_data: Dictionary = Dictionary(data.get("world", {}))
	TEST_UTILS.expect_equal(int(world_data.get("world_seed", 0)), 9182, failures, "Save data should include the generated world seed")
	var landmarks: Array = Array(world_data.get("landmarks", []))
	TEST_UTILS.expect_equal(landmarks.size(), 1, failures, "Save data should include the generated landmark layout")
	if landmarks.size() == 1:
		var landmark := Dictionary(landmarks[0])
		TEST_UTILS.expect_equal(str(landmark.get("id", "")), "save_pond", failures, "Save data should preserve landmark ids in the world layout")
		TEST_UTILS.expect_equal(str(landmark.get("type", "")), "pond", failures, "Save data should preserve landmark types in the world layout")
		TEST_UTILS.expect_equal(str(landmark.get("biome_id", "")), "westwood", failures, "Save data should preserve landmark biome ids in the world layout")
	_cleanup_save_scene(context)


func _test_restore_player_data_restores_player_state(failures: Array[String]) -> void:
	var save_system := SAVE_SYSTEM_SCRIPT.new()
	var player := _make_player()
	save_system.call("_restore_player_data", player, {
		"position": {"x": 42.0, "y": -12.0},
		"stats": {"health": 75.0, "hunger": 60.0, "stamina": 70.0, "rest": 80.0},
		"inventory": {"wood": 3},
		"has_spear": true,
		"has_bow": true,
		"torch_active": true,
		"torch_remaining_seconds": 12.5
	})
	TEST_UTILS.expect_close(player.global_position.x, 42.0, failures, "Player X should be restored")
	TEST_UTILS.expect_close(player.global_position.y, -12.0, failures, "Player Y should be restored")
	TEST_UTILS.expect_close(player.stats.health, 75.0, failures, "Player health should be restored")
	TEST_UTILS.expect_close(player.stats.hunger, 60.0, failures, "Player hunger should be restored")
	TEST_UTILS.expect_close(player.stats.stamina, 70.0, failures, "Player stamina should be restored")
	TEST_UTILS.expect_close(player.stats.rest, 80.0, failures, "Player rest should be restored")
	TEST_UTILS.expect_equal(player.inventory.get_amount("wood"), 3, failures, "Player inventory should be restored")
	TEST_UTILS.expect(player.torch_active, failures, "Player torch state should be restored")
	TEST_UTILS.expect(player.has_spear == true, failures, "Player spear state should be restored")
	TEST_UTILS.expect(player.has_bow == true, failures, "Player bow state should be restored")
	TEST_UTILS.expect_close(player.torch_remaining_seconds, 12.5, failures, "Player torch duration should be restored")


func _test_restore_save_data_restores_world_layout_and_bootstrap(failures: Array[String]) -> void:
	var context := _setup_save_scene()
	var save_system: Node = context.get("save_system")
	var world: TestWorldSaveData = context.get("world")
	var game_session: Node = context.get("game_session")
	save_system.call("_restore_save_data", {
		"world": {
			"world_seed": 4444,
			"landmarks": [{
				"id": "load_hill",
				"type": "hill",
				"position": {"x": -55.0, "y": 230.0},
				"radius": 210.0,
				"biome_id": "stoneback_ridge",
				"gameplay_tags": ["high_ground"]
			}]
		},
		"player": {},
		"resources": [],
		"varnaks": [],
		"small_prey": [],
		"grazers": [],
		"buildings": [],
		"day_night": {},
		"evolution": {},
		"ecosystem": {}
	})
	TEST_UTILS.expect_equal(world.restore_landmarks_call_count, 1, failures, "Load should restore the runtime landmark layout on the world")
	TEST_UTILS.expect_equal(world.restored_world_seed, 4444, failures, "Load should pass the saved world seed back to the world")
	TEST_UTILS.expect_equal(world.restored_landmarks.size(), 1, failures, "Load should pass the saved landmark layout back to the world")
	if world.restored_landmarks.size() == 1:
		var landmark := Dictionary(world.restored_landmarks[0])
		TEST_UTILS.expect_equal(str(landmark.get("id", "")), "load_hill", failures, "Load should preserve landmark ids when restoring the world")
	if game_session is TestGameSessionNode:
		var mock_game_session := game_session as TestGameSessionNode
		TEST_UTILS.expect_equal(mock_game_session.set_bootstrap_call_count, 1, failures, "Load should refresh the bootstrap world state for follow-up scene use")
		TEST_UTILS.expect_equal(mock_game_session.last_world_seed, 4444, failures, "Load should refresh the bootstrap seed with the restored world seed")
		TEST_UTILS.expect_equal(mock_game_session.last_landmarks.size(), 1, failures, "Load should refresh the bootstrap landmark layout")
	else:
		TEST_UTILS.expect(game_session.has_method("get_bootstrap_world_seed"), failures, "GameSession should expose bootstrap world seed after load")
		TEST_UTILS.expect_equal(int(game_session.call("get_bootstrap_world_seed")), 4444, failures, "Load should refresh the bootstrap seed with the restored world seed")
		if game_session.has_method("get_bootstrap_landmarks"):
			var bootstrap_landmarks: Array = Array(game_session.call("get_bootstrap_landmarks"))
			TEST_UTILS.expect_equal(bootstrap_landmarks.size(), 1, failures, "Load should refresh the bootstrap landmark layout")
	_cleanup_save_scene(context)


func _test_restore_save_data_skips_missing_world_layout(failures: Array[String]) -> void:
	var context := _setup_save_scene()
	var save_system: Node = context.get("save_system")
	var world: TestWorldSaveData = context.get("world")
	var game_session: Node = context.get("game_session")
	save_system.call("_restore_save_data", {
		"version": 1,
		"player": {},
		"resources": [],
		"varnaks": [],
		"buildings": [],
		"day_night": {},
		"evolution": {},
		"ecosystem": {}
	})
	TEST_UTILS.expect_equal(world.restore_landmarks_call_count, 0, failures, "Older saves without world data should not try to restore landmark layout")
	if game_session is TestGameSessionNode:
		var mock_game_session := game_session as TestGameSessionNode
		TEST_UTILS.expect_equal(mock_game_session.set_bootstrap_call_count, 0, failures, "Older saves without world data should not overwrite bootstrap world state")
	elif game_session.has_method("get_bootstrap_world_seed"):
		TEST_UTILS.expect_equal(int(game_session.call("get_bootstrap_world_seed")), int(context.get("original_bootstrap_seed", 0)), failures, "Older saves without world data should leave bootstrap world state untouched")
	_cleanup_save_scene(context)


func _test_get_building_data_contains_expected_fields(failures: Array[String]) -> void:
	var save_system := SAVE_SYSTEM_SCRIPT.new()
	var campfire := TestCampfire.new()
	campfire.global_position = Vector2(10.0, 20.0)
	var trap := TestTrap.new()
	trap.global_position = Vector2(30.0, 40.0)
	var wall := TestWall.new()
	wall.global_position = Vector2(50.0, 60.0)
	var campfire_data: Dictionary = Dictionary(save_system.call("_get_building_data", "campfire", campfire))
	var trap_data: Dictionary = Dictionary(save_system.call("_get_building_data", "trap", trap))
	var wall_data: Dictionary = Dictionary(save_system.call("_get_building_data", "wall", wall))
	TEST_UTILS.expect_equal(campfire_data.get("kind", ""), "campfire", failures, "Campfire save data should contain the kind")
	TEST_UTILS.expect_equal(trap_data.get("kind", ""), "trap", failures, "Trap save data should contain the kind")
	TEST_UTILS.expect_equal(wall_data.get("kind", ""), "wall", failures, "Wall save data should contain the kind")
	TEST_UTILS.expect(campfire_data.has("position"), failures, "Campfire save data should contain position")


func _test_restore_building_state_restores_building_fields(failures: Array[String]) -> void:
	var save_system := SAVE_SYSTEM_SCRIPT.new()
	var campfire := TestCampfire.new()
	var trap := TestTrap.new()
	var wall := TestWall.new()
	save_system.call("_restore_building_state", "campfire", campfire, {"active": false, "fear_radius": 260.0})
	save_system.call("_restore_building_state", "trap", trap, {"armed": false, "damage": 24.0})
	save_system.call("_restore_building_state", "wall", wall, {"health": 65.0})
	TEST_UTILS.expect(not campfire.active, failures, "Campfire active state should be restored")
	TEST_UTILS.expect_close(campfire.fear_radius, 260.0, failures, "Campfire fear radius should be restored")
	TEST_UTILS.expect(not trap.armed, failures, "Trap armed state should be restored")
	TEST_UTILS.expect_close(trap.damage, 24.0, failures, "Trap damage should be restored")
	TEST_UTILS.expect_close(wall.health, 65.0, failures, "Wall health should be restored")


func _make_player() -> TestPlayer:
	return TestPlayer.new()


func _setup_save_scene() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := tree.current_scene
	var root := tree.root
	for child_name in ["Player", "World", "DayNightSystem", "EvolutionDirector", "EcosystemDirector", "TestSaveSystem"]:
		_clear_scene_child(scene, str(child_name))
	var save_system := SAVE_SYSTEM_SCRIPT.new()
	var player := _make_player()
	var world := TestWorldSaveData.new()
	var day_night_system := TestDayNightSystem.new()
	var evolution_director := TestEvolutionDirector.new()
	var ecosystem_director := TestEcosystemDirector.new()
	var game_session: Node = root.get_node_or_null("GameSession")
	var created_game_session := false
	var original_bootstrap_seed := 0
	var original_bootstrap_landmarks: Array = []
	if game_session == null:
		game_session = TestGameSessionNode.new()
		game_session.name = "GameSession"
		root.add_child(game_session)
		created_game_session = true
	elif game_session.has_method("get_bootstrap_world_seed"):
		original_bootstrap_seed = int(game_session.call("get_bootstrap_world_seed"))
		if game_session.has_method("get_bootstrap_landmarks"):
			original_bootstrap_landmarks = Array(game_session.call("get_bootstrap_landmarks")).duplicate(true)
	save_system.name = "TestSaveSystem"
	player.name = "Player"
	world.name = "World"
	day_night_system.name = "DayNightSystem"
	evolution_director.name = "EvolutionDirector"
	ecosystem_director.name = "EcosystemDirector"
	scene.add_child(save_system)
	scene.add_child(player)
	scene.add_child(world)
	scene.add_child(day_night_system)
	scene.add_child(evolution_director)
	scene.add_child(ecosystem_director)
	return {
		"scene": scene,
		"save_system": save_system,
		"player": player,
		"world": world,
		"day_night_system": day_night_system,
		"evolution_director": evolution_director,
		"ecosystem_director": ecosystem_director,
		"game_session": game_session,
		"created_game_session": created_game_session,
		"original_bootstrap_seed": original_bootstrap_seed,
		"original_bootstrap_landmarks": original_bootstrap_landmarks
	}


func _cleanup_save_scene(context: Dictionary) -> void:
	for key in ["save_system", "player", "world", "day_night_system", "evolution_director", "ecosystem_director"]:
		var node: Variant = context.get(key)
		if node is Node and is_instance_valid(node):
			var node_ref := node as Node
			if node_ref.get_parent():
				node_ref.get_parent().remove_child(node_ref)
			node_ref.free()
	var game_session: Variant = context.get("game_session")
	if game_session is Node and is_instance_valid(game_session):
		var game_session_node := game_session as Node
		if bool(context.get("created_game_session", false)):
			if game_session_node.get_parent():
				game_session_node.get_parent().remove_child(game_session_node)
			game_session_node.free()
		elif game_session_node.has_method("set_bootstrap_world_state"):
			game_session_node.call(
				"set_bootstrap_world_state",
				int(context.get("original_bootstrap_seed", 0)),
				Array(context.get("original_bootstrap_landmarks", [])).duplicate(true)
			)


func _clear_scene_child(scene: Node, child_name: String) -> void:
	var existing := scene.get_node_or_null(child_name)
	if existing and is_instance_valid(existing):
		scene.remove_child(existing)
		existing.free()
