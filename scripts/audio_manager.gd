extends Node

const WORLD_VOICE_COUNT := 12
const UI_VOICE_COUNT := 3
const SETTINGS_PATH := "user://audio_settings.cfg"
const ASSET_SOURCE := "Meta Open Sound / Oculus Audio Pack 1"
const ASSET_LICENSE := "CC BY 4.0"
const ASSET_SOURCE_URL := "https://github.com/facebookincubator/Meta-open-sound/tree/251c0be57d5d1b3242b91f53e0cde62ab1cb42d9/corpora/oculus-audio-pack"
const ASSET_ROOT := "res://assets/audio/oculus/"
const SOUND_CATEGORIES := {
	"environment": ["ocean", "birds", "insects", "wind", "light_rain", "storm_rain", "campfire"],
	"sfx": [
		"wood_chop", "tree_impact", "tree_fall", "wood_break", "stone_hit",
		"stone_crack", "stone_break", "pickup_wood", "pickup_stone", "pickup_berries",
		"footstep_grass", "footstep_sand", "footstep_rock", "footstep_wood",
		"jump", "land", "swim", "eat", "drink", "breath", "exertion",
		"deer_call", "deer_alert", "deer_flee", "deer_step", "boar_step", "boar_growl",
		"boar_defend", "thunder", "lightning", "craft_axe", "craft_spear",
		"craft_campfire", "build_foundation", "build_wall", "build_door", "build_roof",
		"action_fail", "ui_click"
	]
}
const SOUND_FILES := {
	"footstep_grass": [
		ASSET_ROOT + "FEETHmn_ShoeGrassRun_OS_01.ogg",
		ASSET_ROOT + "FEETHmn_ShoeGrassRun_OS_02.ogg",
		ASSET_ROOT + "FEETHmn_ShoeGrassRun_OS_03.ogg"
	],
	"footstep_sand": [
		ASSET_ROOT + "FEETHmn_ShoeDirtRun_OS_01.ogg",
		ASSET_ROOT + "FEETHmn_ShoeDirtRun_OS_02.ogg",
		ASSET_ROOT + "FEETHmn_ShoeDirtRun_OS_03.ogg"
	],
	"footstep_rock": [
		ASSET_ROOT + "FEETHmn_ShoeConcreteRun_OS_01.ogg",
		ASSET_ROOT + "FEETHmn_ShoeConcreteRun_OS_02.ogg",
		ASSET_ROOT + "FEETHmn_ShoeConcreteRun_OS_03.ogg"
	],
	"footstep_wood": [
		ASSET_ROOT + "FEETHmn_ShoeWoodRun_OS_01.ogg",
		ASSET_ROOT + "FEETHmn_ShoeWoodRun_OS_02.ogg",
		ASSET_ROOT + "FEETHmn_ShoeWoodRun_OS_03.ogg"
	],
	"land": [
		ASSET_ROOT + "FEETHmn_ShoeGrassLand_OS_01.ogg",
		ASSET_ROOT + "FEETHmn_ShoeGrassLand_OS_02.ogg"
	],
	"craft_axe": [ASSET_ROOT + "UIClick_WoodConfirm_OS_01.ogg"],
	"craft_spear": [ASSET_ROOT + "UIClick_WoodConfirm_OS_01.ogg"],
	"craft_campfire": [ASSET_ROOT + "UIClick_WoodConfirm_OS_01.ogg"],
	"build_foundation": [ASSET_ROOT + "WOODImpt_LargeWoodDrop_OS_01.ogg"],
	"build_wall": [ASSET_ROOT + "WOODImpt_LargeWoodDrop_OS_01.ogg"],
	"build_door": [ASSET_ROOT + "WOODImpt_LargeWoodDrop_OS_01.ogg"],
	"build_roof": [ASSET_ROOT + "WOODImpt_LargeWoodDrop_OS_01.ogg"],
	"action_fail": [ASSET_ROOT + "UIAlert_WoodError_OS_01.ogg"],
	"ui_click": [ASSET_ROOT + "UIClick_WoodConfirm_OS_01.ogg"]
}
const LOOP_FILES := {
	"ocean": ASSET_ROOT + "WATRWave_OceanWaves_LOOP_01.ogg",
	"birds": ASSET_ROOT + "AMBForst_Forest_LOOP_01.ogg",
	"insects": ASSET_ROOT + "AMBForst_Night_LOOP_01.ogg",
	"wind": ASSET_ROOT + "WINDVege_LightWindTreesBirds_LOOP_01.ogg",
	"light_rain": ASSET_ROOT + "RAINVege_ForestRain_LOOP_01.ogg",
	"storm_rain": ASSET_ROOT + "RAINVege_ForestRain_LOOP_01.ogg"
}
const BUS_NAMES := ["Music", "Environment", "SFX"]
const SETTING_DEFAULTS := {
	"Master": 0.85,
	"Music": 0.7,
	"Environment": 0.55,
	"SFX": 0.8
}

