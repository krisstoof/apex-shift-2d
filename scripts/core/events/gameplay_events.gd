extends RefCounted
class_name GameplayEvents

const DOMAIN_EVENT := preload("res://scripts/core/events/domain_event.gd")

const RESOURCE_HARVESTED := "ResourceHarvested"
const RESOURCE_DEPLETED := "ResourceDepleted"
const CREATURE_SPAWNED := "CreatureSpawned"
const CREATURE_DIED := "CreatureDied"
const MEAT_DROPPED := "MeatDropped"
const BUILDING_PLACED := "BuildingPlaced"
const CAMPFIRE_LIT := "CampfireLit"
const TRAP_TRIGGERED := "TrapTriggered"
const DAY_CHANGED := "DayChanged"
const BIOME_BIOMASS_CHANGED := "BiomeBiomassChanged"
const INVENTORY_CHANGED := "InventoryChanged"
const CRAFTING_COMPLETED := "CraftingCompleted"
const DEBUG_MESSAGE := "DebugMessage"


static func make(event_type: String, payload: Dictionary = {}, source: String = "gameplay") -> DomainEvent:
	return DOMAIN_EVENT.new_with(event_type, payload, source)


static func resource_harvested(resource_kind: String, position: Vector2 = Vector2.ZERO, amount: int = 1, payload: Dictionary = {}) -> DomainEvent:
	var data := payload.duplicate(true)
	data["resource_kind"] = resource_kind
	data["position"] = position
	data["amount"] = amount
	return make(RESOURCE_HARVESTED, data)


static func resource_depleted(resource_kind: String, position: Vector2 = Vector2.ZERO, payload: Dictionary = {}) -> DomainEvent:
	var data := payload.duplicate(true)
	data["resource_kind"] = resource_kind
	data["position"] = position
	return make(RESOURCE_DEPLETED, data)


static func creature_spawned(creature_kind: String, position: Vector2 = Vector2.ZERO, payload: Dictionary = {}) -> DomainEvent:
	var data := payload.duplicate(true)
	data["creature_kind"] = creature_kind
	data["position"] = position
	return make(CREATURE_SPAWNED, data)


static func creature_died(creature_kind: String, reason: String = "", position: Vector2 = Vector2.ZERO, payload: Dictionary = {}) -> DomainEvent:
	var data := payload.duplicate(true)
	data["creature_kind"] = creature_kind
	data["reason"] = reason
	data["position"] = position
	return make(CREATURE_DIED, data)


static func meat_dropped(animal_kind: String, position: Vector2 = Vector2.ZERO, amount: int = 1, payload: Dictionary = {}) -> DomainEvent:
	var data := payload.duplicate(true)
	data["animal_kind"] = animal_kind
	data["position"] = position
	data["amount"] = amount
	return make(MEAT_DROPPED, data)


static func building_placed(building_kind: String, position: Vector2 = Vector2.ZERO, payload: Dictionary = {}) -> DomainEvent:
	var data := payload.duplicate(true)
	data["building_kind"] = building_kind
	data["position"] = position
	return make(BUILDING_PLACED, data)


static func campfire_lit(position: Vector2 = Vector2.ZERO, payload: Dictionary = {}) -> DomainEvent:
	var data := payload.duplicate(true)
	data["position"] = position
	return make(CAMPFIRE_LIT, data)


static func trap_triggered(trap_kind: String = "trap", position: Vector2 = Vector2.ZERO, payload: Dictionary = {}) -> DomainEvent:
	var data := payload.duplicate(true)
	data["trap_kind"] = trap_kind
	data["position"] = position
	return make(TRAP_TRIGGERED, data)


static func day_changed(day: int, reason: String = "", payload: Dictionary = {}) -> DomainEvent:
	var data := payload.duplicate(true)
	data["day"] = day
	data["reason"] = reason
	return make(DAY_CHANGED, data)


static func biome_biomass_changed(biome_id: String, biomass_percent: float, payload: Dictionary = {}) -> DomainEvent:
	var data := payload.duplicate(true)
	data["biome_id"] = biome_id
	data["biomass_percent"] = biomass_percent
	return make(BIOME_BIOMASS_CHANGED, data)


