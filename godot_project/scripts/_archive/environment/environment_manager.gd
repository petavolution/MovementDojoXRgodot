## EnvironmentManager - Manages dojo environments and visual themes
## Handles lighting, skybox, and environment transitions
class_name EnvironmentManager
extends Node3D

signal environment_changed(env_id: String)
signal theme_changed(theme_id: String)
signal transition_started(from_env: String, to_env: String)
signal transition_completed

## Environment presets
enum EnvironmentPreset {
	TRAINING_DOJO,
	NIGHT_TEMPLE,
	FOREST_CLEARING,
	MOUNTAIN_PEAK,
	VOID_SPACE,
	SUNRISE_GARDEN,
	SUNSET_BEACH,
	STARFIELD
}

## Visual themes (affect colors/effects)
enum VisualTheme {
	CLASSIC_BLUE,
	SITH_RED,
	JEDI_GREEN,
	NEUTRAL_WHITE,
	PURPLE_MYSTIC,
	GOLDEN_DAWN,
	DARK_MODE
}

## Current state
var current_environment: EnvironmentPreset = EnvironmentPreset.TRAINING_DOJO
var current_theme: VisualTheme = VisualTheme.CLASSIC_BLUE
var is_transitioning: bool = false

## Scene components
var world_environment: WorldEnvironment
var directional_light: DirectionalLight3D
var ambient_particles: GPUParticles3D
var skybox_material: ShaderMaterial

## Environment objects
var floor_mesh: MeshInstance3D
var walls: Array[MeshInstance3D] = []
var props: Array[Node3D] = []

## Transition
var transition_duration: float = 2.0
var transition_progress: float = 0.0
var from_env_data: Dictionary = {}
var to_env_data: Dictionary = {}

## Environment configurations
var environment_configs: Dictionary = {}
var theme_colors: Dictionary = {}


func _ready() -> void:
	_setup_environment_configs()
	_setup_theme_colors()
	_create_base_environment()
	apply_environment(current_environment)
	apply_theme(current_theme)


func _process(delta: float) -> void:
	if is_transitioning:
		_process_transition(delta)


