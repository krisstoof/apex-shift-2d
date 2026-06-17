extends RefCounted
class_name RenderPerformanceGovernor

const GAME_BALANCE := preload("res://scripts/systems/game_balance.gd")

var fps_ema := 60.0
var mode := "normal"
var recovery_timer := 0.0


func update(delta: float, current_fps: float) -> void:
	var alpha := float(GAME_BALANCE.RENDER_PERFORMANCE.get("fps_ema_alpha", 0.08))
	fps_ema = lerpf(fps_ema, current_fps, alpha)
	var low_threshold := float(GAME_BALANCE.RENDER_PERFORMANCE.get("low_fps_threshold", 45))
	var recover_threshold := float(GAME_BALANCE.RENDER_PERFORMANCE.get("recover_fps_threshold", 55))
	if fps_ema < low_threshold:
		mode = "pressure"
		recovery_timer = 0.0
	elif fps_ema > recover_threshold:
		recovery_timer += delta
		if recovery_timer >= float(GAME_BALANCE.RENDER_PERFORMANCE.get("recovery_seconds", 3.0)):
			mode = "normal"
	else:
		recovery_timer = 0.0


func get_budget() -> Dictionary:
	var source := Dictionary(GAME_BALANCE.RENDER_PERFORMANCE.get(mode, GAME_BALANCE.RENDER_PERFORMANCE.get("normal", {})))
	var budgets: Dictionary = {}
	for key in source.keys():
		budgets[key] = source.get(key)
	budgets["mode"] = mode
	return budgets


func get_debug_data() -> Dictionary:
	return {
		"render_governor_mode": mode,
		"render_governor_fps_ema": fps_ema,
		"render_governor_recovery_timer": recovery_timer
	}