static func inventory_changed(item_kind: String = "", delta: int = 0, payload: Dictionary = {}) -> DomainEvent:
	var data := payload.duplicate(true)
	data["item_kind"] = item_kind
	data["delta"] = delta
	return make(INVENTORY_CHANGED, data)


static func crafting_completed(recipe_id: String, payload: Dictionary = {}) -> DomainEvent:
	var data := payload.duplicate(true)
	data["recipe_id"] = recipe_id
	return make(CRAFTING_COMPLETED, data)


static func debug_message(message: String, payload: Dictionary = {}) -> DomainEvent:
	var data := payload.duplicate(true)
	data["message"] = message
	return make(DEBUG_MESSAGE, data, "debug")


static func from_game_event(event_name: String, payload: Dictionary = {}) -> DomainEvent:
	match event_name:
		"plant_resource_harvested", "resource_harvested":
			return resource_harvested(
				str(payload.get("resource_kind", payload.get("resource_type", ""))),
				Vector2(payload.get("position", Vector2.ZERO)),
				int(payload.get("amount", payload.get("loot_amount", 1))),
				payload
			)
		"resource_depleted":
			return resource_depleted(
				str(payload.get("resource_kind", payload.get("resource_type", ""))),
				Vector2(payload.get("position", Vector2.ZERO)),
				payload
			)
		"creature_spawned", "small_prey_spawned", "grazer_spawned", "varnak_spawned":
			return creature_spawned(
				str(payload.get("creature_kind", payload.get("animal_kind", event_name.replace("_spawned", "")))),
				Vector2(payload.get("position", Vector2.ZERO)),
				payload
			)
		"creature_died", "small_prey_killed_by_player", "small_prey_killed_by_varnak", "small_prey_killed_by_grazer", "grazer_killed_by_player", "grazer_killed_by_varnak", "varnak_killed_by_player", "varnak_killed_by_trap":
			return creature_died(
				str(payload.get("creature_kind", payload.get("animal_kind", _infer_creature_kind(event_name)))),
				str(payload.get("reason", event_name)),
				Vector2(payload.get("position", Vector2.ZERO)),
				payload
			)
		"animal_dropped_meat", "meat_dropped":
			return meat_dropped(
				str(payload.get("animal_kind", "")),
				Vector2(payload.get("position", Vector2.ZERO)),
				int(payload.get("amount", 1)),
				payload
			)
		"building_placed":
			return building_placed(str(payload.get("building_kind", payload.get("kind", ""))), Vector2(payload.get("position", Vector2.ZERO)), payload)
		"campfire_lit":
			return campfire_lit(Vector2(payload.get("position", Vector2.ZERO)), payload)
		"trap_triggered":
			return trap_triggered(str(payload.get("trap_kind", "trap")), Vector2(payload.get("position", Vector2.ZERO)), payload)
		"day_ended", "day_changed":
			return day_changed(int(payload.get("day", 1)), str(payload.get("reason", event_name)), payload)
		"ecosystem_vegetation_changed", "ecosystem_delta_applied", "ecosystem_biome_stressed", "ecosystem_biome_depleted", "ecosystem_biome_collapsing":
			return biome_biomass_changed(str(payload.get("biome_id", "")), float(payload.get("plant_biomass_percent", payload.get("biomass_percent", 0.0))), payload)
		"inventory_changed":
			return inventory_changed(str(payload.get("item_kind", payload.get("item", ""))), int(payload.get("delta", 0)), payload)
		"crafting_completed":
			return crafting_completed(str(payload.get("recipe_id", payload.get("recipe", ""))), payload)
	return make(event_name, payload, "godot_event_bus")


static func _infer_creature_kind(event_name: String) -> String:
	if event_name.begins_with("small_prey"):
		return "small_prey"
	if event_name.begins_with("grazer"):
		return "grazer"
	if event_name.begins_with("varnak"):
		return "varnak"
	return "creature"