func _setup_environment_configs() -> void:
	# Training Dojo - default indoor training space
	environment_configs[EnvironmentPreset.TRAINING_DOJO] = {
		"name": "Training Dojo",
		"sky_color_top": Color(0.1, 0.15, 0.25),
		"sky_color_bottom": Color(0.05, 0.08, 0.15),
		"ambient_color": Color(0.15, 0.2, 0.3),
		"ambient_energy": 0.3,
		"sun_color": Color(0.9, 0.85, 0.8),
		"sun_energy": 0.5,
		"sun_angle": Vector3(-45, 30, 0),
		"fog_enabled": false,
		"floor_color": Color(0.08, 0.1, 0.15),
		"glow_enabled": true,
		"glow_intensity": 0.5
	}

	# Night Temple - mystical night setting
	environment_configs[EnvironmentPreset.NIGHT_TEMPLE] = {
		"name": "Night Temple",
		"sky_color_top": Color(0.02, 0.03, 0.08),
		"sky_color_bottom": Color(0.05, 0.05, 0.12),
		"ambient_color": Color(0.1, 0.1, 0.2),
		"ambient_energy": 0.2,
		"sun_color": Color(0.6, 0.7, 0.9),
		"sun_energy": 0.2,
		"sun_angle": Vector3(-70, 45, 0),
		"fog_enabled": true,
		"fog_color": Color(0.05, 0.05, 0.1),
		"fog_density": 0.02,
		"floor_color": Color(0.05, 0.05, 0.1),
		"glow_enabled": true,
		"glow_intensity": 0.8
	}

	# Forest Clearing - natural outdoor setting
	environment_configs[EnvironmentPreset.FOREST_CLEARING] = {
		"name": "Forest Clearing",
		"sky_color_top": Color(0.4, 0.6, 0.9),
		"sky_color_bottom": Color(0.7, 0.8, 0.9),
		"ambient_color": Color(0.3, 0.4, 0.3),
		"ambient_energy": 0.5,
		"sun_color": Color(1.0, 0.95, 0.8),
		"sun_energy": 1.0,
		"sun_angle": Vector3(-50, 60, 0),
		"fog_enabled": true,
		"fog_color": Color(0.6, 0.7, 0.6),
		"fog_density": 0.005,
		"floor_color": Color(0.15, 0.2, 0.1),
		"glow_enabled": false,
		"glow_intensity": 0.3
	}

	# Mountain Peak - high altitude setting
	environment_configs[EnvironmentPreset.MOUNTAIN_PEAK] = {
		"name": "Mountain Peak",
		"sky_color_top": Color(0.2, 0.3, 0.6),
		"sky_color_bottom": Color(0.5, 0.6, 0.8),
		"ambient_color": Color(0.4, 0.45, 0.5),
		"ambient_energy": 0.4,
		"sun_color": Color(1.0, 0.9, 0.7),
		"sun_energy": 1.2,
		"sun_angle": Vector3(-30, 80, 0),
		"fog_enabled": true,
		"fog_color": Color(0.7, 0.75, 0.85),
		"fog_density": 0.01,
		"floor_color": Color(0.3, 0.28, 0.25),
		"glow_enabled": true,
		"glow_intensity": 0.4
	}

	# Void Space - abstract dark space
	environment_configs[EnvironmentPreset.VOID_SPACE] = {
		"name": "Void Space",
		"sky_color_top": Color(0.0, 0.0, 0.02),
		"sky_color_bottom": Color(0.0, 0.0, 0.05),
		"ambient_color": Color(0.05, 0.05, 0.1),
		"ambient_energy": 0.1,
		"sun_color": Color(0.3, 0.3, 0.5),
		"sun_energy": 0.1,
		"sun_angle": Vector3(-90, 0, 0),
		"fog_enabled": false,
		"floor_color": Color(0.02, 0.02, 0.05),
		"glow_enabled": true,
		"glow_intensity": 1.0
	}

	# Sunrise Garden - peaceful morning
	environment_configs[EnvironmentPreset.SUNRISE_GARDEN] = {
		"name": "Sunrise Garden",
		"sky_color_top": Color(0.5, 0.4, 0.5),
		"sky_color_bottom": Color(0.9, 0.6, 0.4),
		"ambient_color": Color(0.5, 0.4, 0.4),
		"ambient_energy": 0.4,
		"sun_color": Color(1.0, 0.7, 0.4),
		"sun_energy": 0.8,
		"sun_angle": Vector3(-10, 90, 0),
		"fog_enabled": true,
		"fog_color": Color(0.9, 0.7, 0.5),
		"fog_density": 0.008,
		"floor_color": Color(0.2, 0.18, 0.12),
		"glow_enabled": true,
		"glow_intensity": 0.6
	}

	# Sunset Beach - warm evening
	environment_configs[EnvironmentPreset.SUNSET_BEACH] = {
		"name": "Sunset Beach",
		"sky_color_top": Color(0.3, 0.2, 0.4),
		"sky_color_bottom": Color(0.9, 0.5, 0.3),
		"ambient_color": Color(0.5, 0.35, 0.3),
		"ambient_energy": 0.35,
		"sun_color": Color(1.0, 0.5, 0.2),
		"sun_energy": 0.6,
		"sun_angle": Vector3(-5, 270, 0),
		"fog_enabled": true,
		"fog_color": Color(0.8, 0.5, 0.4),
		"fog_density": 0.01,
		"floor_color": Color(0.7, 0.65, 0.5),
		"glow_enabled": true,
		"glow_intensity": 0.7
	}

	# Starfield - space setting
	environment_configs[EnvironmentPreset.STARFIELD] = {
		"name": "Starfield",
		"sky_color_top": Color(0.0, 0.0, 0.02),
		"sky_color_bottom": Color(0.02, 0.0, 0.05),
		"ambient_color": Color(0.1, 0.1, 0.15),
		"ambient_energy": 0.15,
		"sun_color": Color(0.8, 0.85, 1.0),
		"sun_energy": 0.3,
		"sun_angle": Vector3(-60, 120, 0),
		"fog_enabled": false,
		"floor_color": Color(0.03, 0.03, 0.05),
		"glow_enabled": true,
		"glow_intensity": 1.2
	}


