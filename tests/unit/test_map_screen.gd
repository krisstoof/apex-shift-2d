extends RefCounted

const MAP_SCREEN_SCRIPT := preload("res://scripts/ui/map_screen.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


class CountingMapScreen:
	extends MAP_SCREEN_SCRIPT

	var ensure_calls := 0

	func _ensure_biome_texture() -> void:
		ensure_calls += 1


class StableCacheMapScreen:
	extends MAP_SCREEN_SCRIPT

	var static_dirty_calls := 0
	var dynamic_redraw_calls := 0

	func _refresh_landmarks_from_world() -> bool:
		return false

	func _update_marker_cache() -> bool:
		return false

	func mark_map_cache_dirty() -> void:
		pass

	func _request_map_redraw(force := false) -> bool:
		if force:
			return true
		return false


class MockStats:
	extends RefCounted
	var health := 86
	var hunger := 72
	var stamina := 54
	var rest := 43

	func get_condition_text() -> String:
		return "steady"


class MockInventory:
	extends RefCounted

	func get_amount(item_id: String) -> int:
		match item_id:
			"wood":
				return 3
			"stone":
				return 4
			"fiber":
				return 5
			"meat":
				return 6
			"hide":
				return 7
			"bone":
				return 8
		return 0


class MockPlayer:
	extends Node2D
	var stats := MockStats.new()
	var inventory := MockInventory.new()


class MockEvolutionDirector:
	extends Node

	func get_profile() -> Dictionary:
		return {
			"generation": 3,
			"aggression": 0.45,
			"fire_fear": 0.85,
			"trap_awareness": 0.10,
			"pack_coordination": 0.20
		}


class MockDayNightSystem:
	extends Node

	func get_day() -> int:
		return 2

	func get_clock_time() -> String:
		return "10:31"

	func get_time_label() -> String:
		return "Day"


class MockResource:
	extends Node2D
	var resource_kind := "berry_bush"
	var item_name := "berries"
	var player_harvestable := true


class MockVarnak:
	extends Node2D


class MockWorld:
	extends Node
	var registered_resources: Array = []
	var registered_varnaks: Array = []
	var surface_texture := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	var surface_texture_key := "shared-surface"

	func get_registered_resources() -> Array:
		return registered_resources

	func get_registered_creatures_by_type(creature_type: String) -> Array:
		if creature_type == "varnak":
			return registered_varnaks
		return []

	func get_landmarks() -> Array[Dictionary]:
		return []

	func get_surface_texture() -> ImageTexture:
		return surface_texture

	func get_surface_texture_key() -> String:
		return surface_texture_key


class MockSnapshotService:
	extends RefCounted
	var snapshot := {}

	func get_snapshot() -> Dictionary:
		return snapshot

	func refresh(_force := false) -> Dictionary:
		return snapshot


class ShapeMapNoUnderlayStub:
	extends RefCounted

	var sample_grid_size_calls := 0
	var sample_grid_cell_world_rect_calls := 0

	func has_renderable_polygons() -> bool:
		return true

	func get_polygons_by_layer() -> Dictionary:
		return {
			"biome:test|terrain:land": [
				{
					"biome_id": "test_biome",
					"terrain_id": "land",
					"points": PackedVector2Array([Vector2.ZERO, Vector2(64.0, 0.0), Vector2(0.0, 64.0)])
				}
			]
		}

	func get_sample_grid_size() -> Vector2i:
		sample_grid_size_calls += 1
		return Vector2i(4, 4)

	func get_sample_grid_cell_world_rect(_x: int, _y: int) -> Rect2:
		sample_grid_cell_world_rect_calls += 1
		return Rect2(Vector2.ZERO, Vector2(16.0, 16.0))

	func get_sample_grid_cell(_x: int, _y: int) -> Dictionary:
		return {"biome_id": "test_biome", "terrain_id": "land"}


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_info_lines_fall_back_when_player_is_missing(failures)
	_test_info_lines_use_player_stats_and_inventory(failures)
	_test_map_redraw_state_does_not_retrigger_when_state_is_unchanged(failures)
	_test_map_redraw_state_reacts_to_player_position_changes(failures)
	_test_landmark_signature_changes_only_when_landmarks_change(failures)
	_test_map_redraw_state_reacts_to_resource_signature_changes(failures)
	_test_map_screen_skips_updates_while_hidden(failures)
	_test_map_screen_static_cache_stays_quiet_when_signatures_do_not_change(failures)
	_test_map_screen_reads_registry_resources_and_varnaks(failures)
	_test_map_screen_builds_texture_outside_draw_path(failures)
	_test_map_screen_shape_map_skips_sample_grid_underlay_when_polygons_exist(failures)
	_test_map_screen_reuses_world_surface_texture_when_available(failures)
	return failures


func _test_info_lines_fall_back_when_player_is_missing(failures: Array[String]) -> void:
	var map_screen: Object = _make_map_screen()
	var lines: Array[String] = map_screen.call("_build_info_lines")
	TEST_UTILS.expect(lines.has("Health:   0"), failures, "Map screen should show zero health when the player reference is missing")
	TEST_UTILS.expect(lines.has("Hunger:   0"), failures, "Map screen should show zero hunger when the player reference is missing")
	TEST_UTILS.expect(lines.has("Stamina:   0"), failures, "Map screen should show zero stamina when the player reference is missing")
	TEST_UTILS.expect(lines.has("Rest:   0  unknown"), failures, "Map screen should show a fallback rest condition when the player reference is missing")
	TEST_UTILS.expect(lines.has("Wood 0  Stone 0  Fiber 0"), failures, "Map screen should show zero inventory counts when the player reference is missing")
	TEST_UTILS.expect(lines.has("Meat 0  Hide 0  Bone 0"), failures, "Map screen should show zero loot counts when the player reference is missing")
	map_screen.free()


func _test_info_lines_use_player_stats_and_inventory(failures: Array[String]) -> void:
	var map_screen: Object = _make_map_screen()
	var player := MockPlayer.new()
	map_screen.set("player", player)
	var lines: Array[String] = map_screen.call("_build_info_lines")
	TEST_UTILS.expect(lines.has("Health:  86"), failures, "Map screen should expose the player's health when stats are available")
	TEST_UTILS.expect(lines.has("Hunger:  72"), failures, "Map screen should expose the player's hunger when stats are available")
	TEST_UTILS.expect(lines.has("Stamina:  54"), failures, "Map screen should expose the player's stamina when stats are available")
	TEST_UTILS.expect(lines.has("Rest:  43  steady"), failures, "Map screen should expose the player's rest condition when stats are available")
	TEST_UTILS.expect(lines.has("Wood 3  Stone 4  Fiber 5"), failures, "Map screen should expose inventory resource counts when inventory is available")
	TEST_UTILS.expect(lines.has("Meat 6  Hide 7  Bone 8"), failures, "Map screen should expose inventory loot counts when inventory is available")
	player.free()
	map_screen.free()


func _test_map_redraw_state_does_not_retrigger_when_state_is_unchanged(failures: Array[String]) -> void:
	var map_screen: Object = _make_bound_map_screen()
	var first_refresh: bool = map_screen.call("_request_map_redraw", true)
	var second_refresh: bool = map_screen.call("_request_map_redraw")
	TEST_UTILS.expect(first_refresh, failures, "Map screen should request an initial redraw for the first visible state snapshot")
	TEST_UTILS.expect(not second_refresh, failures, "Map screen should not request another redraw when the visible state key is unchanged")
	var player: Node2D = map_screen.get("player")
	player.free()
	map_screen.free()


func _test_map_redraw_state_reacts_to_player_position_changes(failures: Array[String]) -> void:
	var map_screen: Object = _make_bound_map_screen()
	var player: Node2D = map_screen.get("player")
	map_screen.call("_request_map_redraw", true)
	player.global_position = Vector2(180.0, -64.0)
	var changed: bool = map_screen.call("_request_map_redraw")
	TEST_UTILS.expect(changed, failures, "Map screen should request redraw when the player position shown on the map changes")
	player.free()
	map_screen.free()


func _test_landmark_signature_changes_only_when_landmarks_change(failures: Array[String]) -> void:
	var map_screen: Object = _make_map_screen()
	var landmarks: Array[Dictionary] = [
		{
			"id": "pond_a",
			"type": "pond",
			"position": Vector2(120.0, 80.0),
			"radius": 90.0
		}
	]
	map_screen.set("landmarks", landmarks)
	var first_change: bool = map_screen.call("_update_landmarks_signature")
	var second_change: bool = map_screen.call("_update_landmarks_signature")
	landmarks[0]["radius"] = 120.0
	map_screen.set("landmarks", landmarks)
	var third_change: bool = map_screen.call("_update_landmarks_signature")
	TEST_UTILS.expect(first_change, failures, "Map screen should mark landmark cache as changed when the first signature is built")
	TEST_UTILS.expect(not second_change, failures, "Map screen should keep landmark cache stable when landmarks do not change")
	TEST_UTILS.expect(third_change, failures, "Map screen should notice landmark changes that require a new map redraw")
	map_screen.free()


func _test_map_redraw_state_reacts_to_resource_signature_changes(failures: Array[String]) -> void:
	var map_screen: Object = _make_bound_map_screen()
	map_screen.set("cached_resources_signature", "resource-a")
	map_screen.call("_request_map_redraw", true)
	map_screen.set("cached_resources_signature", "resource-b")
	var changed: bool = map_screen.call("_request_map_redraw")
	TEST_UTILS.expect(changed, failures, "Map screen should request redraw when the cached resource signature changes")
	var player: Node2D = map_screen.get("player")
	player.free()
	map_screen.free()


func _test_map_screen_skips_updates_while_hidden(failures: Array[String]) -> void:
	var map_screen := _make_bound_map_screen()
	var skipped_before := int(map_screen.get("map_screen_skipped_update_hidden_count"))
	map_screen.call("_process", 0.5)
	TEST_UTILS.expect_equal(int(map_screen.get("map_screen_skipped_update_hidden_count")), skipped_before + 1, failures, "Map screen should skip hidden cache work instead of rebuilding while it is not visible")
	TEST_UTILS.expect_equal(int(map_screen.get("map_screen_redraw_count")), 0, failures, "Hidden map screen should not redraw")
	var player: Node2D = map_screen.get("player")
	player.free()
	map_screen.free()


func _test_map_screen_static_cache_stays_quiet_when_signatures_do_not_change(failures: Array[String]) -> void:
	var map_screen := StableCacheMapScreen.new()
	map_screen.set("landmarks", [])
	map_screen.set("biome_zones", [])
	map_screen.set("cached_resources_signature", "")
	map_screen.set("cached_campfires_signature", "")
	map_screen.set("cached_varnaks_signature", "")
	map_screen.set("cached_small_prey_signature", "")
	map_screen.set("cached_grazers_signature", "")
	TEST_UTILS.expect_equal(bool(map_screen.call("_update_landmarks_signature")), false, failures, "An unchanged landmark set should not report a landmark signature change")
	TEST_UTILS.expect_equal(bool(map_screen.call("_update_marker_cache")), false, failures, "An unchanged marker set should not report a marker cache rebuild")
	TEST_UTILS.expect_equal(int(map_screen.get("map_screen_marker_cache_rebuild_count")), 0, failures, "Unchanged markers should not increment the map screen rebuild counter")
	map_screen.free()


func _test_map_screen_reads_registry_resources_and_varnaks(failures: Array[String]) -> void:
	var map_screen: Control = _make_bound_map_screen()
	var snapshot_service := MockSnapshotService.new()
	snapshot_service.snapshot = {
		"markers": {
			"resources": [{"position": Vector2(120.0, -40.0), "item_name": "berries", "resource_kind": "berry_bush", "player_harvestable": true}],
			"varnaks": [{"position": Vector2(260.0, 80.0), "type": "varnak"}]
		},
		"player": {
			"health": 86,
			"hunger": 72,
			"stamina": 54,
			"rest": 43,
			"condition_text": "steady",
			"inventory": {"wood": 3, "stone": 4, "fiber": 5, "meat": 6, "hide": 7, "bone": 8}
		},
		"time": {
			"day": 2,
			"clock_time": "10:31",
			"time_label": "Day"
		},
		"world": {
			"current_biome_name": "Westwood",
			"landmarks": []
		},
		"evolution": {
			"profile": MockEvolutionDirector.new().get_profile(),
			"generation": 3
		},
		"debug": {
			"live_varnaks": 1
		}
	}
	map_screen.set("snapshot_service", snapshot_service)
	var cache_changed: bool = map_screen.call("_update_resources_cache")
	var lines: Array[String] = map_screen.call("_build_info_lines")
	TEST_UTILS.expect(cache_changed, failures, "Map screen should rebuild its resource cache when the snapshot service provides a new resource marker")
	TEST_UTILS.expect_equal(Array(map_screen.get("cached_resources")).size(), 1, failures, "Map screen should cache resource markers from the snapshot service")
	TEST_UTILS.expect(lines.has("Live Varnaks: 1"), failures, "Map screen info panel should count varnaks from the snapshot service instead of direct group scans")
	map_screen.free()


func _test_map_screen_builds_texture_outside_draw_path(failures: Array[String]) -> void:
	var map_screen := _make_map_screen()
	var biome_zones_config: Array[Dictionary] = [{
		"name": "Test Biome",
		"points": PackedVector2Array([
			Vector2(-240.0, -160.0),
			Vector2(240.0, -160.0),
			Vector2(240.0, 160.0),
			Vector2(-240.0, 160.0)
		]),
		"color": Color(0.2, 0.4, 0.2)
	}]
	var landmarks: Array[Dictionary] = []
	map_screen.bind(
		MockPlayer.new(),
		MockEvolutionDirector.new(),
		MockDayNightSystem.new(),
		Rect2(Vector2(-240.0, -160.0), Vector2(480.0, 320.0)),
		biome_zones_config,
		landmarks,
		MockSnapshotService.new()
	)
	TEST_UTILS.expect_equal(map_screen.get("map_screen_texture_build_count"), 1, failures, "Map screen should build its biome texture outside _draw()")
	TEST_UTILS.expect(float(map_screen.get("map_screen_texture_last_build_ms")) >= 0.0, failures, "Map screen should track the last biome texture build time")
	var biome_zones: Array[Dictionary] = map_screen.biome_zones.duplicate(true)
	map_screen.free()

	var draw_spy := CountingMapScreen.new()
	draw_spy.world_rect = Rect2(Vector2(-240.0, -160.0), Vector2(480.0, 320.0))
	draw_spy.set("biome_zones", biome_zones)
	draw_spy.set("biome_blend_texture", ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8)))
	draw_spy.set("biome_blend_colors_key", "test")
	var ensure_calls_before := draw_spy.ensure_calls
	draw_spy.call("_draw_biomes", Rect2(Vector2.ZERO, Vector2(300.0, 180.0)))
	TEST_UTILS.expect_equal(draw_spy.ensure_calls, ensure_calls_before, failures, "Map screen draw path should reuse the cached biome texture instead of rebuilding it")
	draw_spy.free()


