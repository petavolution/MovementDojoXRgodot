## Level1DroneSpawner - Manages drone spawning for Level 1 training phases
## Spawns safe, slow drones appropriate for each drill phase
## Ensures clean lifecycle: spawn on phase enter, despawn on phase exit
extends Node
class_name Level1DroneSpawner

const SOURCE := "L1Spawner"

# =============================================================================
# SIGNALS
# =============================================================================

signal drone_spawned(drone: SimpleDrone)
signal drone_destroyed(drone: SimpleDrone, by_player: bool)
signal projectile_fired(drone: SimpleDrone, projectile: Projectile)
signal projectile_blocked(projectile: Projectile)
signal projectile_hit_player(projectile: Projectile)
signal dive_started(drone: SimpleDrone)
signal dive_completed(drone: SimpleDrone, hit_player: bool)
signal all_drones_destroyed()

# =============================================================================
# CONFIGURATION - Safe defaults for training
# =============================================================================

@export_group("Limits")
## Maximum drones active at once (safety limit)
@export var max_active_drones := 5
## Maximum projectiles active at once (safety limit)
@export var max_active_projectiles := 15

@export_group("Saber Drill Config")
## Number of drones that shoot projectiles
@export var saber_drone_count := 2
## Fire interval for saber drill (slower = easier)
@export var saber_fire_interval := 3.5
## Projectile speed for saber drill (slower = easier to block)
@export var saber_projectile_speed := 3.0

@export_group("Blaster Drill Config")
## Number of target drones for blaster practice
@export var blaster_drone_count := 3
## Whether blaster targets move
@export var blaster_drones_move := true

@export_group("Mixed Drill Config")
## Number of shooting drones
@export var mixed_shooter_count := 2
## Whether to include a dive drone
@export var mixed_include_dive := true
## Fire interval for mixed drill (slightly faster)
@export var mixed_fire_interval := 2.5

@export_group("Spawn Positions")
## Distance from player for drone spawns
@export var spawn_distance := 3.0
## Height offset for drone spawns
@export var spawn_height := 1.6
## Arc spread for multiple drones (degrees)
@export var spawn_arc := 90.0

# =============================================================================
# STATE
# =============================================================================

var active_drones: Array[SimpleDrone] = []
var active_projectiles: Array[Projectile] = []
var _next_drone_id := 0
var _projectile_id := 0

# References
var target: Node3D  # Player camera
var spawn_parent: Node3D  # Where to add drones

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	DebugLogger.debug(SOURCE, "Level1DroneSpawner initialized")


func _process(_delta: float) -> void:
	# Clean up destroyed projectiles from tracking
	_cleanup_projectile_list()


func _exit_tree() -> void:
	despawn_all()


# =============================================================================
# SETUP
# =============================================================================

func setup(player_target: Node3D, parent: Node3D) -> void:
	target = player_target
	spawn_parent = parent
	DebugLogger.debug(SOURCE, "Spawner configured: target=%s, parent=%s" % [
		target.name if target else "null",
		parent.name if parent else "null"
	])


# =============================================================================
# PHASE-SPECIFIC SPAWNING
# =============================================================================

## Spawn drones for SABER_DRILL phase
## - Stationary drones that fire slow projectiles for blocking practice
func spawn_saber_drill_drones() -> void:
	DebugLogger.info(SOURCE, "=== SABER DRILL: Spawning %d shooter drones ===" % saber_drone_count)

	var positions := _calculate_spawn_positions(saber_drone_count)

	for i in range(saber_drone_count):
		var drone := SimpleDrone.create_drone(
			_next_drone_id,
			positions[i],
			SimpleDrone.Behavior.HOVER,
			Color(0.8, 0.3, 0.1)  # Orange-red
		)
		_next_drone_id += 1

		# Configure for slow shooting
		drone.can_shoot = true
		drone.shoot_at_player = true
		drone.fire_interval = saber_fire_interval
		drone.projectile_speed = saber_projectile_speed
		drone.projectile_damage = 10.0

		_spawn_drone(drone)


## Spawn drones for BLASTER_DRILL phase
## - Target drones for shooting practice (don't shoot back)
func spawn_blaster_drill_drones() -> void:
	DebugLogger.info(SOURCE, "=== BLASTER DRILL: Spawning %d target drones ===" % blaster_drone_count)

	var positions := _calculate_spawn_positions(blaster_drone_count)

	for i in range(blaster_drone_count):
		var behavior := SimpleDrone.Behavior.SLOW_ORBIT if blaster_drones_move else SimpleDrone.Behavior.HOVER
		var drone := SimpleDrone.create_drone(
			_next_drone_id,
			positions[i],
			behavior,
			Color(0.2, 0.6, 0.9)  # Blue (friendly target color)
		)
		_next_drone_id += 1

		# Configure as target only (no shooting)
		drone.can_shoot = false
		drone.orbit_radius = 0.8
		drone.orbit_speed = 0.3
		drone.max_health = 30.0  # Easier to destroy

		_spawn_drone(drone)


