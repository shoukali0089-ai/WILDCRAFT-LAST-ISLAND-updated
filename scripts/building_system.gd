extends Node3D

signal structure_placed(component_id: String, position: Vector3)

const COMPONENT_SCRIPT := preload("res://scripts/building_component.gd")
const GRID_SIZE := 4.0
const TERRAIN_RAY_TOP := 100.0
const TERRAIN_RAY_BOTTOM := -20.0
const FOUNDATION_CORNER_OFFSET := 1.82

const COMPONENTS := {
	"wooden_foundation": {"name": "Foundation", "cost": 6},
	"wooden_wall": {"name": "Wall", "cost": 4},
	"wooden_door": {"name": "Door", "cost": 3},
	"wooden_roof": {"name": "Roof", "cost": 5}
}

const EDGE_NAMES := ["north", "east", "south", "west"]

var terrain_body: StaticBody3D
var player: CharacterBody3D
var placed_root: Node3D
var preview_root: StaticBody3D
var placed_components: Array[StaticBody3D] = []
var foundations: Dictionary = {}
var edge_occupancy: Dictionary = {}
var roof_occupancy: Dictionary = {}
var last_preview: Dictionary = {}


func _ready() -> void:
	placed_root = Node3D.new()
	placed_root.name = "PlacedStructures"
	add_child(placed_root)
	preview_root = COMPONENT_SCRIPT.new()
	preview_root.name = "PlacementPreview"
	preview_root.configure("wooden_foundation", true)
	preview_root.hide()
	add_child(preview_root)


func configure(ground: StaticBody3D, actor: CharacterBody3D) -> void:
	terrain_body = ground
	player = actor


func get_component_definitions() -> Dictionary:
	return COMPONENTS.duplicate(true)


func get_preview_at(component_id: String, target: Vector3, rotation_steps: int = 0) -> Dictionary:
	if not COMPONENTS.has(component_id):
		return _invalid_preview(target, "Select a building component.")
	match component_id:
		"wooden_foundation":
			return _foundation_preview(target, rotation_steps)
		"wooden_wall":
			return _edge_preview(component_id, target, rotation_steps)
		"wooden_door":
			return _door_preview(target, rotation_steps)
		"wooden_roof":
			return _roof_preview(target, rotation_steps)
	return _invalid_preview(target, "Invalid building component.")


func update_preview(component_id: String, target: Vector3, rotation_steps: int = 0) -> Dictionary:
	if preview_root.component_id != component_id:
		remove_child(preview_root)
		preview_root.queue_free()
		preview_root = COMPONENT_SCRIPT.new()
		preview_root.name = "PlacementPreview"
		preview_root.configure(component_id, true)
		add_child(preview_root)

	last_preview = get_preview_at(component_id, target, rotation_steps)
	preview_root.global_position = last_preview["position"]
	preview_root.rotation = last_preview["rotation"]
	preview_root.set_preview_valid(last_preview["valid"])
	preview_root.show()
	return last_preview


func hide_preview() -> void:
	if is_instance_valid(preview_root):
		preview_root.hide()
	last_preview.clear()


func place(component_id: String, target: Vector3, rotation_steps: int, inventory: Dictionary) -> Dictionary:
	var preview := get_preview_at(component_id, target, rotation_steps)
	if not preview["valid"]:
		return {"success": false, "message": preview["reason"]}

	var cost: int = COMPONENTS[component_id]["cost"]
	var available := int(inventory.get("wood", 0))
	if available < cost:
		return {
			"success": false,
			"message": "Need %d Wood (have %d)." % [cost, available]
		}

	var structure: StaticBody3D = COMPONENT_SCRIPT.new()
	structure.name = COMPONENTS[component_id]["name"].replace(" ", "")
	structure.configure(component_id)
	structure.position = preview["position"]
	structure.rotation = preview["rotation"]
	structure.set_meta("component_id", component_id)
	structure.set_meta("grid_key", preview.get("grid_key", ""))
	structure.set_meta("edge_key", preview.get("edge_key", ""))
	structure.set_meta("edge_name", preview.get("edge_name", ""))
	placed_root.add_child(structure)
	placed_components.append(structure)

	if component_id == "wooden_foundation":
		foundations[preview["grid_key"]] = structure
	elif component_id == "wooden_wall" or component_id == "wooden_door":
		edge_occupancy[preview["edge_key"]] = {
			"component_id": component_id,
			"grid_key": preview["grid_key"],
			"edge_name": preview["edge_name"]
		}
	elif component_id == "wooden_roof":
		roof_occupancy[preview["grid_key"]] = structure

	inventory["wood"] = available - cost
	structure_placed.emit(component_id, structure.global_position)
	return {
		"success": true,
		"message": "Placed %s." % COMPONENTS[component_id]["name"],
		"structure": structure
	}


