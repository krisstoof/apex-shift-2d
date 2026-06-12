extends RefCounted

const VARNAK_SCENE := preload("res://scenes/creatures/varnak.tscn")
const RESOURCE_NODE_SCENE := preload("res://scenes/world/resource_node.tscn")
const WORLD_CONFIG := preload("res://scripts/world/world_config.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")
const VARNAK_PROFILE_PATH := "res://data/species_varnak.json"


class TestWorld:
	extends Node2D

	var terrain_multiplier := 1.0
	var water := false
	var navigation_blocked := false
	var deep_water := false
	var spawned_meat_amount := 0
	var spawned_bone_amount := 0
	var cached_groups := {}

	func get_terrain_speed_multiplier(_position: Vector2) -> float:
		return terrain_multiplier

	func is_position_in_water(_position: Vector2) -> bool:
		return water

	func is_position_in_deep_water(_position: Vector2) -> bool:
		return deep_water

	func is_creature_navigation_blocked(_position: Vector2) -> bool:
		return navigation_blocked

	func spawn_meat_drop_for_animal(_animal_kind: String, _drop_position: Vector2) -> Node:
		spawned_meat_amount += 1
		return Node2D.new()

	func spawn_bone_drop_for_animal(_animal_kind: String, _drop_position: Vector2) -> Node:
		spawned_bone_amount += 1
		return Node2D.new()

	func get_cached_group_nodes(group_name: String) -> Array:
		var nodes: Array = cached_groups.get(group_name, [])
		return nodes.duplicate()

	func register_cached_group_node(group_name: String, node: Node) -> void:
		if not cached_groups.has(group_name):
			cached_groups[group_name] = []
		var nodes: Array = cached_groups[group_name]
		if not nodes.has(node):
			nodes.append(node)


class TestTarget:
	extends Node2D

	var health := 100.0
	var damage_taken := 0.0

	func take_damage(amount: float, _source: String) -> void:
		damage_taken += amount
		health = max(health - amount, 0.0)


class TestEcosystemDirector:
	extends Node

	var state: Dictionary = {}

	func get_biome_state(_biome_id: String) -> Dictionary:
		return state.duplicate(true)


class TestDayNightSystem:
	extends Node

	var day := 1

	func get_day() -> int:
		return day


class TestPlayer:
	extends Node2D

	var damage_taken := 0.0
	var torch_active := false

	func receive_damage(amount: float, _source: String = "unknown") -> void:
		damage_taken += amount

	func is_torch_active() -> bool:
		return torch_active


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_varnak_initializes_with_valid_health(failures)
	_test_varnak_initializes_inside_world(failures)
	_test_varnak_has_predator_diet(failures)
	_test_varnak_uses_first_week_profile_tuning(failures)
	_test_varnak_has_hunger_component(failures)
	_test_varnak_has_attack_damage(failures)
	_test_varnak_has_detection_range(failures)
	_test_varnak_throttles_ai_decisions(failures)
	_test_varnak_can_wander(failures)
	_test_varnak_does_not_leave_world_bounds(failures)
	_test_varnak_searches_prey_when_hungry(failures)
	_test_varnak_does_not_hunt_when_not_hungry(failures)
	_test_varnak_prefers_nearest_valid_prey(failures)
	_test_varnak_protects_critical_prey_populations(failures)
	_test_varnak_detects_nearby_small_prey(failures)
	_test_varnak_detects_nearby_grazer(failures)
	_test_varnak_detects_player_when_hungry(failures)
	_test_varnak_ignores_target_outside_detection_range(failures)
	_test_varnak_moves_toward_target(failures)
	_test_varnak_attacks_target_in_range(failures)
	_test_varnak_attack_reduces_target_health(failures)
	_test_varnak_attack_has_cooldown(failures)
	_test_varnak_cannot_attack_during_cooldown(failures)
	_test_varnak_resumes_attack_after_cooldown(failures)
	_test_varnak_eats_meat_or_dead_prey(failures)
	_test_varnak_skips_freed_meat_drop_targets(failures)
	_test_varnak_hunger_restored_after_eating(failures)
	_test_varnak_restore_from_data_handles_null_fields(failures)
	_test_varnak_visibility_culling_sleeps_ai_and_collision(failures)
	_test_varnak_returns_to_wandering_after_eating(failures)
	_test_varnak_takes_damage(failures)
	_test_varnak_dies_at_zero_health(failures)
	_test_varnak_drops_meat_on_death(failures)
	_test_varnak_drops_bone_on_death(failures)
	_test_varnak_does_not_duplicate_meat_drop_on_repeated_death(failures)
	_test_varnak_removed_from_ecosystem_after_death(failures)
	return failures