## Spawn drones for MIXED_DRILL phase
## - Combination of shooters and one dive attacker
func spawn_mixed_drill_drones() -> void:
	var total := mixed_shooter_count + (1 if mixed_include_dive else 0)
	DebugLogger.info(SOURCE, "=== MIXED DRILL: Spawning %d drones (%d shooters + %d dive) ===" % [
		total, mixed_shooter_count, 1 if mixed_include_dive else 0
	])

	var positions := _calculate_spawn_positions(total)
	var pos_idx := 0

	# Spawn shooter drones
	for i in range(mixed_shooter_count):
		var drone := SimpleDrone.create_drone(
			_next_drone_id,
			positions[pos_idx],
			SimpleDrone.Behavior.SLOW_ORBIT,
			Color(0.8, 0.2, 0.2)  # Red
		)
		_next_drone_id += 1
		pos_idx += 1

		drone.can_shoot = true
		drone.shoot_at_player = true
		drone.fire_interval = mixed_fire_interval
		drone.projectile_speed = 4.0
		drone.orbit_radius = 1.0
		drone.orbit_speed = 0.4

		_spawn_drone(drone)

	# Spawn dive drone
	if mixed_include_dive:
		var dive_pos := positions[pos_idx]
		dive_pos.y += 0.5  # Slightly higher for dive drone

		var dive_drone := SimpleDrone.create_drone(
			_next_drone_id,
			dive_pos,
			SimpleDrone.Behavior.DIVE,
			Color(1.0, 0.8, 0.0)  # Yellow (warning color)
		)
		_next_drone_id += 1

		dive_drone.can_shoot = false
		dive_drone.dive_telegraph_duration = 2.5  # Long telegraph for training
		dive_drone.dive_speed = 1.5  # Slow dive
		dive_drone.max_health = 80.0  # Can be destroyed before dive completes

		_spawn_drone(dive_drone)


# =============================================================================
# SPAWN HELPERS
# =============================================================================

func _spawn_drone(drone: SimpleDrone) -> void:
	if active_drones.size() >= max_active_drones:
		DebugLogger.warn(SOURCE, "Max drone limit reached (%d), skipping spawn" % max_active_drones)
		drone.queue_free()
		return

	# Set target
	drone.set_target(target)

	# Connect signals
	drone.drone_spawned.connect(_on_drone_spawned)
	drone.drone_destroyed.connect(_on_drone_destroyed)
	drone.projectile_fired.connect(_on_projectile_fired)
	drone.dive_started.connect(_on_dive_started)
	drone.dive_completed.connect(_on_dive_completed)

	# Add to scene
	if spawn_parent:
		spawn_parent.add_child(drone)
	else:
		get_tree().root.add_child(drone)

	active_drones.append(drone)


func _calculate_spawn_positions(count: int) -> Array[Vector3]:
	var positions: Array[Vector3] = []

	if target == null:
		# Fallback: spawn in front of origin
		for i in range(count):
			positions.append(Vector3(i * 2.0 - count, spawn_height, -spawn_distance))
		return positions

	var base_pos := target.global_position
	var forward := -target.global_transform.basis.z

	if count == 1:
		# Single drone: directly in front
		var pos := base_pos + forward * spawn_distance
		pos.y = spawn_height
		positions.append(pos)
	else:
		# Multiple drones: spread in an arc
		var arc_rad := deg_to_rad(spawn_arc)
		var angle_step := arc_rad / (count - 1)
		var start_angle := -arc_rad / 2.0

		for i in range(count):
			var angle := start_angle + angle_step * i
			var dir := forward.rotated(Vector3.UP, angle)
			var pos := base_pos + dir * spawn_distance
			pos.y = spawn_height
			positions.append(pos)

	return positions


# =============================================================================
# DESPAWNING
# =============================================================================

