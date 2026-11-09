extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const JOYSTICK_SCRIPT := preload("res://scripts/virtual_joystick.gd")
const TOUCH_LOOK_SCRIPT := preload("res://scripts/touch_look.gd")
const HARVESTABLE_SCRIPT := preload("res://scripts/harvestable.gd")
const SAVE_TEST_PATH := "user://wildcraft_prototype_smoke_save.json"
const AUDIO_SETTINGS_TEST_PATH := "user://wildcraft_audio_smoke_settings.cfg"
const GRAPHICS_SETTINGS_SCRIPT := preload("res://scripts/graphics_settings.gd")
const GRAPHICS_SETTINGS_TEST_PATH := "user://wildcraft_graphics_smoke_settings.cfg"

var test_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(360, 800)
	var mobile_viewport := SubViewport.new()
	mobile_viewport.size = Vector2i(360, 800)
	mobile_viewport.own_world_3d = true
	mobile_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(mobile_viewport)
	var game: Node3D = MAIN_SCENE.instantiate()
	mobile_viewport.add_child(game)
	await process_frame
	game.get("save_manager").save_path = SAVE_TEST_PATH
	game.get("save_manager").delete_save(true)

	var player: CharacterBody3D = game.get("player")
	_check(player != null, "The main scene should spawn the player.")
	var hud_root: Control = game.get_node("HUD").get_child(0)
	var joystick: Control
	var look_area: Control
	for control in hud_root.get_children():
		if control.get_script() == JOYSTICK_SCRIPT:
			joystick = control
		elif control.get_script() == TOUCH_LOOK_SCRIPT:
			look_area = control
	_check(joystick != null and look_area != null, "The mobile movement and look controls should exist.")

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
	_check(player.get("joystick_input").y < -0.5, "Dragging the joystick upward should request forward movement.")
	for frame_index in range(12):
		await physics_frame
	var horizontal_distance := Vector2(
		player.global_position.x - start_position.x,
		player.global_position.z - start_position.z
	).length()
	_check(horizontal_distance > 0.1, "The player should move horizontally.")
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
	_check(player.rotation.y != rotation_before_look, "Dragging the touch-look area should rotate the player.")
	var look_release := InputEventScreenTouch.new()
	look_release.index = 4
	look_release.position = look_drag.position
	look_release.pressed = false
	look_area.call("_gui_input", look_release)
	print("PASS: mobile controls and player movement")

	var palm: Node3D
	for child in game.get_children():
		if child.has_method("gather") and child.get("display_name") == "Palm tree":
			palm = child
			break
	_check(palm != null, "The island should contain a gatherable palm.")
	game.set("nearby_resource", palm)
	game.call("_gather_nearby")
	var inventory: Dictionary = game.get("inventory")
	_check(inventory["wood"] == 1 and inventory["fiber"] == 1, "Gathering a palm should add wood and fiber.")
	_check(String(game.get("inventory_label").text).contains("Wood   1"), "Gathering should update the inventory HUD immediately.")
	_check(palm.get("gathers_left") == 2, "Gathering should consume one resource use.")
	print("PASS: palm gathering and immediate inventory HUD update")

	game.get("craft_menu_button").pressed.emit()
	await process_frame
	var crafting_menu: Control = game.get("crafting_menu")
	_check(crafting_menu.visible, "The crafting menu should open.")
	var requirement_labels: Dictionary = game.get("recipe_requirement_labels")
	var craft_buttons: Dictionary = game.get("recipe_craft_buttons")
	_check(requirement_labels.size() == 3 and craft_buttons.size() == 3, "All three recipe cards should be present.")
	var crafting_panel: Control = crafting_menu.get_child(1)
	var scroll_container: ScrollContainer = crafting_panel.get_child(0).get_child(1)
	_assert_crafting_layout(game, mobile_viewport, crafting_panel, scroll_container, craft_buttons, Vector2i(360, 800))
	mobile_viewport.size = Vector2i(800, 450)
	await process_frame
	_assert_crafting_layout(game, mobile_viewport, crafting_panel, scroll_container, craft_buttons, Vector2i(800, 450))
	mobile_viewport.size = Vector2i(360, 800)
	await process_frame
	print("PASS: crafting menu interactions and portrait/landscape mobile layout")
	_check(String(requirement_labels["stone_axe"].text).contains("Wood 3 (have 1)"), "The recipe should show live resource quantities.")
	_check(craft_buttons["stone_axe"].disabled, "A recipe should be disabled when materials are insufficient.")
	var build_inventory_before_cancel: Dictionary = inventory.duplicate(true)
	game.get("build_mode_button").pressed.emit()
	await process_frame
	var build_menu: Control = game.get("build_menu")
	_check(build_menu.visible, "Build Mode button should open the building menu.")
	_check(build_menu.get_global_rect().position.x >= 0.0, "Building menu should fit within a portrait mobile viewport.")
	_check(build_menu.get_global_rect().end.x <= 360.0, "Building menu should not overflow a portrait mobile viewport.")
	_check(build_menu.get_global_rect().end.y <= 800.0, "Building menu should fit vertically on a portrait mobile viewport.")
	for selector in game.get("build_component_buttons").values():
		_check(selector.get_global_rect().size.x >= 100.0 and selector.get_global_rect().size.y >= 56.0, "Building selectors should be finger-friendly.")
	game.get("build_component_buttons")["wooden_foundation"].pressed.emit()
	_check(game.get("building_system").preview_root.visible, "Building selection should show its preview.")
	game.get("build_cancel_button").pressed.emit()
	_check(inventory == build_inventory_before_cancel, "Cancelling the mobile build menu must not consume resources.")
	_check(game.get("joystick_control").visible and game.get("look_control").visible, "Mobile movement and camera controls should remain available in build mode.")
	print("PASS: mobile build menu bounds, touch targets, preview, and cancellation")

	var inventory_before_failed_craft := inventory.duplicate(true)
	_check(not game.call("_craft_recipe", "stone_axe"), "Crafting without enough materials should fail.")
	_check(inventory == inventory_before_failed_craft, "A failed craft should not change inventory.")
	_check(game.get("notification_label").visible, "A crafting failure should show a notification.")
	inventory["wood"] = 3
	inventory["stone"] = 1
	game.call("_update_crafting_menu")
	var inventory_before_stone_shortage := inventory.duplicate(true)
	_check(not game.call("_craft_recipe", "stone_axe"), "Crafting should fail when stone is one short.")
	_check(inventory == inventory_before_stone_shortage, "A stone shortage must not consume any wood.")
	print("PASS: insufficient-resource handling and atomic deductions")

	inventory["wood"] = 3
	inventory["stone"] = 2
	craft_buttons["stone_axe"].pressed.emit()
	_check(inventory["wood"] == 0 and inventory["stone"] == 0, "The axe recipe should deduct exactly 3 wood and 2 stone.")
	_check(inventory["stone_axe"] == 1, "Crafting the axe once should add exactly one axe.")
	_check(String(game.get("inventory_label").text).contains("Stone Axe 1"), "The inventory HUD should update immediately.")
	_check(String(game.get("notification_label").text).contains("Crafted Stone Axe"), "Successful crafting should show a notification.")
	_check(craft_buttons["stone_axe"].disabled, "The axe button should refresh after materials are spent.")

	_check(not game.call("_craft_recipe", "unknown_recipe"), "Unknown recipes should fail without granting an item.")
	_check(inventory["stone_axe"] == 1, "An invalid recipe must not duplicate a crafted item.")

	inventory["wood"] = 3
	inventory["stone"] = 2
	_check(game.call("_craft_recipe", "stone_axe"), "The axe should be craftable again when materials are supplied.")
	_check(inventory["stone_axe"] == 2, "A second successful craft should add only one additional axe.")
	_check(inventory["wood"] == 0 and inventory["stone"] == 0, "Repeated crafting should deduct each cost once.")
	print("PASS: Stone Axe recipe, output count, and repeated crafting")

	game.set("nearby_resource", palm)
	var wood_before_axe_gather: int = inventory["wood"]
	game.call("_gather_nearby")
	_check(inventory["wood"] == wood_before_axe_gather + 2, "A carried Stone Axe should yield one extra wood from a palm.")

	inventory["wood"] = 10
	inventory["stone"] = 6
	game.call("_update_crafting_menu")
	_check(craft_buttons["campfire"].disabled == false, "Campfire should be enabled at or above its 5 wood and 3 stone requirements.")
	_check(game.call("_craft_recipe", "campfire"), "The Campfire recipe should craft with sufficient materials.")
	_check(inventory["wood"] == 5 and inventory["stone"] == 3, "Crafting a Campfire should deduct 5 wood and 3 stone.")
	_check(inventory["campfire"] == 1, "A crafted Campfire should be stored in inventory.")
	_check(game.call("_craft_recipe", "campfire"), "A second Campfire should craft when its cost is available.")
	_check(inventory["campfire"] == 2 and inventory["wood"] == 0 and inventory["stone"] == 0, "Repeated Campfire crafting should update its stack and costs.")
	_check(not game.call("_craft_recipe", "campfire"), "A third Campfire should fail without materials.")
	_check(inventory["wood"] >= 0 and inventory["stone"] >= 0, "Failed crafting must never make resource counts negative.")
	print("PASS: Campfire recipe, output count, and repeated crafting")

	inventory["wood"] = 8
	inventory["stone"] = 2
	game.call("_update_crafting_menu")
	_check(craft_buttons["wooden_spear"].disabled == false, "Wooden Spear should be enabled at or above its 4 wood and 1 stone requirements.")
	_check(game.call("_craft_recipe", "wooden_spear"), "The Wooden Spear recipe should craft with sufficient materials.")
	_check(inventory["wood"] == 4 and inventory["stone"] == 1, "Crafting a Spear should deduct 4 wood and 1 stone.")
	_check(game.call("_craft_recipe", "wooden_spear"), "Repeated Spear crafting should work when materials are restored.")
	_check(inventory["wooden_spear"] == 2 and inventory["wood"] == 0 and inventory["stone"] == 0, "Repeated Spear crafting should add one item and deduct its cost each time.")
	_check(not game.call("_craft_recipe", "wooden_spear"), "A Spear should not be granted when its cost is unavailable.")
	_check(inventory["wood"] >= 0 and inventory["stone"] >= 0, "Repeated craft attempts must not produce negative resources.")
	for item in inventory:
		_check(int(inventory[item]) >= 0, "Inventory values must never become negative.")
	print("PASS: Wooden Spear recipe and non-negative inventory")

	var rock: Node3D
	var bush: Node3D
	for child in game.get_children():
		if not child.has_method("gather"):
			continue
		if child.get("display_name") == "Rock" and rock == null:
			rock = child
		elif child.get("display_name") == "Berry bush" and bush == null:
			bush = child
	_check(rock != null and bush != null, "The island should contain gatherable rocks and berry bushes.")
	game.set("nearby_resource", rock)
	game.call("_gather_nearby")
	_check(inventory["stone"] == 1, "Gathering a rock should still add stone.")
	game.set("nearby_resource", bush)
	game.call("_gather_nearby")
	_check(inventory["berries"] == 1, "Gathering a berry bush should still add berries.")
	print("PASS: Stone Axe bonus and existing rock/berry gathering")

	game.get("craft_menu_close_button").pressed.emit()
	_check(not crafting_menu.visible, "The crafting menu should close.")
	await process_frame
	var building_game: Node3D = MAIN_SCENE.instantiate()
	root.add_child(building_game)
	await process_frame
	building_game.get("save_manager").save_path = SAVE_TEST_PATH
	building_game.get("save_manager").delete_save(true)
	await physics_frame
	await _test_building_system(building_game)

	var hunger_before: float = game.get("hunger")
	game.call("_update_survival", 10.0)
	_check(game.get("hunger") < hunger_before, "Hunger should decrease over time.")
	game.call("_update_day_cycle")
	_check(not String(game.get("time_label").text).is_empty(), "The day/night clock should update.")
	await _test_wildlife(game)
	await _test_weather(game, building_game)
	await _test_audio_system(game, building_game)
	await _test_graphics_settings(game)
	await _test_save_system(building_game, game)

	root.remove_child(building_game)
	building_game.free()
	root.remove_child(mobile_viewport)
	mobile_viewport.free()
	await process_frame

	if test_failed:
		push_error("Prototype, crafting, building, wildlife, weather, audio, or save tests failed.")
		quit(1)
	else:
		print("Prototype, crafting, building, wildlife, weather, audio, and save smoke tests passed.")
		quit()


