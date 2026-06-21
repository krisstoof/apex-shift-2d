extends RefCounted

const BiomeSurfaceSampler := preload("res://scripts/core/rendering/biome_surface_sampler.gd")


func run() -> Dictionary:
	var failures: Array[String] = []
	_test_returns_biome_id_for_point_inside_polygon(failures)
	_test_returns_empty_for_point_outside(failures)
	_test_returns_biome_color(failures)
	return {"passed": failures.is_empty(), "failures": failures}


func _test_returns_biome_id_for_point_inside_polygon(failures: Array[String]) -> void:
	var sampler := BiomeSurfaceSampler.new()
	var biomes := [{
		"id": "test_biome",
		"name": "Test Biome",
		"points": [Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)],
		"color": Color(1, 0, 0)
	}]
	var biome_id := sampler.get_biome_id_at(Vector2(50, 50), biomes)
	if biome_id != "test_biome":
		failures.append("Expected test_biome, got %s" % biome_id)


func _test_returns_empty_for_point_outside(failures: Array[String]) -> void:
	var sampler := BiomeSurfaceSampler.new()
	var biomes := [{
		"id": "test_biome",
		"points": [Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)],
		"color": Color(1, 0, 0)
	}]
	var biome_id := sampler.get_biome_id_at(Vector2(200, 200), biomes)
	if biome_id != "":
		failures.append("Expected empty biome id outside polygon")


func _test_returns_biome_color(failures: Array[String]) -> void:
	var sampler := BiomeSurfaceSampler.new()
	var expected_color := Color(0.2, 0.4, 0.6)
	var biomes := [{
		"id": "color_biome",
		"points": [Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)],
		"color": expected_color
	}]
	var color := sampler.get_biome_color_at(Vector2(50, 50), biomes, Color.BLACK)
	if color != expected_color:
		failures.append("Expected biome color to be returned")
