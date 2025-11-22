## SimpleDrone - Safe, predictable drone for Level 1 training
## Behaviors: HOVER (stationary), SLOW_ORBIT (gentle movement), DIVE (slow ram attack)
## Uses existing Projectile system with slower, more visible projectiles
extends Node3D
class_name SimpleDrone

const SOURCE := "SimpleDrone"

# =============================================================================
# SIGNALS
# =============================================================================

signal drone_spawned(drone: SimpleDrone)
signal drone_destroyed(drone: SimpleDrone, by_player: bool)
signal projectile_fired(drone: SimpleDrone, projectile: Projectile)
signal dive_started(drone: SimpleDrone)
signal dive_completed(drone: SimpleDrone, hit_player: bool)
signal drone_hit(drone: SimpleDrone, damage: float)

# =============================================================================
# BEHAVIOR TYPES
# =============================================================================

enum Behavior {
	HOVER,       # Stay in place, optionally shoot
	SLOW_ORBIT,  # Gentle circular movement, optionally shoot
	DIVE         # Telegraph then slowly ram towards player
}

enum DroneState {
	SPAWNING,    # Fade in / appear animation
	ACTIVE,      # Normal behavior
	TELEGRAPHING,# Dive: showing warning before attack
	DIVING,      # Dive: moving towards player
	STUNNED,     # Temporarily disabled
	DESTROYED    # Being removed
}

# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Identity")
@export var drone_id := 0

@export_group("Behavior")
@export var behavior := Behavior.HOVER
@export var can_shoot := true
@export var shoot_at_player := true

@export_group("Movement")
## Orbit radius for SLOW_ORBIT behavior
@export var orbit_radius := 1.5
## Orbit speed (radians per second)
@export var orbit_speed := 0.5
## Hover bob amplitude
@export var bob_amplitude := 0.1
## Hover bob speed
@export var bob_speed := 2.0

@export_group("Dive Attack")
## How long to telegraph before diving (seconds)
@export var dive_telegraph_duration := 2.0
## Dive movement speed (units/second)
@export var dive_speed := 2.0
## Maximum dive duration before timeout
@export var dive_max_duration := 5.0
## Distance at which dive is considered a "hit"
@export var dive_hit_radius := 0.8

@export_group("Shooting")
## Seconds between shots
@export var fire_interval := 3.0
## Projectile speed (slower than normal for training)
@export var projectile_speed := 4.0
## Projectile damage
@export var projectile_damage := 10.0

@export_group("Health")
@export var max_health := 50.0

@export_group("Appearance")
@export var drone_color := Color(0.8, 0.2, 0.2)  # Red
@export var telegraph_color := Color(1.0, 0.8, 0.0)  # Yellow warning
@export var drone_radius := 0.25

# =============================================================================
# STATE
# =============================================================================

var current_state := DroneState.SPAWNING
var current_health: float
var is_destroyed := false

# Movement state
var _spawn_position := Vector3.ZERO
var _orbit_phase := 0.0
var _bob_phase := 0.0

# Shooting state
var _fire_timer := 0.0
var _projectiles_fired := 0

# Dive state
var _dive_timer := 0.0
var _dive_target_pos := Vector3.ZERO
var _dive_hit := false

# Target (player camera)
var target: Node3D

# Visual nodes
var mesh: MeshInstance3D
var material: StandardMaterial3D
var eye_mesh: MeshInstance3D
var eye_material: StandardMaterial3D
var collision_area: Area3D

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	current_health = max_health
	_spawn_position = global_position
	_orbit_phase = randf() * TAU  # Random start phase for variety
	_bob_phase = randf() * TAU

	_setup_visuals()
	_setup_collision()

	# Start in spawning state, transition to active after brief delay
	current_state = DroneState.SPAWNING
	_enter_spawning()


func _process(delta: float) -> void:
	if is_destroyed:
		return

	match current_state:
		DroneState.SPAWNING:
			_process_spawning(delta)
		DroneState.ACTIVE:
			_process_active(delta)
		DroneState.TELEGRAPHING:
			_process_telegraphing(delta)
		DroneState.DIVING:
			_process_diving(delta)
		DroneState.STUNNED:
			_process_stunned(delta)


func _exit_tree() -> void:
	DebugLogger.trace(SOURCE, "Drone %d exiting tree" % drone_id)


# =============================================================================
# VISUAL SETUP
# =============================================================================

