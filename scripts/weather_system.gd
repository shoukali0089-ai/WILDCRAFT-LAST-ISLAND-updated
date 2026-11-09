extends Node3D

signal weather_changed(weather_name: String)

enum WeatherState { SUNNY, CLOUDY, RAINY, STORM }

const WEATHER_NAMES := ["SUNNY", "CLOUDY", "RAINY", "STORM"]
const WEATHER_CLOUDS := [0.0, 0.78, 0.9, 1.0]
const WEATHER_RAIN := [0.0, 0.0, 0.58, 1.0]
const WEATHER_WIND := [0.12, 0.28, 0.58, 1.0]
const WEATHER_SUNLIGHT := [1.0, 0.68, 0.52, 0.36]
const WEATHER_AMBIENT := [1.0, 0.91, 0.78, 0.68]
const WEATHER_TEMPERATURE := [27.0, 24.0, 20.0, 16.0]
const SHELTER_TEMPERATURE := 25.0
const RAIN_PARTICLE_COUNT := 360
const SHELTER_CHECK_INTERVAL := 0.3
const FOLLOW_UPDATE_INTERVAL := 0.12
const WIND_UPDATE_INTERVAL := 0.12

@export_range(10.0, 600.0, 1.0) var weather_duration_min := 55.0
@export_range(10.0, 600.0, 1.0) var weather_duration_max := 100.0
@export_range(0.5, 60.0, 0.5) var transition_duration := 8.0
@export_range(0.01, 1.0, 0.01) var temperature_change_per_second := 0.08
@export var automatic_weather_enabled := true
@export var thunder_stream: AudioStream

var weather_state: WeatherState = WeatherState.SUNNY
var temperature := 26.0
var is_player_sheltered := false
var cloud_amount := 0.0
var rain_amount := 0.0
var wind_strength := 0.12
var daylight := 0.5
var weather_remaining := 0.0
var transition_remaining := 0.0
var shelter_check_timer := 0.0
var follow_timer := 0.0
var wind_timer := 0.0
var wind_phase := 0.0
var lightning_timer := 0.0
var lightning_flash := 0.0
var lightning_visible_time := 0.0

var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var player: CharacterBody3D
var shelter_check: Callable
var wind_parts: Array[Node3D] = []
var wind_base_rotations: Dictionary = {}
var cloud_layer: MultiMeshInstance3D
var cloud_material: StandardMaterial3D
var rain_particles: GPUParticles3D
var lightning_root: Node3D
var lightning_segments: Array[MeshInstance3D] = []
var lightning_light: OmniLight3D
var thunder_player: AudioStreamPlayer3D
var rng := RandomNumberGenerator.new()

var _from_clouds := 0.0
var _from_rain := 0.0
var _from_wind := 0.12
var _from_sunlight := 1.0
var _from_ambient := 1.0
var _target_clouds := 0.0
var _target_rain := 0.0
var _target_wind := 0.12
var _target_sunlight := 1.0
var _target_ambient := 1.0
var _current_sunlight := 1.0
var _current_ambient := 1.0
var _transition_elapsed := 0.0
var _transition_length := 0.0
var _shelter_check_elapsed := 0.0
var _follow_elapsed := 0.0
var _wind_elapsed := 0.0


func configure(
	environment_node: WorldEnvironment,
	sun_light: DirectionalLight3D,
	actor: CharacterBody3D,
	shelter_callback: Callable,
	vegetation: Array[Node3D]
) -> void:
	world_environment = environment_node
	sun = sun_light
	player = actor
	shelter_check = shelter_callback
	wind_parts = vegetation.duplicate()
	for part in wind_parts:
		if is_instance_valid(part):
			wind_base_rotations[part.get_instance_id()] = part.rotation


func _ready() -> void:
	rng.seed = 198431
	_create_cloud_layer()
	_create_rain_effect()
	_create_lightning_effect()
	_create_thunder_player()
	weather_remaining = rng.randf_range(weather_duration_min, weather_duration_max)
	_update_shelter_state()
	_apply_visuals()


