## WaveSpawnEntry - Defines a single enemy spawn configuration within a wave
## Used by TrainingWave to specify what enemies to spawn and how they behave
##
## Design: Data-driven resource that can be saved/loaded from .tres files
## Maps generic enemy types to concrete implementations at runtime
class_name WaveSpawnEntry
extends Resource

# =============================================================================
# ENEMY TYPES (Generic, mechanics-focused names)
# =============================================================================

enum EnemyType {
	FLYING_DRONE,      # Hovering enemy that can shoot projectiles
	MELEE_BOT,         # Close-range attacker that charges/swings
	RANGED_TROOP,      # Ground-based shooter at distance
	DIVE_ATTACKER,     # Flying enemy that telegraphs then rams player
	TARGET_DUMMY,      # Non-threatening practice target
	SHIELDED_DRONE,    # Drone with frontal shield (requires flanking)
	BOMBER_DRONE,      # Drops area attacks from above
}

enum SpawnBehavior {
	STATIONARY,        # Stays in spawn position
	PATROL,            # Moves between waypoints
	ORBIT,             # Circles around a point (usually player)
	AGGRESSIVE,        # Actively pursues player
	DEFENSIVE,         # Maintains distance, retreats if approached
	RANDOM_DRIFT,      # Gentle random movement
}

enum SpawnFormation {
	SINGLE,            # One at a time at calculated positions
	ARC,               # Spread in an arc facing player
	LINE,              # Horizontal line
	CLUSTER,           # Tight group
	SURROUND,          # Circle around player
}

# =============================================================================
# IDENTITY
# =============================================================================

## Unique identifier for this spawn entry (for logging/debugging)
@export var entry_id: String = ""

## Human-readable description
@export var description: String = ""

# =============================================================================
# SPAWN CONFIGURATION
# =============================================================================

@export_group("Enemy Type")
## Type of enemy to spawn
@export var enemy_type: EnemyType = EnemyType.FLYING_DRONE

## Number of this enemy type to spawn
@export var count: int = 1

## Behavior pattern for spawned enemies
@export var behavior: SpawnBehavior = SpawnBehavior.STATIONARY

## Formation for multiple enemies
@export var formation: SpawnFormation = SpawnFormation.ARC

@export_group("Combat Stats")
## Whether this enemy can shoot projectiles
@export var can_shoot: bool = false

## Time between shots (seconds)
@export var fire_interval: float = 3.0

## Projectile travel speed (m/s)
@export var projectile_speed: float = 3.0

## Damage per hit
@export var projectile_damage: float = 10.0

## Health multiplier (1.0 = default health for enemy type)
@export var health_multiplier: float = 1.0

@export_group("Movement Stats")
## Movement speed multiplier (1.0 = default for enemy type)
@export var movement_speed: float = 1.0

## Orbit radius for ORBIT behavior
@export var orbit_radius: float = 1.5

## Orbit speed for ORBIT behavior (rad/s)
@export var orbit_speed: float = 0.5

## Patrol waypoints (relative to spawn position)
@export var patrol_points: Array[Vector3] = []

@export_group("Spawn Position")
## Distance from player for spawn
@export var spawn_distance: float = 3.0

## Height offset from player eye level
@export var spawn_height_offset: float = 0.0

## Arc spread for formation (degrees, centered on forward)
@export var spawn_arc_degrees: float = 90.0

## Random position jitter (meters)
@export var position_jitter: float = 0.2

@export_group("Visual")
## Override color (ignored if use_default_color is true)
@export var color_override: Color = Color.WHITE

## Use the default color for enemy type
@export var use_default_color: bool = true

## Scale multiplier
@export var scale_multiplier: float = 1.0

@export_group("Timing")
## Delay before this entry spawns (relative to wave start)
@export var spawn_delay: float = 0.0

## Stagger time between individual spawns in this entry
@export var spawn_stagger: float = 0.3

# =============================================================================
# HELPER METHODS
# =============================================================================

## Get display name for enemy type
static func get_enemy_type_name(type: EnemyType) -> String:
	match type:
		EnemyType.FLYING_DRONE: return "Flying Drone"
		EnemyType.MELEE_BOT: return "Melee Bot"
		EnemyType.RANGED_TROOP: return "Ranged Troop"
		EnemyType.DIVE_ATTACKER: return "Dive Attacker"
		EnemyType.TARGET_DUMMY: return "Target Dummy"
		EnemyType.SHIELDED_DRONE: return "Shielded Drone"
		EnemyType.BOMBER_DRONE: return "Bomber Drone"
		_: return "Unknown"


## Get default color for enemy type
static func get_default_color(type: EnemyType) -> Color:
	match type:
		EnemyType.FLYING_DRONE: return Color(0.8, 0.3, 0.1)      # Orange-red
		EnemyType.MELEE_BOT: return Color(0.6, 0.1, 0.1)         # Dark red
		EnemyType.RANGED_TROOP: return Color(0.2, 0.4, 0.8)      # Blue
		EnemyType.DIVE_ATTACKER: return Color(0.9, 0.8, 0.1)     # Yellow
		EnemyType.TARGET_DUMMY: return Color(0.2, 0.6, 0.9)      # Light blue
		EnemyType.SHIELDED_DRONE: return Color(0.5, 0.5, 0.7)    # Steel blue
		EnemyType.BOMBER_DRONE: return Color(0.6, 0.2, 0.6)      # Purple
		_: return Color.WHITE


## Get the actual color to use (respects use_default_color)
func get_spawn_color() -> Color:
	if use_default_color:
		return get_default_color(enemy_type)
	return color_override


## Create a summary string for logging
func get_summary() -> String:
	var type_name := get_enemy_type_name(enemy_type)
	var behavior_str := SpawnBehavior.keys()[behavior].to_lower()
	var shoot_str := "shooting" if can_shoot else "non-shooting"
	return "%dx %s (%s, %s)" % [count, type_name, behavior_str, shoot_str]


## Validate this entry (returns array of error messages, empty if valid)
func validate() -> Array[String]:
	var errors: Array[String] = []

	if count <= 0:
		errors.append("count must be > 0")
	if count > 20:
		errors.append("count > 20 may cause performance issues")
	if spawn_distance <= 0:
		errors.append("spawn_distance must be > 0")
	if can_shoot and fire_interval <= 0:
		errors.append("fire_interval must be > 0 when can_shoot is true")
	if behavior == SpawnBehavior.PATROL and patrol_points.is_empty():
		errors.append("PATROL behavior requires patrol_points")

	return errors
