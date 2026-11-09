extends CharacterBody3D

signal state_changed(animal: CharacterBody3D, state_name: String)

enum AnimalState { IDLE, WANDER, ALERT, FLEE, DEFEND, RETURN }

const DEER_DETECT_DISTANCE := 12.0
const DEER_FLEE_DISTANCE := 22.0
const BOAR_ALERT_DISTANCE := 10.0
const BOAR_DEFEND_DISTANCE := 4.0
const BOAR_DISENGAGE_DISTANCE := 13.0
const AI_INTERVAL := 0.25

const DEER_COAT := Color(0.49, 0.30, 0.16)
const DEER_LIGHT := Color(0.77, 0.65, 0.44)
const BOAR_COAT := Color(0.28, 0.20, 0.15)
const BOAR_SNOUT := Color(0.48, 0.31, 0.24)
const LEG_COLOR := Color(0.24, 0.17, 0.12)

@export var animal_type := "deer"
@export var walk_speed := 1.65
@export var flee_speed := 5.0

var state: AnimalState = AnimalState.IDLE
var player: CharacterBody3D
var home_position := Vector3.ZERO
var avoidance_nodes: Array[Node3D] = []
var island_radius := 48.0
var ai_timer := 0.0
var state_elapsed := 0.0
var state_duration := 1.0
var gait_time := 0.0
var wander_target := Vector3.ZERO
var steering_target := Vector3.ZERO
var move_direction := Vector3.ZERO
var body_visual: Node3D
var tail_visual: Node3D
var leg_pivots: Array[Node3D] = []
var rng := RandomNumberGenerator.new()


func configure(
	type: String,
	actor: CharacterBody3D,
	home: Vector3,
	obstacles: Array[Node3D],
	playable_radius: float
) -> void:
	animal_type = type
	player = actor
	home_position = home
	avoidance_nodes = obstacles
	island_radius = playable_radius
	rng.randomize()
	_build_animal_model()


func _ready() -> void:
	name = "Deer" if animal_type == "deer" else "WildBoar"
	add_to_group("wildlife")
	collision_layer = 4
	collision_mask = 5
	if is_instance_valid(player):
		add_collision_exception_with(player)
		player.add_collision_exception_with(self)
	_set_state(AnimalState.IDLE)
	state_duration = rng.randf_range(1.0, 3.0)


func _physics_process(delta: float) -> void:
	ai_timer += delta
	if ai_timer >= AI_INTERVAL:
		var update_delta := ai_timer
		ai_timer = 0.0
		_update_ai(update_delta)

	var desired_direction := _movement_direction()
	var acceleration := 12.0 if desired_direction.length_squared() > 0.01 else 10.0
	move_direction = move_direction.move_toward(desired_direction, acceleration * delta)
	var speed := walk_speed
	if state == AnimalState.FLEE:
		speed = flee_speed
	elif state == AnimalState.DEFEND:
		speed = walk_speed * 1.8
	velocity.x = move_direction.x * speed
	velocity.z = move_direction.z * speed
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()
	_animate(delta, move_direction)
	_keep_inside_island()


func get_state_name() -> String:
	return AnimalState.keys()[state]


func restore_saved_state(state_name: String) -> bool:
	var state_index := AnimalState.keys().find(state_name)
	if state_index < 0:
		return false
	_set_state(state_index as AnimalState)
	return true


func _update_ai(delta: float) -> void:
	state_elapsed += delta
	var player_distance := INF
	if is_instance_valid(player):
		player_distance = Vector2(
			player.global_position.x - global_position.x,
			player.global_position.z - global_position.z
		).length()

	if animal_type == "deer":
		_update_deer_response(player_distance)
	else:
		_update_boar_response(player_distance)

	match state:
		AnimalState.IDLE:
			if state_elapsed >= state_duration:
				_choose_wander_target()
				_set_state(AnimalState.WANDER)
		AnimalState.WANDER:
			if _horizontal_distance(global_position, wander_target) < 0.8 or state_elapsed >= state_duration:
				_set_state(AnimalState.IDLE)
				state_duration = rng.randf_range(1.0, 3.0)
		AnimalState.ALERT:
			if is_instance_valid(player):
				wander_target = player.global_position
		AnimalState.FLEE:
			_update_flee_target()
		AnimalState.DEFEND:
			_update_defend_target(player_distance)
		AnimalState.RETURN:
			wander_target = home_position
			if _horizontal_distance(global_position, home_position) < 1.0:
				_set_state(AnimalState.IDLE)
				state_duration = rng.randf_range(0.6, 2.0)
	steering_target = wander_target
	if state != AnimalState.IDLE and state != AnimalState.ALERT:
		steering_target = _avoid_obstacles(wander_target)