func _check(condition: bool, message: String) -> void:
	if not condition:
		test_failed = true
		push_error("FAIL: %s" % message)


func _test_building_system(game: Node3D) -> void:
	var building_system: Node3D = game.get("building_system")
	var inventory: Dictionary = game.get("inventory")
	var definitions: Dictionary = building_system.get_component_definitions()
	_check(definitions["wooden_foundation"]["cost"] == 6, "Foundation should cost 6 wood.")
	_check(definitions["wooden_wall"]["cost"] == 4, "Wall should cost 4 wood.")
	_check(definitions["wooden_door"]["cost"] == 3, "Door should cost 3 wood.")
	_check(definitions["wooden_roof"]["cost"] == 5, "Roof should cost 5 wood.")

	inventory["wood"] = 5
	var available_ground := Vector3(16.0, 0.0, 0.0)
	var valid_foundation_preview: Dictionary = building_system.get_preview_at("wooden_foundation", available_ground)
	_check(valid_foundation_preview["valid"], "A foundation should preview on gentle solid island ground: %s" % valid_foundation_preview.get("reason", ""))
	var invalid_ground_preview: Dictionary = building_system.get_preview_at("wooden_foundation", Vector3(120.0, 0.0, 120.0))
	_check(not invalid_ground_preview["valid"], "A foundation must reject locations without suitable ground.")
	var invalid_ground_result: Dictionary = building_system.place("wooden_foundation", Vector3(120.0, 0.0, 120.0), 0, inventory)
	_check(not invalid_ground_result["success"] and inventory["wood"] == 5, "Invalid placement must not deduct materials.")
	var insufficient_result: Dictionary = building_system.place("wooden_foundation", available_ground, 0, inventory)
	_check(not insufficient_result["success"], "Foundation placement should fail with insufficient wood.")
	_check(String(insufficient_result["message"]).contains("Need 6 Wood"), "Insufficient placement should explain the missing cost.")
	_check(inventory["wood"] == 5, "Failed placement must not deduct wood.")
	print("PASS: building component costs, valid ground, and insufficient-resource handling")

	var structures_before_cancel: int = building_system.placed_components.size()
	game.get("build_mode_button").pressed.emit()
	_check(game.get("build_mode_active"), "Build Mode button should enter build mode.")
	_check(game.get("build_menu").visible, "Build menu should open with build mode.")
	_check(game.get("joystick_control").visible and game.get("look_control").visible, "Build mode should preserve movement and camera controls.")
	game.get("build_component_buttons")["wooden_foundation"].pressed.emit()
	_check(building_system.preview_root.visible, "Selecting a structure should show a transparent placement preview.")
	game.get("build_cancel_button").pressed.emit()
	_check(not game.get("build_mode_active") and not building_system.preview_root.visible, "Cancel should exit build mode and hide the preview.")
	_check(inventory["wood"] == 5, "Cancelled placement must not deduct resources.")
	_check(building_system.placed_components.size() == structures_before_cancel, "Cancelled placement must not create a structure.")
	print("PASS: build mode UI, preview, preserved controls, and free cancellation")

	inventory["wood"] = 40
	var foundation_result: Dictionary = building_system.place("wooden_foundation", available_ground, 0, inventory)
	_check(foundation_result["success"], "A valid foundation should place successfully.")
	if not foundation_result["success"]:
		return
	var foundation: StaticBody3D = foundation_result["structure"]
	_check(inventory["wood"] == 34, "Foundation placement should deduct exactly 6 wood.")
	_check(_collision_shape_count(foundation) == 1, "Foundation should have a floor collision shape.")
	var foundation_duplicate: Dictionary = building_system.get_preview_at("wooden_foundation", available_ground)
	_check(not foundation_duplicate["valid"], "A second foundation must not overlap an existing foundation.")
	var invalid_wall: Dictionary = building_system.get_preview_at("wooden_wall", Vector3(40.0, 0.0, 40.0))
	_check(not invalid_wall["valid"], "A wall must not float without a supporting foundation.")
	print("PASS: foundation placement, collision, cost deduction, and overlap prevention")

	var wall_target := available_ground + Vector3(0.0, 0.0, -3.0)
	var wall_preview: Dictionary = building_system.get_preview_at("wooden_wall", wall_target)
	_check(wall_preview["valid"], "Wall should snap to a foundation edge.")
	_check(is_equal_approx(wall_preview["position"].y, foundation.position.y + 0.30), "Wall should sit on, not float above, the foundation.")
	var rotated_wall_preview: Dictionary = building_system.get_preview_at("wooden_wall", wall_target, 1)
	_check(rotated_wall_preview["valid"] and rotated_wall_preview["edge_name"] == "east", "Wall rotation should select the adjacent foundation edge.")
	var wall_result: Dictionary = building_system.place("wooden_wall", wall_target, 0, inventory)
	_check(wall_result["success"], "A wall should place at its snapped foundation edge.")
	var wall: StaticBody3D = wall_result["structure"]
	_check(inventory["wood"] == 30, "Wall placement should deduct exactly 4 wood.")
	_check(_collision_shape_count(wall) == 1, "Wall should block the player with a collision shape.")
	_check(not building_system.get_preview_at("wooden_wall", wall_target)["valid"], "Duplicate walls must not overlap in one edge slot.")

	var unsupported_door: Dictionary = building_system.get_preview_at(
		"wooden_door",
		available_ground + Vector3(0.0, 0.0, 3.0)
	)
	_check(not unsupported_door["valid"], "A doorway must be supported by an adjacent wall.")
	var unsupported_roof: Dictionary = building_system.get_preview_at("wooden_roof", available_ground)
	_check(not unsupported_roof["valid"], "A roof must not float before enough walls are built.")
	var blocked_door: Dictionary = building_system.get_preview_at("wooden_door", wall_target)
	_check(not blocked_door["valid"], "A door must not overlap a wall occupying that opening.")
	print("PASS: wall snapping, rotation, collision, and door-opening validation")

	var door_target := available_ground + Vector3(3.0, 0.0, 0.0)
	var door_preview: Dictionary = building_system.get_preview_at("wooden_door", door_target)
	_check(door_preview["valid"], "A door should fit the adjacent unoccupied foundation edge.")
	var door_result: Dictionary = building_system.place("wooden_door", door_target, 0, inventory)
	_check(door_result["success"], "A valid doorway should place successfully.")
	var door: StaticBody3D = door_result["structure"]
	_check(inventory["wood"] == 27, "Door placement should deduct exactly 3 wood.")
	_check(_collision_shape_count(door) == 4, "Door frame and access ramp should have matching collision shapes.")
	_check(not building_system.get_preview_at("wooden_door", door_target)["valid"], "A second door must not occupy the same opening.")

	var roof_preview: Dictionary = building_system.get_preview_at("wooden_roof", available_ground)
	_check(roof_preview["valid"], "Roof should snap above the foundation after walls are built.")
	var roof_result: Dictionary = building_system.place("wooden_roof", available_ground, 0, inventory)
	_check(roof_result["success"], "A supported roof should place successfully.")
	var roof: StaticBody3D = roof_result["structure"]
	_check(inventory["wood"] == 22, "Roof placement should deduct exactly 5 wood.")
	_check(_collision_shape_count(roof) == 2, "Roof panels should have matching collision shapes.")
	_check(not building_system.get_preview_at("wooden_roof", available_ground)["valid"], "A duplicate roof must not overlap.")

	await physics_frame
	var space := game.get_world_3d().direct_space_state
	var door_crossing := PhysicsRayQueryParameters3D.create(
		Vector3(door.global_position.x - 2.0, door.global_position.y + 1.0, door.global_position.z),
		Vector3(door.global_position.x + 2.0, door.global_position.y + 1.0, door.global_position.z),
		1,
		[game.get("player").get_rid()]
	)
	_check(space.intersect_ray(door_crossing).is_empty(), "The doorway center should remain an open passage.")
	var wall_crossing := PhysicsRayQueryParameters3D.create(
		Vector3(wall.global_position.x, wall.global_position.y + 1.35, wall.global_position.z - 2.0),
		Vector3(wall.global_position.x, wall.global_position.y + 1.35, wall.global_position.z + 2.0),
		1,
		[game.get("player").get_rid()]
	)
	_check(space.intersect_ray(wall_crossing).get("collider") == wall, "A placed wall should block passage with its collision.")
	print("PASS: door and roof placement, costs, collisions, and accessible doorway")

	_check(
		not building_system.is_position_sheltered(foundation.global_position + Vector3(0.0, 0.31, 0.0)),
		"A roof and partial walls must not provide shelter protection."
	)
	var edge_offsets: Array[Vector3] = [
		Vector3(0.0, 0.3, -1.9),
		Vector3(1.9, 0.3, 0.0),
		Vector3(0.0, 0.3, 1.9),
		Vector3(-1.9, 0.3, 0.0)
	]
	for edge_offset in edge_offsets:
		var edge_target: Vector3 = foundation.global_position + edge_offset
		var edge_preview: Dictionary = building_system.get_preview_at("wooden_wall", edge_target)
		if edge_preview["valid"]:
			var enclosure_result: Dictionary = building_system.place("wooden_wall", edge_target, 0, inventory)
			_check(enclosure_result["success"], "Remaining shelter walls should place successfully.")
	_check(
		building_system.is_position_sheltered(foundation.global_position + Vector3(0.0, 0.31, 0.0)),
		"A roofed foundation with all perimeter edges and a door must provide shelter protection."
	)
	print("PASS: shelter protection requires a roofed, enclosed foundation with a doorway")

	var wildlife_system: Node3D = game.get("wildlife_system")
	var wildlife: Array[CharacterBody3D] = wildlife_system.get_animals()
	var walking_animal: CharacterBody3D = wildlife[0]
	var start_z := wall.global_position.z - 5.0
	var animal_ground: Dictionary = building_system.call(
		"_raycast_ground",
		Vector3(wall.global_position.x, 0.0, start_z)
	)
	walking_animal.global_position = animal_ground["position"] + Vector3.UP * 0.04
	walking_animal.call("_set_state", 1)
	walking_animal.set("state_elapsed", 0.0)
	walking_animal.set("state_duration", 20.0)
	walking_animal.set(
		"wander_target",
		Vector3(wall.global_position.x, wall.global_position.y, wall.global_position.z + 1.5)
	)
	for frame_index in range(100):
		await physics_frame
	_check(walking_animal.global_position.z > start_z + 0.5, "An animal should move along the ground toward a target.")
	_check(walking_animal.global_position.z < wall.global_position.z, "An animal should not walk through a solid shelter wall.")
	print("PASS: animal movement and solid shelter collision")

	var player: CharacterBody3D = game.get("player")
	player.position = Vector3(door.global_position.x - 2.0, foundation.position.y + 0.31, door.global_position.z)
	player.set_move_input(Vector2(1.0, 0.0))
	for frame_index in range(60):
		await physics_frame
	_check(player.global_position.x > door.global_position.x + 0.4, "Player should exit through the open doorway.")
	player.set_move_input(Vector2(-1.0, 0.0))
	for frame_index in range(60):
		await physics_frame
	_check(player.global_position.x < door.global_position.x - 0.4, "Player should re-enter through the open doorway.")
	player.set_move_input(Vector2.ZERO)
	print("PASS: player enters and exits through the shelter doorway")


