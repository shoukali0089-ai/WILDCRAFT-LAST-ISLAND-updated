extends Node

const SETTINGS_PATH := "user://graphics_settings.cfg"
const PROFILES := ["low", "medium", "high"]
const PROFILE_SETTINGS := {
	"low": {"shadow_distance": 0.0, "rain_quality": 0.35, "ai_interval": 0.4, "fps_cap": 30},
	"medium": {"shadow_distance": 45.0, "rain_quality": 0.65, "ai_interval": 0.25, "fps_cap": 60},
	"high": {"shadow_distance": 65.0, "rain_quality": 1.0, "ai_interval": 0.2, "fps_cap": 60}
}

@export var settings_path := SETTINGS_PATH

var profile := "medium"
var fps_monitor_enabled := false
var sun: DirectionalLight3D
var weather_system: Node
var wildlife_system: Node


func configure(
	sun_light: DirectionalLight3D,
	weather: Node,
	wildlife: Node
) -> void:
	sun = sun_light
	weather_system = weather
	wildlife_system = wildlife


func _ready() -> void:
	_load_settings()
	_apply_profile()


func set_profile(profile_name: String) -> bool:
	var normalized_name := profile_name.to_lower()
	if not PROFILES.has(normalized_name):
		return false
	profile = normalized_name
	_apply_profile()
	_save_settings()
	return true


func set_fps_monitor_enabled(enabled: bool) -> void:
	fps_monitor_enabled = enabled
	_save_settings()


func _apply_profile() -> void:
	var settings: Dictionary = PROFILE_SETTINGS[profile]
	Engine.max_fps = int(settings["fps_cap"])
	if is_instance_valid(sun):
		sun.shadow_enabled = profile != "low"
		sun.directional_shadow_max_distance = float(settings["shadow_distance"])
	if is_instance_valid(weather_system):
		weather_system.set("quality_scale", float(settings["rain_quality"]))
	if is_instance_valid(wildlife_system):
		wildlife_system.call("set_ai_update_interval", float(settings["ai_interval"]))


func _load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(settings_path)
	if error == ERR_FILE_NOT_FOUND:
		return
	if error != OK:
		push_warning("Graphics settings could not be loaded: %s" % error_string(error))
		return
	var saved_profile: Variant = config.get_value("graphics", "profile", profile)
	if typeof(saved_profile) == TYPE_STRING and PROFILES.has(String(saved_profile).to_lower()):
		profile = String(saved_profile).to_lower()
	var saved_fps: Variant = config.get_value("graphics", "fps_monitor_enabled", fps_monitor_enabled)
	if typeof(saved_fps) == TYPE_BOOL:
		fps_monitor_enabled = saved_fps


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "profile", profile)
	config.set_value("graphics", "fps_monitor_enabled", fps_monitor_enabled)
	var error := config.save(settings_path)
	if error != OK:
		push_warning("Graphics settings could not be saved: %s" % error_string(error))
