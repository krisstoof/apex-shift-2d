extends RefCounted
class_name BiomeGenerator

func build_biome_map(seed: int, world_rect: Rect2, generator: Object):
	var biome_map = load("res://scripts/world/biome_map.gd").new()
	biome_map.build(seed, world_rect, generator)
	return biome_map