func _setup_visuals() -> void:
	# Main body sphere
	mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = drone_radius
	sphere.height = drone_radius * 2
	sphere.radial_segments = 16
	sphere.rings = 8

	material = StandardMaterial3D.new()
	material.albedo_color = drone_color
	material.emission_enabled = true
	material.emission = drone_color * 0.3
	material.emission_energy_multiplier = 0.5
	material.metallic = 0.4
	material.roughness = 0.6

	sphere.material = material
	mesh.mesh = sphere
	mesh.name = "DroneMesh"
	add_child(mesh)

	# Eye indicator (shows direction/state)
	eye_mesh = MeshInstance3D.new()
	var eye_sphere := SphereMesh.new()
	eye_sphere.radius = drone_radius * 0.3
	eye_sphere.height = drone_radius * 0.6

	eye_material = StandardMaterial3D.new()
	eye_material.albedo_color = Color(1.0, 0.5, 0.0)  # Orange eye
	eye_material.emission_enabled = true
	eye_material.emission = Color(1.0, 0.5, 0.0)
	eye_material.emission_energy_multiplier = 1.0

	eye_sphere.material = eye_material
	eye_mesh.mesh = eye_sphere
	eye_mesh.name = "DroneEye"
	eye_mesh.position = Vector3(0, 0, -drone_radius * 0.85)
	add_child(eye_mesh)


func _setup_collision() -> void:
	# Area for detecting hits (blade, projectiles)
	collision_area = Area3D.new()
	collision_area.collision_layer = 4  # Enemy layer
	collision_area.collision_mask = 2 | 16  # Blade + projectile layers
	collision_area.name = "HitArea"

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = drone_radius * 1.2
	shape.shape = sphere
	collision_area.add_child(shape)

	add_child(collision_area)
	collision_area.area_entered.connect(_on_area_entered)


# =============================================================================
# STATE: SPAWNING
# =============================================================================

var _spawn_timer := 0.0
const SPAWN_DURATION := 0.5

func _enter_spawning() -> void:
	# Start scaled down / transparent
	mesh.scale = Vector3.ZERO
	eye_mesh.scale = Vector3.ZERO
	_spawn_timer = 0.0

	DebugLogger.info(SOURCE, "Drone %d spawning at %s, behavior=%s" % [
		drone_id,
		_format_vec3(global_position),
		Behavior.keys()[behavior]
	])


func _process_spawning(delta: float) -> void:
	_spawn_timer += delta
	var t := minf(_spawn_timer / SPAWN_DURATION, 1.0)

	# Ease-out scale animation
	var scale_t := 1.0 - pow(1.0 - t, 3.0)
	mesh.scale = Vector3.ONE * scale_t
	eye_mesh.scale = Vector3.ONE * scale_t

	if t >= 1.0:
		drone_spawned.emit(self)
		_change_state(DroneState.ACTIVE)


# =============================================================================
# STATE: ACTIVE
# =============================================================================

func _change_state(new_state: DroneState) -> void:
	var old_name := DroneState.keys()[current_state]
	var new_name := DroneState.keys()[new_state]
	current_state = new_state
	DebugLogger.debug(SOURCE, "Drone %d: %s → %s" % [drone_id, old_name, new_name])


func _process_active(delta: float) -> void:
	# Movement based on behavior
	match behavior:
		Behavior.HOVER:
			_update_hover(delta)
		Behavior.SLOW_ORBIT:
			_update_orbit(delta)
		Behavior.DIVE:
			# Dive drones start in active, then telegraph, then dive
			_update_hover(delta)  # Gentle hover before dive

	# Face the target
	_face_target()

	# Shooting (if enabled and not dive behavior)
	if can_shoot and behavior != Behavior.DIVE:
		_update_shooting(delta)

	# Dive behavior triggers telegraph after a delay
	if behavior == Behavior.DIVE:
		_fire_timer += delta
		if _fire_timer >= 2.0:  # Wait 2 seconds before starting telegraph
			_start_telegraph()


func _update_hover(delta: float) -> void:
	_bob_phase += delta * bob_speed
	var bob_offset := sin(_bob_phase) * bob_amplitude
	global_position.y = _spawn_position.y + bob_offset


func _update_orbit(delta: float) -> void:
	_orbit_phase += delta * orbit_speed
	_bob_phase += delta * bob_speed

	var orbit_offset := Vector3(
		cos(_orbit_phase) * orbit_radius,
		sin(_bob_phase) * bob_amplitude,
		sin(_orbit_phase) * orbit_radius
	)

	global_position = _spawn_position + orbit_offset