@export var settings_path := SETTINGS_PATH
@export_range(0.0, 1.0, 0.01) var environment_volume := 0.55

var world_voices: Array[AudioStreamPlayer3D] = []
var ui_voices: Array[AudioStreamPlayer] = []
var ambience_players: Dictionary = {}
var ambience_tweens: Dictionary = {}
var sound_streams: Dictionary = {}
var voice_cursor := 0
var ui_cursor := 0
var last_played_msec: Dictionary = {}
var sound_attempt_count: Dictionary = {}
var sound_resolution_count: Dictionary = {}
var missing_asset_warnings: Dictionary = {}
var weather_name := "SUNNY"
var day_phase := 0.5
var audio_output_available := true
var audio_paused := false
var _ambience_weather := ""
var _ambience_night_state := -1
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("audio_manager")
	rng.seed = 24987
	audio_output_available = DisplayServer.get_name() != "headless"
	_ensure_audio_buses()
	_load_settings()
	_create_voice_pools()
	_create_ambience_players()
	set_weather("SUNNY")
	set_day_phase(day_phase)


func _exit_tree() -> void:
	for tween in ambience_tweens.values():
		if is_instance_valid(tween):
			tween.kill()
	for player in world_voices:
		player.stop()
		player.stream = null
	for player in ui_voices:
		player.stop()
		player.stream = null
	for player in ambience_players.values():
		player.stop()
		player.stream = null
	sound_streams.clear()
	ambience_tweens.clear()
	ambience_players.clear()
	world_voices.clear()
	ui_voices.clear()


func play_3d(
	sound_name: String,
	position: Vector3,
	bus_name: String = "SFX",
	volume_db: float = -3.0,
	cooldown_msec: int = 70
) -> bool:
	if not _is_known_sound(sound_name):
		return false
	sound_attempt_count[sound_name] = int(sound_attempt_count.get(sound_name, 0)) + 1
	var now := Time.get_ticks_msec()
	if now - int(last_played_msec.get(sound_name, -1000000)) < cooldown_msec:
		return false
	var stream := _get_sound_stream(sound_name)
	if stream == null:
		return false
	var player := _get_next_world_voice()
	player.stream = stream
	player.bus = bus_name if _bus_exists(bus_name) else "SFX"
	player.volume_db = volume_db + rng.randf_range(-0.8, 0.8)
	player.pitch_scale = rng.randf_range(0.96, 1.04)
	player.global_position = position
	if audio_output_available:
		player.play()
		player.stream_paused = audio_paused
	last_played_msec[sound_name] = now
	sound_resolution_count[sound_name] = int(sound_resolution_count.get(sound_name, 0)) + 1
	return true


func play_ui(sound_name: String, volume_db: float = -4.0) -> bool:
	if not _is_known_sound(sound_name):
		return false
	sound_attempt_count[sound_name] = int(sound_attempt_count.get(sound_name, 0)) + 1
	var stream := _get_sound_stream(sound_name)
	if stream == null:
		return false
	var player := _get_next_ui_voice()
	player.stream = stream
	player.bus = "SFX"
	player.volume_db = volume_db + rng.randf_range(-0.8, 0.8)
	player.pitch_scale = rng.randf_range(0.96, 1.04)
	if audio_output_available:
		player.play()
		player.stream_paused = audio_paused
	sound_resolution_count[sound_name] = int(sound_resolution_count.get(sound_name, 0)) + 1
	return true


func play_event(sound_name: String, position: Vector3, cooldown_msec: int = 70) -> bool:
	return play_3d(sound_name, position, "SFX", -3.0, cooldown_msec)


func get_sound_names() -> Array[String]:
	var names: Array[String] = []
	for category in SOUND_CATEGORIES.values():
		for sound_name in category:
			names.append(String(sound_name))
	return names


