extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HARVESTABLE_SCRIPT := preload("res://scripts/harvestable.gd")
const JOYSTICK_SCRIPT := preload("res://scripts/virtual_joystick.gd")
const TOUCH_LOOK_SCRIPT := preload("res://scripts/touch_look.gd")
const RECIPE_ICON_SCRIPT := preload("res://scripts/recipe_icon.gd")
const CRAFTING_SYSTEM_SCRIPT := preload("res://scripts/crafting_system.gd")
const BUILDING_SYSTEM_SCRIPT := preload("res://scripts/building_system.gd")

const ISLAND_RADIUS := 48.0
const TERRAIN_STEPS := 56
const GATHER_DISTANCE := 4.0

var player: CharacterBody3D
var terrain_body: StaticBody3D
var building_system: Node3D
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
var craft_menu_button: Button
var craft_menu_close_button: Button
var build_mode_button: Button
var build_menu: PanelContainer
var build_menu_title: Label
var build_status_label: Label
var build_place_button: Button
var build_cancel_button: Button
var crafting_menu: Control
var crafting_system: RefCounted
var joystick_control: Control
var look_control: Control
var notification_label: Label
var notification_time_left := 0.0
var recipe_requirement_labels: Dictionary = {}
var recipe_craft_buttons: Dictionary = {}
var build_component_buttons: Dictionary = {}
var build_mode_active := false
var selected_build_component := ""
var build_rotation_steps := 0
var nearby_resource: Node3D
var survival_tick := 0.0


func _ready() -> void:
	_build_environment()
	_build_island()
	_scatter_resources()
	_spawn_player()
	crafting_system = CRAFTING_SYSTEM_SCRIPT.new()
	building_system = BUILDING_SYSTEM_SCRIPT.new()
	building_system.name = "BuildingSystem"
	add_child(building_system)
	building_system.configure(terrain_body, player)
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
	if build_mode_active and not selected_build_component.is_empty():
		_update_build_preview()
	if notification_time_left > 0.0:
		notification_time_left -= delta
		if notification_time_left <= 0.0:
			notification_label.hide()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.add_look_input(event.relative)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if build_mode_active:
			_place_building()
		else:
			_gather_nearby()
	elif event.is_action_pressed("craft_menu"):
		_set_crafting_menu_open(not crafting_menu.visible)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("build_mode"):
		_set_build_mode_active(not build_mode_active)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("rotate_build") and build_mode_active:
		_rotate_building()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel"):
		if build_mode_active:
			_set_build_mode_active(false)
		elif crafting_menu.visible:
			_set_crafting_menu_open(false)
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
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

	terrain_body = StaticBody3D.new()
	terrain_body.name = "TerrainCollision"
	var terrain_collision := CollisionShape3D.new()
	var terrain_shape := terrain_mesh.create_trimesh_shape() as ConcavePolygonShape3D
	terrain_shape.backface_collision = true
	terrain_collision.shape = terrain_shape
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

	joystick_control = JOYSTICK_SCRIPT.new()
	joystick_control.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick_control.position = Vector2(26.0, -190.0)
	joystick_control.size = Vector2(164.0, 164.0)
	joystick_control.value_changed.connect(player.set_move_input)
	root.add_child(joystick_control)

	look_control = TOUCH_LOOK_SCRIPT.new()
	look_control.anchor_left = 0.48
	look_control.anchor_top = 0.0
	look_control.anchor_right = 1.0
	look_control.anchor_bottom = 1.0
	look_control.mouse_filter = Control.MOUSE_FILTER_STOP
	look_control.look_changed.connect(player.add_look_input)
	root.add_child(look_control)

	interact_button = Button.new()
	interact_button.text = "GATHER"
	interact_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	interact_button.position = Vector2(-156.0, -116.0)
	interact_button.size = Vector2(132.0, 72.0)
	interact_button.add_theme_font_size_override("font_size", 18)
	interact_button.pressed.connect(_gather_nearby)
	root.add_child(interact_button)

	craft_menu_button = Button.new()
	craft_menu_button.text = "CRAFT"
	craft_menu_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	craft_menu_button.position = Vector2(-156.0, -190.0)
	craft_menu_button.size = Vector2(132.0, 64.0)
	craft_menu_button.add_theme_font_size_override("font_size", 18)
	craft_menu_button.pressed.connect(_open_crafting_menu)
	root.add_child(craft_menu_button)

	build_mode_button = Button.new()
	build_mode_button.text = "BUILD"
	build_mode_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	build_mode_button.position = Vector2(-156.0, -264.0)
	build_mode_button.size = Vector2(132.0, 64.0)
	build_mode_button.add_theme_font_size_override("font_size", 18)
	build_mode_button.pressed.connect(func() -> void: _set_build_mode_active(not build_mode_active))
	root.add_child(build_mode_button)

	_build_crafting_menu(root)
	_build_building_menu(root)
	notification_label = Label.new()
	notification_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	notification_label.position = Vector2(-240.0, 26.0)
	notification_label.size = Vector2(480.0, 44.0)
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.add_theme_font_size_override("font_size", 22)
	notification_label.hide()
	root.add_child(notification_label)


