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


func get_animals_of_type(type: String) -> Array[CharacterBody3D]:
	var matching: Array[CharacterBody3D] = []
	for animal in animals:
		if is_instance_valid(animal) and animal.animal_type == type:
			matching.append(animal)
	return matching


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