func _test_map_screen_shape_map_skips_sample_grid_underlay_when_polygons_exist(failures: Array[String]) -> void:
	var map_screen := _make_map_screen()
	var shape_map := ShapeMapNoUnderlayStub.new()
	map_screen.set("biome_shape_map", shape_map)
	map_screen.set("terrain_cell_map", null)
	map_screen.set("biome_zones", [])
	map_screen.call("_draw_shape_map", Rect2(Vector2.ZERO, Vector2(160.0, 100.0)))
	TEST_UTILS.expect_equal(shape_map.sample_grid_size_calls, 0, failures, "Map screen should not draw the sample grid underlay when renderable polygons already exist")
	TEST_UTILS.expect_equal(shape_map.sample_grid_cell_world_rect_calls, 0, failures, "Map screen should not probe sample grid cells when renderable polygons already exist")
	map_screen.free()


func _test_map_screen_reuses_world_surface_texture_when_available(failures: Array[String]) -> void:
	var map_screen := _make_map_screen()
	var player := MockPlayer.new()
	var fake_world := MockWorld.new()
	map_screen.set("player", player)
	map_screen.set("world", fake_world)
	map_screen.set("biome_zones", [{"name": "Test Biome", "points": PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE]), "color": Color(0.2, 0.4, 0.2)}])
	map_screen.call("_sync_biome_texture")
	TEST_UTILS.expect_equal(map_screen.get("biome_blend_texture"), fake_world.surface_texture, failures, "Map screen should reuse the shared world surface texture when it exists")
	TEST_UTILS.expect_equal(str(map_screen.get("biome_blend_colors_key")), fake_world.surface_texture_key, failures, "Map screen should mirror the shared world surface texture key")
	map_screen.free()
	player.free()
	fake_world.free()


func _make_map_screen() -> Object:
	var map_screen: Control = MAP_SCREEN_SCRIPT.new()
	map_screen.size = Vector2(1280.0, 720.0)
	return map_screen


func _make_bound_map_screen() -> Object:
	var map_screen: Object = _make_map_screen()
	var player := MockPlayer.new()
	player.global_position = Vector2(32.0, 48.0)
	map_screen.set("player", player)
	map_screen.set("evolution_director", MockEvolutionDirector.new())
	map_screen.set("day_night_system", MockDayNightSystem.new())
	map_screen.set("landmarks", [
		{
			"id": "hill_a",
			"type": "hill",
			"position": Vector2(260.0, -120.0),
			"radius": 140.0
		}
	])
	map_screen.call("_update_landmarks_signature")
	return map_screen
