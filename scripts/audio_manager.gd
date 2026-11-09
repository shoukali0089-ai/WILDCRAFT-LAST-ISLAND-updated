extends Node

const SAMPLE_RATE := 22050
const WORLD_VOICE_COUNT := 12
const UI_VOICE_COUNT := 3
const SETTINGS_PATH := "user://audio_settings.cfg"
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
const SOUND_DEFINITIONS := {
	"wood_chop": [0.19, 105.0, 0.78, 0.22],
	"tree_impact": [0.26, 78.0, 0.88, 0.14],
	"tree_fall": [0.72, 54.0, 0.92, 0.1],
	"wood_break": [0.34, 92.0, 0.86, 0.24],
	"stone_hit": [0.18, 245.0, 0.7, 0.24],
	"stone_crack": [0.38, 168.0, 0.85, 0.18],
	"stone_break": [0.42, 126.0, 0.92, 0.26],
	"pickup_wood": [0.13, 520.0, 0.3, 0.06],
	"pickup_stone": [0.13, 345.0, 0.42, 0.1],
	"pickup_berries": [0.16, 760.0, 0.22, 0.02],
	"footstep_grass": [0.13, 95.0, 0.48, 0.2],
	"footstep_sand": [0.15, 80.0, 0.68, 0.1],
	"footstep_rock": [0.12, 210.0, 0.5, 0.16],
	"footstep_wood": [0.14, 155.0, 0.64, 0.12],
	"jump": [0.22, 185.0, 0.4, 0.12],
	"land": [0.24, 72.0, 0.78, 0.12],
	"swim": [0.34, 220.0, 0.72, 0.28],
	"eat": [0.2, 410.0, 0.48, 0.18],
	"drink": [0.32, 620.0, 0.38, 0.16],
	"breath": [0.55, 190.0, 0.72, 0.1],
	"exertion": [0.31, 145.0, 0.68, 0.16],
	"deer_call": [0.78, 540.0, 0.22, 0.14],
	"deer_alert": [0.32, 680.0, 0.3, 0.16],
	"deer_flee": [0.18, 360.0, 0.64, 0.13],
	"deer_step": [0.12, 170.0, 0.42, 0.15],
	"boar_step": [0.15, 105.0, 0.72, 0.16],
	"boar_growl": [0.62, 82.0, 0.56, 0.08],
	"boar_defend": [0.42, 68.0, 0.82, 0.1],
	"thunder": [1.35, 48.0, 0.86, 0.04],
	"lightning": [0.2, 310.0, 0.7, 0.12],
	"craft_axe": [0.31, 450.0, 0.46, 0.12],
	"craft_spear": [0.28, 380.0, 0.52, 0.1],
	"craft_campfire": [0.4, 260.0, 0.54, 0.12],
	"build_foundation": [0.38, 92.0, 0.78, 0.1],
	"build_wall": [0.32, 135.0, 0.68, 0.12],
	"build_door": [0.29, 175.0, 0.62, 0.14],
	"build_roof": [0.4, 118.0, 0.7, 0.1],
	"action_fail": [0.18, 180.0, 0.28, 0.02],
	"ui_click": [0.07, 780.0, 0.16, 0.01]
}
const LOOP_DEFINITIONS := {
	"ocean": [0.31, 52.0, 0.22],
	"birds": [0.47, 1050.0, 0.12],
	"insects": [0.55, 1900.0, 0.09],
	"wind": [0.42, 120.0, 0.24],
	"light_rain": [0.39, 2100.0, 0.18],
	"storm_rain": [0.35, 1650.0, 0.28],
	"campfire": [0.46, 680.0, 0.14]
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
var loop_streams: Dictionary = {}
var voice_cursor := 0
var ui_cursor := 0
var last_played_msec: Dictionary = {}
var sound_attempt_count: Dictionary = {}
var weather_name := "SUNNY"
var day_phase := 0.5
var audio_output_available := true
var audio_paused := false
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
	loop_streams.clear()
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
	if not SOUND_DEFINITIONS.has(sound_name):
		return false
	var now := Time.get_ticks_msec()
	if now - int(last_played_msec.get(sound_name, -1000000)) < cooldown_msec:
		return false
	var player := _get_next_world_voice()
	player.stream = _get_sound_stream(sound_name)
	player.bus = bus_name if _bus_exists(bus_name) else "SFX"
	player.volume_db = volume_db
	player.global_position = position
	if audio_output_available:
		player.play()
		player.stream_paused = audio_paused
	last_played_msec[sound_name] = now
	sound_attempt_count[sound_name] = int(sound_attempt_count.get(sound_name, 0)) + 1
	return true


func play_ui(sound_name: String, volume_db: float = -4.0) -> bool:
	if not SOUND_DEFINITIONS.has(sound_name):
		return false
	var player := _get_next_ui_voice()
	player.stream = _get_sound_stream(sound_name)
	player.bus = "SFX"
	player.volume_db = volume_db
	if audio_output_available:
		player.play()
		player.stream_paused = audio_paused
	sound_attempt_count[sound_name] = int(sound_attempt_count.get(sound_name, 0)) + 1
	return true


func play_event(sound_name: String, position: Vector3, cooldown_msec: int = 70) -> bool:
	return play_3d(sound_name, position, "SFX", -3.0, cooldown_msec)


func get_sound_names() -> Array[String]:
	var names: Array[String] = []
	for sound_name in SOUND_DEFINITIONS:
		names.append(sound_name)
	return names


func get_missing_asset_report() -> Dictionary:
	var report: Dictionary = {}
	for sound_name in SOUND_DEFINITIONS:
		report[sound_name] = "generated_placeholder"
	for loop_name in LOOP_DEFINITIONS:
		report[loop_name] = "generated_placeholder_loop"
	return report


func set_weather(next_weather: String) -> void:
	weather_name = next_weather.to_upper()
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
	for loop_name in LOOP_DEFINITIONS:
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
	if not ambience_players.has(loop_name):
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


func _get_sound_stream(sound_name: String) -> AudioStreamWAV:
	if sound_streams.has(sound_name):
		return sound_streams[sound_name]
	var definition: Array = SOUND_DEFINITIONS[sound_name]
	var stream := _synthesize(float(definition[0]), float(definition[1]), float(definition[2]), float(definition[3]), false)
	sound_streams[sound_name] = stream
	return stream


func _get_loop_stream(loop_name: String) -> AudioStreamWAV:
	if loop_streams.has(loop_name):
		return loop_streams[loop_name]
	var definition: Array = LOOP_DEFINITIONS[loop_name]
	var stream := _synthesize(float(definition[0]), float(definition[1]), float(definition[2]), 0.0, true)
	loop_streams[loop_name] = stream
	return stream


func _synthesize(duration: float, frequency: float, noise_amount: float, overtone: float, looping: bool) -> AudioStreamWAV:
	var sample_count := maxi(256, roundi(duration * float(SAMPLE_RATE)))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase := rng.randf_range(0.0, TAU)
	var loop_start := floori(float(sample_count) * 0.08) if looping else 0
	var loop_end := sample_count - floori(float(sample_count) * 0.08) if looping else sample_count
	var loop_samples := maxi(1, loop_end - loop_start)
	for index in range(sample_count):
		var time := float(index) / float(SAMPLE_RATE)
		var envelope := 1.0
		if not looping:
			var progress := float(index) / float(sample_count)
			envelope = minf(1.0, progress * 16.0) * pow(maxf(0.0, 1.0 - progress), 1.7)
		elif index < loop_start:
			envelope = float(index) / float(maxi(loop_start, 1))
		elif index >= loop_end:
			envelope = float(sample_count - index) / float(maxi(sample_count - loop_end, 1))
		var fundamental := sin(TAU * frequency * time + phase)
		var overtone_wave := sin(TAU * frequency * 2.03 * time + phase * 0.7)
		var noise := rng.randf_range(-1.0, 1.0)
		var sample := (fundamental * (1.0 - overtone) + overtone_wave * overtone + noise * noise_amount) * envelope * 0.34
		if looping and index >= loop_start and index < loop_end:
			var local_phase := float(index - loop_start) / float(loop_samples)
			sample += sin(TAU * (frequency * 0.37) * local_phase) * 0.035
		var pcm := clampi(roundi(clampf(sample, -1.0, 1.0) * 32767.0), -32768, 32767)
		data.encode_s16(index * 2, pcm)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = loop_start
		stream.loop_end = loop_end
	return stream


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