func _test_weather(game: Node3D, sheltered_game: Node3D) -> void:
	var weather: Node3D = game.get("weather_system")
	_check(is_instance_valid(weather), "The main scene should initialize a weather manager.")
	if not is_instance_valid(weather):
		return

	var weather_names := ["SUNNY", "CLOUDY", "RAINY", "STORM"]
	for weather_name in weather_names:
		_check(weather.set_weather(weather_name, 0.1), "Weather state %s should be selectable." % weather_name)
		weather.call("_process", 0.1)
		weather.call("_process", 0.1)
		_check(weather.get_weather_name() == weather_name, "Weather state should update to %s." % weather_name)
		_check(weather.get("transition_remaining") == 0.0, "Weather transition to %s should complete smoothly." % weather_name)

	var cloud_layer: MultiMeshInstance3D = weather.get("cloud_layer")
	var rain_particles: GPUParticles3D = weather.get("rain_particles")
	var lightning_root: Node3D = weather.get("lightning_root")
	var lightning_light: OmniLight3D = weather.get("lightning_light")
	_check(cloud_layer.multimesh.instance_count == 8, "Cloud effects should use the capped procedural multimesh.")
	_check(rain_particles.amount == 360, "Rain particles should stay within the mobile particle budget.")
	_check(rain_particles.emitting, "Rain should initialize and emit in rainy weather.")
	_check(lightning_root.get_child_count() == 8, "Storm lightning should initialize procedural segments and a flash light.")
	weather.call("_trigger_lightning")
	_check(lightning_root.visible and lightning_light.light_energy > 0.0, "Storm lightning should show a flash.")

	weather.set("automatic_weather_enabled", true)
	weather.set("weather_remaining", 0.0)
	weather.call("_process", 0.1)
	_check(weather.get_weather_name() != "STORM", "Automatic weather should transition after its duration expires.")

	weather.set("temperature", 24.0)
	weather.set("is_player_sheltered", false)
	weather.set_weather("STORM", 0.1)
	for frame_index in range(20):
		weather.call("_process", 0.25)
	_check(weather.get("temperature") < 24.0, "Storm exposure should gradually lower temperature.")
	_check(weather.get("temperature") >= 0.0, "Temperature should remain non-negative.")
	game.call("_update_hud")
	_check(
		String(game.get("weather_status_label").text).contains("STORM")
		or String(game.get("weather_status_label").text).contains("RAIN"),
		"Weather HUD should display the active weather and temperature."
	)

	var mobile_viewport: SubViewport = game.get_parent()
	var weather_panel: Control = game.get("weather_status_panel")
	for viewport_size in [Vector2i(360, 800), Vector2i(800, 450)]:
		mobile_viewport.size = viewport_size
		await process_frame
		var panel_rect := weather_panel.get_global_rect()
		_check(panel_rect.position.x >= 0.0 and panel_rect.end.x <= viewport_size.x, "Weather HUD should fit a mobile viewport width.")
		_check(panel_rect.position.y >= 0.0 and panel_rect.end.y <= viewport_size.y, "Weather HUD should fit a mobile viewport height.")
	game.get("craft_menu_button").pressed.emit()
	await process_frame
	_check(not weather_panel.visible, "Weather HUD should hide while the crafting menu is open.")
	game.get("craft_menu_close_button").pressed.emit()
	game.get("build_mode_button").pressed.emit()
	_check(not weather_panel.visible, "Weather HUD should hide while Build Mode is open.")
	game.get("build_cancel_button").pressed.emit()

	var protected_weather: Node3D = sheltered_game.get("weather_system")
	var shelter_building: Node3D = sheltered_game.get("building_system")
	var shelter_foundation: StaticBody3D = shelter_building.get("foundations").values()[0]
	var protected_player: CharacterBody3D = sheltered_game.get("player")
	protected_player.global_position = shelter_foundation.global_position + Vector3(0.0, 0.31, 0.0)
	protected_weather.call("refresh_shelter_state")
	_check(protected_weather.get("is_player_sheltered"), "A player inside a completed shelter should be protected.")
	protected_weather.set("temperature", 20.0)
	for frame_index in range(20):
		protected_weather.call("_process", 0.25)
	_check(protected_weather.get("temperature") > 20.0, "Shelter should prevent cold exposure and move temperature toward a safe value.")
	shelter_building.get("roof_occupancy").clear()
	protected_weather.call("refresh_shelter_state")
	_check(not protected_weather.get("is_player_sheltered"), "Removing a roof must remove shelter protection.")
	print("PASS: weather states, transitions, effects, temperature, shelter protection, HUD, and mobile layout")


