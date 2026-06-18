extends Node


func _ready() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var failures: Array[String] = []
	failures.append_array(preload("res://tests/unit/test_world_generation_stability.gd").new().run())
	failures.append_array(preload("res://tests/unit/test_biome_generation_rules.gd").new().run())

	if failures.is_empty():
		print("\nAll world generation tests PASSED!")
		print("  - stability tests")
		print("  - biome rule tests")
		get_tree().quit(0)
	else:
		print("\nFAILURES DETECTED:")
		for failure in failures:
			print("  - " + failure)
		print("\nTotal failures: %d" % failures.size())
		get_tree().quit(1)
