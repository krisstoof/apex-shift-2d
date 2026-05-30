extends Node

signal game_event(event_name: String, payload: Dictionary)
signal message_posted(message: String)

func emit_game_event(event_name: String, payload: Dictionary = {}) -> void:
	print("[EventBus] %s %s" % [event_name, payload])
	game_event.emit(event_name, payload)


func post_message(message: String) -> void:
	print("[Message] %s" % message)
	message_posted.emit(message)
