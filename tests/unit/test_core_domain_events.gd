extends RefCounted

const DOMAIN_EVENT := preload("res://scripts/core/events/domain_event.gd")
const DOMAIN_EVENT_BUS := preload("res://scripts/core/events/domain_event_bus.gd")
const GAMEPLAY_EVENTS := preload("res://scripts/core/events/gameplay_events.gd")
const GODOT_EVENT_BUS := preload("res://scripts/systems/event_bus.gd")
const TEST_UTILS := preload("res://tests/unit/test_utils.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_domain_event_round_trips_as_dictionary(failures)
	_test_domain_event_bus_emits_to_subscribers_and_history(failures)
	_test_gameplay_event_factories_create_explicit_domain_events(failures)
	_test_godot_event_bus_bridges_legacy_events_to_domain_events(failures)
	_test_godot_event_bus_accepts_domain_events_directly(failures)
	return failures


func _test_domain_event_round_trips_as_dictionary(failures: Array[String]) -> void:
	var event := DOMAIN_EVENT.new_with("ResourceHarvested", {"resource_kind": "wood", "amount": 2}, "unit_test")
	var restored := DOMAIN_EVENT.from_dictionary(event.to_dictionary())
	TEST_UTILS.expect_equal(restored.event_type, "ResourceHarvested", failures, "DomainEvent should preserve event type")
	TEST_UTILS.expect_equal(str(restored.payload.get("resource_kind", "")), "wood", failures, "DomainEvent should preserve payload")
	TEST_UTILS.expect_equal(int(restored.payload.get("amount", 0)), 2, failures, "DomainEvent should preserve numeric payload")
	TEST_UTILS.expect_equal(restored.source, "unit_test", failures, "DomainEvent should preserve source")


func _test_domain_event_bus_emits_to_subscribers_and_history(failures: Array[String]) -> void:
	var bus := DOMAIN_EVENT_BUS.new()
	var received: Array[String] = []
	bus.subscribe("CreatureDied", func(event: DomainEvent):
		received.append(str(event.payload.get("creature_kind", "")))
	)
	bus.emit(GAMEPLAY_EVENTS.creature_died("varnak", "unit_test"))
	TEST_UTILS.expect_equal(received.size(), 1, failures, "DomainEventBus should notify typed subscribers")
	if received.size() == 1:
		TEST_UTILS.expect_equal(received[0], "varnak", failures, "DomainEventBus should pass event payload to subscribers")
	var history := bus.get_history()
	TEST_UTILS.expect_equal(history.size(), 1, failures, "DomainEventBus should keep emitted events in history")
	if history.size() == 1:
		TEST_UTILS.expect_equal(history[0].event_type, "CreatureDied", failures, "DomainEventBus history should preserve event type")


func _test_gameplay_event_factories_create_explicit_domain_events(failures: Array[String]) -> void:
	var harvested := GAMEPLAY_EVENTS.resource_harvested("berry_bush", Vector2(3, 4), 1)
	TEST_UTILS.expect_equal(harvested.event_type, GAMEPLAY_EVENTS.RESOURCE_HARVESTED, failures, "GameplayEvents should expose ResourceHarvested")
	TEST_UTILS.expect_equal(str(harvested.payload.get("resource_kind", "")), "berry_bush", failures, "ResourceHarvested should include resource kind")
	var day_changed := GAMEPLAY_EVENTS.day_changed(3, "debug_next_day")
	TEST_UTILS.expect_equal(day_changed.event_type, GAMEPLAY_EVENTS.DAY_CHANGED, failures, "GameplayEvents should expose DayChanged")
	TEST_UTILS.expect_equal(int(day_changed.payload.get("day", 0)), 3, failures, "DayChanged should include the day")
	var mapped := GAMEPLAY_EVENTS.from_game_event("animal_dropped_meat", {"animal_kind": "grazer", "amount": 2})
	TEST_UTILS.expect_equal(mapped.event_type, GAMEPLAY_EVENTS.MEAT_DROPPED, failures, "GameplayEvents should map legacy meat events to MeatDropped")


func _test_godot_event_bus_bridges_legacy_events_to_domain_events(failures: Array[String]) -> void:
	var event_bus := GODOT_EVENT_BUS.new()
	var legacy_events: Array[Dictionary] = []
	var domain_events: Array[String] = []
	event_bus.game_event.connect(func(event_name: String, payload: Dictionary):
		legacy_events.append({"name": event_name, "payload": payload.duplicate(true)})
	)
	event_bus.domain_event_emitted.connect(func(event: DomainEvent):
		domain_events.append(event.event_type)
	)
	event_bus.emit_game_event("day_ended", {"day": 5, "reason": "unit_test"})
	TEST_UTILS.expect_equal(legacy_events.size(), 1, failures, "Godot EventBus should keep legacy game_event signal")
	if legacy_events.size() == 1:
		TEST_UTILS.expect_equal(str(legacy_events[0].get("name", "")), "day_ended", failures, "Godot EventBus should preserve legacy event name")
	TEST_UTILS.expect_equal(domain_events.size(), 1, failures, "Godot EventBus should emit a domain event")
	if domain_events.size() == 1:
		TEST_UTILS.expect_equal(domain_events[0], GAMEPLAY_EVENTS.DAY_CHANGED, failures, "Godot EventBus should map day_ended to DayChanged")
	var history := event_bus.get_domain_event_history()
	TEST_UTILS.expect_equal(history.size(), 1, failures, "Godot EventBus should expose core domain event history")


func _test_godot_event_bus_accepts_domain_events_directly(failures: Array[String]) -> void:
	var event_bus := GODOT_EVENT_BUS.new()
	var legacy_names: Array[String] = []
	event_bus.game_event.connect(func(event_name: String, _payload: Dictionary):
		legacy_names.append(event_name)
	)
	var emitted := event_bus.emit_domain_event(GAMEPLAY_EVENTS.inventory_changed("wood", 1))
	TEST_UTILS.expect(emitted != null, failures, "Godot EventBus should accept direct domain events")
	TEST_UTILS.expect_equal(legacy_names.size(), 1, failures, "Direct domain events should bridge to game_event signal for legacy listeners")
	if legacy_names.size() == 1:
		TEST_UTILS.expect_equal(legacy_names[0], GAMEPLAY_EVENTS.INVENTORY_CHANGED, failures, "Direct domain event bridge should use domain event type")
