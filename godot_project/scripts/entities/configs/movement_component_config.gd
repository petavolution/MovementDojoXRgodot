## MovementComponentConfig - Configuration for MovementComponent
##
## Data-driven movement system configuration
## Save as .tres and assign to EntityDefinition.movement_config
class_name MovementComponentConfig
extends Resource

# =============================================================================
# MOVEMENT TYPE
# =============================================================================

enum MovementType {
	STATIC,          ## No movement (stationary)
	HOVER,           ## Hover in place with bob
	ORBIT,           ## Circle around a point
	FOLLOW,          ## Follow a target
	PATROL,          ## Waypoint patrol
	WANDER,          ## Random wandering
	CUSTOM           ## Behavior-driven movement
}

@export var movement_type: MovementType = MovementType.STATIC

# =============================================================================
# BASIC MOVEMENT
# =============================================================================

## Movement speed (units per second)
@export var speed: float = 2.0

## Rotation speed (radians per second)
@export var rotation_speed: float = 5.0

## Acceleration rate
@export var acceleration: float = 5.0

## Deceleration rate
@export var deceleration: float = 5.0

## Maximum speed cap
@export var max_speed: float = 10.0

# =============================================================================
# HOVER SETTINGS
# =============================================================================

@export_group("Hover")

## Hover bob amplitude (vertical movement)
@export var hover_amplitude: float = 0.1

## Hover bob frequency (cycles per second)
@export var hover_frequency: float = 1.0

## Random hover drift
@export var hover_drift: float = 0.0

# =============================================================================
# ORBIT SETTINGS
# =============================================================================

@export_group("Orbit")

## Orbit radius (distance from center)
@export var orbit_radius: float = 2.0

## Orbit speed (radians per second)
@export var orbit_speed: float = 1.0

## Orbit clockwise (false = counter-clockwise)
@export var orbit_clockwise: bool = true

## Orbit height offset
@export var orbit_height: float = 0.0

# =============================================================================
# FOLLOW SETTINGS
# =============================================================================

@export_group("Follow")

## Follow distance (maintain this distance from target)
@export var follow_distance: float = 3.0

## Stop distance (stop when this close to target)
@export var follow_stop_distance: float = 1.0

## Follow smoothing (1.0 = instant, 0.1 = smooth)
@export var follow_smoothing: float = 0.5

## Look at target while following
@export var follow_look_at_target: bool = true

# =============================================================================
# PATROL SETTINGS
# =============================================================================

@export_group("Patrol")

## Patrol waypoints (positions to visit)
@export var patrol_waypoints: Array[Vector3] = []

## Loop patrol (return to first waypoint)
@export var patrol_loop: bool = true

## Reverse direction at end (ping-pong)
@export var patrol_reverse: bool = false

## Wait time at each waypoint (seconds)
@export var patrol_wait_time: float = 1.0

## Waypoint reach threshold
@export var patrol_reach_distance: float = 0.5

# =============================================================================
# WANDER SETTINGS
# =============================================================================

@export_group("Wander")

## Wander radius (area to wander in)
@export var wander_radius: float = 5.0

## Change direction interval (seconds)
@export var wander_change_interval: float = 3.0

## Wander speed multiplier
@export var wander_speed_mult: float = 0.5

# =============================================================================
# CONSTRAINTS
# =============================================================================

@export_group("Constraints")

## Constrain to horizontal plane (no Y movement)
@export var constrain_to_plane: bool = false

## Movement bounds (min position)
@export var bounds_min: Vector3 = Vector3(-999, -999, -999)

## Movement bounds (max position)
@export var bounds_max: Vector3 = Vector3(999, 999, 999)

## Wrap around bounds (teleport to opposite side)
@export var bounds_wrap: bool = false

# =============================================================================
# AVOIDANCE
# =============================================================================

@export_group("Avoidance")

## Enable obstacle avoidance
@export var avoid_obstacles: bool = false

## Avoidance radius
@export var avoidance_radius: float = 1.0

## Avoidance layers (collision mask)
@export_flags_3d_physics var avoidance_layers: int = 0

# =============================================================================
# VALIDATION
# =============================================================================

func validate() -> Array[String]:
	var errors: Array[String] = []

	if speed < 0:
		errors.append("speed cannot be negative")

	if rotation_speed < 0:
		errors.append("rotation_speed cannot be negative")

	if orbit_radius < 0:
		errors.append("orbit_radius cannot be negative")

	if follow_distance < 0:
		errors.append("follow_distance cannot be negative")

	if movement_type == MovementType.PATROL and patrol_waypoints.is_empty():
		errors.append("PATROL movement requires waypoints")

	return errors