func _build_crafting_menu(parent: Control) -> void:
	crafting_menu = Control.new()
	crafting_menu.name = "CraftingMenu"
	crafting_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crafting_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	crafting_menu.hide()
	parent.add_child(crafting_menu)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.045, 0.045, 0.84)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	crafting_menu.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.set_anchor(SIDE_LEFT, 0.06)
	panel.set_anchor(SIDE_TOP, 0.055)
	panel.set_anchor(SIDE_RIGHT, 0.94)
	panel.set_anchor(SIDE_BOTTOM, 0.945)
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.14, 0.13, 0.98)
	panel_style.border_color = Color(0.45, 0.64, 0.49)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.content_margin_left = 18.0
	panel_style.content_margin_right = 18.0
	panel_style.content_margin_top = 14.0
	panel_style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", panel_style)
	crafting_menu.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "CRAFTING"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	header.add_child(title)
	craft_menu_close_button = Button.new()
	craft_menu_close_button.text = "CLOSE"
	craft_menu_close_button.custom_minimum_size = Vector2(132.0, 72.0)
	craft_menu_close_button.add_theme_font_size_override("font_size", 18)
	craft_menu_close_button.pressed.connect(func() -> void: _set_crafting_menu_open(false))
	header.add_child(craft_menu_close_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var recipe_list := VBoxContainer.new()
	recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_list.add_theme_constant_override("separation", 10)
	scroll.add_child(recipe_list)

	var recipes: Dictionary = crafting_system.get_recipes()
	for recipe_id in recipes:
		var recipe: Dictionary = recipes[recipe_id]
		_add_recipe_card(recipe_list, recipe_id, recipe)
	_update_crafting_menu()


func _build_building_menu(parent: Control) -> void:
	build_menu = PanelContainer.new()
	build_menu.name = "BuildingMenu"
	build_menu.anchor_left = 0.5
	build_menu.anchor_right = 0.5
	build_menu.position = Vector2(-170.0, 164.0)
	build_menu.size = Vector2(340.0, 348.0)
	build_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	build_menu.hide()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.14, 0.13, 0.97)
	panel_style.border_color = Color(0.45, 0.64, 0.49)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 10.0
	panel_style.content_margin_right = 10.0
	panel_style.content_margin_top = 10.0
	panel_style.content_margin_bottom = 10.0
	build_menu.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(build_menu)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	build_menu.add_child(column)
	build_menu_title = Label.new()
	build_menu_title.text = "BUILD MODE  •  %d WOOD" % int(inventory.get("wood", 0))
	build_menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_menu_title.add_theme_font_size_override("font_size", 19)
	column.add_child(build_menu_title)

	var component_grid := GridContainer.new()
	component_grid.columns = 2
	component_grid.add_theme_constant_override("h_separation", 8)
	component_grid.add_theme_constant_override("v_separation", 8)
	column.add_child(component_grid)
	var definitions: Dictionary = building_system.get_component_definitions()
	for component_id in definitions:
		var selector := Button.new()
		selector.text = "%s\n%d Wood" % [definitions[component_id]["name"], int(definitions[component_id]["cost"])]
		selector.custom_minimum_size = Vector2(148.0, 62.0)
		selector.add_theme_font_size_override("font_size", 16)
		selector.pressed.connect(_select_build_component.bind(component_id))
		component_grid.add_child(selector)
		build_component_buttons[component_id] = selector

	build_status_label = Label.new()
	build_status_label.text = "Choose a structure to preview."
	build_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_status_label.custom_minimum_size.y = 40.0
	build_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_status_label.add_theme_font_size_override("font_size", 15)
	column.add_child(build_status_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	column.add_child(actions)
	var rotate_button := Button.new()
	rotate_button.text = "ROTATE"
	rotate_button.custom_minimum_size = Vector2(92.0, 68.0)
	rotate_button.add_theme_font_size_override("font_size", 14)
	rotate_button.pressed.connect(_rotate_building)
	actions.add_child(rotate_button)
	build_place_button = Button.new()
	build_place_button.text = "PLACE"
	build_place_button.custom_minimum_size = Vector2(104.0, 68.0)
	build_place_button.add_theme_font_size_override("font_size", 16)
	build_place_button.pressed.connect(_place_building)
	actions.add_child(build_place_button)
	build_cancel_button = Button.new()
	build_cancel_button.text = "CANCEL"
	build_cancel_button.custom_minimum_size = Vector2(104.0, 68.0)
	build_cancel_button.add_theme_font_size_override("font_size", 14)
	build_cancel_button.pressed.connect(func() -> void: _set_build_mode_active(false))
	actions.add_child(build_cancel_button)


func _select_build_component(component_id: String) -> void:
	selected_build_component = component_id
	build_rotation_steps = 0
	for id in build_component_buttons:
		build_component_buttons[id].toggle_mode = true
		build_component_buttons[id].button_pressed = false
	build_component_buttons[component_id].button_pressed = true
	_update_build_preview()


func _update_build_preview() -> void:
	if not is_instance_valid(building_system) or selected_build_component.is_empty():
		return
	var target := player.global_position - player.global_basis.z * 3.0
	var preview: Dictionary = building_system.update_preview(
		selected_build_component,
		target,
		build_rotation_steps
	)
	build_place_button.disabled = not bool(preview["valid"])
	var text := "READY TO PLACE" if preview["valid"] else String(preview["reason"])
	build_status_label.text = "%s  •  %d Wood" % [text, int(inventory.get("wood", 0))]
	build_status_label.add_theme_color_override(
		"font_color",
		Color(0.55, 0.95, 0.60) if preview["valid"] else Color(1.0, 0.55, 0.46)
	)


func _rotate_building() -> void:
	if not build_mode_active or selected_build_component.is_empty():
		return
	build_rotation_steps = posmod(build_rotation_steps + 1, 4)
	_update_build_preview()


func _place_building() -> void:
	if not build_mode_active or selected_build_component.is_empty():
		return
	var target := player.global_position - player.global_basis.z * 3.0
	var result: Dictionary = building_system.place(
		selected_build_component,
		target,
		build_rotation_steps,
		inventory
	)
	_show_notification(result["message"], bool(result["success"]))
	_update_hud()
	_update_build_preview()


func _set_build_mode_active(active: bool) -> void:
	if active and crafting_menu.visible:
		_set_crafting_menu_open(false)
	build_mode_active = active
	build_menu.visible = active
	build_mode_button.text = "EXIT BUILD" if active else "BUILD"
	interact_button.visible = not active
	craft_menu_button.visible = not active
	if active:
		if selected_build_component.is_empty():
			build_status_label.text = "Choose a structure to preview."
		if not OS.has_feature("mobile"):
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif is_instance_valid(building_system):
		building_system.hide_preview()
		selected_build_component = ""
		build_place_button.disabled = true
		if not OS.has_feature("mobile"):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _add_recipe_card(parent: VBoxContainer, recipe_id: String, recipe: Dictionary) -> void:
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.13, 0.22, 0.19, 0.98)
	card_style.set_corner_radius_all(10)
	card_style.content_margin_left = 12.0
	card_style.content_margin_right = 12.0
	card_style.content_margin_top = 8.0
	card_style.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", card_style)
	parent.add_child(card)

	var card_column := VBoxContainer.new()
	card_column.add_theme_constant_override("separation", 8)
	card.add_child(card_column)

	var details_row := HBoxContainer.new()
	details_row.add_theme_constant_override("separation", 14)
	card_column.add_child(details_row)
	var icon = RECIPE_ICON_SCRIPT.new()
	icon.icon_type = recipe["icon"]
	details_row.add_child(icon)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	details_row.add_child(details)
	var name_label := Label.new()
	name_label.text = recipe["name"]
	name_label.add_theme_font_size_override("font_size", 21)
	details.add_child(name_label)
	var description_label := Label.new()
	description_label.text = recipe["description"]
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 15)
	details.add_child(description_label)
	var requirement_label := Label.new()
	requirement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	requirement_label.add_theme_font_size_override("font_size", 16)
	details.add_child(requirement_label)
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	card_column.add_child(action_row)
	recipe_requirement_labels[recipe_id] = requirement_label

	var craft_button := Button.new()
	craft_button.text = "CRAFT"
	craft_button.custom_minimum_size = Vector2(132.0, 72.0)
	craft_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	craft_button.add_theme_font_size_override("font_size", 18)
	craft_button.pressed.connect(_craft_recipe.bind(recipe_id))
	action_row.add_child(craft_button)
	recipe_craft_buttons[recipe_id] = craft_button


