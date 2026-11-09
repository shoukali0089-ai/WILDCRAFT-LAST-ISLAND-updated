extends Node3D

@export var display_name := "Resource"
@export var resource_id := ""
@export var gathered_items: Dictionary = {&"wood": 1}
@export var gathers_left := 3
@export var max_gathers := 3


func gather() -> Dictionary:
	if gathers_left <= 0:
		return {}
	gathers_left -= 1
	var result := gathered_items.duplicate()
	if gathers_left == 0:
		hide()
	return result