func _face_target() -> void:
	if target == null:
		return

	var look_pos := target.global_position
	look_pos.y = global_position.y  # Keep level

	if global_position.distance_to(look_pos) > 0.1:
		look_at(look_pos, Vector3.UP)


func _update_shooting(delta: float) -> void:
	if target == null or not shoot_at_player:
		return

	_fire_timer += delta
	if _fire_timer >= fire_interval:
		_fire_timer = 0.0
		_fire_projectile()


func _fire_projectile() -> void:
	if target == null:
		return

	var spawn_pos := global_position + (global_transform.basis.z * -0.3)
	var direction := (target.global_position - spawn_pos).normalized()

	# Add slight inaccuracy for training (easier to dodge)
	direction += Vector3(
		randf_range(-0.1, 0.1),
		randf_range(-0.05, 0.05),
		randf_range(-0.1, 0.1)
	)
	direction = direction.normalized()

	var projectile := Projectile.create_at(spawn_pos, direction, projectile_speed)
	projectile.damage = projectile_damage
	projectile.projectile_color = Color(1.0, 0.4, 0.1)  # Orange-red

	get_tree().root.add_child(projectile)
	_projectiles_fired += 1

	DebugLogger.debug(SOURCE, "Drone %d fired projectile %d (speed=%.1f)" % [
		drone_id, _projectiles_fired, projectile_speed
	])

	projectile_fired.emit(self, projectile)


# =============================================================================
# STATE: TELEGRAPHING (Dive attack warning)
# =============================================================================

func _start_telegraph() -> void:
	_change_state(DroneState.TELEGRAPHING)
	_dive_timer = 0.0

	# Lock target position for dive
	if target:
		_dive_target_pos = target.global_position
	else:
		_dive_target_pos = global_position + Vector3.FORWARD * 3.0

	# Visual warning: change color to yellow
	material.albedo_color = telegraph_color
	material.emission = telegraph_color
	material.emission_energy_multiplier = 1.5

	eye_material.albedo_color = Color(1.0, 0.0, 0.0)  # Red eye = danger
	eye_material.emission = Color(1.0, 0.0, 0.0)
	eye_material.emission_energy_multiplier = 2.0

	DebugLogger.info(SOURCE, "Drone %d TELEGRAPHING DIVE (%.1fs warning)" % [
		drone_id, dive_telegraph_duration
	])

	dive_started.emit(self)


func _process_telegraphing(delta: float) -> void:
	_dive_timer += delta

	# Pulsing effect during telegraph
	var pulse := sin(_dive_timer * 10.0) * 0.5 + 0.5
	material.emission_energy_multiplier = 1.0 + pulse * 1.5

	# Shake slightly
	mesh.position = Vector3(
		randf_range(-0.02, 0.02),
		randf_range(-0.02, 0.02),
		randf_range(-0.02, 0.02)
	)

	# Start dive after telegraph duration
	if _dive_timer >= dive_telegraph_duration:
		_start_dive()


# =============================================================================
# STATE: DIVING
# =============================================================================

func _start_dive() -> void:
	_change_state(DroneState.DIVING)
	_dive_timer = 0.0
	_dive_hit = false

	# Reset mesh position from shake
	mesh.position = Vector3.ZERO

	# Intense color during dive
	material.albedo_color = Color(1.0, 0.2, 0.0)
	material.emission = Color(1.0, 0.2, 0.0)
	material.emission_energy_multiplier = 2.0

	DebugLogger.info(SOURCE, "Drone %d DIVING towards player (speed=%.1f)" % [
		drone_id, dive_speed
	])


func _process_diving(delta: float) -> void:
	_dive_timer += delta

	# Move towards target position
	var direction := (_dive_target_pos - global_position).normalized()
	global_position += direction * dive_speed * delta

	# Face movement direction
	look_at(global_position + direction, Vector3.UP)

	# Check if close enough to player (hit)
	if target:
		var dist := global_position.distance_to(target.global_position)
		if dist <= dive_hit_radius:
			_dive_hit = true
			_complete_dive(true)
			return

	# Check if reached target position (miss - player moved)
	var dist_to_target := global_position.distance_to(_dive_target_pos)
	if dist_to_target <= 0.5:
		_complete_dive(false)
		return

	# Timeout
	if _dive_timer >= dive_max_duration:
		DebugLogger.debug(SOURCE, "Drone %d dive timed out" % drone_id)
		_complete_dive(false)