func _update_crafting_menu() -> void:
	if not is_instance_valid(crafting_menu):
		return
	var recipes: Dictionary = crafting_system.get_recipes()
	for recipe_id in recipes:
		var ingredients: Dictionary = recipes[recipe_id]["ingredients"]
		var costs: Array[String] = []
		for item in ingredients:
			costs.append("%s %d (have %d)" % [
				String(item).capitalize(),
				int(ingredients[item]),
				int(inventory.get(item, 0))
			])
		recipe_requirement_labels[recipe_id].text = " • ".join(costs)
		recipe_craft_buttons[recipe_id].disabled = not crafting_system.can_craft(recipe_id, inventory)


func _open_crafting_menu() -> void:
	_set_crafting_menu_open(true)


func _set_crafting_menu_open(open: bool) -> void:
	if open and build_mode_active:
		_set_build_mode_active(false)
	crafting_menu.visible = open
	joystick_control.visible = not open
	look_control.visible = not open
	interact_button.visible = not open
	craft_menu_button.visible = not open
	build_mode_button.visible = not open
	player.set_physics_process(not open)
	if open:
		player.velocity = Vector3.ZERO
		player.set_move_input(Vector2.ZERO)
		if not OS.has_feature("mobile"):
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_update_crafting_menu()
	elif not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _craft_recipe(recipe_id: String) -> bool:
	var result: Dictionary = crafting_system.craft(recipe_id, inventory)
	_show_notification(result["message"], bool(result["success"]))
	_update_crafting_menu()
	_update_hud()
	return bool(result["success"])


func _show_notification(message: String, success: bool) -> void:
	notification_label.text = message
	notification_label.add_theme_color_override(
		"font_color",
		Color(0.62, 0.96, 0.66) if success else Color(1.0, 0.52, 0.43)
	)
	notification_time_left = 2.5
	notification_label.show()

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
	if nearby_resource.get("display_name") == "Palm tree" and int(inventory.get("stone_axe", 0)) > 0:
		result["wood"] = int(result.get("wood", 0)) + 1
	for item in result:
		var item_key := String(item)
		inventory[item_key] = int(inventory.get(item_key, 0)) + int(result[item])
	_update_hud()


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
	if is_instance_valid(build_menu_title):
		build_menu_title.text = "BUILD MODE  •  %d WOOD" % int(inventory.get("wood", 0))
	inventory_label.text = "PACK\nWood   %d\nFiber   %d\nStone  %d\nBerries %d\n\nCRAFTED\nStone Axe %d\nCampfire %d\nSpear %d" % [
		inventory.get("wood", 0),
		inventory.get("fiber", 0),
		inventory.get("stone", 0),
		inventory.get("berries", 0),
		inventory.get("stone_axe", 0),
		inventory.get("campfire", 0),
		inventory.get("wooden_spear", 0)
	]
