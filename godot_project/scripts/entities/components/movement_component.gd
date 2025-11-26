## MovementComponent - Handles entity movement and positioning
##
## Responsibilities:
## - Process movement based on configuration
## - Update entity position/rotation
## - Handle different movement patterns (hover, orbit, follow, etc.)
## - Enforce movement constraints (bounds, plane-lock)
##
## Configuration: MovementComponentConfig Resource
##
## Usage:
## ```gdscript
## var movement = entity.get_component(MovementComponent)
## movement.set_orbit_center(player.global_position, 3.0)
## movement.move_to(target_position)
## ```
class_name MovementComponent
extends EntityComponent

# =============================================================================
# SIGNALS
# =============================================================================

signal movement_started()
signal movement_stopped()
signal target_reached(target: Vector3)
signal waypoint_reached(index: int)

# =============================================================================
# PROPERTIES
# =============================================================================

var movement_type: MovementComponentConfig.MovementType
var speed: float = 2.0
var rotation_speed: float = 5.0
var is_moving: bool = false

# Private state
var _config: MovementComponentConfig
var _spawn_position: Vector3
var _target_position: Vector3

# Hover state
var _hover_phase: float = 0.0

# Orbit state
var _orbit_center: Vector3
var _orbit_angle: float = 0.0
var _orbit_radius: float = 2.0
var _orbit_speed: float = 1.0

# Follow state
var _follow_target: Node3D
var _follow_distance: float = 3.0

# =============================================================================
# INITIALIZATION
# =============================================================================

func _on_initialized() -> void:
	component_id = "Movement"

	# Load from config
	if config is MovementComponentConfig:
		_config = config
		movement_type = _config.movement_type
		speed = _config.speed
		rotation_speed = _config.rotation_speed
		_orbit_radius = _config.orbit_radius
		_orbit_speed = _config.orbit_speed if _config.orbit_clockwise else -_config.orbit_speed
		_follow_distance = _config.follow_distance

		log_debug("Initialized: type=%s, speed=%.1f" % [
			MovementComponentConfig.MovementType.keys()[movement_type],
			speed
		])
	else:
		log_warn("No MovementComponentConfig provided, using defaults")
		movement_type = MovementComponentConfig.MovementType.STATIC


func on_entity_spawned() -> void:
	super.on_entity_spawned()

	_spawn_position = entity.global_position
	_orbit_center = entity.global_position

	# Initialize random phase for hover
	_hover_phase = randf() * TAU

	# Start movement if not static
	if movement_type != MovementComponentConfig.MovementType.STATIC:
		is_moving = true
		movement_started.emit()

# =============================================================================
# UPDATE
# =============================================================================

func process_component(delta: float) -> void:
	if not is_moving:
		return

	match movement_type:
		MovementComponentConfig.MovementType.STATIC:
			pass  # No movement

		MovementComponentConfig.MovementType.HOVER:
			_process_hover(delta)

		MovementComponentConfig.MovementType.ORBIT:
			_process_orbit(delta)

		MovementComponentConfig.MovementType.FOLLOW:
			_process_follow(delta)

		MovementComponentConfig.MovementType.PATROL:
			_process_patrol(delta)

		MovementComponentConfig.MovementType.WANDER:
			_process_wander(delta)

		MovementComponentConfig.MovementType.CUSTOM:
			pass  # Handled by behavior component

	# Apply constraints
	if _config:
		_apply_constraints()

# =============================================================================
# MOVEMENT MODES
# =============================================================================

func _process_hover(delta: float) -> void:
	if not _config:
		return

	# Vertical bobbing
	_hover_phase += delta * _config.hover_frequency * TAU
	var bob_offset := sin(_hover_phase) * _config.hover_amplitude

	entity.global_position = _spawn_position + Vector3(0, bob_offset, 0)


func _process_orbit(delta: float) -> void:
	if not _config:
		return

	# Update orbit angle
	_orbit_angle += _orbit_speed * delta

	# Calculate position on orbit
	var offset := Vector3(
		cos(_orbit_angle) * _orbit_radius,
		_config.orbit_height,
		sin(_orbit_angle) * _orbit_radius
	)

	entity.global_position = _orbit_center + offset

	# Optionally look at center
	if _config.follow_look_at_target:
		entity.look_at(_orbit_center, Vector3.UP)