## Despawn all active drones and projectiles
func despawn_all() -> void:
	var drone_count := active_drones.size()
	var proj_count := active_projectiles.size()

	# Despawn drones
	for drone in active_drones:
		if is_instance_valid(drone) and not drone.is_queued_for_deletion():
			drone.queue_free()
	active_drones.clear()

	# Despawn projectiles
	for proj in active_projectiles:
		if is_instance_valid(proj) and not proj.is_queued_for_deletion():
			proj.queue_free()
	active_projectiles.clear()

	if drone_count > 0 or proj_count > 0:
		DebugLogger.debug(SOURCE, "Despawned %d drones, %d projectiles" % [drone_count, proj_count])


## Despawn all drones but keep projectiles in flight
func despawn_drones_only() -> void:
	var count := active_drones.size()

	for drone in active_drones:
		if is_instance_valid(drone) and not drone.is_queued_for_deletion():
			drone.queue_free()
	active_drones.clear()

	if count > 0:
		DebugLogger.debug(SOURCE, "Despawned %d drones" % count)


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_drone_spawned(drone: SimpleDrone) -> void:
	DebugLogger.debug(SOURCE, "Drone %d spawned (behavior=%s)" % [
		drone.drone_id, SimpleDrone.Behavior.keys()[drone.behavior]
	])
	drone_spawned.emit(drone)


func _on_drone_destroyed(drone: SimpleDrone, by_player: bool) -> void:
	DebugLogger.info(SOURCE, "Drone %d destroyed (by_player=%s)" % [drone.drone_id, by_player])

	# Remove from active list
	var idx := active_drones.find(drone)
	if idx >= 0:
		active_drones.remove_at(idx)

	drone_destroyed.emit(drone, by_player)

	# Check if all drones are gone
	if active_drones.is_empty():
		DebugLogger.debug(SOURCE, "All drones destroyed")
		all_drones_destroyed.emit()


func _on_projectile_fired(drone: SimpleDrone, projectile: Projectile) -> void:
	_projectile_id += 1
	DebugLogger.debug(SOURCE, "Drone %d fired projectile %d" % [drone.drone_id, _projectile_id])

	# Track projectile
	if active_projectiles.size() < max_active_projectiles:
		active_projectiles.append(projectile)
		projectile.deflected.connect(_on_projectile_deflected.bind(projectile))
		projectile.hit_target.connect(_on_projectile_hit.bind(projectile))
		projectile.expired.connect(_on_projectile_expired.bind(projectile))
	else:
		DebugLogger.warn(SOURCE, "Max projectile limit reached, projectile not tracked")

	projectile_fired.emit(drone, projectile)


func _on_projectile_deflected(projectile: Projectile, _new_dir: Vector3) -> void:
	DebugLogger.debug(SOURCE, "Projectile BLOCKED/DEFLECTED")
	projectile_blocked.emit(projectile)


func _on_projectile_hit(projectile: Projectile, target_node: Node3D) -> void:
	if target_node and target_node.is_in_group("player"):
		DebugLogger.debug(SOURCE, "Projectile hit PLAYER")
		projectile_hit_player.emit(projectile)
	else:
		DebugLogger.trace(SOURCE, "Projectile hit target: %s" % (target_node.name if target_node else "unknown"))


func _on_projectile_expired(_projectile: Projectile) -> void:
	DebugLogger.trace(SOURCE, "Projectile expired (timeout)")


func _on_dive_started(drone: SimpleDrone) -> void:
	DebugLogger.info(SOURCE, "Drone %d started DIVE attack!" % drone.drone_id)
	dive_started.emit(drone)


func _on_dive_completed(drone: SimpleDrone, hit_player: bool) -> void:
	var result := "HIT" if hit_player else "MISS"
	DebugLogger.info(SOURCE, "Drone %d completed DIVE (result=%s)" % [drone.drone_id, result])
	dive_completed.emit(drone, hit_player)


# =============================================================================
# PROJECTILE CLEANUP
# =============================================================================

func _cleanup_projectile_list() -> void:
	# Remove invalid projectiles from tracking list
	var i := active_projectiles.size() - 1
	while i >= 0:
		var proj := active_projectiles[i]
		if not is_instance_valid(proj) or proj.is_queued_for_deletion():
			active_projectiles.remove_at(i)
		i -= 1


# =============================================================================
# QUERIES
# =============================================================================

func get_active_drone_count() -> int:
	return active_drones.size()


func get_active_projectile_count() -> int:
	_cleanup_projectile_list()
	return active_projectiles.size()


func has_active_drones() -> bool:
	return not active_drones.is_empty()


func has_dive_drone_active() -> bool:
	for drone in active_drones:
		if drone.behavior == SimpleDrone.Behavior.DIVE:
			return true
	return false
