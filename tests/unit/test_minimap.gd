extends RefCounted

const MINIMAP_SCRIPT := preload("res://scripts/ui/minimap.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_minimap_view_rect_follows_player_and_stays_larger_than_camera(failures)
	_test_world_to_map_keeps_player_in_minimap_center(failures)
	_test_world_slice_maps_to_partial_texture_region(failures)
	return failures


func _test_minimap_view_rect_follows_player_and_stays_larger_than_camera(failures: Array[String]) -> void:
	var minimap := _make_minimap()
	var player := Node2D.new()
	player.global_position = Vector2(420.0, -180.0)
	minimap.player = player
	minimap.world_rect = Rect2(Vector2(-2000.0, -1200.0), Vector2(4000.0, 2400.0))
	minimap.camera_world_size_override = Vector2(960.0, 540.0)
	var content_rect := Rect2(Vector2.ZERO, Vector2(220.0, 140.0))
	var view_world_rect: Rect2 = minimap.call("_get_minimap_view_world_rect", content_rect)
	var camera_world_size: Vector2 = minimap.call("_get_player_camera_world_size")
	TEST_UTILS.expect_close(view_world_rect.get_center().x, player.global_position.x, failures, "Minimap view rect should follow the player's X position")
	TEST_UTILS.expect_close(view_world_rect.get_center().y, player.global_position.y, failures, "Minimap view rect should follow the player's Y position")
	TEST_UTILS.expect(view_world_rect.size.x > camera_world_size.x, failures, "Minimap should show a wider world slice than the current camera view")
	TEST_UTILS.expect(view_world_rect.size.y > camera_world_size.y, failures, "Minimap should show a taller world slice than the current camera view")
	minimap.free()
	player.free()


func _test_world_to_map_keeps_player_in_minimap_center(failures: Array[String]) -> void:
	var minimap := _make_minimap()
	var player := Node2D.new()
	player.global_position = Vector2(-640.0, 320.0)
	minimap.player = player
	minimap.world_rect = Rect2(Vector2(-2000.0, -1200.0), Vector2(4000.0, 2400.0))
	minimap.camera_world_size_override = Vector2(1280.0, 720.0)
	var content_rect := Rect2(Vector2(16.0, 12.0), Vector2(232.0, 152.0))
	var view_world_rect: Rect2 = minimap.call("_get_minimap_view_world_rect", content_rect)
	var player_map_position: Vector2 = minimap.call("_world_to_map", player.global_position, content_rect, view_world_rect)
	TEST_UTILS.expect_close(player_map_position.x, content_rect.get_center().x, failures, "Player marker should stay centered on the minimap horizontally")
	TEST_UTILS.expect_close(player_map_position.y, content_rect.get_center().y, failures, "Player marker should stay centered on the minimap vertically")
	minimap.free()
	player.free()


func _test_world_slice_maps_to_partial_texture_region(failures: Array[String]) -> void:
	var minimap := _make_minimap()
	minimap.world_rect = Rect2(Vector2(-2000.0, -1200.0), Vector2(4000.0, 2400.0))
	var partial_world_rect := Rect2(Vector2(-500.0, -300.0), Vector2(1000.0, 600.0))
	var texture_region: Rect2 = minimap.call("_world_rect_to_texture_region", partial_world_rect)
	TEST_UTILS.expect(texture_region.position.x > 0.0, failures, "A centered world slice should start inside the biome texture instead of always from the left edge")
	TEST_UTILS.expect(texture_region.position.y > 0.0, failures, "A centered world slice should start inside the biome texture instead of always from the top edge")
	TEST_UTILS.expect(texture_region.size.x < 192.0, failures, "A minimap slice should sample only part of the biome texture width")
	TEST_UTILS.expect(texture_region.size.y < 116.0, failures, "A minimap slice should sample only part of the biome texture height")
	minimap.free()


func _make_minimap() -> Control:
	var minimap := MINIMAP_SCRIPT.new()
	minimap.size = Vector2(260.0, 180.0)
	return minimap