func is_position_sheltered(position: Vector3) -> bool:
	for grid_key in foundations:
		var foundation: StaticBody3D = foundations[grid_key]
		if not is_instance_valid(foundation) or not roof_occupancy.has(grid_key):
			continue
		if not is_instance_valid(roof_occupancy[grid_key]):
			continue
		if absf(position.x - foundation.position.x) > 1.55:
			continue
		if absf(position.z - foundation.position.z) > 1.55:
			continue
		if position.y < foundation.position.y - 0.5 or position.y > foundation.position.y + 2.6:
			continue
		var occupied_edges: Dictionary = {}
		var has_door := false
		for slot in edge_occupancy.values():
			if slot["grid_key"] != grid_key:
				continue
			occupied_edges[slot["edge_name"]] = true
			has_door = has_door or slot["component_id"] == "wooden_door"
		if has_door and occupied_edges.size() == EDGE_NAMES.size():
			return true
	return false


func get_save_data() -> Array[Dictionary]:
	var saved_structures: Array[Dictionary] = []
	for structure in placed_components:
		if not is_instance_valid(structure):
			continue
		saved_structures.append({
			"component_id": String(structure.get_meta("component_id", "")),
			"position": _vector_to_array(structure.global_position),
			"rotation": _vector_to_array(structure.global_rotation),
			"grid_key": String(structure.get_meta("grid_key", "")),
			"edge_key": String(structure.get_meta("edge_key", "")),
			"edge_name": String(structure.get_meta("edge_name", ""))
		})
	return saved_structures


func validate_save_data(data: Variant) -> bool:
	if typeof(data) != TYPE_ARRAY:
		return false
	var foundation_keys: Dictionary = {}
	var edge_keys: Dictionary = {}
	var roof_keys: Dictionary = {}
	for item in data:
		if typeof(item) != TYPE_DICTIONARY:
			return false
		var component_id := String(item.get("component_id", ""))
		if not COMPONENTS.has(component_id):
			return false
		if not _is_vector_array(item.get("position")) or not _is_vector_array(item.get("rotation")):
			return false
		var grid_key := String(item.get("grid_key", ""))
		var edge_key := String(item.get("edge_key", ""))
		var edge_name := String(item.get("edge_name", ""))
		match component_id:
			"wooden_foundation":
				if grid_key.is_empty() or foundation_keys.has(grid_key):
					return false
				foundation_keys[grid_key] = true
			"wooden_wall", "wooden_door":
				if grid_key.is_empty() or edge_key.is_empty() or not EDGE_NAMES.has(edge_name) or edge_keys.has(edge_key):
					return false
				edge_keys[edge_key] = grid_key
			"wooden_roof":
				if grid_key.is_empty() or roof_keys.has(grid_key):
					return false
				roof_keys[grid_key] = true
	for grid_key in roof_keys:
		if not foundation_keys.has(grid_key):
			return false
	for edge_key in edge_keys:
		if not foundation_keys.has(edge_keys[edge_key]):
			return false
	return true


func restore_save_data(data: Array) -> bool:
	if not validate_save_data(data):
		return false
	for structure in placed_components:
		if is_instance_valid(structure):
			placed_root.remove_child(structure)
			structure.free()
	placed_components.clear()
	foundations.clear()
	edge_occupancy.clear()
	roof_occupancy.clear()

	for item in data:
		var component_id := String(item["component_id"])
		var structure: StaticBody3D = COMPONENT_SCRIPT.new()
		structure.name = COMPONENTS[component_id]["name"].replace(" ", "")
		structure.configure(component_id)
		structure.set_meta("component_id", component_id)
		structure.set_meta("grid_key", item["grid_key"])
		structure.set_meta("edge_key", item["edge_key"])
		structure.set_meta("edge_name", item["edge_name"])
		placed_root.add_child(structure)
		structure.global_position = _array_to_vector(item["position"])
		structure.global_rotation = _array_to_vector(item["rotation"])
		placed_components.append(structure)
		match component_id:
			"wooden_foundation":
				foundations[item["grid_key"]] = structure
			"wooden_wall", "wooden_door":
				edge_occupancy[item["edge_key"]] = {
					"component_id": component_id,
					"grid_key": item["grid_key"],
					"edge_name": item["edge_name"]
				}
			"wooden_roof":
				roof_occupancy[item["grid_key"]] = structure
	return true