func _test_audio_system(game: Node3D, building_game: Node3D) -> void:
	var manager: Node = game.get("audio_manager")
	_check(is_instance_valid(manager), "The game should initialize its AudioManager.")
	if not is_instance_valid(manager):
		return

	_check(manager.get("world_voices").size() == 12, "AudioManager should use a bounded pool of 3D voices.")
	_check(manager.get("ui_voices").size() == 3, "AudioManager should use a bounded pool of UI voices.")
	for bus_name in ["Music", "Environment", "SFX"]:
		_check(AudioServer.get_bus_index(bus_name) >= 0, "Audio bus %s should exist." % bus_name)
	_check(
		not manager.play_event("wood_chop", Vector3.ZERO),
		"Missing licensed wood-chop audio should fail safely instead of synthesizing a replacement."
	)
	_check(manager.play_ui("ui_click"), "Known UI sounds should play through the UI voice pool.")
	_check(not manager.play_event("not_a_sound", Vector3.ZERO), "Unknown sound names should fail safely.")
	_check(not manager.play_ui("not_a_sound"), "Unknown UI sound names should fail safely.")

	var asset_report: Dictionary = manager.get_missing_asset_report()
	var sound_names: Array = manager.get_sound_names()
	_check(sound_names.size() >= 35, "The sound manifest should include the requested sound categories.")
	_check(asset_report.size() == sound_names.size(), "Every sound event and ambience loop should have an asset status.")
	var integrated_asset_count := 0
	var unique_asset_paths: Dictionary = {}
	for asset_name in asset_report:
		var asset_entry: Dictionary = asset_report[asset_name]
		_check(
			asset_entry["status"] in ["integrated", "surrogate", "fallback", "pending", "missing_file"],
			"Every sound should be marked integrated, surrogate, fallback, or pending."
		)
		_check(asset_entry["status"] != "missing_file", "No configured audio asset should be missing from the project.")
		for asset_path in asset_entry["files"]:
			integrated_asset_count += 1
			unique_asset_paths[asset_path] = true
			_check(ResourceLoader.exists(asset_path), "Licensed audio file %s should exist." % asset_path)
			var stream: AudioStream = manager.call("_load_audio_asset", asset_path)
			_check(stream is AudioStreamOggVorbis, "Real asset %s should load as OGG audio." % asset_path)
	var variation_fallback: AudioStream = manager.call(
		"_load_first_available",
		[
			"res://assets/audio/oculus/missing-test-asset.ogg",
			"res://assets/audio/oculus/FEETHmn_ShoeGrassRun_OS_01.ogg"
		]
	)
	_check(
		variation_fallback is AudioStreamOggVorbis,
		"Missing variation files should fall through to the next real licensed take."
	)
	_check(integrated_asset_count >= 20, "The project should include a meaningful set of real audio assets.")
	_check(unique_asset_paths.size() == 22, "All 22 bundled licensed OGG files should be referenced by the audio manager.")
	_check(asset_report["deer_call"]["status"] == "pending", "Unavailable animal calls should remain pending, not use unrelated samples.")
	_check(asset_report["thunder"]["status"] == "pending", "Unavailable thunder should remain pending.")
	_check(asset_report["storm_rain"]["status"] == "fallback", "Storm rain should disclose its real light-rain fallback.")
	_check(
		asset_report["storm_rain"]["files"] == asset_report["light_rain"]["files"],
		"Storm rain fallback should reuse the disclosed real foliage-rain recording."
	)
	for loop_name in manager.get("ambience_players"):
		var ambience_player: AudioStreamPlayer = manager.get("ambience_players")[loop_name]
		if asset_report[loop_name]["status"] == "pending":
			_check(ambience_player.stream == null, "Pending ambience %s should not use generated audio." % loop_name)
		else:
			_check(
				ambience_player.stream is AudioStreamOggVorbis,
				"Ambience loop %s should use a licensed OGG stream." % loop_name
			)
			var ogg_loop: AudioStreamOggVorbis = ambience_player.stream as AudioStreamOggVorbis
			_check(ogg_loop.loop, "Ambience loop %s should loop continuously." % loop_name)

	_check(manager.get("weather_name") == "STORM", "Weather changes should reach the AudioManager.")
	game.call("_update_day_cycle")
	var elapsed_game_time: float = game.get("elapsed_game_time")
	var day_length_seconds: float = game.get("day_length_seconds")
	var expected_day_phase := fposmod(elapsed_game_time / day_length_seconds, 1.0)
	_check(
		manager.get("day_phase") == expected_day_phase,
		"Day/night phase should synchronize with the AudioManager."
	)
	_check(manager.get_play_attempt_count("wood_chop") > 0, "Successful wood gathering should retain its pending chopping-audio hook.")
	_check(manager.get_play_attempt_count("stone_hit") > 0, "Successful rock gathering should retain its pending stone-audio hook.")
	_check(manager.get_resolved_play_count("craft_axe") > 0, "Successful crafting should resolve to the real UI-confirmation fallback.")
	_check(manager.get_resolved_play_count("action_fail") > 0, "Failed gameplay actions should resolve to real error UI feedback.")
	_check(manager.get_play_attempt_count("lightning") > 0, "Storm lightning should retain its pending positional-audio hook.")
	var building_audio: Node = building_game.get("audio_manager")
	_check(
		building_audio.get_resolved_play_count("build_foundation") > 0,
		"Successful foundation placement should resolve to the real wooden-impact fallback."
	)
	var animals: Array = game.get("wildlife_system").get_animals()
	var wildlife_sound_count: int = (
		int(manager.get_play_attempt_count("deer_alert"))
		+ int(manager.get_play_attempt_count("deer_flee"))
		+ int(manager.get_play_attempt_count("boar_growl"))
		+ int(manager.get_play_attempt_count("boar_defend"))
		+ int(manager.get_play_attempt_count("deer_step"))
		+ int(manager.get_play_attempt_count("boar_step"))
	)
	_check(not animals.is_empty() and wildlife_sound_count > 0, "Wildlife state or movement changes should retain their positional-audio hooks.")

	_check(
		manager.play_event("footstep_grass", Vector3.ZERO, 0),
		"An integrated real footstep should play through the 3D voice pool."
	)
	var world_voices: Array = manager.get("world_voices")
	var active_voice: AudioStreamPlayer3D
	for voice in world_voices:
		if voice.stream is AudioStreamOggVorbis:
			active_voice = voice
			break
	if manager.get("audio_output_available"):
		_check(active_voice != null, "A world sound should be active before testing application pause.")
	manager.pause_audio(true)
	if manager.get("audio_output_available"):
		_check(active_voice != null and active_voice.stream_paused, "Audio playback should pause with the application.")
	else:
		_check(manager.get("audio_paused"), "AudioManager should track the paused application state.")
	manager.pause_audio(false)
	if manager.get("audio_output_available"):
		_check(active_voice != null and not active_voice.stream_paused, "Audio playback should resume with the application.")
	else:
		_check(not manager.get("audio_paused"), "AudioManager should track the resumed application state.")

	var saved_volumes: Dictionary = {}
	var saved_mutes: Dictionary = {}
	for bus_name in ["Master", "Music", "Environment", "SFX"]:
		saved_volumes[bus_name] = manager.get_bus_volume(bus_name)
		saved_mutes[bus_name] = manager.is_bus_muted(bus_name)
	manager.settings_path = AUDIO_SETTINGS_TEST_PATH
	var test_settings_absolute_path := ProjectSettings.globalize_path(AUDIO_SETTINGS_TEST_PATH)
	if FileAccess.file_exists(AUDIO_SETTINGS_TEST_PATH):
		DirAccess.remove_absolute(test_settings_absolute_path)

	game.call("_set_main_menu_open", true)
	game.get("audio_settings_button").pressed.emit()
	await process_frame
	var settings_panel: Control = game.get("audio_settings_panel")
	_check(settings_panel.visible, "Audio settings should open from the mobile main menu.")
	for viewport_size in [Vector2i(360, 800), Vector2i(800, 450)]:
		game.get_parent().size = viewport_size
		await process_frame
		var panel_rect := settings_panel.get_global_rect()
		_check(panel_rect.position.x >= 0.0 and panel_rect.end.x <= viewport_size.x, "Audio settings should fit the viewport width.")
		_check(panel_rect.position.y >= 0.0 and panel_rect.end.y <= viewport_size.y, "Audio settings should fit the viewport height.")
		var settings_column: VBoxContainer = settings_panel.get_child(0)
		for row_index in range(1, 5):
			var settings_row: Control = settings_column.get_child(row_index)
			var row_rect := settings_row.get_global_rect()
			_check(row_rect.position.x >= panel_rect.position.x and row_rect.end.x <= panel_rect.end.x, "Audio setting controls should fit inside the panel.")
		for setting_control in settings_column.get_children():
			var control_rect: Rect2 = setting_control.get_global_rect()
			_check(
				control_rect.position.y >= panel_rect.position.y and control_rect.end.y <= panel_rect.end.y,
				"Every audio and graphics setting row should fit inside the panel."
			)
	_check(game.get("audio_sliders").size() == 4 and game.get("audio_mute_buttons").size() == 4, "Master and all three audio buses should have volume and mute controls.")
	var master_slider: HSlider = game.get("audio_sliders")["Master"]
	master_slider.value = 0.63
	_check(is_equal_approx(manager.get_bus_volume("Master"), 0.63), "The master volume slider should update its audio bus.")
	var master_mute: CheckButton = game.get("audio_mute_buttons")["Master"]
	master_mute.set_pressed_no_signal(true)
	master_mute.toggled.emit(true)
	_check(manager.is_bus_muted("Master"), "The master mute control should mute the audio bus.")
	master_mute.set_pressed_no_signal(false)
	master_mute.toggled.emit(false)
	_check(not manager.is_bus_muted("Master"), "The master mute control should unmute the audio bus.")
	var test_settings := ConfigFile.new()
	_check(test_settings.load(AUDIO_SETTINGS_TEST_PATH) == OK, "Audio settings should persist locally in a ConfigFile.")
	_check(
		is_equal_approx(float(test_settings.get_value("audio", "Master_volume", -1.0)), 0.63),
		"Persisted audio settings should contain the selected master volume."
	)

	for bus_name in ["Master", "Music", "Environment", "SFX"]:
		manager.set_bus_volume(bus_name, float(saved_volumes[bus_name]))
		manager.set_bus_muted(bus_name, bool(saved_mutes[bus_name]))
	if FileAccess.file_exists(AUDIO_SETTINGS_TEST_PATH):
		DirAccess.remove_absolute(test_settings_absolute_path)
	game.get("audio_settings_back_button").pressed.emit()
	game.call("_set_main_menu_open", false)
	game.get_parent().size = Vector2i(360, 800)
	print("PASS: real audio assets, missing-asset handling, gameplay hooks, settings, pause/resume, and mobile layout")