func _setup_theme_colors() -> void:
	theme_colors[VisualTheme.CLASSIC_BLUE] = {
		"primary": Color(0.2, 0.6, 1.0),
		"secondary": Color(0.4, 0.8, 1.0),
		"accent": Color(0.1, 0.4, 0.8),
		"blade_color": Color(0.3, 0.7, 1.0)
	}

	theme_colors[VisualTheme.SITH_RED] = {
		"primary": Color(1.0, 0.2, 0.1),
		"secondary": Color(1.0, 0.4, 0.3),
		"accent": Color(0.8, 0.1, 0.0),
		"blade_color": Color(1.0, 0.2, 0.1)
	}

	theme_colors[VisualTheme.JEDI_GREEN] = {
		"primary": Color(0.2, 0.9, 0.3),
		"secondary": Color(0.4, 1.0, 0.5),
		"accent": Color(0.1, 0.7, 0.2),
		"blade_color": Color(0.3, 1.0, 0.4)
	}

	theme_colors[VisualTheme.NEUTRAL_WHITE] = {
		"primary": Color(0.9, 0.9, 0.95),
		"secondary": Color(0.8, 0.8, 0.85),
		"accent": Color(0.7, 0.7, 0.75),
		"blade_color": Color(0.95, 0.95, 1.0)
	}

	theme_colors[VisualTheme.PURPLE_MYSTIC] = {
		"primary": Color(0.6, 0.2, 0.9),
		"secondary": Color(0.8, 0.4, 1.0),
		"accent": Color(0.5, 0.1, 0.7),
		"blade_color": Color(0.7, 0.3, 1.0)
	}

	theme_colors[VisualTheme.GOLDEN_DAWN] = {
		"primary": Color(1.0, 0.8, 0.2),
		"secondary": Color(1.0, 0.9, 0.5),
		"accent": Color(0.9, 0.7, 0.1),
		"blade_color": Color(1.0, 0.85, 0.3)
	}

	theme_colors[VisualTheme.DARK_MODE] = {
		"primary": Color(0.3, 0.3, 0.35),
		"secondary": Color(0.2, 0.2, 0.25),
		"accent": Color(0.4, 0.4, 0.45),
		"blade_color": Color(0.5, 0.5, 0.6)
	}


func _create_base_environment() -> void:
	# Create WorldEnvironment
	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR

	# Enable glow
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.1

	# Tone mapping
	env.tonemap_mode = Environment.TONE_MAPPER_ACES

	world_environment.environment = env
	add_child(world_environment)

	# Create directional light
	directional_light = DirectionalLight3D.new()
	directional_light.name = "SunLight"
	directional_light.shadow_enabled = true
	directional_light.light_energy = 1.0
	add_child(directional_light)

	# Create floor
	floor_mesh = MeshInstance3D.new()
	floor_mesh.name = "Floor"

	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(20, 20)

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.1, 0.1, 0.15)
	floor_mat.roughness = 0.8
	floor_plane.material = floor_mat

	floor_mesh.mesh = floor_plane
	add_child(floor_mesh)

	# Create ambient particles
	_create_ambient_particles()


