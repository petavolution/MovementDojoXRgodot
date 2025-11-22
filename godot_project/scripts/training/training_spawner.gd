## TrainingSpawner - Generic enemy spawner for the training sequence system
## Maps WaveSpawnEntry definitions to actual game entities
##
## Design: Bridge between data-driven WaveSpawnEntry and concrete entity classes
## Handles spawn positioning, entity configuration, and lifecycle management
class_name TrainingSpawner
extends Node

const SOURCE := "TrnSpawner"

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when an enemy is spawned
signal enemy_spawned(enemy: Node3D, entry: WaveSpawnEntry)

## Emitted when an enemy is destroyed
signal enemy_destroyed(enemy: Node3D, by_player: bool)

## Emitted when a projectile is fired by an enemy
signal projectile_fired(enemy: Node3D, projectile: Node3D)

## Emitted when a projectile is blocked/deflected
signal projectile_blocked(projectile: Node3D)

## Emitted when a projectile hits the player
signal projectile_hit_player(projectile: Node3D)

## Emitted when a dive attack starts
signal dive_started(enemy: Node3D)

## Emitted when a dive attack completes
signal dive_completed(enemy: Node3D, hit_player: bool)

## Emitted when all spawned enemies are destroyed
signal all_enemies_destroyed()

# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Limits")
## Maximum concurrent enemies
@export var max_active_enemies := 10

## Maximum concurrent projectiles
@export var max_active_projectiles := 20

@export_group("Defaults")
## Default spawn distance from player
@export var default_spawn_distance := 3.0

## Default spawn height (player eye level offset)
@export var default_spawn_height := 0.0

## Base arc spread for formations (degrees)
@export var default_spawn_arc := 120.0

# =============================================================================
# STATE
# =============================================================================

## Currently active enemies
var active_enemies: Array[Node3D] = []

## Currently active projectiles
var active_projectiles: Array[Node3D] = []

## Enemy ID counter
var _enemy_id := 0

## Player target (for positioning and aiming)
var player_target: Node3D

## Parent node for spawned entities
var spawn_parent: Node3D

## Is spawner active
var is_active := false

# =============================================================================
# WAVE TRACKING (for completion detection)
# =============================================================================

## Current wave ID being spawned
var current_wave_id: String = ""

## Enemies spawned in current wave (for completion tracking)
var wave_enemies_total := 0

## Enemies killed in current wave by player
var wave_enemies_killed := 0

## Projectiles fired this wave
var wave_projectiles_fired := 0

## Projectiles blocked this wave
var wave_projectiles_blocked := 0

## Hits taken by player this wave
var wave_hits_taken := 0

## Whether wave spawning is complete (all entries processed)
var wave_spawning_complete := false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	DebugLogger.debug(SOURCE, "TrainingSpawner initialized")


func _process(_delta: float) -> void:
	# Clean up destroyed entities from tracking arrays
	_cleanup_destroyed_entities()


func _exit_tree() -> void:
	despawn_all()


# =============================================================================
# SETUP
# =============================================================================

## Configure the spawner with required references
func setup(target: Node3D, parent: Node3D) -> void:
	player_target = target
	spawn_parent = parent
	is_active = true

	DebugLogger.debug(SOURCE, "Spawner configured: target=%s, parent=%s" % [
		target.name if target else "null",
		parent.name if parent else "null"
	])


## Disable the spawner
func disable() -> void:
	is_active = false
	despawn_all()


# =============================================================================
# WAVE LIFECYCLE
# =============================================================================

## Start a new wave - resets wave tracking
func start_wave(wave_id: String) -> void:
	# Cleanup any remaining entities from previous wave
	if has_active_enemies():
		DebugLogger.warn(SOURCE, "Starting wave '%s' with %d enemies still active - cleaning up" % [
			wave_id, get_active_enemy_count()
		])
		despawn_all()

	current_wave_id = wave_id
	wave_enemies_total = 0
	wave_enemies_killed = 0
	wave_projectiles_fired = 0
	wave_projectiles_blocked = 0
	wave_hits_taken = 0
	wave_spawning_complete = false

	DebugLogger.debug(SOURCE, "Wave '%s' started - tracking reset" % wave_id)


## Mark wave spawning as complete (all entries processed)
func mark_spawning_complete() -> void:
	wave_spawning_complete = true
	DebugLogger.debug(SOURCE, "Wave '%s' spawning complete: %d enemies total" % [
		current_wave_id, wave_enemies_total
	])