func _test_graphics_settings(game: Node3D) -> void:
	var manager: Node = game.get("graphics_settings")
	var weather: Node = game.get("weather_system")
	manager.settings_path = GRAPHICS_SETTINGS_TEST_PATH
	if FileAccess.file_exists(GRAPHICS_SETTINGS_TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GRAPHICS_SETTINGS_TEST_PATH))

	for profile_name in GRAPHICS_SETTINGS_SCRIPT.PROFILES:
		_check(manager.set_profile(String(profile_name)), "Each supported graphics profile should apply.")
		_check(manager.get("profile") == profile_name, "The selected graphics profile should be tracked.")
		var profile_settings: Dictionary = GRAPHICS_SETTINGS_SCRIPT.PROFILE_SETTINGS[profile_name]
		var saved_rain_amount: float = weather.rain_amount
		var saved_wind_strength: float = weather.wind_strength
		weather.rain_amount = 1.0
		weather.wind_strength = 1.0
		weather.call("_apply_visuals")
		_check(
			is_equal_approx(weather.rain_particles.amount_ratio, float(profile_settings["rain_quality"])),
			"Graphics profiles should scale the weather particle workload."
		)
		weather.rain_amount = saved_rain_amount
		weather.wind_strength = saved_wind_strength
		weather.call("_apply_visuals")
		_check(
			game.get("sun").shadow_enabled == (profile_name != "low"),
			"Low graphics should disable sun shadows and other profiles should retain them."
		)
		_check(
			is_equal_approx(float(game.get("wildlife_system").ai_update_interval), float(profile_settings["ai_interval"])),
			"Graphics profiles should adjust wildlife decision update intervals."
		)
		_check(Engine.max_fps == int(profile_settings["fps_cap"]), "Graphics profiles should apply their frame-rate cap.")

	game.call("_set_main_menu_open", true)
	game.get("audio_settings_button").pressed.emit()
	await process_frame
	var settings_panel: Control = game.get("audio_settings_panel")
	var profile_option: OptionButton = game.get("graphics_profile_option")
	var fps_toggle: CheckButton = game.get("fps_monitor_toggle")
	for viewport_size in [Vector2i(360, 800), Vector2i(800, 450)]:
		game.get_parent().size = viewport_size
		await process_frame
		var panel_rect := settings_panel.get_global_rect()
		for control in [profile_option, fps_toggle]:
			var control_rect: Rect2 = control.get_global_rect()
			_check(
				control_rect.position.x >= panel_rect.position.x and control_rect.end.x <= panel_rect.end.x
				and control_rect.position.y >= panel_rect.position.y and control_rect.end.y <= panel_rect.end.y,
				"Graphics controls should remain inside the audio/graphics settings panel."
			)
	profile_option.item_selected.emit(GRAPHICS_SETTINGS_SCRIPT.PROFILES.find("high"))
	_check(manager.get("profile") == "high", "The graphics selector should apply the selected quality profile.")
	fps_toggle.set_pressed_no_signal(true)
	fps_toggle.toggled.emit(true)
	game.call("_process", 0.5)
	_check(manager.get("fps_monitor_enabled"), "The FPS toggle should enable the monitor.")
	_check(game.get("fps_monitor_label").visible, "Enabling FPS should show its HUD readout.")
	_check(String(game.get("fps_monitor_label").text).begins_with("FPS: "), "The FPS readout should display the measured frame rate.")

	var restored_settings: Node = GRAPHICS_SETTINGS_SCRIPT.new()
	restored_settings.settings_path = GRAPHICS_SETTINGS_TEST_PATH
	root.add_child(restored_settings)
	await process_frame
	_check(restored_settings.get("profile") == "high", "The graphics profile should persist across manager initialization.")
	_check(restored_settings.get("fps_monitor_enabled"), "The FPS monitor preference should persist across manager initialization.")
	restored_settings.queue_free()

	profile_option.item_selected.emit(GRAPHICS_SETTINGS_SCRIPT.PROFILES.find("medium"))
	fps_toggle.set_pressed_no_signal(false)
	fps_toggle.toggled.emit(false)
	game.call("_set_main_menu_open", false)
	game.get_parent().size = Vector2i(360, 800)
	if FileAccess.file_exists(GRAPHICS_SETTINGS_TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GRAPHICS_SETTINGS_TEST_PATH))
	print("PASS: Low/Medium/High profiles, persisted settings, FPS toggle, and portrait/landscape settings layout")


