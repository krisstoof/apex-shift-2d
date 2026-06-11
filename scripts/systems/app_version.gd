extends Node

const VERSION := "0.1.2"
const VERSION_NAME := "v0.1.2"
const APP_NAME := "Apex Shift 2D"


static func get_version() -> String:
	return VERSION


static func get_version_name() -> String:
	return VERSION_NAME


static func get_display_name() -> String:
	return "%s %s" % [APP_NAME, VERSION_NAME]
