extends RefCounted
class_name TerrainMaterialResolver

## Abstraction layer between world generation data and terrain rendering.
##
## The world generator outputs terrain types ("land", "shore", "pond", …) and
## biome IDs ("hearth_meadow", "westwood", …).  The renderer should call this
## resolver to obtain material keys and fallback colors, rather than inlining
## terrain→color decisions directly in the rendering pipeline.
##
## This separation means:
##   - Terrain textures / materials can be swapped without touching WorldGenerator.
##   - The same key can map to a flat debug color today and a PBR texture tomorrow.
##   - WorldGenerationResult.generation_hash is unaffected by any material change.


## Returns a stable string key that identifies the visual material for a given
## terrain/biome combination.  The key can be used to look up textures, shaders,
## or tilesets without coupling the generator to the renderer.
func get_material_key(terrain_type: String, biome_id: String) -> String:
	match terrain_type:
		"deep_ocean":
			return "water_deep"
		"shallow_water":
			return "water_shallow"
		"shore":
			return "shore"
		"pond":
			return "water_pond"
		"highland":
			return biome_id + "_highland"
		"rocky_patch":
			return biome_id + "_rocky"
		"wetland":
			return biome_id + "_wetland"
		_:
			return biome_id + "_land"


## Returns the flat fallback color used when a texture asset is unavailable.
## Matches the color logic currently inlined in TerrainSurfaceChunkRenderer
## so both systems produce identical output until real textures are added.
func get_base_color(terrain_type: String, biome_id: String) -> Color:
	match terrain_type:
		"deep_ocean":
			return Color(0.045, 0.145, 0.31)
		"shallow_water":
			return Color(0.07, 0.27, 0.43)
		"shore":
			return Color(0.70, 0.65, 0.42)
		"pond":
			return Color(0.06, 0.29, 0.38)
		"highland":
			return _get_biome_color(biome_id).lerp(Color(0.52, 0.48, 0.34), 0.34)
		"rocky_patch":
			return _get_biome_color(biome_id).lerp(Color(0.44, 0.42, 0.35), 0.42)
		"wetland":
			return _get_biome_color(biome_id).lerp(Color(0.13, 0.27, 0.18), 0.35)
		_:
			return _get_biome_color(biome_id)


## True for terrain types that are covered by water (characters cannot walk here).
func is_water_type(terrain_type: String) -> bool:
	return terrain_type in ["deep_ocean", "shallow_water", "pond"]


## True for terrain types considered walkable land.
func is_land_type(terrain_type: String) -> bool:
	return not is_water_type(terrain_type) and terrain_type != "shore"


func _get_biome_color(biome_id: String) -> Color:
	match biome_id:
		"westwood":
			return Color(0.16, 0.35, 0.17)
		"stoneback_ridge":
			return Color(0.50, 0.46, 0.36)
		"hearth_meadow":
			return Color(0.39, 0.58, 0.27)
		"south_thicket":
			return Color(0.23, 0.43, 0.18)
		"redfang_wilds":
			return Color(0.48, 0.27, 0.19)
		_:
			return Color(0.34, 0.51, 0.25)
