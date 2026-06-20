extends RefCounted

const SNAPSHOT_SERVICE_SCRIPT := preload("res://scripts/systems/world_snapshot_service.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


class MockStats:
	extends RefCounted
	var health := 91
	var hunger := 62
	var stamina := 48
	var rest := 77
	var campfire_regen_active := true
	var campfire_regen_distance := 88.0

	func get_condition_text() -> String:
		return "steady"


class MockInventory:
	extends RefCounted

	func get_amount(item_id: String) -> int:
		match item_id:
			"wood":
				return 4
			"stone":
				return 3
			"fiber":
				return 2
			"meat":
				return 1
			"hide":
				return 5
			"bone":
				return 6
			"torch":
				return 2
		return 0


class MockPlayer:
	extends Node2D
	var stats := MockStats.new()
	var inventory := MockInventory.new()
	var has_spear := true
	var has_bow := false
	var torch_active := true

	func get_interaction_prompt() -> String:
		return "E: interact"

	func is_torch_active() -> bool:
		return torch_active

	func get_torch_remaining_seconds() -> float:
		return 17.2


class MockEvolutionDirector:
	extends Node

	func get_profile() -> Dictionary:
		return {
			"generation": 4,
			"aggression": 0.45,
			"fire_fear": 0.80,
			"trap_awareness": 0.30,
			"pack_coordination": 0.22
		}


class MockDayNightSystem:
	extends Node
	var night_amount := 0.35

	func get_day() -> int:
		return 3

	func get_clock_time() -> String:
		return "13:48"

	func get_time_label() -> String:
		return "Day"

	func get_phase_label() -> String:
		return "Afternoon"


class MockEcosystemDirector:
	extends Node

	func get_biome_states() -> Dictionary:
		return {
			"westwood": {
				"name": "Westwood",
				"status": "stable",
				"small_prey_population": 4.0,
				"grazer_population": 3.0,
				"varnak_population": 1.0
			},
			"redfang_wilds": {
				"name": "Redfang Wilds",
				"status": "stressed",
				"small_prey_population": 1.0,
				"grazer_population": 0.0,
				"varnak_population": 2.0
			}
		}


class MockResource:
	extends Node2D
	var resource_kind := ""
	var item_name := ""
	var player_harvestable := true


class MockCreature:
	extends Node2D


class MockAiCreature:
	extends Node2D

	var ai_state := "wandering"

	func get_debug_ai_state() -> String:
		return ai_state


class MockWorld:
	extends Node
	var resources: Array = []
	var varnaks: Array = []
	var small_prey: Array = []
	var grazers: Array = []
	var resource_reads := 0
	var creature_reads := 0
	var world_rect_reads := 0
	var biome_zone_reads := 0
	var landmark_reads := 0

	func get_world_rect() -> Rect2:
		world_rect_reads += 1
		return Rect2(Vector2(-1000.0, -800.0), Vector2(2000.0, 1600.0))

	func get_biome_zones() -> Array[Dictionary]:
		biome_zone_reads += 1
		return [{
			"name": "Westwood",
			"points": PackedVector2Array([
				Vector2(-1000.0, -800.0),
				Vector2(1000.0, -800.0),
				Vector2(1000.0, 800.0),
				Vector2(-1000.0, 800.0)
			]),
			"color": Color(0.2, 0.4, 0.2)
		}]

	func get_landmarks() -> Array[Dictionary]:
		landmark_reads += 1
		return [{
			"id": "pond_a",
			"type": "pond",
			"position": Vector2(120.0, -60.0),
			"radius": 90.0
		}]

	func get_landmark_counts() -> Dictionary:
		return {"generated": 1, "hill": 0, "pond": 1}

	func get_world_seed() -> int:
		return 2468

	func get_creatures_out_of_bounds_count() -> int:
		return 2

	func get_current_biome_texture_id(_position: Vector2) -> String:
		return "westwood_sample"

	func get_nearest_landmark_data(_position: Vector2) -> Dictionary:
		return {"id": "pond_a", "type": "pond", "distance_to_position": 42.0}

	func get_biome_texture_cache_status() -> Dictionary:
		return {"sample_image_cache_count": 1, "accent_cache_count": 2, "pending_biomes": 0, "build_running": false}

	func get_varnak_population_status() -> Dictionary:
		return {"day": 4, "target": 5, "live": varnaks.size(), "max": 12, "spawn_chance": 0.76}

	func get_varnak_spawn_sync_debug() -> Dictionary:
		return {
			"retry_timer": 0.0,
			"warning_printed": false,
			"attempt_count": 1,
			"failed_count": 0,
			"skipped_by_cooldown_count": 0,
			"last_requested": 2,
			"last_failed": 0,
			"last_success": 2
		}

	func get_visibility_culling_debug() -> Dictionary:
		return {
			"enabled": true,
			"interval_seconds": 0.35,
			"margin": 384.0,
			"visible_resources": 2,
			"hidden_resources": 5,
			"visible_creatures": 3,
			"hidden_creatures": 4
		}

	func is_landmark_debug_overlay_enabled() -> bool:
		return true

	func are_biome_textures_enabled() -> bool:
		return true

	func are_biome_terrain_accents_enabled() -> bool:
		return false

	func is_low_end_rendering_enabled() -> bool:
		return true

	func get_registered_resources() -> Array:
		resource_reads += 1
		return resources

	func get_registered_creatures_by_type(creature_type: String) -> Array:
		creature_reads += 1
		match creature_type:
			"varnak":
				return varnaks
			"small_prey":
				return small_prey
			"grazer":
				return grazers
		return []

	func get_cached_group_nodes(group_name: String) -> Array:
		match group_name:
			"trees":
				return resources.filter(func(resource): return resource.resource_kind == "conifer_tree")
			"bushes":
				return resources.filter(func(resource): return resource.resource_kind == "bush")
			"grass":
				return resources.filter(func(resource): return resource.resource_kind == "grass_patch")
			"rocks":
				return resources.filter(func(resource): return resource.resource_kind == "rock")
			"pond_vegetation":
				return []
			"campfires":
				return [Node.new()]
			"traps":
				return [Node.new(), Node.new()]
			"walls":
				return []
			"storage_boxes":
				return []
			"tents":
				return []
		return []


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_snapshot_service_builds_ui_snapshot_and_filters_markers(failures)
	_test_snapshot_service_refresh_hud_is_lightweight(failures)
	_test_snapshot_service_falls_back_to_biome_zones_for_current_biome_name(failures)
	return failures


func _test_snapshot_service_builds_ui_snapshot_and_filters_markers(failures: Array[String]) -> void:
	var service = SNAPSHOT_SERVICE_SCRIPT.new()
	var player := MockPlayer.new()
	player.global_position = Vector2(50.0, 20.0)
	var world := MockWorld.new()
	world.resources = [
		_make_resource("conifer_tree", "wood", Vector2(10.0, 10.0), true),
		_make_resource("berry_bush", "berries", Vector2(20.0, 20.0), true),
		_make_resource("rock", "stone", Vector2(30.0, 30.0), true),
		_make_resource("grass_patch", "grass", Vector2(40.0, 40.0), true),
		_make_resource("bush", "fiber", Vector2(50.0, 50.0), false)
	]
	world.varnaks = [_make_creature(Vector2(120.0, 0.0))]
	world.small_prey = [_make_ai_creature(Vector2(-90.0, 20.0), "wandering"), _make_ai_creature(Vector2(-60.0, 10.0), "hungry_wander")]
	world.grazers = [_make_ai_creature(Vector2(70.0, -40.0), "eating_plants")]
	service.bind(player, MockEvolutionDirector.new(), MockDayNightSystem.new(), MockEcosystemDirector.new(), world)
	var snapshot: Dictionary = service.refresh(true)
	var player_snapshot := Dictionary(snapshot.get("player", {}))
	var world_snapshot := Dictionary(snapshot.get("world", {}))
	var markers := Dictionary(snapshot.get("markers", {}))
	var ecosystem_snapshot := Dictionary(snapshot.get("ecosystem", {}))
	var debug_snapshot := Dictionary(snapshot.get("debug", {}))
	var varnak_sync := Dictionary(world_snapshot.get("varnak_spawn_sync", {}))
	var visibility_culling := Dictionary(world_snapshot.get("visibility_culling", {}))
	var ai_state_counts := Dictionary(world_snapshot.get("creature_ai_state_counts", {}))
	TEST_UTILS.expect_equal(int(player_snapshot.get("health", 0)), 91, failures, "Snapshot service should capture player health")
	TEST_UTILS.expect_equal(str(player_snapshot.get("condition_text", "")), "steady", failures, "Snapshot service should capture player condition text")
	TEST_UTILS.expect_equal(int(Dictionary(player_snapshot.get("inventory", {})).get("torch", 0)), 2, failures, "Snapshot service should capture inventory amounts")
	TEST_UTILS.expect_equal(str(world_snapshot.get("current_biome_name", "")), "Westwood", failures, "Snapshot service should resolve the current biome name")
	TEST_UTILS.expect_equal(int(Dictionary(world_snapshot.get("building_counts", {})).get("traps", 0)), 2, failures, "Snapshot service should expose building counts for debug/UI")
	var varnak_population := Dictionary(world_snapshot.get("varnak_population", {}))
	TEST_UTILS.expect_equal(int(varnak_population.get("target", 0)), 5, failures, "Snapshot service should expose the current Varnak population target")
	TEST_UTILS.expect_equal(int(varnak_population.get("max", 0)), 12, failures, "Snapshot service should expose the Varnak population hard limit")
	TEST_UTILS.expect_equal(Array(markers.get("resources", [])).size(), 2, failures, "Snapshot service should expose only minimap/map resource markers that stay visible to the player")
	TEST_UTILS.expect_equal(Array(markers.get("varnaks", [])).size(), 1, failures, "Snapshot service should expose varnak markers")
	TEST_UTILS.expect_equal(int(Dictionary(ecosystem_snapshot.get("population_totals", {})).get("small_prey_population", 0)), 5, failures, "Snapshot service should aggregate ecosystem population totals")
	TEST_UTILS.expect_equal(int(Dictionary(ai_state_counts.get("small_prey", {})).get("wandering", 0)), 1, failures, "Snapshot service should aggregate small prey wandering states")
	TEST_UTILS.expect_equal(int(Dictionary(ai_state_counts.get("small_prey", {})).get("hungry", 0)), 1, failures, "Snapshot service should aggregate small prey hungry states")
	TEST_UTILS.expect_equal(int(Dictionary(ai_state_counts.get("grazer", {})).get("eating", 0)), 1, failures, "Snapshot service should aggregate grazer eating states")
	TEST_UTILS.expect_equal(int(varnak_sync.get("attempt_count", 0)), 1, failures, "Snapshot service should expose Varnak spawn sync diagnostics")
	TEST_UTILS.expect_equal(int(visibility_culling.get("visible_resources", 0)), 2, failures, "Snapshot service should expose visible resource counts")
	TEST_UTILS.expect_equal(int(visibility_culling.get("hidden_resources", 0)), 5, failures, "Snapshot service should expose hidden resource counts")
	TEST_UTILS.expect_equal(int(visibility_culling.get("visible_creatures", 0)), 3, failures, "Snapshot service should expose visible creature counts")
	TEST_UTILS.expect_equal(int(visibility_culling.get("hidden_creatures", 0)), 4, failures, "Snapshot service should expose hidden creature counts")
	TEST_UTILS.expect(str(ecosystem_snapshot.get("warnings_text", "")).contains("Redfang Wilds:stressed"), failures, "Snapshot service should expose ecosystem warnings text")
	TEST_UTILS.expect_equal(int(debug_snapshot.get("live_varnaks", 0)), 1, failures, "Snapshot service should expose debug summary creature counts")
	TEST_UTILS.expect_equal(bool(world_snapshot.get("biome_terrain_accents_enabled", true)), false, failures, "Snapshot service should expose the biome terrain accent flag")
	TEST_UTILS.expect_equal(bool(world_snapshot.get("low_end_rendering", false)), true, failures, "Snapshot service should expose the low-end rendering flag")
	TEST_UTILS.expect_equal(world.resource_reads, 1, failures, "Snapshot service should build resource markers only once per refresh")
	TEST_UTILS.expect_equal(world.creature_reads, 3, failures, "Snapshot service should build each creature marker list only once per refresh")


func _test_snapshot_service_refresh_hud_is_lightweight(failures: Array[String]) -> void:
	var service = SNAPSHOT_SERVICE_SCRIPT.new()
	var player := MockPlayer.new()
	player.global_position = Vector2(25.0, -10.0)
	var world := MockWorld.new()
	service.bind(player, MockEvolutionDirector.new(), MockDayNightSystem.new(), MockEcosystemDirector.new(), world)
	var full_snapshot: Dictionary = service.refresh(true)
	var world_reads_before := world.world_rect_reads + world.biome_zone_reads + world.landmark_reads
	var hud_snapshot: Dictionary = service.refresh_hud()
	var world_reads_after := world.world_rect_reads + world.biome_zone_reads + world.landmark_reads
	TEST_UTILS.expect(hud_snapshot.has("player"), failures, "HUD snapshot should include player data")
	TEST_UTILS.expect(hud_snapshot.has("time"), failures, "HUD snapshot should include time data")
	TEST_UTILS.expect(not hud_snapshot.has("world"), failures, "HUD snapshot should not rebuild the full world snapshot")
	TEST_UTILS.expect(not hud_snapshot.has("markers"), failures, "HUD snapshot should not rebuild marker data")
	TEST_UTILS.expect_equal(world_reads_before, world_reads_after, failures, "HUD snapshot refresh should not reread world geometry or landmarks")
	TEST_UTILS.expect_equal(str(Dictionary(full_snapshot.get("time", {})).get("clock_time", "")), "13:48", failures, "Full snapshot should still be available for world data consumers")


func _test_snapshot_service_falls_back_to_biome_zones_for_current_biome_name(failures: Array[String]) -> void:
	var service = SNAPSHOT_SERVICE_SCRIPT.new()
	var player := MockPlayer.new()
	player.global_position = Vector2(-320.0, 0.0)
	var world := MockWorld.new()
	service.bind(player, MockEvolutionDirector.new(), MockDayNightSystem.new(), MockEcosystemDirector.new(), world)
	var world_snapshot: Dictionary = Dictionary(service.refresh(true).get("world", {}))
	TEST_UTILS.expect_equal(str(world_snapshot.get("current_biome_name", "")), "Westwood", failures, "Snapshot service should fall back to biome zone names when world biome lookup is unavailable")


func _make_resource(kind: String, item_name: String, position: Vector2, harvestable: bool) -> MockResource:
	var resource := MockResource.new()
	resource.resource_kind = kind
	resource.item_name = item_name
	resource.player_harvestable = harvestable
	resource.global_position = position
	return resource


func _make_creature(position: Vector2) -> MockCreature:
	var creature := MockCreature.new()
	creature.global_position = position
	return creature


func _make_ai_creature(position: Vector2, ai_state: String) -> MockAiCreature:
	var creature := MockAiCreature.new()
	creature.global_position = position
	creature.ai_state = ai_state
	return creature
