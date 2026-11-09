extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HARVESTABLE_SCRIPT := preload("res://scripts/harvestable.gd")
const JOYSTICK_SCRIPT := preload("res://scripts/virtual_joystick.gd")
const TOUCH_LOOK_SCRIPT := preload("res://scripts/touch_look.gd")

const ISLAND_RADIUS := 48.0
const TERRAIN_STEPS := 56
const GATHER_DISTANCE := 4.0

var player: CharacterBody3D
var inventory := {"wood": 0, "fiber": 0, "stone": 0, "berries": 0}
var health := 100.0
var hunger := 100.0
var thirst := 100.0
var elapsed_game_time := 0.0
var day_length_seconds := 240.0

var sun: DirectionalLight3D
var environment: WorldEnvironment
var prompt_label: Label
var inventory_label: Label
var time_label: Label
var health_bar: ProgressBar
var hunger_bar: ProgressBar
var thirst_bar: ProgressBar
var interact_button: Button
var nearby_resource: Node3D
var survival_tick := 0.0


func _ready() -> void:
	_build_environment()
	_build_island()
	_scatter_resources()
	_spawn_player()
	_build_hud()


func _process(delta: float) -> void:
	elapsed_game_time += delta
	survival_tick += delta
	_update_day_cycle()
	if survival_tick >= 1.0:
		_update_survival(minf(survival_tick, 5.0))
		survival_tick = 0.0
	_update_nearby_resource()
	_update_hud()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.add_look_input(event.relative)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_gather_nearby()
	elif event.is_action_pressed("cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_environment() -> void:
	environment = WorldEnvironment.new()
	var world_environment := Environment.new()
	world_environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.10, 0.36, 0.63)
	sky_material.sky_horizon_color = Color(0.58, 0.79, 0.88)
	sky_material.ground_bottom_color = Color(0.10, 0.17, 0.16)
	sky_material.ground_horizon_color = Color(0.47, 0.62, 0.58)
	sky.sky_material = sky_material
	world_environment.sky = sky
	world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.ambient_light_color = Color(0.68, 0.77, 0.77)
	world_environment.ambient_light_energy = 0.65
	world_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = world_environment
	add_child(environment)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -30.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)


func _build_island() -> void:
	var terrain_mesh := _create_terrain_mesh()
	var terrain := MeshInstance3D.new()
	terrain.name = "IslandTerrain"
	terrain.mesh = terrain_mesh
	terrain.material_override = _terrain_material()
	add_child(terrain)

	var terrain_body := StaticBody3D.new()
	terrain_body.name = "TerrainCollision"
	var terrain_collision := CollisionShape3D.new()
	terrain_collision.shape = terrain_mesh.create_trimesh_shape()
	terrain_body.add_child(terrain_collision)
	add_child(terrain_body)

	var ocean := MeshInstance3D.new()
	ocean.name = "Ocean"
	var ocean_mesh := PlaneMesh.new()
	ocean_mesh.size = Vector2(240.0, 240.0)
	ocean.mesh = ocean_mesh
	var ocean_material := StandardMaterial3D.new()
	ocean_material.albedo_color = Color(0.04, 0.38, 0.52)
	ocean_material.roughness = 0.28
	ocean.material_override = ocean_material
	ocean.position.y = -0.35
	add_child(ocean)


func _create_terrain_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_size := ISLAND_RADIUS + 5.0
	var step_size := half_size * 2.0 / float(TERRAIN_STEPS)
	for z in range(TERRAIN_STEPS):
		for x in range(TERRAIN_STEPS):
			var x0 := -half_size + float(x) * step_size
			var z0 := -half_size + float(z) * step_size
			var p00 := _terrain_point(x0, z0)
			var p10 := _terrain_point(x0 + step_size, z0)
			var p01 := _terrain_point(x0, z0 + step_size)
			var p11 := _terrain_point(x0 + step_size, z0 + step_size)
			_add_terrain_triangle(tool, p00, p01, p10)
			_add_terrain_triangle(tool, p10, p01, p11)
	tool.generate_normals()
	return tool.commit()


func _terrain_point(x: float, z: float) -> Vector3:
	var distance := Vector2(x, z).length()
	var shoreline := clampf((ISLAND_RADIUS - distance) / 12.0, 0.0, 1.0)
	var hill := maxf(0.0, 1.0 - distance / 38.0)
	var y := -1.35 + shoreline * 1.75 + hill * 4.6
	if distance > ISLAND_RADIUS:
		y -= minf((distance - ISLAND_RADIUS) * 0.28, 2.0)
	return Vector3(x, y, z)


