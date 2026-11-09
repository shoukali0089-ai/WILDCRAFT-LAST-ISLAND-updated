# WILDCRAFT: LAST ISLAND

A mobile-first, single-player 3D survival prototype made with Godot 4 and GDScript. All visible world geometry is generated from Godot primitives at runtime; no third-party art assets are required.

## Requirements

- Godot 4.4.1
- A desktop computer for editor testing; Android/iOS export templates are needed to export mobile builds

## Run the prototype

1. Open `project.godot` in Godot 4.
2. Press **F6** or **F5** to run the island scene.
3. Use **WASD** to move, move the mouse to look around, and press **E** near a palm, rock, or berry bush to gather.
4. Press **Esc** to release or recapture the mouse.
5. On touch devices, use the lower-left joystick to move, drag on the right half of the screen to look, and tap **GATHER** near a resource.
6. Tap **CRAFT** or press **C** to open the crafting menu. Select a recipe, review its costs and current materials, and tap **CRAFT**. Close the menu to return to the island.

The HUD shows health, hunger, thirst, the day/night clock, gathered materials, and crafted items. Hunger and thirst decrease over time; health decreases if either reaches zero. The Stone Axe yields one extra wood when gathering palms. Campfires are held in inventory ready for placement; Wooden Spears are held ready for future combat. The first run is a playable island-and-gathering prototype, not the complete survival game.

Run the headless prototype and crafting smoke tests with `godot --headless --path . --script res://tests/prototype_smoke.gd`. It checks scene startup, mobile controls, movement, gathering, all recipes, material deductions, repeated and insufficient crafting, HUD updates, survival decay, and the clock.

## Prototype contents

- Procedurally generated, collidable 3D island, ocean, palm trees, rocks, and berry bushes.
- Third-person character movement with desktop mouse/keyboard and on-screen touch controls.
- Resource gathering and a small inventory display.
- Mobile-friendly crafting menu with Stone Axe, Campfire, and Wooden Spear recipes.
- Health, hunger, and thirst meters plus a continuous day/night lighting cycle.
- Godot's Compatibility renderer and primitive-only assets for a modest mobile rendering baseline.

## Not implemented yet

Shelter construction, wildlife, weather effects, consumable use, local save/load, campfire placement, spear combat, and mobile export configuration are planned follow-up work. They are intentionally not presented as working features in this prototype.