func _process_follow(delta: float) -> void:
	if not _follow_target or not _config:
		return

	var to_target := _follow_target.global_position - entity.global_position
	var distance := to_target.length()

	# Stop if within follow distance
	if distance <= _config.follow_stop_distance:
		return

	# Move toward target
	var direction := to_target.normalized()
	var move_distance := speed * delta

	# Smooth approach as we get closer
	if distance < _follow_distance:
		move_distance *= (distance / _follow_distance)

	entity.global_position += direction * move_distance

	# Look at target
	if _config.follow_look_at_target:
		entity.look_at(_follow_target.global_position, Vector3.UP)


func _process_patrol(delta: float) -> void:
	# TODO: Implement waypoint patrol
	log_warn("PATROL movement not yet implemented")


func _process_wander(delta: float) -> void:
	# TODO: Implement random wandering
	log_warn("WANDER movement not yet implemented")

# =============================================================================
# MOVEMENT CONTROL
# =============================================================================

## Move to a specific position
func move_to(target: Vector3, speed_override: float = -1.0) -> void:
	_target_position = target
	is_moving = true
	movement_started.emit()

	if speed_override > 0:
		speed = speed_override

	log_debug("Moving to: %v" % target)


## Stop movement
func stop() -> void:
	if not is_moving:
		return

	is_moving = false
	movement_stopped.emit()
	log_debug("Movement stopped")


## Set orbit parameters
func set_orbit(center: Vector3, radius: float, orbit_speed_val: float) -> void:
	_orbit_center = center
	_orbit_radius = radius
	_orbit_speed = orbit_speed_val
	movement_type = MovementComponentConfig.MovementType.ORBIT

	log_debug("Orbit set: center=%v, radius=%.1f, speed=%.1f" % [center, radius, orbit_speed_val])


## Set orbit center without changing other params
func set_orbit_center(center: Vector3) -> void:
	_orbit_center = center


## Set follow target
func set_follow_target(target: Node3D, distance: float = -1.0) -> void:
	_follow_target = target
	if distance > 0:
		_follow_distance = distance

	movement_type = MovementComponentConfig.MovementType.FOLLOW
	is_moving = true

	log_debug("Following: %s at distance %.1f" % [target.name, _follow_distance])


## Clear follow target
func clear_follow_target() -> void:
	_follow_target = null
	movement_type = MovementComponentConfig.MovementType.STATIC
	stop()


## Teleport to position (instant, no movement)
func teleport_to(position: Vector3) -> void:
	entity.global_position = position
	_spawn_position = position
	log_debug("Teleported to: %v" % position)

# =============================================================================
# CONSTRAINTS
# =============================================================================

func _apply_constraints() -> void:
	if not _config:
		return

	var pos := entity.global_position

	# Constrain to horizontal plane
	if _config.constrain_to_plane:
		pos.y = _spawn_position.y

	# Apply bounds
	if _config.bounds_wrap:
		# Wrap around bounds
		if pos.x < _config.bounds_min.x:
			pos.x = _config.bounds_max.x
		elif pos.x > _config.bounds_max.x:
			pos.x = _config.bounds_min.x

		if pos.y < _config.bounds_min.y:
			pos.y = _config.bounds_max.y
		elif pos.y > _config.bounds_max.y:
			pos.y = _config.bounds_min.y

		if pos.z < _config.bounds_min.z:
			pos.z = _config.bounds_max.z
		elif pos.z > _config.bounds_max.z:
			pos.z = _config.bounds_min.z
	else:
		# Clamp to bounds
		pos.x = clampf(pos.x, _config.bounds_min.x, _config.bounds_max.x)
		pos.y = clampf(pos.y, _config.bounds_min.y, _config.bounds_max.y)
		pos.z = clampf(pos.z, _config.bounds_min.z, _config.bounds_max.z)

	entity.global_position = pos

# =============================================================================
# HELPER METHODS
# =============================================================================

## Get current velocity (approximate)
func get_velocity() -> Vector3:
	# This is approximate - for CharacterBody3D entities, use velocity property
	return Vector3.ZERO  # TODO: Track velocity


## Get distance to target
func get_distance_to_target() -> float:
	return entity.global_position.distance_to(_target_position)


## Check if at target position
func is_at_target(threshold: float = 0.5) -> bool:
	return get_distance_to_target() <= threshold


## Get spawn position
func get_spawn_position() -> Vector3:
	return _spawn_position

# =============================================================================
# VALIDATION
# =============================================================================

func validate() -> Array[String]:
	var errors := super.validate()

	if speed < 0:
		errors.append("speed cannot be negative")

	return errors
