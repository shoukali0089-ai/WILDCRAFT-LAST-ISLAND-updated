extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const JOYSTICK_SCRIPT := preload("res://scripts/virtual_joystick.gd")
const TOUCH_LOOK_SCRIPT := preload("res://scripts/touch_look.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(360, 800)
	var mobile_viewport := SubViewport.new()
	mobile_viewport.size = Vector2i(360, 800)
	mobile_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(mobile_viewport)
	var game: Node3D = MAIN_SCENE.instantiate()
	mobile_viewport.add_child(game)
	await process_frame

	var player: CharacterBody3D = game.get("player")
	assert(player != null, "The main scene should spawn the player.")
	var hud_root: Control = game.get_node("HUD").get_child(0)
	var joystick: Control
	var look_area: Control
	for control in hud_root.get_children():
		if control.get_script() == JOYSTICK_SCRIPT:
			joystick = control
		elif control.get_script() == TOUCH_LOOK_SCRIPT:
			look_area = control
	assert(joystick != null and look_area != null, "The mobile movement and look controls should exist.")

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
	assert(player.get("joystick_input").y < -0.5, "Dragging the joystick upward should request forward movement.")
	for frame_index in range(12):
		await physics_frame
	var horizontal_distance := Vector2(
		player.global_position.x - start_position.x,
		player.global_position.z - start_position.z
	).length()
	assert(horizontal_distance > 0.1, "The player should move horizontally.")
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
	assert(player.rotation.y != rotation_before_look, "Dragging the touch-look area should rotate the player.")
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
	assert(palm != null, "The island should contain a gatherable palm.")
	game.set("nearby_resource", palm)
	game.call("_gather_nearby")
	var inventory: Dictionary = game.get("inventory")
	assert(inventory["wood"] == 1 and inventory["fiber"] == 1, "Gathering a palm should add wood and fiber.")
	assert(String(game.get("inventory_label").text).contains("Wood   1"), "Gathering should update the inventory HUD immediately.")
	assert(palm.get("gathers_left") == 2, "Gathering should consume one resource use.")
	print("PASS: palm gathering and immediate inventory HUD update")

	game.get("craft_menu_button").pressed.emit()
	await process_frame
	var crafting_menu: Control = game.get("crafting_menu")
	assert(crafting_menu.visible, "The crafting menu should open.")
	var requirement_labels: Dictionary = game.get("recipe_requirement_labels")
	var craft_buttons: Dictionary = game.get("recipe_craft_buttons")
	assert(requirement_labels.size() == 3 and craft_buttons.size() == 3, "All three recipe cards should be present.")
	var crafting_panel: Control = crafting_menu.get_child(1)
	var scroll_container: ScrollContainer = crafting_panel.get_child(0).get_child(1)
	_assert_crafting_layout(game, mobile_viewport, crafting_panel, scroll_container, craft_buttons, Vector2i(360, 800))
	mobile_viewport.size = Vector2i(800, 450)
	await process_frame
	_assert_crafting_layout(game, mobile_viewport, crafting_panel, scroll_container, craft_buttons, Vector2i(800, 450))
	mobile_viewport.size = Vector2i(360, 800)
	await process_frame
	print("PASS: crafting menu interactions and portrait/landscape mobile layout")
	assert(String(requirement_labels["stone_axe"].text).contains("Wood 3 (have 1)"), "The recipe should show live resource quantities.")
	assert(craft_buttons["stone_axe"].disabled, "A recipe should be disabled when materials are insufficient.")

	var inventory_before_failed_craft := inventory.duplicate(true)
	assert(not game.call("_craft_recipe", "stone_axe"), "Crafting without enough materials should fail.")
	assert(inventory == inventory_before_failed_craft, "A failed craft should not change inventory.")
	assert(game.get("notification_label").visible, "A crafting failure should show a notification.")
	inventory["wood"] = 3
	inventory["stone"] = 1
	game.call("_update_crafting_menu")
	var inventory_before_stone_shortage := inventory.duplicate(true)
	assert(not game.call("_craft_recipe", "stone_axe"), "Crafting should fail when stone is one short.")
	assert(inventory == inventory_before_stone_shortage, "A stone shortage must not consume any wood.")
	print("PASS: insufficient-resource handling and atomic deductions")

	inventory["wood"] = 3
	inventory["stone"] = 2
	craft_buttons["stone_axe"].pressed.emit()
	assert(inventory["wood"] == 0 and inventory["stone"] == 0, "The axe recipe should deduct exactly 3 wood and 2 stone.")
	assert(inventory["stone_axe"] == 1, "Crafting the axe once should add exactly one axe.")
	assert(String(game.get("inventory_label").text).contains("Stone Axe 1"), "The inventory HUD should update immediately.")
	assert(String(game.get("notification_label").text).contains("Crafted Stone Axe"), "Successful crafting should show a notification.")
	assert(craft_buttons["stone_axe"].disabled, "The axe button should refresh after materials are spent.")

	assert(not game.call("_craft_recipe", "unknown_recipe"), "Unknown recipes should fail without granting an item.")
	assert(inventory["stone_axe"] == 1, "An invalid recipe must not duplicate a crafted item.")

	inventory["wood"] = 3
	inventory["stone"] = 2
	assert(game.call("_craft_recipe", "stone_axe"), "The axe should be craftable again when materials are supplied.")
	assert(inventory["stone_axe"] == 2, "A second successful craft should add only one additional axe.")
	assert(inventory["wood"] == 0 and inventory["stone"] == 0, "Repeated crafting should deduct each cost once.")
	print("PASS: Stone Axe recipe, output count, and repeated crafting")

	game.set("nearby_resource", palm)
	var wood_before_axe_gather: int = inventory["wood"]
	game.call("_gather_nearby")
	assert(inventory["wood"] == wood_before_axe_gather + 2, "A carried Stone Axe should yield one extra wood from a palm.")

	inventory["wood"] = 10
	inventory["stone"] = 6
	game.call("_update_crafting_menu")
	assert(craft_buttons["campfire"].disabled == false, "Campfire should be enabled at or above its 5 wood and 3 stone requirements.")
	assert(game.call("_craft_recipe", "campfire"), "The Campfire recipe should craft with sufficient materials.")
	assert(inventory["wood"] == 5 and inventory["stone"] == 3, "Crafting a Campfire should deduct 5 wood and 3 stone.")
	assert(inventory["campfire"] == 1, "A crafted Campfire should be stored in inventory.")
	assert(game.call("_craft_recipe", "campfire"), "A second Campfire should craft when its cost is available.")
	assert(inventory["campfire"] == 2 and inventory["wood"] == 0 and inventory["stone"] == 0, "Repeated Campfire crafting should update its stack and costs.")
	assert(not game.call("_craft_recipe", "campfire"), "A third Campfire should fail without materials.")
	assert(inventory["wood"] >= 0 and inventory["stone"] >= 0, "Failed crafting must never make resource counts negative.")
	print("PASS: Campfire recipe, output count, and repeated crafting")

	inventory["wood"] = 8
	inventory["stone"] = 2
	game.call("_update_crafting_menu")
	assert(craft_buttons["wooden_spear"].disabled == false, "Wooden Spear should be enabled at or above its 4 wood and 1 stone requirements.")
	assert(game.call("_craft_recipe", "wooden_spear"), "The Wooden Spear recipe should craft with sufficient materials.")
	assert(inventory["wood"] == 4 and inventory["stone"] == 1, "Crafting a Spear should deduct 4 wood and 1 stone.")
	assert(game.call("_craft_recipe", "wooden_spear"), "Repeated Spear crafting should work when materials are restored.")
	assert(inventory["wooden_spear"] == 2 and inventory["wood"] == 0 and inventory["stone"] == 0, "Repeated Spear crafting should add one item and deduct its cost each time.")
	assert(not game.call("_craft_recipe", "wooden_spear"), "A Spear should not be granted when its cost is unavailable.")
	assert(inventory["wood"] >= 0 and inventory["stone"] >= 0, "Repeated craft attempts must not produce negative resources.")
	for item in inventory:
		assert(int(inventory[item]) >= 0, "Inventory values must never become negative.")
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
	assert(rock != null and bush != null, "The island should contain gatherable rocks and berry bushes.")
	game.set("nearby_resource", rock)
	game.call("_gather_nearby")
	assert(inventory["stone"] == 1, "Gathering a rock should still add stone.")
	game.set("nearby_resource", bush)
	game.call("_gather_nearby")
	assert(inventory["berries"] == 1, "Gathering a berry bush should still add berries.")
	print("PASS: Stone Axe bonus and existing rock/berry gathering")

	game.get("craft_menu_close_button").pressed.emit()
	assert(not crafting_menu.visible, "The crafting menu should close.")

	var hunger_before: float = game.get("hunger")
	game.call("_update_survival", 10.0)
	assert(game.get("hunger") < hunger_before, "Hunger should decrease over time.")
	game.call("_update_day_cycle")
	assert(not String(game.get("time_label").text).is_empty(), "The day/night clock should update.")

	print("Prototype and crafting smoke tests passed.")
	quit()


func _assert_crafting_layout(
	game: Node3D,
	mobile_viewport: SubViewport,
	crafting_panel: Control,
	scroll_container: ScrollContainer,
	craft_buttons: Dictionary,
	expected_size: Vector2i
) -> void:
	var mobile_rect := mobile_viewport.get_visible_rect()
	assert(mobile_viewport.size == expected_size, "Crafting layout should use the expected phone viewport size.")
	assert(crafting_panel.get_global_rect().position.x >= mobile_rect.position.x, "Crafting panel should stay within the mobile viewport.")
	assert(crafting_panel.get_global_rect().end.x <= mobile_rect.end.x, "Crafting panel should not overflow the mobile viewport.")
	assert(scroll_container.get_global_rect().size.x <= crafting_panel.get_global_rect().size.x, "Recipe list should fit inside the mobile panel.")
	assert(not scroll_container.get_h_scroll_bar().is_visible_in_tree(), "Recipe cards should not require horizontal scrolling on a phone.")
	for craft_button in craft_buttons.values():
		assert(craft_button.get_global_rect().size.x >= 100.0 and craft_button.get_global_rect().size.y >= 64.0, "Craft buttons should remain finger-friendly.")
		var card_rect: Rect2 = craft_button.get_parent().get_parent().get_parent().get_global_rect()
		assert(craft_button.get_global_rect().position.x >= card_rect.position.x, "Craft button should stay within its recipe card.")
		assert(craft_button.get_global_rect().end.x <= card_rect.end.x, "Craft button should not overlap or overflow its recipe card.")
	assert(game.get("craft_menu_close_button").get_global_rect().size.x >= 100.0, "Close button should remain finger-friendly.")