func get_missing_asset_report() -> Dictionary:
	var report: Dictionary = {}
	for sound_name in get_sound_names():
		var files: Array = SOUND_FILES.get(sound_name, [])
		if LOOP_FILES.has(sound_name):
			files = [String(LOOP_FILES[sound_name])]
		var status := "pending" if files.is_empty() else "integrated"
		if sound_name in ["footstep_sand", "footstep_rock"]:
			status = "surrogate"
		elif sound_name == "storm_rain" or sound_name.begins_with("craft_"):
			status = "fallback"
		elif sound_name.begins_with("build_"):
			status = "fallback"
		for asset_path in files:
			if not ResourceLoader.exists(asset_path):
				status = "missing_file"
				break
		report[sound_name] = {
			"status": status,
			"files": files.duplicate(),
			"license": ASSET_LICENSE if not files.is_empty() else "",
			"source": ASSET_SOURCE if not files.is_empty() else ""
		}
	return report


func set_weather(next_weather: String) -> void:
	var normalized_weather := next_weather.to_upper()
	if normalized_weather == _ambience_weather:
		return
	_ambience_weather = normalized_weather
	weather_name = normalized_weather
	var rain_target := -80.0
	var wind_target := -80.0
	match weather_name:
		"RAINY":
			rain_target = -11.0
			wind_target = -28.0
		"STORM":
			rain_target = -5.0
			wind_target = -14.0
		"CLOUDY":
			wind_target = -34.0
		_:
			wind_target = -38.0
	_fade_ambience("light_rain", -80.0)
	_fade_ambience("storm_rain", -80.0)
	if weather_name == "RAINY":
		_fade_ambience("light_rain", rain_target)
	elif weather_name == "STORM":
		_fade_ambience("storm_rain", rain_target)
	_fade_ambience("wind", wind_target)


func set_day_phase(value: float) -> void:
	day_phase = fposmod(value, 1.0)
	var night := day_phase < 0.22 or day_phase > 0.78
	var next_night_state := 1 if night else 0
	if next_night_state == _ambience_night_state:
		return
	_ambience_night_state = next_night_state
	_fade_ambience("birds", -80.0 if night else -22.0)
	_fade_ambience("insects", -24.0 if night else -80.0)


func play_lightning(position: Vector3) -> void:
	play_3d("lightning", position, "Environment", -4.0, 100)
	play_3d("thunder", position, "Environment", -8.0, 500)


func set_bus_volume(bus_name: String, normalized: float) -> void:
	var value := clampf(normalized, 0.0, 1.0)
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(bus_index, value <= 0.0)
	_save_settings()


func get_bus_volume(bus_name: String) -> float:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(bus_index))


func set_bus_muted(bus_name: String, muted: bool) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, muted)
	_save_settings()


func is_bus_muted(bus_name: String) -> bool:
	var bus_index := AudioServer.get_bus_index(bus_name)
	return bus_index >= 0 and AudioServer.is_bus_mute(bus_index)


func get_play_attempt_count(sound_name: String) -> int:
	return int(sound_attempt_count.get(sound_name, 0))


func get_resolved_play_count(sound_name: String) -> int:
	return int(sound_resolution_count.get(sound_name, 0))


func pause_audio(paused: bool) -> void:
	audio_paused = paused
	for player in world_voices:
		player.stream_paused = paused
	for player in ui_voices:
		player.stream_paused = paused
	for player in ambience_players.values():
		player.stream_paused = paused


func _ensure_audio_buses() -> void:
	for bus_name in BUS_NAMES:
		if _bus_exists(bus_name):
			continue
		AudioServer.add_bus()
		var bus_index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, bus_name)
		AudioServer.set_bus_send(bus_index, "Master")


func _bus_exists(bus_name: String) -> bool:
	return AudioServer.get_bus_index(bus_name) >= 0