## End current wave - returns metrics and cleans up
func end_wave() -> Dictionary:
	var metrics := get_wave_metrics()

	DebugLogger.info(SOURCE, "Wave '%s' ended: spawned=%d, killed=%d, blocked=%d, hits_taken=%d" % [
		current_wave_id,
		metrics.get("enemies_spawned", 0),
		metrics.get("enemies_killed", 0),
		metrics.get("projectiles_blocked", 0),
		metrics.get("hits_taken", 0)
	])

	# Cleanup remaining entities
	despawn_all()

	# Reset wave tracking
	current_wave_id = ""
	wave_spawning_complete = false

	return metrics


## Get current wave metrics
func get_wave_metrics() -> Dictionary:
	return {
		"wave_id": current_wave_id,
		"enemies_spawned": wave_enemies_total,
		"enemies_killed": wave_enemies_killed,
		"enemies_remaining": get_active_enemy_count(),
		"projectiles_fired": wave_projectiles_fired,
		"projectiles_blocked": wave_projectiles_blocked,
		"hits_taken": wave_hits_taken,
		"spawning_complete": wave_spawning_complete,
	}


## Check if current wave is complete (all enemies dead, spawning done)
func is_wave_complete() -> bool:
	if not wave_spawning_complete:
		return false
	return get_active_enemy_count() == 0


# =============================================================================
# SPAWNING API
# =============================================================================

## Spawn enemies from a WaveSpawnEntry
func spawn_from_entry(entry: WaveSpawnEntry) -> Array[Node3D]:
	if not is_active:
		DebugLogger.warn(SOURCE, "Spawner not active, ignoring spawn request")
		return []

	if not _can_spawn(entry.count):
		DebugLogger.warn(SOURCE, "Cannot spawn %d enemies (limit reached)" % entry.count)
		return []

	var spawned: Array[Node3D] = []
	var positions := _calculate_spawn_positions(entry)
	var spawn_failed := 0

	DebugLogger.debug(SOURCE, "Spawning: %s" % entry.get_summary())

	for i in range(entry.count):
		var enemy := _create_enemy(entry, positions[i])
		if enemy:
			spawned.append(enemy)
			wave_enemies_total += 1
		else:
			spawn_failed += 1
			DebugLogger.error(SOURCE, "Failed to spawn enemy %d of %d (%s)" % [
				i + 1, entry.count, WaveSpawnEntry.get_enemy_type_name(entry.enemy_type)
			])

	if spawn_failed > 0:
		DebugLogger.warn(SOURCE, "Spawn entry had %d failures out of %d" % [spawn_failed, entry.count])

	return spawned


## Spawn a single enemy at a specific position
func spawn_single(entry: WaveSpawnEntry, position: Vector3) -> Node3D:
	if not is_active or not _can_spawn(1):
		return null

	return _create_enemy(entry, position)


## Despawn all active enemies and projectiles
func despawn_all() -> void:
	DebugLogger.debug(SOURCE, "Despawning all (%d enemies, %d projectiles)" % [
		active_enemies.size(), active_projectiles.size()
	])

	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()

	for proj in active_projectiles:
		if is_instance_valid(proj):
			proj.queue_free()
	active_projectiles.clear()


## Despawn only enemies (keep projectiles)
func despawn_enemies() -> void:
	DebugLogger.debug(SOURCE, "Despawning %d enemies" % active_enemies.size())

	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()


# =============================================================================
# QUERIES
# =============================================================================

## Get count of active enemies
func get_active_enemy_count() -> int:
	_cleanup_destroyed_entities()
	return active_enemies.size()


## Check if any enemies are active
func has_active_enemies() -> bool:
	return get_active_enemy_count() > 0


## Get count of active projectiles
func get_active_projectile_count() -> int:
	_cleanup_destroyed_entities()
	return active_projectiles.size()


# =============================================================================
# ENEMY CREATION (Maps EnemyType to concrete classes)
# =============================================================================

func _create_enemy(entry: WaveSpawnEntry, position: Vector3) -> Node3D:
	var enemy: Node3D = null

	match entry.enemy_type:
		WaveSpawnEntry.EnemyType.FLYING_DRONE, \
		WaveSpawnEntry.EnemyType.DIVE_ATTACKER, \
		WaveSpawnEntry.EnemyType.TARGET_DUMMY:
			enemy = _create_drone(entry, position)

		WaveSpawnEntry.EnemyType.MELEE_BOT:
			enemy = _create_melee_bot(entry, position)

		WaveSpawnEntry.EnemyType.RANGED_TROOP:
			enemy = _create_ranged_troop(entry, position)

		WaveSpawnEntry.EnemyType.SHIELDED_DRONE:
			enemy = _create_shielded_drone(entry, position)

		WaveSpawnEntry.EnemyType.BOMBER_DRONE:
			enemy = _create_bomber_drone(entry, position)

		_:
			DebugLogger.warn(SOURCE, "Unknown enemy type: %d" % entry.enemy_type)
			return null

	if enemy:
		_register_enemy(enemy, entry)

	return enemy