func _create_ambient_particles() -> void:
	ambient_particles = GPUParticles3D.new()
	ambient_particles.name = "AmbientParticles"
	ambient_particles.amount = 100
	ambient_particles.lifetime = 10.0
	ambient_particles.emitting = true

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(5, 3, 5)
	material.gravity = Vector3(0, 0.05, 0)
	material.initial_velocity_min = 0.1
	material.initial_velocity_max = 0.3
	material.direction = Vector3(0, 1, 0)
	material.spread = 30.0
	material.scale_min = 0.02
	material.scale_max = 0.05

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.5, 0.7, 1.0, 0.0))
	gradient.set_color(1, Color(0.5, 0.7, 1.0, 0.3))
	gradient.add_point(0.5, Color(0.5, 0.7, 1.0, 0.5))

	var color_texture := GradientTexture1D.new()
	color_texture.gradient = gradient
	material.color_ramp = color_texture

	ambient_particles.process_material = material

	# Simple mesh for particles
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var draw_mat := StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = draw_mat
	ambient_particles.draw_pass_1 = quad

	add_child(ambient_particles)


func apply_environment(preset: EnvironmentPreset, instant: bool = false) -> void:
	var config: Dictionary = environment_configs.get(preset, {})
	if config.is_empty():
		return

	if instant or not is_inside_tree():
		_apply_environment_config(config)
		current_environment = preset
		environment_changed.emit(config.get("name", ""))
	else:
		_start_transition(preset)


func _apply_environment_config(config: Dictionary) -> void:
	var env := world_environment.environment

	# Sky colors
	env.background_color = config.get("sky_color_bottom", Color.BLACK)

	# Ambient light
	env.ambient_light_color = config.get("ambient_color", Color.WHITE)
	env.ambient_light_energy = config.get("ambient_energy", 0.5)

	# Glow
	env.glow_enabled = config.get("glow_enabled", true)
	env.glow_intensity = config.get("glow_intensity", 0.5)

	# Fog
	env.fog_enabled = config.get("fog_enabled", false)
	if env.fog_enabled:
		env.fog_light_color = config.get("fog_color", Color.WHITE)
		env.fog_density = config.get("fog_density", 0.01)

	# Sun
	directional_light.light_color = config.get("sun_color", Color.WHITE)
	directional_light.light_energy = config.get("sun_energy", 1.0)

	var sun_angle: Vector3 = config.get("sun_angle", Vector3(-45, 0, 0))
	directional_light.rotation_degrees = sun_angle

	# Floor
	var floor_color: Color = config.get("floor_color", Color(0.1, 0.1, 0.1))
	var floor_mat := floor_mesh.mesh.material as StandardMaterial3D
	if floor_mat:
		floor_mat.albedo_color = floor_color


func apply_theme(theme: VisualTheme) -> void:
	current_theme = theme

	var colors: Dictionary = theme_colors.get(theme, {})
	if colors.is_empty():
		return

	# Update ambient particle color
	if ambient_particles and ambient_particles.process_material:
		var mat := ambient_particles.process_material as ParticleProcessMaterial
		if mat and mat.color_ramp:
			var gradient := (mat.color_ramp as GradientTexture1D).gradient
			if gradient:
				var primary: Color = colors.get("primary", Color.WHITE)
				gradient.set_color(0, Color(primary.r, primary.g, primary.b, 0.0))
				gradient.set_color(1, Color(primary.r, primary.g, primary.b, 0.3))

	# Emit signal for other systems to update
	theme_changed.emit(get_theme_name(theme))


func _start_transition(to_preset: EnvironmentPreset) -> void:
	if is_transitioning:
		return

	var from_config: Dictionary = environment_configs.get(current_environment, {})
	var to_config: Dictionary = environment_configs.get(to_preset, {})

	from_env_data = from_config
	to_env_data = to_config

	is_transitioning = true
	transition_progress = 0.0

	transition_started.emit(
		from_config.get("name", ""),
		to_config.get("name", "")
	)


