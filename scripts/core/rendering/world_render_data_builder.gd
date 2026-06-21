extends RefCounted
class_name WorldRenderDataBuilder

const BiomeSurfaceSampler := preload("res://scripts/core/rendering/biome_surface_sampler.gd")

var biome_surface_sampler := BiomeSurfaceSampler.new()


func build_biome_blend_render_data(world_rect: Rect2, texture_size: Vector2i, biome_zones: Array, fallback_color: Color = Color.BLACK) -> Dictionary:
	var samples: Array[Dictionary] = []
	if texture_size.x <= 0 or texture_size.y <= 0:
		return {"world_rect": world_rect, "texture_size": texture_size, "samples": samples}
	for y in range(texture_size.y):
		for x in range(texture_size.x):
			var sampled_position := world_rect.position + Vector2(
				(float(x) + 0.5) / float(texture_size.x) * world_rect.size.x,
				(float(y) + 0.5) / float(texture_size.y) * world_rect.size.y
			)
			var sample := biome_surface_sampler.build_surface_sample(sampled_position, biome_zones, fallback_color)
			sample["pixel"] = Vector2i(x, y)
			samples.append(sample)
	return {"world_rect": world_rect, "texture_size": texture_size, "samples": samples}


func build_biome_color_key(biome_zones: Array) -> String:
	var parts: Array[String] = []
	for biome_value in biome_zones:
		var biome := Dictionary(biome_value)
		var biome_id := _resolve_biome_id(biome)
		var color := Color(biome.get("color", Color.BLACK))
		parts.append("%s:%.3f,%.3f,%.3f,%.3f" % [biome_id, color.r, color.g, color.b, color.a])
	return "|".join(parts)


func _resolve_biome_id(biome: Dictionary) -> String:
	if biome.has("id"):
		return str(biome.get("id", ""))
	if biome.has("biome_id"):
		return str(biome.get("biome_id", ""))
	if biome.has("name"):
		return str(biome.get("name", "")).to_lower().replace(" ", "_")
	return ""
