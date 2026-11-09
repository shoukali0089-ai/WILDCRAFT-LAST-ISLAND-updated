extends CharacterBody3D

@export var move_speed := 5.0
@export var look_sensitivity := 0.003
@export var look_pitch_min := -0.75
@export var look_pitch_max := 0.45

@onready var camera_pivot: Node3D = $CameraPivot

var joystick_input := Vector2.ZERO


func _ready() -> void:
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
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


func set_move_input(value: Vector2) -> void:
	joystick_input = value


func add_look_input(delta: Vector2) -> void:
	rotation.y -= delta.x * look_sensitivity
	camera_pivot.rotation.x = clampf(
		camera_pivot.rotation.x - delta.y * look_sensitivity,
		look_pitch_min,
		look_pitch_max
	)