func _update_deer_response(player_distance: float) -> void:
	if state == AnimalState.FLEE:
		if player_distance > DEER_FLEE_DISTANCE:
			_set_state(AnimalState.RETURN)
		return
	if state == AnimalState.ALERT:
		if player_distance <= DEER_DETECT_DISTANCE and state_elapsed >= 0.35:
			_set_state(AnimalState.FLEE)
		elif player_distance > DEER_DETECT_DISTANCE:
			_set_state(AnimalState.RETURN)
		return
	if player_distance <= DEER_DETECT_DISTANCE:
		_set_state(AnimalState.ALERT)


func _update_boar_response(player_distance: float) -> void:
	if state == AnimalState.DEFEND:
		if player_distance > BOAR_DISENGAGE_DISTANCE:
			_set_state(AnimalState.RETURN)
		return
	if player_distance <= BOAR_DEFEND_DISTANCE:
		_set_state(AnimalState.DEFEND)
	elif player_distance <= BOAR_ALERT_DISTANCE:
		_set_state(AnimalState.ALERT)
	elif state == AnimalState.ALERT or state == AnimalState.RETURN:
		if player_distance > BOAR_DISENGAGE_DISTANCE:
			_set_state(AnimalState.RETURN)
		elif state == AnimalState.ALERT:
			_set_state(AnimalState.RETURN)


func _set_state(next_state: AnimalState) -> void:
	if state == next_state:
		return
	state = next_state
	state_elapsed = 0.0
	match state:
		AnimalState.IDLE:
			velocity.x = 0.0
			velocity.z = 0.0
		AnimalState.WANDER:
			state_duration = rng.randf_range(3.0, 7.0)
		AnimalState.ALERT:
			if is_instance_valid(player):
				wander_target = player.global_position
		AnimalState.FLEE:
			_update_flee_target()
		AnimalState.RETURN:
			wander_target = home_position
	state_changed.emit(self, get_state_name())


func _choose_wander_target() -> void:
	var angle := rng.randf_range(0.0, TAU)
	var distance := rng.randf_range(3.0, 8.0)
	var candidate := home_position + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
	wander_target = _clamp_to_island(candidate)


func _update_flee_target() -> void:
	if not is_instance_valid(player):
		_set_state(AnimalState.RETURN)
		return
	var away := global_position - player.global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.FORWARD.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
	var flee_destination := global_position + away.normalized() * 12.0
	wander_target = _clamp_to_island(flee_destination)


func _update_defend_target(player_distance: float) -> void:
	if not is_instance_valid(player) or player_distance <= 2.3:
		wander_target = global_position
		return
	var toward_player := player.global_position - global_position
	toward_player.y = 0.0
	wander_target = player.global_position - toward_player.normalized() * 2.0


func _movement_direction() -> Vector3:
	if state == AnimalState.IDLE or state == AnimalState.ALERT:
		return Vector3.ZERO
	if state == AnimalState.DEFEND and _horizontal_distance(global_position, wander_target) < 0.45:
		return Vector3.ZERO
	var direction := steering_target - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		return Vector3.ZERO
	direction = direction.normalized()
	var desired_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, minf(5.5 * get_physics_process_delta_time(), 1.0))
	return Vector3.FORWARD.rotated(Vector3.UP, rotation.y)