func _foundation_preview(target: Vector3, rotation_steps: int) -> Dictionary:
	var grid_x := roundi(target.x / GRID_SIZE)
	var grid_z := roundi(target.z / GRID_SIZE)
	var grid_key := _grid_key(grid_x, grid_z)
	var center := Vector3(float(grid_x) * GRID_SIZE, target.y, float(grid_z) * GRID_SIZE)
	if foundations.has(grid_key):
		return _invalid_preview(center, "A foundation already occupies this tile.", grid_key)

	var samples: Array[Dictionary] = []
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			var sample_point := Vector3(
				center.x + x_sign * FOUNDATION_CORNER_OFFSET,
				center.y,
				center.z + z_sign * FOUNDATION_CORNER_OFFSET
			)
			var sample := _raycast_ground(sample_point)
			if sample.is_empty():
				return _invalid_preview(
					center,
					"Foundation needs clear, solid ground at %.1f, %.1f." % [sample_point.x, sample_point.z],
					grid_key
				)
			if absf(sample["normal"].y) < 0.78:
				return _invalid_preview(center, "Ground is too steep for a foundation.", grid_key)
			samples.append(sample)

	var min_height := INF
	var max_height := -INF
	var average_height := 0.0
	for sample in samples:
		var height: float = sample["position"].y
		min_height = minf(min_height, height)
		max_height = maxf(max_height, height)
		average_height += height
	if max_height - min_height > 0.48:
		return _invalid_preview(center, "Ground is too uneven for a foundation.", grid_key)
	center.y = average_height / float(samples.size())
	return {
		"valid": true,
		"reason": "",
		"position": center,
		"rotation": Vector3(0.0, deg_to_rad(90.0 * posmod(rotation_steps, 4)), 0.0),
		"grid_key": grid_key
	}


func _edge_preview(component_id: String, target: Vector3, rotation_steps: int) -> Dictionary:
	var anchor := _find_nearest_edge(target, rotation_steps)
	if anchor.is_empty():
		return _invalid_preview(target, "Place walls beside a foundation edge.")
	var edge_key: String = anchor["edge_key"]
	if edge_occupancy.has(edge_key):
		return _invalid_preview(anchor["position"], "That foundation edge is occupied.", anchor["grid_key"], edge_key)
	return {
		"valid": true,
		"reason": "",
		"position": anchor["position"],
		"rotation": anchor["rotation"],
		"grid_key": anchor["grid_key"],
		"edge_key": edge_key,
		"edge_name": anchor["edge_name"]
	}


func _door_preview(target: Vector3, rotation_steps: int) -> Dictionary:
	var anchor := _find_nearest_edge(target, rotation_steps)
	if anchor.is_empty():
		return _invalid_preview(target, "A door needs an open foundation edge beside a wall.")
	var edge_key: String = anchor["edge_key"]
	if edge_occupancy.has(edge_key):
		return _invalid_preview(anchor["position"], "That doorway position is occupied.", anchor["grid_key"], edge_key)
	if not _has_adjacent_wall(anchor["grid_key"], anchor["edge_name"]):
		return _invalid_preview(anchor["position"], "Build a wall beside the doorway first.", anchor["grid_key"], edge_key)
	return {
		"valid": true,
		"reason": "",
		"position": anchor["position"],
		"rotation": anchor["rotation"],
		"grid_key": anchor["grid_key"],
		"edge_key": edge_key,
		"edge_name": anchor["edge_name"]
	}


func _roof_preview(target: Vector3, rotation_steps: int) -> Dictionary:
	var foundation := _nearest_foundation(target, 3.2)
	if foundation.is_empty():
		return _invalid_preview(target, "A roof must be placed above a foundation.")
	var grid_key: String = foundation["grid_key"]
	if roof_occupancy.has(grid_key):
		return _invalid_preview(foundation["position"], "This foundation already has a roof.", grid_key)
	if _wall_count(grid_key) < 2:
		return _invalid_preview(foundation["position"], "Build at least two walls before placing a roof.", grid_key)
	var roof_position: Vector3 = foundation["position"] + Vector3(0.0, 3.0, 0.0)
	return {
		"valid": true,
		"reason": "",
		"position": roof_position,
		"rotation": Vector3(0.0, deg_to_rad(90.0 * posmod(rotation_steps, 4)), 0.0),
		"grid_key": grid_key
	}


