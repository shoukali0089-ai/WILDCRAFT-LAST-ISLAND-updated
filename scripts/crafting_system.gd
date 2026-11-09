extends RefCounted

const RECIPES := {
	"stone_axe": {
		"name": "Stone Axe",
		"description": "A sturdy tool. Palm trees yield extra wood while carried.",
		"ingredients": {"wood": 3, "stone": 2},
		"icon": "axe"
	},
	"campfire": {
		"name": "Campfire",
		"description": "Crafted and ready to place.",
		"ingredients": {"wood": 5, "stone": 3},
		"icon": "campfire"
	},
	"wooden_spear": {
		"name": "Wooden Spear",
		"description": "Crafted and ready for future combat.",
		"ingredients": {"wood": 4, "stone": 1},
		"icon": "spear"
	}
}


func get_recipes() -> Dictionary:
	return RECIPES.duplicate(true)


func can_craft(recipe_id: String, inventory: Dictionary) -> bool:
	if not RECIPES.has(recipe_id):
		return false
	for item in RECIPES[recipe_id]["ingredients"]:
		if int(inventory.get(item, 0)) < int(RECIPES[recipe_id]["ingredients"][item]):
			return false
	return true


func craft(recipe_id: String, inventory: Dictionary) -> Dictionary:
	if not RECIPES.has(recipe_id):
		return {"success": false, "message": "Unknown recipe."}

	var recipe: Dictionary = RECIPES[recipe_id]
	for item in recipe["ingredients"]:
		var required: int = recipe["ingredients"][item]
		var available := int(inventory.get(item, 0))
		if available < required:
			return {
				"success": false,
				"message": "Need %d %s (have %d)." % [required, String(item).capitalize(), available]
			}

	for item in recipe["ingredients"]:
		var remaining := int(inventory.get(item, 0)) - int(recipe["ingredients"][item])
		inventory[item] = remaining
	var crafted_key := String(recipe_id)
	inventory[crafted_key] = int(inventory.get(crafted_key, 0)) + 1

	return {"success": true, "message": "Crafted %s." % recipe["name"]}