func _process(delta: float) -> void:
	var step := minf(delta, 0.25)
	if transition_remaining > 0.0:
		_transition_elapsed = minf(_transition_elapsed + step, _transition_length)
		var progress := _transition_elapsed / _transition_length
		var eased_progress := progress * progress * (3.0 - 2.0 * progress)
		cloud_amount = lerpf(_from_clouds, _target_clouds, eased_progress)
		rain_amount = lerpf(_from_rain, _target_rain, eased_progress)
		wind_strength = lerpf(_from_wind, _target_wind, eased_progress)
		_current_sunlight = lerpf(_from_sunlight, _target_sunlight, eased_progress)
		_current_ambient = lerpf(_from_ambient, _target_ambient, eased_progress)
		transition_remaining = maxf(0.0, _transition_length - _transition_elapsed)
		if transition_remaining == 0.0:
			weather_remaining = rng.randf_range(weather_duration_min, weather_duration_max)
	elif automatic_weather_enabled:
		weather_remaining -= step
		if weather_remaining <= 0.0:
			_select_next_weather()

	var target_temperature: float = SHELTER_TEMPERATURE if is_player_sheltered else WEATHER_TEMPERATURE[weather_state]
	temperature = move_toward(temperature, target_temperature, temperature_change_per_second * step)

	_shelter_check_elapsed += step
	if _shelter_check_elapsed >= SHELTER_CHECK_INTERVAL:
		_shelter_check_elapsed = 0.0
		_update_shelter_state()

	_follow_elapsed += step
	if _follow_elapsed >= FOLLOW_UPDATE_INTERVAL:
		_follow_elapsed = 0.0
		_update_effect_positions()

	_wind_elapsed += step
	if _wind_elapsed >= WIND_UPDATE_INTERVAL:
		var wind_step := _wind_elapsed
		_wind_elapsed = 0.0
		_update_wind(wind_step)

	_update_lightning(step)
	_apply_visuals()


func set_weather(weather_name: String, seconds: float = -1.0) -> bool:
	var state_index := WEATHER_NAMES.find(weather_name.to_upper())
	if state_index < 0:
		return false
	return set_weather_state(state_index, seconds)


func set_weather_state(next_state: int, seconds: float = -1.0) -> bool:
	if next_state < 0 or next_state >= WEATHER_NAMES.size():
		return false
	if next_state == weather_state:
		return true
	_from_clouds = cloud_amount
	_from_rain = rain_amount
	_from_wind = wind_strength
	_from_sunlight = _current_sunlight
	_from_ambient = _current_ambient
	weather_state = next_state as WeatherState
	_target_clouds = WEATHER_CLOUDS[weather_state]
	_target_rain = WEATHER_RAIN[weather_state]
	_target_wind = WEATHER_WIND[weather_state]
	_target_sunlight = WEATHER_SUNLIGHT[weather_state]
	_target_ambient = WEATHER_AMBIENT[weather_state]
	_transition_length = maxf(0.1, transition_duration if seconds < 0.0 else seconds)
	_transition_elapsed = 0.0
	transition_remaining = _transition_length
	weather_remaining = 0.0
	if weather_state == WeatherState.STORM:
		lightning_timer = rng.randf_range(2.0, 5.0)
	weather_changed.emit(get_weather_name())
	return true


func get_weather_name() -> String:
	return WEATHER_NAMES[weather_state]


func get_temperature() -> float:
	return temperature


func get_display_text() -> String:
	var icon_text: String = ["SUN", "CLOUD", "RAIN", "STORM"][weather_state]
	return "%s  •  %.1f C" % [icon_text, temperature]


func set_daylight(value: float) -> void:
	daylight = clampf(value, 0.0, 1.0)