func _process_transition(delta: float) -> void:
	transition_progress += delta / transition_duration

	if transition_progress >= 1.0:
		transition_progress = 1.0
		is_transitioning = false
		_apply_environment_config(to_env_data)
		current_environment = _get_preset_from_name(to_env_data.get("name", ""))
		transition_completed.emit()
		environment_changed.emit(to_env_data.get("name", ""))
		return

	# Interpolate environment values
	_interpolate_environment(transition_progress)


func _interpolate_environment(t: float) -> void:
	var env := world_environment.environment

	# Interpolate colors
	env.background_color = from_env_data.get("sky_color_bottom", Color.BLACK).lerp(
		to_env_data.get("sky_color_bottom", Color.BLACK), t)

	env.ambient_light_color = from_env_data.get("ambient_color", Color.WHITE).lerp(
		to_env_data.get("ambient_color", Color.WHITE), t)

	env.ambient_light_energy = lerpf(
		from_env_data.get("ambient_energy", 0.5),
		to_env_data.get("ambient_energy", 0.5), t)

	env.glow_intensity = lerpf(
		from_env_data.get("glow_intensity", 0.5),
		to_env_data.get("glow_intensity", 0.5), t)

	# Sun
	directional_light.light_color = from_env_data.get("sun_color", Color.WHITE).lerp(
		to_env_data.get("sun_color", Color.WHITE), t)

	directional_light.light_energy = lerpf(
		from_env_data.get("sun_energy", 1.0),
		to_env_data.get("sun_energy", 1.0), t)


func _get_preset_from_name(env_name: String) -> EnvironmentPreset:
	for preset in environment_configs:
		if environment_configs[preset].get("name", "") == env_name:
			return preset
	return EnvironmentPreset.TRAINING_DOJO


## Utility functions
func get_environment_name(preset: EnvironmentPreset) -> String:
	var config: Dictionary = environment_configs.get(preset, {})
	return config.get("name", "Unknown")


func get_theme_name(theme: VisualTheme) -> String:
	match theme:
		VisualTheme.CLASSIC_BLUE: return "Classic Blue"
		VisualTheme.SITH_RED: return "Sith Red"
		VisualTheme.JEDI_GREEN: return "Jedi Green"
		VisualTheme.NEUTRAL_WHITE: return "Neutral White"
		VisualTheme.PURPLE_MYSTIC: return "Purple Mystic"
		VisualTheme.GOLDEN_DAWN: return "Golden Dawn"
		VisualTheme.DARK_MODE: return "Dark Mode"
	return "Unknown"


func get_theme_colors() -> Dictionary:
	return theme_colors.get(current_theme, {})


func get_available_environments() -> Array[EnvironmentPreset]:
	return [
		EnvironmentPreset.TRAINING_DOJO,
		EnvironmentPreset.NIGHT_TEMPLE,
		EnvironmentPreset.FOREST_CLEARING,
		EnvironmentPreset.MOUNTAIN_PEAK,
		EnvironmentPreset.VOID_SPACE,
		EnvironmentPreset.SUNRISE_GARDEN,
		EnvironmentPreset.SUNSET_BEACH,
		EnvironmentPreset.STARFIELD
	]


func get_available_themes() -> Array[VisualTheme]:
	return [
		VisualTheme.CLASSIC_BLUE,
		VisualTheme.SITH_RED,
		VisualTheme.JEDI_GREEN,
		VisualTheme.NEUTRAL_WHITE,
		VisualTheme.PURPLE_MYSTIC,
		VisualTheme.GOLDEN_DAWN,
		VisualTheme.DARK_MODE
	]


func cycle_environment() -> void:
	var envs := get_available_environments()
	var current_idx := envs.find(current_environment)
	var next_idx := (current_idx + 1) % envs.size()
	apply_environment(envs[next_idx])


func cycle_theme() -> void:
	var themes := get_available_themes()
	var current_idx := themes.find(current_theme)
	var next_idx := (current_idx + 1) % themes.size()
	apply_theme(themes[next_idx])
