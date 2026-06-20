extends Node

const DOMAIN_EVENT := preload("res://scripts/core/events/domain_event.gd")
const DOMAIN_EVENT_BUS := preload("res://scripts/core/events/domain_event_bus.gd")
const GAMEPLAY_EVENTS := preload("res://scripts/core/events/gameplay_events.gd")

signal game_event(event_name: String, payload: Dictionary)
signal message_posted(message: String)
signal domain_event_emitted(event: DomainEvent)

var domain_event_bus: DomainEventBus = DOMAIN_EVENT_BUS.new()


func emit_game_event(event_name: String, payload: Dictionary = {}) -> void:
	var safe_payload := payload.duplicate(true)
	var domain_event := GAMEPLAY_EVENTS.from_game_event(event_name, safe_payload)
	domain_event_bus.emit(domain_event)
	domain_event_emitted.emit(domain_event)
	game_event.emit(event_name, safe_payload)


func emit_domain_event(event_value: Variant) -> DomainEvent:
	var domain_event := domain_event_bus.emit(event_value)
	if domain_event == null:
		return null
	domain_event_emitted.emit(domain_event)
	game_event.emit(domain_event.event_type, domain_event.payload.duplicate(true))
	return domain_event


func post_message(message: String) -> void:
	var domain_event := GAMEPLAY_EVENTS.debug_message(message)
	domain_event_bus.emit(domain_event)
	domain_event_emitted.emit(domain_event)
	message_posted.emit(message)


func subscribe_domain_event(event_type: String, callback: Callable) -> void:
	domain_event_bus.subscribe(event_type, callback)


func subscribe_all_domain_events(callback: Callable) -> void:
	domain_event_bus.subscribe_all(callback)


func get_domain_event_history() -> Array[DomainEvent]:
	return domain_event_bus.get_history()


func drain_domain_event_history() -> Array[DomainEvent]:
	return domain_event_bus.drain_history()
