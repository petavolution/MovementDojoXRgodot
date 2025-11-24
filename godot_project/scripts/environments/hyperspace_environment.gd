## HyperspaceEnvironment - Spaceship cockpit flying through hyperspace
## Player stands in a small platform/cockpit with star streaks flying by
##
## Layout:
##   - Hexagonal platform (5m diameter)
##   - Console railings for sci-fi flavor
##   - Surrounding dark space dome
##   - Animated hyperspace streaks (elongated emissive lines)
extends BaseEnvironment
class_name HyperspaceEnvironment

const ENV_SOURCE := "Hyperspace"

# =============================================================================
# CONFIGURATION
# =============================================================================

## Platform configuration
@export var platform_radius := 2.5
@export var platform_height := 0.15
@export var platform_segments := 6  # Hexagonal

## Console/railing configuration
@export var console_height := 0.9
@export var console_width := 1.2
@export var console_depth := 0.3

## Space dome configuration
@export var dome_radius := 50.0

## Hyperspace streaks
@export var num_streaks := 60
@export var streak_min_length := 5.0
@export var streak_max_length := 15.0
@export var streak_min_distance := 8.0
@export var streak_max_distance := 40.0
@export var streak_speed := 20.0  # Units per second
@export var animate_streaks := true

## Colors
@export var platform_color := Color(0.15, 0.18, 0.22)
@export var console_color := Color(0.1, 0.12, 0.15)
@export var console_screen_color := Color(0.2, 0.6, 0.9)
@export var streak_color := Color(0.7, 0.85, 1.0)
@export var streak_core_color := Color(1.0, 1.0, 1.0)
@export var space_color := Color(0.02, 0.02, 0.05)

# =============================================================================
# STATE
# =============================================================================

var streaks: Array[MeshInstance3D] = []
var streak_velocities: Array[float] = []
var streak_data: Array[Dictionary] = []

# =============================================================================
# IMPLEMENTATION
# =============================================================================

func get_environment_name() -> String:
	return "Hyperspace"


func _build_environment() -> void:
	_build_space_environment()
	_build_platform()
	_build_consoles()
	_build_hyperspace_streaks()

	DebugLogger.info(ENV_SOURCE, "Platform: hexagonal %.1fm radius" % platform_radius)
	DebugLogger.info(ENV_SOURCE, "Hyperspace: %d streaks, speed %.1f m/s" % [num_streaks, streak_speed])


func _process(delta: float) -> void:
	if animate_streaks and is_built:
		_update_streaks(delta)


func _build_space_environment() -> void:
	# Dark space environment
	_create_world_environment(
		space_color,
		Color(0.1, 0.15, 0.25),  # Subtle blue ambient
		0.2,
		true,  # fog
		Color(0.05, 0.08, 0.15),  # Dark blue fog
		0.001
	)

	# Minimal ambient light from streaks
	var ambient := DirectionalLight3D.new()
	ambient.name = "AmbientLight"
	ambient.light_color = Color(0.6, 0.7, 1.0)
	ambient.light_energy = 0.3
	ambient.shadow_enabled = false
	ambient.look_at_from_position(Vector3(0, 5, 0), Vector3.ZERO, Vector3.FORWARD)
	_add_geometry(ambient)


func _build_platform() -> void:
	# Create hexagonal platform using ring (approximation)
	# For true hexagon, we'd use ArrayMesh, but ring works well enough

	# Main platform surface
	var platform := ProceduralMeshes.create_ring(
		0.0,  # solid center
		platform_radius,
		platform_color,
		Vector3(0, 0, 0),
		platform_segments * 4  # More segments for smooth edge
	)
	platform.name = "Platform"
	var platform_mat := ProceduralMeshes.create_simple_pbr_material(platform_color, 0.6, 0.4)
	platform.material_override = platform_mat
	_add_geometry(platform)

	# Platform edge trim (glowing)
	var edge := ProceduralMeshes.create_ring(
		platform_radius - 0.08,
		platform_radius,
		console_screen_color,
		Vector3(0, 0.01, 0),
		platform_segments * 4
	)
	edge.name = "PlatformEdge"
	edge.material_override = ProceduralMeshes.create_emissive_material(
		console_screen_color,
		Color(-1,-1,-1),
		0.8
	)
	_add_geometry(edge)

	# Platform underside (gives depth)
	var underside := ProceduralMeshes.create_cylinder(
		platform_radius,
		platform_height,
		Color(0.08, 0.1, 0.12),
		Vector3(0, -platform_height/2, 0),
		ProceduralMeshes.CylinderAxis.Y,
		platform_segments * 2
	)
	underside.name = "PlatformBase"
	_add_geometry(underside)

	# Center accent ring
	var center_ring := ProceduralMeshes.create_ring(
		0.3,
		0.5,
		console_screen_color,
		Vector3(0, 0.02, 0),
		24
	)
	center_ring.name = "CenterRing"
	center_ring.material_override = ProceduralMeshes.create_emissive_material(
		console_screen_color,
		Color(-1,-1,-1),
		0.5
	)
	_add_geometry(center_ring)


func _build_consoles() -> void:
	# Front console (main display)
	_create_console(Vector3(0, 0, -platform_radius + 0.5), 0, "Front")

	# Side consoles (smaller)
	_create_console(Vector3(-platform_radius + 0.6, 0, -0.5), 45, "Left", 0.7)
	_create_console(Vector3(platform_radius - 0.6, 0, -0.5), -45, "Right", 0.7)

	DebugLogger.debug(ENV_SOURCE, "Created 3 consoles")