func _add_terrain_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for point in [a, b, c]:
		var color := Color(0.79, 0.72, 0.48)
		if point.y > 0.45:
			color = Color(0.22, 0.49, 0.27)
		elif point.y > -0.05:
			color = Color(0.68, 0.67, 0.39)
		tool.set_color(color)
		tool.add_vertex(point)


func _terrain_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	return material


func _scatter_resources() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 481516
	for index in range(18):
		var point := _random_island_point(rng, 9.0, 34.0)
		_add_palm(point, rng.randf_range(0.82, 1.2))
	for index in range(12):
		var point := _random_island_point(rng, 7.0, 32.0)
		_add_rock(point, rng.randf_range(0.75, 1.4))
	for index in range(10):
		var point := _random_island_point(rng, 7.0, 31.0)
		_add_bush(point, rng.randf_range(0.75, 1.25))


func _random_island_point(rng: RandomNumberGenerator, min_radius: float, max_radius: float) -> Vector3:
	var angle := rng.randf_range(0.0, TAU)
	var radius := rng.randf_range(min_radius, max_radius)
	var x := cos(angle) * radius
	var z := sin(angle) * radius
	return Vector3(x, _terrain_point(x, z).y, z)


func _add_palm(point: Vector3, scale_factor: float) -> void:
	var tree := _new_harvestable("Palm tree", {&"wood": 1, &"fiber": 1}, 3)
	tree.position = point
	tree.scale = Vector3.ONE * scale_factor
	add_child(tree)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.32
	trunk_mesh.height = 5.2
	trunk.mesh = trunk_mesh
	trunk.position.y = 2.6
	trunk.material_override = _material(Color(0.39, 0.25, 0.12))
	tree.add_child(trunk)
	var crown := Vector3(0.0, 5.1, 0.0)
	for frond_index in range(5):
		var angle := TAU * float(frond_index) / 5.0
		var direction := Vector3(cos(angle), 0.48, sin(angle)).normalized()
		var frond := MeshInstance3D.new()
		var frond_mesh := CylinderMesh.new()
		frond_mesh.top_radius = 0.015
		frond_mesh.bottom_radius = 0.11
		frond_mesh.height = 3.2
		frond.mesh = frond_mesh
		frond.position = crown + direction * 1.45
		frond.quaternion = Quaternion(Vector3.UP, direction)
		frond.material_override = _material(Color(0.12, 0.38, 0.18))
		tree.add_child(frond)


func _add_rock(point: Vector3, scale_factor: float) -> void:
	var rock := _new_harvestable("Rock", {&"stone": 1}, 3)
	rock.position = point + Vector3(0.0, 0.3 * scale_factor, 0.0)
	rock.scale = Vector3(1.2, 0.8, 1.0) * scale_factor
	add_child(rock)
	var mesh_instance := MeshInstance3D.new()
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.8
	rock_mesh.height = 1.3
	mesh_instance.mesh = rock_mesh
	mesh_instance.material_override = _material(Color(0.43, 0.48, 0.47))
	rock.add_child(mesh_instance)


func _add_bush(point: Vector3, scale_factor: float) -> void:
	var bush := _new_harvestable("Berry bush", {&"berries": 1}, 2)
	bush.position = point + Vector3(0.0, 0.42 * scale_factor, 0.0)
	bush.scale = Vector3.ONE * scale_factor
	add_child(bush)
	var foliage := MeshInstance3D.new()
	var foliage_mesh := SphereMesh.new()
	foliage_mesh.radius = 0.68
	foliage_mesh.height = 1.1
	foliage.mesh = foliage_mesh
	foliage.material_override = _material(Color(0.17, 0.42, 0.19))
	bush.add_child(foliage)
	var berries := MeshInstance3D.new()
	var berry_mesh := SphereMesh.new()
	berry_mesh.radius = 0.11
	berry_mesh.height = 0.18
	berries.mesh = berry_mesh
	berries.position = Vector3(0.38, 0.1, 0.36)
	berries.material_override = _material(Color(0.7, 0.12, 0.2))
	bush.add_child(berries)


