extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const JOYSTICK_SCRIPT := preload("res://scripts/virtual_joystick.gd")
const TOUCH_LOOK_SCRIPT := preload("res://scripts/touch_look.gd")
const HARVESTABLE_SCRIPT := preload("res://scripts/harvestable.gd")

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
	await physics_frame
	await _test_building_system(building_game)

	var hunger_before: float = game.get("hunger")
	game.call("_update_survival", 10.0)
	_check(game.get("hunger") < hunger_before, "Hunger should decrease over time.")
	game.call("_update_day_cycle")
	_check(not String(game.get("time_label").text).is_empty(), "The day/night clock should update.")
	await _test_wildlife(game)

	if test_failed:
		push_error("Prototype, crafting, building, or wildlife tests failed.")
		quit(1)
	else:
		print("Prototype, crafting, building, and wildlife smoke tests passed.")
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
	player.global_position = test_deer.global_position + Vector3(35.0, 0.0, 0.0)
	test_deer.call("_update_ai", 0.3)
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
	player.global_position = test_boar.global_position + Vector3(25.0, 0.0, 0.0)
	test_boar.call("_update_ai", 0.3)
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
