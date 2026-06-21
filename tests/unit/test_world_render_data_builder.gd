extends RefCounted

const WorldRenderDataBuilder := preload("res://scripts/core/rendering/world_render_data_builder.gd")


func run() -> Dictionary:
	var failures: Array[String] = []
	_test_build_biome_blend_render_data(failures)
	_test_build_biome_color_key(failures)
	return {"passed": failures.is_empty(), "failures": failures}


func _test_build_biome_blend_render_data(failures: Array[String]) -> void:
	var builder := WorldRenderDataBuilder.new()
	var biomes := [{
		"id": "test_biome",
		"name": "Test Biome",
		"points": [Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)],
		"color": Color(1, 0, 0)
	}]
	var data := builder.build_biome_blend_render_data(Rect2(Vector2.ZERO, Vector2(100, 100)), Vector2i(4, 4), biomes, Color.BLACK)
	var samples := Array(data.get("samples", []))
	if samples.size() != 16:
		failures.append("Expected 16 render samples, got %d" % samples.size())
	if Vector2i(data.get("texture_size", Vector2i.ZERO)) != Vector2i(4, 4):
		failures.append("Expected texture size 4x4")


func _test_build_biome_color_key(failures: Array[String]) -> void:
	var builder := WorldRenderDataBuilder.new()
	var biomes := [{"id": "a", "color": Color(1, 0, 0)}, {"id": "b", "color": Color(0, 1, 0)}]
	var key := builder.build_biome_color_key(biomes)
	if not key.contains("a:"):
		failures.append("Expected color key to contain biome a")
	if not key.contains("b:"):
		failures.append("Expected color key to contain biome b")
