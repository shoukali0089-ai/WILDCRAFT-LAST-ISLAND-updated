extends Node3D

@export var display_name := "Resource"
@export var gathered_items: Dictionary = {&"wood": 1}
@export var gathers_left := 3


func gather() -> Dictionary:
	if gathers_left <= 0:
		return {}
	gathers_left -= 1
	var result := gathered_items.duplicate()
	if gathers_left == 0:
		queue_free()
	return result