func _complete_dive(hit_player: bool) -> void:
	DebugLogger.info(SOURCE, "Drone %d completed DIVE (hit_player=%s)" % [
		drone_id, hit_player
	])

	dive_completed.emit(self, hit_player)

	# After dive, either destroy or go back to hover
	# For simplicity in Level 1, destroy after dive
	take_damage(max_health, Vector3.ZERO)


# =============================================================================
# STATE: STUNNED
# =============================================================================

var _stun_timer := 0.0
var _stun_duration := 1.0

func stun(duration: float = 1.0) -> void:
	_stun_duration = duration
	_stun_timer = 0.0
	_change_state(DroneState.STUNNED)

	material.albedo_color = Color(0.5, 0.5, 0.5)  # Gray when stunned
	material.emission_energy_multiplier = 0.2


func _process_stunned(delta: float) -> void:
	_stun_timer += delta

	if _stun_timer >= _stun_duration:
		material.albedo_color = drone_color
		material.emission = drone_color * 0.3
		_change_state(DroneState.ACTIVE)


# =============================================================================
# DAMAGE & DESTRUCTION
# =============================================================================

func take_damage(damage: float, hit_position: Vector3 = Vector3.ZERO) -> void:
	if is_destroyed:
		return

	current_health -= damage
	DebugLogger.debug(SOURCE, "Drone %d took %.0f damage (health: %.0f/%.0f)" % [
		drone_id, damage, current_health, max_health
	])

	drone_hit.emit(self, damage)

	# Flash effect
	_flash_hit()

	if current_health <= 0:
		_destroy(true)


func _flash_hit() -> void:
	material.emission_energy_multiplier = 3.0
	# Reset after brief delay
	var tween := create_tween()
	tween.tween_property(material, "emission_energy_multiplier", 0.5, 0.15)


func _destroy(by_player: bool) -> void:
	if is_destroyed:
		return

	is_destroyed = true
	_change_state(DroneState.DESTROYED)

	DebugLogger.info(SOURCE, "Drone %d DESTROYED (by_player=%s)" % [drone_id, by_player])

	drone_destroyed.emit(self, by_player)

	# Destruction particles
	_spawn_destruction_particles()

	# Shrink and remove
	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3.ZERO, 0.2)
	tween.parallel().tween_property(eye_mesh, "scale", Vector3.ZERO, 0.2)
	tween.tween_callback(queue_free)


func _spawn_destruction_particles() -> void:
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 25
	particles.lifetime = 0.6

	var particle_mat := ParticleProcessMaterial.new()
	particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_mat.emission_sphere_radius = drone_radius
	particle_mat.direction = Vector3(0, 1, 0)
	particle_mat.spread = 180.0
	particle_mat.initial_velocity_min = 2.0
	particle_mat.initial_velocity_max = 5.0
	particle_mat.gravity = Vector3(0, -5, 0)
	particle_mat.scale_min = 0.02
	particle_mat.scale_max = 0.06
	particle_mat.color = drone_color

	particles.process_material = particle_mat
	particles.global_position = global_position

	get_tree().root.add_child(particles)

	# Auto-cleanup
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(particles.queue_free)


# =============================================================================
# COLLISION HANDLING
# =============================================================================

func _on_area_entered(area: Area3D) -> void:
	var parent := area.get_parent()

	# Hit by blade
	if parent is Lightsaber or (parent and "Saber" in parent.name):
		DebugLogger.debug(SOURCE, "Drone %d hit by blade" % drone_id)
		take_damage(30.0, area.global_position)
		return

	# Hit by deflected projectile
	if parent is Projectile:
		var proj := parent as Projectile
		if proj.is_deflected:
			DebugLogger.debug(SOURCE, "Drone %d hit by deflected projectile" % drone_id)
			take_damage(proj.damage, proj.global_position)


# =============================================================================
# PUBLIC API
# =============================================================================

func set_target(new_target: Node3D) -> void:
	target = new_target


func get_state_name() -> String:
	return DroneState.keys()[current_state]


func force_dive() -> void:
	if behavior == Behavior.DIVE and current_state == DroneState.ACTIVE:
		_start_telegraph()


# =============================================================================
# HELPERS
# =============================================================================

func _format_vec3(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]


# =============================================================================
# FACTORY
# =============================================================================

static func create_drone(
	id: int,
	pos: Vector3,
	drone_behavior: Behavior,
	color: Color = Color(0.8, 0.2, 0.2)
) -> SimpleDrone:
	var drone := SimpleDrone.new()
	drone.drone_id = id
	drone.position = pos
	drone.behavior = drone_behavior
	drone.drone_color = color
	return drone
