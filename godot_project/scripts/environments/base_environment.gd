## BaseEnvironment - Abstract base class for procedural training environments
## Provides common interface and utilities for all environment types
##
## Subclasses must override:
##   - _build_environment() - Create the environment geometry
##   - get_environment_name() - Return a human-readable name
##
## Usage:
##   var env = OceanPlatformEnvironment.new()
##   add_child(env)  # Calls _ready() which builds the environment
extends Node3D
class_name BaseEnvironment

const SOURCE := "Environment"

# =============================================================================
# CONFIGURATION
# =============================================================================

## Player spawn position (environments should place floor around this)
@export var player_spawn := Vector3.ZERO

## Default training area size (meters)
@export var training_area_radius := 3.0

## Whether to include decorative elements
@export var include_decorations := true

# =============================================================================
# STATE
# =============================================================================

## Set to true after build() completes
var is_built := false

## Container for environment geometry
var geometry_root: Node3D

## Container for dynamic/animated elements
var dynamic_root: Node3D

## World environment node (if created)
var world_environment: WorldEnvironment

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_setup_containers()
	build()


func _setup_containers() -> void:
	geometry_root = Node3D.new()
	geometry_root.name = "Geometry"
	add_child(geometry_root)

	dynamic_root = Node3D.new()
	dynamic_root.name = "Dynamic"
	add_child(dynamic_root)


# =============================================================================
# PUBLIC API
# =============================================================================

## Build the environment (call once)
func build() -> void:
	if is_built:
		DebugLogger.warn(SOURCE, "Environment already built, skipping")
		return

	var start_time := Time.get_ticks_msec()

	DebugLogger.info(SOURCE, "Building %s environment..." % get_environment_name())

	# Call subclass implementation
	_build_environment()

	is_built = true

	var elapsed := Time.get_ticks_msec() - start_time
	DebugLogger.info(SOURCE, "Built %s environment in %d ms" % [get_environment_name(), elapsed])


## Clean up environment (for hot-swapping)
func cleanup() -> void:
	DebugLogger.info(SOURCE, "Cleaning up %s environment" % get_environment_name())

	# Remove all geometry
	for child in geometry_root.get_children():
		child.queue_free()

	for child in dynamic_root.get_children():
		child.queue_free()

	if world_environment:
		world_environment.queue_free()
		world_environment = null

	is_built = false


## Get the player spawn position for this environment
func get_player_spawn_position() -> Vector3:
	return player_spawn


## Get the approximate bounds of the training area
func get_training_bounds() -> AABB:
	return AABB(
		player_spawn - Vector3(training_area_radius, 0, training_area_radius),
		Vector3(training_area_radius * 2, 3.0, training_area_radius * 2)
	)


## Get environment name (override in subclass)
func get_environment_name() -> String:
	return "Base"


# =============================================================================
# SUBCLASS INTERFACE (Override these)
# =============================================================================

## Build environment geometry - override in subclass
func _build_environment() -> void:
	push_warning("BaseEnvironment._build_environment() not overridden")


# =============================================================================
# COMMON UTILITIES
# =============================================================================

## Create and configure a WorldEnvironment with common settings
func _create_world_environment(
	background_color: Color,
	ambient_color: Color,
	ambient_energy: float = 0.5,
	fog_enabled: bool = false,
	fog_color: Color = Color.WHITE,
	fog_density: float = 0.01
) -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy

	if fog_enabled:
		env.fog_enabled = true
		env.fog_light_color = fog_color
		env.fog_density = fog_density

	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = env
	add_child(world_environment)

	return world_environment


## Create a directional light (sun/moon)
func _create_directional_light(
	direction: Vector3,
	color: Color = Color.WHITE,
	energy: float = 1.0,
	shadows: bool = true
) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.name = "DirectionalLight"
	light.light_color = color
	light.light_energy = energy
	light.shadow_enabled = shadows
	light.rotation = direction.normalized().signed_angle_to(Vector3.DOWN, Vector3.RIGHT) * Vector3.ONE
	# Point light in the given direction
	light.look_at_from_position(Vector3.ZERO, -direction, Vector3.UP)
	geometry_root.add_child(light)
	return light


## Create a point/omni light
func _create_omni_light(
	position: Vector3,
	color: Color = Color.WHITE,
	energy: float = 1.0,
	range_val: float = 5.0
) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = "OmniLight"
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_val
	light.omni_attenuation = 1.5
	geometry_root.add_child(light)
	return light


## Add a mesh to the geometry container
func _add_geometry(mesh: MeshInstance3D) -> void:
	geometry_root.add_child(mesh)


## Add a mesh to the dynamic container (for animated elements)
func _add_dynamic(node: Node3D) -> void:
	dynamic_root.add_child(node)
