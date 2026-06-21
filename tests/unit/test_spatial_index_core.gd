extends RefCounted

const SpatialIndexCore := preload("res://scripts/core/spatial/spatial_index_core.gd")


func run() -> Dictionary:
	var failures: Array[String] = []
	_test_register_and_query_near(failures)
	_test_query_rect(failures)
	_test_update_position_changes_cell(failures)
	_test_unregister_removes_entity(failures)
	_test_type_filter(failures)
	return {"passed": failures.is_empty(), "failures": failures}


func _test_register_and_query_near(failures: Array[String]) -> void:
	var index := SpatialIndexCore.new()
	index.register_entity("r1", "resource", "conifer_tree", Vector2(100, 100))
	index.register_entity("r2", "resource", "leafy_tree", Vector2(500, 500))
	var result := index.query_near(Vector2(100, 100), 80.0, "resource")
	if result.size() != 1:
		failures.append("Expected 1 nearby resource, got %d" % result.size())
		return
	if str(result[0].get("id", "")) != "r1":
		failures.append("Expected r1 in nearby query")


func _test_query_rect(failures: Array[String]) -> void:
	var index := SpatialIndexCore.new()
	index.register_entity("a", "creature", "grazer", Vector2(10, 10))
	index.register_entity("b", "creature", "varnak", Vector2(300, 300))
	var result := index.query_rect(Rect2(Vector2.ZERO, Vector2(100, 100)), "creature")
	if result.size() != 1:
		failures.append("Expected 1 creature in rect, got %d" % result.size())
		return
	if str(result[0].get("id", "")) != "a":
		failures.append("Expected creature a in rect query")


func _test_update_position_changes_cell(failures: Array[String]) -> void:
	var index := SpatialIndexCore.new()
	index.register_entity("x", "resource", "rock", Vector2(0, 0))
	var before := index.query_near(Vector2(0, 0), 50.0, "resource")
	if before.size() != 1:
		failures.append("Expected entity before update")
	index.update_entity_position("x", Vector2(1000, 1000))
	var old_result := index.query_near(Vector2(0, 0), 50.0, "resource")
	var new_result := index.query_near(Vector2(1000, 1000), 50.0, "resource")
	if old_result.size() != 0:
		failures.append("Expected no entity near old position after update")
	if new_result.size() != 1:
		failures.append("Expected entity near new position after update")


func _test_unregister_removes_entity(failures: Array[String]) -> void:
	var index := SpatialIndexCore.new()
	index.register_entity("gone", "resource", "berry_bush", Vector2(20, 20))
	index.unregister_entity("gone")
	var result := index.query_near(Vector2(20, 20), 100.0, "resource")
	if result.size() != 0:
		failures.append("Expected no entity after unregister")


func _test_type_filter(failures: Array[String]) -> void:
	var index := SpatialIndexCore.new()
	index.register_entity("c1", "creature", "grazer", Vector2(0, 0))
	index.register_entity("c2", "creature", "varnak", Vector2(10, 10))
	var grazers := index.query_near(Vector2.ZERO, 100.0, "creature", "grazer")
	if grazers.size() != 1:
		failures.append("Expected 1 grazer, got %d" % grazers.size())
		return
	if str(grazers[0].get("type", "")) != "grazer":
		failures.append("Expected grazer type filter result")