func _test_varnak_throttles_ai_decisions(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	varnak.ai_decision_timer = 0.10
	TEST_UTILS.expect(not varnak.call("_should_update_ai_decision", 0.05), failures, "Varnak should skip decisions before its AI interval elapses")
	TEST_UTILS.expect(varnak.call("_should_update_ai_decision", 0.06), failures, "Varnak should run a decision after its AI interval elapses")
	TEST_UTILS.expect(not varnak.call("_should_update_ai_decision", 0.01), failures, "Varnak should reset its decision interval after an update")
	varnak.queue_free()


func _test_varnak_initializes_with_valid_health(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	TEST_UTILS.expect(varnak.health > 0.0, failures, "Varnak should start with positive health")
	TEST_UTILS.expect_close(varnak.health, varnak.max_health, failures, "Varnak should start at full health")
	varnak.queue_free()


func _test_varnak_initializes_inside_world(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	TEST_UTILS.expect(_get_world_rect().has_point(varnak.global_position), failures, "Varnak should start inside the world")
	varnak.queue_free()


func _test_varnak_has_predator_diet(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var profile := _read_profile()
	varnak.apply_profile(profile)
	TEST_UTILS.expect_close(varnak.meat_diet, 1.0, failures, "Varnak should strongly prefer meat")
	TEST_UTILS.expect_close(varnak.scavenger_diet, 0.45, failures, "Varnak should keep the configured scavenger diet")
	varnak.queue_free()


func _test_varnak_uses_first_week_profile_tuning(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var profile := _read_profile()
	var day_night := TestDayNightSystem.new()
	day_night.day = 1
	varnak.day_night_system = day_night
	varnak.apply_profile(profile)
	TEST_UTILS.expect_close(varnak.aggression, 0.18, failures, "Day 1 should soften Varnak aggression")
	TEST_UTILS.expect_close(varnak.night_activity, 0.14, failures, "Day 1 should soften Varnak night activity")
	day_night.day = 3
	varnak.apply_profile(profile)
	TEST_UTILS.expect_close(varnak.aggression, 0.45, failures, "Day 3 should restore the baseline aggression")
	TEST_UTILS.expect_close(varnak.night_activity, 0.25, failures, "Day 3 should restore the baseline night activity")
	varnak.queue_free()


func _test_varnak_has_hunger_component(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	TEST_UTILS.expect(varnak.hunger >= 0.0, failures, "Varnak hunger should be initialized")
	TEST_UTILS.expect(varnak.energy > 0.0, failures, "Varnak energy should be initialized")
	varnak.queue_free()


func _test_varnak_has_attack_damage(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var player := _make_player(Vector2(24.0, 0.0))
	varnak.player = player
	varnak.global_position = Vector2.ZERO
	varnak.state = varnak.State.ATTACK
	varnak.facing_angle = 0.0
	varnak.attack_cooldown = 0.0
	varnak.call("_act", 0.0)
	TEST_UTILS.expect(player.damage_taken > 0.0, failures, "Attack should deal damage to the player")
	varnak.queue_free()


func _test_varnak_has_detection_range(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	TEST_UTILS.expect(varnak.call("_get_prey_detect_radius") > 0.0, failures, "Prey detection range should be positive")
	TEST_UTILS.expect(varnak.call("_get_player_intrusion_radius") > 0.0, failures, "Player intrusion radius should be positive")
	varnak.queue_free()


func _test_varnak_can_wander(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var world := _ensure_world()
	world.navigation_blocked = false
	varnak.global_position = Vector2.ZERO
	varnak.call("_pick_wander_target")
	TEST_UTILS.expect(varnak.wander_target != Vector2.ZERO, failures, "Varnak should pick a wander target")
	varnak.queue_free()


func _test_varnak_does_not_leave_world_bounds(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	varnak.global_position = Vector2(10000.0, 10000.0)
	varnak.call("_enforce_world_bounds")
	var clamped_world: Rect2 = _get_world_rect()
	TEST_UTILS.expect(varnak.global_position.x >= clamped_world.position.x and varnak.global_position.x <= clamped_world.end.x, failures, "Varnak should stay within the world width")
	TEST_UTILS.expect(varnak.global_position.y >= clamped_world.position.y and varnak.global_position.y <= clamped_world.end.y, failures, "Varnak should stay within the world height")
	varnak.queue_free()


func _test_varnak_searches_prey_when_hungry(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var world := _ensure_world()
	var prey := _spawn_target(world, "small_prey", Vector2(150.0, 0.0))
	_set_player(varnak, Vector2(2000.0, 0.0))
	varnak.hunger = 0.55
	varnak.energy = 1.0
	varnak.global_position = Vector2.ZERO
	varnak.call("_update_state")
	TEST_UTILS.expect_equal(varnak.state, varnak.State.HUNT_ECOSYSTEM, failures, "Hungry Varnak should hunt ecosystem prey")
	TEST_UTILS.expect_equal(varnak.ecosystem_target_kind, "small_prey", failures, "Varnak should lock a small prey target")
	prey.queue_free()
	varnak.queue_free()


func _test_varnak_does_not_hunt_when_not_hungry(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var world := _ensure_world()
	_spawn_target(world, "small_prey", Vector2(150.0, 0.0))
	_set_player(varnak, Vector2(2000.0, 0.0))
	varnak.hunger = 0.10
	varnak.energy = 1.0
	varnak.global_position = Vector2.ZERO
	varnak.call("_update_state")
	TEST_UTILS.expect(varnak.state != varnak.State.HUNT_ECOSYSTEM, failures, "Comfortable Varnak should not hunt prey")
	TEST_UTILS.expect_equal(varnak.ecosystem_target_kind, "", failures, "Comfortable Varnak should not lock a prey target")
	varnak.queue_free()


func _test_varnak_prefers_nearest_valid_prey(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var world := _ensure_world()
	var near_prey := _spawn_target(world, "small_prey", Vector2(120.0, 0.0))
	var far_prey := _spawn_target(world, "small_prey", Vector2(260.0, 0.0))
	_set_player(varnak, Vector2(2000.0, 0.0))
	varnak.hunger = 0.55
	varnak.energy = 1.0
	varnak.global_position = Vector2.ZERO
	varnak.call("_update_state")
	TEST_UTILS.expect_equal(varnak.state, varnak.State.HUNT_ECOSYSTEM, failures, "Hungry Varnak should enter hunting state")
	TEST_UTILS.expect_equal(varnak.ecosystem_target, near_prey, failures, "Varnak should choose the nearest valid prey")
	TEST_UTILS.expect(varnak.ecosystem_target != far_prey, failures, "Varnak should not prefer a farther prey over a nearer one")
	near_prey.queue_free()
	far_prey.queue_free()
	varnak.queue_free()


func _test_varnak_detects_nearby_small_prey(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var world := _ensure_world()
	_spawn_target(world, "small_prey", Vector2(150.0, 0.0))
	_set_player(varnak, Vector2(2000.0, 0.0))
	varnak.hunger = 0.55
	varnak.global_position = Vector2.ZERO
	varnak.call("_update_state")
	TEST_UTILS.expect_equal(varnak.state, varnak.State.HUNT_ECOSYSTEM, failures, "Varnak should detect a nearby small prey")
	TEST_UTILS.expect_equal(varnak.ecosystem_target_kind, "small_prey", failures, "Varnak should mark the small prey target")
	varnak.queue_free()


func _test_varnak_detects_nearby_grazer(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var world := _ensure_world()
	_spawn_target(world, "grazer", Vector2(150.0, 0.0))
	_set_player(varnak, Vector2(2000.0, 0.0))
	varnak.hunger = 0.55
	varnak.global_position = Vector2.ZERO
	varnak.call("_update_state")
	TEST_UTILS.expect_equal(varnak.state, varnak.State.HUNT_ECOSYSTEM, failures, "Varnak should detect a nearby grazer")
	TEST_UTILS.expect_equal(varnak.ecosystem_target_kind, "grazer", failures, "Varnak should mark the grazer target")
	varnak.queue_free()


func _test_varnak_detects_player_when_hungry(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var player := _make_player(Vector2(110.0, 0.0))
	varnak.player = player
	varnak.global_position = Vector2.ZERO
	varnak.hunger = 0.55
	varnak.call("_update_state")
	TEST_UTILS.expect(varnak.state == varnak.State.CHASE or varnak.state == varnak.State.STALK or varnak.state == varnak.State.ATTACK, failures, "Hungry Varnak should react to a nearby player")
	varnak.queue_free()


func _test_varnak_ignores_target_outside_detection_range(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var world := _ensure_world()
	_spawn_target(world, "small_prey", Vector2(2000.0, 0.0))
	_set_player(varnak, Vector2(4000.0, 0.0))
	varnak.hunger = 0.55
	varnak.global_position = Vector2.ZERO
	varnak.call("_update_state")
	TEST_UTILS.expect(varnak.state != varnak.State.HUNT_ECOSYSTEM, failures, "Varnak should ignore prey outside the detection range")
	TEST_UTILS.expect_equal(varnak.ecosystem_target_kind, "", failures, "Varnak should not lock a distant prey target")
	varnak.queue_free()


func _test_varnak_moves_toward_target(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var target := TestTarget.new()
	target.global_position = Vector2(140.0, 0.0)
	varnak.ecosystem_target = target
	varnak.ecosystem_target_kind = "small_prey"
	varnak.state = varnak.State.HUNT_ECOSYSTEM
	varnak.global_position = Vector2.ZERO
	varnak.call("_act", 0.0)
	TEST_UTILS.expect(varnak.velocity.length() > 0.0, failures, "Varnak should move toward ecosystem prey")
	varnak.queue_free()


func _test_varnak_attacks_target_in_range(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var target := TestTarget.new()
	target.global_position = Vector2(30.0, 0.0)
	varnak.ecosystem_target = target
	varnak.ecosystem_target_kind = "small_prey"
	varnak.state = varnak.State.HUNT_ECOSYSTEM
	varnak.global_position = Vector2.ZERO
	varnak.call("_act", 0.0)
	TEST_UTILS.expect(target.damage_taken > 0.0, failures, "Varnak should attack a target in range")
	varnak.queue_free()


func _test_varnak_attack_reduces_target_health(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var target := TestTarget.new()
	target.health = 150.0
	target.global_position = Vector2(30.0, 0.0)
	varnak.ecosystem_target = target
	varnak.ecosystem_target_kind = "grazer"
	varnak.state = varnak.State.HUNT_ECOSYSTEM
	varnak.global_position = Vector2.ZERO
	varnak.call("_act", 0.0)
	TEST_UTILS.expect(target.health < 150.0, failures, "Attack should reduce the target health")
	varnak.queue_free()


func _test_varnak_attack_has_cooldown(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var target := TestTarget.new()
	target.global_position = Vector2(30.0, 0.0)
	varnak.ecosystem_target = target
	varnak.ecosystem_target_kind = "small_prey"
	varnak.state = varnak.State.HUNT_ECOSYSTEM
	varnak.attack_cooldown = 1.0
	varnak.global_position = Vector2.ZERO
	varnak.call("_act", 0.0)
	TEST_UTILS.expect_close(varnak.attack_cooldown, 1.0, failures, "Cooldown should remain active until time passes")
	varnak.queue_free()


func _test_varnak_cannot_attack_during_cooldown(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var target := TestTarget.new()
	target.global_position = Vector2(30.0, 0.0)
	varnak.ecosystem_target = target
	varnak.ecosystem_target_kind = "small_prey"
	varnak.state = varnak.State.HUNT_ECOSYSTEM
	varnak.attack_cooldown = 1.0
	varnak.global_position = Vector2.ZERO
	varnak.call("_act", 0.0)
	TEST_UTILS.expect_close(target.damage_taken, 0.0, failures, "Cooldown should block attacks")
	varnak.queue_free()


func _test_varnak_resumes_attack_after_cooldown(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var target := TestTarget.new()
	target.global_position = Vector2(30.0, 0.0)
	varnak.ecosystem_target = target
	varnak.ecosystem_target_kind = "small_prey"
	varnak.state = varnak.State.HUNT_ECOSYSTEM
	varnak.attack_cooldown = 0.0
	varnak.global_position = Vector2.ZERO
	varnak.call("_act", 0.0)
	TEST_UTILS.expect(target.damage_taken > 0.0, failures, "Varnak should attack again once cooldown is over")
	varnak.queue_free()


func _test_varnak_eats_meat_or_dead_prey(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var world := _ensure_world()
	var meat := _spawn_meat(world, Vector2(20.0, 0.0))
	varnak.hunger = 0.60
	varnak.energy = 1.0
	varnak.global_position = Vector2.ZERO
	_set_player(varnak, Vector2(2000.0, 0.0))
	varnak.call("_update_state")
	TEST_UTILS.expect_equal(varnak.state, varnak.State.EAT_MEAT, failures, "Hungry Varnak should choose meat when available")
	TEST_UTILS.expect(is_instance_valid(varnak.meat_target), failures, "Varnak should lock the meat target")
	meat.queue_free()
	varnak.queue_free()


func _test_varnak_skips_freed_meat_drop_targets(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var world := _ensure_world()
	var live_meat := _spawn_meat(world, Vector2(180.0, 0.0))
	var stale_meat := _spawn_meat(world, Vector2(24.0, 0.0))
	stale_meat.free()
	var found: Node2D = varnak.call("_find_nearest_meat_drop", 500.0) as Node2D
	TEST_UTILS.expect_equal(found, live_meat, failures, "Varnak should ignore freed meat drops and pick the live target")
	varnak.queue_free()


func _test_varnak_hunger_restored_after_eating(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var world := _ensure_world()
	var meat := _spawn_meat(world, Vector2(20.0, 0.0))
	varnak.hunger = 0.65
	varnak.energy = 1.0
	varnak.global_position = Vector2.ZERO
	_set_player(varnak, Vector2(2000.0, 0.0))
	varnak.meat_target = meat
	var before_hunger: float = varnak.hunger
	varnak.call("_consume_meat_target")
	TEST_UTILS.expect(varnak.hunger < before_hunger, failures, "Eating meat should reduce hunger")
	TEST_UTILS.expect_equal(varnak.last_food_source, "meat_drop", failures, "Meat eating should be recorded")
	meat.queue_free()
	varnak.queue_free()


func _test_varnak_restore_from_data_handles_null_fields(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var before_health: float = varnak.health
	varnak.restore_from_data({
		"facing_angle": null,
		"rotation": null,
		"health": null,
		"attack_cooldown": null,
		"dropped_meat": null
	})
	TEST_UTILS.expect_close(varnak.health, before_health, failures, "Varnak restore should ignore null health values")
	TEST_UTILS.expect(varnak.facing_angle == varnak.facing_angle, failures, "Varnak restore should not produce an invalid facing angle")
	varnak.queue_free()


func _test_varnak_visibility_culling_sleeps_ai_and_collision(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	varnak.player = Node2D.new()
	varnak.player.global_position = Vector2(100000.0, 100000.0)
	var original_layer: int = varnak.collision_layer
	var original_mask: int = varnak.collision_mask
	var before_position: Vector2 = varnak.global_position
	var before_ai_decisions: int = varnak.ai_decision_count
	TEST_UTILS.expect(varnak.has_method("set_visibility_culled"), failures, "Varnak should expose visibility culling")
	varnak.call("set_visibility_culled", false)
	TEST_UTILS.expect_equal(varnak.visible, false, failures, "Culled varnak should be hidden")
	TEST_UTILS.expect_equal(bool(varnak.get("is_visibility_culled")), true, failures, "Culled varnak should remember it is sleeping")
	TEST_UTILS.expect_equal(varnak.collision_layer, 0, failures, "Culled varnak should disable its collision layer")
	TEST_UTILS.expect_equal(varnak.collision_mask, 0, failures, "Culled varnak should disable its collision mask")
	TEST_UTILS.expect_equal(varnak.is_physics_processing(), false, failures, "Culled varnak should stop physics processing")
	TEST_UTILS.expect_equal(varnak.is_processing(), false, failures, "Culled varnak should stop frame processing")
	varnak.call("_physics_process", 0.2)
	TEST_UTILS.expect_equal(varnak.ai_decision_count, before_ai_decisions, failures, "Sleeping varnak should not advance AI decisions")
	TEST_UTILS.expect_equal(varnak.global_position, before_position, failures, "Sleeping varnak should not move")
	varnak.call("set_visibility_culled", true)
	TEST_UTILS.expect_equal(varnak.visible, true, failures, "Reactivated varnak should be visible")
	TEST_UTILS.expect_equal(bool(varnak.get("is_visibility_culled")), false, failures, "Reactivated varnak should clear the sleeping flag")
	TEST_UTILS.expect_equal(varnak.collision_layer, original_layer, failures, "Reactivated varnak should restore its collision layer")
	TEST_UTILS.expect_equal(varnak.collision_mask, original_mask, failures, "Reactivated varnak should restore its collision mask")
	TEST_UTILS.expect_equal(varnak.is_physics_processing(), true, failures, "Reactivated varnak should resume physics")
	TEST_UTILS.expect_equal(varnak.is_processing(), true, failures, "Reactivated varnak should resume frame processing")
	varnak.queue_free()


func _test_varnak_returns_to_wandering_after_eating(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var world := _ensure_world()
	var meat := _spawn_meat(world, Vector2(20.0, 0.0))
	varnak.hunger = 0.65
	varnak.energy = 1.0
	varnak.global_position = Vector2.ZERO
	_set_player(varnak, Vector2(2000.0, 0.0))
	varnak.meat_target = meat
	varnak.state = varnak.State.EAT_MEAT
	varnak.call("_update_state")
	TEST_UTILS.expect_equal(varnak.state, varnak.State.WANDER, failures, "Varnak should return to wandering after eating")
	meat.queue_free()
	varnak.queue_free()


func _test_varnak_takes_damage(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var before_health: float = varnak.health
	varnak.take_damage(10.0, "player")
	TEST_UTILS.expect(varnak.health < before_health, failures, "Damage should reduce varnak health")
	TEST_UTILS.expect_equal(varnak.state, varnak.State.CHASE, failures, "Surviving damage should switch to chase")
	varnak.queue_free()


func _test_varnak_dies_at_zero_health(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	varnak.take_damage(999.0, "player")
	TEST_UTILS.expect(varnak.is_dead, failures, "Fatal damage should mark the varnak as dead")
	varnak.queue_free()


func _test_varnak_drops_meat_on_death(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var world := _ensure_world()
	world.spawned_meat_amount = 0
	varnak.take_damage(999.0, "player")
	TEST_UTILS.expect(world.spawned_meat_amount > 0, failures, "Dead varnak should spawn meat")
	varnak.queue_free()


func _test_varnak_drops_bone_on_death(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var world := _ensure_world()
	world.spawned_bone_amount = 0
	varnak.take_damage(999.0, "player")
	TEST_UTILS.expect(world.spawned_bone_amount > 0, failures, "Dead varnak should spawn a bone drop")
	varnak.queue_free()


func _test_varnak_does_not_duplicate_meat_drop_on_repeated_death(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	var world := _ensure_world()
	world.spawned_meat_amount = 0
	varnak.take_damage(999.0, "player")
	varnak.take_damage(999.0, "player")
	TEST_UTILS.expect_equal(world.spawned_meat_amount, 1, failures, "Varnak death should drop meat only once")
	varnak.queue_free()


func _test_varnak_removed_from_ecosystem_after_death(failures: Array[String]) -> void:
	var varnak := _make_varnak()
	varnak.take_damage(999.0, "player")
	TEST_UTILS.expect(varnak.is_queued_for_deletion(), failures, "Dead varnak should be queued for removal")
	varnak.queue_free()


func _test_varnak_protects_critical_prey_populations(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var current_scene := tree.current_scene
	var existing_director := current_scene.get_node_or_null("EcosystemDirector")
	if existing_director:
		existing_director.name = "LiveEcosystemDirector"
	var director := TestEcosystemDirector.new()
	director.name = "EcosystemDirector"
	director.state = {
		"small_prey_population": 5.0,
		"grazer_population": 14.0
	}
	current_scene.add_child(director)
	var varnak := _make_varnak()
	var world := _ensure_world()
	varnak.global_position = Vector2.ZERO
	var small_prey := _spawn_target(world, "small_prey", Vector2(30.0, 0.0))
	var grazer := _spawn_target(world, "grazer", Vector2(60.0, 0.0))
	var target := varnak.call("_find_ecosystem_target") as Node2D
	TEST_UTILS.expect(target == grazer, failures, "Varnak should skip SmallPrey below the configured minimum")
	varnak.ecosystem_target = small_prey
	varnak.ecosystem_target_kind = "small_prey"
	varnak.state = varnak.State.HUNT_ECOSYSTEM
	varnak.call("_hunt_ecosystem_target")
	TEST_UTILS.expect(varnak.ecosystem_target == null, failures, "Varnak should release a locked target when its population becomes critical")
	TEST_UTILS.expect_equal(varnak.decision_reason, "critical_prey_population_protected", failures, "Released critical prey should expose the protection reason")
	director.state["small_prey_population"] = 12.0
	target = varnak.call("_find_ecosystem_target") as Node2D
	TEST_UTILS.expect(target == small_prey, failures, "Varnak should hunt SmallPrey again after recovery reaches the minimum")
	varnak.queue_free()
	director.queue_free()
	if existing_director:
		existing_director.name = "EcosystemDirector"


func _make_varnak() -> Node:
	var varnak := VARNAK_SCENE.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.current_scene.add_child(varnak)
	return varnak


func _ensure_world() -> TestWorld:
	var tree := Engine.get_main_loop() as SceneTree
	var current_scene: Node = tree.current_scene
	var existing_world: Node = current_scene.get_node_or_null("World")
	if existing_world and not (existing_world is TestWorld):
		existing_world.name = "LiveWorld"
	var world: TestWorld = current_scene.get_node_or_null("World") as TestWorld
	if world:
		world.cached_groups.clear()
		world.spawned_meat_amount = 0
		world.spawned_bone_amount = 0
		return world
	var new_world := TestWorld.new()
	new_world.name = "World"
	current_scene.add_child(new_world)
	return new_world


func _spawn_target(world: TestWorld, group_name: String, position: Vector2) -> TestTarget:
	var target := TestTarget.new()
	target.add_to_group(group_name)
	world.add_child(target)
	target.position = position
	world.register_cached_group_node(group_name, target)
	return target


func _spawn_meat(world: TestWorld, position: Vector2) -> Node:
	var resource := RESOURCE_NODE_SCENE.instantiate()
	world.add_child(resource)
	resource.position = position
	resource.call("setup", "meat_drop")
	world.register_cached_group_node("meat_drops", resource)
	return resource


func _make_player(position: Vector2) -> TestPlayer:
	var player := TestPlayer.new()
	player.global_position = position
	return player


func _set_player(varnak: Node, position: Vector2) -> void:
	varnak.player = _make_player(position)


func _read_profile() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(VARNAK_PROFILE_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		return Dictionary(parsed)
	return {}


func _get_world_rect() -> Rect2:
	return WORLD_CONFIG.WORLD_RECT.grow(-32.0)
