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
7. Tap **BUILD** or press **B** to open Build Mode. Choose a foundation, wall, door, or roof; tap **ROTATE** or press **R** to rotate; use **PLACE** or **E** to place, and **CANCEL** or **Esc** to leave Build Mode. Mobile movement and look controls remain available while building.
8. Tap **MAIN MENU** to save, continue, start a new game, or return to play. Starting a new game and deleting a save both require confirmation.
9. Open **AUDIO & GRAPHICS** in the main menu to adjust sound, choose Low/Medium/High graphics, or toggle the FPS readout. Graphics choices are stored locally in `user://graphics_settings.cfg`.

The HUD shows health, hunger, thirst, the day/night clock, gathered materials, and crafted items. Hunger and thirst decrease over time; health decreases if either reaches zero. The Stone Axe yields one extra wood when gathering palms. Campfires are held in inventory ready for placement; Wooden Spears are held ready for future combat. The first run is a playable island-and-gathering prototype, not the complete survival game.

Shelter pieces cost 6 Wood for a foundation, 4 Wood for a wall, 3 Wood for a door, and 5 Wood for a roof. Foundations require suitable ground; walls snap to foundation edges; doors require an adjacent wall; and roofs require at least two walls. Structures have collision and remain in the world for the current session.

Four procedural animals spawn on clear island ground: deer flee from nearby players, while wild boars remain calm at a distance and defend themselves when approached closely. They idle, wander around their home areas, react to the player, flee or defend as appropriate, and return home after the threat moves away. Animal AI makes decisions four times per second and uses simple collision shapes.

Weather transitions among sunny, cloudy, rainy, and storm conditions. Clouds, capped rain particles, wind sway, and storm lightning are procedurally generated; thunder audio is optional and has no built-in asset. The weather HUD shows the current condition and gradual temperature. Cold outdoor exposure below 18 C slightly increases hunger drain. A player is sheltered only while inside a foundation with a roof, all four perimeter edges occupied, and at least one door; open or partial builds do not protect the player.

Local saves use versioned JSON at `user://wildcraft_save.json`. Manual saving is available from the Main Menu; the game also saves after successful gathering, crafting, and building, and every two minutes. Saves include player and survival state, inventory, built shelters, resource depletion, weather/day progress, and wildlife positions and AI states.

Run the headless prototype, crafting, shelter, wildlife, weather, and save smoke tests with `godot --headless --path . --script res://tests/prototype_smoke.gd`. It checks scene startup, mobile controls and layouts, movement, gathering, crafting, shelter placement/collisions/protection, wildlife, weather, and save/load, corruption/version rejection, deletion confirmation, and autosave.

## Prototype contents

- Procedurally generated, collidable 3D island, ocean, palm trees, rocks, and berry bushes.
- Third-person character movement with desktop mouse/keyboard and on-screen touch controls.
- Resource gathering and a small inventory display.
- Mobile-friendly crafting menu with Stone Axe, Campfire, and Wooden Spear recipes.
- Mobile-friendly shelter building with procedural foundations, walls, doors, roofs, placement previews, snapping, rotation, and wood costs.
- Procedural deer and wild boars with distance-based detection, wandering, fleeing, defensive behavior, return-home movement, and obstacle avoidance.
- Health, hunger, and thirst meters plus a continuous day/night lighting cycle.
- Procedural sunny, cloudy, rainy, and storm weather with gradual transitions, temperature, shelter protection, rain, wind sway, and lightning.
- Versioned local JSON save/load with safe validation, autosave, and mobile-friendly menu controls.
- Godot's Compatibility renderer and primitive-only assets for a modest mobile rendering baseline.
- Low, Medium, and High graphics profiles adjust sun shadows, rain particle density, wildlife decision cadence, and frame-rate caps (30 FPS for Low; 60 FPS for Medium/High). Settings persist locally. The optional FPS monitor updates twice per second.

## Not implemented yet

Wildlife combat damage or hunting, consumable use, campfire placement, spear combat, and mobile export configuration are planned follow-up work. Thunder audio requires assigning an audio stream; shelter protection currently checks complete four-sided enclosures only. Save files are local to the platform's Godot `user://` location and are not synchronized between devices.
