extends RefCounted
class_name WorldRendererAdapter

const WORLD_RENDER_DATA := preload("res://scripts/rendering/world/world_render_data.gd")
const RUNTIME_PROFILER := preload("res://scripts/debug/runtime_profiler.gd")

var world: Node
var last_render_data: WorldRenderData
var render_data_build_count := 0
var last_render_data_build_ms := 0.0
var max_render_data_build_ms := 0.0
var terrain_adapter_bind_count := 0


func bind_world(p_world: Node) -> void:
	world = p_world


func build_render_data(player: Node2D = null, camera: Camera2D = null, visible_rect: Rect2 = Rect2()) -> WorldRenderData:
	var started := Time.get_ticks_usec()
	var rect := visible_rect
	if rect.size == Vector2.ZERO:
		rect = _resolve_visible_rect(player, camera)
	if bool(_get_world_flag("debug_hitch_breakdown_profiling", false)):
		RUNTIME_PROFILER.begin_scope("world_render_data_build_ms")
	last_render_data = WORLD_RENDER_DATA.from_world(world, rect)
	if bool(_get_world_flag("debug_hitch_breakdown_profiling", false)):
		RUNTIME_PROFILER.end_scope("world_render_data_build_ms")
	last_render_data_build_ms = float(Time.get_ticks_usec() - started) / 1000.0
	max_render_data_build_ms = maxf(max_render_data_build_ms, last_render_data_build_ms)
	render_data_build_count += 1
	return last_render_data


func bind_terrain_surface_renderer(renderer: Node, player: Node2D, camera: Camera2D) -> WorldRenderData:
	var render_data := build_render_data(player, camera)
	if renderer == null or not is_instance_valid(renderer):
		return render_data
	if renderer.has_method("bind"):
		renderer.call("bind", world, player, camera)
	if renderer.has_method("set_world_render_data"):
		renderer.call("set_world_render_data", render_data)
	terrain_adapter_bind_count += 1
	return render_data


func get_debug_data() -> Dictionary:
	var data_debug := last_render_data.to_debug_data() if last_render_data != null else {}
	return {
		"world_renderer_adapter_enabled": true,
		"render_data_build_count": render_data_build_count,
		"last_render_data_build_ms": last_render_data_build_ms,
		"max_render_data_build_ms": max_render_data_build_ms,
		"terrain_adapter_bind_count": terrain_adapter_bind_count,
		"last_render_data": data_debug
	}


func _resolve_visible_rect(player: Node2D, camera: Camera2D) -> Rect2:
	if camera == null and player != null and is_instance_valid(player):
		camera = player.get_node_or_null("Camera2D") as Camera2D
	if camera != null and is_instance_valid(camera) and camera.get_viewport() != null:
		var viewport_size := camera.get_viewport_rect().size
		var zoom := camera.zoom
		var safe_zoom := Vector2(maxf(absf(zoom.x), 0.01), maxf(absf(zoom.y), 0.01))
		var visible_world_size := Vector2(viewport_size.x / safe_zoom.x, viewport_size.y / safe_zoom.y)
		return Rect2(camera.global_position - visible_world_size * 0.5, visible_world_size)
	if world != null and world.has_method("get_world_rect"):
		return Rect2(world.call("get_world_rect"))
	return Rect2()


func _get_world_flag(flag_name: String, fallback: Variant) -> Variant:
	if world != null and world.has_method("get"):
		var value = world.get(flag_name)
		if value != null:
			return value
	return fallback
