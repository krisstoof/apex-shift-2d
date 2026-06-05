extends RefCounted
class_name EcosystemDelta

var biome_id := ""
var biomass_percent_before := 0.0
var biomass_percent_after := 0.0
var status_changed := false
var new_status := ""
var vegetation_target_delta := 0
var payload: Dictionary = {}


static func new_with(
	p_biome_id: String,
	p_biomass_before: float,
	p_biomass_after: float,
	p_status_changed: bool,
	p_new_status: String,
	p_vegetation_target_delta: int = 0,
	p_payload: Dictionary = {}
):
	var delta = new()
	delta.biome_id = p_biome_id
	delta.biomass_percent_before = p_biomass_before
	delta.biomass_percent_after = p_biomass_after
	delta.status_changed = p_status_changed
	delta.new_status = p_new_status
	delta.vegetation_target_delta = p_vegetation_target_delta
	delta.payload = Dictionary(p_payload).duplicate(true)
	return delta


func to_dict() -> Dictionary:
	return {
		"biome_id": biome_id,
		"biomass_percent_before": biomass_percent_before,
		"biomass_percent_after": biomass_percent_after,
		"status_changed": status_changed,
		"new_status": new_status,
		"vegetation_target_delta": vegetation_target_delta,
		"payload": payload.duplicate(true)
	}