func set_thunder_stream(stream: AudioStream) -> void:
	thunder_stream = stream
	if is_instance_valid(thunder_player):
		thunder_player.stream = stream


func refresh_shelter_state() -> void:
	_update_shelter_state()


func _select_next_weather() -> void:
	var offset := rng.randi_range(1, WEATHER_NAMES.size() - 1)
	var next_state := posmod(weather_state + offset, WEATHER_NAMES.size())
	set_weather_state(next_state, transition_duration)


func _update_shelter_state() -> void:
	var sheltered := false
	if is_instance_valid(player) and shelter_check.is_valid():
		sheltered = bool(shelter_check.call(player.global_position))
	is_player_sheltered = sheltered


func _create_cloud_layer() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	cloud_material = StandardMaterial3D.new()
	cloud_material.albedo_color = Color(0.53, 0.57, 0.64, 0.0)
	cloud_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	sphere.material = cloud_material

	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = sphere
	multi_mesh.instance_count = 8
	for index in range(multi_mesh.instance_count):
		var angle := TAU * float(index) / float(multi_mesh.instance_count)
		var position := Vector3(cos(angle) * 17.0, 18.0 + float(index % 3), sin(angle) * 17.0)
		var basis := Basis(Vector3.UP, angle * 0.37).scaled(Vector3(13.0, 1.5, 8.0))
		multi_mesh.set_instance_transform(index, Transform3D(basis, position))

	cloud_layer = MultiMeshInstance3D.new()
	cloud_layer.name = "ProceduralCloudLayer"
	cloud_layer.multimesh = multi_mesh
	cloud_layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloud_layer.custom_aabb = AABB(Vector3(-38.0, 12.0, -38.0), Vector3(76.0, 18.0, 76.0))
	add_child(cloud_layer)


func _create_rain_effect() -> void:
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(9.0, 4.0, 9.0)
	process_material.direction = Vector3(0.0, -1.0, 0.0)
	process_material.spread = 4.0
	process_material.gravity = Vector3(0.0, -4.0, 0.0)
	process_material.initial_velocity_min = 14.0
	process_material.initial_velocity_max = 18.0
	process_material.damping_min = 0.0
	process_material.damping_max = 0.0

	var rain_material := StandardMaterial3D.new()
	rain_material.albedo_color = Color(0.62, 0.78, 0.95, 0.58)
	rain_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var rain_mesh := QuadMesh.new()
	rain_mesh.size = Vector2(0.025, 0.3)
	rain_mesh.material = rain_material
	rain_particles = GPUParticles3D.new()
	rain_particles.name = "RainParticles"
	rain_particles.amount = RAIN_PARTICLE_COUNT
	rain_particles.amount_ratio = 0.0
	rain_particles.lifetime = 0.9
	rain_particles.local_coords = true
	rain_particles.emitting = false
	rain_particles.process_material = process_material
	rain_particles.draw_pass_1 = rain_mesh
	add_child(rain_particles)


func _create_lightning_effect() -> void:
	lightning_root = Node3D.new()
	lightning_root.name = "StormLightning"
	lightning_root.hide()
	add_child(lightning_root)
	var lightning_material := StandardMaterial3D.new()
	lightning_material.albedo_color = Color(0.78, 0.9, 1.0)
	lightning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lightning_material.emission_enabled = true
	lightning_material.emission = Color(0.7, 0.85, 1.0)
	lightning_material.emission_energy_multiplier = 3.0
	var previous_point := Vector3.ZERO
	for index in range(7):
		var next_point := Vector3(
			rng.randf_range(-0.9, 0.9),
			-2.0 - float(index) * 2.5,
			rng.randf_range(-0.9, 0.9)
		)
		var segment := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.018
		mesh.bottom_radius = 0.04
		mesh.height = previous_point.distance_to(next_point)
		mesh.material = lightning_material
		segment.mesh = mesh
		segment.position = (previous_point + next_point) * 0.5
		segment.quaternion = Quaternion(Vector3.UP, (next_point - previous_point).normalized())
		lightning_root.add_child(segment)
		lightning_segments.append(segment)
		previous_point = next_point

	lightning_light = OmniLight3D.new()
	lightning_light.name = "LightningFlash"
	lightning_light.position = Vector3(0.0, -8.0, 0.0)
	lightning_light.light_color = Color(0.68, 0.82, 1.0)
	lightning_light.light_energy = 0.0
	lightning_light.omni_range = 28.0
	lightning_root.add_child(lightning_light)


