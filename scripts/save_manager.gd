extends RefCounted

const FORMAT_VERSION := 1
const DEFAULT_SAVE_PATH := "user://wildcraft_save.json"
const MAX_SAVE_BYTES := 4194304
const MAX_RESOURCE_ENTRIES := 128
const MAX_STRUCTURE_ENTRIES := 256
const MAX_WILDLIFE_ENTRIES := 12
const INVENTORY_KEYS := [
	"wood",
	"fiber",
	"stone",
	"berries",
	"stone_axe",
	"campfire",
	"wooden_spear"
]
const WEATHER_STATES := ["SUNNY", "CLOUDY", "RAINY", "STORM"]
const ANIMAL_TYPES := ["deer", "wild_boar"]
const ANIMAL_STATES := ["IDLE", "WANDER", "ALERT", "FLEE", "DEFEND", "RETURN"]
const STRUCTURE_TYPES := ["wooden_foundation", "wooden_wall", "wooden_door", "wooden_roof"]

var save_path := DEFAULT_SAVE_PATH


func save_game(data: Dictionary) -> Dictionary:
	if not validate_save_data(data):
		return {"success": false, "error": "Save data failed validation."}

	var temporary_path := save_path + ".tmp"
	var absolute_temporary_path := ProjectSettings.globalize_path(temporary_path)
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return {"success": false, "error": "Could not open temporary save file: %s." % error_string(FileAccess.get_open_error())}
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(absolute_temporary_path)
		return {"success": false, "error": "Could not write the save file: %s." % error_string(write_error)}

	var verification := _read_save_file(temporary_path)
	if not verification["success"]:
		DirAccess.remove_absolute(absolute_temporary_path)
		return {"success": false, "error": "Temporary save verification failed: %s." % verification["error"]}

	var absolute_save_path := ProjectSettings.globalize_path(save_path)
	var backup_path := ""
	if FileAccess.file_exists(save_path):
		backup_path = "%s.bak.%d" % [absolute_save_path, Time.get_ticks_usec()]
		var backup_error := DirAccess.rename_absolute(absolute_save_path, backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(absolute_temporary_path)
			return {"success": false, "error": "Could not safely replace the existing save: %s." % error_string(backup_error)}

	var replace_error := DirAccess.rename_absolute(absolute_temporary_path, absolute_save_path)
	if replace_error != OK:
		if not backup_path.is_empty():
			var rollback_error := DirAccess.rename_absolute(backup_path, absolute_save_path)
			if rollback_error != OK:
				DirAccess.remove_absolute(absolute_temporary_path)
				return {
					"success": false,
					"error": "Save replacement failed (%s); the previous save remains at %s because rollback failed (%s)." % [
						error_string(replace_error),
						backup_path,
						error_string(rollback_error)
					]
				}
		DirAccess.remove_absolute(absolute_temporary_path)
		return {"success": false, "error": "Could not finalize the save file: %s." % error_string(replace_error)}

	if not backup_path.is_empty():
		var cleanup_error := DirAccess.remove_absolute(backup_path)
		if cleanup_error != OK:
			push_warning("New save is valid, but the previous save backup remains at %s: %s." % [
				backup_path,
				error_string(cleanup_error)
			])
	return {"success": true, "error": ""}


func load_game() -> Dictionary:
	return _read_save_file(save_path)


func has_save_file() -> bool:
	return FileAccess.file_exists(save_path)


func has_valid_save() -> bool:
	var result := load_game()
	return bool(result["success"])


func delete_save(confirmed: bool) -> Dictionary:
	if not confirmed:
		return {"success": false, "error": "Save deletion requires confirmation."}
	if not FileAccess.file_exists(save_path):
		return {"success": true, "error": ""}
	var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	if remove_error != OK:
		return {"success": false, "error": "Could not delete the save file: %s." % error_string(remove_error)}
	return {"success": true, "error": ""}


func validate_save_data(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if not _is_integer_in_range(data.get("format_version"), FORMAT_VERSION, FORMAT_VERSION):
		return false
	if not data.has("player") or typeof(data["player"]) != TYPE_DICTIONARY:
		return false
	if not data.has("inventory") or typeof(data["inventory"]) != TYPE_DICTIONARY:
		return false
	if not data.has("world") or typeof(data["world"]) != TYPE_DICTIONARY:
		return false

	var player_data: Dictionary = data["player"]
	for key in ["position", "rotation"]:
		if not _is_vector_array(player_data.get(key)):
			return false
	if not _is_number_in_range(player_data.get("camera_pitch"), -1.5, 1.5):
		return false
	for key in ["health", "hunger", "thirst"]:
		if not _is_number_in_range(player_data.get(key), 0.0, 100.0):
			return false

	var inventory: Dictionary = data["inventory"]
	for key in inventory:
		if not INVENTORY_KEYS.has(String(key)) or not _is_integer_in_range(inventory[key], 0, 1000000):
			return false
	for key in ["wood", "fiber", "stone", "berries"]:
		if not inventory.has(key):
			return false

	var world_data: Dictionary = data["world"]
	if not _is_number_in_range(world_data.get("elapsed_game_time"), 0.0, 1000000000.0):
		return false
	if not _is_number_in_range(world_data.get("day_length_seconds"), 1.0, 100000.0):
		return false
	if not _is_number_in_range(world_data.get("survival_tick"), 0.0, 10.0):
		return false
	if typeof(world_data.get("weather")) != TYPE_DICTIONARY:
		return false
	if typeof(world_data.get("resources")) != TYPE_ARRAY:
		return false
	if typeof(world_data.get("structures")) != TYPE_ARRAY:
		return false
	if typeof(world_data.get("wildlife")) != TYPE_ARRAY:
		return false
	if world_data["resources"].size() > MAX_RESOURCE_ENTRIES:
		return false
	if world_data["structures"].size() > MAX_STRUCTURE_ENTRIES:
		return false
	if world_data["wildlife"].size() > MAX_WILDLIFE_ENTRIES:
		return false

	var weather: Dictionary = world_data["weather"]
	if not WEATHER_STATES.has(String(weather.get("state", ""))):
		return false
	if not _is_number_in_range(weather.get("temperature"), 0.0, 50.0):
		return false
	if not _is_number_in_range(weather.get("weather_remaining"), 0.0, 100000.0):
		return false

	for resource in world_data["resources"]:
		if typeof(resource) != TYPE_DICTIONARY:
			return false
		if typeof(resource.get("id")) != TYPE_STRING or String(resource["id"]).is_empty():
			return false
		if not _is_integer_in_range(resource.get("gathers_left"), 0, 3):
			return false

	for structure in world_data["structures"]:
		if typeof(structure) != TYPE_DICTIONARY:
			return false
		if not STRUCTURE_TYPES.has(String(structure.get("component_id", ""))):
			return false
		if not _is_vector_array(structure.get("position")) or not _is_vector_array(structure.get("rotation")):
			return false
		for key in ["grid_key", "edge_key", "edge_name"]:
			if typeof(structure.get(key)) != TYPE_STRING:
				return false

	for animal in world_data["wildlife"]:
		if typeof(animal) != TYPE_DICTIONARY:
			return false
		if not ANIMAL_TYPES.has(String(animal.get("animal_type", ""))):
			return false
		if not ANIMAL_STATES.has(String(animal.get("state", ""))):
			return false
		if not _is_vector_array(animal.get("position")) or not _is_vector_array(animal.get("home_position")):
			return false
		if String(animal["state"]) == "DEFEND" and String(animal["animal_type"]) != "wild_boar":
			return false
	return true


func _read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"success": false, "error": "No save file exists."}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "Could not read the save file: %s." % error_string(FileAccess.get_open_error())}
	if file.get_length() > MAX_SAVE_BYTES:
		file.close()
		return {"success": false, "error": "Save file exceeds the supported size limit."}
	var text := file.get_as_text()
	file.close()
	var parsed := JSON.new()
	var parse_error := parsed.parse(text)
	if parse_error != OK:
		return {"success": false, "error": "Save JSON is corrupted at line %d: %s." % [parsed.get_error_line(), parsed.get_error_message()]}
	if not validate_save_data(parsed.data):
		return {"success": false, "error": "Save data is invalid or uses an unsupported format version."}
	return {"success": true, "error": "", "data": parsed.data}


func _is_vector_array(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY or value.size() != 3:
		return false
	for component in value:
		if not _is_number_in_range(component, -10000.0, 10000.0):
			return false
	return true


func _is_number_in_range(value: Variant, minimum: float, maximum: float) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and number >= minimum and number <= maximum


func _is_integer_in_range(value: Variant, minimum: int, maximum: int) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and floorf(number) == number and number >= minimum and number <= maximum