func _avoid_obstacles(destination: Vector3) -> Vector3:
	var forward := destination - global_position
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		return destination
	forward = forward.normalized()
	var avoidance := Vector3.ZERO
	for obstacle in avoidance_nodes:
		if not is_instance_valid(obstacle) or not obstacle.visible:
			continue
		var offset := global_position - obstacle.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > 3.5 or distance < 0.01 or forward.dot(-offset.normalized()) < 0.15:
			continue
		var side := Vector3(-forward.z, 0.0, forward.x)
		if side.dot(offset) < 0.0:
			side = -side
		avoidance += side * (3.5 - distance) / 3.5
	if avoidance.length_squared() < 0.01:
		return destination
	return global_position + (forward + avoidance.normalized() * 1.5).normalized() * 4.0


func _keep_inside_island() -> void:
	var horizontal := Vector2(global_position.x, global_position.z)
	if horizontal.length() > island_radius - 2.0:
		var inward := -Vector3(global_position.x, 0.0, global_position.z).normalized()
		wander_target = global_position + inward * 8.0


func _clamp_to_island(point: Vector3) -> Vector3:
	var horizontal := Vector2(point.x, point.z)
	var limit := island_radius - 3.0
	if horizontal.length() > limit:
		horizontal = horizontal.normalized() * limit
	return Vector3(horizontal.x, point.y, horizontal.y)


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _animate(delta: float, direction: Vector3) -> void:
	var moving := direction.length_squared() > 0.01 and is_on_floor()
	gait_time += delta * (9.0 if state == AnimalState.FLEE else 5.0)
	var amplitude := 0.42 if moving else 0.04
	for index in range(leg_pivots.size()):
		leg_pivots[index].rotation.x = sin(gait_time + float(index % 2) * PI) * amplitude
	if is_instance_valid(body_visual):
		body_visual.position.y = absf(sin(gait_time * 2.0)) * 0.06 if moving else 0.0
	if is_instance_valid(tail_visual):
		tail_visual.rotation.x = sin(gait_time * 1.8) * (0.18 if moving else 0.08)


func _build_animal_model() -> void:
	body_visual = Node3D.new()
	body_visual.name = "ProceduralModel"
	add_child(body_visual)
	if animal_type == "deer":
		_build_deer_model()
	else:
		_build_boar_model()

	var capsule := CollisionShape3D.new()
	capsule.name = "BodyCollision"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38 if animal_type == "deer" else 0.46
	shape.height = 1.55 if animal_type == "deer" else 1.2
	capsule.shape = shape
	capsule.position.y = 0.78 if animal_type == "deer" else 0.62
	add_child(capsule)


func _build_deer_model() -> void:
	_add_ellipsoid(body_visual, "Body", Vector3(0.0, 0.95, 0.0), Vector3(0.52, 0.43, 0.88), DEER_COAT)
	_add_ellipsoid(body_visual, "Chest", Vector3(0.0, 0.98, -0.48), Vector3(0.43, 0.47, 0.42), DEER_LIGHT)
	_add_ellipsoid(body_visual, "Neck", Vector3(0.0, 1.38, -0.58), Vector3(0.25, 0.48, 0.28), DEER_COAT)
	_add_ellipsoid(body_visual, "Head", Vector3(0.0, 1.73, -0.79), Vector3(0.28, 0.24, 0.34), DEER_LIGHT)
	for side in [-1.0, 1.0]:
		_add_ellipsoid(body_visual, "Ear", Vector3(side * 0.25, 1.94, -0.72), Vector3(0.10, 0.22, 0.08), DEER_COAT)
		_add_antler(side)
	tail_visual = _add_ellipsoid(body_visual, "Tail", Vector3(0.0, 1.08, 0.78), Vector3(0.16, 0.2, 0.22), DEER_LIGHT)
	_add_legs(DEER_COAT, 0.36, 0.34)


