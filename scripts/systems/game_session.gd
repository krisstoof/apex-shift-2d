extends Node

const SAVE_PATH := "user://savegame.json"

var load_save_requested := false


func request_new_game() -> void:
	load_save_requested = false


func request_continue() -> void:
	load_save_requested = true


func consume_load_save_request() -> bool:
	var requested := load_save_requested
	load_save_requested = false
	return requested


func has_save_game() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