func _create_voice_pools() -> void:
	for index in range(WORLD_VOICE_COUNT):
		var player := AudioStreamPlayer3D.new()
		player.name = "WorldVoice%d" % index
		player.max_distance = 42.0
		player.unit_size = 8.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.max_polyphony = 1
		add_child(player)
		world_voices.append(player)
	for index in range(UI_VOICE_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "UIVoice%d" % index
		player.max_polyphony = 1
		add_child(player)
		ui_voices.append(player)


func _create_ambience_players() -> void:
	for loop_name in SOUND_CATEGORIES["environment"]:
		var player := AudioStreamPlayer.new()
		player.name = "Ambience_%s" % loop_name
		player.bus = "Environment"
		player.stream = _get_loop_stream(loop_name)
		player.volume_db = -80.0
		add_child(player)
		ambience_players[loop_name] = player
	_fade_ambience("ocean", -22.0)
	_fade_ambience("birds", -22.0)
	_fade_ambience("wind", -38.0)
	_fade_ambience("campfire", -80.0)


func _fade_ambience(loop_name: String, target_db: float) -> void:
	if not ambience_players.has(loop_name) or ambience_players[loop_name].stream == null:
		return
	var player: AudioStreamPlayer = ambience_players[loop_name]
	if ambience_tweens.has(loop_name) and is_instance_valid(ambience_tweens[loop_name]):
		ambience_tweens[loop_name].kill()
	if target_db > -60.0 and audio_output_available and not player.playing:
		player.play()
	var tween := create_tween()
	ambience_tweens[loop_name] = tween
	tween.tween_property(player, "volume_db", target_db, 1.4)
	if target_db <= -60.0:
		tween.tween_callback(func() -> void:
			if is_instance_valid(player) and not player.stream_paused:
				player.stop()
		)


func _get_next_world_voice() -> AudioStreamPlayer3D:
	var player := world_voices[voice_cursor]
	voice_cursor = (voice_cursor + 1) % world_voices.size()
	return player


func _get_next_ui_voice() -> AudioStreamPlayer:
	var player := ui_voices[ui_cursor]
	ui_cursor = (ui_cursor + 1) % ui_voices.size()
	return player


func _is_known_sound(sound_name: String) -> bool:
	return get_sound_names().has(sound_name)


func _get_sound_stream(sound_name: String) -> AudioStream:
	var files: Array = SOUND_FILES.get(sound_name, [])
	if files.is_empty():
		_warn_missing_asset(sound_name)
		return null
	return _load_first_available(files)


func _load_first_available(asset_paths: Array) -> AudioStream:
	if asset_paths.is_empty():
		return null
	var first_index := rng.randi_range(0, asset_paths.size() - 1)
	for offset in range(asset_paths.size()):
		var asset_path := String(asset_paths[(first_index + offset) % asset_paths.size()])
		var stream := _load_audio_asset(asset_path)
		if stream != null:
			return stream
	return null


func _get_loop_stream(loop_name: String) -> AudioStream:
	if not LOOP_FILES.has(loop_name):
		return null
	var stream := _load_audio_asset(String(LOOP_FILES[loop_name]))
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	return stream


func _load_audio_asset(asset_path: String) -> AudioStream:
	if sound_streams.has(asset_path):
		return sound_streams[asset_path]
	if not ResourceLoader.exists(asset_path):
		_warn_missing_asset(asset_path)
		return null
	var stream := load(asset_path) as AudioStream
	if stream == null:
		_warn_missing_asset(asset_path)
		return null
	sound_streams[asset_path] = stream
	return stream


func _warn_missing_asset(asset_name: String) -> void:
	if missing_asset_warnings.has(asset_name):
		return
	missing_asset_warnings[asset_name] = true
	push_warning("Audio asset is not integrated: %s." % asset_name)


func _load_settings() -> void:
	var config := ConfigFile.new()
	var load_error := config.load(settings_path)
	for bus_name in ["Master", "Music", "Environment", "SFX"]:
		var default_value := float(SETTING_DEFAULTS[bus_name])
		var normalized := float(config.get_value("audio", "%s_volume" % bus_name, default_value))
		var muted := bool(config.get_value("audio", "%s_muted" % bus_name, false))
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index < 0:
			continue
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(clampf(normalized, 0.0, 1.0), 0.0001)))
		AudioServer.set_bus_mute(bus_index, muted or normalized <= 0.0)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_warning("Audio settings could not be loaded: %s." % error_string(load_error))


func _save_settings() -> void:
	var config := ConfigFile.new()
	for bus_name in ["Master", "Music", "Environment", "SFX"]:
		config.set_value("audio", "%s_volume" % bus_name, get_bus_volume(bus_name))
		config.set_value("audio", "%s_muted" % bus_name, is_bus_muted(bus_name))
	var save_error := config.save(settings_path)
	if save_error != OK:
		push_warning("Audio settings could not be saved: %s." % error_string(save_error))