func _build_boar_model() -> void:
	_add_ellipsoid(body_visual, "Body", Vector3(0.0, 0.77, 0.08), Vector3(0.63, 0.56, 0.82), BOAR_COAT)
	_add_ellipsoid(body_visual, "Shoulders", Vector3(0.0, 0.88, -0.48), Vector3(0.54, 0.53, 0.48), BOAR_COAT)
	_add_ellipsoid(body_visual, "Head", Vector3(0.0, 1.05, -0.76), Vector3(0.43, 0.39, 0.46), BOAR_COAT)
	_add_ellipsoid(body_visual, "Snout", Vector3(0.0, 0.98, -1.12), Vector3(0.31, 0.23, 0.25), BOAR_SNOUT)
	for side in [-1.0, 1.0]:
		_add_ellipsoid(body_visual, "Ear", Vector3(side * 0.32, 1.43, -0.72), Vector3(0.16, 0.25, 0.11), BOAR_SNOUT)
		_add_ellipsoid(body_visual, "Eye", Vector3(side * 0.34, 1.15, -0.96), Vector3(0.055, 0.06, 0.045), Color(0.08, 0.06, 0.04))
		_add_tusk(side)
	tail_visual = Node3D.new()
	tail_visual.name = "Tail"
	tail_visual.position = Vector3(0.0, 1.05, 0.82)
	body_visual.add_child(tail_visual)
	_add_segment(tail_visual, "TailBase", Vector3.ZERO, Vector3(0.0, 0.16, 0.22), 0.075, BOAR_COAT)
	_add_segment(tail_visual, "TailCurl", Vector3(0.0, 0.16, 0.22), Vector3(0.0, 0.32, 0.1), 0.055, BOAR_COAT)
	_add_legs(BOAR_COAT, 0.42, 0.38)


func _add_legs(color: Color, x_offset: float, z_offset: float) -> void:
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(x_sign * x_offset, 0.68 if animal_type == "deer" else 0.54, z_sign * z_offset)
			body_visual.add_child(pivot)
			_add_ellipsoid(
				pivot,
				"Leg",
				Vector3(0.0, -0.32, 0.0),
				Vector3(0.12, 0.39 if animal_type == "deer" else 0.30, 0.13),
				LEG_COLOR if animal_type == "deer" else color
			)
			leg_pivots.append(pivot)


func _add_antler(side: float) -> void:
	var base := Vector3(side * 0.16, 1.86, -0.76)
	var stem_end := Vector3(side * 0.28, 2.28, -0.72)
	_add_segment(body_visual, "AntlerStem", base, stem_end, 0.045, Color(0.73, 0.68, 0.53))
	_add_segment(body_visual, "AntlerTine", stem_end, stem_end + Vector3(side * 0.12, 0.18, 0.0), 0.032, Color(0.73, 0.68, 0.53))
	_add_segment(body_visual, "AntlerBranch", base + Vector3(side * 0.04, 0.18, 0.0), base + Vector3(side * 0.25, 0.28, 0.0), 0.035, Color(0.73, 0.68, 0.53))


func _add_tusk(side: float) -> void:
	var tusk := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.075
	cone.height = 0.25
	tusk.mesh = cone
	tusk.position = Vector3(side * 0.3, 0.94, -1.02)
	tusk.rotation.x = deg_to_rad(-20.0)
	tusk.material_override = _make_material(Color(0.88, 0.79, 0.58))
	body_visual.add_child(tusk)


func _add_ellipsoid(
	parent: Node3D,
	part_name: String,
	part_position: Vector3,
	part_scale: Vector3,
	color: Color
) -> Node3D:
	var visual := MeshInstance3D.new()
	visual.name = part_name
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	visual.mesh = mesh
	visual.position = part_position
	visual.scale = part_scale
	visual.material_override = _make_material(color)
	parent.add_child(visual)
	return visual


func _add_segment(
	parent: Node3D,
	part_name: String,
	start: Vector3,
	finish: Vector3,
	radius: float,
	color: Color
) -> void:
	var segment := MeshInstance3D.new()
	segment.name = part_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.72
	mesh.bottom_radius = radius
	mesh.height = start.distance_to(finish)
	segment.mesh = mesh
	segment.position = (start + finish) * 0.5
	segment.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())
	segment.material_override = _make_material(color)
	parent.add_child(segment)


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
