extends RefCounted
class_name DomainEvent

var event_type := ""
var payload: Dictionary = {}
var source := ""
var occurred_at_msec := 0


func _init(p_event_type: String = "", p_payload: Dictionary = {}, p_source: String = "core") -> void:
	event_type = p_event_type
	payload = p_payload.duplicate(true)
	source = p_source
	occurred_at_msec = Time.get_ticks_msec()


static func new_with(p_event_type: String, p_payload: Dictionary = {}, p_source: String = "core") -> DomainEvent:
	return DomainEvent.new(p_event_type, p_payload, p_source)


static func from_dictionary(data: Dictionary) -> DomainEvent:
	var event := DomainEvent.new(
		str(data.get("event_type", data.get("type", ""))),
		Dictionary(data.get("payload", {})),
		str(data.get("source", "core"))
	)
	event.occurred_at_msec = int(data.get("occurred_at_msec", event.occurred_at_msec))
	return event


func duplicate_event() -> DomainEvent:
	var event := DomainEvent.new(event_type, payload, source)
	event.occurred_at_msec = occurred_at_msec
	return event


func to_dictionary() -> Dictionary:
	return {
		"event_type": event_type,
		"payload": payload.duplicate(true),
		"source": source,
		"occurred_at_msec": occurred_at_msec
	}


func is_type(expected_type: String) -> bool:
	return event_type == expected_type


func with_payload(extra_payload: Dictionary) -> DomainEvent:
	var merged := payload.duplicate(true)
	for key in extra_payload.keys():
		merged[key] = extra_payload[key]
	return DomainEvent.new_with(event_type, merged, source)