func _find_nearest_edge(target: Vector3, rotation_steps: int) -> Dictionary:
	var selected: Dictionary = {}
	var best_distance := 3.2
	for grid_key in foundations:
		var foundation: StaticBody3D = foundations[grid_key]
		var base_position := _foundation_base(foundation)
		var nearest_edge := 0
		var nearest_distance := INF
		for edge_index in range(4):
			var edge_position := _edge_position(base_position, edge_index)
			var distance := Vector2(target.x - edge_position.x, target.z - edge_position.z).length()
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_edge = edge_index
		if nearest_distance >= best_distance:
			continue
		var edge_index := posmod(nearest_edge + rotation_steps, 4)
		var edge_position := _edge_position(base_position, edge_index)
		selected = {
			"position": edge_position,
			"rotation": Vector3(0.0, _edge_yaw(edge_index), 0.0),
			"grid_key": grid_key,
			"edge_name": EDGE_NAMES[edge_index],
			"edge_key": _edge_key(edge_position, edge_index)
		}
		best_distance = nearest_distance
	return selected


func _nearest_foundation(target: Vector3, max_distance: float) -> Dictionary:
	var selected: Dictionary = {}
	var best_distance := max_distance
	for grid_key in foundations:
		var foundation: StaticBody3D = foundations[grid_key]
		var base_position := _foundation_base(foundation)
		var distance := Vector2(target.x - base_position.x, target.z - base_position.z).length()
		if distance < best_distance:
			best_distance = distance
			selected = {"grid_key": grid_key, "position": base_position}
	return selected


func _has_adjacent_wall(grid_key: String, edge_name: String) -> bool:
	var edge_index := EDGE_NAMES.find(edge_name)
	for adjacent_index in [posmod(edge_index - 1, 4), posmod(edge_index + 1, 4)]:
		var slot_key := _edge_key_for_grid(grid_key, adjacent_index)
		if edge_occupancy.has(slot_key) and edge_occupancy[slot_key]["component_id"] == "wooden_wall":
			return true
	return false


func _wall_count(grid_key: String) -> int:
	var count := 0
	for slot in edge_occupancy.values():
		if slot["grid_key"] == grid_key:
			count += 1
	return count


func _raycast_ground(point: Vector3) -> Dictionary:
	if not is_inside_tree() or not is_instance_valid(terrain_body):
		return {}
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(point.x, TERRAIN_RAY_TOP, point.z),
		Vector3(point.x, TERRAIN_RAY_BOTTOM, point.z)
	)
	var excluded: Array[RID] = []
	if is_instance_valid(player):
		excluded.append(player.get_rid())
	for structure in placed_components:
		excluded.append(structure.get_rid())
	query.exclude = excluded
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit["collider"] != terrain_body:
		return {}
	return hit


func _edge_position(base_position: Vector3, edge_index: int) -> Vector3:
	match edge_index:
		0:
			return base_position + Vector3(0.0, 0.30, -1.90)
		1:
			return base_position + Vector3(1.90, 0.30, 0.0)
		2:
			return base_position + Vector3(0.0, 0.30, 1.90)
		_:
			return base_position + Vector3(-1.90, 0.30, 0.0)


func _edge_yaw(edge_index: int) -> float:
	return deg_to_rad(90.0 * float(posmod(2 - edge_index, 4)))


func _foundation_base(foundation: StaticBody3D) -> Vector3:
	return foundation.position


func _grid_key(grid_x: int, grid_z: int) -> String:
	return "%d:%d" % [grid_x, grid_z]


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


func _edge_key(position: Vector3, edge_index: int) -> String:
	var axis := "x" if edge_index == 0 or edge_index == 2 else "z"
	return "%d:%d:%s" % [roundi(position.x * 2.0), roundi(position.z * 2.0), axis]


func _edge_key_for_grid(grid_key: String, edge_index: int) -> String:
	var parts := grid_key.split(":")
	var base_position := Vector3(float(parts[0]) * GRID_SIZE, 0.0, float(parts[1]) * GRID_SIZE)
	var edge_position := _edge_position(base_position, edge_index)
	return _edge_key(edge_position, edge_index)


func _invalid_preview(
	position: Vector3,
	reason: String,
	grid_key: String = "",
	edge_key: String = ""
) -> Dictionary:
	return {
		"valid": false,
		"reason": reason,
		"position": position,
		"rotation": Vector3.ZERO,
		"grid_key": grid_key,
		"edge_key": edge_key
	}
