extends RefCounted
class_name DomainEventBus

const DOMAIN_EVENT := preload("res://scripts/core/events/domain_event.gd")

const ANY_EVENT := "*"

var max_history_size := 128
var _subscribers_by_type: Dictionary = {}
var _history: Array[DomainEvent] = []


func emit(event_value: Variant) -> DomainEvent:
	var event := _normalize_event(event_value)
	if event == null or event.event_type.is_empty():
		return null
	_history.append(event.duplicate_event())
	while _history.size() > max_history_size:
		_history.pop_front()
	_notify_subscribers(ANY_EVENT, event)
	_notify_subscribers(event.event_type, event)
	return event


func subscribe(event_type: String, callback: Callable) -> void:
	if event_type.is_empty() or not callback.is_valid():
		return
	var callbacks: Array = Array(_subscribers_by_type.get(event_type, []))
	for existing in callbacks:
		if existing == callback:
			return
	callbacks.append(callback)
	_subscribers_by_type[event_type] = callbacks


func subscribe_all(callback: Callable) -> void:
	subscribe(ANY_EVENT, callback)


func unsubscribe(event_type: String, callback: Callable) -> void:
	if event_type.is_empty() or not _subscribers_by_type.has(event_type):
		return
	var callbacks: Array = Array(_subscribers_by_type.get(event_type, []))
	var filtered: Array = []
	for existing in callbacks:
		if existing != callback:
			filtered.append(existing)
	if filtered.is_empty():
		_subscribers_by_type.erase(event_type)
	else:
		_subscribers_by_type[event_type] = filtered


func get_history() -> Array[DomainEvent]:
	var copy: Array[DomainEvent] = []
	for event in _history:
		copy.append(event.duplicate_event())
	return copy


func get_events_by_type(event_type: String) -> Array[DomainEvent]:
	var matching: Array[DomainEvent] = []
	for event in _history:
		if event.event_type == event_type:
			matching.append(event.duplicate_event())
	return matching


func drain_history() -> Array[DomainEvent]:
	var drained := get_history()
	_history.clear()
	return drained


func clear() -> void:
	_history.clear()
	_subscribers_by_type.clear()


func _normalize_event(event_value: Variant) -> DomainEvent:
	if event_value is DomainEvent:
		return (event_value as DomainEvent).duplicate_event()
	if typeof(event_value) == TYPE_DICTIONARY:
		return DOMAIN_EVENT.from_dictionary(Dictionary(event_value))
	return null


func _notify_subscribers(event_type: String, event: DomainEvent) -> void:
	var callbacks: Array = Array(_subscribers_by_type.get(event_type, []))
	for callback_value in callbacks:
		var callback: Callable = callback_value
		if callback.is_valid():
			callback.call(event.duplicate_event())