## Create a flying drone (most common enemy type)
func _create_drone(entry: WaveSpawnEntry, position: Vector3) -> Node3D:
	# Map WaveSpawnEntry to SimpleDrone behavior
	var behavior := SimpleDrone.Behavior.HOVER
	match entry.behavior:
		WaveSpawnEntry.SpawnBehavior.STATIONARY:
			behavior = SimpleDrone.Behavior.HOVER
		WaveSpawnEntry.SpawnBehavior.ORBIT, WaveSpawnEntry.SpawnBehavior.RANDOM_DRIFT:
			behavior = SimpleDrone.Behavior.SLOW_ORBIT
		_:
			behavior = SimpleDrone.Behavior.HOVER

	# Override for dive attackers
	if entry.enemy_type == WaveSpawnEntry.EnemyType.DIVE_ATTACKER:
		behavior = SimpleDrone.Behavior.DIVE

	var drone := SimpleDrone.create_drone(
		_enemy_id,
		position,
		behavior,
		entry.get_spawn_color()
	)
	_enemy_id += 1

	# Apply entry configuration
	drone.can_shoot = entry.can_shoot
	drone.shoot_at_player = entry.can_shoot
	drone.fire_interval = entry.fire_interval
	drone.projectile_speed = entry.projectile_speed
	drone.projectile_damage = entry.projectile_damage

	# Health with multiplier
	var base_health := 50.0
	if entry.enemy_type == WaveSpawnEntry.EnemyType.TARGET_DUMMY:
		base_health = 30.0
	drone.max_health = base_health * entry.health_multiplier

	# Movement configuration
	drone.orbit_radius = entry.orbit_radius
	drone.orbit_speed = entry.orbit_speed * entry.movement_speed

	# Scale
	if entry.scale_multiplier != 1.0:
		drone.scale *= entry.scale_multiplier

	return drone


## Create a melee bot (placeholder - uses drone for now)
func _create_melee_bot(entry: WaveSpawnEntry, position: Vector3) -> Node3D:
	# TODO: Implement MeleeBot class
	# For now, create a non-shooting aggressive drone as placeholder
	DebugLogger.debug(SOURCE, "MeleeBot not implemented, using drone placeholder")

	var drone := SimpleDrone.create_drone(
		_enemy_id,
		position,
		SimpleDrone.Behavior.SLOW_ORBIT,
		entry.get_spawn_color()
	)
	_enemy_id += 1

	drone.can_shoot = false
	drone.orbit_radius = 1.5
	drone.orbit_speed = 0.8 * entry.movement_speed
	drone.max_health = 80.0 * entry.health_multiplier

	return drone


## Create a ranged troop (placeholder - uses drone for now)
func _create_ranged_troop(entry: WaveSpawnEntry, position: Vector3) -> Node3D:
	# TODO: Implement RangedTroop class
	# For now, create a stationary shooting drone as placeholder
	DebugLogger.debug(SOURCE, "RangedTroop not implemented, using drone placeholder")

	var drone := SimpleDrone.create_drone(
		_enemy_id,
		position,
		SimpleDrone.Behavior.HOVER,
		entry.get_spawn_color()
	)
	_enemy_id += 1

	drone.can_shoot = true
	drone.shoot_at_player = true
	drone.fire_interval = entry.fire_interval
	drone.projectile_speed = entry.projectile_speed
	drone.max_health = 60.0 * entry.health_multiplier

	return drone


## Create a shielded drone (placeholder)
func _create_shielded_drone(entry: WaveSpawnEntry, position: Vector3) -> Node3D:
	# TODO: Implement ShieldedDrone class
	DebugLogger.debug(SOURCE, "ShieldedDrone not implemented, using drone placeholder")

	var drone := SimpleDrone.create_drone(
		_enemy_id,
		position,
		SimpleDrone.Behavior.SLOW_ORBIT,
		entry.get_spawn_color()
	)
	_enemy_id += 1

	drone.can_shoot = entry.can_shoot
	drone.max_health = 100.0 * entry.health_multiplier  # Extra tanky

	return drone