func _test_save_system(game: Node3D, mobile_game: Node3D) -> void:
	var save_manager: RefCounted = game.get("save_manager")
	mobile_game.get("save_manager").save_path = SAVE_TEST_PATH
	var mobile_viewport: SubViewport = mobile_game.get_parent()
	mobile_viewport.size = Vector2i(360, 800)
	await process_frame
	_check(is_instance_valid(save_manager), "The game should initialize its local save manager.")
	if not is_instance_valid(save_manager):
		return
	save_manager.delete_save(true)
	mobile_game.call("_set_main_menu_open", true)
	await process_frame
	_check(mobile_game.get("continue_game_button").disabled, "Continue Game should be disabled when no valid save exists.")
	var menu_rect: Rect2 = mobile_game.get("main_menu").get_global_rect()
	_check(menu_rect.position.x >= 0.0 and menu_rect.end.x <= 360.0, "Main Menu should fit within a portrait mobile viewport.")
	_check(menu_rect.position.y >= 0.0 and menu_rect.end.y <= 800.0, "Main Menu should fit within a portrait mobile viewport.")
	mobile_viewport.size = Vector2i(800, 450)
	await process_frame
	menu_rect = mobile_game.get("main_menu").get_global_rect()
	_check(menu_rect.position.x >= 0.0 and menu_rect.end.x <= 800.0, "Main Menu should fit within a landscape mobile viewport.")
	_check(menu_rect.position.y >= 0.0 and menu_rect.end.y <= 450.0, "Main Menu should fit within a landscape mobile viewport.")
	var menu_panel: Control = mobile_game.get("main_menu").get_child(1)
	var menu_column: VBoxContainer = menu_panel.get_child(0)
	for button_index in range(4, menu_column.get_child_count()):
		var menu_button: Button = menu_column.get_child(button_index)
		_check(menu_button.get_global_rect().size.y >= 44.0, "Main Menu actions should have touch-friendly target heights.")
		_check(
			menu_button.get_global_rect().position.y >= menu_panel.get_global_rect().position.y
			and menu_button.get_global_rect().end.y <= menu_panel.get_global_rect().end.y,
			"Main Menu actions should fit inside the panel in landscape."
		)
	mobile_viewport.size = Vector2i(360, 800)
	await process_frame
	mobile_game.call("_set_main_menu_open", false)

	var player: CharacterBody3D = game.get("player")
	player.global_position = Vector3(11.25, 2.4, -7.5)
	player.global_rotation = Vector3(0.0, 0.72, 0.0)
	player.camera_pivot.rotation.x = 0.24
	game.set("health", 67.0)
	game.set("hunger", 48.0)
	game.set("thirst", 29.0)
	game.set("elapsed_game_time", 86.5)
	game.set("survival_tick", 0.65)
	var inventory: Dictionary = game.get("inventory")
	inventory.assign({
		"wood": 21,
		"fiber": 7,
		"stone": 8,
		"berries": 4,
		"stone_axe": 2,
		"campfire": 1,
		"wooden_spear": 3
	})

	var weather: Node3D = game.get("weather_system")
	weather.set_weather("STORM", 2.0)
	weather.call("_process", 0.5)
	weather.set("temperature", 17.4)
	weather.set("weather_remaining", 25.0)

	var resource_id := ""
	for child in game.get_children():
		if child.get_script() == HARVESTABLE_SCRIPT:
			resource_id = String(child.get("resource_id"))
			child.set("gathers_left", 1)
			break
	_check(not resource_id.is_empty(), "A stable resource should be available for save testing.")

	var wildlife_system: Node3D = game.get("wildlife_system")
	var animals: Array[CharacterBody3D] = wildlife_system.get_animals()
	var saved_animal_position := animals[0].global_position + Vector3(1.0, 0.0, 0.0)
	var saved_animal_type: String = animals[0].animal_type
	animals[0].global_position = saved_animal_position
	animals[0].restore_saved_state("WANDER")
	var original_structure_count: int = game.get("building_system").placed_components.size()
	_check(original_structure_count >= 6, "Shelter structures should exist before saving.")
	_check(game.call("_save_current_game", false), "Saving a valid game should create a JSON save.")
	_check(save_manager.has_save_file() and save_manager.has_valid_save(), "A completed save should exist and validate.")

	var loaded: Dictionary = save_manager.load_game()
	_check(loaded["success"], "The newly written save should load.")
	var persisted_text_file := FileAccess.open(SAVE_TEST_PATH, FileAccess.READ)
	if persisted_text_file == null:
		_check(false, "The created JSON save should be readable.")
		return
	var valid_save_text := persisted_text_file.get_as_text()
	persisted_text_file.close()
	_check(
		not save_manager.save_game({"format_version": 1})["success"],
		"Invalid data must not be written over a valid save."
	)
	var after_invalid_save_file := FileAccess.open(SAVE_TEST_PATH, FileAccess.READ)
	_check(
		after_invalid_save_file.get_as_text() == valid_save_text,
		"Rejecting invalid save data must preserve the previous valid file."
	)
	after_invalid_save_file.close()

	mobile_game.call("_set_main_menu_open", true)
	_check(not mobile_game.get("continue_game_button").disabled, "Continue Game should enable for a valid save.")
	mobile_game.get("continue_game_button").pressed.emit()
	_check(not mobile_game.get("main_menu").visible, "Continue Game should close the menu after loading.")
	_check(
		mobile_game.get("player").global_position.distance_to(Vector3(11.25, 2.4, -7.5)) < 0.01,
		"Continue Game should restore player state through its menu action."
	)
	player.global_position = Vector3.ZERO
	game.set("health", 100.0)
	game.set("hunger", 100.0)
	game.set("thirst", 100.0)
	inventory["wood"] = 0
	game.set("elapsed_game_time", 0.0)
	game.get("building_system").restore_save_data([])
	wildlife_system.restore_save_data([])
	weather.set_weather("SUNNY", 0.1)
	for child in game.get_children():
		if child.get_script() == HARVESTABLE_SCRIPT:
			child.set("gathers_left", 0)
			child.hide()

	_check(game.call("_restore_save_data", loaded["data"]), "A valid save should restore all supported game state.")
	_check(player.global_position.distance_to(Vector3(11.25, 2.4, -7.5)) < 0.01, "Saved player position should be restored.")
	_check(absf(player.rotation.y - 0.72) < 0.01, "Saved player rotation should be restored.")
	_check(absf(player.camera_pivot.rotation.x - 0.24) < 0.01, "Saved camera pitch should be restored.")
	_check(game.get("health") == 67.0 and game.get("hunger") == 48.0 and game.get("thirst") == 29.0, "Survival meters should be restored.")
	_check(inventory["wood"] == 21 and inventory["stone_axe"] == 2, "Inventory resources and crafted items should be restored.")
	_check(game.get("elapsed_game_time") == 86.5 and game.get("survival_tick") == 0.65, "Day/night and survival progress should be restored.")
	_check(weather.get_weather_name() == "STORM" and absf(weather.get("temperature") - 17.4) < 0.01, "Weather state and temperature should be restored.")
	_check(absf(weather.get("weather_remaining") - 25.0) < 0.01, "Remaining weather duration should be restored.")
	_check(
		absf(weather.get("transition_remaining") - float(loaded["data"]["world"]["weather"]["transition_remaining"])) < 0.01,
		"In-progress weather transition should be restored."
	)
	_check(game.get("building_system").placed_components.size() == original_structure_count, "All shelter structures should be restored.")
	var restored_structure_data: Array[Dictionary] = game.get("building_system").get_save_data()
	for structure_index in range(restored_structure_data.size()):
		var saved_structure: Dictionary = loaded["data"]["world"]["structures"][structure_index]
		var restored_structure: Dictionary = restored_structure_data[structure_index]
		_check(
			restored_structure["component_id"] == saved_structure["component_id"]
			and _array_to_vector(restored_structure["position"]).distance_to(_array_to_vector(saved_structure["position"])) < 0.01
			and _array_to_vector(restored_structure["rotation"]).distance_to(_array_to_vector(saved_structure["rotation"])) < 0.01,
			"Restored shelter components should preserve their types, world positions, and rotations."
		)
	for structure in game.get("building_system").placed_components:
		_check(_collision_shape_count(structure) > 0, "Restored shelter structures should regain their collision shapes.")
	_check(wildlife_system.get_animals().size() == animals.size(), "Wildlife count should be restored.")
	var restored_animal: CharacterBody3D = wildlife_system.get_animals()[0]
	_check(restored_animal.animal_type == saved_animal_type, "Wildlife type should be restored.")
	_check(restored_animal.global_position.distance_to(saved_animal_position) < 0.01, "Wildlife position should be restored.")
	_check(restored_animal.get_state_name() == "WANDER", "Wildlife AI state should be restored.")
	var restored_resource: Node3D
	for child in game.get_children():
		if child.get_script() == HARVESTABLE_SCRIPT and child.get("resource_id") == resource_id:
			restored_resource = child
			break
	_check(restored_resource != null and restored_resource.get("gathers_left") == 1, "Resource depletion progress should be restored.")
	var restored_foundation: StaticBody3D = game.get("building_system").foundations.values()[0]
	player.global_position = restored_foundation.global_position + Vector3(0.0, 0.31, 0.0)
	weather.call("refresh_shelter_state")
	_check(weather.get("is_player_sheltered"), "Restored complete shelters should continue to protect the player.")
	print("PASS: JSON save creation, player/inventory/survival/world/shelter/wildlife restoration")

	inventory["wood"] = 99
	game.set("autosave_interval", 0.1)
	game.set("autosave_elapsed", 0.0)
	game.call("_process", 0.2)
	var autosaved: Dictionary = save_manager.load_game()
	_check(autosaved["success"] and autosaved["data"]["inventory"]["wood"] == 99, "Autosave should persist gameplay changes at its configured interval.")
	print("PASS: interval autosave")

	var corrupted_file := FileAccess.open(SAVE_TEST_PATH, FileAccess.WRITE)
	corrupted_file.store_string("{not valid json")
	corrupted_file.close()
	_check(not save_manager.load_game()["success"], "Corrupted JSON should fail safely.")
	_check(not save_manager.has_valid_save(), "A corrupted save must not enable Continue Game.")
	mobile_game.call("_set_main_menu_open", true)
	_check(mobile_game.get("continue_game_button").disabled, "Continue Game should disable for corrupted JSON.")
	mobile_game.call("_set_main_menu_open", false)

	var unsupported_file := FileAccess.open(SAVE_TEST_PATH, FileAccess.WRITE)
	unsupported_file.store_string(JSON.stringify({"format_version": 99}))
	unsupported_file.close()
	_check(not save_manager.load_game()["success"], "An unsupported save version should be rejected.")
	_check(not save_manager.delete_save(false)["success"], "Save deletion should require explicit confirmation.")
	_check(save_manager.has_save_file(), "Unconfirmed deletion must leave the save file intact.")
	mobile_game.call("_set_main_menu_open", true)
	mobile_game.call("_request_save_deletion")
	mobile_game.get("delete_confirmation_dialog").confirmed.emit()
	_check(not save_manager.has_save_file(), "Confirming Delete Save should remove the local file.")
	_check(not save_manager.load_game()["success"], "Loading a missing save should return a safe failure.")
	_check(mobile_game.get("continue_game_button").disabled, "Continue Game should remain disabled after save deletion.")
	mobile_game.call("_set_main_menu_open", false)
	print("PASS: missing/corrupt/version validation, confirmed deletion, and Continue availability")


