extends Node

signal game_event(event_name: String, payload: Dictionary)
signal message_posted(message: String)


func emit_game_event(event_name: String, payload: Dictionary = {}) -> void:
	game_event.emit(event_name, payload)


func post_message(message: String) -> void:
	message_posted.emit(message)