func _create_thunder_player() -> void:
	thunder_player = AudioStreamPlayer3D.new()
	thunder_player.name = "OptionalThunderAudio"
	thunder_player.max_distance = 90.0
	thunder_player.volume_db = -4.0
	thunder_player.stream = thunder_stream
	add_child(thunder_player)


func _update_lightning(delta: float) -> void:
	lightning_flash = move_toward(lightning_flash, 0.0, delta * 6.0)
	lightning_visible_time = maxf(0.0, lightning_visible_time - delta)
	if lightning_visible_time == 0.0 and is_instance_valid(lightning_root):
		lightning_root.hide()
		lightning_light.light_energy = 0.0

	if weather_state != WeatherState.STORM or transition_remaining > 0.0:
		return
	lightning_timer -= delta
	if lightning_timer <= 0.0:
		_trigger_lightning()
		lightning_timer = rng.randf_range(6.0, 13.0)


func _trigger_lightning() -> void:
	if not is_instance_valid(player):
		return
	lightning_root.position = player.global_position + Vector3(
		rng.randf_range(-14.0, 14.0),
		21.0,
		rng.randf_range(-14.0, 14.0)
	)
	lightning_root.show()
	lightning_visible_time = 0.16
	lightning_flash = 0.85
	lightning_light.light_energy = 4.0
	if thunder_player.stream != null:
		thunder_player.global_position = lightning_root.global_position
		thunder_player.play()


func _update_effect_positions() -> void:
	if not is_instance_valid(player):
		return
	rain_particles.global_position = player.global_position + Vector3(0.0, 8.0, 0.0)
	cloud_layer.global_position = Vector3(player.global_position.x, 0.0, player.global_position.z)


func _update_wind(delta: float) -> void:
	wind_phase += delta * (0.6 + wind_strength * 2.2)
	var sway_amount := wind_strength * 0.08
	for index in range(wind_parts.size()):
		var part := wind_parts[index]
		if not is_instance_valid(part):
			continue
		var base_rotation: Vector3 = wind_base_rotations.get(part.get_instance_id(), part.rotation)
		var phase := wind_phase + float(index) * 0.31
		var target_rotation := base_rotation + Vector3(
			sin(phase) * sway_amount,
			0.0,
			cos(phase * 0.83) * sway_amount
		)
		part.rotation = part.rotation.lerp(target_rotation, 0.45)


func _apply_visuals() -> void:
	if not is_instance_valid(world_environment) or not is_instance_valid(sun):
		return
	cloud_material.albedo_color.a = cloud_amount * 0.76
	cloud_layer.visible = cloud_amount > 0.015
	rain_particles.amount_ratio = rain_amount * (0.58 + wind_strength * 0.42)
	rain_particles.emitting = rain_amount > 0.015 and not is_player_sheltered
	world_environment.environment.fog_enabled = true
	world_environment.environment.fog_density = 0.0005 + rain_amount * 0.004
	world_environment.environment.fog_light_color = Color(0.63, 0.71, 0.78).lerp(
		Color(0.38, 0.47, 0.57),
		rain_amount
	)
	sun.light_energy = daylight * 1.35 * _current_sunlight + lightning_flash * 3.5
	world_environment.environment.ambient_light_energy = (
		0.25 + daylight * 0.48
	) * _current_ambient

