## EnvironmentLoader - Factory and manager for procedural training environments
## Handles creation, switching, and cleanup of environments
##
## Usage:
##   var loader = EnvironmentLoader.new()
##   parent.add_child(loader)
##   loader.load_environment(XRHelpers.EnvironmentType.OCEAN)
##
##   # Later, to switch:
##   loader.load_environment(XRHelpers.EnvironmentType.HYPERSPACE)
extends Node
class_name EnvironmentLoader

const SOURCE := "EnvLoader"

# =============================================================================
# SIGNALS
# =============================================================================

signal environment_loaded(env_type: XRHelpers.EnvironmentType)
signal environment_unloaded(env_type: XRHelpers.EnvironmentType)
signal environment_load_failed(env_type: XRHelpers.EnvironmentType, reason: String)

# =============================================================================
# STATE
# =============================================================================

## Currently active environment instance
var current_environment: BaseEnvironment = null

## Currently active environment type
var current_type: XRHelpers.EnvironmentType = XRHelpers.EnvironmentType.DOJO

## Whether an environment is currently loaded
var is_loaded := false

# =============================================================================
# PUBLIC API
# =============================================================================

## Load an environment by type
## Cleans up any existing environment first
## Returns true if successful
func load_environment(env_type: XRHelpers.EnvironmentType) -> bool:
	var env_name := XRHelpers.get_environment_name(env_type)
	DebugLogger.info(SOURCE, "Loading environment: %s" % env_name)

	# Clean up existing environment
	if current_environment != null:
		_unload_current()

	# Create new environment
	var env := _create_environment(env_type)
	if env == null:
		var error_msg := "Failed to create environment: %s" % env_name
		DebugLogger.error(SOURCE, error_msg)
		environment_load_failed.emit(env_type, error_msg)

		# Fall back to empty dojo if not already trying dojo
		if env_type != XRHelpers.EnvironmentType.DOJO:
			DebugLogger.warn(SOURCE, "Falling back to dojo environment")
			return load_environment(XRHelpers.EnvironmentType.DOJO)
		return false

	# Add to scene tree
	current_environment = env
	current_type = env_type
	add_child(current_environment)

	# Environment builds itself in _ready()
	is_loaded = true

	DebugLogger.info(SOURCE, "Environment loaded: %s" % env_name)
	environment_loaded.emit(env_type)
	return true


## Unload the current environment
func unload_environment() -> void:
	if current_environment != null:
		_unload_current()


## Get the currently active environment
func get_current_environment() -> BaseEnvironment:
	return current_environment


## Get the currently active environment type
func get_current_type() -> XRHelpers.EnvironmentType:
	return current_type


## Check if an environment is loaded
func has_environment() -> bool:
	return is_loaded and current_environment != null


## Reload the current environment (useful for debugging)
func reload_current() -> bool:
	var type_to_reload := current_type
	unload_environment()
	return load_environment(type_to_reload)


# =============================================================================
# FACTORY
# =============================================================================

## Create an environment instance by type
func _create_environment(env_type: XRHelpers.EnvironmentType) -> BaseEnvironment:
	var env: BaseEnvironment = null

	match env_type:
		XRHelpers.EnvironmentType.OCEAN:
			env = OceanPlatformEnvironment.new()
		XRHelpers.EnvironmentType.HYPERSPACE:
			env = HyperspaceEnvironment.new()
		XRHelpers.EnvironmentType.DOJO:
			env = KungFuDojoEnvironment.new()
		_:
			DebugLogger.warn(SOURCE, "Unknown environment type %d, using dojo" % env_type)
			env = KungFuDojoEnvironment.new()

	if env != null:
		env.name = "TrainingEnvironment"

	return env


## Clean up current environment
func _unload_current() -> void:
	if current_environment == null:
		return

	var old_type := current_type
	var old_name := XRHelpers.get_environment_name(old_type)

	DebugLogger.info(SOURCE, "Unloading environment: %s" % old_name)

	# Call cleanup on environment
	if current_environment.is_built:
		current_environment.cleanup()

	# Remove from tree
	current_environment.queue_free()
	current_environment = null
	is_loaded = false

	environment_unloaded.emit(old_type)
	DebugLogger.debug(SOURCE, "Environment unloaded: %s" % old_name)


# =============================================================================
# STATIC HELPERS
# =============================================================================

## Load environment from command-line flag
## Call this to automatically select based on --env=<type>
static func get_startup_environment_type() -> XRHelpers.EnvironmentType:
	var env_type := XRHelpers.get_environment_flag()
	var env_name := XRHelpers.get_environment_name(env_type)
	DebugLogger.info("EnvLoader", "Selected environment from CLI: %s" % env_name)
	return env_type


## Create a loader and immediately load the CLI-specified environment
## Convenience method for simple setup
static func create_and_load(parent: Node) -> EnvironmentLoader:
	var loader := EnvironmentLoader.new()
	loader.name = "EnvironmentLoader"
	parent.add_child(loader)

	var env_type := get_startup_environment_type()
	loader.load_environment(env_type)

	return loader
