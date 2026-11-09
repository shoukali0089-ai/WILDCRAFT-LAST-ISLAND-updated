extends CharacterBody3D

@export var move_speed := 5.0
@export var look_sensitivity := 0.003
@export var look_pitch_min := -0.75
@export var look_pitch_max := 0.45

@onready var camera_pivot: Node3D = $CameraPivot

var joystick_input := Vector2.ZERO
var audio_manager: Node
var footstep_elapsed := 0.0
var was_on_floor := false
var fall_started := false
var last_breath_msec := 0


func _ready() -> void:
	audio_manager = get_tree().get_first_node_in_group("audio_manager")
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	was_on_floor = is_on_floor()
	var axis := joystick_input
	if axis.length() < 0.1:
		axis = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	var direction := Vector3(axis.x, 0.0, axis.y).rotated(Vector3.UP, rotation.y)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()
	_update_movement_audio(delta)


func set_move_input(value: Vector2) -> void:
	joystick_input = value


func add_look_input(delta: Vector2) -> void:
	rotation.y -= delta.x * look_sensitivity
	camera_pivot.rotation.x = clampf(
		camera_pivot.rotation.x - delta.y * look_sensitivity,
		look_pitch_min,
		look_pitch_max
	)


func _update_movement_audio(delta: float) -> void:
	if not is_instance_valid(audio_manager):
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var grounded := is_on_floor()
	if not grounded and velocity.y < -1.0:
		fall_started = true
	if grounded and fall_started and not was_on_floor:
		audio_manager.play_event("land", global_position, 180)
		fall_started = false
	if grounded and horizontal_speed > 0.65:
		var run_ratio := clampf(horizontal_speed / maxf(move_speed, 0.1), 0.0, 1.0)
		var stride_interval := lerpf(0.68, 0.42, run_ratio)
		footstep_elapsed += delta
		if footstep_elapsed >= stride_interval:
			footstep_elapsed = 0.0
			audio_manager.play_event(_get_footstep_sound(), global_position, 110)
		if run_ratio > 0.75 and Time.get_ticks_msec() - last_breath_msec > 16000:
			audio_manager.play_event("exertion", global_position, 1000)
			last_breath_msec = Time.get_ticks_msec()
	else:
		footstep_elapsed = 0.0


func _get_footstep_sound() -> String:
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.12,
		global_position - Vector3.UP * 0.65,
		1,
		[get_rid()]
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return "footstep_grass"
	var collider: Object = hit["collider"]
	if collider is Node and collider.is_in_group("wooden_structure"):
		return "footstep_wood"
	if collider is Node and collider.is_in_group("rock_surface"):
		return "footstep_rock"
	var island_radius := Vector2(global_position.x, global_position.z).length()
	return "footstep_sand" if island_radius > 39.0 else "footstep_grass"