func _new_harvestable(title: String, yields: Dictionary, uses: int) -> Node3D:
	var resource := Node3D.new()
	resource.set_script(HARVESTABLE_SCRIPT)
	resource.set("display_name", title)
	resource.set("gathered_items", yields)
	resource.set("gathers_left", uses)
	return resource


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	return material


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.position = Vector3(0.0, _terrain_point(0.0, 0.0).y + 0.15, 0.0)
	add_child(player)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var stats := PanelContainer.new()
	stats.position = Vector2(18.0, 18.0)
	stats.custom_minimum_size = Vector2(235.0, 124.0)
	root.add_child(stats)
	var stats_column := VBoxContainer.new()
	stats.add_child(stats_column)
	health_bar = _add_stat_bar(stats_column, "Health", Color(0.75, 0.2, 0.16))
	hunger_bar = _add_stat_bar(stats_column, "Hunger", Color(0.86, 0.61, 0.17))
	thirst_bar = _add_stat_bar(stats_column, "Thirst", Color(0.17, 0.53, 0.83))

	time_label = Label.new()
	time_label.position = Vector2(18.0, 151.0)
	time_label.add_theme_font_size_override("font_size", 18)
	root.add_child(time_label)

	inventory_label = Label.new()
	inventory_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	inventory_label.position = Vector2(-228.0, 18.0)
	inventory_label.size = Vector2(210.0, 140.0)
	inventory_label.add_theme_font_size_override("font_size", 17)
	inventory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(inventory_label)

	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-190.0, -102.0)
	prompt_label.size = Vector2(380.0, 38.0)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 21)
	root.add_child(prompt_label)

	var joystick = JOYSTICK_SCRIPT.new()
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.position = Vector2(26.0, -190.0)
	joystick.size = Vector2(164.0, 164.0)
	joystick.value_changed.connect(player.set_move_input)
	root.add_child(joystick)

	var look_area = TOUCH_LOOK_SCRIPT.new()
	look_area.anchor_left = 0.48
	look_area.anchor_top = 0.0
	look_area.anchor_right = 1.0
	look_area.anchor_bottom = 1.0
	look_area.mouse_filter = Control.MOUSE_FILTER_STOP
	look_area.look_changed.connect(player.add_look_input)
	root.add_child(look_area)

	interact_button = Button.new()
	interact_button.text = "GATHER"
	interact_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	interact_button.position = Vector2(-156.0, -116.0)
	interact_button.size = Vector2(132.0, 72.0)
	interact_button.add_theme_font_size_override("font_size", 18)
	interact_button.pressed.connect(_gather_nearby)
	root.add_child(interact_button)


func _add_stat_bar(parent: VBoxContainer, title: String, tint: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 64.0
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(145.0, 22.0)
	row.add_child(bar)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = tint
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("fill", fill_style)
	return bar


func _update_nearby_resource() -> void:
	nearby_resource = null
	var closest_distance := GATHER_DISTANCE
	for candidate in get_children():
		if candidate.get_script() != HARVESTABLE_SCRIPT:
			continue
		var distance := player.global_position.distance_to(candidate.global_position)
		if distance < closest_distance:
			closest_distance = distance
			nearby_resource = candidate
	if is_instance_valid(nearby_resource):
		var remaining: int = nearby_resource.get("gathers_left")
		prompt_label.text = "E / GATHER  •  %s (%d)" % [nearby_resource.get("display_name"), remaining]
		interact_button.disabled = false
	else:
		prompt_label.text = "Explore the island and gather what you need."
		interact_button.disabled = true


func _gather_nearby() -> void:
	if not is_instance_valid(nearby_resource):
		return
	var result: Dictionary = nearby_resource.gather()
	if result.is_empty():
		return
	for item in result:
		inventory[item] = int(inventory.get(item, 0)) + int(result[item])


func _update_survival(delta: float) -> void:
	hunger = maxf(0.0, hunger - 0.1 * delta)
	thirst = maxf(0.0, thirst - 0.15 * delta)
	if hunger <= 0.0 or thirst <= 0.0:
		health = maxf(0.0, health - 0.12 * delta)


func _update_day_cycle() -> void:
	var day_phase := fposmod(elapsed_game_time / day_length_seconds, 1.0)
	var sun_angle := day_phase * TAU - PI * 0.5
	sun.rotation = Vector3(sun_angle, deg_to_rad(-30.0), 0.0)
	var daylight := clampf(sin(day_phase * TAU) * 0.65 + 0.5, 0.12, 1.0)
	sun.light_energy = daylight * 1.35
	environment.environment.ambient_light_energy = 0.25 + daylight * 0.48
	var hour := int(day_phase * 24.0)
	var minute := int(fposmod(day_phase * 1440.0, 60.0))
	time_label.text = "Day %d  •  %02d:%02d" % [int(elapsed_game_time / day_length_seconds) + 1, hour, minute]


func _update_hud() -> void:
	health_bar.value = health
	hunger_bar.value = hunger
	thirst_bar.value = thirst
	inventory_label.text = "PACK\nWood   %d\nFiber   %d\nStone  %d\nBerries %d" % [
		inventory["wood"], inventory["fiber"], inventory["stone"], inventory["berries"]
	]
