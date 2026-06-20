extends RefCounted
class_name ResourceHarvestResult

var success := false
var message := ""
var item_id := ""
var requested_amount := 0
var added_amount := 0
var leftover_amount := 0
var should_remove_node := false
var should_start_regrowth := false
var emitted_event_name := ""
var emitted_event_payload: Dictionary = {}
