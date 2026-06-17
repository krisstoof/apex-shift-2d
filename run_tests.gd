extends Node

func _ready() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var test_suite = preload("res://tests/unit/test_world_generation_stability.gd").new()
	var failures = test_suite.run()
	
	if failures.is_empty():
		print("\n✓ All world generation tests PASSED!")
		print("  - 13 test methods")
		print("  - 14 test seeds each")
		print("  - 182 total test cases")
		get_tree().quit(0)
	else:
		print("\n✗ FAILURES DETECTED:")
		for failure in failures:
			print("  - " + failure)
		print("\nTotal failures: %d" % failures.size())
		get_tree().quit(1)
