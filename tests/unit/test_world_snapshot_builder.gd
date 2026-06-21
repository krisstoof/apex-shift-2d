extends RefCounted

const WorldSnapshotBuilder := preload("res://scripts/core/presentation/world_snapshot_builder.gd")


func run() -> Dictionary:
	var failures: Array[String] = []
	_test_build_player_snapshot(failures)
	_test_build_marker_snapshot(failures)
	_test_build_full_snapshot(failures)
	_test_build_world_snapshot_includes_runtime_context(failures)
	return {"passed": failures.is_empty(), "failures": failures}


func _test_build_player_snapshot(failures: Array[String]) -> void:
	var builder := WorldSnapshotBuilder.new()
	var snapshot := builder.build_player_snapshot({
		"position": Vector2(10, 20),
		"health": 80,
		"hunger": 40,
		"stamina": 70,
		"rest": 60,
		"inventory": {"wood": 3}
	})
	if Vector2(snapshot.get("position", Vector2.ZERO)) != Vector2(10, 20):
		failures.append("Expected player position to be preserved")
	if float(snapshot.get("health", 0.0)) != 80.0:
		failures.append("Expected player health to be preserved")
	var inventory := Dictionary(snapshot.get("inventory", {}))
	if int(inventory.get("wood", 0)) != 3:
		failures.append("Expected inventory wood amount to be preserved")


func _test_build_marker_snapshot(failures: Array[String]) -> void:
	var builder := WorldSnapshotBuilder.new()
	var markers := builder.build_marker_snapshot(
		[{"position": Vector2(1, 2), "type": "conifer_tree"}],
		[{"position": Vector2(3, 4), "type": "campfire"}],
		[],
		[],
		[]
	)
	if Array(markers.get("resources", [])).size() != 1:
		failures.append("Expected one resource marker")
	if Array(markers.get("campfires", [])).size() != 1:
		failures.append("Expected one campfire marker")


func _test_build_full_snapshot(failures: Array[String]) -> void:
	var builder := WorldSnapshotBuilder.new()
	var snapshot := builder.build_snapshot({
		"player": {"position": Vector2(5, 6)},
		"time": {"day": 2},
		"world": {"world_seed": 123},
		"markers": {"resources": []},
		"ecosystem": {"biomes": {}},
		"debug": {"fps": 60}
	})
	if not snapshot.has("player"):
		failures.append("Expected full snapshot to have player section")
	if not snapshot.has("time"):
		failures.append("Expected full snapshot to have time section")
	if not snapshot.has("world"):
		failures.append("Expected full snapshot to have world section")
	if int(Dictionary(snapshot.get("time", {})).get("day", 0)) != 2:
		failures.append("Expected day to be preserved")


func _test_build_world_snapshot_includes_runtime_context(failures: Array[String]) -> void:
	var builder := WorldSnapshotBuilder.new()
	var snapshot := builder.build_world_snapshot({
		"runtime_context": {
			"bound": true,
			"world": true,
			"player": true,
			"event_bus": true
		}
	})
	var runtime_context := Dictionary(snapshot.get("runtime_context", {}))
	if runtime_context.is_empty():
		failures.append("Expected world snapshot to include runtime_context")
	if runtime_context.get("bound", false) != true:
		failures.append("Expected runtime_context.bound to be true")
	if runtime_context.get("player", false) != true:
		failures.append("Expected runtime_context.player to be true")
