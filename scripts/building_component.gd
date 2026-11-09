extends StaticBody3D

const WOOD_COLOR := Color(0.49, 0.32, 0.19)
const FLOOR_COLOR := Color(0.56, 0.39, 0.24)
const ROOF_COLOR := Color(0.34, 0.24, 0.16)
const GHOST_GREEN := Color(0.20, 0.92, 0.30, 0.42)
const GHOST_RED := Color(0.96, 0.16, 0.12, 0.42)

var component_id := ""
var preview_only := false
var preview_valid := false
var visuals: Array[MeshInstance3D] = []


func configure(id: String, as_preview: bool = false) -> void:
	component_id = id
	preview_only = as_preview
	collision_layer = 0 if as_preview else 1
	collision_mask = 0 if as_preview else 1
	if not as_preview:
		add_to_group("wooden_structure")
	for part in _parts_for(id):
		var part_size: Vector3 = part["size"]
		var part_position: Vector3 = part["position"]
		var part_rotation: Vector3 = part["rotation"]
		var mesh_instance := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = part_size
		mesh_instance.mesh = box_mesh
		mesh_instance.position = part_position
		mesh_instance.rotation = part_rotation
		mesh_instance.material_override = _make_material(part["color"], as_preview)
		add_child(mesh_instance)
		visuals.append(mesh_instance)
		if not as_preview:
			var collision := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			box_shape.size = part_size
			collision.shape = box_shape
			collision.position = part_position
			collision.rotation = part_rotation
			add_child(collision)


func set_preview_valid(valid: bool) -> void:
	preview_valid = valid
	if not preview_only:
		return
	var color := GHOST_GREEN if valid else GHOST_RED
	for visual in visuals:
		visual.material_override = _make_material(color, true)


static func _parts_for(id: String) -> Array[Dictionary]:
	match id:
		"wooden_foundation":
			return [{"size": Vector3(4.0, 0.30, 4.0), "position": Vector3(0.0, 0.15, 0.0), "rotation": Vector3.ZERO, "color": FLOOR_COLOR}]
		"wooden_wall":
			return [{"size": Vector3(3.60, 2.70, 0.20), "position": Vector3(0.0, 1.35, 0.0), "rotation": Vector3.ZERO, "color": WOOD_COLOR}]
		"wooden_door":
			return [
				{"size": Vector3(0.18, 2.70, 0.20), "position": Vector3(-0.91, 1.35, 0.0), "rotation": Vector3.ZERO, "color": WOOD_COLOR},
				{"size": Vector3(0.18, 2.70, 0.20), "position": Vector3(0.91, 1.35, 0.0), "rotation": Vector3.ZERO, "color": WOOD_COLOR},
				{"size": Vector3(2.0, 0.24, 0.20), "position": Vector3(0.0, 2.58, 0.0), "rotation": Vector3.ZERO, "color": WOOD_COLOR},
				{"size": Vector3(1.6, 0.10, 2.40), "position": Vector3(0.0, -0.45, 1.30), "rotation": Vector3(deg_to_rad(22.0), 0.0, 0.0), "color": FLOOR_COLOR}
			]
		"wooden_roof":
			return [
				{"size": Vector3(4.0, 0.18, 2.25), "position": Vector3(0.0, 0.0, -1.02), "rotation": Vector3(deg_to_rad(-25.0), 0.0, 0.0), "color": ROOF_COLOR},
				{"size": Vector3(4.0, 0.18, 2.25), "position": Vector3(0.0, 0.0, 1.02), "rotation": Vector3(deg_to_rad(25.0), 0.0, 0.0), "color": ROOF_COLOR}
			]
		_:
			return []


func _make_material(color: Color, is_ghost: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	if is_ghost:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
