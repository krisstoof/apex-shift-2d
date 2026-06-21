extends RefCounted
class_name GodotBiomeTextureRenderer


func build_texture_from_render_data(render_data: Dictionary) -> ImageTexture:
	var texture_size := Vector2i(render_data.get("texture_size", Vector2i.ZERO))
	if texture_size.x <= 0 or texture_size.y <= 0:
		return null
	var image := Image.create(texture_size.x, texture_size.y, false, Image.FORMAT_RGBA8)
	for sample_value in Array(render_data.get("samples", [])):
		var sample := Dictionary(sample_value)
		var pixel := Vector2i(sample.get("pixel", Vector2i.ZERO))
		var color := Color(sample.get("color", Color.BLACK))
		if pixel.x < 0 or pixel.y < 0:
			continue
		if pixel.x >= texture_size.x or pixel.y >= texture_size.y:
			continue
		image.set_pixel(pixel.x, pixel.y, color)
	return ImageTexture.create_from_image(image)