func _test_wildlife(game: Node3D) -> void:
	var wildlife_system: Node3D = game.get("wildlife_system")
	_check(is_instance_valid(wildlife_system), "The main scene should initialize its wildlife system.")
	if not is_instance_valid(wildlife_system):
		return
	var animals: Array[CharacterBody3D] = wildlife_system.get_animals()
	var deer: Array[CharacterBody3D] = wildlife_system.get_animals_of_type("deer")
	var boars: Array[CharacterBody3D] = wildlife_system.get_animals_of_type("wild_boar")
	_check(animals.size() == 4, "Wildlife should spawn a small fixed group of four animals.")
	_check(deer.size() == 2 and boars.size() == 2, "Wildlife should include two deer and two wild boars.")
	if deer.is_empty() or boars.is_empty():
		return

	var player: CharacterBody3D = game.get("player")
	for animal in animals:
		var collision: CollisionShape3D = animal.get_node_or_null("BodyCollision")
		var spawn_position: Vector3 = animal.get("home_position")
		_check(collision != null and collision.shape is CapsuleShape3D, "Each animal should have a simple capsule collision shape.")
		_check((animal.collision_mask & 1) != 0, "Animals should collide with terrain and solid shelter structures.")
		_check(animal.get_node("ProceduralModel").position.y < 0.07, "Animal procedural models should remain grounded while animating.")
		_check(Vector2(spawn_position.x, spawn_position.z).length() < 43.0, "Animals should spawn within the playable island.")
		_check(spawn_position.distance_to(player.global_position) > 10.0, "Animals should not spawn inside the player.")
	for first_index in range(animals.size()):
		for second_index in range(first_index + 1, animals.size()):
			_check(animals[first_index].home_position.distance_to(animals[second_index].home_position) > 5.0, "Animals should spawn clear of one another.")
	for child in game.get_children():
		if child.get_script() != HARVESTABLE_SCRIPT:
			continue
		for animal in animals:
			_check(
				Vector2(animal.home_position.x - child.global_position.x, animal.home_position.z - child.global_position.z).length() > 3.0,
				"Animals should not spawn inside trees, rocks, or bushes."
			)
	print("PASS: wildlife spawning, species counts, obstacle clearance, and collision setup")

	var test_deer: CharacterBody3D = deer[0]
	var original_player_position := player.global_position
	player.global_position = test_deer.global_position + Vector3(0.0, 0.0, 30.0)
	test_deer.call("_set_state", 0)
	test_deer.set("state_elapsed", 0.0)
	test_deer.set("state_duration", 0.01)
	test_deer.call("_update_ai", 0.02)
	_check(test_deer.get_state_name() == "WANDER", "An idle deer should transition to wandering.")
	var deer_position_before_wander := test_deer.global_position
	for frame_index in range(30):
		await physics_frame
	_check(test_deer.global_position.distance_to(deer_position_before_wander) > 0.2, "A wandering deer should move smoothly.")

	test_deer.global_position += Vector3(5.0, 0.0, 0.0)
	player.global_position = test_deer.global_position + Vector3(0.0, 0.0, 4.0)
	test_deer.call("_update_ai", 0.3)
	_check(test_deer.get_state_name() == "ALERT", "A deer should notice a nearby player before fleeing.")
	test_deer.call("_set_state", 2)
	player.global_position = test_deer.global_position + Vector3(0.0, 0.0, 13.0)
	test_deer.call("_update_ai", 0.3)
	_check(test_deer.get_state_name() == "RETURN", "A deer should stop reacting when the player leaves its detection range.")
	player.global_position = test_deer.global_position + Vector3(0.0, 0.0, 4.0)
	test_deer.call("_update_ai", 0.3)
	_check(test_deer.get_state_name() == "ALERT", "A deer should notice the player again when approached.")
	test_deer.call("_update_ai", 0.4)
	_check(test_deer.get_state_name() == "FLEE", "A deer should flee after becoming alert.")
	var flee_start_distance := test_deer.global_position.distance_to(player.global_position)
	for frame_index in range(30):
		await physics_frame
	_check(test_deer.global_position.distance_to(player.global_position) > flee_start_distance + 0.7, "A fleeing deer should increase its distance from the player.")
	test_deer.call("_set_state", 3)
	player.global_position = test_deer.global_position + Vector3(35.0, 0.0, 0.0)
	test_deer.call("_update_deer_response", 35.0)
	_check(test_deer.get_state_name() == "RETURN", "A deer should return toward its home area when the player is far away.")

	var test_boar: CharacterBody3D = boars[0]
	test_boar.global_position += Vector3(5.0, 0.0, 0.0)
	player.global_position = test_boar.global_position + Vector3(0.0, 0.0, 7.0)
	test_boar.call("_update_ai", 0.3)
	_check(test_boar.get_state_name() == "ALERT", "A boar should notice a player at a safe distance.")
	player.global_position = test_boar.global_position + Vector3(0.0, 0.0, 3.0)
	test_boar.call("_update_ai", 0.3)
	_check(test_boar.get_state_name() == "DEFEND", "A boar should defend itself when approached closely.")
	var defend_start_distance := test_boar.global_position.distance_to(player.global_position)
	for frame_index in range(30):
		await physics_frame
	_check(test_boar.global_position.distance_to(player.global_position) < defend_start_distance, "A defensive boar should move toward the nearby threat.")
	test_boar.call("_set_state", 4)
	player.global_position = test_boar.global_position + Vector3(25.0, 0.0, 0.0)
	test_boar.call("_update_boar_response", 25.0)
	_check(test_boar.get_state_name() == "RETURN", "A boar should disengage and return when the player moves away.")
	player.global_position = original_player_position

	for frame_index in range(30):
		await physics_frame
	for animal in animals:
		_check(Vector2(animal.global_position.x, animal.global_position.z).length() < 48.0, "Animals should remain within the island boundary.")
	print("PASS: deer idle/wander/alert/flee/return and boar alert/defend/return transitions")
	print("PASS: wildlife movement remains within island bounds")


