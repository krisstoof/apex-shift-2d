extends RefCounted
class_name PlayerStats

var health := 100.0
var hunger := 100.0
var stamina := 100.0

func tick(delta: float, running: bool) -> void:
	hunger = max(hunger - 0.9 * delta, 0.0)
	if running:
		stamina = max(stamina - 18.0 * delta, 0.0)
	else:
		stamina = min(stamina + 16.0 * delta, 100.0)
	if hunger <= 0.0:
		health = max(health - 3.0 * delta, 0.0)


func spend_stamina(amount: float) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	return true


func damage(amount: float) -> void:
	health = max(health - amount, 0.0)