func _create_console(pos: Vector3, rotation_y: float, console_name: String, scale_factor: float = 1.0) -> void:
	var scaled_width := console_width * scale_factor
	var scaled_height := console_height * scale_factor
	var scaled_depth := console_depth * scale_factor

	# Console body
	var body := ProceduralMeshes.create_box(
		Vector3(scaled_width, scaled_height, scaled_depth),
		console_color,
		Vector3(pos.x, scaled_height/2, pos.z)
	)
	body.name = "Console" + console_name
	body.rotation_degrees.y = rotation_y
	body.material_override = ProceduralMeshes.create_simple_pbr_material(console_color, 0.7, 0.3)
	_add_geometry(body)

	# Console screen (angled top surface)
	var screen := ProceduralMeshes.create_box(
		Vector3(scaled_width * 0.8, 0.02, scaled_depth * 0.6),
		console_screen_color,
		Vector3(pos.x, scaled_height + 0.01, pos.z)
	)
	screen.name = "ConsoleScreen" + console_name
	screen.rotation_degrees.y = rotation_y
	screen.material_override = ProceduralMeshes.create_emissive_material(
		console_screen_color,
		Color(-1,-1,-1),
		1.2
	)
	_add_geometry(screen)

	# Status light
	var light_pos := Vector3(pos.x, scaled_height + 0.05, pos.z)
	var status_light := OmniLight3D.new()
	status_light.name = "ConsoleLight" + console_name
	status_light.position = light_pos
	status_light.light_color = console_screen_color
	status_light.light_energy = 0.3
	status_light.omni_range = 1.5
	status_light.omni_attenuation = 1.5
	_add_geometry(status_light)


func _build_hyperspace_streaks() -> void:
	streaks.clear()
	streak_velocities.clear()
	streak_data.clear()

	for i in range(num_streaks):
		var data := _generate_streak_data()
		streak_data.append(data)

		var streak := _create_streak(data)
		streak.name = "Streak%d" % i
		streaks.append(streak)
		_add_dynamic(streak)

		# Random velocity variation
		streak_velocities.append(streak_speed * randf_range(0.7, 1.3))

	DebugLogger.info(ENV_SOURCE, "Created %d hyperspace streaks" % num_streaks)


func _generate_streak_data() -> Dictionary:
	# Generate random position in a cylinder around the player
	var angle := randf() * TAU
	var distance := randf_range(streak_min_distance, streak_max_distance)
	var height := randf_range(-10.0, 15.0)
	var length := randf_range(streak_min_length, streak_max_length)

	# Streaks oriented along -Z (forward direction)
	var z_pos := randf_range(-30.0, 50.0)

	return {
		"angle": angle,
		"distance": distance,
		"height": height,
		"length": length,
		"z_offset": z_pos,
		"brightness": randf_range(0.5, 1.0),
	}


func _create_streak(data: Dictionary) -> MeshInstance3D:
	var angle: float = data.angle
	var distance: float = data.distance
	var x := cos(angle) * distance
	var y: float = data.height
	var z: float = data.z_offset
	var length: float = data.length
	var brightness: float = data.brightness

	# Create elongated box for streak
	var streak := ProceduralMeshes.create_box(
		Vector3(0.03, 0.03, length),
		streak_color,
		Vector3(x, y, z)
	)

	# Apply emissive material based on brightness
	var emission_energy := 2.0 * brightness
	var mat := ProceduralMeshes.create_unlit_material(streak_color, emission_energy)
	streak.material_override = mat

	return streak


func _update_streaks(delta: float) -> void:
	var wrap_distance := streak_max_distance + 50.0
	var spawn_distance := -30.0

	for i in range(streaks.size()):
		var streak := streaks[i]
		var velocity: float = streak_velocities[i]

		# Move streak backwards (towards player)
		streak.position.z -= velocity * delta

		# Wrap around when past player
		if streak.position.z < spawn_distance:
			# Reset to far distance with new random position
			var data := streak_data[i]
			streak.position.z = wrap_distance + randf() * 20.0

			# Randomize angle and distance slightly for variety
			var new_angle := data.angle + randf_range(-0.3, 0.3)
			var new_distance: float = data.distance + randf_range(-5.0, 5.0)
			new_distance = clampf(new_distance, streak_min_distance, streak_max_distance)

			streak.position.x = cos(new_angle) * new_distance
			streak.position.y = data.height + randf_range(-2.0, 2.0)

			# Update stored data
			streak_data[i].angle = new_angle
			streak_data[i].distance = new_distance


# =============================================================================
# PUBLIC API
# =============================================================================

## Set streak animation speed (for intensity control)
func set_streak_speed(speed: float) -> void:
	streak_speed = maxf(speed, 0.0)
	DebugLogger.debug(ENV_SOURCE, "Streak speed set to %.1f" % streak_speed)


## Toggle streak animation
func set_animation_enabled(enabled: bool) -> void:
	animate_streaks = enabled
	DebugLogger.debug(ENV_SOURCE, "Streak animation %s" % ("enabled" if enabled else "disabled"))


## Get current streak count
func get_streak_count() -> int:
	return streaks.size()
