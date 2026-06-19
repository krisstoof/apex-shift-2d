extends SceneTree

const CORE_CRAFTING_TESTS := preload("res://tests/unit/test_core_crafting.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var suite := CORE_CRAFTING_TESTS.new()
	var failures: Array[String] = await suite.run()
	if failures.is_empty():
		print("[CoreCraftingTests] All tests passed.")
		quit(0)
		return
	push_error("[CoreCraftingTests] %d failure(s):" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(1)