func _collision_shape_count(body: StaticBody3D) -> int:
	var count := 0
	for child in body.get_children():
		if child is CollisionShape3D:
			count += 1
	return count


func _array_to_vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func _assert_crafting_layout(
	game: Node3D,
	mobile_viewport: SubViewport,
	crafting_panel: Control,
	scroll_container: ScrollContainer,
	craft_buttons: Dictionary,
	expected_size: Vector2i
) -> void:
	var mobile_rect := mobile_viewport.get_visible_rect()
	_check(mobile_viewport.size == expected_size, "Crafting layout should use the expected phone viewport size.")
	_check(crafting_panel.get_global_rect().position.x >= mobile_rect.position.x, "Crafting panel should stay within the mobile viewport.")
	_check(crafting_panel.get_global_rect().end.x <= mobile_rect.end.x, "Crafting panel should not overflow the mobile viewport.")
	_check(scroll_container.get_global_rect().size.x <= crafting_panel.get_global_rect().size.x, "Recipe list should fit inside the mobile panel.")
	_check(not scroll_container.get_h_scroll_bar().is_visible_in_tree(), "Recipe cards should not require horizontal scrolling on a phone.")
	for craft_button in craft_buttons.values():
		_check(craft_button.get_global_rect().size.x >= 100.0 and craft_button.get_global_rect().size.y >= 64.0, "Craft buttons should remain finger-friendly.")
		var card_rect: Rect2 = craft_button.get_parent().get_parent().get_parent().get_global_rect()
		_check(craft_button.get_global_rect().position.x >= card_rect.position.x, "Craft button should stay within its recipe card.")
		_check(craft_button.get_global_rect().end.x <= card_rect.end.x, "Craft button should not overlap or overflow its recipe card.")
	_check(game.get("craft_menu_close_button").get_global_rect().size.x >= 100.0, "Close button should remain finger-friendly.")
