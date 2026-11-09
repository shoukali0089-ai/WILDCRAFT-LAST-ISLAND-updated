extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const JOYSTICK_SCRIPT := preload("res://scripts/virtual_joystick.gd")
const TOUCH_LOOK_SCRIPT := preload("res://scripts/touch_look.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node3D = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame

	var player: CharacterBody3D = game.get("player")
	assert(player != null, "The main scene should spawn the player.")
	var hud_root: Control = game.get_node("HUD").get_child(0)
	var joystick: Control
	var look_area: Control
	for control in hud_root.get_children():
		if control.get_script() == JOYSTICK_SCRIPT:
			joystick = control
		elif control.get_script() == TOUCH_LOOK_SCRIPT:
			look_area = control
	assert(joystick != null and look_area != null, "The mobile movement and look controls should exist.")

	var start_position := player.global_position
	var joystick_center := joystick.get_global_rect().get_center()
	var joystick_press := InputEventScreenTouch.new()
	joystick_press.index = 3
	joystick_press.pressed = true
	joystick_press.position = joystick_center
	joystick.call("_gui_input", joystick_press)
	var joystick_drag := InputEventScreenDrag.new()
	joystick_drag.index = 3
	joystick_drag.position = joystick_center + Vector2(0.0, -45.0)
	joystick_drag.relative = Vector2(0.0, -45.0)
	joystick.call("_gui_input", joystick_drag)
	assert(player.get("joystick_input").y < -0.5, "Dragging the joystick upward should request forward movement.")
	for frame_index in range(12):
		await physics_frame
	var horizontal_distance := Vector2(
		player.global_position.x - start_position.x,
		player.global_position.z - start_position.z
	).length()
	assert(horizontal_distance > 0.1, "The player should move horizontally.")
	var joystick_release := InputEventScreenTouch.new()
	joystick_release.index = 3
	joystick_release.position = joystick_drag.position
	joystick_release.pressed = false
	joystick.call("_gui_input", joystick_release)

	var rotation_before_look := player.rotation.y
	var look_center := look_area.get_global_rect().get_center()
	var look_press := InputEventScreenTouch.new()
	look_press.index = 4
	look_press.pressed = true
	look_press.position = look_center
	look_area.call("_gui_input", look_press)
	var look_drag := InputEventScreenDrag.new()
	look_drag.index = 4
	look_drag.position = look_center + Vector2(24.0, 0.0)
	look_drag.relative = Vector2(24.0, 0.0)
	look_area.call("_gui_input", look_drag)
	assert(player.rotation.y != rotation_before_look, "Dragging the touch-look area should rotate the player.")
	var look_release := InputEventScreenTouch.new()
	look_release.index = 4
	look_release.position = look_drag.position
	look_release.pressed = false
	look_area.call("_gui_input", look_release)

	var palm: Node3D
	for child in game.get_children():
		if child.has_method("gather") and child.get("display_name") == "Palm tree":
			palm = child
			break
	assert(palm != null, "The island should contain a gatherable palm.")
	game.set("nearby_resource", palm)
	game.call("_gather_nearby")
	var inventory: Dictionary = game.get("inventory")
	assert(inventory["wood"] == 1 and inventory["fiber"] == 1, "Gathering a palm should add wood and fiber.")
	assert(palm.get("gathers_left") == 2, "Gathering should consume one resource use.")

	var hunger_before: float = game.get("hunger")
	game.call("_update_survival", 10.0)
	assert(game.get("hunger") < hunger_before, "Hunger should decrease over time.")
	game.call("_update_day_cycle")
	assert(not String(game.get("time_label").text).is_empty(), "The day/night clock should update.")

	print("Prototype smoke tests passed.")
	quit()