## Create a bomber drone (placeholder)
func _create_bomber_drone(entry: WaveSpawnEntry, position: Vector3) -> Node3D:
	# TODO: Implement BomberDrone class
	DebugLogger.debug(SOURCE, "BomberDrone not implemented, using drone placeholder")

	var drone := SimpleDrone.create_drone(
		_enemy_id,
		position,
		SimpleDrone.Behavior.SLOW_ORBIT,
		entry.get_spawn_color()
	)
	_enemy_id += 1

	drone.can_shoot = false
	drone.orbit_radius = 2.0
	drone.max_health = 70.0 * entry.health_multiplier

	return drone


# =============================================================================
# ENEMY REGISTRATION & SIGNALS
# =============================================================================

func _register_enemy(enemy: Node3D, entry: WaveSpawnEntry) -> void:
	if spawn_parent:
		spawn_parent.add_child(enemy)

	active_enemies.append(enemy)

	# Connect signals based on enemy type
	if enemy is SimpleDrone:
		var drone := enemy as SimpleDrone
		drone.drone_destroyed.connect(_on_drone_destroyed.bind(enemy))
		drone.projectile_fired.connect(_on_projectile_fired.bind(enemy))
		drone.dive_started.connect(_on_dive_started.bind(enemy))
		drone.dive_completed.connect(_on_dive_completed.bind(enemy))

	enemy_spawned.emit(enemy, entry)
	DebugLogger.debug(SOURCE, "Spawned %s at %s" % [
		WaveSpawnEntry.get_enemy_type_name(entry.enemy_type),
		enemy.global_position
	])


func _on_drone_destroyed(by_player: bool, enemy: Node3D) -> void:
	active_enemies.erase(enemy)

	# Track wave metric
	if by_player:
		wave_enemies_killed += 1
		DebugLogger.debug(SOURCE, "Enemy killed by player (%d/%d in wave '%s')" % [
			wave_enemies_killed, wave_enemies_total, current_wave_id
		])

	enemy_destroyed.emit(enemy, by_player)

	# Check if all enemies destroyed
	if active_enemies.is_empty():
		DebugLogger.debug(SOURCE, "All enemies destroyed for wave '%s'" % current_wave_id)
		all_enemies_destroyed.emit()


func _on_projectile_fired(projectile: Projectile, enemy: Node3D) -> void:
	if projectile and is_instance_valid(projectile):
		active_projectiles.append(projectile)
		wave_projectiles_fired += 1

		# Connect projectile signals
		if projectile.has_signal("deflected"):
			projectile.deflected.connect(_on_projectile_deflected.bind(projectile))
		if projectile.has_signal("hit_player"):
			projectile.hit_player.connect(_on_projectile_hit.bind(projectile))

	projectile_fired.emit(enemy, projectile)


func _on_projectile_deflected(projectile: Node3D) -> void:
	wave_projectiles_blocked += 1
	DebugLogger.debug(SOURCE, "Projectile blocked (%d total in wave '%s')" % [
		wave_projectiles_blocked, current_wave_id
	])
	projectile_blocked.emit(projectile)


func _on_projectile_hit(projectile: Node3D) -> void:
	wave_hits_taken += 1
	DebugLogger.debug(SOURCE, "Player hit by projectile (%d hits in wave '%s')" % [
		wave_hits_taken, current_wave_id
	])
	projectile_hit_player.emit(projectile)


func _on_dive_started(enemy: Node3D) -> void:
	DebugLogger.debug(SOURCE, "Dive attack started in wave '%s'" % current_wave_id)
	dive_started.emit(enemy)


func _on_dive_completed(hit_player: bool, enemy: Node3D) -> void:
	if hit_player:
		wave_hits_taken += 1
		DebugLogger.debug(SOURCE, "Player hit by dive attack (%d hits in wave '%s')" % [
			wave_hits_taken, current_wave_id
		])
	dive_completed.emit(enemy, hit_player)


# =============================================================================
# POSITIONING
# =============================================================================

