extends Node3D

const ANIMAL_SCRIPT := preload("res://scripts/wildlife_animal.gd")
const ANIMAL_TYPES := ["deer", "deer", "wild_boar", "wild_boar"]
const MIN_SPAWN_RADIUS := 14.0
const MAX_SPAWN_RADIUS := 36.0
const MIN_PLAYER_DISTANCE := 13.0
const MIN_ANIMAL_DISTANCE := 7.0
const RESOURCE_CLEARANCE := 3.8

var terrain_body: StaticBody3D
var player: CharacterBody3D
var obstacle_nodes: Array[Node3D] = []
var island_radius := 48.0
var animals: Array[CharacterBody3D] = []
var rng := RandomNumberGenerator.new()
var ai_update_interval := 0.25


func configure(
	ground: StaticBody3D,
	actor: CharacterBody3D,
	obstacles: Array[Node3D],
	playable_radius: float
) -> void:
	terrain_body = ground
	player = actor
	obstacle_nodes = obstacles
	island_radius = playable_radius


func _ready() -> void:
	rng.seed = 783421
	_spawn_animals()


func get_animals() -> Array[CharacterBody3D]:
	return animals.duplicate()


func set_ai_update_interval(interval: float) -> void:
	ai_update_interval = maxf(interval, 0.05)
	for animal in animals:
		if is_instance_valid(animal):
			animal.ai_update_interval = ai_update_interval


func get_animals_of_type(type: String) -> Array[CharacterBody3D]:
	var matching: Array[CharacterBody3D] = []
	for animal in animals:
		if is_instance_valid(animal) and animal.animal_type == type:
			matching.append(animal)
	return matching


func get_save_data() -> Array[Dictionary]:
	var saved_animals: Array[Dictionary] = []
	for animal in animals:
		if not is_instance_valid(animal):
			continue
		saved_animals.append({
			"animal_type": animal.animal_type,
			"position": _vector_to_array(animal.global_position),
			"home_position": _vector_to_array(animal.home_position),
			"state": animal.get_state_name()
		})
	return saved_animals


func validate_save_data(data: Variant) -> bool:
	if typeof(data) != TYPE_ARRAY or data.size() > 12:
		return false
	for item in data:
		if typeof(item) != TYPE_DICTIONARY:
			return false
		if not ANIMAL_TYPES.has(String(item.get("animal_type", ""))):
			return false
		if not ["IDLE", "WANDER", "ALERT", "FLEE", "DEFEND", "RETURN"].has(String(item.get("state", ""))):
			return false
		if String(item["state"]) == "DEFEND" and String(item["animal_type"]) != "wild_boar":
			return false
		if not _is_vector_array(item.get("position")) or not _is_vector_array(item.get("home_position")):
			return false
		var saved_position := _array_to_vector(item["position"])
		var saved_home := _array_to_vector(item["home_position"])
		if Vector2(saved_position.x, saved_position.z).length() > island_radius + 1.0:
			return false
		if Vector2(saved_home.x, saved_home.z).length() > island_radius + 1.0:
			return false
	return true


func restore_save_data(data: Array) -> bool:
	if not validate_save_data(data):
		return false
	for animal in animals:
		if is_instance_valid(animal):
			remove_child(animal)
			animal.free()
	animals.clear()
	for item in data:
		var home := _array_to_vector(item["home_position"])
		var animal: CharacterBody3D = ANIMAL_SCRIPT.new()
		animal.configure(String(item["animal_type"]), player, home, obstacle_nodes, island_radius)
		animal.ai_update_interval = ai_update_interval
		animal.position = _array_to_vector(item["position"])
		add_child(animal)
		if not animal.restore_saved_state(String(item["state"])):
			return false
		animals.append(animal)
	return true


func _spawn_animals() -> void:
	for animal_type in ANIMAL_TYPES:
		var spawn_position := _find_spawn_position()
		if spawn_position.is_empty():
			push_warning("WildlifeSystem could not find clear ground for a %s." % animal_type)
			continue
		var animal: CharacterBody3D = ANIMAL_SCRIPT.new()
		animal.configure(
			animal_type,
			player,
			spawn_position["position"],
			obstacle_nodes,
			island_radius
		)
		animal.ai_update_interval = ai_update_interval
		animal.position = spawn_position["position"]
		add_child(animal)
		animals.append(animal)


func _find_spawn_position() -> Dictionary:
	for attempt in range(160):
		var angle := rng.randf_range(0.0, TAU)
		var radius := sqrt(rng.randf()) * (MAX_SPAWN_RADIUS - MIN_SPAWN_RADIUS) + MIN_SPAWN_RADIUS
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		var candidate := Vector3(x, 0.0, z)
		if not _has_clearance(candidate):
			continue
		var ground := _raycast_ground(candidate)
		if ground.is_empty() or float(ground["normal"].y) < 0.78:
			continue
		return {"position": ground["position"] + Vector3.UP * 0.04}
	return {}


func _has_clearance(candidate: Vector3) -> bool:
	if Vector2(candidate.x, candidate.z).length() > island_radius - 5.0:
		return false
	if is_instance_valid(player) and _horizontal_distance(candidate, player.global_position) < MIN_PLAYER_DISTANCE:
		return false
	for node in obstacle_nodes:
		if is_instance_valid(node) and _horizontal_distance(candidate, node.global_position) < RESOURCE_CLEARANCE:
			return false
	for animal in animals:
		if is_instance_valid(animal) and _horizontal_distance(candidate, animal.global_position) < MIN_ANIMAL_DISTANCE:
			return false
	return true


func _raycast_ground(candidate: Vector3) -> Dictionary:
	if not is_inside_tree() or not is_instance_valid(terrain_body):
		return {}
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(candidate.x, 100.0, candidate.z),
		Vector3(candidate.x, -20.0, candidate.z)
	)
	if is_instance_valid(player):
		query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit["collider"] != terrain_body:
		return {}
	return hit


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _array_to_vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func _is_vector_array(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY or value.size() != 3:
		return false
	for component in value:
		if typeof(component) != TYPE_INT and typeof(component) != TYPE_FLOAT:
			return false
		var number := float(component)
		if not is_finite(number) or absf(number) > 10000.0:
			return false
	return true