func _calculate_spawn_positions(entry: WaveSpawnEntry) -> Array[Vector3]:
	var positions: Array[Vector3] = []

	if not player_target:
		DebugLogger.warn(SOURCE, "No player target for spawn positioning")
		for i in range(entry.count):
			positions.append(Vector3(0, 1.6, -entry.spawn_distance))
		return positions

	var player_pos := player_target.global_position
	var player_forward := -player_target.global_transform.basis.z
	player_forward.y = 0
	player_forward = player_forward.normalized()

	var spawn_distance := entry.spawn_distance if entry.spawn_distance > 0 else default_spawn_distance
	var spawn_height := player_pos.y + entry.spawn_height_offset
	var arc_degrees := entry.spawn_arc_degrees if entry.spawn_arc_degrees > 0 else default_spawn_arc

	match entry.formation:
		WaveSpawnEntry.SpawnFormation.SINGLE, WaveSpawnEntry.SpawnFormation.ARC:
			positions = _calculate_arc_positions(
				player_pos, player_forward, entry.count,
				spawn_distance, spawn_height, arc_degrees, entry.position_jitter
			)

		WaveSpawnEntry.SpawnFormation.LINE:
			positions = _calculate_line_positions(
				player_pos, player_forward, entry.count,
				spawn_distance, spawn_height, arc_degrees, entry.position_jitter
			)

		WaveSpawnEntry.SpawnFormation.CLUSTER:
			positions = _calculate_cluster_positions(
				player_pos, player_forward, entry.count,
				spawn_distance, spawn_height, entry.position_jitter
			)

		WaveSpawnEntry.SpawnFormation.SURROUND:
			positions = _calculate_surround_positions(
				player_pos, entry.count,
				spawn_distance, spawn_height, entry.position_jitter
			)

	return positions


func _calculate_arc_positions(
	center: Vector3, forward: Vector3, count: int,
	distance: float, height: float, arc_deg: float, jitter: float
) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var arc_rad := deg_to_rad(arc_deg)

	if count == 1:
		var pos := center + forward * distance
		pos.y = height
		positions.append(_apply_jitter(pos, jitter))
	else:
		var start_angle := -arc_rad / 2.0
		var angle_step := arc_rad / float(count - 1)

		for i in range(count):
			var angle := start_angle + angle_step * i
			var dir := forward.rotated(Vector3.UP, angle)
			var pos := center + dir * distance
			pos.y = height
			positions.append(_apply_jitter(pos, jitter))

	return positions


func _calculate_line_positions(
	center: Vector3, forward: Vector3, count: int,
	distance: float, height: float, spread: float, jitter: float
) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var right := forward.cross(Vector3.UP).normalized()
	var total_width := spread * 0.05  # Convert degrees to rough meters

	var spawn_center := center + forward * distance
	spawn_center.y = height

	if count == 1:
		positions.append(_apply_jitter(spawn_center, jitter))
	else:
		var start_offset := -total_width / 2.0
		var step := total_width / float(count - 1)

		for i in range(count):
			var offset := start_offset + step * i
			var pos := spawn_center + right * offset
			positions.append(_apply_jitter(pos, jitter))

	return positions


func _calculate_cluster_positions(
	center: Vector3, forward: Vector3, count: int,
	distance: float, height: float, jitter: float
) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var cluster_center := center + forward * distance
	cluster_center.y = height

	# Cluster with higher jitter
	var cluster_jitter := jitter + 0.5

	for i in range(count):
		positions.append(_apply_jitter(cluster_center, cluster_jitter))

	return positions


func _calculate_surround_positions(
	center: Vector3, count: int,
	distance: float, height: float, jitter: float
) -> Array[Vector3]:
	var positions: Array[Vector3] = []

	for i in range(count):
		var angle := (TAU / float(count)) * i
		var dir := Vector3(cos(angle), 0, sin(angle))
		var pos := center + dir * distance
		pos.y = height
		positions.append(_apply_jitter(pos, jitter))

	return positions


func _apply_jitter(pos: Vector3, jitter: float) -> Vector3:
	if jitter <= 0:
		return pos

	return pos + Vector3(
		randf_range(-jitter, jitter),
		randf_range(-jitter * 0.5, jitter * 0.5),
		randf_range(-jitter, jitter)
	)


# =============================================================================
# UTILITY
# =============================================================================

func _can_spawn(count: int) -> bool:
	return (active_enemies.size() + count) <= max_active_enemies


func _cleanup_destroyed_entities() -> void:
	# Remove invalid enemies
	var i := active_enemies.size() - 1
	while i >= 0:
		if not is_instance_valid(active_enemies[i]):
			active_enemies.remove_at(i)
		i -= 1

	# Remove invalid projectiles
	i = active_projectiles.size() - 1
	while i >= 0:
		if not is_instance_valid(active_projectiles[i]):
			active_projectiles.remove_at(i)
		i -= 1
